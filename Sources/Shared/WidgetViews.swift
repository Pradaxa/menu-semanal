import SwiftUI
import WidgetKit

// MARK: - Entrada y vistas del widget (compartidas: el widget las muestra y la app las previsualiza en CI)

public struct MenuEntry: TimelineEntry {
    public let date: Date
    public let days: [WidgetDay]
    public let weekKey: String

    public init(date: Date, days: [WidgetDay], weekKey: String) {
        self.date = date
        self.days = days
        self.weekKey = weekKey
    }
}

enum WidgetPalette {
    static func green(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.55, green: 0.82, blue: 0.60)
            : Color(red: 0.20, green: 0.46, blue: 0.27)
    }
    static let orange = Color(red: 0.96, green: 0.62, blue: 0.04)
    static let blue = Color(red: 0.36, green: 0.55, blue: 0.94)
    static func text(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.90, green: 0.92, blue: 0.91) : Color(red: 0.20, green: 0.18, blue: 0.19)
    }
    static func highlight(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.35, green: 0.62, blue: 0.42).opacity(0.55)
            : Color(red: 0.35, green: 0.58, blue: 0.40).opacity(0.50)
    }
    static var backgroundLight = LinearGradient(
        colors: [Color(red: 0.985, green: 0.980, blue: 0.965), Color(red: 0.955, green: 0.945, blue: 0.920)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static var backgroundDark = LinearGradient(
        colors: [Color(red: 0.067, green: 0.082, blue: 0.078), Color(red: 0.039, green: 0.047, blue: 0.043)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

public struct MenuWidgetView: View {
    @Environment(\.widgetFamily) private var envFamily
    @Environment(\.colorScheme) private var scheme
    public let entry: MenuEntry
    public var familyOverride: WidgetFamily?

    public init(entry: MenuEntry, familyOverride: WidgetFamily? = nil) {
        self.entry = entry
        self.familyOverride = familyOverride
    }

    private var family: WidgetFamily { familyOverride ?? envFamily }

    private var todayIndex: Int { Week.todayIndex(on: entry.date) }
    private var hasData: Bool { entry.days.contains { !$0.lunch.isEmpty || !$0.dinner.isEmpty } }

    public var body: some View {
        Group {
            if !hasData {
                emptyState
            } else {
                switch family {
                case .systemSmall: smallView
                case .systemLarge: largeView
                default: mediumView
                }
            }
        }
        .padding(family == .systemSmall ? 10 : 12)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(WidgetPalette.green(scheme)).frame(width: 7, height: 7)
                Text("Menú · \(Week.rangeLabel(for: entry.weekKey))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetPalette.green(scheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            Text("Abre la app Menú para generar tu semana")
                .font(.system(size: 12))
                .foregroundStyle(WidgetPalette.text(scheme).opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: Horizontal (1x2) — systemMedium

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 4)
            ForEach(entry.days, id: \.dayIndex) { day in
                mediumRow(day)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Circle().fill(WidgetPalette.green(scheme)).frame(width: 7, height: 7)
            Text("Menú · \(Week.rangeLabel(for: entry.weekKey))")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WidgetPalette.green(scheme))
            Spacer(minLength: 0)
        }
    }

    private func mediumRow(_ day: WidgetDay) -> some View {
        let isToday = day.dayIndex == todayIndex
        return HStack(spacing: 6) {
            Text(Week.dayShort[day.dayIndex])
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(isToday ? Color.white : WidgetPalette.green(scheme))
                .frame(width: 26, alignment: .leading)
            Text(day.lunch)
                .font(.system(size: 10.5))
                .foregroundStyle(isToday ? Color.white : WidgetPalette.text(scheme))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(day.dinner)
                .font(.system(size: 10.5))
                .foregroundStyle(isToday ? Color.white : WidgetPalette.text(scheme))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isToday ? WidgetPalette.highlight(scheme) : Color.clear)
        )
    }

    // MARK: Vertical (2x1) — systemLarge

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 8)
            ForEach(entry.days, id: \.dayIndex) { day in
                largeDay(day)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private func largeDay(_ day: WidgetDay) -> some View {
        let isToday = day.dayIndex == todayIndex
        return HStack(alignment: .center, spacing: 8) {
            Text(Week.dayShort[day.dayIndex])
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isToday ? Color.white : WidgetPalette.green(scheme))
                .frame(width: 30, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                mealLine(dot: WidgetPalette.orange, text: day.lunch, isToday: isToday)
                mealLine(dot: WidgetPalette.blue, text: day.dinner, isToday: isToday)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isToday ? WidgetPalette.highlight(scheme) : Color.clear)
        )
    }

    private func mealLine(dot: Color, text: String, isToday: Bool) -> some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(isToday ? Color.white : WidgetPalette.text(scheme))
                .lineLimit(1)
        }
    }

    // MARK: Hoy — systemSmall

    private var smallView: some View {
        let day = entry.days[todayIndex]
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(WidgetPalette.green(scheme)).frame(width: 7, height: 7)
                Text("Hoy · \(Week.dayShort[todayIndex])")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetPalette.green(scheme))
            }
            Spacer(minLength: 0)
            mealLine(dot: WidgetPalette.orange, text: day.lunch.isEmpty ? "—" : day.lunch, isToday: false)
            mealLine(dot: WidgetPalette.blue, text: day.dinner.isEmpty ? "—" : day.dinner, isToday: false)
            Spacer(minLength: 0)
        }
    }
}
