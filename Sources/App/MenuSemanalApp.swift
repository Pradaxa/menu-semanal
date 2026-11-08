import SwiftUI
import WidgetKit

@main
struct MenuSemanalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var week: [DayMenu] = MenuStore.load()
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(week.indices, id: \.self) { i in
                        dayCard(index: i)
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Menú semanal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        MenuStore.save(week)
                        WidgetCenter.shared.reloadAllTimelines()
                        saved = true
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .alert("Widget actualizado", isPresented: $saved) {
                Button("Vale", role: .cancel) {}
            } message: {
                Text("El widget de la pantalla de inicio ya muestra esta semana.")
            }
        }
    }

    private func dayCard(index i: Int) -> some View {
        let isToday = i == MenuStore.todayIndex
        return HStack(alignment: .top, spacing: 12) {
            Text(week[i].short)
                .font(.headline)
                .frame(width: 34, height: 34)
                .background(Circle().fill(isToday ? Color.green : Color.secondary.opacity(0.2)))
                .foregroundStyle(isToday ? Color.white : Color.primary)
            VStack(spacing: 8) {
                field("Comida", text: $week[i].lunch)
                field("Cena", text: $week[i].dinner)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            )
    }
}
