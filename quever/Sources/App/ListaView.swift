import SwiftUI

// MARK: - Tab Mi lista: Pendientes (con filtros) y Vistas (por meses), gestos como la web

struct ListaView: View {
    @EnvironmentObject private var store: QVStore
    @Environment(\.colorScheme) private var scheme
    @State private var tab: Tab = .pendientes
    @State private var filter = "all"
    @State private var pendShown = 10
    @State private var vistasShown = 10
    @State private var selected: QVTitle?

    enum Tab { case pendientes, vistas }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    QVHeader()
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Button { withAnimation(.appSpring) { tab = .pendientes } } label: { Text("⏳ Pendientes") }
                                    .buttonStyle(ChipStyle(isOn: tab == .pendientes))
                                Button { withAnimation(.appSpring) { tab = .vistas } } label: { Text("✅ Vistas") }
                                    .buttonStyle(ChipStyle(isOn: tab == .vistas))
                                Spacer()
                            }
                            if tab == .pendientes && hasAnyPending {
                                filterChips
                            }
                        }
                    }
                    if tab == .pendientes { pendientesBody } else { vistasBody }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .sheet(item: $selected) { item in
                DetailView(item: item)
                    .environmentObject(store)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var hasAnyPending: Bool {
        !store.pendientes.isEmpty || !store.pendTemps.isEmpty || !store.lola.isEmpty
    }

    private var filterChips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], spacing: 6) {
            Button { filter = "all"; pendShown = 10 } label: { Text("Todas") }
                .buttonStyle(ChipStyle(isOn: filter == "all"))
            ForEach(Platforms.all, id: \.id) { p in
                Button { filter = p.id; pendShown = 10 } label: {
                    HStack(spacing: 5) {
                        PlatIcon(url: p.iconURL(), size: 14)
                        Text(p.name)
                    }
                }
                .buttonStyle(ChipStyle(isOn: filter == p.id))
            }
            Button { filter = "none"; pendShown = 10 } label: { Text("Ninguna") }
                .buttonStyle(ChipStyle(isOn: filter == "none"))
            Button { filter = "lola"; pendShown = 10 } label: { Text("❤️ Con Lola") }
                .buttonStyle(ChipStyle(isOn: filter == "lola"))
        }
    }

    // MARK: Pendientes

    private var pendientesItems: [QVTitle] {
        var items = Array(store.pendientes.values)
        for (k, v) in store.pendTemps where store.pendientes[k] == nil { items.append(v) }
        for (k, v) in store.lola where store.pendientes[k] == nil && store.pendTemps[k] == nil { items.append(v) }
        items.sort { a, b in
            let ta = store.pendientes[a.id]?.ts ?? store.pendTemps[a.id]?.ts ?? store.lola[a.id]?.ts ?? 0
            let tb = store.pendientes[b.id]?.ts ?? store.pendTemps[b.id]?.ts ?? store.lola[b.id]?.ts ?? 0
            return ta > tb
        }
        return items
    }

    private var pendientesFiltered: [QVTitle] {
        pendientesItems.filter { it in
            switch filter {
            case "all": return !store.isLola(it.id)
            case "lola": return store.isLola(it.id)
            case "none": return it.minePlats.isEmpty
            default: return it.minePlats.contains { $0.id == filter }
            }
        }
    }

    @ViewBuilder
    private var pendientesBody: some View {
        if pendientesItems.isEmpty {
            EmptyCard(emoji: "⏳", title: "Nada pendiente",
                      sub: "Cuando algo te interese, márcalo con ⏳ Pendiente en su ficha y aparecerá aquí, lo más reciente primero.")
        } else if pendientesFiltered.isEmpty {
            GlassCard {
                Text("Nada aquí con ese filtro")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.ink2(scheme))
                    .frame(maxWidth: .infinity)
            }
        } else {
            let list = pendientesFiltered
            GlassCard {
                LazyVStack(spacing: 0) {
                    ForEach(Array(list.prefix(pendShown)), id: \.id) { item in
                        Button { selected = item } label: {
                            TitleRow(item: item)
                                .padding(.horizontal, 0)
                        }
                        .buttonStyle(SilentButtonStyle())
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                store.removeEverywhere(item.id)
                                ToastCenter.shared.show("Quitada de pendientes")
                            } label: {
                                Label("Quitar", systemImage: "trash")
                            }
                            Button {
                                let msg = store.mark(.vista, item)
                                ToastCenter.shared.show(msg)
                            } label: {
                                Label("Vista", systemImage: "checkmark")
                            }
                            .tint(Color.accentScheme(scheme))
                        }
                        if item.id != list.prefix(pendShown).last?.id { Divider().opacity(0.3) }
                    }
                }
            }
            if list.count > pendShown {
                Button {
                    pendShown += 10
                } label: {
                    Text("Cargar más (\(list.count - pendShown))")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    // MARK: Vistas (por meses)

    private static let meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio",
                                "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    private var vistasSorted: [QVTitle] {
        store.vistas.values.sorted { ($0.watchedAt ?? 0) > ($1.watchedAt ?? 0) }
    }

    @ViewBuilder
    private var vistasBody: some View {
        if vistasSorted.isEmpty {
            EmptyCard(emoji: "✅", title: "Nada visto todavía",
                      sub: "Cuando marques algo como visto aparecerá aquí, ordenado por meses.")
        } else {
            let items = Array(vistasSorted.prefix(vistasShown))
            let groups = groupByMonth(items)
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                GlassCard {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("📅 \(group.name)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.ink(scheme))
                            Text("\(group.items.count)")
                                .font(.caption)
                                .foregroundStyle(Color.ink2(scheme))
                        }
                        .padding(.bottom, 8)
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, item in
                            Button { selected = item } label: {
                                TitleRow(item: item)
                            }
                            .buttonStyle(SilentButtonStyle())
                            if idx < group.items.count - 1 { Divider().opacity(0.3) }
                        }
                    }
                }
            }
            if vistasSorted.count > vistasShown {
                Button {
                    vistasShown += 10
                } label: {
                    Text("Cargar más (\(vistasSorted.count - vistasShown))")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func groupByMonth(_ items: [QVTitle]) -> [(name: String, items: [QVTitle])] {
        var groups: [(String, [QVTitle])] = []
        for item in items {
            let name: String
            if let ts = item.watchedAt {
                let d = Date(timeIntervalSince1970: ts / 1000)
                let cal = Calendar.current
                name = "\(Self.meses[cal.component(.month, from: d) - 1]) \(cal.component(.year, from: d))"
            } else {
                name = "Sin fecha"
            }
            if let i = groups.firstIndex(where: { $0.0 == name }) {
                groups[i].1.append(item)
            } else {
                groups.append((name, [item]))
            }
        }
        return groups
    }
}
