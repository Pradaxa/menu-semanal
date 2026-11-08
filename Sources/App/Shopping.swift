import Foundation

// MARK: - Normalización de texto (idéntica a la web app)

enum TextNorm {
    /// Dt: minúsculas, sin acentos, solo a-z0-9 y espacios
    static func dt(_ s: String) -> String {
        let folded = s.decomposedStringWithCanonicalMapping
            .unicodeScalars
            .filter { !($0.value >= 0x0300 && $0.value <= 0x036F) }
        var out = String(String.UnicodeScalarView(folded)).lowercased()
        out = out.replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// D1: plural simple
    static func stem(_ w: String) -> String {
        if w.count > 4 && (w.hasSuffix("ones") || w.hasSuffix("ores")) { return String(w.dropLast(2)) }
        if w.count > 3 && w.hasSuffix("s") && !w.hasSuffix("ss") { return String(w.dropLast()) }
        return w
    }

    static let specialKeys: [String: String] = [
        "patata grande": "patata",
        "pasta corta": "pasta",
        "pimiento verde": "pimiento",
        "tomate cherry": "tomate cherry",
    ]

    /// Ct: clave canónica de ingrediente (mantiene la ñ)
    static func ct(_ s: String) -> String {
        var lowered = s.lowercased().trimmingCharacters(in: .whitespaces)
        lowered = lowered.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let marked = lowered.replacingOccurrences(of: "ñ", with: "\u{0001}")
        let stripped = marked.decomposedStringWithCanonicalMapping
            .unicodeScalars
            .filter { !($0.value >= 0x0300 && $0.value <= 0x036F) }
        let restored = String(String.UnicodeScalarView(stripped)).replacingOccurrences(of: "\u{0001}", with: "ñ")
        let key = restored.split(separator: " ").map { stem(String($0)) }.joined(separator: " ")
        return specialKeys[key] ?? key
    }

    /// fl: distancia de Levenshtein con corte
    static func levenshtein(_ a: String, _ b: String, _ max: Int = 3) -> Int {
        if a == b { return 0 }
        let ca = Array(a), cb = Array(b)
        if abs(ca.count - cb.count) > max { return max + 1 }
        var prev = Array(0...cb.count)
        var curr = Array(repeating: 0, count: cb.count + 1)
        for i in 1...ca.count {
            curr[0] = i
            for j in 1...cb.count {
                let cost = ca[i - 1] == cb[j - 1] ? 0 : 1
                curr[j] = Swift.min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[cb.count]
    }
}

// MARK: - Lista de la compra

struct ShoppingItem: Identifiable, Hashable {
    var key: String
    var label: String
    var variants: [String]
    var count: Int
    var id: String { key }
}

enum Shopping {
    static let sectionOrder = ["Fruta y verdura", "Carne y pescado", "Lácteos y huevos", "Despensa", "Hogar"]

    static let keywords: [String: String] = [
        "Fruta y verdura": "lechuga tomate zanahoria cebolla calabacin pimiento brocoli brecol espinaca berenjena pepino aguacate champinon champi seta ajo guisante haba patata limon lima naranja mandarina manzana pera platano banana fresa uva melon sandia melocoton kiwi cereza ciruela mango pina piña coliflor puerro calabaza esparrago apio rucula canonigo acelga col repollo remolacha nabo maiz perejil cilantro albahaca jengibre fruta verdura ensalada pisto",
        "Carne y pescado": "pollo pavo bacalao salmon caballa langostino gamba albondiga codillo carne ternera cerdo lomo cordero conejo jamon lacon panceta bacon atun pescado merluza sardina lubina dorada pulpo calamar mejillon almeja marisco salchicha chorizo hamburguesa pechuga filete costilla morcilla mortadela fiambre pato anchoa",
        "Lácteos y huevos": "huevo clara nata queso yogur leche mantequilla margarina requeson kefir mozzarella parmesano cuajada flan natillas",
        "Hogar": "papel servilleta detergente suavizante lavavajillas fregasuelos lejia bayeta estropajo esponja jabon champu gel desodorante dentifrico cepillo bolsa basura film aluminio pañal compresa algodon pilas bombilla vela insecticida limpiador",
    ]

    static let specialPatterns: [(NSRegularExpression, String)] = {
        let defs: [(String, String)] = [
            ("judias verdes", "Fruta y verdura"),
            ("tomate (triturado|frito|natural)|leche de coco|salsa|conserva|bote", "Despensa"),
            ("pasta de dientes|papel higienico|papel de cocina|papel de aluminio|bolsa de basura|film transparente", "Hogar"),
        ]
        return defs.compactMap { pat, section in
            guard let re = try? NSRegularExpression(pattern: pat) else { return nil }
            return (re, section)
        }
    }()

    static let keywordIndex: [(String, [String])] = keywords.map { section, list in
        (section, list.split(separator: " ").map { TextNorm.dt(String($0)) }.filter { !$0.isEmpty })
    }

    /// Gr: sección de un producto
    static func section(for name: String) -> String {
        let t = TextNorm.dt(name)
        for (re, section) in specialPatterns {
            if re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil { return section }
        }
        let words = t.split(separator: " ").map(String.init).filter { $0.count > 2 }
        let forms = words.map { w -> (t: String, ts: String) in
            (t: w, ts: w.count > 3 && w.hasSuffix("s") ? String(w.dropLast()) : w)
        }
        for (section, kws) in keywordIndex {
            if forms.contains(where: { f in kws.contains(f.t) || kws.contains(f.ts) }) { return section }
        }
        for (section, kws) in keywordIndex {
            let hit = forms.contains { f in
                f.t.count >= 5 && kws.contains { kw in kw.count >= 5 && TextNorm.levenshtein(f.ts, kw, 1) <= 1 }
            }
            if hit { return section }
        }
        return "Despensa"
    }

    /// q0: agrega los ingredientes del menú en items coherentes
    static func build(from menu: WeekMenu, dishes: [Dish]) -> [ShoppingItem] {
        let byId = Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0) })
        var map: [String: (variants: [String: Int], count: Int)] = [:]
        for slot in menu.slots where !SpecialSlot.isSpecial(slot.dishId) {
            var seenInSlot = Set<String>()
            for ing in byId[slot.dishId]?.ingredients ?? [] {
                let key = TextNorm.ct(ing)
                if key.isEmpty { continue }
                var entry = map[key] ?? (variants: [:], count: 0)
                entry.variants[ing, default: 0] += 1
                if !seenInSlot.contains(key) {
                    seenInSlot.insert(key)
                    entry.count += 1
                }
                map[key] = entry
            }
        }
        return map.map { key, entry in
            let variants = Array(entry.variants.keys)
            let best = variants.sorted { a, b in
                let aw = a.split(separator: " ").count, bw = b.split(separator: " ").count
                if aw != bw { return aw < bw }
                if a.count != b.count { return a.count > b.count }
                return a.localizedCompare(b) == .orderedAscending
            }.first ?? key
            let label = best.prefix(1).uppercased() + best.dropFirst()
            return ShoppingItem(key: key, label: label, variants: variants, count: entry.count)
        }.sorted { $0.label.localizedCompare($1.label) == .orderedAscending }
    }

