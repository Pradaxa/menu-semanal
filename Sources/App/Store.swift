import Foundation
import SwiftUI
import WidgetKit

// MARK: - Tienda principal

final class AppStore: ObservableObject {
    @Published var dishes: [Dish] { didSet { persist(dishes, "menus.dishes.v1"); refreshWidget() } }
    @Published var history: [WeekMenu] { didSet { persist(history, "menus.history.v1"); refreshWidget() } }
    @Published var drafts: [DraftMenu] { didSet { persist(drafts, "menus.drafts.v1"); refreshWidget() } }
    @Published var learning: Learning { didSet { persist(learning, "menus.prefs.v1") } }
    @Published var shopping: ShoppingState { didSet { persist(shopping, "menus.shopping.v1") } }
    @Published var weekSel: String { didSet { persist(weekSel, "menus.weeksel.v1") } }
    @Published var geminiKey: String { didSet { persistStandard(geminiKey, "menus.gemini.v1") } }

    /// nil = seguir al iPhone; true = oscuro; false = claro
    @Published var darkOverride: Bool? { didSet { persistStandard(darkOverride as Any, "menus.dark.v2") } }

    private let suite = UserDefaults(suiteName: SharedMenuReader.suiteName)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    static let shared = AppStore()

    init() {
        func read<T: Decodable>(_ type: T.Type, _ key: String, from defaults: UserDefaults?) -> T? {
            guard let data = defaults?.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        }
        let suite = UserDefaults(suiteName: SharedMenuReader.suiteName)
        self.dishes = read([Dish].self, "menus.dishes.v1", from: suite) ?? AppStore.seedDishes()
        self.history = read([WeekMenu].self, "menus.history.v1", from: suite) ?? []
        self.drafts = read([DraftMenu].self, "menus.drafts.v1", from: suite) ?? []
        self.learning = read(Learning.self, "menus.prefs.v1", from: suite) ?? Learning()
        self.shopping = read(ShoppingState.self, "menus.shopping.v1", from: suite) ?? ShoppingState()
        self.weekSel = read(String.self, "menus.weeksel.v1", from: suite) ?? Week.currentKey
        let std = UserDefaults.standard
        self.geminiKey = std.string(forKey: "menus.gemini.v1") ?? ""
        self.darkOverride = std.object(forKey: "menus.dark.v2") as? Bool
    }

    private func persist<T: Encodable>(_ value: T, _ key: String) {
        guard let data = try? encoder.encode(value) else { return }
        suite?.set(data, forKey: key)
    }

    private func persistStandard(_ value: Any, _ key: String) {
        if let s = value as? String {
            UserDefaults.standard.set(s, forKey: key)
        } else if let b = value as? Bool {
            UserDefaults.standard.set(b, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func refreshWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: semana visible

    struct ResolvedMenu {
        var menu: WeekMenu
        var isDraft: Bool
        var confirmed: Bool
    }

    func resolved(_ weekKey: String) -> ResolvedMenu {
        if let d = drafts.first(where: { $0.weekKey == weekKey }) {
            return ResolvedMenu(menu: WeekMenu(weekKey: d.weekKey, slots: d.slots, createdAt: d.createdAt, source: d.source),
                                isDraft: true, confirmed: false)
        }
        if let h = history.first(where: { $0.weekKey == weekKey }) {
            return ResolvedMenu(menu: h, isDraft: false, confirmed: h.confirmed ?? false)
        }
        return ResolvedMenu(menu: WeekMenu(weekKey: weekKey, slots: [], createdAt: Engine.isoNow(), source: "reglas"),
                            isDraft: false, confirmed: false)
    }

    var dishNames: [String: String] {
        Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0.name) })
    }

    func dish(_ id: String) -> Dish? { dishes.first { $0.id == id } }

    func slotTitle(_ dishId: String) -> String {
        SpecialSlot.isSpecial(dishId) ? SpecialSlot.label(for: dishId) : (dishNames[dishId] ?? dishId)
    }

    // MARK: edición del menú

