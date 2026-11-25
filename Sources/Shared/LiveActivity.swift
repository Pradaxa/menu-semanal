import ActivityKit
import SwiftUI

/// Live Activity del progreso de generación con IA.
/// La UI vive en la extensión de widget; el estado viaja en ContentState.
struct GenActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: Double
        var stage: String
    }
    var title: String
}

/// Vista compacta (barra + un texto, lo más baja posible).
/// La usan la Live Activity (extensión) y la captura de vista previa de CI (app).
struct GenActivityBanner: View {
    var progress: Double
    var stage: String
    @Environment(\.colorScheme) private var scheme

    private var green: Color {
        // Mismo verde vivo del tema de la app
        scheme == .dark
            ? Color(red: 0.298, green: 0.835, blue: 0.541)
            : Color(red: 0.176, green: 0.729, blue: 0.439)
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Text(stage.isEmpty ? "Generando el menú…" : stage)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.caption.bold().monospacedDigit())
            }
            ProgressView(value: progress, total: 1)
                .tint(green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
