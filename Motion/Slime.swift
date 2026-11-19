import SwiftUI

/// Full-screen "slimed!" moment, played in four beats:
/// 1. A Gloop creature gets flung up from the bottom of the screen.
/// 2. It bursts into a jiggling splat with spiky splashes, smaller
///    splats land around the screen, and droplets fly everywhere.
/// 3. Goo oozes: strands drip down from the splat and stuck droplets slide
///    and stretch under gravity, all wobbling like jelly.
/// 4. The whole mess slumps off the bottom of the screen.
/// Tap anywhere to skip to the end.
struct SlimeOverlay: View {
    let event: SlimeEvent
    let onDone: () -> Void

    @State private var start = Date()
    @State private var exitAt: Double?
    @State private var impactHaptic = false
    @State private var finished = false
    @State private var drops = SplatData.drops()
    @State private var spokes = SplatData.spokes()
    @State private var minis = SplatData.minis()
    @State private var strands = SplatData.strands()
    @State private var copy = SlimeCopy(title: "", subtitle: "")
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let impact = 0.34     // seconds until the goo hits
    static let hold = 3.4        // when it starts sliding away
    static let exitDuration = 0.75

    var body: some View {
        TimelineView(.animation) { context in
            let real = context.date.timeIntervalSince(start)
            // With Reduce Motion, jump straight to the finished splat (no flying or oozing).
            let t = reduceMotion && exitAt == nil ? Self.impact + 1.6 : real
            let exitU = exitAt.map { max(0, real - $0) } ?? 0
            GeometryReader { g in
                scene(t: t, exitU: exitU, size: g.size)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { beginExit() }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: impactHaptic)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(copy.title) \(copy.subtitle)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to dismiss")
        .onAppear { copy = SlimeCopy.pick(for: event) }
        .task { await run() }
    }

    // MARK: Timing

    private func run() async {
        try? await Task.sleep(for: .seconds(Self.impact))
        impactHaptic.toggle()
        try? await Task.sleep(for: .seconds(Self.hold - Self.impact))
        beginExit()
    }

    private func beginExit() {
        guard exitAt == nil else { return }
        exitAt = Date().timeIntervalSince(start)
        Task {
            try? await Task.sleep(for: .seconds(Self.exitDuration))
            guard !finished else { return }
            finished = true
            onDone()
        }
    }

    // MARK: The scene at time t

    @ViewBuilder
    private func scene(t: Double, exitU: Double, size: CGSize) -> some View {
        let w = size.width, h = size.height
        let center = CGPoint(x: w / 2, y: h * 0.38)
        let u = t - Self.impact
        let radius = min(w, h) * 0.3

        ZStack {
            // A quick green flash on impact.
            Theme.sprout.opacity(u > 0 ? max(0, 0.35 - u * 0.9) : 0)

            if u < 0 {
                projectile(t: t, w: w, h: h, center: center)
            } else {
                ForEach(minis) { mini in miniSplat(mini, u: u, t: t, w: w, h: h) }
                ForEach(strands) { s in strand(s, u: u, t: t, center: center, radius: radius) }
                ForEach(drops) { d in drop(d, u: u, center: center) }
                mainSplat(u: u, t: t, center: center, radius: radius)
                caption(u: u, t: t, center: center, w: w)
            }
        }
        .frame(width: w, height: h)
        // Exit: everything slumps downward, stretching as it falls.
        .scaleEffect(x: 1 - min(0.15, exitU * 0.25), y: 1 + exitU * 0.9, anchor: .top)
        .offset(y: 1500 * exitU * exitU)
        .opacity(1 - max(0, (exitU - 0.45) / 0.3))
    }

    /// A little Gloop creature, stretched by speed, flying up to the impact point.
    private func projectile(t: Double, w: CGFloat, h: CGFloat, center: CGPoint) -> some View {
        let p = min(1, t / Self.impact)
        let e = 1 - pow(1 - p, 2.2)
        let y = (h + 90) + (center.y - (h + 90)) * e
        return ZStack {
            BlobShape(phase: t * 9, wobble: 0.08, lobes: 3)
                .fill(SlimeColors.goo)
            JellyEyes(time: t, size: 11)
        }
        .frame(width: 86, height: 86)
        .scaleEffect(x: 1 - 0.25 * (1 - p), y: 1 + 0.55 * (1 - p))
        .rotationEffect(.degrees(sin(t * 20) * 8))
        .position(x: center.x + CGFloat(sin(p * .pi)) * 30, y: y)
    }

    /// The big central splat: a jiggling blob with spiky splashes and round tips.
    private func mainSplat(u: Double, t: Double, center: CGPoint, radius: CGFloat) -> some View {
        let grow = SplatData.spring(u)
        return ZStack {
            SplatShape(radius: radius, spokes: spokes, grow: grow, phase: t * 2.2)
                .fill(SlimeColors.goo)
                .shadow(color: Theme.sea.opacity(0.35), radius: 10, y: 6)
            ForEach(spokes) { s in
                let r = radius * grow * (1 + s.length) * 0.98
                Circle()
                    .fill(SlimeColors.goo)
                    .frame(width: s.tip * grow, height: s.tip * grow)
                    .offset(x: CGFloat(cos(s.angle)) * r, y: CGFloat(sin(s.angle)) * r)
            }
            // Wet shines.
            Capsule().fill(.white.opacity(0.45))
                .frame(width: 70 * grow, height: 16 * grow)
                .rotationEffect(.degrees(-24))
                .offset(x: -radius * 0.38, y: -radius * 0.5)
            Circle().fill(.white.opacity(0.4))
                .frame(width: 14 * grow, height: 14 * grow)
                .offset(x: -radius * 0.05, y: -radius * 0.62)
        }
        .frame(width: radius * 4, height: radius * 4)
        // A little screen-shake right at impact.
        .offset(x: CGFloat(sin(u * 70) * 9 * exp(-7 * u)))
        .position(center)
    }

    /// Smaller splats that land around the screen a moment after the big one.
    private func miniSplat(_ m: SplatData.Mini, u: Double, t: Double, w: CGFloat, h: CGFloat) -> some View {
        let grow = SplatData.spring(u - m.delay)
        return BlobShape(phase: t * 1.7 + m.phase, wobble: 0.12, lobes: 5)
            .fill(SlimeColors.goo)
            .frame(width: m.size, height: m.size * 0.85)
            .scaleEffect(grow)
            .rotationEffect(.radians(m.phase))
            .position(x: w * m.x, y: h * m.y + CGFloat(18 * pow(max(0, u - m.delay - 0.8), 1.6)))
    }

    /// A flying droplet: shoots out, sticks, then slowly slides and stretches.
    private func drop(_ d: SplatData.Drop, u: Double, center: CGPoint) -> some View {
        let f = min(1, max(0, (u - d.delay) / 0.4))
        let fly = 1 - pow(1 - f, 3)
        let slide = d.slip * pow(max(0, u - d.delay - 0.55), 1.7)
        // Droplets sag as they slide, but stay drop-shaped rather than turning into rods.
        let stretch = min(2.2, 1 + slide / 70)
        return Ellipse()
            .fill(d.color.gradient)
            .frame(width: d.size, height: d.size * CGFloat(stretch))
            .opacity(u < d.delay ? 0 : 1)
            .position(x: center.x + CGFloat(cos(d.angle)) * d.distance * CGFloat(fly),
                      y: center.y + CGFloat(sin(d.angle)) * d.distance * CGFloat(fly) + CGFloat(slide))
    }

    /// A strand of goo oozing down from the splat, with a round blob at the end.
    private func strand(_ s: SplatData.Strand, u: Double, t: Double, center: CGPoint, radius: CGFloat) -> some View {
        let p = min(1, max(0, (u - s.delay) / 1.9))
        let ease = p * p * (3 - 2 * p)
        let length = s.length * CGFloat(ease) + CGFloat(sin(t * 3 + s.delay * 9)) * 6 * CGFloat(ease)
        let width = s.width * (1 + 0.12 * CGFloat(sin(t * 4 + s.delay * 5)))
        let top = center.y + radius * 0.55
        return VStack(spacing: -width * 0.45) {
            Capsule().fill(SlimeColors.goo)
                .frame(width: width, height: max(width, length))
            Circle().fill(SlimeColors.goo)
                .frame(width: width * 1.45, height: width * 1.45)
        }
        .opacity(u < s.delay ? 0 : 1)
        .position(x: center.x + radius * s.x, y: top + max(width, length) / 2)
    }

    /// Who got slimed and the joke, stuck on top of the goo.
    private func caption(u: Double, t: Double, center: CGPoint, w: CGFloat) -> some View {
        let pop = SplatData.spring(u - 0.35, k: 6, w: 12)
        return VStack(spacing: 8) {
            Avatar(person: event.person, size: 58)
                .rotationEffect(.degrees(sin(t * 5) * 10 * exp(-0.6 * max(0, u - 0.35))))
            Text(copy.title)
                .font(.title2.weight(.heavy))
            Text(copy.subtitle)
                .font(.subheadline.weight(.semibold))
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(Theme.onColor)
        .frame(width: min(w - 80, 250))
        .scaleEffect(pop)
        .opacity(u < 0.35 ? 0 : 1)
        .position(x: center.x, y: center.y)
    }
}

/// The goo's colors.
enum SlimeColors {
    static let goo = LinearGradient(colors: [Theme.lime, Theme.sprout, Theme.slime, Theme.sea],
                                    startPoint: .top, endPoint: .bottom)
}

/// The jokes. Picked at random each time someone gets slimed.
struct SlimeCopy {
    let title: String
    let subtitle: String

    static func pick(for e: SlimeEvent) -> SlimeCopy {
        let n = e.person.firstName, app = e.app
        if e.byMe {
            return SlimeCopy(
                title: ["\(n) got slimed!", "\(n) has been gooped.", "Direct hit on \(n)!",
                        "\(n) is now 80% jelly."].randomElement()!,
                subtitle: ["\(app) is back in the jar.", "\(app) is sealed in goo until tomorrow.",
                           "No more \(app). Only slime.", "\(n) will be sticky for a while.",
                           "Go touch grass, \(n). Then wash your hands."].randomElement()!)
        }
        return SlimeCopy(
            title: ["You got slimed!", "SPLAT. That was you.", "You've been gooped."].randomElement()!,
            subtitle: ["\(n) slimed you out of \(app).", "\(n) says: phone down, jelly brain.",
                       "\(app) is in the jar, courtesy of \(n)."].randomElement()!)
    }
}

/// Random layouts for one splat, made once per animation.
enum SplatData {
    struct Spoke: Identifiable { let id = UUID(); let angle: Double; let length: CGFloat; let width: Double; let tip: CGFloat }
    struct Drop: Identifiable { let id = UUID(); let angle: Double; let distance: CGFloat; let size: CGFloat; let color: Color; let slip: Double; let delay: Double }
    struct Mini: Identifiable { let id = UUID(); let x: CGFloat; let y: CGFloat; let size: CGFloat; let delay: Double; let phase: Double }
    struct Strand: Identifiable { let id = UUID(); let x: CGFloat; let width: CGFloat; let length: CGFloat; let delay: Double }

    static func spokes() -> [Spoke] {
        (0..<11).map { i in
            Spoke(angle: Double(i) / 11 * 2 * .pi + .random(in: -0.2...0.2),
                  length: .random(in: 0.25...0.75), width: .random(in: 0.05...0.1),
                  tip: .random(in: 16...30))
        }
    }

    static func drops() -> [Drop] {
        (0..<34).map { _ in
            Drop(angle: .random(in: 0...(2 * .pi)), distance: .random(in: 150...430),
                 size: .random(in: 8...24),
                 color: [Theme.lime, Theme.sprout, Theme.slime, Theme.sea].randomElement()!,
                 slip: .random(in: 10...45), delay: .random(in: 0...0.12))
        }
    }

    static func minis() -> [Mini] {
        [Mini(x: 0.14, y: 0.13, size: 84, delay: 0.12, phase: 0.4),
         Mini(x: 0.88, y: 0.2, size: 64, delay: 0.18, phase: 1.9),
         Mini(x: 0.1, y: 0.7, size: 72, delay: 0.24, phase: 3.1),
         Mini(x: 0.86, y: 0.78, size: 96, delay: 0.16, phase: 4.4),
         Mini(x: 0.55, y: 0.92, size: 58, delay: 0.3, phase: 5.2)]
            .map { Mini(x: $0.x + .random(in: -0.04...0.04), y: $0.y + .random(in: -0.03...0.03),
                        size: $0.size, delay: $0.delay, phase: $0.phase) }
    }

    static func strands() -> [Strand] {
        [(-0.62, 0.15), (-0.3, 0.05), (0.02, 0.25), (0.36, 0.1), (0.66, 0.3)].map { x, delay in
            Strand(x: x + .random(in: -0.05...0.05), width: .random(in: 14...24),
                   length: .random(in: 110...300), delay: delay)
        }
    }

    /// A springy 0 → 1 that overshoots and wobbles back, like jelly settling.
    static func spring(_ x: Double, k: Double = 7, w: Double = 13) -> CGFloat {
        guard x > 0 else { return 0 }
        return CGFloat(1 - exp(-k * x) * cos(w * x))
    }
}

/// A splat: a wobbly round body with sharp splashes radiating out.
struct SplatShape: Shape {
    let radius: CGFloat
    let spokes: [SplatData.Spoke]
    let grow: CGFloat
    let phase: Double

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        let n = 240
        for i in 0...n {
            let a = Double(i) / Double(n) * 2 * .pi
            var k = 1 + 0.08 * sin(5 * a + phase) + 0.05 * sin(3 * a - phase * 1.3)
            for s in spokes {
                var d = abs(a - s.angle).truncatingRemainder(dividingBy: 2 * .pi)
                if d > .pi { d = 2 * .pi - d }
                k += Double(s.length) * exp(-(d * d) / (2 * s.width * s.width))
            }
            let r = radius * grow * CGFloat(k)
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

extension View {
    /// Plays the slime animation whenever `event` is set; clears it when done.
    func slimeOverlay(_ event: Binding<SlimeEvent?>) -> some View {
        overlay {
            if let e = event.wrappedValue {
                SlimeOverlay(event: e) { event.wrappedValue = nil }
                    .id(e.id)
            }
        }
    }
}

/// The "Slime out" button: a slime-green pill with a soft shine on top and one
/// small drip hanging off its bottom edge. Simple, but unmistakably goo.
struct SlimeButton: View {
    var title = "Slime out"
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font((compact ? Font.footnote : .subheadline).weight(.bold))
                .foregroundStyle(Theme.onColor)
                .padding(.horizontal, compact ? 14 : 16)
                .padding(.vertical, compact ? 9 : 13)
                .frame(maxWidth: compact ? nil : .infinity)
                .background(alignment: .bottomLeading) {
                    GeometryReader { g in
                        let drip: CGFloat = compact ? 7 : 9
                        ZStack(alignment: .topLeading) {
                            Capsule()
                                .frame(width: g.size.width, height: g.size.height)
                            // The one drip.
                            Capsule()
                                .frame(width: drip, height: drip * 1.8)
                                .offset(x: g.size.width * 0.72, y: g.size.height - drip * 0.9)
                        }
                        .foregroundStyle(Theme.slime)
                        // A wet shine along the top.
                        .overlay(alignment: .topLeading) {
                            Capsule()
                                .fill(.white.opacity(0.45))
                                .frame(width: g.size.width * 0.5, height: compact ? 3 : 4)
                                .offset(x: g.size.width * 0.12, y: compact ? 4 : 5)
                        }
                    }
                }
        }
        .buttonStyle(.pressable)
    }
}

/// A simple jelly-colored pill. The highlighted one is solid slime green.
struct JellyChip: View {
    let title: String
    var highlighted = false

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Theme.onColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(highlighted ? Theme.slime : Theme.lime.opacity(0.6), in: Capsule())
    }
}

/// The small goo splatter in the corner of a request. Tap it to slime them out.
struct SlimeSplatButton: View {
    let name: String
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    GooDollop(drip: reduceMotion ? 0.8 : 0.78 + 0.18 * CGFloat(sin(t * 1.3)))
                }
                .frame(width: 44, height: 38)
                Text("slime")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.sea)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Slime \(name) out")
    }
}

