import SwiftUI

/// Choose exactly which apps are limited, from every app on the phone grouped
/// into categories, and set a daily limit for each. Nothing changes until Save.
struct EditAppsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// An app you've picked, with its daily limit.
    struct Pick: Identifiable, Equatable {
        let name: String
        let symbol: String
        var minutes: Int
        var id: String { name }
    }

    @State private var picks: [Pick] = []
    @State private var expanded: Set<String> = []
    @State private var search = ""
    @State private var loaded = false

    private var total: Int { picks.reduce(0) { $0 + $1.minutes } }
    private func isPicked(_ name: String) -> Bool { picks.contains { $0.name == name } }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SearchField(text: $search)

                    if search.isEmpty {
                        if !picks.isEmpty {
                            SectionLabel(text: "Limited (\(picks.count))").padding(.top, 6)
                            ForEach($picks) { $pick in
                                PickedRow(pick: $pick) { toggle(pick.name, pick.symbol) }
                                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity),
                                                            removal: .opacity))
                            }
                        }
                        SectionLabel(text: "All apps").padding(.top, 14)
                        ForEach(AppModel.categories) { category in
                            CategoryCard(category: category,
                                         isOpen: expanded.contains(category.id),
                                         pickedCount: category.apps.filter { isPicked($0.name) }.count,
                                         isPicked: isPicked,
                                         onToggleOpen: { toggleOpen(category.id) },
                                         onToggleApp: { toggle($0, $1) },
                                         onAll: { pickAll(category) })
                        }
                    } else {
                        searchResults
                    }

                    Text("On a real iPhone, this list shows the apps actually installed, using Apple's Screen Time app picker.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .animation(Motion.smooth, value: picks)
                .animation(Motion.smooth, value: expanded)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            PrimaryButton(title: picks.isEmpty ? "Save with no limits" : "Save \(picks.count) limits") {
                model.saveApps(picks.map { ($0.name, $0.symbol, $0.minutes) })
                dismiss()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .onAppear(perform: load)
        .sensoryFeedback(.selection, trigger: picks.count)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Limited apps").font(.title.weight(.bold))
                Text(picks.isEmpty ? "Nothing limited yet" : "Daily total: \(Self.format(total))")
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(Motion.snappy, value: total)
            }
            Spacer()
            CircleIconButton(symbol: "xmark") { dismiss() }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var searchResults: some View {
        let q = search.lowercased()
        let hits = AppModel.categories.flatMap { c in
            c.apps.filter { $0.name.lowercased().contains(q) }.map { (app: $0, category: c.name) }
        }
        if hits.isEmpty {
            Text("No apps match \u{201C}\(search)\u{201D}")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
        }
        ForEach(hits, id: \.app.name) { hit in
            AppPickRow(name: hit.app.name, symbol: hit.app.symbol, caption: hit.category,
                       picked: isPicked(hit.app.name)) { toggle(hit.app.name, hit.app.symbol) }
                .padding(.horizontal, 14)
                .background(Theme.fill.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: Actions

    private func load() {
        guard !loaded else { return }
        loaded = true
        picks = model.apps.map { Pick(name: $0.name, symbol: $0.symbol, minutes: $0.dailyMinutes) }
        // Open the categories that already have limited apps.
        expanded = Set(AppModel.categories.filter { c in c.apps.contains { isPicked($0.name) } }.map(\.id))
    }

    private func toggle(_ name: String, _ symbol: String) {
        if let i = picks.firstIndex(where: { $0.name == name }) {
            picks.remove(at: i)
        } else {
            picks.append(Pick(name: name, symbol: symbol, minutes: 30))
        }
    }

    private func toggleOpen(_ id: String) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }

    /// Picks every app in a category, or clears them all if they're all picked already.
    private func pickAll(_ category: AppCategory) {
        let allPicked = category.apps.allSatisfy { isPicked($0.name) }
        if allPicked {
            picks.removeAll { p in category.apps.contains { $0.name == p.name } }
        } else {
            for app in category.apps where !isPicked(app.name) {
                picks.append(Pick(name: app.name, symbol: app.symbol, minutes: 30))
            }
        }
    }

    static func format(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }
}

// MARK: - Pieces

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search apps", text: $text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.fill, in: Capsule())
    }
}

/// A category that opens like a drawer to show its apps.
private struct CategoryCard: View {
    let category: AppCategory
    let isOpen: Bool
    let pickedCount: Int
    let isPicked: (String) -> Bool
    let onToggleOpen: () -> Void
    let onToggleApp: (String, String) -> Void
    let onAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggleOpen) {
                HStack(spacing: 12) {
                    Image(systemName: category.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.onColor)
                        .frame(width: 38, height: 38)
                        .background(pickedCount > 0 ? Theme.sprout : Theme.fill,
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name).font(.body.weight(.semibold))
                        Text(pickedCount == 0 ? "\(category.apps.count) apps"
                                              : "\(pickedCount) of \(category.apps.count) limited")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.ink)

            if isOpen {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(pickedCount == category.apps.count ? "Clear all" : "Limit all") { onAll() }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.ocean)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
                    ForEach(category.apps, id: \.name) { app in
                        AppPickRow(name: app.name, symbol: app.symbol, caption: nil,
                                   picked: isPicked(app.name)) { onToggleApp(app.name, app.symbol) }
                            .padding(.horizontal, 14)
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.fill.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(Motion.smooth, value: isOpen)
    }
}

/// One app with a check circle. Tap anywhere on the row to pick it.
private struct AppPickRow: View {
    let name: String
    let symbol: String
    let caption: String?
    let picked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.onColor)
                    .frame(width: 32, height: 32)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.subheadline.weight(.medium))
                    if let caption {
                        Text(caption).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Checkmark(on: picked)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
    }
}

/// A picked app with its daily limit, adjustable with − and +.
private struct PickedRow: View {
    @Binding var pick: EditAppsView.Pick
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: pick.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.onColor)
                .frame(width: 38, height: 38)
                .background(Theme.sprout, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(pick.name).font(.subheadline.weight(.semibold))
                Button("Remove", action: onRemove)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StepButton(symbol: "minus", enabled: pick.minutes > 5) {
                pick.minutes = max(5, pick.minutes - (pick.minutes > 60 ? 15 : 5))
            }
            Text(EditAppsView.format(pick.minutes))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(minWidth: 70)
            StepButton(symbol: "plus", enabled: pick.minutes < 240) {
                pick.minutes = min(240, pick.minutes + (pick.minutes >= 60 ? 15 : 5))
            }
        }
        .padding(12)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(Motion.snappy, value: pick.minutes)
        .sensoryFeedback(.selection, trigger: pick.minutes)
    }
}

private struct StepButton: View {
    let symbol: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.onColor)
                .frame(width: 32, height: 32)
                .background(Theme.bg, in: Circle())
                .overlay(Circle().stroke(Theme.onColor.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}
