import WidgetKit
import SwiftUI

struct MenuEntry: TimelineEntry {
    let date: Date
    let week: [DayMenu]
}

struct MenuProvider: TimelineProvider {
    private func entry() -> MenuEntry {
        MenuEntry(date: Date(), week: MenuStore.load())
    }

    func placeholder(in context: Context) -> MenuEntry {
        MenuEntry(date: Date(), week: MenuStore.sampleWeek)
    }

    func getSnapshot(in context: Context, completion: @escaping (MenuEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MenuEntry>) -> Void) {
        let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400)
        completion(Timeline(entries: [entry()], policy: .after(tomorrow)))
    }
}

struct MenuWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: MenuEntry

    private var todayIndex: Int {
        (Calendar.current.component(.weekday, from: entry.date) + 5) % 7
    }

    var body: some View {
        switch family {
        case .systemSmall:
            todayView
        default:
            weekView
        }
    }

    private var weekView: some View {
        HStack(spacing: 6) {
            ForEach(Array(entry.week.enumerated()), id: \.offset) { i, day in
                VStack(spacing: 4) {
                    Text(day.short)
                        .font(.caption2.bold())
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(i == todayIndex ? Color.green : Color.clear))
                        .foregroundStyle(i == todayIndex ? Color.white : Color.secondary)
                    Text(day.lunch)
                        .font(.system(size: 8))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                    Divider()
                    Text(day.dinner)
                        .font(.system(size: 8))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(i == todayIndex ? Color.green.opacity(0.15) : Color.clear)
                )
            }
        }
    }

    private var todayView: some View {
        let day = entry.week[todayIndex]
        return VStack(alignment: .leading, spacing: 6) {
            Text("Hoy · \(day.day)")
                .font(.caption.bold())
            Text(day.lunch)
                .font(.caption2)
                .lineLimit(3)
            Divider()
            Text(day.dinner)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MenuWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MenuWidget", provider: MenuProvider()) { entry in
            MenuWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Menú semanal")
        .description("Tu menú de lunes a domingo, de un vistazo.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct MenuWidgetBundle: WidgetBundle {
    var body: some Widget {
        MenuWidget()
    }
}
