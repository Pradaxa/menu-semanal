import SwiftUI
import WidgetKit

@main
struct MenuSemanalApp: App {
    @StateObject private var store = AppStore.shared

    /// Para capturas automáticas en el simulador de CI: -screenshot <tab>
    private var screenshotTarget: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-screenshot"), args.count > idx + 1 else { return nil }
        return args[idx + 1]
    }

    /// CI: -selftest ejecuta las pruebas de lógica y termina
    private var isSelfTest: Bool {
        ProcessInfo.processInfo.arguments.contains("-selftest")
    }

    var body: some Scene {
        WindowGroup {
            if isSelfTest {
                SelfTestRunnerView()
            } else {
                RootView(screenshotTarget: screenshotTarget)
                    .environmentObject(store)
                    .preferredColorScheme(store.darkOverride.map { $0 ? .dark : .light })
            }
        }
    }
}

struct RootView: View {
    let screenshotTarget: String?
    @EnvironmentObject private var store: AppStore
    @State private var tab = 0

    var body: some View {
        Group {
            if let target = screenshotTarget, target.hasPrefix("widget-") {
                WidgetPreviewScreen(family: target)
            } else {
                TabView(selection: $tab) {
                    MenuView()
                        .tabItem { Label("Menú", systemImage: "calendar") }
                        .tag(0)
                    DishesView()
                        .tabItem { Label("Platos", systemImage: "fork.knife") }
                        .tag(1)
                    ShoppingView()
                        .tabItem { Label("Compra", systemImage: "cart") }
                        .tag(2)
                    SettingsView()
                        .tabItem { Label("Ajustes", systemImage: "gearshape") }
                        .tag(3)
                }
                .tint(Color(red: 0.451, green: 0.659, blue: 0.604))
            }
        }
        .onAppear {
            switch screenshotTarget {
            case "menu": tab = 0
            case "platos": tab = 1
            case "compra": tab = 2
            case "ajustes": tab = 3
            default: break
            }
        }
    }
}

/// Ejecuta el self-test en CI y cierra la app
struct SelfTestRunnerView: View {
    var body: some View {
        Color.clear
            .onAppear {
                DispatchQueue.global(qos: .userInitiated).async {
                    let ok = SelfTest.run()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        exit(ok ? 0 : 1)
                    }
                }
            }
    }
}

/// Previsualización del widget a tamaño exacto, solo para capturas de CI
struct WidgetPreviewScreen: View {
    let family: String
    @Environment(\.colorScheme) private var scheme

    private var days: [WidgetDay] {
        let stored = SharedMenuReader.days(for: Week.currentKey)
        let hasData = stored.contains { !$0.lunch.isEmpty || !$0.dinner.isEmpty }
        return hasData ? stored : Self.sampleDays
    }

    var body: some View {
        let entry = MenuEntry(date: Date(), days: days, weekKey: Week.currentKey)
        ZStack {
            AppBackground()
            VStack(spacing: 20) {
                switch family {
                case "widget-small":
                    MenuWidgetView(entry: entry, familyOverride: .systemSmall)
                        .frame(width: 155, height: 155)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                case "widget-large":
                    MenuWidgetView(entry: entry, familyOverride: .systemLarge)
                        .frame(width: 329, height: 345)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                default:
                    MenuWidgetView(entry: entry, familyOverride: .systemMedium)
                        .frame(width: 329, height: 155)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
        }
    }

    /// Semana de ejemplo solo para capturas de CI (cuando aún no hay menú)
    private static let sampleDays: [WidgetDay] = [
        WidgetDay(dayIndex: 0, lunch: "Pollo asado", dinner: "Ensalada de tomate con hummus"),
        WidgetDay(dayIndex: 1, lunch: "Ñoquis bolognesa", dinner: "Tortilla de claras"),
        WidgetDay(dayIndex: 2, lunch: "Habas con curry de gambas", dinner: "Salmón y ensalada"),
        WidgetDay(dayIndex: 3, lunch: "Albóndigas con arroz", dinner: "Brécol con huevo cocido"),
        WidgetDay(dayIndex: 4, lunch: "Pasta carbonara", dinner: "Fajitas"),
        WidgetDay(dayIndex: 5, lunch: "Comer fuera", dinner: "Pollo en pita"),
        WidgetDay(dayIndex: 6, lunch: "Codillo al horno", dinner: "Sobras"),
    ]
}
