import SwiftUI

// MARK: - Colores de la web app (mismos tokens)

extension Color {
    /// #73a89a (claro) / #6aab92 (oscuro)
    static func tealScheme(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.416, green: 0.671, blue: 0.573)
            : Color(red: 0.451, green: 0.659, blue: 0.604)
    }
    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.906, green: 0.925, blue: 0.914) : Color(red: 0.145, green: 0.122, blue: 0.129)
    }
    static func ink2(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.624, green: 0.682, blue: 0.647) : Color(red: 0.345, green: 0.322, blue: 0.329)
    }
}

// MARK: - Fondo de la web app (degradados, nunca negro puro)

struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            if scheme == .dark {
                LinearGradient(colors: [Color(red: 0.067, green: 0.082, blue: 0.078), Color(red: 0.039, green: 0.047, blue: 0.043)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color(red: 0.251, green: 0.471, blue: 0.376).opacity(0.20), .clear],
                               center: .topLeading, startRadius: 0, endRadius: 420)
                RadialGradient(colors: [Color(red: 0.471, green: 0.373, blue: 0.235).opacity(0.12), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 400)
                RadialGradient(colors: [Color(red: 0.235, green: 0.333, blue: 0.471).opacity(0.16), .clear],
                               center: .bottom, startRadius: 0, endRadius: 460)
            } else {
                LinearGradient(colors: [Color(red: 0.973, green: 0.961, blue: 0.941), Color(red: 0.941, green: 0.929, blue: 0.906)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color(red: 0.588, green: 0.824, blue: 0.737).opacity(0.55), .clear],
                               center: .topLeading, startRadius: 0, endRadius: 420)
                RadialGradient(colors: [Color(red: 0.961, green: 0.816, blue: 0.690).opacity(0.55), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 400)
                RadialGradient(colors: [Color(red: 0.667, green: 0.761, blue: 0.910).opacity(0.45), .clear],
                               center: .bottom, startRadius: 0, endRadius: 460)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Tarjeta de cristal (estilo web app)

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(scheme == .dark
                              ? LinearGradient(colors: [Color(red: 0.145, green: 0.169, blue: 0.157).opacity(0.8),
                                                        Color(red: 0.086, green: 0.102, blue: 0.094).opacity(0.68)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient(colors: [Color.white.opacity(0.74), Color.white.opacity(0.46)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(scheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.7), lineWidth: 1)
                }
            )
            .shadow(color: scheme == .dark ? Color.black.opacity(0.4) : Color(red: 0.259, green: 0.212, blue: 0.188).opacity(0.10),
                    radius: 14, x: 0, y: 12)
    }
}

// MARK: - Interruptor sol-luna (copia del de la web app)

struct SunMoonToggle: View {
    /// true = oscuro
    @Binding var isDark: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let trackWidth: CGFloat = 60
    private let trackHeight: CGFloat = 36
    private let knob: CGFloat = 30
    private let travel: CGFloat = 24

    var body: some View {
        // Button + SilentButtonStyle: con onTapGesture, iOS 26 pinta un recuadro gris
        // translúcido al pulsar. Con un estilo que no toca la etiqueta no aparece nada,
        // solo la animación del interruptor, igual que en la web.
        Button {
            withAnimation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.65)) {
                isDark.toggle()
            }
        } label: {
            graphic
        }
        .buttonStyle(SilentButtonStyle())
        .accessibilityLabel("Modo oscuro")
        .accessibilityValue(isDark ? "Activado" : "Desactivado")
    }

    private var graphic: some View {
        ZStack(alignment: .leading) {
            // Pista: cielo de día / noche
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(isDark
                      ? LinearGradient(colors: [Color(red: 0.102, green: 0.157, blue: 0.212), Color(red: 0.043, green: 0.075, blue: 0.125)],
                                       startPoint: .top, endPoint: .bottom)
                      : LinearGradient(colors: [Color(red: 0.486, green: 0.741, blue: 0.902), Color(red: 0.788, green: 0.906, blue: 0.969)],
                                       startPoint: .top, endPoint: .bottom))
                .frame(width: trackWidth, height: trackHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5)
                )
                .shadow(color: Color(red: 0.071, green: 0.165, blue: 0.235).opacity(0.35), radius: 2, x: 0, y: 1)

            // Nubes (día)
            Group {
                Capsule().fill(Color.white.opacity(0.95)).frame(width: 17, height: 11)
                    .offset(x: 9, y: -3)
                Capsule().fill(Color.white.opacity(0.9)).frame(width: 13, height: 8)
                    .offset(x: 20, y: 6)
            }
            .opacity(isDark ? 0 : 0.95)

            // Estrellas (noche)
            Group {
                Circle().fill(Color.white).frame(width: 2.5, height: 2.5).offset(x: 40, y: -8)
                Circle().fill(Color.white.opacity(0.85)).frame(width: 2.5, height: 2.5).offset(x: 27, y: 1)
                Circle().fill(Color.white.opacity(0.65)).frame(width: 2, height: 2).offset(x: 35, y: 8)
                Circle().fill(Color.white.opacity(0.75)).frame(width: 2, height: 2).offset(x: 45, y: 9)
                Circle().fill(Color.white.opacity(0.55)).frame(width: 2, height: 2).offset(x: 21, y: -5)
            }
            .opacity(isDark ? 1 : 0)
            .scaleEffect(isDark ? 1 : 0.4)

            // Knob: sol / luna
            ZStack {
                Circle()
                    .fill(isDark
                          ? RadialGradient(colors: [Color(red: 0.969, green: 0.980, blue: 0.988),
                                                    Color(red: 0.886, green: 0.910, blue: 0.937),
                                                    Color(red: 0.761, green: 0.800, blue: 0.843)],
                                           center: .init(x: 0.42, y: 0.38), startRadius: 2, endRadius: 24)
                          : RadialGradient(colors: [Color(red: 1.0, green: 0.929, blue: 0.678),
                                                    Color(red: 1.0, green: 0.843, blue: 0.431),
                                                    Color(red: 0.949, green: 0.718, blue: 0.235)],
                                           center: .init(x: 0.38, y: 0.35), startRadius: 2, endRadius: 24))
                    .frame(width: knob, height: knob)
                    .shadow(color: isDark ? Color(red: 0.725, green: 0.804, blue: 0.902).opacity(0.35)
                                          : Color(red: 1.0, green: 0.804, blue: 0.314).opacity(0.6),
                            radius: 6)
                    .shadow(color: Color.black.opacity(isDark ? 0.45 : 0.28), radius: 3, x: 0, y: 2)
                // Cráter / sombra de la luna
                Circle()
                    .fill(Color(red: 0.086, green: 0.133, blue: 0.180))
                    .frame(width: 26, height: 26)
                    .offset(x: 5, y: -3)
                    .scaleEffect(isDark ? 1 : 0)
            }
            .offset(x: isDark ? travel : 3, y: 0)
        }
        .frame(width: trackWidth + 6, height: trackHeight)
    }
}

