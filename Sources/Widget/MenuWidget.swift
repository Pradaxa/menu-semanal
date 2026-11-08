import WidgetKit
import SwiftUI

struct MenuProvider: TimelineProvider {
    private func entry() -> MenuEntry {
        let key = Week.currentKey
        return MenuEntry(date: Date(), days: SharedMenuReader.days(for: key), weekKey: key)
    }

    func placeholder(in context: Context) -> MenuEntry {
        entry()
    }

    func getSnapshot(in context: Context, completion: @escaping (MenuEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MenuEntry>) -> Void) {
        let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400)
        completion(Timeline(entries: [entry()], policy: .after(tomorrow)))
    }
}

struct MenuWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MenuWidget", provider: MenuProvider()) { entry in
            MenuWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetContainerBackground()
                }
        }
        .configurationDisplayName("Menú semanal")
        .description("Tu menú de lunes a domingo, de un vistazo.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WidgetContainerBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if scheme == .dark {
            WidgetPalette.backgroundDark
        } else {
            WidgetPalette.backgroundLight
        }
    }
}

@main
struct MenuWidgetBundle: WidgetBundle {
    var body: some Widget {
        MenuWidget()
    }
}
