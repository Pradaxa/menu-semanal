import Foundation

// MARK: - Plataformas (ids de JustWatch, como en la web app)

struct QVPlatform: Codable, Equatable, Hashable {
    let id: String
    let name: String
    let iconTemplate: String
    let aliases: [String]

    func iconURL(_ profile: String = "s100") -> String {
        JustWatch.imageURL(iconTemplate, profile: profile)
    }
}

enum Platforms {
    static let all: [QVPlatform] = [
        QVPlatform(id: "nfx", name: "Netflix", iconTemplate: "/icon/207360008/{profile}/netflix.{format}", aliases: ["nfx", "nfa"]),
        QVPlatform(id: "mxx", name: "HBO Max", iconTemplate: "/icon/332884837/{profile}/max.{format}", aliases: ["mxx"]),
        QVPlatform(id: "dnp", name: "Disney+", iconTemplate: "/icon/313118777/{profile}/disneyplus.{format}", aliases: ["dnp"]),
        QVPlatform(id: "sst", name: "SkyShowtime", iconTemplate: "/icon/330520548/{profile}/skyshowtime.{format}", aliases: ["sst"]),
        QVPlatform(id: "prv", name: "Prime Video", iconTemplate: "/icon/322992749/{profile}/amazonprimevideo.{format}", aliases: ["prv"]),
        QVPlatform(id: "mp9", name: "Movistar+", iconTemplate: "/icon/321303679/{profile}/movistarott.{format}", aliases: ["mp9"]),
        QVPlatform(id: "fil", name: "Filmin", iconTemplate: "/icon/187161245/{profile}/filmin.{format}", aliases: ["fil", "fip"]),
    ]

    static func byId(_ id: String) -> QVPlatform? { all.first { $0.id == id } }
    static func byAlias(_ shortName: String) -> QVPlatform? {
        all.first { $0.aliases.contains(shortName.lowercased()) }
    }

    /// Canonización idéntica a la web: por alias de paquete y, si no, por nombre visible.
    static func canon(shortName: String?, clearName: String?) -> QVPlatform? {
        if let sn = shortName?.lowercased(), let p = byAlias(sn) { return p }
        let cn = (clearName ?? "").lowercased().replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        if cn.isEmpty { return nil }
        if cn.contains("netflix") { return all[0] }
        if cn.contains("hbo") { return all[1] }
        if cn.contains("disney") { return all[2] }
        if cn.contains("skyshowtime") || cn.contains("sky showtime") { return all[3] }
        if cn == "movistar plus+" || cn == "movistar plus" || cn == "m+" { return all[5] }
        if cn.contains("movistar") || cn.hasPrefix("m+") { return nil }
        if cn.contains("filmin") { return all[6] }
        if cn.contains("amazon") || cn.contains("prime") { return all[4] }
        return nil
    }
}

// MARK: - Referencia a plataforma en una ficha

struct PlatRef: Codable, Equatable, Hashable {
    var id: String
    var name: String
    var icon: String
    var mine: Bool
}

struct Season: Codable, Equatable {
    var num: Int
    var plats: [PlatRef]
}

// MARK: - Título (ficha normalizada; también es el snapshot guardado)

struct QVTitle: Codable, Identifiable, Equatable {
    var id: String
    var type: String // "movie" | "show"
    var title: String
    var year: Int?
    var releaseDate: String?
    var poster: String = ""
    var posterBig: String = ""
    var genres: [String] = []
    var imdbId: String?
    var imdb: Double?
    var director: [String] = []
    var actors: [String] = []
    var synopsis: String = ""
    var plats: [PlatRef] = []
    var seasonCount: Int = 0
    var seasonsList: [Season] = []
    var detailFetched: Bool = false
    // Estado del usuario (solo en elementos guardados)
    var watchedAt: Double?
    var ts: Double?
    var temps: [Int]?
    var tempsLola: [Int]?

    var minePlats: [PlatRef] { plats.filter { $0.mine } }
    var isShow: Bool { type == "show" }

    var isUpcoming: Bool {
        guard let d = releaseDate else { return false }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        return d > today
    }

    /// "Estreno: 9 nov 2026" en formato es-ES como la web
    var releaseFormatted: String {
        guard let d = releaseDate else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: d) else { return d }
        let out = DateFormatter()
        out.locale = Locale(identifier: "es_ES")
        out.setLocalizedDateFormatFromTemplate("dMMMyyyy")
        return out.string(from: date)
    }

    /// Nota IMDb tal como la muestra la web: un decimal si < 10.
    var imdbText: String? {
        guard let v = imdb, v > 0 else { return nil }
        return v < 10 ? String(format: "%.1f", v) : String(Int(v))
    }

    /// Snapshot para guardar (marca ts), igual que snapshot() de la web.
    func snapshot(now: Double = Date().timeIntervalSince1970 * 1000) -> QVTitle {
        var s = self
        s.ts = now
        return s
    }
}

// MARK: - Claves de almacenamiento (mismo esquema JSON que la web para importar/exportar)

enum StoreKeys {
    static let store = "qv-store-v1"     // {pendientes, vistas, lola, pendTemps}
    static let settings = "qv-settings-v1"
    static let ratings = "qv-rt-v1"
    static let top = "qv-top-v1"
    static let aiCards = "qv-ai-cards-v1"
}

/// Contenedor del store persistente, compatible con el localStorage de la web.
struct StoreFile: Codable {
    var pendientes: [String: QVTitle] = [:]
    var vistas: [String: QVTitle] = [:]
    var lola: [String: QVTitle] = [:]
    var pendTemps: [String: QVTitle] = [:]
    var seedV: Int?
}

// MARK: - Utilidades de texto compartidas

enum TextUtil {
    /// Clave de título como aiTitleKey de la web (sin acentos, minúsculas, solo a-z0-9).
    static func titleKey(_ s: String) -> String {
        let folded = s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .lowercased()
        let cleaned = folded.replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    /// Distancia de Levenshtein (para casar títulos de Gemini con el catálogo).
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let aa = Array(a), bb = Array(b)
        var prev = Array(0...bb.count)
        for (i, ca) in aa.enumerated() {
            var cur = [i + 1]
            for (j, cb) in bb.enumerated() {
                cur.append(min(cur[j] + 1, prev[j + 1] + 1, prev[j] + (ca == cb ? 0 : 1)))
            }
            prev = cur
        }
        return prev[bb.count]
    }
}
