import SwiftUI

// MARK: - Tab Platos

struct DishesView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var query = ""
    @State private var editing: Dish?
    @State private var adding = false

    private var filtered: [Dish] {
        let sorted = store.dishes.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        let q = TextNorm.dt(query)
        guard !q.isEmpty else { return sorted }
        return sorted.filter { TextNorm.dt($0.name).contains(q) }
    }

    /// Pie fijo dentro del área segura: fondo opaco para que no se lean platos detrás.
    private var searchPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.ink2(scheme))
            TextField("Buscar plato", text: $query)
                .foregroundStyle(Color.ink(scheme))
            if !query.isEmpty {
                Button { withAnimation(.appSpring) { query = "" } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.ink2(scheme).opacity(0.6))
                }
                .accessibilityLabel("Borrar búsqueda")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(scheme == .dark
                      ? Color(red: 0.12, green: 0.15, blue: 0.14)
                      : Color(red: 0.96, green: 0.97, blue: 0.94))
                .shadow(color: Color.black.opacity(scheme == .dark ? 0.3 : 0.08), radius: 8, x: 0, y: 3)
        )
        .overlay(Capsule().strokeBorder(Color.white.opacity(scheme == .dark ? 0.15 : 0.7), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(filtered) { dish in
                        Button { editing = dish } label: {
                            GlassCard {
                                HStack(spacing: 12) {
                                    Text(FunEmoji.dish(dish))
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(dish.name)
                                            .font(.headline)
                                            .foregroundStyle(Color.ink(scheme))
                                        Text(meta(dish))
                                            .font(.caption)
                                            .foregroundStyle(Color.ink2(scheme))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Color.ink2(scheme).opacity(0.5))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            searchPill
            }
            .background(AppBackground())
            .animation(.appSpring, value: filtered)
            .navigationTitle("Platos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                            .tint(Color.tealScheme(scheme))
                    }
                    .accessibilityLabel("Añadir plato")
                }
            }
            .sheet(item: $editing) { dish in
                DishEditorSheet(dish: dish, isNew: false)
                    .environmentObject(store)
            }
            .sheet(isPresented: $adding) {
                DishEditorSheet(dish: Dish(id: "", name: ""), isNew: true)
                    .environmentObject(store)
            }
            .onAppear {
                // Captura de CI: -screenshot plato-editor abre la hoja de nuevo plato
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-screenshot"), i + 1 < args.count, args[i + 1] == "plato-editor" {
                    adding = true
                }
                if let i = args.firstIndex(of: "-screenshot"), i + 1 < args.count, args[i + 1] == "platos-busqueda" {
                    query = "ensalada"
                }
            }
        }
    }

    private func meta(_ dish: Dish) -> String {
        var parts: [String] = []
        switch dish.meal {
        case "comida": parts.append("Solo comida")
        case "cena": parts.append("Solo cena")
        default: parts.append("Comida y cena")
        }
        if dish.timesPerWeek > 0 {
            parts.append("máx \(dish.timesPerWeek)/sem")
        } else {
            parts.append("nunca solo")
        }
        let seasons = dish.seasons.isEmpty ? ["all"] : dish.seasons
        if !seasons.contains("all") {
            parts.append(seasons.map { seasonLabel($0) }.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }
}

func seasonLabel(_ s: String) -> String {
    switch s {
    case "primavera": return "Primavera"
    case "verano": return "Verano"
    case "otono": return "Otoño"
    case "invierno": return "Invierno"
    default: return "Todo el año"
    }
}

// MARK: - Editor de plato

struct DishEditorSheet: View {
    let isNew: Bool
    @State var dish: Dish
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var newIngredient = ""
    @State private var working = false
    @State private var notice: String?
    @State private var confirmDelete = false

    static let allTags = ["pasta", "legumbre", "ensalada", "huevo", "pollo", "pescado", "marisco", "carne", "verdura", "arroz", "patata"]
    static let seasonOptions = ["all", "primavera", "verano", "otono", "invierno"]

    init(dish: Dish, isNew: Bool) {
        self.isNew = isNew
        _dish = State(initialValue: dish)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Nombre del plato", text: $dish.name)
                        .onChange(of: dish.name) { _, _ in autoGuessIfEmpty() }
                }
                Section("Momento") {
                    Picker("Momento", selection: $dish.meal) {
                        Text("Comida y cena").tag("ambas")
                        Text("Solo comida").tag("comida")
                        Text("Solo cena").tag("cena")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Estaciones") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                        ForEach(Self.seasonOptions, id: \.self) { s in
                            let selected = dish.seasons.contains(s) || (s == "all" && dish.seasons.isEmpty)
                            Button {
                                toggleSeason(s)
                            } label: {
                                Text(seasonLabel(s))
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(selected ? Color.tealScheme(scheme) : Color.tealScheme(scheme).opacity(0.15)))
                                    .foregroundStyle(selected ? .white : Color.ink(scheme))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("Veces por semana (máximo)") {
                    Stepper(value: $dish.timesPerWeek, in: 0...7) {
                        Text(dish.timesPerWeek == 0 ? "Solo si lo eliges tú" : "\(dish.timesPerWeek) vez\(dish.timesPerWeek == 1 ? "" : "ces")")
                    }
                }
                Section("Categorías") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                        ForEach(Self.allTags, id: \.self) { tag in
                            let selected = dish.tags.contains(tag)
                            Button {
                                if selected { dish.tags.removeAll { $0 == tag } } else { dish.tags.append(tag) }
                            } label: {
                                Text(tag)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(selected ? Color.tealScheme(scheme) : Color.tealScheme(scheme).opacity(0.15)))
                                    .foregroundStyle(selected ? .white : Color.ink(scheme))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    ForEach(dish.ingredients, id: \.self) { ing in
                        Text(ing)
                    }
                    .onDelete { dish.ingredients.remove(atOffsets: $0) }
                    HStack {
                        TextField("Añadir ingrediente", text: $newIngredient)
                            .onSubmit { addIngredient() }
                        Button(action: addIngredient) {
                            Image(systemName: "plus.circle.fill")
                                .tint(Color.tealScheme(scheme))
                        }
                        .disabled(newIngredient.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if !dish.ingredients.isEmpty {
                        Button("Quitar todos", role: .destructive) {
                            dish.ingredients = []
                        }
                    }
                    if !store.geminiKey.isEmpty {
                        Button {
                            fillWithAI()
                        } label: {
                            HStack {
                                if working {
                                    ProgressView().scaleEffect(0.8).tint(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(working ? "Preguntando a la IA…" : "Rellenar ingredientes con IA")
                            }
                        }
                        .buttonStyle(MagicButtonStyle())
                        .disabled(working || dish.name.trimmingCharacters(in: .whitespaces).isEmpty)
                        // Sin listRowBackground personalizado: con Color.clear, iOS 26
                        // saca la fila de la tarjeta de la sección y el borde inferior
                        // de la tarjeta queda cortado.
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    }
                } header: {
                    Text("Ingredientes")
                } footer: {
                    Text("Un plato sin ingredientes no añade nada a la compra (por ejemplo, comida ya preparada).")
                }
                if !isNew {
                    Section {
                        Button("Eliminar plato", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(isNew ? "Nuevo plato" : "Editar plato")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { save() }
                        .disabled(dish.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Aviso", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("Vale", role: .cancel) {}
            } message: {
                Text(notice ?? "")
            }
            .confirmationDialog("¿Eliminar «\(dish.name)»?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    store.deleteDish(dish.id)
                    dismiss()
                }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }

    private func autoGuessIfEmpty() {
        // Al crear: adivina categorías e ingredientes una vez que hay nombre
        guard isNew, !dish.name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let g = IngredientGuesser.guess(dish.name)
        if g.recognized {
            if dish.tags.isEmpty { dish.tags = g.tags }
            if dish.ingredients.isEmpty { dish.ingredients = g.ingredients }
        }
    }

    private func toggleSeason(_ s: String) {
        if s == "all" {
            dish.seasons = ["all"]
            return
        }
        dish.seasons.removeAll { $0 == "all" }
        if dish.seasons.contains(s) {
            dish.seasons.removeAll { $0 == s }
            if dish.seasons.isEmpty { dish.seasons = ["all"] }
        } else {
            dish.seasons.append(s)
        }
    }

    private func addIngredient() {
        let v = newIngredient.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        dish.ingredients.append(v)
        newIngredient = ""
    }

    private func fillWithAI() {
        working = true
        let key = store.geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = dish.name
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let ings = try Gemini.generateIngredients(apiKey: key, dishName: name)
                DispatchQueue.main.async {
                    dish.ingredients = ings
                    working = false
                }
            } catch {
                DispatchQueue.main.async {
                    notice = error.localizedDescription + " No se han cambiado tus ingredientes."
                    working = false
                }
            }
        }
    }

    private func save() {
        var d = dish
        d.name = d.name.trimmingCharacters(in: .whitespaces)
        if d.id.isEmpty {
            var base = AppStore.slug(d.name)
            var candidate = base
            var n = 2
            while store.dishes.contains(where: { $0.id == candidate }) {
                candidate = "\(base)-\(n)"
                n += 1
            }
            base = candidate
            d.id = base
        }
        if d.seasons.isEmpty { d.seasons = ["all"] }
        store.saveDish(d)
        dismiss()
    }
}
