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
    }

    var body: some View {
        let ranked = model.board.sorted { metric.value($0.stats) > metric.value($1.stats) }
        let top = max(1, ranked.map { metric.value($0.stats) }.max() ?? 1)

        ScrollView {
            VStack(spacing: 18) {
                ScreenHeader(title: "This week", subtitle: "Who's crushing it").appear(0)
                MetricPicker(metric: $metric).appear(1)

                VStack(spacing: 6) {
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { i, e in
                        BoardRow(rank: i + 1, entry: e,
                                 fraction: Double(metric.value(e.stats)) / Double(top),
                                 label: metric.label(e.stats), index: i)
                            .appear(2 + i)
                    }
                }

            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .animation(Motion.smooth, value: metric)
        }
        .scrollIndicators(.hidden)
    }
}

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
                                Capsule().fill(Theme.accent).matchedGeometryEffect(id: "metric", in: ns)
                            }
                        }
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(4)
        .background(Theme.fill, in: Capsule())
        .animation(Motion.snappy, value: metric)
        .sensoryFeedback(.selection, trigger: metric)
    }
}

private struct BoardRow: View {
    let rank: Int
    let entry: BoardEntry
    let fraction: Double
    let label: String
    let index: Int

    @State private var grown = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if rank <= 3 {
                    // Top three get a little pastel badge instead of a plain number.
                    Text("\(rank)")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(Theme.onColor)
                        .frame(width: 28, height: 28)
                        .background([Theme.lime, Theme.sprout, Theme.moss][rank - 1], in: Circle())
                        .overlay(Circle().stroke(Theme.onColor.opacity(0.12), lineWidth: 1))
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                } else {
                    Text("\(rank)")
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .id(rank)
            .frame(width: 30)
            .animation(Motion.bouncy, value: rank)

            Avatar(person: entry.person, size: 40)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(entry.isMe ? "You" : entry.person.firstName)
                        .font(.body.weight(entry.isMe ? .bold : .medium))
                    Spacer()
                    Text(label)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.fill)
                        Capsule().fill(entry.person.color.gradient)
                            .frame(width: max(6, g.size.width * (grown ? fraction : 0)))
                    }
                }
                .frame(height: 6)
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
            withAnimation(Motion.smooth.delay(0.25 + Double(index) * 0.07)) { grown = true }
        }
    }
}
