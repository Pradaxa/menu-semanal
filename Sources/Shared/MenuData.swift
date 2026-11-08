import Foundation
import Security

// MARK: - Modelos compartidos (app + widget)

public struct Dish: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var timesPerWeek: Int
    public var seasons: [String]   // "all", "primavera", "verano", "otono", "invierno"
    public var meal: String        // "ambas", "comida", "cena"
    public var tags: [String]
    public var ingredients: [String]

    public init(id: String, name: String, timesPerWeek: Int = 1, seasons: [String] = ["all"], meal: String = "ambas", tags: [String] = [], ingredients: [String] = []) {
        self.id = id
        self.name = name
        self.timesPerWeek = timesPerWeek
        self.seasons = seasons
        self.meal = meal
        self.tags = tags
        self.ingredients = ingredients
    }
}

public struct Slot: Codable, Hashable {
    public var day: Int            // 0 = lunes ... 6 = domingo
    public var meal: String        // "comida" | "cena"
    public var dishId: String
    public init(day: Int, meal: String, dishId: String) {
        self.day = day
        self.meal = meal
        self.dishId = dishId
    }
}

public struct WeekMenu: Codable, Hashable {
    public var weekKey: String     // "YYYY-MM-DD" (lunes)
    public var slots: [Slot]
    public var createdAt: String
    public var source: String      // "reglas" | "ia"
    public var confirmed: Bool?
    public init(weekKey: String, slots: [Slot], createdAt: String, source: String, confirmed: Bool? = nil) {
        self.weekKey = weekKey
        self.slots = slots
        self.createdAt = createdAt
        self.source = source
        self.confirmed = confirmed
    }
}

public struct DraftMenu: Codable, Hashable {
    public var weekKey: String
    public var slots: [Slot]
    public var createdAt: String
    public var source: String
    public var orig: [Slot]
    public var base: String        // "fresh" | "confirmed"
    public var confirmed: Bool?
    public init(weekKey: String, slots: [Slot], createdAt: String, source: String, orig: [Slot], base: String, confirmed: Bool? = false) {
        self.weekKey = weekKey
        self.slots = slots
        self.createdAt = createdAt
        self.source = source
        self.orig = orig
        self.base = base
        self.confirmed = confirmed
    }
}

public struct Learning: Codable, Hashable {
    public var kept: [String: Int] = [:]
    public var added: [String: Int] = [:]
    public var removed: [String: Int] = [:]
    public var pairs: [String: Int] = [:]
    public var weeks: Int = 0
    public init() {}
}

public struct ExtraItem: Codable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
    public init(from decoder: Decoder) throws {
        if let c = try? decoder.singleValueContainer(), let s = try? c.decode(String.self) {
            self.id = "x-" + s
            self.name = s
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.name = (try? c.decode(String.self, forKey: .name)) ?? ""
    }
    private enum CodingKeys: String, CodingKey { case id, name }
}

public struct ShoppingWeek: Codable, Hashable {
    public var states: [String: String] = [:]   // itemKey -> "bought" | "home"
    public var extras: [ExtraItem] = []
    public init() {}
}

public struct ShoppingState: Codable, Hashable {
    public var weeks: [String: ShoppingWeek] = [:]
    public init() {}
}

// MARK: - Constantes

public enum SpecialSlot {
    public static let fuera = "__comer-fuera__"
    public static let sobras = "__sobras__"
    public static let vacio = "__vacio__"

    public static func label(for id: String) -> String {
        switch id {
        case fuera: return "Comer fuera"
        case sobras: return "Sobras"
        case vacio: return "—"
        default: return id
        }
    }

    public static func isSpecial(_ id: String) -> Bool {
        id == fuera || id == sobras || id == vacio
    }
}