    private func saveDraft(_ menu: WeekMenu, orig: [Slot], base: String) {
        var d = drafts
        let draft = DraftMenu(weekKey: menu.weekKey, slots: menu.slots, createdAt: menu.createdAt,
                              source: menu.source, orig: orig, base: base, confirmed: false)
        if let idx = d.firstIndex(where: { $0.weekKey == menu.weekKey }) {
            d[idx] = draft
        } else {
            d.append(draft)
        }
        drafts = d
    }

    /// Cambia el plato de un turno (o lo quita con dishId vacío)
    func setSlot(_ dishId: String?, day: Int, meal: String, in weekKey: String) {
        let current = resolved(weekKey)
        var slots = current.menu.slots
        slots.removeAll { $0.day == day && $0.meal == meal }
        if let dishId = dishId, !dishId.isEmpty {
            slots.append(Slot(day: day, meal: meal, dishId: dishId))
        }
        slots.sort { a, b in a.day != b.day ? a.day < b.day : (a.meal == "comida" && b.meal != "comida") }
        let base = current.isDraft
            ? (drafts.first { $0.weekKey == weekKey }?.base ?? "fresh")
            : (current.confirmed ? "confirmed" : "fresh")
        let orig = current.isDraft
            ? (drafts.first { $0.weekKey == weekKey }?.orig ?? current.menu.slots)
            : current.menu.slots
        var menu = current.menu
        menu.slots = slots
        saveDraft(menu, orig: orig, base: base)
    }

