import Foundation

// MARK: - Sync con Mi Día (mi-dia-hub.pages.dev)
// Sube el menú visible (borrador si existe, si no el confirmado) de esta semana
// y la siguiente al endpoint de Mi Día, cada vez que cambia. La clave la pega el
// usuario en Ajustes y solo se guarda en este iPhone.

enum MenuSync {
    static let endpoint = URL(string: "https://mi-dia-hub.pages.dev/api/menu")!
    private static var pending: DispatchWorkItem?

    struct SyncDay: Codable { let day: Int; let comida: String; let cena: String }
    struct SyncWeek: Codable { let weekKey: String; let days: [SyncDay] }
    struct SyncPayload: Codable { let v: Int; let weeks: [SyncWeek] }

    /// Tras cambios en el menú: agrupa ráfagas de ediciones en un solo envío.
    static func schedulePush(store: AppStore) {
        guard !store.syncKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        pending?.cancel()
        let item = DispatchWorkItem { push(store: store) }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: item)
    }

    static func push(store: AppStore) {
        let key = store.syncKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        let keys = [Week.currentKey, Week.add(1, to: Week.currentKey)]
        let weeks = keys.map { k -> SyncWeek in
            let r = store.resolved(k)
            let days = (0..<7).map { day -> SyncDay in
                func title(_ meal: String) -> String {
                    guard let s = r.menu.slots.first(where: { $0.day == day && $0.meal == meal }) else { return "" }
                    return store.slotTitle(s.dishId)
                }
                return SyncDay(day: day, comida: title("comida"), cena: title("cena"))
            }
            return SyncWeek(weekKey: k, days: days)
        }
        guard let body = try? JSONEncoder().encode(SyncPayload(v: 1, weeks: weeks)) else { return }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-menu-key")
        req.httpBody = body
        URLSession.shared.dataTask(with: req) { _, resp, err in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let ok = err == nil && code == 200
            DispatchQueue.main.async {
                if ok {
                    let f = DateFormatter()
                    f.dateFormat = "HH:mm"
                    store.lastSync = f.string(from: Date())
                } else {
                    store.lastSync = code == 401 ? "clave incorrecta" : "error de red"
                }
            }
        }.resume()
    }
}
