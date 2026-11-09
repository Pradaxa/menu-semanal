import Foundation

// MARK: - Cliente JustWatch (GraphQL público, mismo esquema que usa la web app)

enum JWError: LocalizedError {
    case http(Int)
    case api(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .http(let code): return "jw \(code)"
        case .api(let msg): return msg
        case .badResponse: return "Respuesta inesperada del catálogo"
        }
    }
}

enum JustWatch {
    static let endpoint = URL(string: "https://apis.justwatch.com/graphql")!

    static func imageURL(_ template: String?, profile: String = "s166") -> String {
        guard let tpl = template, !tpl.isEmpty else { return "" }
        return "https://images.justwatch.com" + tpl
            .replacingOccurrences(of: "{profile}", with: profile)
            .replacingOccurrences(of: "{format}", with: "webp")
    }

    static let fields = "content(country:$country,language:$language){title fullPath posterUrl originalReleaseYear originalReleaseDate shortDescription genres{shortName translation(language:$language)} externalIds{imdbId} credits{role name} scoring{imdbScore}} offers(country:$country,platform:WEB){monetizationType package{shortName clearName icon}}"
    static let fieldsNoMeta = "content(country:$country,language:$language){title fullPath posterUrl} ... on Movie {" + fields + "} ... on Show {" + fields + "}"

    /// POST GraphQL con reintentos ante 429 (como la web: hasta 5, espera creciente).
    static func query(_ query: String, variables: [String: Any], attempt: Int = 0) async throws -> [String: Any] {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 20
        req.httpBody = try JSONSerialization.data(withJSONObject: ["query": query, "variables": variables])

        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 429 && attempt < 5 {
            try await Task.sleep(nanoseconds: UInt64(1500 * (attempt + 1)) * 1_000_000)
            return try await self.query(query, variables: variables, attempt: attempt + 1)
        }
        guard status == 200 else { throw JWError.http(status) }
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if let errors = obj["errors"] as? [[String: Any]], let first = errors.first {
            throw JWError.api(first["message"] as? String ?? "Error del catálogo")
        }
        guard let d = obj["data"] as? [String: Any] else { throw JWError.badResponse }
        return d
    }

    /// Búsqueda por título (admite faltas: lo hace el servidor).
    static func search(_ q: String, first: Int = 14) async throws -> [QVTitle] {
        let query = "query($country:Country!,$language:Language!,$first:Int!,$filter:TitleFilter){popularTitles(country:$country,first:$first,filter:$filter){edges{node{id objectId objectType " + fieldsNoMeta + "}}}}"
        let data = try await self.query(query, variables: ["country": "ES", "language": "es", "first": first, "filter": ["searchQuery": q]])
        let edges = ((data["popularTitles"] as? [String: Any])?["edges"] as? [[String: Any]]) ?? []
        return edges.compactMap { $0["node"] as? [String: Any] }.map(norm)
    }

    /// Top 10 de una plataforma (popularidad JustWatch España, igual que la web).
    static func top(packages: [String], kind: String) async throws -> [QVTitle] {
        let query = "query($country:Country!,$language:Language!,$filter:TitleFilter){popularTitles(country:$country,first:10,filter:$filter,sortBy:POPULAR){edges{node{id objectId objectType " + fieldsNoMeta + "}}}}"
        let data = try await self.query(query, variables: [
            "country": "ES", "language": "es",
            "filter": ["packages": packages, "objectTypes": [kind == "show" ? "SHOW" : "MOVIE"]],
        ])
        let edges = ((data["popularTitles"] as? [String: Any])?["edges"] as? [[String: Any]]) ?? []
        return edges.compactMap { $0["node"] as? [String: Any] }.map(norm)
    }

    /// Ficha completa (con temporadas y sus plataformas para series).
    static func detail(_ id: String) async throws -> QVTitle? {
        let query = "query($id:ID!,$country:Country!,$language:Language!){node(id:$id){id ... on Movie {objectId objectType " + fields + "} ... on Show {objectId objectType seasons{content(country:$country,language:$language){seasonNumber} offers(country:$country,platform:WEB){monetizationType package{shortName clearName icon}}} " + fields + "}}}"
        let data = try await self.query(query, variables: ["id": id, "country": "ES", "language": "es"])
        guard let node = data["node"] as? [String: Any] else { return nil }
        return norm(node)
    }

    // MARK: Normalización (port fiel de norm() de la web)