/// A dollop of goo: a soft, wide blob with drips running off the bottom, all one
/// continuous shape and gradient, plus two flung droplets and a wet shine.
struct GooDollop: View {
    /// How far the drips hang, 0 to 1.
    var drip: CGFloat = 0.8

    private let goo = LinearGradient(colors: [Theme.sprout, Theme.slime, Theme.sea],
                                     startPoint: .top, endPoint: .bottom)

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                // One gradient through blob, drips and beads, so there are no seams.
                goo.mask {
                    ZStack {
                        GooDollopShape(drip: drip, part: .blob).fill()
                        ForEach(0..<2, id: \.self) { i in
                            GooDollopShape(drip: drip, part: .drip(i)).fill()
                            GooDollopShape(drip: drip, part: .bead(i)).fill()
                        }
                    }
                }
                .shadow(color: Theme.sea.opacity(0.25), radius: 2, y: 1)
                // Flung droplets.
                Circle().fill(goo).frame(width: w * 0.12, height: w * 0.12)
                    .position(x: w * 0.08, y: h * 0.2)
                Circle().fill(goo).frame(width: w * 0.08, height: w * 0.08)
                    .position(x: w * 0.93, y: h * 0.1)
                // Shine.
                Capsule().fill(.white.opacity(0.65))
                    .frame(width: w * 0.24, height: h * 0.09)
                    .rotationEffect(.degrees(-18))
                    .position(x: w * 0.36, y: h * 0.22)
                Circle().fill(.white.opacity(0.65))
                    .frame(width: w * 0.06, height: w * 0.06)
                    .position(x: w * 0.55, y: h * 0.16)
            }
        }
    }
}

