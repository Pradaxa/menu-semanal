import SwiftUI

// MARK: - Tab Buscar: por título (catálogo JustWatch) y por descripción (Gemini + catálogo)

struct BuscarView: View {
    @EnvironmentObject private var store: QVStore
    @Environment(\.colorScheme) private var scheme
    @State private var query = ""
    @State private var mode: Mode = .title
    @State private var results: [QVTitle] = []
    @State private var status: Status = .hint
    @State private var searchTask: Task<Void, Never>?
    @State private var selected: QVTitle?
    // IA
    @State private var aiReply: String = ""
    @State private var aiNote: String = ""
    @State private var aiProgress: String = ""
    @State private var aiError: AIError?
    @State private var aiSlots: [AISlot] = []
    // Pegar respuesta de Gemini
    @State private var pasteOpen = false
    @State private var pasteText = ""
    @State private var pasteTitles: [(title: String, year: Int?)]?

    enum Mode { case title, ai }
    enum Status { case hint, searching, results, empty, error, aiSteps, pasteReady }

    struct AISlot: Identifiable {
        let id = UUID()
        let candidate: (title: String, year: Int?)
        var item: QVTitle?
        var missing = false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    QVHeader()
                    searchCard
                    content
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .scrollDismissesKeyboard(.interactively)
            .sheet(item: $selected) { item in
                DetailView(item: item)
                    .environmentObject(store)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: Tarjeta de búsqueda

    private var searchCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField(mode == .ai ? "Describe la película o serie…" : "Película o serie…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.ink(scheme).opacity(0.12), lineWidth: 1)
                        )
                        .submitLabel(.search)
                        .onSubmit { submit() }
                        .onChange(of: query) { _ in debounceSearch() }
                        .overlay(alignment: .trailing) {
                            if !query.isEmpty {
                                Button {
                                    query = ""
                                    resetToHint()
                                } label: {
                                    Text("×")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.ink2(scheme))
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(SilentButtonStyle())
                            }
                        }
                }

                HStack(spacing: 6) {
                    Button { mode = .title; resetToHint() } label: {
                        Text("🔍 Por título")
                    }
                    .buttonStyle(ChipStyle(isOn: mode == .title))
                    Button { mode = .ai; resetToHint() } label: {
                        Text("✨ Por descripción")
                    }
                    .buttonStyle(ChipStyle(isOn: mode == .ai))
                }

