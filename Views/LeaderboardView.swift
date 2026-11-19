import SwiftUI

struct LeaderboardView: View {
    @Environment(AppModel.self) private var model
    @State private var metric: Metric = .streak

    enum Metric: String, CaseIterable, Identifiable {
        case streak = "Streak"
        case improvement = "Cutting back"
        var id: Self { self }

        func value(_ s: Stats) -> Int { self == .streak ? s.streak : s.improvement }
        func label(_ s: Stats) -> String { self == .streak ? "\(s.streak) days" : "\(s.improvement)% less" }
        func short(_ s: Stats) -> String { self == .streak ? "\(s.streak)d" : "\(s.improvement)%" }
        var unit: String { self == .streak ? "days" : "%" }
    }

    var body: some View {
        let ranked = model.board.sorted { metric.value($0.stats) > metric.value($1.stats) }
        let top = max(1, ranked.map { metric.value($0.stats) }.max() ?? 1)
        let podium = Array(ranked.prefix(3))
        let rest = Array(ranked.dropFirst(3))

        ScrollView {
            VStack(spacing: 18) {
                ScreenHeader(title: "This week", subtitle: tagline(ranked)).appear(0)
                MetricPicker(metric: $metric).appear(1)

                Podium(entries: podium, metric: metric)
                    .id(metric) // re-run the bounce-in when the metric changes
                    .appear(2)

                if !rest.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(Array(rest.enumerated()), id: \.element.id) { i, e in
                            BoardRow(rank: i + 4, entry: e,
                                     fraction: Double(metric.value(e.stats)) / Double(top),
                                     label: metric.label(e.stats), index: i)
                                .appear(3 + i)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .animation(Motion.smooth, value: metric)
        }
        .scrollIndicators(.hidden)
    }

    /// A little line about where you stand.
    private func tagline(_ ranked: [BoardEntry]) -> String {
        guard let i = ranked.firstIndex(where: \.isMe) else { return "Who's crushing it" }
        if i == 0 { return "You're the top blob" }
        let ahead = ranked[i - 1]
        let gap = metric.value(ahead.stats) - metric.value(ranked[i].stats)
        if gap <= 0 { return "Neck and neck with \(ahead.person.firstName)" }
        let amount = metric == .streak ? "\(gap) \(gap == 1 ? "day" : "days")" : "\(gap)%"
        return "\(amount) behind \(ahead.person.firstName)"
    }
}

// MARK: - Podium

/// The top three as jelly blobs plopped on gooey pedestals: 2nd, 1st, 3rd.
private struct Podium: View {
    let entries: [BoardEntry]
    let metric: LeaderboardView.Metric

    var body: some View {
        // Display order puts the winner in the middle.
        let order = [1, 0, 2].filter { $0 < entries.count }
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(order, id: \.self) { rank in
                PodiumSpot(entry: entries[rank], rank: rank + 1,
                           value: metric.short(entries[rank].stats))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }
}

private struct PodiumSpot: View {
    let entry: BoardEntry
    let rank: Int
    let value: String

    @State private var landed = false
    @State private var jiggles = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var height: CGFloat { [118, 88, 66][rank - 1] }
    private var blob: CGFloat { rank == 1 ? 74 : 60 }
    private var colors: [Color] {
        [[Theme.lime, Theme.sprout], [Theme.sprout, Theme.moss], [Theme.moss, Theme.slime]][rank - 1]
    }
    /// The goo cap dripping over the top, a shade deeper than the block.
    private var goo: Color { [Theme.moss, Theme.slime, Theme.sea][rank - 1] }
    /// The winner drops last, so you watch it land.
    private var dropDelay: Double { [0.55, 0.3, 0.15][rank - 1] }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                jiggles += 1
            } label: {
                VStack(spacing: 4) {
                    if rank == 1 {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.sprout.gradient)
                            .shadow(color: Theme.slime.opacity(0.5), radius: 4, y: 1)
                            .rotationEffect(.degrees(landed ? -8 : 20))
                            .offset(y: landed ? 0 : -20)
                            .opacity(landed ? 1 : 0)
                            .animation(Motion.bouncy.delay(dropDelay + 0.25), value: landed)
                    }
                    Avatar(person: entry.person, size: blob)
                        .keyframeAnimator(initialValue: Squish(), trigger: jiggles) { view, s in
                            view.scaleEffect(x: s.x, y: s.y, anchor: .bottom)
                        } keyframes: { _ in
                            KeyframeTrack(\.x) {
                                SpringKeyframe(1.25, duration: 0.12)
                                SpringKeyframe(0.88, duration: 0.14)
                                SpringKeyframe(1.06, duration: 0.14)
                                SpringKeyframe(1, duration: 0.3)
                            }
                            KeyframeTrack(\.y) {
                                SpringKeyframe(0.75, duration: 0.12)
                                SpringKeyframe(1.15, duration: 0.14)
                                SpringKeyframe(0.95, duration: 0.14)
                                SpringKeyframe(1, duration: 0.3)
                            }
                        }
                        .overlay { ConfettiBurst(trigger: jiggles, spread: 0.35, count: 10) }
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: jiggles)
            // Drops from above and squashes onto the pedestal.
            .offset(y: landed || reduceMotion ? 0 : -140)
            .opacity(landed || reduceMotion ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.55).delay(dropDelay), value: landed)
            .zIndex(1)

            Text(entry.isMe ? "You" : entry.person.firstName)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .padding(.top, 6)
                .padding(.bottom, 6)

            Pedestal(rank: rank, value: value, colors: colors, goo: goo)
                .frame(height: height)
        }
        .frame(maxWidth: .infinity)
        .onAppear { landed = true }
        .onChange(of: landed) { _, now in
            // A little squash when it lands.
            if now && !reduceMotion {
                Task {
                    try? await Task.sleep(for: .seconds(dropDelay + 0.32))
                    jiggles += 1
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rank == 1 ? "First" : rank == 2 ? "Second" : "Third"), \(entry.isMe ? "you" : entry.person.firstName), \(value)")
    }

    private struct Squish { var x: CGFloat = 1; var y: CGFloat = 1 }
}

/// A block of jelly with drips running down from the top edge.
private struct Pedestal: View {
    let rank: Int
    let value: String
    let colors: [Color]
    let goo: Color
    @State private var dripped = false

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 8,
                                           bottomTrailingRadius: 8, topTrailingRadius: 20,
                                           style: .continuous)
        ZStack(alignment: .top) {
            shape.fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))

            // A goo cap on the rim, with drips slowly stretching down.
            GeometryReader { g in
                goo.frame(height: 12)
                ForEach(0..<3, id: \.self) { i in
                    let x = g.size.width * [0.2, 0.55, 0.82][i]
                    let len = [22.0, 34.0, 16.0][(i + rank) % 3]
                    Capsule()
                        .fill(goo)
                        .frame(width: [9.0, 12.0, 8.0][i], height: dripped ? len : 12)
                        .overlay(alignment: .bottom) {
                            Circle().fill(goo)
                                .frame(width: [13.0, 16.0, 11.0][i])
                                .offset(y: 3)
                        }
                        .position(x: x, y: (dripped ? len : 12) / 2)
                        .animation(.easeInOut(duration: 1.6 + Double(i) * 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.3), value: dripped)
                }
            }
            .clipShape(shape)

            // Shine.
            Capsule()
                .fill(.white.opacity(0.45))
                .frame(width: 26, height: 6)
                .rotationEffect(.degrees(-8))
                .offset(x: -18, y: 5)

            VStack(spacing: 0) {
                Text("\(rank)")
                    .font(.system(size: rank == 1 ? 40 : 32, weight: .heavy, design: .rounded))
                Text(value)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .opacity(0.75)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(Theme.onColor)
            .padding(.top, rank == 1 ? 30 : 22)
        }
        .onAppear { dripped = true }
    }
}

