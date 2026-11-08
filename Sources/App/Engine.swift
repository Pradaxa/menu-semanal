import Foundation

// MARK: - RNG con semilla (mulberry32, igual que la web app)

struct SeededRNG {
    private var a: Int32

    init(seed: Int) {
        a = Int32(truncatingIfNeeded: seed)
    }

    mutating func next() -> Double {
        a = a &+ Int32(bitPattern: 1831565813)
        let u = UInt32(bitPattern: a)
        var t = Int32(bitPattern: (u ^ (u >> 15)) &* UInt32(bitPattern: 1 | a))
        let ut = UInt32(bitPattern: t)
        let t2 = Int32(bitPattern: ut &+ ((ut ^ (ut >> 7)) &* UInt32(bitPattern: 61 | t)))
        t = t2 ^ t
        let uf = UInt32(bitPattern: t)
        let res = uf ^ (uf >> 14)
        return Double(res) / 4294967296.0
    }
}

enum Engine {

    // MARK: utilidades

    static func isoNow() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: Date())
    }

    /// Estación de una semana a partir de su lunes
    static func season(_ weekKey: String) -> String { Week.season(of: weekKey) }

    static func seasonsOf(_ dish: Dish) -> [String] {
        dish.seasons.isEmpty ? ["all"] : dish.seasons
    }

    /// Su: platos elegibles por estación y veces/semana > 0
    static func eligible(_ dishes: [Dish], _ weekKey: String) -> [Dish] {
        let s = Week.season(of: weekKey)
        return dishes.filter { d in
            d.timesPerWeek > 0 && (seasonsOf(d).contains("all") || seasonsOf(d).contains(s))
        }
    }

    /// mealBiasMap: si un plato "ambas" se ha puesto 3 veces seguidas en cena, solo cena (y viceversa)
    static func mealBias(_ history: [WeekMenu]) -> [String: String] {
        var seq: [String: [String]] = [:]
        for menu in history.sorted(by: { $0.weekKey > $1.weekKey }) {
            let slots = menu.slots
                .filter { !SpecialSlot.isSpecial($0.dishId) }
                .sorted { a, b in
                    if a.day != b.day { return a.day > b.day }
                    return a.meal == "cena" && b.meal != "cena"
                }
            for s in slots { seq[s.dishId, default: []].append(s.meal) }
        }
        var bias: [String: String] = [:]
        for (id, meals) in seq where meals.count >= 3 {
            let first = meals[0]
            var i = 0
            while i < meals.count && meals[i] == first { i += 1 }
            if i >= 3 { bias[id] = first }
        }
        return bias
    }

    /// gc: penaliza platos de las últimas 3 semanas
    static func recencyWeight(_ dishId: String, _ history: [WeekMenu], _ weekKey: String) -> Double {
        if SpecialSlot.isSpecial(dishId) { return 1 }
        let recent = history.filter { $0.weekKey != weekKey }.sorted { $0.weekKey > $1.weekKey }
        let weights = [0.05, 0.3, 0.6]
        for (i, menu) in recent.prefix(3).enumerated() {
            if menu.slots.contains(where: { $0.dishId == dishId }) { return weights[i] }
        }
        return 1
    }

    /// pc: peso por aprendizaje (kept/added/removed)
    static func learningWeight(_ dishId: String, _ learning: Learning?) -> Double {
        guard let l = learning else { return 1 }
        let e = 0.12 * Double(l.kept[dishId] ?? 0)
            + 0.35 * Double(l.added[dishId] ?? 0)
            - 0.4 * Double(l.removed[dishId] ?? 0)
        return exp(max(-1.4, min(1.4, e)))
    }

    static func pairKey(_ a: String, _ b: String) -> String {
        a < b ? "\(a)|\(b)" : "\(b)|\(a)"
    }

    /// vc: bonus por parejas comida-cena que suele conservar
    static func pairWeight(_ a: String?, _ b: String, _ learning: Learning?) -> Double {
        guard let l = learning, let a = a, !a.isEmpty else { return 1 }
        return 1 + 0.3 * Double(min(3, l.pairs[pairKey(a, b)] ?? 0))
    }

    /// yc: el plato ya aparece y alguna aparición está a <= 2 días de `day`
    static func gapOK(_ days: [String: [Int]], _ dishId: String, _ day: Int) -> Bool {
        guard let existing = days[dishId], !existing.isEmpty else { return true }
        return existing.contains { abs($0 - day) <= 2 }
    }

    /// dc: elección ponderada
    static func weightedPick<T>(_ items: [T], _ weights: [Double], _ rng: inout SeededRNG) -> T {
        let total = weights.reduce(0, +)
        var r = rng.next() * total
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return items[i] }
        }
        return items[items.count - 1]
    }

    /// j1: pesos para el fallback greedy
    static func greedyWeights(_ candidates: [Dish], _ dishCount: [String: Int], _ tagCount: [String: Int],
                              _ history: [WeekMenu], _ weekKey: String, _ relaxed: Bool,
                              _ learning: Learning?, _ prevDishId: String?) -> [Double] {
        candidates.map { d in
            var s = recencyWeight(d.id, history, weekKey) * learningWeight(d.id, learning) * pairWeight(prevDishId, d.id, learning)
            s *= 1 / (1 + Double(tagCount[d.tags.first ?? ""] ?? 0) * 0.5)
            s *= 1 / (1 + Double(dishCount[d.id] ?? 0))
            if relaxed { s *= 0.3 }
            return s
        }
    }

    /// R1: elige el multiset de platos de la semana
    static func pickPool(_ candidates: [Dish], _ count: Int, _ history: [WeekMenu], _ weekKey: String,
                         _ learning: Learning?, _ rng: inout SeededRNG) -> [Dish] {
        var dishCount: [String: Int] = [:]
        var tagCount: [String: Int] = [:]
        var pool: [Dish] = []
        while pool.count < count {
            let avail = candidates.filter { (dishCount[$0.id] ?? 0) < $0.timesPerWeek }
            if avail.isEmpty { break }
            let weights = avail.map { d -> Double in
                var p = recencyWeight(d.id, history, weekKey) * learningWeight(d.id, learning)
                p *= 1 / (1 + Double(tagCount[d.tags.first ?? ""] ?? 0) * 0.5)
                p *= 1 / (1 + Double(dishCount[d.id] ?? 0))
                return p
            }
            let pick = weightedPick(avail, weights, &rng)
            pool.append(pick)
            dishCount[pick.id, default: 0] += 1
            for t in pick.tags { tagCount[t, default: 0] += 1 }
        }
        return pool
    }

    /// G1: coloca el pool en los 14 turnos con backtracking
    static func arrange(_ pool: [Dish], _ learning: Learning?, _ rng: inout SeededRNG,
                        _ fixed: [Slot], _ bias: [String: String]) -> [Slot]? {
        var byId: [String: Dish] = [:]
        for d in pool { byId[d.id] = d }
        var remaining: [String: Int] = [:]
        for d in pool { remaining[d.id, default: 0] += 1 }

        var order: [(day: Int, meal: String)] = []
        for day in 0..<7 {
            order.append((day, "comida"))
            order.append((day, "cena"))
        }
        var fixedAt: [Int: Slot] = [:]
        for (idx, slot) in order.enumerated() {
            if let f = fixed.first(where: { $0.day == slot.day && $0.meal == slot.meal }) {
                fixedAt[idx] = f
            }
        }

        var placed: [Slot?] = Array(repeating: nil, count: order.count)
        var usedDays: [String: [Int]] = [:]
        var steps = 0
        let maxSteps = 60000

        func rec(_ p: Int) -> Bool {
            if p == order.count { return true }
            steps += 1
            if steps > maxSteps { return false }
            if let f = fixedAt[p] {
                placed[p] = f
                return rec(p + 1)
            }
            let (day, meal) = order[p]
            let prev = p > 0 ? placed[p - 1] : nil
            let prevDish = (prev?.day == day) ? prev.flatMap { byId[$0.dishId] } : nil
            let dayTags = Set(prevDish?.tags ?? [])

            let candidates: [Dish] = remaining.keys
                .filter { (remaining[$0] ?? 0) > 0 }
                .compactMap { byId[$0] }
                .filter { $0.meal == "ambas" || $0.meal == meal }
                .filter { d in bias[d.id].map { $0 == meal } ?? true }
                .filter { d in !d.tags.contains(where: { dayTags.contains($0) }) }
                .filter { gapOK(usedDays, $0.id, day) }
                .map { d in (d, pairWeight(prevDish?.id, d.id, learning) * (0.2 + rng.next())) }
                .sorted { $0.1 > $1.1 }
                .map { $0.0 }

            for d in candidates {
                remaining[d.id, default: 0] -= 1
                usedDays[d.id, default: []].append(day)
                placed[p] = Slot(day: day, meal: meal, dishId: d.id)
                if rec(p + 1) { return true }
                placed[p] = nil
                usedDays[d.id]?.removeLast()
                remaining[d.id, default: 0] += 1
            }
            return false
        }

        return rec(0) ? placed.compactMap { $0 } : nil
    }

    /// Rr: genera un menú completo (reglas)
    static func generate(dishes: [Dish], history: [WeekMenu], weekKey: String, seed: Int?,
                         learning: Learning?, fixed: [Slot] = []) -> WeekMenu {
        var rng = SeededRNG(seed: seed ?? Int(Date().timeIntervalSince1970 * 1000))
        let pool0 = eligible(dishes, weekKey)
        let bias = mealBias(history)
        let need = 14 - fixed.count

        for _ in 0..<24 {
            var pool = pickPool(pool0, need, history, weekKey, learning, &rng)
            if pool.count < need {
                var counts: [String: Int] = [:]
                for d in pool { counts[d.id, default: 0] += 1 }
                while pool.count < need && !pool0.isEmpty {
                    let weights = pool0.map { 0.05 / (1 + Double(counts[$0.id] ?? 0)) }
                    let extra = weightedPick(pool0, weights, &rng)
                    pool.append(extra)
                    counts[extra.id, default: 0] += 1
                }
            }
            if let arranged = arrange(pool, learning, &rng, fixed, bias) {
                let slots = arranged.sorted { a, b in
                    a.day != b.day ? a.day < b.day : (a.meal == "comida" && b.meal != "comida")
                }
                return WeekMenu(weekKey: weekKey, slots: slots, createdAt: isoNow(), source: "reglas")
            }
        }

        // Fallback greedy turno a turno
        var rng2 = SeededRNG(seed: (seed ?? Int(Date().timeIntervalSince1970 * 1000)) + 777)
        var dishCount: [String: Int] = [:]
        var tagCount: [String: Int] = [:]
        var usedDays: [String: [Int]] = [:]
        var slots: [Slot] = []
        func isFixed(_ day: Int, _ meal: String) -> Bool {
            fixed.contains { $0.day == day && $0.meal == meal }
        }
        for day in 0..<7 {
            var dayTags = Set<String>()
            var prevDishId: String? = nil
            for meal in ["comida", "cena"] {
                if isFixed(day, meal) {
                    slots.append(fixed.first { $0.day == day && $0.meal == meal }!)
                    continue
                }
                func filterUr(_ strictTags: Bool, _ strictGap: Bool) -> [Dish] {
                    pool0.filter { d in
                        (dishCount[d.id] ?? 0) < d.timesPerWeek
                            && (d.meal == "ambas" || d.meal == meal)
                            && (!strictTags || !d.tags.contains(where: { dayTags.contains($0) }))
                            && (!strictGap || gapOK(usedDays, d.id, day))
                            && (bias[d.id].map { $0 == meal } ?? true)
                    }
                }
                var relaxed = false
                var m = filterUr(true, true)
                if m.isEmpty { m = filterUr(false, true); relaxed = true }
                if m.isEmpty { m = filterUr(true, false); relaxed = true }
                if m.isEmpty {
                    m = pool0.filter { $0.meal == "ambas" || $0.meal == meal }
                    relaxed = true
                }
                if m.isEmpty { continue }
                let weights = greedyWeights(m, dishCount, tagCount, history, weekKey, relaxed, learning, prevDishId)
                let pick = weightedPick(m, weights, &rng2)
                if meal == "comida" { prevDishId = pick.id }
                slots.append(Slot(day: day, meal: meal, dishId: pick.id))
                dishCount[pick.id, default: 0] += 1
                usedDays[pick.id, default: []].append(day)
                for t in pick.tags { dayTags.insert(t); tagCount[t, default: 0] += 1 }
            }
        }
        return WeekMenu(weekKey: weekKey, slots: slots, createdAt: isoNow(), source: "reglas")
    }

    /// O0: sugerencias para cambiar un turno (máx 14, siguiendo las mismas reglas)
    static func suggestions(dishes: [Dish], menu: WeekMenu, day: Int, meal: String,
                            history: [WeekMenu], learning: Learning?) -> [Dish] {
        var byId: [String: Dish] = [:]
        for d in dishes { byId[d.id] = d }
        let pool = eligible(dishes, menu.weekKey)
        let bias = mealBias(history)

        var counts: [String: Int] = [:]
        var usedDays: [String: [Int]] = [:]
        for s in menu.slots where !SpecialSlot.isSpecial(s.dishId) && !(s.day == day && s.meal == meal) {
            counts[s.dishId, default: 0] += 1
            usedDays[s.dishId, default: []].append(s.day)
        }
        let otherSlot = menu.slots.first { $0.day == day && $0.meal != meal }
        let otherTags: Set<String> = {
            guard let o = otherSlot, !SpecialSlot.isSpecial(o.dishId) else { return [] }
            return Set(byId[o.dishId]?.tags ?? [])
        }()

        func mealOK(_ d: Dish) -> Bool {
            (d.meal == "ambas" || d.meal == meal) && (bias[d.id].map { $0 == meal } ?? true)
        }
        func score(_ d: Dish) -> Double {
            recencyWeight(d.id, history, menu.weekKey) * learningWeight(d.id, learning)
                * pairWeight(otherSlot?.dishId, d.id, learning)
        }

        let first = pool
            .filter { mealOK($0) && !$0.tags.contains(where: { otherTags.contains($0) })
                && (counts[$0.id] ?? 0) < $0.timesPerWeek && gapOK(usedDays, $0.id, day) }
            .sorted { score($0) > score($1) }
        let second = pool
            .filter { mealOK($0) && (counts[$0.id] ?? 0) < $0.timesPerWeek && !first.contains($0) }
            .sorted { score($0) > score($1) }
        return Array((first + second).prefix(14))
    }

    /// x0: reemplazo aleatorio ponderado para un turno
    static func randomReplacement(dishes: [Dish], menu: WeekMenu, day: Int, meal: String,
                                  history: [WeekMenu], seed: Int?, learning: Learning?) -> Dish? {
        var byId: [String: Dish] = [:]
        for d in dishes { byId[d.id] = d }
        let pool = eligible(dishes, menu.weekKey)
        let bias = mealBias(history)
        var counts: [String: Int] = [:]
        var usedDays: [String: [Int]] = [:]
        for s in menu.slots where !SpecialSlot.isSpecial(s.dishId) && !(s.day == day && s.meal == meal) {
            counts[s.dishId, default: 0] += 1
            usedDays[s.dishId, default: []].append(s.day)
        }
        let otherSlot = menu.slots.first { $0.day == day && $0.meal != meal }
        let otherTags: Set<String> = {
            guard let o = otherSlot, !SpecialSlot.isSpecial(o.dishId) else { return [] }
            return Set(byId[o.dishId]?.tags ?? [])
        }()
        let candidates = pool.filter { d in
            (d.meal == "ambas" || d.meal == meal)
                && (bias[d.id].map { $0 == meal } ?? true)
                && !d.tags.contains(where: { otherTags.contains($0) })
                && (counts[d.id] ?? 0) < d.timesPerWeek
                && gapOK(usedDays, d.id, day)
        }
        if candidates.isEmpty { return nil }
        let weights = candidates.map { d in
            recencyWeight(d.id, history, menu.weekKey) * learningWeight(d.id, learning)
                * pairWeight(otherSlot?.dishId, d.id, learning)
        }
        var rng = SeededRNG(seed: seed ?? Int(Date().timeIntervalSince1970 * 1000))
        return weightedPick(candidates, weights, &rng)
    }

    /// N0: aprendizaje al confirmar un menú
    static func learn(_ learning: Learning, confirmed menu: WeekMenu, orig: [Slot], base: String) -> Learning {
        var l = learning
        func origId(_ day: Int, _ meal: String) -> String? {
            orig.first(where: { $0.day == day && $0.meal == meal })?.dishId
        }
        var changedDays = Set<Int>()
        for s in menu.slots {
            let o = origId(s.day, s.meal)
            if SpecialSlot.isSpecial(s.dishId) || (o.map { SpecialSlot.isSpecial($0) } ?? false) { continue }
            if let o = o, o != s.dishId {
                l.removed[o, default: 0] += 1
                l.added[s.dishId, default: 0] += 1
                changedDays.insert(s.day)
            } else if base == "fresh" {
                l.kept[s.dishId, default: 0] += 1
            }
        }
        for day in 0..<7 {
            if base != "fresh" && !changedDays.contains(day) { continue }
            guard let c = menu.slots.first(where: { $0.day == day && $0.meal == "comida" })?.dishId,
                  let n = menu.slots.first(where: { $0.day == day && $0.meal == "cena" })?.dishId,
                  !SpecialSlot.isSpecial(c), !SpecialSlot.isSpecial(n) else { continue }
            l.pairs[pairKey(c, n), default: 0] += 1
        }
        if base == "fresh" { l.weeks += 1 }
        return l
    }
}
