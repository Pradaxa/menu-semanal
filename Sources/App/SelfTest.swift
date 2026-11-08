import Foundation

// MARK: - Pruebas automáticas de lógica (CI): se lanzan con -selftest y escriben SELFTEST-* por consola

enum SelfTest {
    static var failures: [String] = []

    static func check(_ name: String, _ condition: Bool) {
        if condition {
            print("SELFTEST-OK \(name)")
        } else {
            print("SELFTEST-FAIL \(name)")
            failures.append(name)
        }
    }

    static func run() -> Bool {
        let dishes = AppStore.seedDishes()
        let weekKey = Week.currentKey

        // 1. Generación completa
        let menu = Engine.generate(dishes: dishes, history: [], weekKey: weekKey, seed: 42, learning: nil)
        check("generate-14-slots", menu.slots.count == 14)
        check("generate-unique-slots", Set(menu.slots.map { "\($0.day)-\($0.meal)" }).count == menu.slots.count)

        // 2. Sin choque de categorías el mismo día
        let byId = Dictionary(grouping: dishes, by: { $0.id }).mapValues { $0[0] }
        var dayClash = false
        for day in 0..<7 {
            let lunch = menu.slots.first { $0.day == day && $0.meal == "comida" }
            let dinner = menu.slots.first { $0.day == day && $0.meal == "cena" }
            if let l = lunch, let d = dinner, !SpecialSlot.isSpecial(l.dishId), !SpecialSlot.isSpecial(d.dishId) {
                let lt = Set(byId[l.dishId]?.tags ?? [])
                if (byId[d.dishId]?.tags ?? []).contains(where: { lt.contains($0) }) { dayClash = true }
            }
        }
        check("generate-no-same-day-tag-clash", !dayClash)

        // 3. Máximo por semana
        var counts: [String: Int] = [:]
        for s in menu.slots where !SpecialSlot.isSpecial(s.dishId) { counts[s.dishId, default: 0] += 1 }
        let overMax = counts.contains { id, n in n > (byId[id]?.timesPerWeek ?? 0) }
        check("generate-respects-max", !overMax)

        // 4. Repeticiones a <= 2 días
        var days: [String: [Int]] = [:]
        for s in menu.slots where !SpecialSlot.isSpecial(s.dishId) { days[s.dishId, default: []].append(s.day) }
        var gapViolation = false
        for (_, ds) in days {
            let sorted = ds.sorted()
            for i in 1..<sorted.count where sorted[i] - sorted[i - 1] > 2 { gapViolation = true }
        }
        check("generate-gap-2-days", !gapViolation)

        // 5. Momento del plato
        let wrongMeal = menu.slots.contains { s in
            guard let d = byId[s.dishId] else { return false }
            return d.meal != "ambas" && d.meal != s.meal
        }
        check("generate-respects-meal", !wrongMeal)

        // 6. Sugerencias
        let sugg = Engine.suggestions(dishes: dishes, menu: menu, day: 2, meal: "cena", history: [], learning: nil)
        check("suggestions-max-14", sugg.count <= 14)
        check("suggestions-nonempty", !sugg.isEmpty)

        // 7. Compra: claves coherentes y secciones conocidas
        let items = Shopping.build(from: menu, dishes: dishes)
        check("shopping-nonempty", !items.isEmpty)
        check("shopping-unique-keys", Set(items.map { $0.key }).count == items.count)
        let sections = Set(Shopping.grouped(items).map { $0.0 })
        check("shopping-known-sections", sections.isSubset(of: Set(Shopping.sectionOrder)))
        check("shopping-pollo-en-carne", Shopping.section(for: "pechuga de pollo") == "Carne y pescado")
        check("shopping-lechuga-en-fruta", Shopping.section(for: "lechuga") == "Fruta y verdura")
        check("shopping-papel-en-hogar", Shopping.section(for: "papel higiénico") == "Hogar")

        // 8. Normalización
        check("norm-plural", TextNorm.ct("Patatas") == "patata")
        check("norm-accent", TextNorm.dt("Jamón") == "jamon")
        check("norm-ñ", TextNorm.ct("Champiñones") == "champiñon")

        // 9. Adivinador de ingredientes
        let g1 = IngredientGuesser.guess("Pollo asado")
        check("guess-pollo", g1.recognized && g1.tags.contains("pollo"))
        let g2 = IngredientGuesser.guess("Judías con pavo, pisto y huevo")
        check("guess-judias", g2.recognized && !g2.ingredients.isEmpty)

        // 10. Aprendizaje
        var learning = Learning()
        learning = Engine.learn(learning, confirmed: menu, orig: [], base: "fresh")
        check("learn-weeks", learning.weeks == 1)
        check("learn-kept", !learning.kept.isEmpty)
        var menu2 = menu
        let first = menu.slots[0]
        let other = dishes.first { $0.id != first.dishId && !SpecialSlot.isSpecial($0.id) }!
        menu2.slots[0] = Slot(day: first.day, meal: first.meal, dishId: other.id)
        learning = Engine.learn(learning, confirmed: menu2, orig: menu.slots, base: "confirmed")
        check("learn-removed", (learning.removed[first.dishId] ?? 0) >= 1)
        check("learn-added", (learning.added[other.id] ?? 0) >= 1)

        // 11. mealBias tras 3 cenas seguidas
        let d0 = dishes.first { $0.meal == "ambas" }!
        func hist(_ n: Int) -> [WeekMenu] {
            (0..<n).map { i in
                WeekMenu(weekKey: Week.add(-(i + 1), to: weekKey),
                         slots: [Slot(day: 0, meal: "cena", dishId: d0.id)],
                         createdAt: Engine.isoNow(), source: "reglas", confirmed: true)
            }
        }
        check("mealbias-3-cenas", Engine.mealBias(hist(3))[d0.id] == "cena")
        check("mealbias-2-cenas", Engine.mealBias(hist(2))[d0.id] == nil)

        // 12. Exportar/importar ida y vuelta
        let store = AppStore.shared
        if let data = try? store.exportData(), let text = String(data: data, encoding: .utf8) {
            check("export-format", text.contains("\"app\" : \"menus-semanales\"") || text.contains("\"app\":\"menus-semanales\"") || text.contains("menus-semanales"))
        } else {
            check("export-format", false)
        }

        // 13. Semilla: los 31 platos iniciales
        check("seed-31-dishes", dishes.count == 31)

        // 14. App Group: la suite compartida con el widget persiste de verdad.
        // Sin entitlement embebido (IPA sin firmar) UserDefaults(suiteName:) no
        // persiste y el widget se queda sin datos: esta prueba lo detecta.
        let suiteName = SharedMenuReader.suiteName
        check("appgroup-resolved", !suiteName.isEmpty)
        if let suite = UserDefaults(suiteName: suiteName) {
            let probeKey = "selftest.probe.v1"
            let probe = Data([1, 2, 3, 42])
            suite.set(probe, forKey: probeKey)
            let readBack = UserDefaults(suiteName: suiteName)?.data(forKey: probeKey)
            suite.removeObject(forKey: probeKey)
            check("appgroup-persists", readBack == probe)
        } else {
            check("appgroup-persists", false)
        }

        if failures.isEmpty {
            print("SELFTEST-PASS all")
        } else {
            print("SELFTEST-FAILURES \(failures.count): \(failures.joined(separator: ", "))")
        }
        return failures.isEmpty
    }
}