// MARK: - Picker

private struct MetricPicker: View {
    @Binding var metric: LeaderboardView.Metric
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(LeaderboardView.Metric.allCases) { m in
                Button { metric = m } label: {
                    Text(m.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(metric == m ? Theme.onColor : Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if metric == m {
                                BlobShape(phase: 0.8, wobble: 0.05, lobes: 4)
                                    .fill(Theme.accent.gradient)
                                    .matchedGeometryEffect(id: "metric", in: ns)
                            }
                        }
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(4)
        .background(Theme.fill, in: Capsule())
        .animation(Motion.bouncy, value: metric)
        .sensoryFeedback(.selection, trigger: metric)
    }
}

// MARK: - Everyone else

private struct BoardRow: View {
    let rank: Int
    let entry: BoardEntry
    let fraction: Double
    let label: String
    let index: Int

    @State private var grown = false

    var body: some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 26)
                .contentTransition(.numericText())

            Avatar(person: entry.person, size: 40)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(entry.isMe ? "You" : entry.person.firstName)
                        .font(.body.weight(entry.isMe ? .bold : .medium))
                    Spacer()
                    Text(label)
                        .font(.footnote.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                // A jelly bar that oozes out to its length, with a little shine.
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.fill)
                        Capsule()
                            .fill(entry.person.color.gradient)
                            .overlay(alignment: .topLeading) {
                                Capsule().fill(.white.opacity(0.45))
                                    .frame(width: 14, height: 3)
                                    .offset(x: 5, y: 2)
                            }
                            .frame(width: max(12, g.size.width * (grown ? fraction : 0)))
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background {
            if entry.isMe {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.accentSoft)
            }
        }
        .onAppear {
            withAnimation(Motion.bouncy.delay(0.6 + Double(index) * 0.08)) { grown = true }
        }
    }
}