    /// Agrupa items por sección en el orden fijo
    static func grouped(_ items: [ShoppingItem]) -> [(String, [ShoppingItem])] {
        var bySection: [String: [ShoppingItem]] = [:]
        for item in items {
            bySection[section(for: item.label), default: []].append(item)
        }
        return sectionOrder.compactMap { section in
            guard let items = bySection[section], !items.isEmpty else { return nil }
            return (section, items)
        }
    }
}

// MARK: - Adivinador offline de ingredientes y categorías

struct IngRule {
    let kw: String
    let ing: String
    let tags: String?
    let not: String?
}

struct GuessedDish {
    var ingredients: [String]
    var tags: [String]
    var recognized: Bool
}

enum IngredientGuesser {
    static let stopwords: Set<String> = ["rellena", "rellenas", "relleno", "rellenos", "con", "de", "del", "al", "a", "la", "el", "los", "las", "y", "e", "en", "o", "un", "una", "para", "sin", "estilo", "casero", "casera", "horno", "plancha", "asado", "asada", "guisado", "frito"]

    static func singular(_ w: String) -> String {
        w.count > 3 && w.hasSuffix("s") ? String(w.dropLast()) : w
    }

    /// k1: coincidencia tolerante de palabra
    static func wordMatch(_ a: String, _ t: String) -> Bool {
        if a == t || singular(a) == singular(t) { return true }
        if t.count >= 5 && a.count >= 4 && a.first == t.first {
            let tol = t.count >= 8 ? 2 : 1
            if TextNorm.levenshtein(a, t, tol) <= tol { return true }
            if a.count >= 5 && t.hasPrefix(a) && a.count >= t.count - 2 { return true }
        }
        return false
    }

