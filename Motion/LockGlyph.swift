import SwiftUI

/// The Gloop padlock. When it opens, the shackle springs up and tips
/// to the side and the keyhole turns, like a key just turned in it.
struct LockGlyph: View {
    var isOpen: Bool
    var color: Color = Theme.ink

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            let line = w * 0.13

            ZStack(alignment: .top) {
                Shackle()
                    .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .frame(width: w * 0.6, height: h * 0.5)
                    .padding(.top, line / 2)
                    .rotationEffect(.degrees(isOpen ? 16 : 0), anchor: .bottomTrailing)
                    .offset(y: isOpen ? -h * 0.13 : 0)

                RoundedRectangle(cornerRadius: w * 0.2, style: .continuous)
                    .fill(color)
                    .frame(width: w, height: h * 0.58)
                    .overlay {
                        VStack(spacing: -w * 0.02) {
                            Circle().frame(width: w * 0.17, height: w * 0.17)
                            Capsule().frame(width: w * 0.07, height: h * 0.11)
                        }
                        .foregroundStyle(Theme.bg)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: w, height: h)
        }
        .animation(Motion.bouncy, value: isOpen)
        .accessibilityLabel(isOpen ? "Unlocked" : "Locked")
    }
}

/// An upside-down U. Built from curves so the direction is unambiguous.
struct Shackle: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        let k = 0.5523 * r
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addCurve(to: CGPoint(x: r, y: 0),
                   control1: CGPoint(x: 0, y: r - k),
                   control2: CGPoint(x: r - k, y: 0))
        p.addCurve(to: CGPoint(x: 2 * r, y: r),
                   control1: CGPoint(x: r + k, y: 0),
                   control2: CGPoint(x: 2 * r, y: r - k))
        p.addLine(to: CGPoint(x: 2 * r, y: rect.height))
        return p
    }
}

/// Rings that ripple outwards while you wait for an answer.
struct PulseRings: View {
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Theme.teal.opacity(0.5), lineWidth: 1.5)
                    .scaleEffect(animate ? 1 : 0.3)
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: 2.4)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.8),
                        value: animate
                    )
            }
        }
        .opacity(reduceMotion ? 0 : 1)
        .onAppear { animate = true }
    }
}

/// Today's remaining time as a little jelly creature.
/// It slowly morphs on its own, blinks and looks around, shrinks as time gets
/// spent, shifts from slime green (plenty left) to teal to deep ocean blue
/// (almost out, and a bit sleepy), and jiggles when tapped.
struct TimeBlob: View {
    let used: Int
    let limit: Int
    var compact = false
    /// Called after the jiggle when it's tapped (Today uses it to show the breakdown).
    var onTap: (() -> Void)? = nil

    @State private var displayed = 0
    @State private var squish = false
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var leftFraction: Double { 1 - min(1, Double(used) / Double(max(limit, 1))) }
    private var left: Int { max(0, limit - used) }
    private var color: Color {
        leftFraction > 0.5 ? Theme.moss : leftFraction > 0.2 ? Theme.teal : Theme.deep
    }
    /// White text on the teal and deep blue, dark text on the light green.
    private var textColor: Color { leftFraction > 0.5 ? Theme.onColor : .white }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                // A few faint bubbles rising around it (only the big one on Today).
                if !compact && !reduceMotion {
                    RisingBubbles(time: t, size: CGSize(width: 330, height: 300))
                        .frame(width: 330, height: 300)
                }
                // A paler blob behind, wobbling out of step, for a bit of depth.
                BlobShape(phase: t * 0.7 + 2, wobble: 0.05, lobes: 3)
                    .fill(Theme.lime.opacity(0.55))
                BlobShape(phase: t * 1.1, wobble: 0.045, lobes: 4)
                    .fill(color.gradient)
                    .scaleEffect(grown ? 0.72 + 0.24 * leftFraction : 0.3)
                // A soft shine, so it reads as jelly rather than a flat circle.
                Ellipse()
                    .fill(.white.opacity(0.45))
                    .frame(width: compact ? 18 : 46, height: compact ? 9 : 22)
                    .rotationEffect(.degrees(-25))
                    .offset(x: compact ? -18 : -52, y: compact ? -22 : -60)
                    .scaleEffect(grown ? 1 : 0.3)
                VStack(spacing: compact ? 1 : 4) {
                    JellyEyes(time: t, size: compact ? 7 : 15, sleepy: leftFraction <= 0.2,
                              reduceMotion: reduceMotion)
                    Text("\(displayed)")
                        .font(.system(size: compact ? 22 : 50, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                    Text(compact ? "min left" : "minutes left")
                        .font(compact ? .caption2.weight(.semibold) : .subheadline.weight(.semibold))
                }
                .foregroundStyle(textColor)
                .offset(y: compact ? 2 : 6)
            }
            // Every few seconds it does a tiny squish all on its own.
            .scaleEffect(x: 1 + 0.05 * bloop(t), y: 1 - 0.05 * bloop(t), anchor: .bottom)
        }
        .scaleEffect(x: squish ? 1.08 : 1, y: squish ? 0.9 : 1)
        .contentShape(Circle())
        .onTapGesture { jiggle(); onTap?() }
        .sensoryFeedback(.impact(weight: .light), trigger: squish) { _, new in new }
        .onAppear {
            displayed = limit
            withAnimation(.spring(response: 0.9, dampingFraction: 0.55).delay(0.15)) { grown = true }
            withAnimation(.spring(response: 1.2, dampingFraction: 0.9).delay(0.15)) { displayed = left }
        }
        .onChange(of: used) { _, _ in
            withAnimation(Motion.smooth) { displayed = left }
        }
        .animation(Motion.smooth, value: leftFraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(left) minutes left today")
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
        .accessibilityHint(onTap == nil ? "" : "Shows how much time each app has left")
    }