/// The dollop's outline: a wide, wobbly blob with two drips hanging straight
/// down, a longer one and a short one, each ending in a round bead. It's all one
/// path, so a single gradient flows through blob and drips with no seams.
struct GooDollopShape: Shape {
    enum Part { case blob, drip(Int), bead(Int) }

    var drip: CGFloat
    var part: Part
    var animatableData: CGFloat {
        get { drip }
        set { drip = newValue }
    }

    /// (x position, size, length) as fractions of the frame: a longer drip and a short one.
    private static let drips: [(x: CGFloat, size: CGFloat, length: CGFloat)] = [(0.6, 0.13, 0.38), (0.34, 0.1, 0.18)]

    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        let c = CGPoint(x: r.midX, y: r.minY + h * 0.4)
        let rx = w * 0.42, ry = h * 0.3
        var p = Path()

        switch part {
        case .blob:
            let n = 160
            for i in 0...n {
                let a = Double(i) / Double(n) * 2 * .pi
                let k = 1 + 0.08 * sin(3 * a + 0.7) + 0.05 * sin(5 * a - 1.1)
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rx * CGFloat(k),
                                 y: c.y + CGFloat(sin(a)) * ry * CGFloat(k))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()

        case .drip(let i), .bead(let i):
            // Wide where it leaves the blob, pinching to a thin neck, ending in a bead.
            let d = Self.drips[i]
            let cx = r.minX + w * d.x
            let topW = w * d.size * 1.9, neck = w * d.size * 0.55, bead = w * d.size * 1.15
            let top = c.y + ry * 0.55
            let beadY = c.y + ry * 0.95 + h * d.length * drip
            if case .bead = part {
                p.addEllipse(in: CGRect(x: cx - bead / 2, y: beadY - bead / 2, width: bead, height: bead))
            } else {
                let mid = top + (beadY - top) * 0.55
                p.move(to: CGPoint(x: cx - topW / 2, y: top))
                p.addCurve(to: CGPoint(x: cx - neck / 2, y: beadY - bead * 0.3),
                           control1: CGPoint(x: cx - topW / 2, y: mid),
                           control2: CGPoint(x: cx - neck / 2, y: mid))
                p.addLine(to: CGPoint(x: cx + neck / 2, y: beadY - bead * 0.3))
                p.addCurve(to: CGPoint(x: cx + topW / 2, y: top),
                           control1: CGPoint(x: cx + neck / 2, y: mid),
                           control2: CGPoint(x: cx + topW / 2, y: mid))
                p.closeSubpath()
            }
        }
        return p
    }
}
