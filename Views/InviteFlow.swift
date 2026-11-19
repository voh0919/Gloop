import SwiftUI

/// Four short steps: who, how you're connected, who holds the key, and
/// exactly what they're agreeing to. Steps slide in from the side.
struct InviteFlow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var forward = true
    @State private var name = ""
    @State private var isMinor = false
    @State private var mode: LinkMode = .buddy
    @State private var direction: KeyDirection = .both
    @FocusState private var nameFocused: Bool

    private var steps: [Int] { mode == .family ? [0, 1, 3] : [0, 1, 2, 3] }
    private var position: Int { steps.firstIndex(of: step) ?? 0 }
    private var effectiveDirection: KeyDirection { mode == .family ? .holdTheirs : direction }
    private var blockedReason: String? { model.inviteBlockedReason(isMinor: isMinor, mode: mode) }
    private var firstName: String {
        let n = name.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init)
        return n ?? "They"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if position > 0 {
                    CircleIconButton(symbol: "chevron.left") { go(-1) }
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                StepDots(count: steps.count, current: position)
                Spacer()
                CircleIconButton(symbol: "xmark") { dismiss() }
            }
            .padding(20)

            ZStack {
                Group {
                    switch step {
                    case 0: whoStep
                    case 1: modeStep
                    case 2: directionStep
                    default: consentStep
                    }
                }
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                ))
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .clipped()

            Group {
                if step == 3 {
                    PrimaryButton(title: "Send invite", enabled: blockedReason == nil) {
                        model.invite(name: name.trimmingCharacters(in: .whitespaces),
                                     isMinor: isMinor, mode: mode, direction: effectiveDirection)
                        dismiss()
                    }
                } else {
                    PrimaryButton(title: "Continue", enabled: canContinue) { go(1) }
                }
            }
            .padding(24)
        }
        .animation(Motion.smooth, value: step)
        .onAppear { nameFocused = true }
    }

    private var canContinue: Bool {
        if step == 0 { return !name.trimmingCharacters(in: .whitespaces).isEmpty }
        if step == 1 { return blockedReason == nil }
        return true
    }

    private func go(_ delta: Int) {
        nameFocused = false
        forward = delta > 0
        let next = min(max(position + delta, 0), steps.count - 1)
        withAnimation(Motion.smooth) { step = steps[next] }
    }

    // MARK: Steps

    private var whoStep: some View {
        StepPage(title: "Who are you inviting?") {
            TextField("Their name", text: $name)
                .font(.title3)
                .focused($nameFocused)
                .submitLabel(.next)
                .onSubmit { if canContinue { go(1) } }
                .padding(.horizontal, 20)
                .padding(.vertical, 17)
                .background(Theme.fill, in: Capsule())
            SwitchRow(title: "They're under 18", isOn: $isMinor)
        }
    }

    private var modeStep: some View {
        StepPage(title: "How are you connected?") {
            ForEach(LinkMode.allCases) { m in
                OptionCard(symbol: m.symbol, title: m.title, detail: m.detail, selected: mode == m) {
                    mode = m
                }
            }
            if let blockedReason {
                Notice(text: blockedReason)
            }
        }
    }

    private var directionStep: some View {
        StepPage(title: "Who holds the key?") {
            ForEach(KeyDirection.allCases) { d in
                OptionCard(symbol: d.symbol, title: d.title, detail: directionDetail(d), selected: direction == d) {
                    direction = d
                }
            }
        }
    }

    private func directionDetail(_ d: KeyDirection) -> String {
        switch d {
        case .holdTheirs: "\(firstName) asks you for more time."
        case .holdMine: "You ask \(firstName) for more time."
        case .both: "You keep each other honest."
        }
    }

    private var consentStep: some View {
        StepPage(title: "\(firstName) will see this before agreeing") {
            VStack(alignment: .leading, spacing: 16) {
                if effectiveDirection != .holdMine {
                    ConsentLine(symbol: "bell", text: "You're told when \(firstName) asks for time or goes over a limit.")
                    ConsentLine(symbol: "chart.bar", text: "You see \(firstName)'s daily screen time and streak.")
                    ConsentLine(symbol: "hand.wave", text: "You can send \(firstName) nudges.")
                }
                if effectiveDirection != .holdTheirs {
                    ConsentLine(symbol: "lock.open", text: "\(firstName) decides when you get more time.")
                    ConsentLine(symbol: "eye", text: "\(firstName) sees your daily screen time and streak.")
                }
                ConsentLine(
                    symbol: mode == .family ? "house" : "hourglass",
                    text: mode == .family
                        ? "Only you can remove this family link."
                        : "Either of you can leave. It takes 24 hours."
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.fill.opacity(0.6), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            if let blockedReason { Notice(text: blockedReason) }
        }
    }
}

// MARK: - Pieces

private struct StepPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title.weight(.bold))
                .padding(.bottom, 10)
                .appear(0)
            content.appear(1)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StepDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Theme.accent : Theme.ink.opacity(0.18))
                    .frame(width: i == current ? 22 : 6, height: 6)
            }
        }
        .animation(Motion.bouncy, value: current)
        .animation(Motion.smooth, value: count)
    }
}

private struct OptionCard: View {
    let symbol: String
    let title: String
    let detail: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
                    .background(Theme.fill, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.body.weight(.semibold))
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Checkmark(on: selected)
            }
            .padding(16)
            .multilineTextAlignment(.leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(selected ? Theme.accent : Theme.ink.opacity(0.12), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.pressable)
        .foregroundStyle(Theme.ink)
        .animation(Motion.snappy, value: selected)
        .sensoryFeedback(.selection, trigger: selected)
    }
}

private struct ConsentLine: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct Notice: View {
    let text: String
    @State private var shakes = 0

    var body: some View {
        Label(text, systemImage: "exclamationmark.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
            .modifier(Shake(amount: 6, animatableData: CGFloat(shakes)))
            .onAppear { withAnimation(.linear(duration: 0.4)) { shakes += 1 } }
            .transition(.opacity)
    }
}
