import Foundation
import SwiftUI

// MARK: - Tienda principal (mismo modelo que la web: pendientes / vistas / lola / pendTemps)

@MainActor
final class QVStore: ObservableObject {
    @Published var pendientes: [String: QVTitle] { didSet { save() } }
    @Published var vistas: [String: QVTitle] { didSet { save() } }
    @Published var lola: [String: QVTitle] { didSet { save() } }
    @Published var pendTemps: [String: QVTitle] { didSet { save() } }

    @Published var geminiKey: String { didSet { UserDefaults.standard.set(geminiKey, forKey: "qv-gemini-key") } }
    @Published var omdbKey: String { didSet { UserDefaults.standard.set(omdbKey, forKey: "qv-omdb-key") } }
    /// nil = seguir al iPhone; true = oscuro; false = claro
    @Published var darkOverride: Bool? { didSet { UserDefaults.standard.set(darkOverride as Any, forKey: "qv-dark") } }

    static let shared = QVStore()

    private init() {
        let std = UserDefaults.standard
        if let data = std.data(forKey: StoreKeys.store),
           let file = try? JSONDecoder().decode(StoreFile.self, from: data) {
            self.pendientes = file.pendientes
            self.vistas = file.vistas
            self.lola = file.lola
            self.pendTemps = file.pendTemps
        } else {
            self.pendientes = [:]
            self.vistas = [:]
            self.lola = [:]
            self.pendTemps = [:]
        }
        self.geminiKey = std.string(forKey: "qv-gemini-key") ?? ""
        self.omdbKey = std.string(forKey: "qv-omdb-key") ?? ""
        self.darkOverride = std.object(forKey: "qv-dark") as? Bool
    }

    private func save() {
        let file = StoreFile(pendientes: pendientes, vistas: vistas, lola: lola, pendTemps: pendTemps)
        if let data = try? JSONEncoder().encode(file) {
            UserDefaults.standard.set(data, forKey: StoreKeys.store)
        }
    }

    // MARK: Estado

    func isLola(_ id: String) -> Bool {
        lola[id] != nil || !((pendTemps[id]?.tempsLola) ?? []).isEmpty
    }

    /// Busca un título guardado en cualquier colección.
    func stored(_ id: String) -> QVTitle? {
        pendientes[id] ?? pendTemps[id] ?? vistas[id] ?? lola[id]
    }

    // MARK: Marcas (port de mark / setTemp / markTemp / removeEverywhere)

    enum MarkKind { case vista, pendiente, lola }

    func mark(_ kind: MarkKind, _ item: QVTitle) -> String {
        var s = item.snapshot()
        let id = item.id
        switch kind {
        case .vista:
            if vistas[id] != nil {
                vistas.removeValue(forKey: id)
                return "Quitada de vistas"
            }
            s.watchedAt = Date().timeIntervalSince1970 * 1000
            vistas[id] = s
            pendientes.removeValue(forKey: id)
            pendTemps.removeValue(forKey: id)
            lola.removeValue(forKey: id)
            return "Marcada como vista ✅"
        case .lola:
            if lola[id] != nil {
                lola.removeValue(forKey: id)
                return "Quitada de con Lola"
            }
            lola[id] = s
            return "Marcada para ver con Lola 🩷"
        case .pendiente:
            if pendientes[id] != nil {
                pendientes.removeValue(forKey: id)
                return "Quitada de pendientes"
            }
            pendientes[id] = s
            vistas.removeValue(forKey: id)
            pendTemps.removeValue(forKey: id)
            return "Guardada en pendientes ⏳"
        }
    }

    func removeEverywhere(_ id: String) {
        pendientes.removeValue(forKey: id)
        pendTemps.removeValue(forKey: id)
        lola.removeValue(forKey: id)
    }

    /// Marca una temporada como pendiente / con Lola (port de setTemp).
    func setTemp(_ item: QVTitle, _ t: Int, kind: String) -> String {
        var e = pendTemps[item.id] ?? item.snapshot()
        var temps = e.temps ?? []
        var tl = e.tempsLola ?? []
        let msg: String
        if kind == "pend" {
            if let i = temps.firstIndex(of: t) {
                temps.remove(at: i)
                tl.removeAll { $0 == t }
                msg = "T\(t) quitada de pendientes"
            } else {
                temps.append(t); temps.sort()
                msg = "T\(t) pendiente ⏳"
            }
        } else {
            if let k = tl.firstIndex(of: t) {
                tl.remove(at: k)
                msg = "T\(t) quitada de con Lola"
            } else {
                tl.append(t)
                if !temps.contains(t) { temps.append(t); temps.sort() }
                msg = "T\(t) para ver con Lola ❤️"
            }
        }
        if temps.isEmpty && tl.isEmpty {
            pendTemps.removeValue(forKey: item.id)
        } else {
            e.temps = temps
            e.tempsLola = tl
            e.ts = Date().timeIntervalSince1970 * 1000
            pendTemps[item.id] = e
        }
        return msg
    }

