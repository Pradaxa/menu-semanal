import Foundation

struct DayMenu: Codable, Identifiable {
    var id: String { day }
    let day: String
    let short: String
    var lunch: String
    var dinner: String
}

enum MenuStore {
    static let suiteName = "group.com.pradaxa.menusemanal"
    static let key = "weekMenu"

    static var sampleWeek: [DayMenu] {
        [
            DayMenu(day: "Lunes", short: "L", lunch: "Lentejas con verduras", dinner: "Ensalada César"),
            DayMenu(day: "Martes", short: "M", lunch: "Pasta al pesto", dinner: "Tortilla francesa"),
            DayMenu(day: "Miércoles", short: "X", lunch: "Pollo asado con patatas", dinner: "Crema de calabaza"),
            DayMenu(day: "Jueves", short: "J", lunch: "Arroz tres delicias", dinner: "Salmón a la plancha"),
            DayMenu(day: "Viernes", short: "V", lunch: "Paella", dinner: "Pizza casera"),
            DayMenu(day: "Sábado", short: "S", lunch: "Hamburguesa casera", dinner: "Sopa de fideos"),
            DayMenu(day: "Domingo", short: "D", lunch: "Cocido", dinner: "Tortilla española"),
        ]
    }

    static func save(_ week: [DayMenu]) {
        guard let data = try? JSONEncoder().encode(week) else { return }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: key)
    }

    static func load() -> [DayMenu] {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key),
              let week = try? JSONDecoder().decode([DayMenu].self, from: data),
              week.count == 7 else {
            return sampleWeek
        }
        return week
    }

    /// 0 = lunes ... 6 = domingo
    static var todayIndex: Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }
}
