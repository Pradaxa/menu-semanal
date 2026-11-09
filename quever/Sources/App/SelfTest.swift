import Foundation

// MARK: - Pruebas automáticas de lógica (CI): se lanzan con -selftest y escriben SELFTEST-*

enum SelfTest {
    static var failures: [String] = []

    static func check(_ name: String, _ condition: Bool) {
        if condition {
            print("SELFTEST-OK \(name)")
        } else {
            print("SELFTEST-FAIL \(name)")
            failures.append(name)
        }
    }

    @MainActor
    static func run() -> Bool {
        // 1. Canonización de plataformas (como la web)
        check("canon-netflix-alias", Platforms.canon(shortName: "nfx", clearName: nil)?.id == "nfx")
        check("canon-max-clearname", Platforms.canon(shortName: "zzz", clearName: "HBO Max")?.id == "mxx")
        check("canon-movistar-plus", Platforms.canon(shortName: nil, clearName: "Movistar Plus+")?.id == "mp9")
        check("canon-movistar-packs-out", Platforms.canon(shortName: nil, clearName: "Movistar Ficción Total") == nil)
        check("canon-skyshowtime", Platforms.canon(shortName: nil, clearName: "SkyShowtime")?.id == "sst")
        check("canon-amazon-channel-out", Platforms.canon(shortName: nil, clearName: "HBO Max Amazon Channel")?.id == "mxx")

        // 2. titleKey (acentos, símbolos)
        check("titlekey-acentos", TextUtil.titleKey("El Niño y la Bestia!") == "el nino y la bestia")
        check("titlekey-vacio", TextUtil.titleKey("  ") == "")

        // 3. Levenshtein
        check("lev-identico", TextUtil.levenshtein("lupin", "lupin") == 0)
        check("lev-cercano", TextUtil.levenshtein("el padrino", "el padrino 2") == 2)

        // 4. PasteParser: lista numerada
        let paste1 = PasteParser.parse("Aquí tienes:\n1. El padrino (1972)\n2. **Cadena perpetua** — IMDb: 9.3\n- Dune: Parte dos\n3. El padrino (1972)")
        check("paste-dedup", paste1.count == 3)
        check("paste-ano", paste1.first?.year == 1972)
        check("paste-titulo-limpio", paste1.contains { $0.title == "Cadena perpetua" })
        check("paste-dune", paste1.contains { $0.title == "Dune: Parte dos" })

        // 5. PasteParser: tabla markdown
        let paste2 = PasteParser.parse("| # | Título | Año |\n|---|---|---|\n| 1 | Alien | 1979 |")
        check("paste-tabla", paste2.count == 1 && paste2[0].title == "Alien" && paste2[0].year == 1979)

        // 6. Store: marcas
        let store = QVStore.shared
        let movie = QVTitle(id: "tm1", type: "movie", title: "Prueba", plats: [
            PlatRef(id: "nfx", name: "Netflix", icon: "", mine: true),
        ])
        _ = store.mark(.pendiente, movie)
        check("store-pendiente", store.pendientes["tm1"] != nil)
        _ = store.mark(.vista, movie)
        check("store-vista-mueve", store.vistas["tm1"] != nil && store.pendientes["tm1"] == nil)
        check("store-watchedAt", store.vistas["tm1"]?.watchedAt != nil)
        _ = store.mark(.vista, movie)
        check("store-vista-toggle", store.vistas["tm1"] == nil)

        // 7. Store: temporadas
        let show = QVTitle(id: "ts1", type: "show", title: "Serie", seasonCount: 3)
        _ = store.setTemp(show, 2, kind: "pend")
        check("temp-pend", store.pendTemps["ts1"]?.temps == [2])
        _ = store.setTemp(show, 2, kind: "lola")
        check("temp-lola", store.pendTemps["ts1"]?.tempsLola == [2])
        check("temp-isLola", store.isLola("ts1"))
        _ = store.setTemp(show, 2, kind: "pend")
        check("temp-quitar", store.pendTemps["ts1"] == nil)

        // 8. Store: export/import JSON compatible con la web
        _ = store.mark(.pendiente, movie)
        let data = store.exportData()
        let roundtrip = (try? JSONDecoder().decode(StoreFile.self, from: data))
        check("export-roundtrip", roundtrip?.pendientes["tm1"] != nil)
        store.removeEverywhere("tm1")

        // 9. Snapshot del seed de la web se decodifica
        let seedJson = "{\"id\":\"tm9\",\"type\":\"movie\",\"title\":\"X\",\"year\":2001,\"plats\":[{\"id\":\"nfx\",\"name\":\"Netflix\",\"icon\":\"\",\"mine\":true}],\"imdb\":\"7.5\"}"
        let parsed = (try? JSONSerialization.jsonObject(with: Data(seedJson.utf8))) as? [String: Any]
        let seeded = parsed.flatMap { QVTitle(seedDict: $0) }
        check("seed-decode", seeded?.title == "X" && seeded?.imdb == 7.5 && seeded?.plats.first?.mine == true)

        // 10. Iconos de plataforma
        check("icon-url", Platforms.all[0].iconURL() == "https://images.justwatch.com/icon/207360008/s100/netflix.webp")

        return failures.isEmpty
    }
}
