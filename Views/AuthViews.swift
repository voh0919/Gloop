import SwiftUI

/// Everything before you're logged in: welcome → (intro slides → sign up) or log in.
struct AuthFlow: View {
    enum Step: Hashable { case welcome, intro, signUp, logIn }
    @State private var step: Step = .welcome

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeView(onSignUp: { step = .intro }, onLogIn: { step = .logIn })
                    .transition(.opacity)
            case .intro:
                OnboardingView(onFinish: { step = .signUp })
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .signUp:
                SignUpView(onBack: { step = .intro }, onLogIn: { step = .logIn })
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .logIn:
                LogInView(onBack: { step = .welcome }, onSignUp: { step = .intro })
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(Motion.smooth, value: step)
        .background { AmbientGoo().ignoresSafeArea() }
    }
}

/// The first thing a logged-out person sees.
private struct WelcomeView: View {
    let onSignUp: () -> Void
    let onLogIn: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            JellyCritter(color: Theme.slime, size: 130)
                .appear(0)
            Text("Gloop")
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .padding(.top, 18)
                .appear(1)
            Text("Your friends hold the key to your apps.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .appear(2)
            Spacer()
            VStack(spacing: 12) {
                PrimaryButton(title: "Create account", action: onSignUp)
                SecondaryButton(title: "I already have an account", action: onLogIn)
            }
            .appear(3)
        }
        .padding(24)
    }
}

/// Name, email, password. Creating the account logs you straight in.
private struct SignUpView: View {
    @Environment(AppModel.self) private var model
    let onBack: () -> Void
    let onLogIn: () -> Void

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var shakes = 0
    @FocusState private var field: Field?
    enum Field { case name, email, password }

    private var filled: Bool { !name.isEmpty && !email.isEmpty && !password.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CircleIconButton(symbol: "chevron.left", action: onBack)
                    .padding(.bottom, 8)
                JellyCritter(color: Theme.slime, size: 64)
                Text("Create your account")
                    .font(.largeTitle.weight(.bold))
                Text("This is how your crew will see you.")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)

                AuthField(symbol: "person.fill", placeholder: "Your name", text: $name)
                    .textContentType(.name)
                    .focused($field, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { field = .email }
                AuthField(symbol: "envelope.fill", placeholder: "Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($field, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { field = .password }
                AuthField(symbol: "lock.fill", placeholder: "Password (8+ characters)", text: $password, secure: true)
                    .textContentType(.newPassword)
                    .focused($field, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)

                ErrorLine(text: error, shakes: shakes)

                PrimaryButton(title: "Create account", enabled: filled, action: submit)
                    .padding(.top, 6)

                Button("Already have an account? Log in", action: onLogIn)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ocean)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { field = .name }
    }

    private func submit() {
        do {
            try model.createAccount(name: name, email: email, password: password)
        } catch {
            self.error = error.localizedDescription
            withAnimation(.linear(duration: 0.4)) { shakes += 1 }
        }
    }
}

/// Email and password for someone who already has an account. No intro slides.
private struct LogInView: View {
    @Environment(AppModel.self) private var model
    let onBack: () -> Void
    let onSignUp: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var shakes = 0
    @FocusState private var field: Field?
    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CircleIconButton(symbol: "chevron.left", action: onBack)
                    .padding(.bottom, 8)
                JellyCritter(color: Theme.lagoon, size: 64, phaseOffset: 1.7)
                Text("Welcome back")
                    .font(.largeTitle.weight(.bold))
                Text("Your crew missed you.")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)

                AuthField(symbol: "envelope.fill", placeholder: "Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($field, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { field = .password }
                AuthField(symbol: "lock.fill", placeholder: "Password", text: $password, secure: true)
                    .textContentType(.password)
                    .focused($field, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)

                ErrorLine(text: error, shakes: shakes)

                PrimaryButton(title: "Log in", enabled: !email.isEmpty && !password.isEmpty, action: submit)
                    .padding(.top, 6)

                Button("New to Gloop? Create an account", action: onSignUp)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ocean)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { field = .email }
    }

    private func submit() {
        do {
            try model.logIn(email: email, password: password)
        } catch {
            self.error = error.localizedDescription
            withAnimation(.linear(duration: 0.4)) { shakes += 1 }
        }
    }
}

// MARK: - Pieces

/// A rounded text field with a leading icon. Secure fields get a show/hide eye.
struct AuthField: View {
    let symbol: String
    let placeholder: String
    @Binding var text: String
    var secure = false
    @State private var revealed = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.sea)
                .frame(width: 20)
            Group {
                if secure && !revealed {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.body)
            if secure {
                Button { revealed.toggle() } label: {
                    Image(systemName: revealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(revealed ? "Hide password" : "Show password")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Theme.fill, in: Capsule())
    }
}

/// A short error under the form that shakes when it appears.
struct ErrorLine: View {
    let text: String?
    let shakes: Int

    var body: some View {
        if let text {
            Label(text, systemImage: "exclamationmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.deep)
                .modifier(Shake(amount: 6, animatableData: CGFloat(shakes)))
                .transition(.opacity)
        }
    }
}
