import SwiftUI

// MARK: - Colores de la web app Qué ver (mismos tokens)

extension Color {
    /// Acento rojizo: #c9574a (claro) / #d97a68 (oscuro)
    static func accentScheme(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.851, green: 0.478, blue: 0.408)
            : Color(red: 0.788, green: 0.341, blue: 0.290)
    }
    /// #ed313e
    static let qvRed = Color(red: 0.929, green: 0.192, blue: 0.243)
    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.925, green: 0.906, blue: 0.902) : Color(red: 0.145, green: 0.122, blue: 0.129)
    }
    static func ink2(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.690, green: 0.635, blue: 0.620) : Color(red: 0.345, green: 0.322, blue: 0.329)
    }
}

// MARK: - Fondo de la web app (degradados cálidos, nunca negro puro)

struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            if scheme == .dark {
                // linear-gradient(165deg,#151111,#0c0a0a)
                LinearGradient(colors: [Color(red: 0.082, green: 0.067, blue: 0.067), Color(red: 0.047, green: 0.039, blue: 0.039)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color(red: 0.627, green: 0.290, blue: 0.243).opacity(0.20), .clear],
                               center: .topLeading, startRadius: 0, endRadius: 420)
                RadialGradient(colors: [Color(red: 0.471, green: 0.373, blue: 0.235).opacity(0.12), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 400)
                RadialGradient(colors: [Color(red: 0.510, green: 0.243, blue: 0.282).opacity(0.16), .clear],
                               center: .bottom, startRadius: 0, endRadius: 460)
            } else {
                // linear-gradient(165deg,#f8f5f0,#f0ede7)
                LinearGradient(colors: [Color(red: 0.973, green: 0.961, blue: 0.941), Color(red: 0.941, green: 0.929, blue: 0.906)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color(red: 0.886, green: 0.620, blue: 0.565).opacity(0.50), .clear],
                               center: .topLeading, startRadius: 0, endRadius: 420)
                RadialGradient(colors: [Color(red: 0.961, green: 0.816, blue: 0.690).opacity(0.55), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 400)
                RadialGradient(colors: [Color(red: 0.839, green: 0.588, blue: 0.620).opacity(0.40), .clear],
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
                              ? LinearGradient(colors: [Color(red: 0.169, green: 0.145, blue: 0.145).opacity(0.8),
                                                        Color(red: 0.102, green: 0.086, blue: 0.086).opacity(0.68)],
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

// MARK: - Chip estilo web (filtros, plataformas)

struct ChipStyle: ButtonStyle {
    let isOn: Bool
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isOn ? Color.accentScheme(scheme) : Color.ink2(scheme))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isOn
                          ? Color.accentScheme(scheme).opacity(scheme == .dark ? 0.22 : 0.20)
                          : (scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.5)))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isOn
                                  ? Color.accentScheme(scheme).opacity(scheme == .dark ? 0.45 : 1)
                                  : (scheme == .dark ? Color.white.opacity(0.12) : Color.ink(scheme).opacity(0.12)),
                                  lineWidth: 1)
            )
    }
}

// MARK: - Botón principal (mg-add-btn)

struct PrimaryButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(prominent ? Color.white : Color.ink2(scheme))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                Capsule().fill(prominent
                               ? Color.accentScheme(scheme)
                               : Color.accentScheme(scheme).opacity(scheme == .dark ? 0.14 : 0.12))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.appSpring, value: configuration.isPressed)
    }
}

// MARK: - Interruptor sol-luna (como en la web y en Menú)

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
        // translúcido al pulsar. Con un estilo que no toca la etiqueta no aparece nada.
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

            Group {
                Capsule().fill(Color.white.opacity(0.95)).frame(width: 17, height: 11)
                    .offset(x: 9, y: -3)
                Capsule().fill(Color.white.opacity(0.9)).frame(width: 13, height: 8)
                    .offset(x: 20, y: 6)
            }
            .opacity(isDark ? 0 : 0.95)

            Group {
                Circle().fill(Color.white).frame(width: 2.5, height: 2.5).offset(x: 40, y: -8)
                Circle().fill(Color.white.opacity(0.85)).frame(width: 2.5, height: 2.5).offset(x: 27, y: 1)
                Circle().fill(Color.white.opacity(0.65)).frame(width: 2, height: 2).offset(x: 35, y: 8)
                Circle().fill(Color.white.opacity(0.75)).frame(width: 2, height: 2).offset(x: 45, y: 9)
                Circle().fill(Color.white.opacity(0.55)).frame(width: 2, height: 2).offset(x: 21, y: -5)
            }
            .opacity(isDark ? 1 : 0)
            .scaleEffect(isDark ? 1 : 0.4)

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

// MARK: - Botón mágico (acciones con IA: degradado + brillo que barre en bucle suave)

struct MagicButtonStyle: ButtonStyle {
    private let gradient = LinearGradient(
        colors: [Color(red: 0.56, green: 0.44, blue: 0.90),   // violeta
                 Color(red: 0.36, green: 0.60, blue: 0.95),   // azul
                 Color(red: 0.85, green: 0.44, blue: 0.38)],  // rojizo de la app
        startPoint: .leading, endPoint: .trailing)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(gradient)
            .overlay(shimmer)
            .clipShape(Capsule())
            .shadow(color: Color(red: 0.45, green: 0.52, blue: 0.95).opacity(0.35), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.appSpring, value: configuration.isPressed)
    }

    /// Banda de brillo que cruza la cápsula: una sola animación en bucle.
    private var shimmer: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, .white.opacity(0.4), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: geo.size.width * 0.45)
                .phaseAnimator([false, true]) { content, phase in
                    content.offset(x: phase ? geo.size.width * 1.45 : -geo.size.width * 0.45)
                } animation: { _ in
                    .linear(duration: 2.8)
                }
        }
        .allowsHitTesting(false)
        .clipShape(Capsule())
    }
}

// MARK: - Animación estándar (una sola curva; una animación nueva interrumpe a la anterior con suavidad)

extension Animation {
    static let appSpring = Animation.spring(response: 0.45, dampingFraction: 0.82)
}
