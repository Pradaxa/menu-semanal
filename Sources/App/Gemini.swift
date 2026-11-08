import Foundation

// MARK: - Cliente Gemini (misma lógica que la web app)

enum GeminiError: LocalizedError {
    case noKey
    case connection(String)
    case http(Int, String)
    case invalidJSON(String)
    case noModels

    var errorDescription: String? {
        switch self {
        case .noKey: return "Pega tu clave de Gemini en Ajustes."
        case .connection(let m): return m
        case .http(let code, let what): return "\(what): error HTTP \(code)."
        case .invalidJSON(let model): return "\(model): JSON inválido"
        case .noModels: return "models.list respondió, pero no anuncia ningún modelo Gemini de texto con generateContent para esta clave."
        }
    }
}

enum Gemini {
    private static var modelCache: (key: String, at: Date, names: [String])?

    struct ModelsResponse: Decodable {
        struct Model: Decodable {
            var name: String?
            var supportedGenerationMethods: [String]?
        }
        var models: [Model]?
        var nextPageToken: String?
    }

    /// mgDiscoverModels
    static func discoverModels(_ key: String, refresh: Bool = false) throws -> [String] {
        if !refresh, let cache = modelCache, cache.key == key,
           Date().timeIntervalSince(cache.at) < 300 {
            return cache.names
        }
        var token = ""
        var all: [ModelsResponse.Model] = []
        for page in 0..<10 {
            var urlString = "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000"
            if !token.isEmpty {
                urlString += "&pageToken=" + (token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token)
            }
            var req = URLRequest(url: URL(string: urlString)!)
            req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            req.timeoutInterval = 15
            let (data, response) = try URLSession.shared.synchronousDataTask(with: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard code == 200 else {
                switch code {
                case 429: throw GeminiError.http(429, "models.list: cuota o límite de solicitudes alcanzado")
                case 400, 401, 403: throw GeminiError.http(code, "models.list: Gemini no acepta la clave o sus permisos")
                default: throw GeminiError.http(code, "models.list")
                }
            }
            let parsed = (try? JSONDecoder().decode(ModelsResponse.self, from: data)) ?? ModelsResponse(models: [], nextPageToken: nil)
            all.append(contentsOf: parsed.models ?? [])
            token = parsed.nextPageToken ?? ""
            if token.isEmpty { break }
            if page == 9 { throw GeminiError.connection("models.list: lista incompleta. Vuelve a intentarlo.") }
        }
        let excluded = try! NSRegularExpression(pattern: "image|audio|tts|live|robotics|computer|embedding|vision", options: .caseInsensitive)
        let valid = try! NSRegularExpression(pattern: "^models/gemini-[a-z0-9.-]+$", options: .caseInsensitive)
        var names = Set<String>()
        for m in all {
            guard let name = m.name,
                  m.supportedGenerationMethods?.contains("generateContent") == true,
                  valid.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil,
                  excluded.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) == nil else { continue }
            names.insert(name.replacingOccurrences(of: "models/", with: ""))
        }
        func rank(_ name: String) -> Int {
            var r = 50
            if name.contains("flash-lite") { r = 0 }
            else if name.contains("flash") { r = 10 }
            else if name.contains("pro") { r = 30 }
            if name.contains("preview") || name.contains("exp") { r += 5 }
            return r
        }
        let sorted = names.sorted { a, b in
            if rank(a) != rank(b) { return rank(a) < rank(b) }
            return a.compare(b, options: .numeric) == .orderedDescending
        }
        if sorted.isEmpty { throw GeminiError.noModels }
        modelCache = (key, Date(), sorted)
        return sorted
    }

