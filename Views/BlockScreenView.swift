import SwiftUI

/// What you see when you open a limited app. In the real app this is drawn by
/// a Screen Time shield; here it's a full-screen view so the flow can be tried.
struct BlockScreenView: View {
    let app: LimitedApp
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    enum Phase: Hashable {
        case locked, asking
        /// Who answered, and the note they sent with it.
        case approved(Person?, String)
        case denied(Person?, String)
    }

    private var answer: (person: Person?, note: String)? {
        switch phase {
        case .approved(let p, let n), .denied(let p, let n): return (p, n)
        default: return nil
        }
    }

    @State private var phase: Phase = .locked
    @State private var minutes = 15
    @State private var reason = ""
    /// A photo or video sent along with the request, as proof or context.
    @State private var proof: Attachment?
    @State private var shakes = 0
    @State private var appeared = false
    @State private var confetti = 0
    /// Plays when a keyholder slimes you out instead of giving you time.
    @State private var slimed: SlimeEvent?
    @Namespace private var ns

    private var isOpen: Bool { if case .approved = phase { return true } else { return false } }
    private var isAsking: Bool { phase == .asking }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                CircleIconButton(symbol: "xmark") { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer(minLength: 20)

            ZStack {
                if isAsking {
                    PulseRings()
                        .frame(width: 280, height: 280)
                        .transition(.opacity)
                }
                LockGlyph(isOpen: isOpen, color: isOpen ? Theme.sea : Theme.abyss)
                    .frame(width: 80, height: 104)
                    .modifier(Shake(animatableData: CGFloat(shakes)))
                    .scaleEffect(appeared ? (isAsking ? 0.9 : 1) : 0.5)
                    .opacity(appeared ? 1 : 0)
                ConfettiBurst(trigger: confetti)
            }
            .frame(height: 260)

            // A ZStack so the old and new text crossfade in place instead of stacking.
            ZStack(alignment: .top) {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2.weight(.bold))
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                    if let answer, !answer.note.isEmpty {
                        NoteBubble(person: answer.person, note: answer.note)
                            .padding(.top, 10)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .id(phase)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 10)),
                    removal: .opacity
                ))
            }
            .frame(height: 170, alignment: .top)

            Spacer(minLength: 20)

            ZStack(alignment: .bottom) {
                controls
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Theme.bg)
        .animation(Motion.smooth, value: phase)
        .onAppear {
            withAnimation(Motion.bouncy.delay(0.1)) { appeared = true }
        }
        .sensoryFeedback(.success, trigger: isOpen) { _, new in new }
        .sensoryFeedback(.error, trigger: shakes)
        .slimeOverlay($slimed)
    }

    // MARK: Text

    private var keyholderNames: String {
        let names = model.myKeyholders.map(\.firstName)
        switch names.count {
        case 0: return "your crew"
        case 1: return names[0]
        default: return names.dropLast().joined(separator: ", ") + " and " + names.last!
        }
    }

    private var title: String {
        switch phase {
        case .locked: "\(app.name) is locked"
        case .asking: "Asking \(keyholderNames)"
        case .approved(let p, _): "\(p?.firstName ?? "Your crew") said yes!"
        case .denied(let p, _): "\(p?.firstName ?? "Your crew") slimed you out"
        }
    }

    private var subtitle: String {
        switch phase {
        case .locked:
            app.isOver
                ? "You've used all \(app.dailyMinutes) minutes today. Ask for a little more?"
                : "You've used \(app.usedMinutes) of \(app.dailyMinutes) minutes. Ask to open it?"
        case .asking: "Fingers crossed…"
        case .approved: "You have \(minutes) minutes, starting now."
        case .denied: "Wipe off the goo and take a break. You can ask again later."
        }
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .locked:
            VStack(spacing: 14) {
                minutePicker
                HStack(spacing: 10) {
                    TextField("Add a message (optional)", text: $reason)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 15)
                        .background(Theme.fill, in: Capsule())
                    AttachButton(attachment: $proof, size: 50)
                }
                PrimaryButton(title: "Ask for \(minutes) minutes") { ask() }
            }
            .transition(.opacity.combined(with: .offset(y: 20)))

        case .asking:
            VStack(spacing: 18) {
                if let proof {
                    HStack(spacing: 10) {
                        AttachmentThumb(attachment: proof, size: 40)
                        Text(proof.kind == .video ? "Your video was sent too" : "Your photo was sent too")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                WaitingAvatars(people: model.myKeyholders)
                SecondaryButton(title: "Cancel") { phase = .locked }
            }
            .transition(.opacity.combined(with: .offset(y: 20)))

        case .approved:
            PrimaryButton(title: "Open \(app.name)") {
                model.grantUnlock(app, minutes: minutes)
                dismiss()
            }
            .transition(.scale(scale: 0.9).combined(with: .opacity))

        case .denied:
            VStack(spacing: 12) {
                PrimaryButton(title: "Okay") { dismiss() }
                SecondaryButton(title: "Ask again") { phase = .locked }
            }
            .transition(.opacity.combined(with: .offset(y: 20)))
        }
    }

    private var minutePicker: some View {
        HStack(spacing: 6) {
            ForEach([5, 15, 30], id: \.self) { m in
                Button {
                    minutes = m
                } label: {
                    Text("\(m) min")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(minutes == m ? Theme.onColor : Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            if minutes == m {
                                Capsule().fill(Theme.accent)
                                    .matchedGeometryEffect(id: "minutes", in: ns)
                            }
                        }
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(4)
        .background(Theme.fill, in: Capsule())
        .animation(Motion.snappy, value: minutes)
        .sensoryFeedback(.selection, trigger: minutes)
    }

    private func ask() {
        phase = .asking
        Task { @MainActor in
            let result = await model.askForTime(minutes: minutes)
            guard phase == .asking else { return } // cancelled meanwhile
            if result.approved {
                withAnimation(Motion.bouncy) { phase = .approved(result.by, result.note) }
                confetti += 1
            } else {
                phase = .denied(result.by, result.note)
                withAnimation(.linear(duration: 0.5)) { shakes += 1 }
                if let by = result.by {
                    slimed = SlimeEvent(person: by, app: app.name, byMe: false)
                }
            }
        }
    }
}

/// What the keyholder said, as a speech bubble from their avatar.
private struct NoteBubble: View {
    let person: Person?
    let note: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if let person { Avatar(person: person, size: 30) }
            Text(note)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background((person?.color ?? Theme.accent).opacity(0.14),
                            in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 4,
                                                       bottomTrailingRadius: 18, topTrailingRadius: 18,
                                                       style: .continuous))
        }
        .transition(.scale(scale: 0.5, anchor: .bottomLeading).combined(with: .opacity))
    }
}

/// Keyholder avatars that bob one after another, like they're thinking.
private struct WaitingAvatars: View {
    let people: [Person]
    @State private var bob = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(people.enumerated()), id: \.element.id) { i, p in
                Avatar(person: p, size: 40)
                    .offset(y: bob ? -6 : 0)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.18),
                        value: bob
                    )
            }
        }
        .frame(height: 52)
        .onAppear { bob = true }
    }
}
