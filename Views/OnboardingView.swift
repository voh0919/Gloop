import SwiftUI

/// The three intro slides, shown once, right before someone creates their account.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [(title: String, body: String)] = [
        ("Your people hold the key.",
         "Friends, siblings, a parent: pick a few people you trust to keep your most distracting apps locked."),
        ("Ask, don't scroll.",
         "Out of time? Ask your crew. They answer with a tap, and maybe a pep talk."),
        ("Keep each other honest.",
         "Nudge your crew, cheer their streaks, and always with both of you agreeing."),
    ]

    var body: some View {
        slides
    }

    private var slides: some View {
        VStack(spacing: 0) {
            Spacer()

            // Outer ZStacks keep the outgoing and incoming page in the same spot.
            ZStack {
                ZStack {
                    switch page {
                    case 0: HeroLock(loops: false)
                    case 1: HeroLock(loops: true)
                    default: HeroPair()
                    }
                }
                .id(page)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.6).combined(with: .opacity),
                    removal: .scale(scale: 1.2).combined(with: .opacity)
                ))
            }
            .frame(height: 220)

            ZStack(alignment: .top) {
                VStack(spacing: 12) {
                    Text(pages[page].title)
                        .font(.title.weight(.bold))
                    Text(pages[page].body)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .id("text\(page)")
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            .padding(.top, 36)
            .frame(height: 180, alignment: .top)
            .clipped()

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Theme.accent : Theme.ink.opacity(0.18))
                        .frame(width: i == page ? 22 : 6, height: 6)
                }
            }
            .padding(.bottom, 24)

            PrimaryButton(title: page == pages.count - 1 ? "Create my account" : "Continue") {
                if page < pages.count - 1 { page += 1 } else { onFinish() }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background { AmbientGoo().ignoresSafeArea() }
        .animation(Motion.smooth, value: page)
        .sensoryFeedback(.impact(weight: .light), trigger: page)
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { v in
                if v.translation.width < -40, page < pages.count - 1 { page += 1 }
                if v.translation.width > 40, page > 0 { page -= 1 }
            }
        )
    }
}

/// A lock that settles in, and on the second page keeps opening and closing.
private struct HeroLock: View {
    let loops: Bool
    @State private var open = false
    @State private var breathe = false

    var body: some View {
        LockGlyph(isOpen: open, color: open ? Theme.sea : Theme.abyss)
            .frame(width: 96, height: 124)
            .scaleEffect(breathe ? 1.03 : 0.97)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: breathe)
            .onAppear { breathe = true }
            .task {
                guard loops else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1.3))
                    open.toggle()
                }
            }
    }
}

/// Two people slide together and a link forms between them.
private struct HeroPair: View {
    @State private var together = false

    var body: some View {
        HStack(spacing: together ? 18 : 90) {
            JellyCritter(color: Theme.slime, size: 74)
            Image(systemName: "heart.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.teal)
                .scaleEffect(together ? 1 : 0.2)
                .opacity(together ? 1 : 0)
            JellyCritter(color: Theme.lagoon, size: 74, phaseOffset: 1.7)
        }
        .onAppear {
            withAnimation(Motion.bouncy.delay(0.3)) { together = true }
        }
    }
}