                if mode == .ai {
                    Button { runAISearch() } label: {
                        Text("Preguntar a Gemini ✨")
                    }
                    .buttonStyle(MagicButtonStyle())
                    pastePanel
                }
            }
        }
    }

    // MARK: Pegar respuesta de Gemini

    private var pastePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    withAnimation(.appSpring) { pasteOpen.toggle() }
                } label: {
                    Text("📋 Pegar respuesta de Gemini")
                }
                .buttonStyle(ChipStyle(isOn: false))
                Spacer()
                Text("Tu lista, en tu orden")
                    .font(.caption)
                    .foregroundStyle(Color.ink2(scheme))
            }
            if pasteOpen {
                Text("Pega aquí la respuesta completa. El texto se ocultará al pegar.")
                    .font(.caption)
                    .foregroundStyle(Color.ink2(scheme))
                TextEditor(text: $pasteText)
                    .frame(minHeight: 70, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85))
                    )
                    .onChange(of: pasteText) { v in
                        if !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { acceptPaste(v) }
                    }
                Text("No hace falta recortar la introducción ni las explicaciones. Se conserva el orden de los títulos.")
                    .font(.caption)
                    .foregroundStyle(Color.ink2(scheme))
            }
            if let titles = pasteTitles {
                HStack {
                    Text("Respuesta de Gemini pegada ✓")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Button {
                        pasteTitles = nil
                        pasteText = ""
                        status = .hint
                    } label: {
                        Text("×").font(.system(size: 18))
                    }
                    .buttonStyle(SilentButtonStyle())
                }
                .foregroundStyle(Color.ink(scheme))
                Text("\(titles.count) títulos detectados. El texto largo ya está oculto.")
                    .font(.caption)
                    .foregroundStyle(Color.ink2(scheme))
                Button {
                    runPasteSearch(titles)
                } label: {
                    Text("Cargar estas fichas")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func acceptPaste(_ text: String) {
        let titles = PasteParser.parse(text)
        pasteText = ""
        withAnimation(.appSpring) { pasteOpen = false }
        if titles.isEmpty {
            ToastCenter.shared.show("No he detectado títulos. Copia una lista numerada, una tabla o títulos en negrita.")
            return
        }
        if titles.count > 50 {
            ToastCenter.shared.show("Hay \(titles.count) títulos. Pega una lista de hasta 50.")
            return
        }
        pasteTitles = titles
    }

    // MARK: Contenido

    @ViewBuilder
    private var content: some View {
        switch status {
        case .hint:
            EmptyCard(emoji: "🍿", title: "Qué ver", sub: hintText)
        case .searching:
            GlassCard { QVSpinner(text: aiProgress.isEmpty ? "Buscando…" : aiProgress) }
        case .aiSteps:
            GlassCard { QVSpinner(text: aiProgress) }
        case .empty:
            EmptyCard(emoji: "🔎", title: "Sin resultados", sub: "Prueba con otro título o con menos palabras.")
        case .error:
            GlassCard {
                VStack(spacing: 6) {
                    Text("No se ha completado la búsqueda")
                        .font(.system(size: 19, design: .serif))
                        .foregroundStyle(Color.ink(scheme))
                    Text(aiError?.message ?? "No hay conexión con el buscador. Reintenta en un momento.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.ink2(scheme))
                        .multilineTextAlignment(.center)
                    if let e = aiError {
                        Text("\(e.stage) · \(e.code)")
                            .font(.caption2)
                            .foregroundStyle(Color.ink2(scheme).opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        case .results:
            resultsCard(items: results)
        case .pasteReady:
            pasteResults
        }
    }

    private var hintText: String {
        if mode == .title {
            return "Empieza a escribir para buscar. Admite faltas y aproximaciones 😉"
        }
        return store.geminiKey.isEmpty
            ? "Para buscar por descripción pon tu clave de Gemini en Ajustes ⚙️ (gratis en Google AI Studio)"
            : "Pídeme lo que quieras: \"la del alienígena pequeño que se hace amigo de un niño\", \"documentales de este año\", \"estrenos de esta semana en Netflix\"…"
    }

    private func resultsCard(items: [QVTitle]) -> some View {
        VStack(spacing: 14) {
            if !aiReply.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(aiReply)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.ink(scheme))
                        if !aiNote.isEmpty {
                            Text(aiNote)
                                .font(.caption)
                                .foregroundStyle(Color.ink2(scheme))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            GlassCard {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        Button {
                            selected = item
                        } label: {
                            TitleRow(item: item)
                        }
                        .buttonStyle(SilentButtonStyle())
                        if idx < items.count - 1 {
                            Divider().opacity(0.3)
                        }
                    }
                }
            }
        }
    }

    private var pasteResults: some View {
        VStack(spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tu lista de Gemini")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.ink(scheme))
                    Text(aiProgress)
                        .font(.caption)
                        .foregroundStyle(Color.ink2(scheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(aiSlots) { slot in
                if let item = slot.item {
                    GlassCard {
                        Button { selected = item } label: {
                            TitleRow(item: item)
                        }
                        .buttonStyle(SilentButtonStyle())
                    }
                } else {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(slot.candidate.title + (slot.candidate.year.map { " (\($0))" } ?? ""))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.ink(scheme))
                            Text(slot.missing
                                 ? "No he encontrado esta ficha en el catálogo de España."
                                 : "Comprobando ficha…")
                                .font(.caption)
                                .foregroundStyle(Color.ink2(scheme))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: Acciones

    private func resetToHint() {
        searchTask?.cancel()
        if status != .pasteReady || pasteTitles == nil {
            status = .hint
        }
        aiReply = ""
        aiNote = ""
        aiError = nil
    }

    private func debounceSearch() {
        guard mode == .title else { return }
        let v = query.trimmingCharacters(in: .whitespaces)
        searchTask?.cancel()
        if v.count < 2 { resetToHint(); return }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            doTitleSearch(v)
        }
    }

    private func submit() {
        let v = query.trimmingCharacters(in: .whitespaces)
        if mode == .ai {
            runAISearch()
        } else if v.count >= 2 {
            searchTask?.cancel()
            doTitleSearch(v)
        }
    }

    private func doTitleSearch(_ v: String) {
        status = .searching
        aiProgress = ""
        searchTask = Task {
            do {
                let list = try await JustWatch.search(v, first: 14)
                guard !Task.isCancelled else { return }
                results = list
                status = list.isEmpty ? .empty : .results
            } catch {
                guard !Task.isCancelled else { return }
                aiError = nil
                status = .error
            }
        }
    }

    private func runAISearch() {
        let v = query.trimmingCharacters(in: .whitespaces)
        if v.count < 3 { ToastCenter.shared.show("Descríbela un poco más"); return }
        let key = store.geminiKey.trimmingCharacters(in: .whitespaces)
        if key.isEmpty { ToastCenter.shared.show("Pon tu clave de Gemini en Ajustes ⚙️"); return }
        searchTask?.cancel()
        searchTask = Task {
            do {
                aiProgress = "1/3 · Gemini está preparando candidatos… ✨"
                status = .aiSteps
                let models = try await Gemini.availableModels(key: key)
                let proposed = try await Gemini.titles(for: v, key: key, models: models)
                var items: [QVTitle] = []
                for (i, c) in proposed.titles.enumerated() {
                    guard !Task.isCancelled else { return }
                    aiProgress = "2/3 · Comprobando géneros y notas: \(i + 1) de \(proposed.titles.count)…"
                    if let item = try await AIResolver.resolve(c), !items.contains(where: { $0.id == item.id }) {
                        items.append(item)
                    }
                    try? await Task.sleep(nanoseconds: 350_000_000)
                }
                guard !items.isEmpty else {
                    throw AIError("JUSTWATCH", "SIN_FICHAS", "No he podido encontrar las fichas de los títulos propuestos por Gemini en el catálogo de España.")
                }
                aiProgress = "3/3 · Gemini está revisando su lista con los géneros y notas reales…"
                let review = try await Gemini.review(desc: v, items: items, key: key, models: models)
                // Validaciones de la revisión, como en la web
                var seen = Set<String>()
                var previous = Double.infinity
                var selectedItems: [QVTitle] = []
                for id in review.ids {
                    guard let item = items.first(where: { $0.id == id }), !seen.contains(id) else {
                        throw AIError("REVISION", "TITULO", "Gemini ha seleccionado una ficha inválida o repetida. Reintenta.")
                    }
                    seen.insert(id)
                    if let genre = review.genre?.lowercased(), ["terror", "horror", "comedia", "comedy"].contains(genre) {
                        let required = genre.contains("terror") || genre.contains("horror") ? "terror|horror" : "comedia|comedy"
                        if !item.genres.contains(where: { $0.range(of: required, options: [.regularExpression, .caseInsensitive]) != nil }) {
                            throw AIError("REVISION", "GENERO", "Gemini no ha respetado el género pedido al revisar las fichas. No voy a mostrarte esa lista incorrecta. Reintenta.")
                        }
                    }
                    if let rt = review.requestedType, ["movie", "show"].contains(rt), item.type != rt {
                        throw AIError("REVISION", "TIPO", "Gemini ha mezclado películas y series al revisar tu consulta. Reintenta.")
                    }
                    if review.sortByImdb {
                        guard let rating = item.imdb, rating <= previous else {
                            throw AIError("REVISION", "ORDEN_IMDB", "Gemini no ha ordenado su lista por las notas reales de las fichas. No voy a mostrarte ese orden incorrecto. Reintenta.")
                        }
                        previous = rating
                    }
                    selectedItems.append(item)
                }
                guard !Task.isCancelled else { return }
                results = selectedItems
                aiReply = review.reply
                aiNote = "\(selectedItems.count) fichas · Lista final de Gemini revisada con datos del catálogo\nModelo: \(Gemini.lastModel)"
                status = .results
            } catch let e as AIError {
                guard !Task.isCancelled else { return }
                aiError = e
                status = .error
            } catch {
                guard !Task.isCancelled else { return }
                aiError = AIError("APP", "RED", "No se pudo completar la búsqueda. Comprueba tu conexión y reintenta.")
                status = .error
            }
        }
    }

    private func runPasteSearch(_ titles: [(title: String, year: Int?)]) {
        searchTask?.cancel()
        aiSlots = titles.map { AISlot(candidate: $0) }
        status = .pasteReady
        aiProgress = "Cargando 0 de \(titles.count) fichas…"
        searchTask = Task {
            var done = 0
            for i in aiSlots.indices {
                guard !Task.isCancelled else { return }
                do {
                    if let item = try await AIResolver.resolve(aiSlots[i].candidate) {
                        aiSlots[i].item = item
                    } else {
                        aiSlots[i].missing = true
                    }
                } catch {
                    aiSlots[i].missing = true
                }
                done += 1
                aiProgress = done < aiSlots.count
                    ? "Cargando \(done) de \(aiSlots.count) fichas…"
                    : "\(aiSlots.filter { $0.item != nil }.count) de \(aiSlots.count) fichas · Mismo orden que has pegado"
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }
    }
}