    /// 0 most of the time; a quick decaying wobble once per cycle.
    private func bloop(_ t: Double) -> CGFloat {
        guard !reduceMotion, !compact else { return 0 }
        let cycle = t.truncatingRemainder(dividingBy: 6.5)
        guard cycle < 0.9 else { return 0 }
        return CGFloat(sin(cycle / 0.9 * .pi * 3) * exp(-cycle * 3.5))
    }

    private func jiggle() {
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) { squish = true }
        Task {
            try? await Task.sleep(for: .milliseconds(140))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.3)) { squish = false }
        }
    }
}

/// Two little alien eyes. They blink every few seconds, glance around slowly,
/// and droop half shut when the creature is sleepy.
struct JellyEyes: View {
    let time: Double
    let size: CGFloat
    var sleepy = false
    var reduceMotion = false

    var body: some View {
        let blinking = !reduceMotion && time.truncatingRemainder(dividingBy: 4.3) < 0.14
        let open: CGFloat = blinking ? 0.1 : (sleepy ? 0.5 : 1)
        let look = reduceMotion ? 0 : CGFloat(sin(time * 0.6)) * size * 0.18

        HStack(spacing: size * 0.9) {
            ForEach(0..<2, id: \.self) { _ in
                Capsule()
                    .fill(.white)
                    .frame(width: size, height: size * 1.25)
                    .overlay(
                        Circle()
                            .fill(Theme.abyss)
                            .frame(width: size * 0.55, height: size * 0.55)
                            .offset(x: look, y: sleepy ? size * 0.15 : 0)
                    )
                    .clipShape(Capsule())
                    .scaleEffect(x: 1, y: open, anchor: sleepy ? .bottom : .center)
                    .shadow(color: Theme.abyss.opacity(0.15), radius: 1, y: 1)
            }
        }
        .animation(.easeInOut(duration: 0.08), value: blinking)
        .accessibilityHidden(true)
    }
}

/// A circle whose edge ripples with a couple of slow sine waves.
struct BlobShape: Shape {
    var phase: Double
    var wobble: Double
    var lobes: Int

    func path(in rect: CGRect) -> Path {
        // Works for any rectangle: in a wide frame the blob stretches into a wobbly pill.
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2 * (1 - wobble * 1.6)
        let ry = rect.height / 2 * (1 - wobble * 1.6)
        var p = Path()
        let n = 120
        for i in 0...n {
            let a = Double(i) / Double(n) * 2 * .pi
            let k = 1 + wobble * sin(Double(lobes) * a + phase)
                      + wobble * 0.6 * sin(Double(lobes + 2) * a - phase * 1.3)
            let pt = CGPoint(x: c.x + cos(a) * rx * k, y: c.y + sin(a) * ry * k)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Two big, very faint slime blobs that drift slowly behind every screen.
/// Just enough to give the app its jelly world without getting in the way.
struct AmbientGoo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { g in
                let w = g.size.width
                ZStack {
                    BlobShape(phase: t * 0.25, wobble: 0.08, lobes: 3)
                        .fill(Theme.lime.opacity(0.45))
                        .frame(width: w * 0.85, height: w * 0.85)
                        .position(x: w * 0.98 + sin(t * 0.1) * 18, y: g.size.height * 0.06)
                    BlobShape(phase: t * 0.2 + 3, wobble: 0.08, lobes: 4)
                        .fill(Theme.slime.opacity(0.2))
                        .frame(width: w, height: w)
                        .position(x: -w * 0.08, y: g.size.height * 0.9 + cos(t * 0.12) * 18)
                }
                .blur(radius: 28)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A tiny jelly creature, used on the onboarding screens.
struct JellyCritter: View {
    let color: Color
    var size: CGFloat = 72
    var phaseOffset: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate + phaseOffset
            ZStack {
                BlobShape(phase: t * 1.2, wobble: 0.06, lobes: 3)
                    .fill(color.gradient)
                Ellipse()
                    .fill(.white.opacity(0.5))
                    .frame(width: size * 0.24, height: size * 0.12)
                    .rotationEffect(.degrees(-30))
                    .offset(x: -size * 0.2, y: -size * 0.24)
                JellyEyes(time: t, size: size * 0.16, reduceMotion: reduceMotion)
                    .offset(y: -size * 0.02)
            }
            .frame(width: size, height: size)
        }
    }
}

/// A few faint bubbles drifting slowly up around the time creature,
/// swaying a little as they rise.
private struct RisingBubbles: View {
    let time: Double
    let size: CGSize

    // Horizontal position (fraction of width), size, seconds per trip, and start offset.
    private let bubbles: [(x: CGFloat, d: CGFloat, period: Double, offset: Double)] = [
        (0.06, 9, 7, 0.0), (0.16, 5, 9, 0.45), (0.86, 11, 8, 0.7),
        (0.95, 6, 10, 0.2), (0.24, 7, 11, 0.8), (0.78, 4, 6.5, 0.35),
    ]

    var body: some View {
        ZStack {
            ForEach(bubbles.indices, id: \.self) { i in
                let b = bubbles[i]
                let p = CGFloat((time / b.period + b.offset).truncatingRemainder(dividingBy: 1))
                Circle()
                    .stroke(Theme.slime.opacity(0.5 * Double(sin(p * .pi))), lineWidth: 1.2)
                    .background(Circle().fill(Theme.lime.opacity(0.25 * Double(sin(p * .pi)))))
                    .frame(width: b.d, height: b.d)
                    .position(x: size.width * b.x + CGFloat(sin(time * 0.6 + Double(i))) * 10,
                              y: size.height * (1.05 - 1.15 * p))
            }
        }
    }
}
