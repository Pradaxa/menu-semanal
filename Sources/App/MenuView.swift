import SwiftUI

// MARK: - Tab Menú

struct MenuView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var slotPicker: SlotTarget?
    @State private var generating = false
    @State private var notice: String?

    struct SlotTarget: Identifiable {
        var day: Int
        var meal: String
        var id: String { "\(day)-\(meal)" }
    }

    private var weekKey: String { store.weekSel }
    private var resolved: AppStore.ResolvedMenu { store.resolved(weekKey) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    weekNavigator
                    actionButtons
                    if resolved.menu.slots.isEmpty && !resolved.confirmed {
                        emptyHero
                    }
                    ForEach(0..<7, id: \.self) { day in
                        dayCard(day)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(.appSpring, value: resolved.menu.slots)
                .animation(.appSpring, value: resolved.confirmed)
            }
            .background(AppBackground())
            .navigationTitle("Menú")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $slotPicker) { target in
                SlotPickerSheet(day: target.day, meal: target.meal, weekKey: weekKey)
                    .environmentObject(store)
            }
            .alert("Aviso", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("Vale", role: .cancel) {}
            } message: {
                Text(notice ?? "")
            }
        }
    }

    private var weekNavigator: some View {
        HStack {
            Button { store.weekSel = Week.add(-1, to: weekKey) } label: {
                Image(systemName: "chevron.left.circle.fill").font(.title2)
            }
            .accessibilityLabel("Semana anterior")
            Spacer()
            VStack(spacing: 2) {
                Text(Week.label(for: weekKey))
                    .font(.headline)
                if resolved.confirmed {
                    Label("Confirmado", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(Color.tealScheme(scheme))
                }
            }
            Spacer()
            Button { store.weekSel = Week.add(1, to: weekKey) } label: {
                Image(systemName: "chevron.right.circle.fill").font(.title2)
            }
            .accessibilityLabel("Semana siguiente")
        }
        .tint(Color.tealScheme(scheme))
        .padding(.horizontal, 8)
    }

    private var emptySlots: Int {
        14 - resolved.menu.slots.count
    }

    private var emptyHero: some View {
        GlassCard {
            VStack(spacing: 8) {
                Text("🤔")
                    .font(.largeTitle)
                Text("¿Qué comemos esta semana?")
                    .font(.headline)
                Text("Pulsa Generar menú y te propongo una semana con tus reglas. Luego la dejas a tu gusto.")
                    .font(.callout)
                    .foregroundStyle(Color.ink2(scheme))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    @ViewBuilder
    private var actionButtons: some View {
        if resolved.confirmed {
            Button {
                store.reopen(weekKey)
            } label: {
                Label("Editar este menú", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.tealScheme(scheme))
        } else {
            HStack(spacing: 10) {
                if store.geminiKey.isEmpty {
                    Button {
                        runGenerate(fillOnly: false)
                    } label: {
                        Label(resolved.menu.slots.isEmpty ? "Generar menú" : "Regenerar", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.tealScheme(scheme))
                    .disabled(generating || store.dishes.isEmpty)
                } else {
                    Button {
                        runGenerate(fillOnly: false)
                    } label: {
                        Label(resolved.menu.slots.isEmpty ? "Generar menú con IA" : "Regenerar con IA", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(MagicButtonStyle())
                    .disabled(generating || store.dishes.isEmpty)
                }

                if !resolved.menu.slots.isEmpty && emptySlots > 0 {
                    if store.geminiKey.isEmpty {
                        Button {
                            runGenerate(fillOnly: true)
                        } label: {
                            Label("Completar huecos", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.tealScheme(scheme))
                        .disabled(generating || store.dishes.isEmpty)
                    } else {
                        Button {
                            runGenerate(fillOnly: true)
                        } label: {
                            Label("Completar con IA", systemImage: "sparkles")
                        }
                        .buttonStyle(MagicButtonStyle())
                        .disabled(generating || store.dishes.isEmpty)
                    }
                }
            }
            if !resolved.menu.slots.isEmpty {
                Button {
                    store.confirm(weekKey)
                } label: {
                    Label("Confirmar menú", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.23, green: 0.55, blue: 0.35))
            }
        }
        if generating {
            HStack(spacing: 8) {
                ProgressView()
                Text(store.geminiKey.isEmpty ? "Generando con tus reglas…" : "Pensando con IA…")
                    .font(.callout)
                    .foregroundStyle(Color.ink2(scheme))
            }
        }
    }

    private func runGenerate(fillOnly: Bool) {
        generating = true
        store.generate(fillOnly: fillOnly, in: weekKey, useAI: !store.geminiKey.isEmpty) { warning in
            generating = false
            if let warning = warning { notice = warning }
        }
    }

    private func dayCard(_ day: Int) -> some View {
        let date = Week.dayDate(weekKey, day)
        let dayNum = Week.calendar.component(.day, from: date)
        let isToday = weekKey == Week.currentKey && day == Week.todayIndex()
        return GlassCard {
            VStack(spacing: 4) {
                HStack {
                    Text("\(Week.dayNames[day]) \(dayNum)")
                        .font(.headline)
                        .foregroundStyle(isToday ? Color.tealScheme(scheme) : Color.ink(scheme))
                    if isToday {
                        Text("Hoy")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.tealScheme(scheme).opacity(0.18)))
                            .foregroundStyle(Color.tealScheme(scheme))
                    }
                    Spacer()
                }
                slotRow(day: day, meal: "comida", label: "Comida", dot: .orange)
                slotRow(day: day, meal: "cena", label: "Cena", dot: Color(red: 0.357, green: 0.553, blue: 0.937))
            }
        }
    }

    private func slotRow(day: Int, meal: String, label: String, dot: Color) -> some View {
        let slot = resolved.menu.slots.first { $0.day == day && $0.meal == meal }
        return Button {
            slotPicker = SlotTarget(day: day, meal: meal)
        } label: {
            HStack(spacing: 10) {
                Circle().fill(dot).frame(width: 9, height: 9)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.ink2(scheme))
                    .frame(width: 52, alignment: .leading)
                if let slot = slot {
                    Text(store.slotTitle(slot.dishId))
                        .font(.body)
                        .foregroundStyle(Color.ink(scheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("Sin plato")
                        .font(.body)
                        .foregroundStyle(Color.ink2(scheme).opacity(0.6))
                        .italic()
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.ink2(scheme).opacity(0.5))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hoja de elección de plato

struct SlotPickerSheet: View {
    let day: Int
    let meal: String
    let weekKey: String

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var query = ""

    private var menu: WeekMenu { store.resolved(weekKey).menu }
    private var currentSlot: Slot? { menu.slots.first { $0.day == day && $0.meal == meal } }

    private var suggestions: [Dish] {
        Engine.suggestions(dishes: store.dishes, menu: menu, day: day, meal: meal,
                           history: store.history, learning: store.learning)
    }

    private var filtered: [Dish] {
        let sorted = store.dishes.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        let q = TextNorm.dt(query)
        guard !q.isEmpty else { return sorted }
        return sorted.filter { TextNorm.dt($0.name).contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        specialButton(SpecialSlot.fuera, "🍽️", "Comer fuera")
                        specialButton(SpecialSlot.sobras, "🥡", "Sobras")
                        specialButton(SpecialSlot.vacio, "✕", "Vacío")
                    }
                }
                if query.isEmpty && !suggestions.isEmpty {
                    Section("✨ Sugerencias para ti") {
                        ForEach(suggestions) { dish in
                            dishRow(dish)
                                .listRowBackground(Color.tealScheme(scheme).opacity(scheme == .dark ? 0.22 : 0.14))
                        }
                    }
                }
                Section(query.isEmpty ? "Todos los platos" : "Resultados") {
                    ForEach(filtered) { dish in dishRow(dish) }
                }
            }
            .searchable(text: $query, prompt: "Buscar plato")
            .navigationTitle("\(Week.dayNames[day]) · \(meal == "comida" ? "Comida" : "Cena")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if currentSlot != nil {
                        Button("Quitar", role: .destructive) {
                            store.setSlot(nil, day: day, meal: meal, in: weekKey)
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private func specialButton(_ id: String, _ emoji: String, _ label: String) -> some View {
        Button {
            store.setSlot(id, day: day, meal: meal, in: weekKey)
            dismiss()
        } label: {
            VStack(spacing: 4) {
                Text(emoji).font(.title2)
                Text(label).font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(Color.tealScheme(scheme))
    }

    private func dishRow(_ dish: Dish) -> some View {
        Button {
            store.setSlot(dish.id, day: day, meal: meal, in: weekKey)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Text(FunEmoji.dish(dish))
                VStack(alignment: .leading, spacing: 2) {
                    Text(dish.name).foregroundStyle(Color.ink(scheme))
                    if !dish.tags.isEmpty {
                        Text(dish.tags.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(Color.ink2(scheme))
                    }
                }
            }
        }
    }
}
