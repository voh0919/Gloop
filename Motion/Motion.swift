import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Theme: alien jelly. A slime-green to deep-ocean palette
// (coolors.co d9ed92-b5e48c-99d98c-76c893-52b69a-34a0a4-168aad-1a759f-1e6091-184e77).
// Text on the light greens uses `onColor` (the deepest blue); text on the blues is white.

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum Theme {
    static let ink = Color.primary
    static let fill = Color.primary.opacity(0.06)
    static let line = Color.primary.opacity(0.12)

    static let lime = Color(hex: 0xD9ED92)
    static let sprout = Color(hex: 0xB5E48C)
    static let moss = Color(hex: 0x99D98C)
    static let slime = Color(hex: 0x76C893)
    static let sea = Color(hex: 0x52B69A)
    static let teal = Color(hex: 0x34A0A4)
    static let lagoon = Color(hex: 0x168AAD)
    static let ocean = Color(hex: 0x1A759F)
    static let deep = Color(hex: 0x1E6091)
    static let abyss = Color(hex: 0x184E77)

    /// Main action color: a fresh slime green.
    static let accent = slime
    static let accentSoft = lime.opacity(0.6)
    /// Text on any light green fill: the deepest blue. Reads well in light and dark mode.
    static let onColor = abyss

    /// Every person gets one of these. The last two are dark, so they get white initials.
    static let palette: [Color] = [lime, moss, sea, lagoon, deep]
    static let paletteIsDark: [Bool] = [false, false, false, true, true]

    static var bg: Color {
        #if os(iOS)
        return Color(uiColor: .systemBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

// MARK: - Motion vocabulary. Three springs used everywhere so the app feels consistent.

enum Motion {
    /// Taps, selection, small state changes.
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.78)
    /// Screens, cards, layout changes.
    static let smooth = Animation.spring(response: 0.55, dampingFraction: 0.88)
    /// Moments worth celebrating: an unlock, a badge, a toast.
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.58)
}

// MARK: - Staggered entrance: fade, rise and un-blur, one item after another.

struct AppearModifier: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 16)
            // A slight squash that springs back, like jelly settling into place.
            .scaleEffect(x: shown || reduceMotion ? 1 : 1.03, y: shown || reduceMotion ? 1 : 0.94, anchor: .bottom)
            .blur(radius: shown || reduceMotion ? 0 : 6)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.68).delay(Double(index) * 0.06)) {
                    shown = true
                }
            }
    }
}

/// A slow, gentle squish, like a jelly blob breathing. Each one starts at a
/// slightly different moment so a row of them never moves in lockstep.
struct JellyBreath: ViewModifier {
    var amount: CGFloat = 0.03
    var period: Double = 2.4
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: on ? 1 + amount : 1 - amount * 0.4,
                         y: on ? 1 - amount : 1 + amount * 0.4,
                         anchor: .bottom)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: period)
                    .repeatForever(autoreverses: true)
                    .delay(.random(in: 0...1.4))) { on = true }
            }
    }
}

/// How new things land: squashed flat, then springing up and settling with a wobble.
private struct JellyPopModifier: ViewModifier {
    let landed: Bool
    func body(content: Content) -> some View {
        content
            .scaleEffect(x: landed ? 1 : 1.25, y: landed ? 1 : 0.3, anchor: .bottom)
            .opacity(landed ? 1 : 0)
    }
}

extension AnyTransition {
    /// Insert with a jelly squish; remove with a quick fade.
    static var jellyPop: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: JellyPopModifier(landed: false), identity: JellyPopModifier(landed: true))
                .animation(.spring(response: 0.5, dampingFraction: 0.55)),
            removal: .opacity)
    }
}

extension View {
    func appear(_ index: Int = 0) -> some View { modifier(AppearModifier(index: index)) }
}

// MARK: - Buttons shrink slightly under your finger.

/// Buttons squish like jelly: a little wider and shorter under your finger,
/// then wobble back when you let go.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(x: configuration.isPressed ? 1.05 : 1,
                         y: configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(configuration.isPressed
                       ? .spring(response: 0.18, dampingFraction: 0.6)
                       : .spring(response: 0.5, dampingFraction: 0.35),
                       value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

struct PrimaryButton: View {
    let title: String
    var enabled = true
    /// Shows a spinner instead of the title while something's loading.
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(busy ? 0 : 1)
                if busy { ProgressView().tint(Theme.onColor) }
            }
                .font(.headline)
                .contentTransition(.opacity)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .foregroundStyle(Theme.onColor)
                .background(Theme.accent.opacity(enabled ? 1 : 0.3), in: Capsule())
        }
        .buttonStyle(.pressable)
        .disabled(!enabled || busy)
        .animation(Motion.snappy, value: enabled)
        .animation(Motion.snappy, value: busy)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .foregroundStyle(Theme.ink)
                .background(Theme.fill, in: Capsule())
        }
        .buttonStyle(.pressable)
    }
}

struct CircleIconButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 38)
                .background(Theme.fill, in: Circle())
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Shared pieces

/// The switch graphic on its own: a pill whose knob springs across.
/// Put it inside a Button; the whole row should be the tap target.
struct PillSwitch: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Theme.accent : Theme.ink.opacity(0.12))
            Circle()
                .fill(.white)
                .padding(2.5)
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
        }
        .frame(width: 52, height: 32)
        .animation(Motion.bouncy, value: isOn)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// A full-width row with a switch. The whole row is the tap target.
