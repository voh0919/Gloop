import SwiftUI

/// "Your crew": friends first, family in its own quieter section.
struct BuddiesView: View {
    @Environment(AppModel.self) private var model
    @State private var inviting = false
    @State private var selected: Person?

    var body: some View {
        @Bindable var model = model
        let rels = model.relationships
        let crew = rels.filter { $0.mode == .buddy }
        let family = rels.filter { $0.mode == .family }

        ScrollView {
            VStack(spacing: 10) {
                ScreenHeader(title: "Your crew", subtitle: "Keep each other honest") {
                    CircleIconButton(symbol: "plus") { inviting = true }
                }
                .appear(0)

                if !crew.isEmpty {
                    SectionLabel(text: "Friends").padding(.top, 8).appear(1)
                    ForEach(Array(crew.enumerated()), id: \.element.id) { i, r in
                        row(r).appear(2 + i)
                    }
                }

                if !family.isEmpty {
                    SectionLabel(text: "Family").padding(.top, 18).appear(5)
                    ForEach(family) { r in row(r).appear(6) }
                }


            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .animation(Motion.smooth, value: rels)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $inviting) {
            InviteFlow()
                .environment(model)
        }
        .sheet(item: $selected) { p in
            BuddyDetail(personID: p.id)
                .environment(model)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func row(_ r: Relationship) -> some View {
        Button { selected = r.person } label: {
            BuddyRow(rel: r, streak: model.stats[r.id]?.streak, lastMessage: model.thread(with: r.id).last)
        }
        .buttonStyle(.pressable)
        .foregroundStyle(Theme.ink)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

private struct BuddyRow: View {
    let rel: Relationship
    let streak: Int?
    let lastMessage: Message?

    var body: some View {
        HStack(spacing: 14) {
            Avatar(person: rel.person, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(rel.person.name).font(.body.weight(.semibold))
                    Image(systemName: rel.relation.symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Group {
                    if rel.isPending {
                        HStack(spacing: 5) { PendingDot(); Text("Waiting for them to accept") }
                    } else if rel.leavingAt != nil {
                        Label("Ending within 24 hours", systemImage: "hourglass")
                    } else if let lastMessage {
                        Text(lastMessage.preview).lineLimit(1)
                    } else {
                        Text(rel.relation.label)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
            }
            Spacer(minLength: 8)
            if let streak, streak > 0, !rel.isPending {
                Label("\(streak)", systemImage: "flame.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.onColor)
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accentSoft, in: Capsule())
            }
        }
        .padding(.vertical, 6)
        .animation(Motion.smooth, value: rel)
    }
}

private struct PendingDot: View {
    @State private var on = false
    var body: some View {
        Circle()
            .fill(Theme.accent)
            .frame(width: 6, height: 6)
            .opacity(on ? 1 : 0.25)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

struct RulePicker: View {
    @Binding var rule: ApprovalRule

    var body: some View {
        VStack(spacing: 0) {
            ForEach(ApprovalRule.allCases) { r in
                Button { rule = r } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.title).font(.body.weight(.medium))
                            Text(r.detail).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Checkmark(on: rule == r)
                    }
                    .padding(16)
                }
                .buttonStyle(.pressable)
                .foregroundStyle(Theme.ink)
                if r != ApprovalRule.allCases.last {
                    Rectangle().fill(Theme.line).frame(height: 0.5).padding(.leading, 16)
                }
            }
        }
        .background(Theme.fill.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sensoryFeedback(.selection, trigger: rule)
    }
}

/// A circle that fills with a spring when chosen.
struct Checkmark: View {
    let on: Bool
    var body: some View {
        ZStack {
            Circle().stroke(Theme.line, lineWidth: 1.5)
            Circle().fill(Theme.accent).scaleEffect(on ? 1 : 0.01)
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.onColor)
                .scaleEffect(on ? 1 : 0.01)
        }
        .frame(width: 24, height: 24)
        .animation(Motion.bouncy, value: on)
    }
}

// MARK: - Buddy detail: stats + a little chat of typed nudges

struct BuddyDetail: View {
    let personID: Person.ID
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var confirmingLeave = false
    @FocusState private var composing: Bool

    private let suggestions = ["phone down", "you got this", "proud of you",
                               "go touch grass", "study date later?"]

    var body: some View {
        if let rel = model.relationship(with: personID) {
            let thread = model.thread(with: personID)
            let isTyping = model.typing.contains(personID)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 22) {
                        header(rel).padding(.top, 24)

                        if rel.iHoldTheirKey, !rel.isPending, let s = model.stats[rel.id] {
                            statsCard(rel.person, s).appear(2)
                        }

                        VStack(spacing: 8) {
                            if thread.isEmpty && !isTyping {
                                Text("Say hi to \(rel.person.firstName). A little encouragement goes a long way.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 24)
                            }
                            ForEach(thread) { m in
                                Bubble(message: m, mine: m.from == model.me.id, color: rel.person.color) {
                                    model.toggleLike(m)
                                }
                                .id(m.id)
                                .transition(.jellyPop)
                            }
                            if isTyping {
                                TypingBubble(color: rel.person.color)
                                    .id("typing")
                                    .transition(.jellyPop)
                            }
                        }
                        .animation(Motion.bouncy, value: thread)
                        .animation(Motion.bouncy, value: isTyping)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear { proxy.scrollTo(thread.last?.id, anchor: .bottom) }
                .onChange(of: thread.count) { _, _ in
                    withAnimation(Motion.smooth) { proxy.scrollTo(thread.last?.id, anchor: .bottom) }
                }
                .onChange(of: isTyping) { _, typing in
                    if typing { withAnimation(Motion.smooth) { proxy.scrollTo("typing", anchor: .bottom) } }
                }
                .safeAreaInset(edge: .bottom) { composer(rel.person) }
            }
            // The detail is a sheet, so it needs its own copy of the slime animation.
            .slimeOverlay(Bindable(model).slimeEvent)
            .confirmationDialog("End this Gloop link?", isPresented: $confirmingLeave, titleVisibility: .visible) {
                Button("End in 24 hours", role: .destructive) { model.startLeaving(rel.id) }
            } message: {
                Text("Blocks stay on for 24 hours, so leaving can't be used to skip a limit.")
            }
        }
    }

    // MARK: Pieces

    private func header(_ rel: Relationship) -> some View {
        VStack(spacing: 8) {
            Avatar(person: rel.person, size: 76).appear(0)
            Text(rel.person.name).font(.title2.weight(.bold)).appear(1)
            Label(rel.relation.label, systemImage: rel.relation.symbol)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .appear(1)
            if let at = rel.leavingAt {
                HStack(spacing: 6) {
                    Text("Ends \(at.formatted(.relative(presentation: .named)))")
                    Button("Keep them") { model.cancelLeaving(rel.id) }
                        .fontWeight(.semibold)
                }
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.accentSoft, in: Capsule())
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) { moreMenu(rel) }
        .animation(Motion.bouncy, value: rel.leavingAt)
    }

    @ViewBuilder
    private func moreMenu(_ rel: Relationship) -> some View {
        Menu {
            if rel.mode == .family {
                if rel.iHoldTheirKey {
                    Button("Remove family link", role: .destructive) {
                        model.removeFamilyLink(rel.id)
                        dismiss()
                    }
                }
            } else if rel.leavingAt == nil {
                Button("End link…", role: .destructive) { confirmingLeave = true }
            } else {
                Button("Keep them") { model.cancelLeaving(rel.id) }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 38)
                .background(Theme.fill, in: Circle())
        }
    }

    private func statsCard(_ person: Person, _ s: Stats) -> some View {
        let slimed = model.slimed.contains(person.id)
        return VStack(spacing: 14) {
            HStack(spacing: 20) {
                TimeBlob(used: s.minutesToday, limit: s.limitToday, compact: true)
                    .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 10) {
                    Label("\(s.streak) day streak", systemImage: "flame.fill").font(.subheadline.weight(.semibold))
                    Label("\(s.improvement)% less than usual", systemImage: "arrow.down.right").font(.subheadline.weight(.semibold))
                }
                Spacer(minLength: 0)
            }
            if let app = s.overApp {
                if slimed {
                    Label("Slimed. \(app) is back in the jar.", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.sea)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(s.overMinutes) min over on \(app)")
                            .font(.subheadline.weight(.bold))
                        SlimeButton(title: "Slime \(person.firstName) out") {
                            model.slimeOut(person, app: app)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(16)
        .background(person.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(Motion.bouncy, value: slimed)
    }

    private func composer(_ person: Person) -> some View {
        let canSend = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { s in
                        Button { draft = s; composing = true } label: {
                            Text(s)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.fill, in: Capsule())
                        }
                        .buttonStyle(.pressable)
                        .foregroundStyle(Theme.ink)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Nudge \(person.firstName)…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($composing)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Button {
                    model.sendMessage(draft, to: person)
                    draft = ""
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.onColor)
                        .frame(width: 44, height: 44)
                        .background(canSend ? Theme.accent : Theme.ink.opacity(0.15), in: Circle())
                        .scaleEffect(canSend ? 1 : 0.85)
                        .rotationEffect(.degrees(canSend ? 0 : -45))
                }
                .buttonStyle(.pressable)
                .disabled(!canSend)
                .animation(Motion.bouncy, value: canSend)
                .sensoryFeedback(.impact(weight: .medium), trigger: model.thread(with: person.id).count)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 10)
        .background(.bar)
    }
}

/// A chat bubble. Mine are coral; theirs are tinted in their color.
/// Double-tap to heart it.
private struct Bubble: View {
    let message: Message
    let mine: Bool
    let color: Color
    let onLike: () -> Void
    @State private var viewing: Attachment?

    var body: some View {
        HStack {
            if mine { Spacer(minLength: 60) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                content
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .foregroundStyle(mine ? Theme.onColor : Theme.ink)
                    .background(mine ? Theme.accent : color.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(alignment: mine ? .bottomLeading : .bottomTrailing) {
                        if message.liked {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.teal)
                                .padding(4)
                                .background(Theme.bg, in: Circle())
                                .offset(x: mine ? -10 : 10, y: 10)
                                .transition(.scale(scale: 0.1).combined(with: .opacity))
                        }
                    }
                    .onTapGesture(count: 2, perform: onLike)
                Text(message.date.shortAgo)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.top, message.liked ? 8 : 0)
            }
            if !mine { Spacer(minLength: 60) }
        }
        .animation(Motion.bouncy, value: message.liked)
        .sensoryFeedback(.impact(weight: .light), trigger: message.liked)
        .fullScreenCover(item: $viewing) { MediaViewer(attachment: $0) }
    }

    /// Plain text, or for requests and answers: a small header, the photo or
    /// video (tap to open), and the note.
    @ViewBuilder
    private var content: some View {
        if message.event == nil && message.media == nil {
            Text(message.text)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if let event = message.event {
                    Label(headline(event), systemImage: symbol(event))
                        .font(.footnote.weight(.bold))
                }
                if let media = message.media {
                    Button { viewing = media } label: {
                        Image(uiImage: media.thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                if media.kind == .video {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .background(.black.opacity(0.45), in: Circle())
                                }
                            }
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(media.kind == .video ? "Video, tap to play" : "Photo, tap to view")
                }
                if !message.text.isEmpty {
                    Text(message.text)
                }
            }
        }
    }

    private func headline(_ e: ChatEvent) -> String {
        switch e {
        case .request(let app, let minutes): "Asked for \(minutes) min on \(app)"
        case .gave(let minutes, let app): "Gave \(minutes) min on \(app)"
        case .slimed(let app): "Slimed out of \(app)"
        }
    }

    private func symbol(_ e: ChatEvent) -> String {
        switch e {
        case .request: "clock.fill"
        case .gave: "checkmark.circle.fill"
        case .slimed: "drop.fill"
        }
    }
}

/// Three dots that hop while a friend is typing.
private struct TypingBubble: View {
    let color: Color
    @State private var hop = false

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .offset(y: hop ? -4 : 2)
                        .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(Double(i) * 0.13),
                                   value: hop)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Spacer()
        }
        .onAppear { hop = true }
    }
}