    static let rules: [IngRule] = [
        IngRule(kw: "pollo|pechuga|pollito|ala|alitas|muslos", ing: "pechuga de pollo", tags: "pollo", not: nil),
        IngRule(kw: "pavo", ing: "pavo", tags: nil, not: nil),
        IngRule(kw: "milanesa", ing: "filetes de ternera|huevos|pan rallado", tags: "carne|huevo", not: nil),
        IngRule(kw: "cerdo|lomo|secreto|costilla|costillas", ing: "cerdo", tags: "carne", not: nil),
        IngRule(kw: "albondigas|albondiga", ing: "albóndigas|tomate triturado", tags: "carne", not: nil),
        IngRule(kw: "salchicha|salchichas", ing: "salchichas", tags: "carne", not: nil),
        IngRule(kw: "chorizo", ing: "chorizo", tags: "carne", not: nil),
        IngRule(kw: "lacon", ing: "lacón", tags: "carne", not: nil),
        IngRule(kw: "codillo", ing: "codillo de cerdo", tags: "carne", not: nil),
        IngRule(kw: "cordero", ing: "cordero", tags: "carne", not: nil),
        IngRule(kw: "conejo", ing: "conejo", tags: "carne", not: nil),
        IngRule(kw: "jamon cocido|york", ing: "jamón cocido", tags: nil, not: nil),
        IngRule(kw: "jamon", ing: "jamón serrano", tags: nil, not: nil),
        IngRule(kw: "bacon|panceta|carbonara", ing: "panceta", tags: "carne", not: nil),
        IngRule(kw: "morcilla", ing: "morcilla", tags: "carne", not: nil),
        IngRule(kw: "croquetas|croqueta", ing: "croquetas", tags: nil, not: nil),
        IngRule(kw: "callos", ing: "callos", tags: "carne", not: nil),
        IngRule(kw: "atun fresco|tataki|tartar de atun", ing: "atún fresco", tags: "pescado", not: nil),
        IngRule(kw: "atun", ing: "atún en lata", tags: nil, not: "fresco|tartar|tataki"),
        IngRule(kw: "tartar", ing: "aguacate|limón", tags: nil, not: nil),
        IngRule(kw: "salmon", ing: "lomos de salmón", tags: "pescado", not: nil),
        IngRule(kw: "bacalao", ing: "bacalao", tags: "pescado", not: nil),
        IngRule(kw: "merluza", ing: "merluza", tags: "pescado", not: nil),
        IngRule(kw: "caballa", ing: "caballa", tags: "pescado", not: nil),
        IngRule(kw: "sardina|sardinas", ing: "sardinas", tags: "pescado", not: nil),
        IngRule(kw: "lubina", ing: "lubina", tags: "pescado", not: nil),
        IngRule(kw: "dorada", ing: "dorada", tags: "pescado", not: nil),
        IngRule(kw: "besugo", ing: "besugo", tags: "pescado", not: nil),
        IngRule(kw: "rape", ing: "rape", tags: "pescado", not: nil),
        IngRule(kw: "rodaballo", ing: "rodaballo", tags: "pescado", not: nil),
        IngRule(kw: "trucha", ing: "trucha", tags: "pescado", not: nil),
        IngRule(kw: "pescadilla", ing: "pescadilla", tags: "pescado", not: nil),
        IngRule(kw: "boquerones|boqueron", ing: "boquerones", tags: "pescado", not: nil),
        IngRule(kw: "anchoa|anchoas", ing: "anchoas", tags: "pescado", not: nil),
        IngRule(kw: "pescado", ing: "pescado", tags: "pescado", not: nil),
        IngRule(kw: "gambas|gamba", ing: "gambas", tags: "marisco", not: nil),
        IngRule(kw: "langostinos|langostino", ing: "langostinos", tags: "marisco", not: nil),
        IngRule(kw: "calamares|calamar", ing: "calamares", tags: "marisco", not: nil),
        IngRule(kw: "chipirones|chipiron", ing: "chipirones", tags: "marisco", not: nil),
        IngRule(kw: "sepia", ing: "sepia", tags: "marisco", not: nil),
        IngRule(kw: "pulpo", ing: "pulpo|patatas", tags: "marisco|patata", not: nil),
        IngRule(kw: "mejillones|mejillon", ing: "mejillones", tags: "marisco", not: nil),
        IngRule(kw: "almejas|almeja", ing: "almejas", tags: "marisco", not: nil),
        IngRule(kw: "cigalas|cigala", ing: "cigalas", tags: "marisco", not: nil),
        IngRule(kw: "marisco|mariscada", ing: "marisco", tags: "marisco", not: nil),
        IngRule(kw: "ceviche", ing: "pescado blanco|limón|cebolla", tags: "pescado", not: nil),
        IngRule(kw: "claras", ing: "claras de huevo", tags: "huevo", not: nil),
        IngRule(kw: "queso|quesos|gratinado|gratinada|parmesano", ing: "queso rallado", tags: nil, not: nil),
        IngRule(kw: "nata|cremosa|cremoso", ing: "nata para cocinar", tags: nil, not: nil),
        IngRule(kw: "yogur|tzatziki", ing: "yogur natural", tags: nil, not: nil),
        IngRule(kw: "cheesecake|tarta de queso", ing: "queso crema|galletas|nata para cocinar", tags: nil, not: nil),
        IngRule(kw: "garbanzos|garbanzo", ing: "garbanzos", tags: "legumbre", not: nil),
        IngRule(kw: "lentejas|lenteja", ing: "lentejas|patatas|zanahoria", tags: "legumbre", not: nil),
        IngRule(kw: "fabada", ing: "alubias|chorizo|morcilla|panceta", tags: "legumbre|carne", not: nil),
        IngRule(kw: "alubias|alubia|fabes", ing: "alubias", tags: "legumbre", not: nil),
        IngRule(kw: "judias verdes", ing: "judías verdes", tags: "verdura", not: nil),
        IngRule(kw: "habas|haba", ing: "habas", tags: "legumbre", not: nil),
        IngRule(kw: "hummus|humus", ing: "hummus", tags: "legumbre", not: nil),
        IngRule(kw: "potaje", ing: "verduras variadas", tags: "legumbre|verdura", not: nil),
        IngRule(kw: "guiso|guisado|estofado|ragu", ing: "patatas|zanahorias", tags: nil, not: nil),
        IngRule(kw: "falafel", ing: "falafel", tags: nil, not: nil),
        IngRule(kw: "tofu", ing: "tofu", tags: nil, not: nil),
        IngRule(kw: "arroz negro", ing: "arroz|calamares", tags: "arroz|marisco", not: nil),
        IngRule(kw: "arroz caldoso|arroz meloso", ing: "arroz|marisco", tags: "arroz|marisco", not: nil),
        IngRule(kw: "arroz con leche", ing: "arroz|leche|limón", tags: "arroz", not: nil),
        IngRule(kw: "paella", ing: "arroz|pollo|judías verdes", tags: "arroz|pollo|verdura", not: nil),
        IngRule(kw: "risotto", ing: "arroz|champiñones|queso parmesano", tags: "arroz|verdura", not: nil),
        IngRule(kw: "fideua", ing: "fideos|gambas|calamares", tags: "pasta|marisco", not: nil),
        IngRule(kw: "arroz|chaufa|tres delicias", ing: "arroz", tags: "arroz", not: nil),
        IngRule(kw: "quinoa", ing: "quinoa", tags: nil, not: nil),
        IngRule(kw: "cuscus", ing: "cuscús", tags: nil, not: nil),
        IngRule(kw: "bulgur", ing: "bulgur", tags: nil, not: nil),
        IngRule(kw: "noquis|ñoquis", ing: "ñoquis", tags: "pasta", not: nil),
        IngRule(kw: "pad thai", ing: "fideos de arroz|gambas|huevos", tags: "pasta|marisco|huevo", not: nil),
        IngRule(kw: "ramen", ing: "fideos ramen|huevos|pechuga de pollo", tags: "pasta|huevo|pollo", not: nil),
        IngRule(kw: "fideos", ing: "fideos", tags: "pasta", not: nil),
        IngRule(kw: "pizza", ing: "masa de pizza|tomate triturado|queso mozzarella", tags: nil, not: nil),
        IngRule(kw: "empanadillas|empanadilla", ing: "empanadillas", tags: nil, not: nil),
        IngRule(kw: "quesadilla|quesadillas", ing: "tortillas de trigo|queso rallado", tags: nil, not: nil),
        IngRule(kw: "pita|pitas", ing: "pan de pita", tags: nil, not: nil),
        IngRule(kw: "sandwich mixto", ing: "pan de molde|jamón cocido|queso", tags: nil, not: nil),
        IngRule(kw: "sandwich|sandwiches", ing: "pan de molde", tags: nil, not: nil),
        IngRule(kw: "bocadillo|bocata", ing: "pan de bocadillo", tags: nil, not: nil),
        IngRule(kw: "tostada|tostadas", ing: "pan", tags: nil, not: nil),
        IngRule(kw: "nachos", ing: "nachos|queso rallado", tags: nil, not: nil),
        IngRule(kw: "migas", ing: "pan|chorizo|panceta", tags: "carne", not: nil),
        IngRule(kw: "gyozas|gyoza", ing: "gyozas", tags: nil, not: nil),
        IngRule(kw: "rollitos", ing: "rollitos de primavera", tags: nil, not: nil),
        IngRule(kw: "pancakes|tortitas americanas", ing: "huevos|leche", tags: nil, not: nil),
        IngRule(kw: "gazpacho", ing: "tomates|pepino|pimiento|pan", tags: nil, not: nil),
        IngRule(kw: "salmorejo", ing: "tomates|pan|huevos|jamón serrano", tags: nil, not: nil),
        IngRule(kw: "crema", ing: "nata para cocinar", tags: nil, not: nil),
        IngRule(kw: "sopa", ing: "fideos", tags: "pasta", not: nil),
        IngRule(kw: "caldo", ing: "", tags: nil, not: nil),
        IngRule(kw: "pesto", ing: "pesto", tags: nil, not: "pisto"),
        IngRule(kw: "poke", ing: "arroz|lomos de salmón|aguacate", tags: "arroz|pescado", not: nil),
        IngRule(kw: "ensalada|ensaladas", ing: "lechuga|tomate", tags: "ensalada", not: nil),
        IngRule(kw: "lechuga", ing: "lechuga", tags: nil, not: nil),
        IngRule(kw: "tomate|tomates", ing: "tomate", tags: nil, not: nil),
        IngRule(kw: "brecol|brocoli|brocolis", ing: "brócoli", tags: "verdura", not: nil),
        IngRule(kw: "espinacas|espinaca", ing: "espinacas", tags: "verdura", not: nil),
        IngRule(kw: "calabacin|calabacines", ing: "calabacín", tags: "verdura", not: nil),
        IngRule(kw: "calabaza", ing: "calabaza", tags: "verdura", not: nil),
        IngRule(kw: "berenjena|berenjenas", ing: "berenjenas", tags: "verdura", not: nil),
        IngRule(kw: "setas|seta|hongos", ing: "setas", tags: "verdura", not: nil),
        IngRule(kw: "pimiento|pimientos", ing: "pimiento", tags: "verdura", not: nil),
        IngRule(kw: "zanahoria|zanahorias", ing: "zanahoria", tags: "verdura", not: nil),
        IngRule(kw: "cebolla|cebollas", ing: "cebolla", tags: nil, not: nil),
        IngRule(kw: "pepino", ing: "pepino", tags: nil, not: nil),
        IngRule(kw: "aguacate|guacamole", ing: "aguacate", tags: nil, not: nil),
        IngRule(kw: "coliflor", ing: "coliflor", tags: "verdura", not: nil),
        IngRule(kw: "esparragos|esparrago", ing: "espárragos", tags: "verdura", not: nil),
        IngRule(kw: "puerro|puerros", ing: "puerro", tags: "verdura", not: nil),
        IngRule(kw: "guisantes|guisante", ing: "guisantes", tags: "verdura", not: nil),
        IngRule(kw: "repollo|lombarda", ing: "repollo", tags: "verdura", not: nil),
        IngRule(kw: "maiz", ing: "maíz dulce", tags: nil, not: nil),
        IngRule(kw: "brocheta|brochetas", ing: "pimiento|cebolla", tags: nil, not: nil),
        IngRule(kw: "patata|patatas|papas|cachelos", ing: "patatas", tags: "patata", not: nil),
        IngRule(kw: "puré|pure", ing: "patatas", tags: nil, not: nil),
        IngRule(kw: "macedonia|ensalada de frutas", ing: "fruta variada", tags: nil, not: nil),
        IngRule(kw: "curry", ing: "leche de coco", tags: nil, not: nil),
    ]

