import SwiftUI

// MARK: - Fila de título (como rowHtml de la web): póster, título, meta, plataformas, nota IMDb

struct TitleRow: View {
    let item: QVTitle
    var rank: Int? = nil
    @EnvironmentObject private var store: QVStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let rank {
                Text("\(rank)")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundStyle(Color.accentScheme(scheme))
                    .frame(width: 20, alignment: .trailing)
                    .padding(.top, 24)
            }
            poster
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.ink(scheme))
                        .lineLimit(2)
                    if store.isLola(item.id) { Text("❤️").font(.system(size: 11)) }
                }
                HStack(spacing: 5) {
                    Text(meta)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.ink2(scheme))
                        .lineLimit(1)
                    if let temps = store.pendTemps[item.id]?.temps, !temps.isEmpty {
                        Text(tempsBadge(temps, lola: store.pendTemps[item.id]?.tempsLola ?? []))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentScheme(scheme))
                            .lineLimit(1)
                    }
                }
                HStack(spacing: 5) {
                    let plats = JustWatch.dedupePlats(item.plats).prefix(5)
                    if plats.isEmpty {
                        Text("Sin suscripción ahora")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.ink2(scheme).opacity(0.8))
                    } else {
                        ForEach(Array(plats), id: \.id) { p in
                            PlatIcon(url: p.icon, size: 18)
                        }
                    }
                    Spacer(minLength: 0)
                    IMDbBadge(value: item.imdbText)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private var poster: some View {
        Group {
            if !item.poster.isEmpty, let url = URL(string: item.poster) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 52, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.ink2(scheme).opacity(0.12))
            Text("🎬").font(.system(size: 22))
        }
    }

    private var meta: String {
        let head = item.isUpcoming ? "Estreno: \(item.releaseFormatted)" : (item.year.map(String.init) ?? "")
        return ([head] + item.genres.prefix(2)).filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func tempsBadge(_ temps: [Int], lola: [Int]) -> String {
        temps.map { "T\($0)\(lola.contains($0) ? " ❤️" : "")" }.joined(separator: " · ")
    }
}

// MARK: - Icono de plataforma (logo real de JustWatch)

struct PlatIcon: View {
    let url: String
    var size: CGFloat = 18
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if let u = URL(string: url), !url.isEmpty {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFit()
                    default: Color.ink2(scheme).opacity(0.15)
                    }
                }
            } else {
                Color.ink2(scheme).opacity(0.15)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

// MARK: - Insignia IMDb (como rtBadge de la web)

struct IMDbBadge: View {
    let value: String?
    var big = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let value {
            HStack(spacing: 4) {
                Text("IMDb")
                    .font(.system(size: big ? 9 : 8, weight: .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.96, green: 0.80, blue: 0.22)))
                Text(value)
                    .font(.system(size: big ? 14 : 12, weight: .bold))
                    .foregroundStyle(Color.ink(scheme))
            }
        }
    }
}

// MARK: - Spinner estilo web

struct QVSpinner: View {
    let text: String
    @Environment(\.colorScheme) private var scheme
    @State private var spinning = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.accentScheme(scheme), lineWidth: 2.5)
                .frame(width: 26, height: 26)
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .onAppear {
                    withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                        spinning = true
                    }
                }
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.ink2(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }
}

// MARK: - Estado vacío estilo web

struct EmptyCard: View {
    let emoji: String
    let title: String
    let sub: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GlassCard {
            VStack(spacing: 6) {
                Text(emoji).font(.system(size: 34))
                Text(title)
                    .font(.system(size: 19, design: .serif))
                    .foregroundStyle(Color.ink(scheme))
                Text(sub)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.ink2(scheme))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Toast ligero

final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()
    @Published var message: String?
    private var timer: Timer?

    func show(_ msg: String) {
        DispatchQueue.main.async {
            self.message = msg
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 2.6, repeats: false) { _ in
                withAnimation(.appSpring) { self.message = nil }
            }
        }
    }
}

struct ToastOverlay: View {
    @ObservedObject private var center = ToastCenter.shared
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let msg = center.message {
            Text(msg)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.ink(scheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(scheme == .dark ? Color(red: 0.169, green: 0.145, blue: 0.145) : Color.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.appSpring, value: center.message)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 90)
        }
    }
}

// MARK: - Fila deslizable (como la web: desliza a la izquierda y aparecen ✓ y 🗑)

struct SwipeRow<Content: View>: View {
    let onTap: () -> Void
    let onVista: () -> Void
    let onDelete: () -> Void
    let content: Content
    @Environment(\.colorScheme) private var scheme

    @State private var offset: CGFloat = 0
    @State private var start: CGFloat = 0
    @State private var active = false
    private let open: CGFloat = 140

    init(onTap: @escaping () -> Void, onVista: @escaping () -> Void, onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onTap = onTap
        self.onVista = onVista
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.appSpring) { offset = 0 }
                    onVista()
                } label: {
                    Text("✓")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.accentScheme(scheme)))
                }
                .buttonStyle(SilentButtonStyle())
                Button {
                    withAnimation(.appSpring) { offset = 0 }
                    onDelete()
                } label: {
                    Text("🗑")
                        .font(.system(size: 17))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.qvRed.opacity(0.9)))
                }
                .buttonStyle(SilentButtonStyle())
            }
            .opacity(offset < -20 ? 1 : 0)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(scheme == .dark ? Color(red: 0.145, green: 0.125, blue: 0.125) : Color.white.opacity(0.95))
                        .opacity(offset < -4 ? 1 : 0)
                )
                .contentShape(Rectangle())
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            if !active { active = true; start = offset }
                            var x = start + value.translation.width
                            if x > 0 { x = x * 0.35 }
                            if x < -open { x = -open + (x + open) * 0.35 }
                            offset = x
                        }
                        .onEnded { _ in
                            active = false
                            withAnimation(.appSpring) {
                                offset = offset < -open / 2 ? -open : 0
                            }
                        }
                )
                .onTapGesture {
                    if offset != 0 {
                        withAnimation(.appSpring) { offset = 0 }
                    } else {
                        onTap()
                    }
                }
        }
        .clipped()
    }
}
