import SwiftUI

// MARK: - Tab Top 10: lo más visto por plataforma (JustWatch España), caché de 12 h

struct TopView: View {
    @EnvironmentObject private var store: QVStore
    @Environment(\.colorScheme) private var scheme
    @AppStorage("qv-top-kind") private var kind: String = "movie"
    @AppStorage("qv-top-plat") private var plat: String = "nfx"
    @State private var lists: [String: [QVTitle]] = [:]
    @State private var loading = false
    @State private var failed = false
    @State private var selected: QVTitle?
    @State private var prefetched = false

    private var key: String { "\(plat):\(kind)" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    QVHeader()
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Button { setKind("movie") } label: { Text("🎬 Películas") }
                                    .buttonStyle(ChipStyle(isOn: kind == "movie"))
                                Button { setKind("show") } label: { Text("📺 Series") }
                                    .buttonStyle(ChipStyle(isOn: kind == "show"))
                                Spacer()
                            }
                            Text("Tus plataformas")
                                .font(.system(size: 12, weight: .semibold))
                                .textCase(.uppercase)
                                .tracking(1.2)
                                .foregroundStyle(Color.ink2(scheme))
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 6)], spacing: 6) {
                                ForEach(Platforms.all, id: \.id) { p in
                                    Button { setPlat(p.id) } label: {
                                        HStack(spacing: 6) {
                                            PlatIcon(url: p.iconURL(), size: 16)
                                            Text(p.name)
                                        }
                                    }
                                    .buttonStyle(ChipStyle(isOn: plat == p.id))
                                }
                            }
                        }
                    }
                    listBody
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .sheet(item: $selected) { item in
                DetailView(item: item)
                    .environmentObject(store)
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                loadFromCache()
                if lists[key] == nil { fetch() }
                prefetchAll()
            }
        }
    }

    @ViewBuilder
    private var listBody: some View {
        if let list = lists[key] {
            GlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        PlatIcon(url: (Platforms.byId(plat) ?? Platforms.all[0]).iconURL(), size: 18)
                        Text((Platforms.byId(plat) ?? Platforms.all[0]).name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.ink(scheme))
                    }
                    .padding(.bottom, 8)
                    if list.isEmpty {
                        Text("Sin datos ahora mismo")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.ink2(scheme))
                    } else {
                        ForEach(Array(list.enumerated()), id: \.element.id) { idx, item in
                            Button { selected = item } label: {
                                TitleRow(item: item, rank: idx + 1)
                            }
                            .buttonStyle(SilentButtonStyle())
                            if idx < list.count - 1 { Divider().opacity(0.3) }
                        }
                    }
                }
            }
        } else if failed {
            GlassCard {
                Text("Sin datos ahora mismo")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.ink2(scheme))
                    .frame(maxWidth: .infinity)
            }
        } else {
            GlassCard { QVSpinner(text: "Cargando lo más visto…") }
        }
    }

    private func setKind(_ k: String) {
        guard k != kind else { return }
        kind = k
        failed = false
        if lists[key] == nil { fetch() }
    }

    private func setPlat(_ p: String) {
        guard p != plat else { return }
        plat = p
        failed = false
        if lists[key] == nil { fetch() }
    }

    private func fetch() {
        let k = key
        let p = Platforms.byId(plat) ?? Platforms.all[0]
        loading = true
        Task {
            do {
                let list = try await JustWatch.top(packages: p.aliases, kind: kind)
                lists[k] = list
                saveCache(k, list)
            } catch {
                if lists[k] == nil { failed = true }
            }
            loading = false
        }
    }

    /// Precarga el resto de plataformas en segundo plano, espaciadas como en la web.
    private func prefetchAll() {
        guard !prefetched else { return }
        prefetched = true
        Task {
            let other = kind == "show" ? "movie" : "show"
            var combos: [(QVPlatform, String)] = []
            for p in Platforms.all { combos.append((p, kind)) }
            for p in Platforms.all { combos.append((p, other)) }
            for (p, k) in combos {
                let ck = "\(p.id):\(k)"
                if lists[ck] != nil || cachedList(ck) != nil {
                    if lists[ck] == nil { lists[ck] = cachedList(ck) }
                    try? await Task.sleep(nanoseconds: 60_000_000)
                    continue
                }
                if let list = try? await JustWatch.top(packages: p.aliases, kind: k) {
                    lists[ck] = list
                    saveCache(ck, list)
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }
    }

    // MARK: Caché de 12 h (como LS_TOP de la web)

    private struct TopCache: Codable {
        var ts: Double
        var list: [QVTitle]
    }

    private func loadFromCache() {
        if lists[key] == nil { lists[key] = cachedList(key) }
    }

    private func cachedList(_ k: String) -> [QVTitle]? {
        guard let data = UserDefaults.standard.data(forKey: StoreKeys.top),
              let all = try? JSONDecoder().decode([String: TopCache].self, from: data),
              let entry = all[k],
              Date().timeIntervalSince1970 * 1000 - entry.ts < 12 * 3600_000 else { return nil }
        return entry.list
    }

    private func saveCache(_ k: String, _ list: [QVTitle]) {
        var all: [String: TopCache] = [:]
        if let data = UserDefaults.standard.data(forKey: StoreKeys.top),
           let decoded = try? JSONDecoder().decode([String: TopCache].self, from: data) {
            all = decoded
        }
        all[k] = TopCache(ts: Date().timeIntervalSince1970 * 1000, list: list)
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: StoreKeys.top)
        }
    }
}