/// Estilo de botón sin feedback visual (ni opacidad ni fondo al pulsar).
struct SilentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

// MARK: - Animación estándar (una sola curva; una animación nueva interrumpe a la anterior con suavidad, nunca se apilan)

extension Animation {
    static let appSpring = Animation.spring(response: 0.45, dampingFraction: 0.82)
}

// MARK: - Emojis de categoría (toque visual, coherente con los puntos naranja/azul)

enum FunEmoji {
    static func dish(_ dish: Dish) -> String {
        for tag in dish.tags {
            if let e = dishMap[tag] { return e }
        }
        return "🍽️"
    }

    private static let dishMap: [String: String] = [
        "pollo": "🍗", "carne": "🥩", "pescado": "🐟", "marisco": "🦐",
        "pasta": "🍝", "arroz": "🍚", "legumbre": "🫘", "verdura": "🥦",
        "ensalada": "🥗", "huevo": "🍳", "patata": "🥔",
    ]

    static func shoppingSection(_ section: String) -> String {
        switch section {
        case "Fruta y verdura": return "🥬"
        case "Carne y pescado": return "🥩"
        case "Lácteos y huevos": return "🧀"
        case "Despensa": return "🥫"
        case "Hogar": return "🧴"
        default: return "🛒"
        }
    }
}