struct SwitchRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack {
                Text(title)
                Spacer()
                PillSwitch(isOn: isOn)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .animation(Motion.bouncy, value: isOn)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

extension Person {
    var color: Color { Theme.palette[colorIndex % Theme.palette.count] }
    /// White on the dark blues, deep blue on the light greens.
    var textColor: Color { Theme.paletteIsDark[colorIndex % Theme.palette.count] ? .white : Theme.onColor }
}

/// Each person is a little jelly blob in their color. Every blob has its own
/// slightly different shape (seeded from the person), plus a soft shine.
struct Avatar: View {
    let person: Person
    var size: CGFloat = 44

    private var seed: Double {
        Double(person.name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 97) / 97 * 2 * .pi
    }

    var body: some View {
        Text(person.initials)
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(person.textColor)
            .frame(width: size, height: size)
            .background {
                BlobShape(phase: seed, wobble: 0.06, lobes: 3)
                    .fill(person.color.gradient)
                    .overlay(alignment: .topLeading) {
                        Ellipse()
                            .fill(.white.opacity(0.5))
                            .frame(width: size * 0.26, height: size * 0.13)
                            .rotationEffect(.degrees(-30))
                            .offset(x: size * 0.18, y: size * 0.16)
                    }
                    .modifier(JellyBreath(amount: 0.035, period: 2.2 + seed / 6))
            }
    }
}

/// A one-shot burst of colorful confetti. Change `trigger` to fire it.
struct ConfettiBurst: View {
    var trigger: Int
    /// 1 is the full celebration; smaller values make a little local pop.
    var spread: CGFloat = 1
    var count = 28
    @State private var pieces: [Piece] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Piece: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let color: Color
        let size: CGFloat
        let spin: Double
        let round: Bool
    }

    var body: some View {
        ZStack {
            ForEach(pieces) { ConfettiPiece(piece: $0) }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in fire() }
    }

    private func fire() {
        guard !reduceMotion else { return }
        let batch = (0..<count).map { _ in
            Piece(angle: .random(in: 0...(2 * .pi)),
                  distance: .random(in: 90...170) * spread,
                  color: [Theme.lime, Theme.sprout, Theme.slime, Theme.teal, Theme.lagoon].randomElement()!,
                  size: .random(in: 6...10) * max(0.5, spread),
                  spin: .random(in: -360...360),
                  round: Bool.random())
        }
        pieces.append(contentsOf: batch)
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            pieces.removeAll { p in batch.contains { $0.id == p.id } }
        }
    }
}

private struct ConfettiPiece: View {
    let piece: ConfettiBurst.Piece
    @State private var flown = false
    @State private var faded = false

    var body: some View {
        // Goo droplets: round blobs, some slightly stretched.
        Ellipse()
            .fill(piece.color.gradient)
            .frame(width: piece.size, height: piece.round ? piece.size : piece.size * 1.35)
            .rotationEffect(.degrees(flown ? piece.spin : 0))
            .scaleEffect(flown ? 1 : 0.2)
            .offset(x: flown ? cos(piece.angle) * piece.distance : 0,
                    y: flown ? sin(piece.angle) * piece.distance + 40 : 0)
            .opacity(faded ? 0 : 1)
            .onAppear {
                withAnimation(.spring(response: 0.75, dampingFraction: 0.7)) { flown = true }
                withAnimation(.easeIn(duration: 0.5).delay(0.7)) { faded = true }
            }
    }
}

struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                if let subtitle {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            Spacer()
            trailing
        }
        .padding(.top, 12)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A horizontal shake, for "no".
struct Shake: GeometryEffect {
    var amount: CGFloat = 10
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * shakes * 2), y: 0))
    }
}

/// A thin progress bar that grows from zero when it appears.
struct ProgressLine: View {
    let value: Double
    var delay: Double = 0
    var color: Color = Theme.accent
    @State private var shown = 0.0

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.fill)
                Capsule().fill(color)
                    .frame(width: max(4, g.size.width * shown))
            }
        }
        .frame(height: 4)
        .onAppear {
            withAnimation(Motion.smooth.delay(0.2 + delay)) { shown = value }
        }
        .onChange(of: value) { _, new in
            withAnimation(Motion.smooth) { shown = new }
        }
    }
}

extension View {
    /// Full-screen on iPhone; a sheet elsewhere (so the code also builds for macOS checks).
    @ViewBuilder
    func fullCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, content: content)
        #else
        sheet(item: item, content: content)
        #endif
    }
}

extension Date {
    var shortAgo: String {
        let s = Int(Date.now.timeIntervalSince(self))
        if s < 60 { return "now" }
        if s < 3600 { return "\(s / 60)m ago" }
        if s < 86400 { return "\(s / 3600)h ago" }
        return "\(s / 86400)d ago"
    }
}

/// Scrolled content fades out as it slides up under the clock and battery,
/// so the app's own background (and its drifting goo) shows through the status
/// bar area instead of a painted band. No hard edge anywhere.
extension View {
    func topFade() -> some View {
        let inset = Self.statusBarHeight
        return mask {
            VStack(spacing: 0) {
                // Over the status bar: fully clear at the top (behind the clock),
                // fading in toward the bottom of the bar.
                LinearGradient(stops: [.init(color: .clear, location: 0),
                                       .init(color: .clear, location: 0.5),
                                       .init(color: .black, location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: inset)
                Color.black
            }
            .padding(.top, -inset)
        }
    }

    private static var statusBarHeight: CGFloat {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return scene?.windows.first?.safeAreaInsets.top ?? 54
    }
}
