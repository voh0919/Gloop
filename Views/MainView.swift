import SwiftUI

enum AppTab: CaseIterable, Identifiable {
    case home, buddies, requests, board
    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Today"
        case .buddies: "Crew"
        case .requests: "Requests"
        case .board: "Board"
        }
    }

    var symbol: String {
        switch self {
        case .home: "circle.circle"
        case .buddies: "person.2"
        case .requests: "tray"
        case .board: "chart.bar"
        }
    }
}

struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .home

    var body: some View {
        @Bindable var model = model

        ZStack {
            switch tab {
            case .home: HomeView(tab: $tab)
            case .buddies: BuddiesView()
            case .requests: RequestsView()
            case .board: LeaderboardView()
            }
        }
        .id(tab)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(y: 10)),
            removal: .opacity
        ))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            TabBar(selection: $tab, badge: model.pendingIncoming.count)
        }
        .topFade()
        .slimeOverlay($model.slimeEvent)
        .overlay(alignment: .top) { Toast(text: model.toast) }
        .background { AmbientGoo().ignoresSafeArea() }
        .animation(Motion.snappy, value: tab)
        .fullCover(item: $model.blockingApp) { app in
            BlockScreenView(app: app)
                .environment(model)
        }
    }
}

struct TabBar: View {
    @Binding var selection: AppTab
    var badge: Int
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { t in
                let selected = selection == t
                Button {
                    withAnimation(Motion.snappy) { selection = t }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: t.symbol)
                            .font(.system(size: 17, weight: selected ? .semibold : .regular))
                            .scaleEffect(selected ? 1.1 : 1)
                            .overlay(alignment: .topTrailing) {
                                if t == .requests && badge > 0 {
                                    Text("\(badge)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .contentTransition(.numericText())
                                        .foregroundStyle(Theme.onColor)
                                        .frame(minWidth: 16, minHeight: 16)
                                        .background(Theme.accent, in: Capsule())
                                        .offset(x: 11, y: -7)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        Text(t.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selected ? Theme.ink : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if selected {
                            // The selection is a little blob of jelly that slides between tabs.
                            BlobShape(phase: 1.3, wobble: 0.07, lobes: 3)
                                .fill(Theme.sprout.opacity(0.7))
                                // Squash and stretch as it lands on a new tab.
                                .keyframeAnimator(initialValue: CGSize(width: 1, height: 1),
                                                  trigger: selection) { content, scale in
                                    content.scaleEffect(x: scale.width, y: scale.height)
                                } keyframes: { _ in
                                    KeyframeTrack(\.width) {
                                        SpringKeyframe(1.18, duration: 0.14)
                                        SpringKeyframe(0.94, duration: 0.16)
                                        SpringKeyframe(1, duration: 0.3)
                                    }
                                    KeyframeTrack(\.height) {
                                        SpringKeyframe(0.82, duration: 0.14)
                                        SpringKeyframe(1.08, duration: 0.16)
                                        SpringKeyframe(1, duration: 0.3)
                                    }
                                }
                                .matchedGeometryEffect(id: "tab", in: ns)
                        }
                    }
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(5)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.line, lineWidth: 0.5))
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
        .animation(Motion.snappy, value: selection)
        .animation(Motion.bouncy, value: badge)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A small pill that drops in from the top and leaves on its own.
struct Toast: View {
    let text: String?

    var body: some View {
        ZStack {
            if let text {
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Theme.abyss, in: Capsule())
                    .id(text)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .scale(scale: 0.8)).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
            }
        }
        .padding(.top, 6)
        .animation(Motion.bouncy, value: text)
        .sensoryFeedback(.impact(weight: .light), trigger: text)
        .allowsHitTesting(false)
    }
}
