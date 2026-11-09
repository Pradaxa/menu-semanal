import Foundation

// MARK: - "Pegar respuesta de Gemini": detecta títulos en listas numeradas, tablas o negritas
// Port fiel de parseGeminiPaste de la web. El texto nunca sale del dispositivo:
// solo los títulos detectados se consultan en el catálogo.

enum PasteParser {
    static func parse(_ text: String) -> [(title: String, year: Int?)] {
        let lines = text.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
        var out: [(String, Int?)] = []
        var seen = Set<String>()

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.range(of: "^\\|?\\s*:?-{3,}", options: .regularExpression) != nil { continue }

            let numbered = line.range(of: "^\\s*(?:#{1,6}\\s*)?(?:\\d+[.)]\\s*|[-*•]\\s+)", options: .regularExpression) != nil
            let bold = firstMatch(line, pattern: "\\*\\*([^*]+)\\*\\*")
            let yearMatch = firstMatch(line, pattern: "\\b((?:18|19|20)\\d{2})\\b")
            var title = ""

            if line.contains("|") {
                let cells = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if cells.count < 2 { continue }
                let joined = cells.joined(separator: " ")
                let headerish = joined.range(of: "t[ií]tulo|pel[ií]cula|puntuaci[oó]n|a[nñ]o|ranking", options: [.regularExpression, .caseInsensitive]) != nil
                let numberedRow = line.range(of: "^\\d+\\s*\\|", options: .regularExpression) != nil
                if headerish && !numberedRow { continue }
                let ci = cells[0].range(of: "^\\d+[.)]?$", options: .regularExpression) != nil ? 1 : 0
                title = cells[ci]
            } else if let b = bold, (numbered || yearMatch != nil || line.hasPrefix("**")) {
                title = b
            } else if numbered || line.range(of: "^#{1,6}\\s", options: .regularExpression) != nil
                        || (yearMatch != nil && line.range(of: "\\(\\s*(?:18|19|20)\\d{2}\\s*\\)", options: .regularExpression) != nil) {
                title = line
                    .replacingOccurrences(of: "^#{1,6}\\s*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "^(?:\\d+[.)]\\s*|[-*•]\\s+)", with: "", options: .regularExpression)
            } else {
                continue
            }

            title = title
                .replacingOccurrences(of: "\\*\\*|__|`", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            title = title
                .replacingOccurrences(of: "\\s*\\((?:18|19|20)\\d{2}\\)[\\s\\S]*$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s+(?:[-–—]|\\|)\\s+(?:(?:IMDb|nota|puntuaci[oó]n)\\s*[:\\-]?\\s*)?\\d[\\s\\S]*$", with: "", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: "\\s*[-–—:]\\s*(?:IMDb|nota|puntuaci[oó]n|g[eé]nero|director)[\\s\\S]*$", with: "", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: "\\s*\\b(?:IMDb|nota|puntuaci[oó]n)\\s*[:\\-]?[\\s\\S]*$", with: "", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: "^\\d+[.)]\\s*", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            title = title
                .replacingOccurrences(of: "^['\"“”]|['\"“”]$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "[.:;\\s]+$", with: "", options: .regularExpression)

            if title.isEmpty || title.count > 160 { continue }
            if title.range(of: "^(?:nota|a[nñ]o|g[eé]nero|director|sinopsis|por qu[eé]|IMDb|t[ií]tulo|pel[ií]cula|ranking|resumen|conclusi[oó]n|recomendaciones?)\\b\\s*:?$",
                           options: [.regularExpression, .caseInsensitive]) != nil { continue }

            let key = TextUtil.titleKey(title) + "|" + (yearMatch ?? "")
            if seen.contains(key) { continue }
            seen.insert(key)
            out.append((title, yearMatch.flatMap { Int($0) }))
        }
        return out
    }

    private static func firstMatch(_ s: String, pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }
}
