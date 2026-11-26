import ActivityKit
import SwiftUI
import UIKit

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

    /// Fondo aurora en tonos del verde de la app (sobre una base verde oscura/clara)
    private var aurora: some View {
        let dark = scheme == .dark
        return ZStack {
            LinearGradient(
                colors: dark
                    ? [Color(red: 0.03, green: 0.14, blue: 0.11), Color(red: 0.05, green: 0.22, blue: 0.17)]
                    : [Color(red: 0.84, green: 0.96, blue: 0.89), Color(red: 0.72, green: 0.92, blue: 0.82)],
                startPoint: .leading, endPoint: .trailing)
            RadialGradient(colors: [green.opacity(dark ? 0.55 : 0.45), .clear],
                           center: .leading, startRadius: 0, endRadius: 190)
            RadialGradient(colors: [Color(red: 0.15, green: 0.72, blue: 0.72).opacity(dark ? 0.40 : 0.30), .clear],
                           center: .trailing, startRadius: 0, endRadius: 210)
            RadialGradient(colors: [Color(red: 0.55, green: 0.85, blue: 0.40).opacity(dark ? 0.28 : 0.30), .clear],
                           center: UnitPoint(x: 0.55, y: 0.5), startRadius: 0, endRadius: 150)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon = UIImage(named: "icon-live") {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 26 * 0.2237, style: .continuous))
            }
            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    Text(stage.isEmpty ? "Generando el menú…" : stage)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.78) : Color.black.opacity(0.6))
                    Spacer(minLength: 6)
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(scheme == .dark ? Color.white : Color.black)
                }
                ProgressView(value: progress, total: 1)
                    .tint(green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            // Más alto que la tarjeta a propósito: iOS deja un margen propio alrededor del contenido
            // (en el bloqueo se veía como franjas más oscuras arriba y abajo) y así queda cubierto.
            aurora
                .frame(maxWidth: .infinity)
                .frame(height: 600)
        }
    }
}