    /// Rellena el detalle de fichas guardadas cuando se conoce (port de backfillStore).
    func backfill(_ node: QVTitle) {
        func patch(_ dict: inout [String: QVTitle]) {
            guard var e = dict[node.id] else { return }
            var dirty = false
            if !node.synopsis.isEmpty && e.synopsis != node.synopsis { e.synopsis = node.synopsis; dirty = true }
            if node.seasonCount > 0 && e.seasonCount != node.seasonCount { e.seasonCount = node.seasonCount; dirty = true }
            if !node.seasonsList.isEmpty && e.seasonsList != node.seasonsList { e.seasonsList = node.seasonsList; dirty = true }
            if e.director.isEmpty && !node.director.isEmpty { e.director = node.director; dirty = true }
            if e.actors.isEmpty && !node.actors.isEmpty { e.actors = node.actors; dirty = true }
            if e.poster.isEmpty && !node.poster.isEmpty { e.poster = node.poster; e.posterBig = node.posterBig; dirty = true }
            if e.imdb == nil && node.imdb != nil { e.imdb = node.imdb; dirty = true }
            if !e.detailFetched { e.detailFetched = true; dirty = true }
            if dirty { dict[node.id] = e }
        }
        patch(&pendientes); patch(&vistas); patch(&lola); patch(&pendTemps)
    }

    // MARK: Importar / exportar (formato JSON compatible con la web)

    func exportData() -> Data {
        let file = StoreFile(pendientes: pendientes, vistas: vistas, lola: lola, pendTemps: pendTemps)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? enc.encode(file)) ?? Data()
    }

    /// Importa un JSON con el formato del store de la web. Devuelve cuántos títulos entraron.
    @discardableResult
    func importData(_ data: Data) throws -> Int {
        let file = try JSONDecoder().decode(StoreFile.self, from: data)
        var added = 0
        for (id, s) in file.vistas where vistas[id] == nil && pendientes[id] == nil { vistas[id] = s; added += 1 }
        for (id, s) in file.pendientes where vistas[id] == nil && pendientes[id] == nil { pendientes[id] = s; added += 1 }
        for (id, s) in file.lola where lola[id] == nil { lola[id] = s; added += 1 }
        for (id, s) in file.pendTemps where pendTemps[id] == nil { pendTemps[id] = s; added += 1 }
        return added
    }

    /// Importa el seed de la web app (su lista inicial) desde su propia web, con un toque.
    /// El archivo es JS (`var QV_SEED={...}` con claves sin comillas); lo convertimos a JSON.
    func importSeedFromWeb() async throws -> Int {
        guard let url = URL(string: "https://que-ver.pages.dev/assets/seed.js") else { return 0 }
        let (data, _) = try await URLSession.shared.data(from: url)
        var text = String(decoding: data, as: UTF8.self)
        guard let range = text.range(of: "QV_SEED=") else { throw ImportError.formato }
        text = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix(";") { text.removeLast() }
        // JSON exige claves entre comillas
        text = text.replacingOccurrences(of: "([{,])\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*:",
                                         with: "$1\"$2\":", options: .regularExpression)
        guard let jsonData = text.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ImportError.formato
        }
        var added = 0
        for key in ["vistas", "pendientes"] {
            for raw in obj[key] as? [[String: Any]] ?? [] {
                guard let t = QVTitle(seedDict: raw) else { continue }
                if key == "vistas" {
                    if vistas[t.id] == nil && pendientes[t.id] == nil { vistas[t.id] = t; added += 1 }
                } else {
                    if vistas[t.id] == nil && pendientes[t.id] == nil { pendientes[t.id] = t; added += 1 }
                }
            }
        }
        return added
    }

    enum ImportError: LocalizedError {
        case formato
        var errorDescription: String? { "No he podido leer esos datos. Comprueba que es el archivo de exportación." }
    }
}

// MARK: - Ficha desde el diccionario del seed de la web

extension QVTitle {
    init?(seedDict d: [String: Any]) {
        guard let id = d["id"] as? String, let title = d["title"] as? String else { return nil }
        self.id = id
        self.type = d["type"] as? String ?? "movie"
        self.title = title
        self.year = d["year"] as? Int
        self.releaseDate = d["releaseDate"] as? String
        self.poster = d["poster"] as? String ?? ""
        self.posterBig = d["posterBig"] as? String ?? ""
        self.genres = d["genres"] as? [String] ?? []
        self.imdbId = d["imdbId"] as? String
        if let v = d["imdb"] as? Double { self.imdb = v }
        else if let s = d["imdb"] as? String { self.imdb = Double(s) }
        self.director = d["director"] as? [String] ?? []
        self.actors = d["actors"] as? [String] ?? []
        self.synopsis = d["synopsis"] as? String ?? ""
        self.plats = (d["plats"] as? [[String: Any]] ?? []).compactMap { p in
            guard let pid = p["id"] as? String else { return nil }
            return PlatRef(id: pid, name: p["name"] as? String ?? pid,
                           icon: p["icon"] as? String ?? "", mine: p["mine"] as? Bool ?? false)
        }
        self.seasonCount = d["seasonCount"] as? Int ?? 0
        self.seasonsList = (d["seasonsList"] as? [[String: Any]] ?? []).compactMap { s in
            guard let num = s["num"] as? Int else { return nil }
            let plats = (s["plats"] as? [[String: Any]] ?? []).compactMap { p -> PlatRef? in
                guard let pid = p["id"] as? String else { return nil }
                return PlatRef(id: pid, name: p["name"] as? String ?? pid,
                               icon: p["icon"] as? String ?? "", mine: p["mine"] as? Bool ?? false)
            }
            return Season(num: num, plats: plats)
        }
        self.detailFetched = d["detailFetched"] as? Bool ?? false
        self.watchedAt = d["watchedAt"] as? Double
        self.ts = d["ts"] as? Double
        self.temps = d["temps"] as? [Int]
        self.tempsLola = d["tempsLola"] as? [Int]
    }
}
