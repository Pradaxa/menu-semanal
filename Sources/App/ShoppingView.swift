import SwiftUI

// MARK: - Tab Compra

struct ShoppingView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var newItem = ""

    private var weekKey: String { store.weekSel }
    private var menu: WeekMenu { store.resolved(weekKey).menu }
    private var week: ShoppingWeek { store.shoppingWeek(weekKey) }

    private var items: [ShoppingItem] {
        Shopping.build(from: menu, dishes: store.dishes)
    }

    private var grouped: [(String, [ShoppingItem])] {
        Shopping.grouped(items)
    }

    private func isStruck(_ item: ShoppingItem) -> Bool {
        let state = week.states[item.key] ?? item.variants.compactMap { week.states[$0] }.first
        return state == "bought" || state == "home"
    }

    private var totalCount: Int { items.count + week.extras.count }
    private var doneCount: Int {
        items.filter { isStruck($0) }.count + week.extras.filter { week.states[$0.id] == "bought" }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    weekNavigator
                    if totalCount > 0 {
                        progressCard
                    }
                    if grouped.isEmpty && week.extras.isEmpty {
                        GlassCard {
                            VStack(spacing: 8) {
                                Text("🛒")
                                    .font(.largeTitle)
                                Text("Nada que comprar")
                                    .font(.headline)
                                Text("Genera o escribe el menú de esta semana y aquí aparecerá la compra.")
                                    .font(.callout)
                                    .foregroundStyle(Color.ink2(scheme))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(grouped, id: \.0) { section, sectionItems in
                        sectionCard(section, sectionItems)
                    }
                    extrasCard
                    addCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(.appSpring, value: week.states)
                .animation(.appSpring, value: grouped.map { $0.0 })
            }
            .background(AppBackground())
            .navigationTitle("Compra")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var weekNavigator: some View {
        HStack {
            Button { store.weekSel = Week.add(-1, to: weekKey) } label: {
                Image(systemName: "chevron.left.circle.fill").font(.title2)
            }
            Spacer()
            Text(Week.label(for: weekKey)).font(.headline)
            Spacer()
            Button { store.weekSel = Week.add(1, to: weekKey) } label: {
                Image(systemName: "chevron.right.circle.fill").font(.title2)
            }
        }
        .tint(Color.tealScheme(scheme))
        .padding(.horizontal, 8)
    }

    private var progressCard: some View {
        let pct = totalCount > 0 ? Double(doneCount) / Double(totalCount) : 0
        return GlassCard {
            VStack(spacing: 8) {
                HStack {
                    Text("\(doneCount) de \(totalCount)")
                        .font(.headline)
                    Spacer()
                    Text(pct >= 1 ? "¡Lista! 🎉" : "\(Int(pct * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(pct >= 1 ? Color.tealScheme(scheme) : Color.ink2(scheme))
                }
                ProgressView(value: pct)
                    .tint(Color.tealScheme(scheme))
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func sectionCard(_ section: String, _ sectionItems: [ShoppingItem]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(FunEmoji.shoppingSection(section)) \(section)")
                        .font(.caption.bold())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Color.ink2(scheme))
                    Spacer()
                    Button {
                        toggleSection(sectionItems)
                    } label: {
                        Image(systemName: sectionItems.allSatisfy { isStruck($0) } ? "checkmark.circle.fill" : "checkmark.circle")
                            .foregroundStyle(Color.tealScheme(scheme))
                    }
                    .accessibilityLabel("Tachar toda la sección")
                }
                ForEach(sectionItems) { item in
                    Button { toggle(item) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isStruck(item) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isStruck(item) ? Color.tealScheme(scheme) : Color.ink2(scheme).opacity(0.4))
                            Text(item.label)
                                .strikethrough(isStruck(item))
                                .foregroundStyle(isStruck(item) ? Color.ink2(scheme) : Color.ink(scheme))
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var extrasCard: some View {
        let mine = week.extras
        return Group {
            if !mine.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("✏️ Añadidos por ti")
                            .font(.caption.bold())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(Color.ink2(scheme))
                        ForEach(mine) { extra in
                            let struck = week.states[extra.id] == "bought"
                            HStack(spacing: 10) {
                                Button { toggleExtra(extra) } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: struck ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(struck ? Color.tealScheme(scheme) : Color.ink2(scheme).opacity(0.4))
                                        Text(extra.name)
                                            .strikethrough(struck)
                                            .foregroundStyle(struck ? Color.ink2(scheme) : Color.ink(scheme))
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Button {
                                    var w = week
                                    w.extras.removeAll { $0.id == extra.id }
                                    w.states.removeValue(forKey: extra.id)
                                    store.setShoppingWeek(w, weekKey)
                                } label: {
                                    Image(systemName: "xmark.circle")
                                        .foregroundStyle(Color.ink2(scheme).opacity(0.5))
                                }
                                .accessibilityLabel("Quitar \(extra.name)")
                            }
                        }
                    }
                }
            }
        }
    }

    private var addCard: some View {
        GlassCard {
            HStack {
                TextField("Añadir producto…", text: $newItem)
                    .onSubmit(addItem)
                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill").font(.title2)
                        .tint(Color.tealScheme(scheme))
                }
                .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Añadir producto")
            }
        }
    }

    private func toggle(_ item: ShoppingItem) {
        var w = week
        let newState = isStruck(item) ? nil : "bought"
        w.states[item.key] = newState
        for v in item.variants { w.states[v] = newState }
        store.setShoppingWeek(w, weekKey)
    }

    private func toggleExtra(_ extra: ExtraItem) {
        var w = week
        w.states[extra.id] = w.states[extra.id] == "bought" ? nil : "bought"
        store.setShoppingWeek(w, weekKey)
    }

    private func toggleSection(_ sectionItems: [ShoppingItem]) {
        var w = week
        let allStruck = sectionItems.allSatisfy { isStruck($0) }
        for item in sectionItems {
            let newState = allStruck ? nil : "bought"
            w.states[item.key] = newState
            for v in item.variants { w.states[v] = newState }
        }
        store.setShoppingWeek(w, weekKey)
    }

    private func addItem() {
        let v = newItem.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        var w = week
        w.extras.append(ExtraItem(id: "x-\(UUID().uuidString.prefix(8))", name: v))
        store.setShoppingWeek(w, weekKey)
        newItem = ""
    }
}