    struct GenerateResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { var text: String? }
                var parts: [Part]?
            }
            var content: Content?
        }
        var candidates: [Candidate]?
    }

    /// mgCall
    static func call(model: String, key: String, prompt: String, schema: [String: Any]? = nil) throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        var generationConfig: [String: Any] = ["responseMimeType": "application/json"]
        if let schema = schema { generationConfig["responseSchema"] = schema }
        let body: [String: Any] = [
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": generationConfig,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try URLSession.shared.synchronousDataTask(with: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code == 200 else { throw GeminiError.http(code, model) }
        guard let parsed = try? JSONDecoder().decode(GenerateResponse.self, from: data) else {
            throw GeminiError.invalidJSON(model)
        }
        let text = parsed.candidates?.first?.content?.parts?.compactMap { $0.text }.joined() ?? ""
        if text.isEmpty { throw GeminiError.invalidJSON(model) }
        return text
    }

    static func parseJSON(_ text: String) -> [String: Any]? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = t.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj
    }

    /// Y1: el prompt del menú (mismo contenido que la web app)
    static func menuPrompt(dishes: [Dish], history: [WeekMenu], learning: Learning, weekKey: String, fixed: [Slot]) -> String {
        let byId = Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0) })
        let season = Week.season(of: weekKey)
        let bias = Engine.mealBias(history)
        let recent = history
            .filter { $0.weekKey != weekKey }
            .sorted { $0.weekKey > $1.weekKey }
            .prefix(2)
            .flatMap { $0.slots.compactMap { byId[$0.dishId]?.name } }
        func liked(_ id: String) -> Double {
            0.12 * Double(learning.kept[id] ?? 0) + 0.35 * Double(learning.added[id] ?? 0) - 0.4 * Double(learning.removed[id] ?? 0)
        }
        let likes = dishes.filter { liked($0.id) > 0.3 }.sorted { liked($0.id) > liked($1.id) }.prefix(6).map { $0.name }
        let dislikes = dishes.filter { liked($0.id) < -0.3 }.sorted { liked($0.id) < liked($1.id) }.prefix(6).map { $0.name }
        let available = dishes
            .filter { d in d.timesPerWeek > 0 && (Engine.seasonsOf(d).contains("all") || Engine.seasonsOf(d).contains(season)) }
            .map { d in "\(d.id): \(d.name) | categorías: \(d.tags.joined(separator: ", ")) | momento: \(bias[d.id] ?? d.meal) | máx \(d.timesPerWeek)/semana" }

        var lines: [String] = [
            "Eres un planificador de menús semanales. Genera un menú de lunes a domingo, comida y cena (14 turnos), usando SOLO los platos de la lista, referenciados por su id.",
            "Estación actual: \(season).",
            "Reglas obligatorias:",
            "- El \"máx N/semana\" de cada plato es solo un máximo: puedes usarlo menos veces o ninguna, pero nunca más de N.",
            "- Si un plato aparece más de una vez en la semana, dos apariciones seguidas suyas deben estar como mucho a 2 días de distancia (cocina en cantidad grande y come las sobras pronto). Si no puedes respetarlo, usa ese plato solo una vez.",
            "- Respeta el momento: \"comida\" solo en comida, \"cena\" solo en cena, \"ambas\" en cualquiera.",
            "- El mismo día, la comida y la cena no pueden compartir ninguna categoría (nada de pasta con pasta, ni dos ensaladas, etc.).",
        ]
        if !fixed.isEmpty {
            let desc = fixed.map { s -> [String: Any] in
                let name: String
                if s.dishId == SpecialSlot.fuera { name = "Comer fuera" }
                else if s.dishId == SpecialSlot.sobras { name = "Sobras" }
                else if s.dishId == SpecialSlot.vacio { name = "Vacío intencional" }
                else { name = byId[s.dishId]?.name ?? s.dishId }
                return ["day": s.day, "meal": s.meal, "dishId": s.dishId, "name": name]
            }
            let json = (try? JSONSerialization.data(withJSONObject: desc)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            lines.append("- Turnos ya decididos e intocables (día 0 = lunes). Respeta exactamente estos ids y completa SOLO los demás: " + json)
        }
        lines.append(contentsOf: [
            "- El menú debe ser variado y equilibrado a lo largo de la semana.",
            "- Sigue las recomendaciones de alimentación saludable de la guía oficial española (Ministerio de Sanidad): a lo largo de la semana, pescado 3-4 veces, legumbres 2-4 veces, carne magra o ave y huevos 3-4 veces cada uno, con la carne roja y procesada lo mínimo, y verdura o ensalada en la mayoría de comidas y cenas. Úsalo como guía cuando la lista de platos lo permita; si los platos no dan para ello, no pasa nada.",
            "- Cenas algo más ligeras que la comida: prefiere para la cena platos con verdura, pescado, huevo o ensalada, y deja la pasta, el arroz y la patata sobre todo para la comida. Es solo una preferencia suave: si los gustos aprendidos (más abajo) o la lista de platos piden otra cosa, manda lo que él prefiere.",
        ])
        if !recent.isEmpty {
            lines.append("- Evita en lo posible estos platos, que salieron en semanas recientes: \(recent.joined(separator: ", ")).")
        }
        if !likes.isEmpty {
            lines.append("- Preferencias aprendidas: le gustan y conviene priorizar: \(likes.joined(separator: ", ")).")
        }
        if !dislikes.isEmpty {
            lines.append("- Suele cambiar estos platos por otros, ponlos menos: \(dislikes.joined(separator: ", ")).")
        }
        lines.append("Platos disponibles:")
        lines.append(contentsOf: available)
        lines.append("Responde ÚNICAMENTE con JSON válido, sin texto adicional, con esta forma: {\"menu\":[{\"day\":0,\"lunch\":\"id\",\"dinner\":\"id\"}, ..., {\"day\":6,\"lunch\":\"id\",\"dinner\":\"id\"}]} donde day 0 es lunes y day 6 es domingo. En los turnos ya decididos conserva exactamente su id, incluidos los ids especiales de comer fuera y sobras.")
        return lines.joined(separator: " ")
    }

    /// V1: valida la respuesta de la IA
    static func validateMenu(_ json: [String: Any], dishes: [Dish], weekKey: String, fixed: [Slot], history: [WeekMenu]) -> [Slot]? {
        guard let rows = json["menu"] as? [[String: Any]], rows.count == 7 else { return nil }
        let byId = Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0) })
        let bias = Engine.mealBias(history)
        let eligible = Engine.eligible(dishes, weekKey)
        func fixedSlot(_ day: Int, _ meal: String) -> Slot? {
            fixed.first { $0.day == day && $0.meal == meal }
        }
        guard Set(rows.compactMap { $0["day"] as? Int }).count == 7 else { return nil }
        var out: [Slot] = []
        for row in rows {
            guard let day = row["day"] as? Int, day >= 0, day <= 6 else { return nil }
            for (meal, key) in [("comida", "lunch"), ("cena", "dinner")] {
                if let f = fixedSlot(day, meal) {
                    out.append(f)
                    continue
                }
                guard let id = row[key] as? String, id != "fuera", let dish = byId[id] else { return nil }
                guard eligible.contains(where: { $0.id == id }) else { return nil }
                guard dish.meal == "ambas" || dish.meal == meal else { return nil }
                if let b = bias[id], b != meal { return nil }
                out.append(Slot(day: day, meal: meal, dishId: id))
            }
        }
        var byDish: [String: [Int]] = [:]
        for s in out where !SpecialSlot.isSpecial(s.dishId) {
            byDish[s.dishId, default: []].append(s.day)
        }
        for (id, days) in byDish {
            guard let dish = byId[id] else { return nil }
            let fixedCount = fixed.filter { $0.dishId == id }.count
            if days.count > max(dish.timesPerWeek, fixedCount) { return nil }
            let sorted = days.sorted()
            for i in 1..<sorted.count {
                if sorted[i] - sorted[i - 1] > 2 {
                    let bothFixed = fixed.contains { $0.dishId == id && $0.day == sorted[i] }
                        && fixed.contains { $0.dishId == id && $0.day == sorted[i - 1] }
                    if !bothFixed { return nil }
                }
            }
        }
        for day in 0..<7 {
            let lunch = out.first { $0.day == day && $0.meal == "comida" }
            let dinner = out.first { $0.day == day && $0.meal == "cena" }
            let bothFixed = fixedSlot(day, "comida") != nil && fixedSlot(day, "cena") != nil
            if !bothFixed, let l = lunch, let d = dinner {
                let lunchTags = Set(byId[l.dishId]?.tags ?? [])
                if (byId[d.dishId]?.tags ?? []).contains(where: { lunchTags.contains($0) }) { return nil }
            }
        }
        return out
    }

    /// j0: genera un menú con IA probando modelos
    static func generateMenu(apiKey: String, dishes: [Dish], history: [WeekMenu], learning: Learning,
                             weekKey: String, fixed: [Slot]) throws -> WeekMenu {
        let prompt = menuPrompt(dishes: dishes, history: history, learning: learning, weekKey: weekKey, fixed: fixed)
        var lastError: Error = GeminiError.connection("La IA no respondió")
        let models = try discoverModels(apiKey)
        for model in models.prefix(6) {
            do {
                let text = try call(model: model, key: apiKey, prompt: prompt)
                if let json = parseJSON(text),
                   let slots = validateMenu(json, dishes: dishes, weekKey: weekKey, fixed: fixed, history: history) {
                    return WeekMenu(weekKey: weekKey, slots: slots, createdAt: Engine.isoNow(), source: "ia")
                }
                lastError = GeminiError.invalidJSON(model)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    static let ingredientBlocklist = try! NSRegularExpression(
        pattern: "^(aceite|sal|pimienta|vinagre|agua|azúcar|azucar|especias?|pimentón|pimenton|curry|orégano|oregano|comino|caldo|harina|ajo en polvo|perejil|laurel)\\b",
        options: .caseInsensitive)

    /// Z1
    static func cleanIngredients(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for item in raw {
            let n = item.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if n.isEmpty || n.count > 40 || seen.contains(n) { continue }
            if ingredientBlocklist.firstMatch(in: n, range: NSRange(n.startIndex..., in: n)) != nil { continue }
            seen.insert(n)
            out.append(n)
        }
        return Array(out.prefix(12))
    }

    /// R0: ingredientes de un plato con IA
    static func generateIngredients(apiKey: String, dishName: String) throws -> [String] {
        let prompt = [
            "Plato: \"\(dishName)\".",
            "Piensa en una receta estándar y habitual de este plato (la versión tradicional más común en España) y devuelve los ingredientes principales que habría que comprar para hacerla (entre 3 y 12), en español, en minúsculas, con nombres de supermercado simples (por ejemplo \"pechuga de pollo\", \"tomate triturado\", \"champiñones\").",
            "Es mejor pasarse que quedarse corto: si dudas entre incluir un ingrediente o no, inclúyelo, también los secundarios y acompañamientos que lleva la receta (verduras, lácteos, huevos, pan rallado, etc.).",
            "No incluyas aceite, sal, pimienta, especias, hierbas, caldo, agua, azúcar, vinagre ni harina.",
            "Responde ÚNICAMENTE con JSON válido: {\"ingredientes\":[\"...\"]}",
        ].joined(separator: " ")
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": ["ingredientes": ["type": "ARRAY", "items": ["type": "STRING"], "minItems": 3, "maxItems": 12]],
            "required": ["ingredientes"],
        ]
        var lastError: Error = GeminiError.connection("La IA no respondió")
        let models = try discoverModels(apiKey)
        for model in models.prefix(6) {
            do {
                let text = try call(model: model, key: apiKey, prompt: prompt, schema: schema)
                if let json = parseJSON(text),
                   let raw = json["ingredientes"] as? [String] {
                    let cleaned = cleanIngredients(raw)
                    if !cleaned.isEmpty { return cleaned }
                }
                lastError = GeminiError.invalidJSON(model)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    /// mgProbeDynamic: probar la clave
    static func testKey(_ key: String) throws -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw GeminiError.noKey }
        var report = ["Prueba de Gemini · app nativa"]
        let models = try discoverModels(trimmed, refresh: true)
        report.append("models.list: OK. Modelos de texto con generateContent: " + models.joined(separator: ", "))
        let schema: [String: Any] = ["type": "OBJECT", "properties": ["ok": ["type": "BOOLEAN"]], "required": ["ok"]]
        for model in models.prefix(6) {
            do {
                let text = try call(model: model, key: trimmed, prompt: "Devuelve este JSON, sin más texto: {\"ok\":true}", schema: schema)
                if parseJSON(text)?["ok"] as? Bool == true {
                    report.append(model + ": OK. Clave comprobada; Gemini responde. La cuota puede cambiar después.")
                    modelCache = (trimmed, Date(), [model] + models.filter { $0 != model })
                    return report.joined(separator: "\n")
                }
                report.append(model + ": La respuesta no contiene la confirmación esperada.")
            } catch {
                report.append(model + ": " + error.localizedDescription)
            }
        }
        throw GeminiError.connection(report.joined(separator: "\n") + "\nNingún intento funcionó.")
    }
}

// MARK: - URLSession síncrona (la lógica de generación ya corre en background)

extension URLSession {
    func synchronousDataTask(with request: URLRequest) throws -> (Data, URLResponse) {
        var result: Result<(Data, URLResponse), Error>?
        let semaphore = DispatchSemaphore(value: 0)
        let task = dataTask(with: request) { data, response, error in
            if let data = data, let response = response {
                result = .success((data, response))
            } else {
                result = .failure(error ?? GeminiError.connection("No se pudo conectar con Gemini. Revisa la conexión o las restricciones de la clave."))
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        return try result!.get()
    }
}
