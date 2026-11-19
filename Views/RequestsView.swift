import SwiftUI

struct RequestsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let pending = model.pendingIncoming

        ScrollView {
            VStack(spacing: 14) {
                ScreenHeader(
                    title: "Requests",
                    subtitle: pending.isEmpty ? "All caught up" : "\(pending.count) waiting for you"
                )
                .appear(0)

                if pending.isEmpty {
                    EmptyRequests()
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }

                ForEach(Array(pending.enumerated()), id: \.element.id) { i, r in
                    RequestCard(request: r)
                        .appear(1 + i)
                        .transition(.jellyPop)
                }

                if !model.answeredRequests.isEmpty {
                    SectionLabel(text: "Earlier")
                        .padding(.top, 18)
                    ForEach(model.answeredRequests) { r in
                        HistoryRow(request: r)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .animation(Motion.smooth, value: model.requests)
        }
        .scrollIndicators(.hidden)
    }
}

private struct RequestCard: View {
    let request: UnlockRequest
    @Environment(AppModel.self) private var model

    /// Set the moment you answer, so the card can show a check before it leaves.
    @State private var answer: Int?? = nil
    @State private var note = ""
    @State private var media: Attachment?
    @State private var viewing: Attachment?
    @State private var confetti = 0

    var body: some View {
        let person = model.person(request.from)

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                if let person { Avatar(person: person) }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(person?.firstName ?? "Someone") wants \(request.minutes) min")
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text("\(request.appName) · \(request.date.shortAgo)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                // Saying no = sliming them out.
                SlimeSplatButton(name: person?.firstName ?? "them") { respond(nil) }
                    .disabled(answer != nil)
            }

            if !request.reason.isEmpty || request.proof != nil {
                RequestMessage(text: request.reason, attachment: request.proof,
                               color: person?.color ?? Theme.accent) { viewing = $0 }
            }

            HStack(spacing: 8) {
                TextField("Add a note for \(person?.firstName ?? "them")… (optional)", text: $note)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Theme.bg, in: Capsule())
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                AttachButton(attachment: $media, size: 42)
            }

            HStack(spacing: 8) {
                ForEach([5, 15, 30], id: \.self) { m in
                    Button { respond(m) } label: {
                        JellyChip(title: "\(m)m")
                    }
                    .buttonStyle(.pressable)
                }
            }
            .disabled(answer != nil)

        }
        .padding(18)
        .background(Theme.fill.opacity(0.6), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.line, lineWidth: 0.5))
        .overlay {
            if let answer {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.regularMaterial)
                    Group {
                        if answer == nil {
                            VStack(spacing: 6) {
                                GooDollop(drip: 0.9).frame(width: 84, height: 72)
                                Text("Slimed!")
                                    .font(.headline.weight(.heavy))
                                    .foregroundStyle(Theme.onColor)
                            }
                        } else {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundStyle(Theme.onColor)
                        }
                    }
                    .transition(.jellyPop)
                }
                .transition(.opacity)
            }
        }
        .overlay { ConfettiBurst(trigger: confetti) }
        .fullScreenCover(item: $viewing) { MediaViewer(attachment: $0) }
        .animation(Motion.bouncy, value: answer != nil)
        .sensoryFeedback(.success, trigger: answer != nil)
    }

    private func respond(_ minutes: Int?) {
        answer = .some(minutes)
        if minutes != nil {
            confetti += 1
        } else if let person = model.person(request.from) {
            model.slimeOut(person, app: request.appName, fromRequest: true)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(750))
            model.answer(request, minutes: minutes, note: note, media: media)
        }
    }
}

/// What the friend sent, as one message bubble in their color: an optional
/// photo or video thumbnail (tap to open) and an optional note. Either can be
/// on its own.
private struct RequestMessage: View {
    let text: String
    let attachment: Attachment?
    let color: Color
    let open: (Attachment) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let attachment {
                Button { open(attachment) } label: {
                    Image(uiImage: attachment.thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            if attachment.kind == .video {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(.black.opacity(0.45), in: Circle())
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(Theme.onColor)
                                .frame(width: 16, height: 16)
                                .background(.white.opacity(0.9), in: Circle())
                                .padding(3)
                        }
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(attachment.kind == .video ? "Video, tap to play" : "Photo, tap to view")
            }
            VStack(alignment: .leading, spacing: 2) {
                if !text.isEmpty {
                    Text(text)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let attachment {
                    Text(attachment.kind == .video ? "Sent a video" : "Sent a photo")
                        .font(.subheadline.weight(.semibold))
                    Text("Tap to view").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(attachment == nil ? 12 : 8)
        .padding(.trailing, 4)
        .background(color.opacity(0.14),
                    in: UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 18,
                                               bottomTrailingRadius: 18, topTrailingRadius: 18,
                                               style: .continuous))
    }
}

/// An answered request, shown as a tiny conversation: their request, then your
/// answer as a reply (with your note and any photo or video).
private struct HistoryRow: View {
    let request: UnlockRequest
    @Environment(AppModel.self) private var model
    @State private var viewing: Attachment?

    var body: some View {
        let person = model.person(request.from)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if let person { Avatar(person: person, size: 30) }
                Text("\(person?.firstName ?? "Someone") asked for \(request.minutes) min")
                    .font(.subheadline.weight(.semibold))
                Text("· \(request.appName)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            if !request.reason.isEmpty || request.proof != nil {
                RequestMessage(text: request.reason, attachment: request.proof,
                               color: person?.color ?? Theme.accent) { viewing = $0 }
                    .padding(.leading, 40)
            }
            // Your answer, as a reply on the right.
            HStack {
                Spacer(minLength: 50)
                VStack(alignment: .trailing, spacing: 6) {
                    Label(outcome, systemImage: isSlimed ? "drop.fill" : "checkmark.circle.fill")
                        .font(.footnote.weight(.bold))
                    if let media = request.answerMedia {
                        Button { viewing = media } label: { AttachmentThumb(attachment: media, size: 56) }
                            .buttonStyle(.pressable)
                    }
                    if !request.note.isEmpty {
                        Text(request.note).font(.subheadline)
                    }
                }
                .foregroundStyle(Theme.onColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSlimed ? Theme.lime : Theme.accent,
                            in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18,
                                                       bottomTrailingRadius: 4, topTrailingRadius: 18,
                                                       style: .continuous))
            }
        }
        .padding(14)
        .background(Theme.fill.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .fullScreenCover(item: $viewing) { MediaViewer(attachment: $0) }
    }

    private var isSlimed: Bool { request.state == .denied }

    private var outcome: String {
        switch request.state {
        case .approved(let m): "You gave \(m) min"
        case .denied: "You slimed them out"
        case .pending: ""
        }
    }
}

private struct EmptyRequests: View {
    @State private var float = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.onColor)
                .frame(width: 76, height: 76)
                .background(Theme.accentSoft, in: Circle())
                .offset(y: float ? -4 : 4)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: float)
            Text("All caught up. Your crew's doing great.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .onAppear { float = true }
    }
}