    /// zu: adivina ingredientes y categorías a partir del nombre del plato
    static func guess(_ dishName: String) -> GuessedDish {
        let t = TextNorm.dt(dishName)
        let words = t.split(separator: " ").map(String.init).filter { $0.count > 1 }
        var ingredients: [String] = []
        var tags: [String] = []
        var recognized = false
        var seen = Set<String>()

        func addIng(_ raw: String) {
            let key = TextNorm.ct(raw)
            if !seen.contains(key) {
                seen.insert(key)
                ingredients.append(raw)
            }
        }

        for rule in rules {
            if let notw = rule.not, notw.split(separator: "|").contains(where: { t.contains(TextNorm.dt(String($0))) }) { continue }
            var matched = false
            for kw in rule.kw.split(separator: "|").map(String.init) {
                let norm = TextNorm.dt(kw)
                if norm.contains(" ") {
                    if t.contains(norm) {
                        matched = true
                    }
                    continue
                }
                for w in words where !stopwords.contains(w) {
                    if wordMatch(w, norm) {
                        matched = true
                        break
                    }
                }
                if matched { break }
            }
            if matched {
                recognized = true
                for ing in rule.ing.split(separator: "|").map(String.init) where !ing.isEmpty { addIng(ing) }
                if let tagList = rule.tags {
                    for tag in tagList.split(separator: "|").map(String.init) where !tags.contains(tag) { tags.append(tag) }
                }
            }
        }

        if seen.contains("patata") && t.contains("ensaladilla") {
            for target in ["lechuga", "tomate"] {
                if let idx = ingredients.firstIndex(where: { TextNorm.ct($0) == target }) { ingredients.remove(at: idx) }
            }
        }
        if seen.contains("tomate triturado") {
            if let idx = ingredients.firstIndex(where: { TextNorm.ct($0) == "tomate" }) { ingredients.remove(at: idx) }
        }
        if t.contains("brecol") && t.contains("lacon") {
            ingredients.removeAll { TextNorm.ct($0) == "patata" }
        }
        return GuessedDish(ingredients: Array(ingredients.prefix(7)), tags: tags, recognized: recognized)
    }
}