public enum Week {
    public static let dayNames = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
    public static let dayShort = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
    public static let monthNames = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    public static let monthShort = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone = TimeZone.current
        return c
    }

    public static func monday(of date: Date) -> Date {
        var cal = calendar
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let noon = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: comps.day, hour: 12))!
        let weekday = cal.component(.weekday, from: noon)
        let delta = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: -delta, to: noon)!
    }

    public static func key(of date: Date) -> String {
        let m = monday(of: date)
        let c = calendar.dateComponents([.year, .month, .day], from: m)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    public static func date(for key: String) -> Date {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return Date() }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))!
    }

    public static func add(_ weeks: Int, to key: String) -> String {
        let d = calendar.date(byAdding: .day, value: weeks * 7, to: date(for: key))!
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    public static func dayDate(_ key: String, _ day: Int) -> Date {
        calendar.date(byAdding: .day, value: day, to: date(for: key))!
    }

    public static func label(for key: String) -> String {
        let d = date(for: key)
        let c = calendar.dateComponents([.day, .month], from: d)
        return "Semana del \(c.day!) de \(monthNames[c.month! - 1])"
    }

    /// "9–15 nov" para el widget
    public static func rangeLabel(for key: String) -> String {
        let d1 = date(for: key)
        let d2 = calendar.date(byAdding: .day, value: 6, to: d1)!
        let c1 = calendar.dateComponents([.day, .month], from: d1)
        let c2 = calendar.dateComponents([.day, .month], from: d2)
        if c1.month == c2.month {
            return "\(c1.day!)–\(c2.day!) \(monthShort[c2.month! - 1])"
        }
        return "\(c1.day!) \(monthShort[c1.month! - 1])–\(c2.day!) \(monthShort[c2.month! - 1])"
    }

    public static func season(of key: String) -> String {
        let month = calendar.component(.month, from: date(for: key))
        switch month {
        case 3...5: return "primavera"
        case 6...8: return "verano"
        case 9...11: return "otono"
        default: return "invierno"
        }
    }

    /// 0 = lunes ... 6 = domingo
    public static func todayIndex(on date: Date = Date()) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    public static var currentKey: String { key(of: Date()) }
}

// MARK: - Lectura compartida (App Group) para el widget

public struct WidgetDay: Hashable {
    public var dayIndex: Int
    public var lunch: String
    public var dinner: String
}

public enum SharedMenuReader {
    /// Respaldo para builds sin entitlements embebidos (p. ej. algunas de simulador).
    public static let fallbackSuiteName = "group.com.pradaxa.menusemanal"

    /// ID real del App Group, leído de los entitlements embebidos en el propio binario.
    /// AltStore puede reasignar el ID al firmar con la cuenta del usuario; leyéndolo
    /// del binario firmado final, app y widget comparten siempre el mismo contenedor.
    public static var suiteName: String {
        if let groups = embeddedAppGroups(), let first = groups.first, !first.isEmpty {
            return first
        }
        return fallbackSuiteName
    }

    /// Lee la sección __TEXT,__entitlements del binario en ejecución (image 0:
    /// el ejecutable del proceso; en el widget es el .appex) y extrae los App Groups.
    private static func embeddedAppGroups() -> [String]? {
        guard let header = _dyld_get_image_header(0) else { return nil }
        let header64 = UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self)
        var size: UInt = 0
        guard let section = getsectiondata(header64, "__TEXT", "__entitlements", &size), size > 0 else { return nil }
        let data = Data(bytes: section, count: Int(size))
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { return nil }
        return plist["com.apple.security.application-groups"] as? [String]
    }

    static func read<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Menú visible de una semana: borrador si existe, si no el confirmado.
    public static func menu(for weekKey: String) -> WeekMenu? {
        if let drafts: [DraftMenu] = read([DraftMenu].self, "menus.drafts.v1"),
           let d = drafts.first(where: { $0.weekKey == weekKey }) {
            return WeekMenu(weekKey: d.weekKey, slots: d.slots, createdAt: d.createdAt, source: d.source)
        }
        if let history: [WeekMenu] = read([WeekMenu].self, "menus.history.v1"),
           let h = history.first(where: { $0.weekKey == weekKey }) {
            return h
        }
        return nil
    }

    public static func days(for weekKey: String) -> [WidgetDay] {
        let dishes = read([Dish].self, "menus.dishes.v1") ?? []
        let names = Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0.name) })
        let menu = self.menu(for: weekKey)
        return (0..<7).map { day in
            let lunch = menu?.slots.first(where: { $0.day == day && $0.meal == "comida" })?.dishId
            let dinner = menu?.slots.first(where: { $0.day == day && $0.meal == "cena" })?.dishId
            return WidgetDay(
                dayIndex: day,
                lunch: lunch.map { SpecialSlot.isSpecial($0) ? SpecialSlot.label(for: $0) : (names[$0] ?? "") } ?? "",
                dinner: dinner.map { SpecialSlot.isSpecial($0) ? SpecialSlot.label(for: $0) : (names[$0] ?? "") } ?? ""
            )
        }
    }
}
