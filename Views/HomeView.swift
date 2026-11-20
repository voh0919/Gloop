import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Binding var tab: AppTab
    @State private var openThread: Person?
    @State private var showingSettings = false
    @State private var showingApps = false
    @State private var showingBreakdown = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                ScreenHeader(title: "Today", subtitle: "Hey \(model.me.firstName)") {
                    CircleIconButton(symbol: "gearshape.fill") { showingSettings = true }
                        .accessibilityLabel("Settings")
                }
                .appear(0)

                VStack(spacing: 14) {
                    TimeBlob(used: model.totalUsed, limit: model.totalLimit) {
                        withAnimation(Motion.bouncy) { showingBreakdown.toggle() }
                    }
                    .frame(width: 250, height: 250)
                    .padding(.vertical, 4)

                    if showingBreakdown {
                        TimeBreakdown(apps: model.apps, left: model.totalLimit - model.totalUsed) {
                            withAnimation(Motion.smooth) { showingBreakdown = false }
                        }
                        .transition(.jellyPop)
                    }
                }
                .appear(1)

                statsRow.appear(2)

                // Places to go: two shortcut tiles side by side.
                HStack(spacing: 12) {
                    LimitedAppsTile(apps: model.apps) { showingApps = true }
                    RequestsTile(requests: model.pendingIncoming, person: model.person) { tab = .requests }
                }
                .fixedSize(horizontal: false, vertical: true)
                .appear(3)

                // Things to act on: friends who are over a limit.
                if !model.crewOverLimit.isEmpty {
                    VStack(spacing: 10) {
                        SectionLabel(text: "Over the limit")
                        ForEach(model.crewOverLimit, id: \.person.id) { item in
                            OverLimitCard(person: item.person, stats: item.stats,
                                          slimed: model.slimed.contains(item.person.id)) {
                                model.slimeOut(item.person, app: item.stats.overApp ?? "that app")
                            }
                        }
                    }
                    .appear(4)
                }

                if !model.inbox.isEmpty {
                    VStack(spacing: 10) {
                        SectionLabel(text: "From your crew").appear(3)
                        ForEach(Array(model.inbox.prefix(3).enumerated()), id: \.element.id) { i, m in
                            if let p = model.person(m.from) {
                                CrewNoteCard(message: m, person: p,
                                             onLike: { model.toggleLike(m) },
                                             onOpen: { openThread = p })
                                    .appear(4 + i)
                                    .transition(.jellyPop)
                            }
                        }
                    }
                    .animation(Motion.bouncy, value: model.inbox)
                }

            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .animation(Motion.smooth, value: model.pendingIncoming.count)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showingApps) {
            LimitedAppsSheet()
                .environment(model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(model)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $openThread) { p in
            BuddyDetail(personID: p.id)
                .environment(model)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var statsRow: some View {
        let s = model.stats[model.me.id]
        return HStack(spacing: 0) {
            Stat(value: s?.streak ?? 0, label: "day streak")
            Rectangle().fill(Theme.line).frame(width: 0.5, height: 36)
            Stat(value: model.myKeyholders.count, label: "hold your key")
            Rectangle().fill(Theme.line).frame(width: 0.5, height: 36)
            Stat(value: s?.improvement ?? 0, suffix: "%", label: "less than usual")
        }
    }
}

/// What makes up the blob's number: each limited app and what it has left.
/// Opens when you tap the blob; tap it to fold it away.
private struct TimeBreakdown: View {
    let apps: [LimitedApp]
    let left: Int
    let onClose: () -> Void

    private func minutesLeft(_ a: LimitedApp) -> Int { max(0, a.dailyMinutes - a.usedMinutes) }
    private var sorted: [LimitedApp] { apps.sorted { minutesLeft($0) > minutesLeft($1) } }

    var body: some View {
        Button(action: onClose) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Your \(left) minutes, app by app")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                if apps.isEmpty {
                    Text("No apps limited yet.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(Array(sorted.enumerated()), id: \.element.id) { i, app in
                    row(app).appear(i)
                }
                Text("Each app keeps its own limit, so leftover time doesn't move between apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.fill.opacity(0.7), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.line, lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
        .foregroundStyle(Theme.ink)
        .accessibilityHint("Hides the breakdown")
    }

    private func row(_ app: LimitedApp) -> some View {
        let unlocked = app.isUnlocked()
        let locked = app.isOver && !unlocked
        return HStack(spacing: 12) {
            Image(systemName: app.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.onColor)
                .frame(width: 30, height: 30)
                .background(locked ? Theme.fill : Theme.accentSoft,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(app.name).font(.subheadline.weight(.semibold))
            Spacer()
            if locked {
                Label("Locked", systemImage: "lock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            } else if unlocked {
                Label("Unlocked", systemImage: "lock.open.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.ocean)
            } else {
                Text("\(minutesLeft(app)) min left")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.onColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.lime, in: Capsule())
            }
        }
    }
}

/// A shortcut tile: some art on top, a title, and a short status line.
private struct ShortcutTile<Art: View>: View {
    let title: String
    let detail: String
    var highlight: String? = nil
    let action: () -> Void
    @ViewBuilder var art: Art

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    art
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 46, alignment: .top)
                .padding(.bottom, 10)
                Text(title).font(.body.weight(.bold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
                // Always takes a line, so both tiles stay the same height.
                Text(highlight ?? " ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ocean)
                    .opacity(highlight == nil ? 0 : 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
            .background(Theme.fill.opacity(0.7), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.line, lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
        .foregroundStyle(Theme.ink)
    }
}

/// Shortcut to all your limited apps: a fanned stack of their icons.
private struct LimitedAppsTile: View {
    let apps: [LimitedApp]
    let action: () -> Void

    private var total: Int { apps.reduce(0) { $0 + $1.dailyMinutes } }
    private var atLimit: Int { apps.filter { $0.isOver && !$0.isUnlocked() }.count }

    var body: some View {
        ShortcutTile(title: "Limited apps",
                     detail: apps.isEmpty ? "Choose apps" : "\(apps.count) apps · \(EditAppsView.format(total))",
                     highlight: atLimit > 0 ? "\(atLimit) locked for today" : nil,
                     action: action) {
            ZStack(alignment: .leading) {
                if apps.isEmpty {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(Theme.sprout, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                ForEach(Array(apps.prefix(3).enumerated()), id: \.element.id) { i, app in
                    Image(systemName: app.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background([Theme.lime, Theme.sprout, Theme.moss][i],
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Theme.bg, lineWidth: 2))
                        .rotationEffect(.degrees(Double(i - 1) * 9))
                        .offset(x: CGFloat(i) * 16)
                        .zIndex(Double(-i))
                }
            }
            .foregroundStyle(Theme.onColor)
        }
        .accessibilityLabel("Limited apps, \(apps.count) apps")
    }
}

/// Shortcut to the Requests tab: who's asking, or all caught up.
private struct RequestsTile: View {
    let requests: [UnlockRequest]
    let person: (Person.ID) -> Person?
    let action: () -> Void

    var body: some View {
        ShortcutTile(title: "Requests",
                     detail: requests.isEmpty ? "All caught up" : "\(requests.count) waiting",
                     highlight: requests.isEmpty ? nil : "Friends need you",
                     action: action) {
            if requests.isEmpty {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.onColor)
                    .frame(width: 40, height: 40)
                    .background(Theme.lime, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                HStack(spacing: -12) {
                    ForEach(requests.prefix(3)) { r in
                        if let p = person(r.from) {
                            Avatar(person: p, size: 40)
                        }
                    }
                }
            }
        }
        .accessibilityLabel(requests.isEmpty ? "Requests, all caught up" : "Requests, \(requests.count) waiting")
    }
}

/// Every limited app with today's usage. Tap one to see what opening it does;
/// Edit chooses apps and limits.
struct LimitedAppsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Text("Limited apps").font(.title.weight(.bold))
                    Spacer()
                    Button { editing = true } label: {
                        Label("Edit", systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.onColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.accentSoft, in: Capsule())
                    }
                    .buttonStyle(.pressable)
                }
                .padding(.bottom, 6)

                if model.apps.isEmpty {
                    Text("Nothing limited yet. Tap Edit to choose apps.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 30)
                }
                ForEach(Array(model.apps.enumerated()), id: \.element.id) { i, app in
                    AppRow(app: app, index: i) { open(app) }
                        .appear(i)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if !model.apps.isEmpty {
                    Text("Tap an app to see what happens when you open it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(24)
            .animation(Motion.smooth, value: model.apps)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $editing) {
            EditAppsView()
                .environment(model)
                .presentationDragIndicator(.visible)
        }
    }

    private func open(_ app: LimitedApp) {
        if app.isUnlocked() {
            model.showToast("Opening \(app.name)")
            return
        }
        // The block screen is shown from the main screen, so close this sheet first.
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            model.blockingApp = app
        }
    }
}

/// A friend who's over their limit. Slime them out to lock the app again.
private struct OverLimitCard: View {
    let person: Person
    let stats: Stats
    let slimed: Bool
    let onSlime: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Avatar(person: person, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(slimed ? "\(person.firstName) got slimed" : "\(person.firstName) is over")
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                Text(slimed ? "\(stats.overApp ?? "The app") is back in the jar"
                            : "\(stats.overMinutes) min on \(stats.overApp ?? "a limited app")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .contentTransition(.opacity)
            Spacer(minLength: 8)
            if slimed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.sea)
                    .transition(.scale.combined(with: .opacity))
            } else {
                SlimeButton(compact: true, action: onSlime)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(14)
        .background(Theme.lime.opacity(slimed ? 0.25 : 0.55),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Theme.slime.opacity(0.5), lineWidth: 1))
        .animation(Motion.bouncy, value: slimed)
    }
}

/// A friend's nudge, shown like a little speech bubble. Tap to reply; tap the heart to love it.
private struct CrewNoteCard: View {
    let message: Message
    let person: Person
    let onLike: () -> Void
    let onOpen: () -> Void
    @State private var hearts = 0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(person: person, size: 40)
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(person.firstName).font(.subheadline.weight(.bold))
                        Text(message.date.shortAgo).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(message.text)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(person.color.opacity(0.12),
                            in: UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 18,
                                                       bottomTrailingRadius: 18, topTrailingRadius: 18,
                                                       style: .continuous))
            }
            .buttonStyle(.pressable)
            .foregroundStyle(Theme.ink)

            Button(action: onLike) {
                Image(systemName: message.liked ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(message.liked ? Theme.teal : Color.secondary)
                    .symbolEffect(.bounce, value: message.liked)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.pressable)
            // A little spray of goo droplets when you heart it.
            .overlay { ConfettiBurst(trigger: hearts, spread: 0.28, count: 9) }
            .onChange(of: message.liked) { _, liked in if liked { hearts += 1 } }
            .sensoryFeedback(.impact(weight: .light), trigger: message.liked)
        }
    }
}

private struct Stat: View {
    let value: Int
    var suffix = ""
    let label: String
    @State private var shown = 0

    var body: some View {
        VStack(spacing: 2) {
            Text("\(shown)\(suffix)")
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(Motion.smooth.delay(0.4)) { shown = value }
        }
        .onChange(of: value) { _, v in withAnimation(Motion.smooth) { shown = v } }
    }
}

private struct AppRow: View {
    let app: LimitedApp
    let index: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let unlocked = app.isUnlocked(at: context.date)
                HStack(spacing: 14) {
                    Image(systemName: app.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.onColor)
                        .frame(width: 44, height: 44)
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(app.name).font(.body.weight(.semibold))
                            Spacer()
                            Text(caption(unlocked: unlocked, now: context.date))
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                        ProgressLine(value: app.progress, delay: Double(index) * 0.06)
                    }

                    Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(unlocked || app.isOver ? Theme.ink : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 20)
                }
                .padding(.vertical, 6)
            }
        }
        .buttonStyle(.pressable)
        .foregroundStyle(Theme.ink)
    }

    private func caption(unlocked: Bool, now: Date) -> String {
        if unlocked, let until = app.unlockedUntil {
            let s = max(0, Int(until.timeIntervalSince(now)))
            return String(format: "open · %d:%02d", s / 60, s % 60)
        }
        return app.isOver ? "limit reached" : "\(app.usedMinutes) of \(app.dailyMinutes) min"
    }
}
