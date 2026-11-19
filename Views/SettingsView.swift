import SwiftUI

/// Your account, inviting friends, and the few settings most people never touch.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var editingName = false
    @State private var changingPassword = false
    @State private var confirmingLogOut = false
    @State private var confirmingDelete = false

    var body: some View {
        @Bindable var model = model
        let keyholders = model.myKeyholders

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Settings").font(.title.weight(.bold))
                    Spacer()
                    CircleIconButton(symbol: "xmark") { dismiss() }
                }
                .padding(.bottom, 8)

                if let account = model.account {
                    accountCard(account)

                    SectionLabel(text: "Invite friends").padding(.top, 14)
                    InviteCard(account: account)

                    SectionLabel(text: "Account").padding(.top, 14)
                    VStack(spacing: 0) {
                        SettingsRow(symbol: "pencil", title: "Edit name") { editingName = true }
                        Divider().padding(.leading, 52)
                        SettingsRow(symbol: "lock.rotation", title: "Change password") { changingPassword = true }
                        Divider().padding(.leading, 52)
                        SettingsRow(symbol: "rectangle.portrait.and.arrow.right", title: "Log out") {
                            confirmingLogOut = true
                        }
                        Divider().padding(.leading, 52)
                        SettingsRow(symbol: "trash", title: "Delete account", destructive: true) {
                            confirmingDelete = true
                        }
                    }
                    .background(Theme.fill.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                SectionLabel(text: "When you ask for more time").padding(.top, 14)
                if keyholders.count >= 2 {
                    Text("\(names(keyholders)) \(keyholders.count == 2 ? "both" : "all") hold your key. Choose how their answers count.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    RulePicker(rule: $model.approvalRule)
                } else {
                    Text(keyholders.isEmpty
                         ? "Nobody holds your key yet. Once two or more people do, you can choose how their answers count here."
                         : "Only \(keyholders[0].firstName) holds your key, so \(keyholders[0].firstName) decides. Once two or more people hold it, you can choose how their answers count here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.fill.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $editingName) {
            EditNameSheet(current: model.account?.name ?? "")
                .environment(model)
                .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $changingPassword) {
            ChangePasswordSheet()
                .environment(model)
                .presentationDetents([.height(420)])
        }
        .confirmationDialog("Log out of Gloop?", isPresented: $confirmingLogOut, titleVisibility: .visible) {
            Button("Log out", role: .destructive) {
                dismiss()
                model.logOut()
            }
        } message: {
            Text("You can log back in any time with your email and password.")
        }
        .confirmationDialog("Delete your account?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                dismiss()
                model.deleteAccount()
            }
        } message: {
            Text("This removes your account from this phone and can't be undone.")
        }
    }

    private func accountCard(_ account: Account) -> some View {
        HStack(spacing: 14) {
            Avatar(person: model.me, size: 60)
            VStack(alignment: .leading, spacing: 3) {
                Text(account.name).font(.title3.weight(.bold))
                Text(account.email).font(.subheadline).foregroundStyle(.secondary)
                Text("Member since \(account.createdAt.formatted(.dateTime.month(.wide).year()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.lime.opacity(0.45), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func names(_ people: [Person]) -> String {
        let n = people.map(\.firstName)
        return n.count <= 2 ? n.joined(separator: " and ")
                            : n.dropLast().joined(separator: ", ") + " and " + n.last!
    }
}

/// Your friend code and join link, with one-tap share and copy.
struct InviteCard: View {
    let account: Account
    /// Settings shows your friend code; the Crew page keeps it simpler.
    var showsCode = true
    @State private var copied = false

    private var message: String {
        "Join me on Gloop! We keep each other off our phones (and slime each other when we don't). \(account.joinLink.absoluteString)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                GooDollop(drip: 0.7).frame(width: 40, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bring your crew").font(.body.weight(.bold))
                    Text("Friends who join with your link are added to your crew.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                if showsCode {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your friend code").font(.caption).foregroundStyle(.secondary)
                        Text(account.referralCode)
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                    }
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = account.joinLink.absoluteString
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.8))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy link", systemImage: copied ? "checkmark" : "link")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.onColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.lime, in: Capsule())
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.pressable)
                .sensoryFeedback(.success, trigger: copied) { _, new in new }
            }
            ShareLink(item: account.joinLink, message: Text(message)) {
                Label("Send a join link", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(Theme.onColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.accent, in: Capsule())
            }
            .buttonStyle(.pressable)
        }
        .padding(16)
        .background(Theme.fill.opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(Motion.snappy, value: copied)
    }
}

private struct SettingsRow: View {
    let symbol: String
    let title: String
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(destructive ? Color.red : Theme.onColor)
                    .frame(width: 22)
                Text(title)
                    .foregroundStyle(destructive ? Color.red : Theme.ink)
                Spacer()
                if !destructive {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct EditNameSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var current: String
    @State private var error: String?
    @State private var shakes = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit name").font(.title2.weight(.bold))
            AuthField(symbol: "person.fill", placeholder: "Your name", text: $current)
                .textContentType(.name)
            ErrorLine(text: error, shakes: shakes)
            Spacer()
            PrimaryButton(title: "Save", enabled: !current.trimmingCharacters(in: .whitespaces).isEmpty) {
                do {
                    try model.updateName(current)
                    dismiss()
                } catch {
                    self.error = error.localizedDescription
                    withAnimation(.linear(duration: 0.4)) { shakes += 1 }
                }
            }
        }
        .padding(24)
    }
}

private struct ChangePasswordSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var new = ""
    @State private var error: String?
    @State private var shakes = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Change password").font(.title2.weight(.bold))
            AuthField(symbol: "lock.fill", placeholder: "Current password", text: $current, secure: true)
                .textContentType(.password)
            AuthField(symbol: "lock.rotation", placeholder: "New password (8+ characters)", text: $new, secure: true)
                .textContentType(.newPassword)
            ErrorLine(text: error, shakes: shakes)
            Spacer()
            PrimaryButton(title: "Change password", enabled: !current.isEmpty && !new.isEmpty) {
                do {
                    try model.changePassword(current: current, new: new)
                    dismiss()
                } catch {
                    self.error = error.localizedDescription
                    withAnimation(.linear(duration: 0.4)) { shakes += 1 }
                }
            }
        }
        .padding(24)
    }
}
