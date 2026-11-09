import SwiftUI

@main
struct QueVerApp: App {
    @StateObject private var store = QVStore.shared

    /// Para capturas automáticas en CI: -screenshot <tab>
    private var screenshotTarget: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screenshot"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    private var selftest: Bool {
        ProcessInfo.processInfo.arguments.contains("-selftest")
    }

    var body: some Scene {
        WindowGroup {
            if selftest {
                SelfTestRunnerView()
            } else {
                RootView(screenshotTarget: screenshotTarget)
                    .environmentObject(store)
                    .preferredColorScheme(store.darkOverride.map { $0 ? .dark : .light })
            }
        }
    }
}

struct SelfTestRunnerView: View {
    var body: some View {
        Text("selftest")
            .onAppear {
                let ok = SelfTest.run()
                print(ok ? "SELFTEST-PASS all" : "SELFTEST-FAIL some")
            }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: QVStore
    @Environment(\.colorScheme) private var scheme
    var screenshotTarget: String?
    @State private var tab = 0

    var body: some View {
        ZStack {
            AppBackground()
            TabView(selection: $tab) {
                BuscarView()
                    .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
                    .tag(0)
                TopView()
                    .tabItem { Label("Top 10", systemImage: "trophy") }
                    .tag(1)
                ListaView()
                    .tabItem { Label("Mi lista", systemImage: "list.bullet") }
                    .tag(2)
                AjustesView()
                    .tabItem { Label("Ajustes", systemImage: "gearshape") }
                    .tag(3)
            }
            .tint(Color.accentScheme(scheme))
        }
        .onAppear {
            switch screenshotTarget {
            case "buscar": tab = 0
            case "top": tab = 1
            case "lista": tab = 2
            case "ajustes": tab = 3
            default: break
            }
        }
    }
}

// MARK: - Cabecera estilo web: "Que ver..? 🍿" + icono

struct QVHeader: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack {
            Text("Que ver..? 🍿")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .foregroundStyle(Color.ink(scheme))
            Spacer()
            Image(uiImage: appIcon())
                .resizable()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color(red: 0.259, green: 0.212, blue: 0.188).opacity(0.16), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, 4)
    }

    private func appIcon() -> UIImage {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last, let img = UIImage(named: name) {
            return img
        }
        return UIImage()
    }
}