    /// Genera un menú (fillOnly = solo huecos, respeta lo puesto)
    func generate(fillOnly: Bool, in weekKey: String, useAI: Bool, completion: @escaping (String?) -> Void) {
        let current = resolved(weekKey)
        let fixed: [Slot]
        if fillOnly {
            fixed = current.menu.slots
        } else {
            fixed = []
        }
        let dishes = self.dishes
        let history = self.history
        let learning = self.learning
        let key = self.geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        func finish(_ menu: WeekMenu, _ warning: String?) {
            var m = menu
            m.slots = m.slots.filter { $0.dishId != SpecialSlot.vacio }
            if fillOnly {
                let fixedMap = Dictionary(uniqueKeysWithValues: fixed.map { ("\($0.day)|\($0.meal)", $0) })
                m.slots = m.slots.map { fixedMap["\($0.day)|\($0.meal)"] ?? $0 }
            }
            DispatchQueue.main.async {
                self.saveDraft(m, orig: m.slots, base: "fresh")
                completion(warning)
            }
        }

        if useAI && !key.isEmpty {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let menu = try Gemini.generateMenu(apiKey: key, dishes: dishes, history: history,
                                                       learning: learning, weekKey: weekKey, fixed: fixed)
                    finish(menu, nil)
                } catch {
                    if fillOnly {
                        DispatchQueue.main.async {
                            completion((error as NSError).localizedDescription + " No se ha cambiado ningún plato.")
                        }
                    } else {
                        let menu = Engine.generate(dishes: dishes, history: history, weekKey: weekKey,
                                                   seed: nil, learning: learning, fixed: fixed)
                        finish(menu, (error as NSError).localizedDescription + " Este menú se ha generado con tus reglas, sin IA.")
                    }
                }
            }
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                let menu = Engine.generate(dishes: dishes, history: history, weekKey: weekKey,
                                           seed: nil, learning: learning, fixed: fixed)
                finish(menu, nil)
            }
        }
    }

    /// Confirma el menú: pasa a historial y aprende
    func confirm(_ weekKey: String) {
        guard let draft = drafts.first(where: { $0.weekKey == weekKey }) else { return }
        let confirmed = WeekMenu(weekKey: draft.weekKey, slots: draft.slots, createdAt: draft.createdAt,
                                 source: draft.source, confirmed: true)
        learning = Engine.learn(learning, confirmed: confirmed, orig: draft.orig, base: draft.base)
        history.removeAll { $0.weekKey == weekKey }
        history.append(confirmed)
        drafts.removeAll { $0.weekKey == weekKey }
    }

    /// Vuelve a editar un menú confirmado
    func reopen(_ weekKey: String) {
        guard let h = history.first(where: { $0.weekKey == weekKey }) else { return }
        let draft = DraftMenu(weekKey: h.weekKey, slots: h.slots, createdAt: h.createdAt,
                              source: h.source, orig: h.slots, base: "confirmed", confirmed: false)
        history.removeAll { $0.weekKey == weekKey }
        drafts.removeAll { $0.weekKey == weekKey }
        drafts.append(draft)
    }

    // MARK: platos

    func saveDish(_ dish: Dish) {
        if let idx = dishes.firstIndex(where: { $0.id == dish.id }) {
            dishes[idx] = dish
        } else {
            dishes.append(dish)
        }
    }

    func deleteDish(_ id: String) {
        dishes.removeAll { $0.id == id }
    }

    static func slug(_ name: String) -> String {
        var s = TextNorm.dt(name).replacingOccurrences(of: " ", with: "-")
        s = s.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        return s.isEmpty ? "plato" : s
    }

    // MARK: compra

    func shoppingWeek(_ weekKey: String) -> ShoppingWeek {
        shopping.weeks[weekKey] ?? ShoppingWeek()
    }

    func setShoppingWeek(_ week: ShoppingWeek, _ weekKey: String) {
        var s = shopping
        s.weeks[weekKey] = week
        shopping = s
    }

    // MARK: exportar / importar

    struct Backup: Codable {
        var app: String
        var version: Int
        var exportedAt: String
        var data: BackupData
    }
    struct BackupData: Codable {
        var dishes: [Dish]
        var history: [WeekMenu]
        var drafts: [DraftMenu]
        var prefs: Learning
        var shopping: ShoppingState
    }

    enum ImportError: LocalizedError {
        case unreadable
        case incompatible
        var errorDescription: String? {
            switch self {
            case .unreadable: return "No se pudo leer la copia. No se ha cambiado nada."
            case .incompatible: return "Este archivo no es una copia compatible de esta app. No se ha cambiado nada."
            }
        }
    }

    func exportData() throws -> Data {
        let backup = Backup(app: "menus-semanales", version: 1, exportedAt: Engine.isoNow(),
                            data: BackupData(dishes: dishes, history: history, drafts: drafts,
                                             prefs: learning, shopping: shopping))
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(backup)
    }

    func importData(_ data: Data) throws {
        guard let backup = try? decoder.decode(Backup.self, from: data) else { throw ImportError.unreadable }
        guard backup.app == "menus-semanales", backup.version == 1 else { throw ImportError.incompatible }
        dishes = backup.data.dishes
        history = backup.data.history
        drafts = backup.data.drafts
        learning = backup.data.prefs
        shopping = backup.data.shopping
    }

    func resetLearning() {
        learning = Learning()
    }

    // MARK: platos iniciales (los mismos que trae la web app)

    static func seedDishes() -> [Dish] {
        let seed: [(String, String, [String], [String])] = [
        ("ensaladilla", "Ensaladilla", ["patata", "ensalada", "huevo"], ["patatas", "zanahorias", "huevos", "atún en lata", "mayonesa", "guisantes"]),
        ("ens-atun-legumbres", "Ensalada con atún y legumbres", ["ensalada", "legumbre"], ["alubias o garbanzos", "atún en lata", "lechuga", "tomate", "maíz dulce", "cebolla morada"]),
        ("tortilla-claras", "Tortilla de claras con ensalada", ["huevo", "ensalada"], ["claras de huevo", "lechuga", "tomate", "zanahoria"]),
        ("noquis-jamon", "Ñoquis con jamón serrano y champis", ["pasta"], ["ñoquis", "jamón serrano", "champiñones", "nata para cocinar", "queso rallado"]),
        ("judias-pavo", "Judías con pavo, pisto y huevo", ["legumbre", "huevo"], ["judías blancas", "pavo", "calabacín", "pimiento verde", "tomate triturado", "huevos"]),
        ("caballa", "Caballa al horno", ["pescado"], ["caballa", "patatas", "cebolla", "limón", "ajo"]),
        ("ens-langostinos", "Ensalada de langostinos", ["ensalada", "marisco"], ["langostinos", "lechuga", "aguacate", "tomate cherry", "maíz dulce"]),
        ("pollo-asado", "Pollo asado", ["pollo"], ["pollo", "patatas", "limón", "ajo"]),
        ("fajitas", "Fajitas", ["pollo"], ["tortillas de trigo", "pechuga de pollo", "pimientos", "cebolla", "queso rallado"]),
        ("tortilla", "Tortilla", ["huevo", "patata"], ["huevos", "patatas", "cebolla"]),
        ("brecol-huevo", "Brécol con huevo cocido y ajada", ["verdura", "huevo"], ["brócoli", "huevos", "ajo", "pimentón"]),
        ("pasta-judias-jamon", "Pasta con judías y jamón serrano", ["pasta", "legumbre"], ["pasta", "judías blancas", "jamón serrano", "tomate triturado"]),
        ("ens-tomate-hummus", "Ensalada de tomate con hummus y zanahoria", ["ensalada", "legumbre"], ["tomates", "hummus", "zanahorias", "lechuga"]),
        ("bacalao-brecol", "Bacalao con brécol y ajada", ["pescado", "verdura"], ["bacalao", "brócoli", "ajo", "pimentón", "guindilla"]),
        ("ens-pasta", "Ensalada de pasta", ["ensalada", "pasta"], ["pasta corta", "atún en lata", "maíz dulce", "tomate", "pepino"]),
        ("noquis-bolognesa", "Ñoquis bolognesa", ["pasta", "carne"], ["ñoquis", "carne picada", "tomate triturado", "cebolla", "zanahoria"]),
        ("salmon", "Salmón y ensalada", ["pescado", "ensalada"], ["lomos de salmón", "lechuga", "aguacate", "limón"]),
        ("pasta-china", "Pasta china con tofu y champiñones", ["pasta", "verdura"], ["fideos chinos", "tofu", "champiñones", "salsa de soja", "zanahoria"]),
        ("pollo-pita", "Pollo en pita", ["pollo"], ["pan de pita", "pechuga de pollo", "lechuga", "tomate", "yogur natural"]),
        ("brecol-lacon", "Brécol con lacón y ajada", ["verdura"], ["brócoli", "lacón", "ajo", "pimentón"]),
        ("pollo-pasta", "Pollo con pasta y champiñones", ["pollo", "pasta"], ["pechuga de pollo", "pasta", "champiñones", "nata para cocinar"]),
        ("berenjenas", "Berenjenas rellenas de bolognesa de atún", ["verdura"], ["berenjenas", "atún en lata", "tomate triturado", "cebolla", "queso rallado"]),
        ("albondigas-judias", "Albóndigas con judías y pasta", ["carne", "legumbre", "pasta"], ["albóndigas", "judías blancas", "pasta corta", "tomate triturado"]),
        ("codillo", "Codillo al horno", ["carne"], ["codillo de cerdo", "patatas", "cerveza", "ajo"]),
        ("habas-curry", "Habas con curry de gambas y espinacas", ["legumbre", "marisco"], ["habas", "gambas", "espinacas", "leche de coco", "curry"]),
        ("carbonara", "Pasta carbonara", ["pasta", "huevo"], ["pasta", "huevos", "panceta o bacon", "queso parmesano"]),
        ("noquis-pavo", "Ñoquis con pavo, espinacas y setas", ["pasta"], ["ñoquis", "pavo", "espinacas", "setas", "ajo"]),
        ("curry-pollo", "Curry de pollo con garbanzos y verduras", ["pollo", "legumbre"], ["pechuga de pollo", "garbanzos", "calabacín", "leche de coco", "curry", "arroz basmati"]),
        ("albondigas-arroz", "Albóndigas con arroz blanco", ["carne", "arroz"], ["albóndigas", "arroz", "tomate triturado"]),
        ("guiso-judias", "Guiso de judías con jamón y huevo cocido", ["legumbre", "huevo"], ["judías blancas", "jamón serrano", "huevos", "cebolla", "pimentón"]),
        ("patata-rellena", "Patata rellena", ["patata"], ["patatas grandes", "carne picada o atún", "queso rallado", "cebolla"]),
        ]
        return seed.map { Dish(id: $0.0, name: $0.1, tags: $0.2, ingredients: $0.3) }
    }
}