    static func norm(_ node: [String: Any]) -> QVTitle {
        let c = node["content"] as? [String: Any] ?? [:]
        let credits = c["credits"] as? [[String: Any]] ?? []
        let director = credits.filter { $0["role"] as? String == "DIRECTOR" }.compactMap { $0["name"] as? String }
        let actors = Array(credits.filter { $0["role"] as? String == "ACTOR" }.compactMap { $0["name"] as? String }.prefix(6))
        let mine = platRecs(node["offers"] as? [[String: Any]] ?? [], mineOnly: true)
        let others = platRecs(node["offers"] as? [[String: Any]] ?? [], mineOnly: false)
            .filter { o in !mine.contains { $0.id == o.id } }

        var seasonCount = 0
        var seasonsList: [Season] = []
        for s in node["seasons"] as? [[String: Any]] ?? [] {
            let num = (s["content"] as? [String: Any])?["seasonNumber"] as? Int ?? 0
            if num > seasonCount { seasonCount = num }
            if num > 0 {
                let sMine = platRecs(s["offers"] as? [[String: Any]] ?? [], mineOnly: true)
                let sOthers = platRecs(s["offers"] as? [[String: Any]] ?? [], mineOnly: false)
                    .filter { o in !sMine.contains { $0.id == o.id } }
                seasonsList.append(Season(num: num, plats: sMine + sOthers))
            }
        }
        seasonsList.sort { $0.num < $1.num }

        let objectType = node["objectType"] as? String ?? ""
        return QVTitle(
            id: node["id"] as? String ?? "",
            type: objectType == "SHOW" ? "show" : "movie",
            title: c["title"] as? String ?? "",
            year: c["originalReleaseYear"] as? Int,
            releaseDate: c["originalReleaseDate"] as? String,
            poster: imageURL(c["posterUrl"] as? String, profile: "s166"),
            posterBig: imageURL(c["posterUrl"] as? String, profile: "s592"),
            genres: (c["genres"] as? [[String: Any]] ?? []).compactMap { $0["translation"] as? String },
            imdbId: (c["externalIds"] as? [String: Any])?["imdbId"] as? String,
            imdb: (c["scoring"] as? [String: Any])?["imdbScore"] as? Double,
            director: director,
            actors: actors,
            synopsis: c["shortDescription"] as? String ?? "",
            plats: mine + others,
            seasonCount: seasonCount,
            seasonsList: seasonsList,
            detailFetched: objectType != "SHOW" || seasonCount > 0
        )
    }

    /// Plataformas de una lista de ofertas: solo suscripción (FLATRATE), deduplicadas.
    static func platRecs(_ offers: [[String: Any]], mineOnly: Bool) -> [PlatRef] {
        var seen = Set<String>()
        var out: [PlatRef] = []
        for o in offers {
            guard o["monetizationType"] as? String == "FLATRATE" else { continue }
            let pkg = o["package"] as? [String: Any] ?? [:]
            guard let sn = pkg["shortName"] as? String, !sn.isEmpty else { continue }
            let mine = Platforms.canon(shortName: sn, clearName: pkg["clearName"] as? String)
            if mineOnly && mine == nil { continue }
            if !mineOnly && mine != nil { continue }
            let key = mine?.id ?? sn
            if seen.contains(key) { continue }
            seen.insert(key)
            if let m = mine {
                out.append(PlatRef(id: m.id, name: m.name, icon: m.iconURL("s100"), mine: true))
            } else {
                out.append(PlatRef(id: sn,
                                   name: ((pkg["clearName"] as? String) ?? sn).trimmingCharacters(in: .whitespaces),
                                   icon: imageURL(pkg["icon"] as? String, profile: "s100"),
                                   mine: false))
            }
        }
        return out
    }

    /// dedupePlats de la web: canoniza y quita duplicados conservando el orden.
    static func dedupePlats(_ plats: [PlatRef]) -> [PlatRef] {
        var seen = Set<String>()
        var out: [PlatRef] = []
        for p in plats {
            let canon = Platforms.byAlias(p.id) ?? Platforms.canon(shortName: nil, clearName: p.name)
            let key = canon?.id ?? p.id
            if seen.contains(key) { continue }
            seen.insert(key)
            if let c = canon {
                out.append(PlatRef(id: c.id, name: c.name, icon: c.iconURL("s100"), mine: true))
            } else {
                out.append(p)
            }
        }
        return out
    }
}

// MARK: - Nota IMDb: JustWatch ya la trae; OMDb solo como respaldo (proxy de la web o clave propia)

enum Ratings {
    /// Devuelve la nota IMDb de un título: la de la ficha, la caché (7 días) u OMDb.
    static func rating(for item: QVTitle, omdbKey: String) async -> Double? {
        if let v = item.imdb { return v }
        guard let imdbId = item.imdbId else { return nil }
        if let cached = cache[imdbId], Date().timeIntervalSince1970 * 1000 - cached.ts < 7 * 86400_000 {
            return cached.v
        }
        let key = omdbKey.trimmingCharacters(in: .whitespaces)
        let urlString = key.isEmpty
            ? "https://que-ver.pages.dev/api/omdb?i=\(imdbId)"
            : "https://www.omdbapi.com/?i=\(imdbId)&apikey=\(key)&plot=short&r=json"
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rating = obj["imdbRating"] as? String,
              rating != "N/A", let v = Double(rating) else { return nil }
        cache[imdbId] = (v, Date().timeIntervalSince1970 * 1000)
        saveCache()
        return v
    }

    private struct RatingEntry: Codable { var v: Double; var ts: Double }
    private static var cache: [String: (v: Double, ts: Double)] = loadCache()

    private static func loadCache() -> [String: (v: Double, ts: Double)] {
        guard let data = UserDefaults.standard.data(forKey: StoreKeys.ratings),
              let raw = try? JSONDecoder().decode([String: RatingEntry].self, from: data) else { return [:] }
        return raw.mapValues { ($0.v, $0.ts) }
    }

    private static func saveCache() {
        let raw = cache.mapValues { RatingEntry(v: $0.v, ts: $0.ts) }
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: StoreKeys.ratings)
        }
    }
}
