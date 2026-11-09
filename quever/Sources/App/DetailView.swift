import SwiftUI

// MARK: - Ficha completa (hoja de detalle): póster, plataformas, temporadas, acciones

struct DetailView: View {
    @State var item: QVTitle
    @EnvironmentObject private var store: QVStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var selTemp = 0
    @State private var synopsisExpanded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    top
                    platsSection
                    actions
                    if item.isShow { seasonsSection }
                    lolaAction
                    fields
                }
                .padding(16)
            }
            .background(AppBackground())
            .navigationTitle(item.title.isEmpty ? "Cargando…" : item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.ink2(scheme))
                    }
                }
            }
        }
        .onAppear { refreshDetail() }
    }

    // MARK: Cabecera: póster grande + título + meta + nota

    private var top: some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if !item.posterBig.isEmpty, let url = URL(string: item.posterBig) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: posterPlaceholder
                        }
                    }
                } else {
                    posterPlaceholder
                }
            }
            .frame(width: 110, height: 165)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.ink(scheme))
                Text(metaLine)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.ink2(scheme))
                if let rating = item.imdbText {
                    IMDbBadge(value: rating, big: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.ink2(scheme).opacity(0.12))
            Text("🎬").font(.system(size: 34))
        }
    }

    private var metaLine: String {
        let head = item.isUpcoming ? "Estreno: \(item.releaseFormatted)" : (item.year.map(String.init) ?? "")
        return ([head, item.isShow ? "Serie" : "Película"] + item.genres.prefix(3))
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    // MARK: Dónde verla (fija mientras cambian las temporadas)

    private var platsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dónde verla\(selTemp > 0 ? " · temporada \(selTemp)" : "")")
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.ink2(scheme))
                let plats = currentPlats
                if plats.isEmpty {
                    Text(selTemp > 0 && item.seasonsList.first(where: { $0.num == selTemp }) == nil
                         ? "Sin datos de esta temporada" : "Sin suscripción ahora")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.ink2(scheme).opacity(0.8))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(plats, id: \.id) { p in
                            HStack(spacing: 6) {
                                PlatIcon(url: p.icon, size: 20)
                                Text(p.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.ink(scheme))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(scheme == .dark ? Color.white.opacity(0.07) : Color.white.opacity(0.6))
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.appSpring, value: selTemp)
        }
    }

    private var currentPlats: [PlatRef] {
        if item.isShow && selTemp > 0 {
            if let s = item.seasonsList.first(where: { $0.num == selTemp }) {
                return JustWatch.dedupePlats(s.plats)
            }
            return []
        }
        return JustWatch.dedupePlats(item.plats)
    }

    // MARK: Acciones

    private var inVistas: Bool { store.vistas[item.id] != nil }
    private var inPendientes: Bool { store.pendientes[item.id] != nil }
    private var inLola: Bool { store.lola[item.id] != nil }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                ToastCenter.shared.show(store.mark(.vista, refreshedItem))
            } label: {
                Text(inVistas ? "✓ Vista" : "Marcar vista")
            }
            .buttonStyle(PrimaryButtonStyle(prominent: inVistas))

            Button {
                if selTemp > 0 && item.isShow {
                    ToastCenter.shared.show(store.setTemp(refreshedItem, selTemp, kind: "pend"))
                } else {
                    ToastCenter.shared.show(store.mark(.pendiente, refreshedItem))
                }
            } label: {
                Text(inPendientes ? "✓ Pendiente de ver" : "Marcar como pendiente")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .buttonStyle(PrimaryButtonStyle(prominent: inPendientes))
        }
    }

    private var lolaAction: some View {
        Button {
            if selTemp > 0 && item.isShow {
                ToastCenter.shared.show(store.setTemp(refreshedItem, selTemp, kind: "lola"))
            } else {
                ToastCenter.shared.show(store.mark(.lola, refreshedItem))
            }
        } label: {
            Text(inLola ? "✓ Con Lola ❤️" : "Ver con Lola ❤️")
        }
        .buttonStyle(PrimaryButtonStyle(prominent: inLola))
    }

    /// Versión más fresca de la ficha: la guardada si existe (con su estado), si no la actual.
    private var refreshedItem: QVTitle {
        var merged = item
        let stored = store.stored(item.id)
        merged.watchedAt = stored?.watchedAt
        merged.temps = stored?.temps
        merged.tempsLola = stored?.tempsLola
        return merged
    }

    // MARK: Temporadas (toca una para ver dónde está; otra vez para desmarcar)

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if item.seasonCount > 0 {
                Text("Temporadas · toca una para ver dónde está")
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.ink2(scheme))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], spacing: 6) {
                    ForEach(1...item.seasonCount, id: \.self) { t in
                        let on = store.pendTemps[item.id]?.temps?.contains(t) ?? false
                        let lola = store.pendTemps[item.id]?.tempsLola?.contains(t) ?? false
                        Button {
                            withAnimation(.appSpring) {
                                selTemp = (selTemp == t) ? 0 : t
                            }
                        } label: {
                            Text("T\(t)\(lola ? " ❤️" : "")")
                        }
                        .buttonStyle(ChipStyle(isOn: on || selTemp == t))
                    }
                }
            }
        }
    }

    // MARK: Dirección, reparto, sinopsis

    @ViewBuilder
    private var fields: some View {
        if !item.director.isEmpty {
            field("Dirección", item.director[0])
        }
        if !item.actors.isEmpty {
            field("Reparto principal", item.actors.joined(separator: ", "))
        }
        if !item.synopsis.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sinopsis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.ink(scheme))
                Text(item.synopsis)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.ink2(scheme))
                    .lineLimit(synopsisExpanded ? nil : 4)
                Button {
                    withAnimation(.appSpring) { synopsisExpanded.toggle() }
                } label: {
                    Text(synopsisExpanded ? "Ver menos" : "Ver más")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentScheme(scheme))
                }
                .buttonStyle(SilentButtonStyle())
            }
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.ink(scheme))
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Color.ink2(scheme))
        }
    }

    // MARK: Carga del detalle completo + nota IMDb

    private func refreshDetail() {
        // Si ya tenemos una versión guardada con más datos, úsala de base
        if let stored = store.stored(item.id), stored.detailFetched && !item.detailFetched {
            item = stored
        }
        guard !item.detailFetched else { loadRating(); return }
        Task {
            if let full = try? await JustWatch.detail(item.id) {
                var merged = full
                let stored = store.stored(item.id)
                merged.watchedAt = stored?.watchedAt
                merged.ts = stored?.ts
                merged.temps = stored?.temps
                merged.tempsLola = stored?.tempsLola
                if merged.imdb == nil { merged.imdb = item.imdb }
                item = merged
                store.backfill(merged)
            }
            loadRating()
        }
    }

    private func loadRating() {
        guard item.imdb == nil else { return }
        Task {
            if let v = await Ratings.rating(for: item, omdbKey: store.omdbKey) {
                item.imdb = v
            }
        }
    }
}
