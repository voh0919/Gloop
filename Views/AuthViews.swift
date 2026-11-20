import SwiftUI
import AuthenticationServices
import CryptoKit

/// Everything before you're logged in: welcome → (intro slides → sign up) or log in,
/// plus confirming your email and resetting a forgotten password.
struct AuthFlow: View {
    enum Step: Hashable {
        case welcome, intro, signUp, logIn
        case confirm(email: String)
        case forgot(email: String)
    }
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
                SignUpView(onBack: { step = .intro }, onLogIn: { step = .logIn },
                           onConfirm: { step = .confirm(email: $0) })
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .logIn:
                LogInView(onBack: { step = .welcome }, onSignUp: { step = .intro },
                          onForgot: { step = .forgot(email: $0) },
                          onConfirm: { step = .confirm(email: $0) })
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .confirm(let email):
                ConfirmEmailView(email: email, onBack: { step = .logIn })
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .forgot(let email):
                ForgotPasswordView(email: email, onBack: { step = .logIn })
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(Motion.smooth, value: step)
        .background { AmbientGoo().ignoresSafeArea() }
    }
}

/// Busy, error and shake state shared by every sign-in form.
@Observable
final class AuthTask {
    var busy = false
    var error: String?
    var shakes = 0

    /// Runs `work`, showing a spinner and a friendly error if it fails.
    /// Closing the Google or Apple sheet yourself isn't an error.
    @MainActor
    func run(_ work: @escaping () async throws -> Void) {
        guard !busy else { return }
        busy = true
        error = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                try await work()
            } catch is CancellationError {
            } catch let e as ASAuthorizationError where e.code == .canceled {
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    @MainActor
    func fail(_ message: String) {
        error = message
        withAnimation(.linear(duration: 0.4)) { shakes += 1 }
    }
}

// MARK: - Welcome

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
            Text("Your friends and family hold the key to your apps.")
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

// MARK: - Sign up

/// Name, email, password, or one tap with Apple or Google.
private struct SignUpView: View {
    @Environment(AppModel.self) private var model
    let onBack: () -> Void
    let onLogIn: () -> Void
    let onConfirm: (String) -> Void

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var task = AuthTask()
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

                SocialSignIn(task: task)

                OrDivider()

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

                ErrorLine(text: task.error, shakes: task.shakes)

                PrimaryButton(title: "Create account", enabled: filled, busy: task.busy, action: submit)
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
    }

    private func submit() {
        guard filled else { return }
        field = nil
        task.run {
            let signedIn = try await model.createAccount(name: name, email: email, password: password)
            if !signedIn { onConfirm(email) }
        }
    }
}

// MARK: - Log in

/// Email and password for someone who already has an account. No intro slides.
private struct LogInView: View {
    @Environment(AppModel.self) private var model
    let onBack: () -> Void
    let onSignUp: () -> Void
    let onForgot: (String) -> Void
    let onConfirm: (String) -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var task = AuthTask()
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

                SocialSignIn(task: task)

                OrDivider()

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

                HStack {
                    ErrorLine(text: task.error, shakes: task.shakes)
                    Spacer(minLength: 8)
                    if AuthService.usesServer && SupabaseConfig.emailCodes {
                        Button("Forgot password?") { onForgot(email) }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.ocean)
                    }
                }

                PrimaryButton(title: "Log in", enabled: !email.isEmpty && !password.isEmpty,
                              busy: task.busy, action: submit)
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
    }

    private func submit() {
        guard !email.isEmpty, !password.isEmpty else { return }
        field = nil
        task.run {
            do {
                try await model.logIn(email: email, password: password)
            } catch AccountError.notConfirmed {
                // Never confirmed their email: send a fresh code and go enter it.
                try? await AuthService.resendConfirmation(email)
                onConfirm(email)
            }
        }
    }
}

// MARK: - Confirm email

/// Enter the 6-digit code the server emailed after signing up.
private struct ConfirmEmailView: View {
    @Environment(AppModel.self) private var model
    let email: String
    let onBack: () -> Void

    @State private var code = ""
    @State private var task = AuthTask()
    @State private var resent = false
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CircleIconButton(symbol: "chevron.left", action: onBack)
                    .padding(.bottom, 8)
                JellyCritter(color: Theme.sea, size: 64, phaseOffset: 0.8)
                Text("Check your email")
                    .font(.largeTitle.weight(.bold))
                Text("We sent a 6-digit code to \(email).")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)

                CodeField(code: $code)
                    .focused($focused)

                ErrorLine(text: task.error, shakes: task.shakes)

                PrimaryButton(title: "Confirm", enabled: code.count == 6, busy: task.busy) {
                    task.run { try await model.confirmEmail(email, code: code) }
                }
                .padding(.top, 6)

                Button(resent ? "Code sent" : "Send a new code") {
                    task.run {
                        try await AuthService.resendConfirmation(email)
                        resent = true
                    }
                }
                .disabled(resent)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ocean)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
            .padding(24)
        }
        .onAppear { focused = true }
        .onChange(of: code) { _, new in
            if new.count == 6 { task.run { try await model.confirmEmail(email, code: new) } }
        }
    }
}

// MARK: - Forgot password

/// Two steps: email a code, then enter it with a new password.
private struct ForgotPasswordView: View {
    @Environment(AppModel.self) private var model
    @State var email: String
    let onBack: () -> Void

    @State private var sent = false
    @State private var code = ""
    @State private var newPassword = ""
    @State private var task = AuthTask()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CircleIconButton(symbol: "chevron.left", action: onBack)
                    .padding(.bottom, 8)
                JellyCritter(color: Theme.teal, size: 64, phaseOffset: 2.4)
                Text(sent ? "Enter your code" : "Reset password")
                    .font(.largeTitle.weight(.bold))
                    .contentTransition(.opacity)
                Text(sent ? "We emailed a 6-digit code to \(email)." : "We'll email you a code.")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)
                    .contentTransition(.opacity)

                if sent {
                    CodeField(code: $code)
                    AuthField(symbol: "lock.rotation", placeholder: "New password (8+ characters)",
                              text: $newPassword, secure: true)
                        .textContentType(.newPassword)
                } else {
                    AuthField(symbol: "envelope.fill", placeholder: "Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                ErrorLine(text: task.error, shakes: task.shakes)

                if sent {
                    PrimaryButton(title: "Set new password",
                                  enabled: code.count == 6 && !newPassword.isEmpty, busy: task.busy) {
                        task.run { try await model.resetPassword(email: email, code: code, newPassword: newPassword) }
                    }
                    .padding(.top, 6)
                } else {
                    PrimaryButton(title: "Send code", enabled: !email.isEmpty, busy: task.busy) {
                        task.run {
                            try await AuthService.sendPasswordReset(email)
                            withAnimation(Motion.smooth) { sent = true }
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Google and Apple

/// "Continue with Apple" and "Continue with Google".
private struct SocialSignIn: View {
    @Environment(AppModel.self) private var model
    let task: AuthTask
    @State private var nonce = ""

    var body: some View {
        VStack(spacing: 10) {
            SignInWithAppleButton(.continue) { request in
                nonce = Self.randomNonce()
                request.requestedScopes = [.fullName, .email]
                request.nonce = Self.sha256(nonce)
            } onCompletion: { result in
                apple(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .clipShape(Capsule())
            .disabled(task.busy)

            Button(action: google) {
                HStack(spacing: 10) {
                    Text("G")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ocean)
                        .frame(width: 26, height: 26)
                        .background(.white, in: Circle())
                    Text("Continue with Google")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(Theme.ink)
                .background(Theme.fill, in: Capsule())
                .overlay(Capsule().stroke(Theme.line, lineWidth: 0.5))
            }
            .buttonStyle(.pressable)
            .disabled(task.busy)
        }
    }

    private func google() {
        task.run { try await model.signInWithGoogle() }
    }

    private func apple(_ result: Result<ASAuthorization, Error>) {
        task.run {
            guard AuthService.usesServer else { throw AccountError.needsServer }
            switch result {
            case .failure(let error):
                if let e = error as? ASAuthorizationError, e.code == .canceled { throw CancellationError() }
                // Without the Sign in with Apple capability, Apple refuses before showing anything.
                throw AccountError.appleNotSetUp
            case .success(let auth):
                guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                      let tokenData = credential.identityToken,
                      let idToken = String(data: tokenData, encoding: .utf8) else {
                    throw AccountError.appleNotSetUp
                }
                let name = credential.fullName.map {
                    PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
                }
                try await model.signInWithApple(idToken: idToken, nonce: nonce, name: name)
            }
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in chars.randomElement(using: &generator)! })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Pieces

/// A thin line with "or" in the middle.
private struct OrDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.line).frame(height: 0.5)
            Text("or").font(.footnote).foregroundStyle(.secondary)
            Rectangle().fill(Theme.line).frame(height: 0.5)
        }
        .padding(.vertical, 4)
    }
}

/// A 6-digit code entry that fills from the email automatically when iOS offers it.
private struct CodeField: View {
    @Binding var code: String

    var body: some View {
        AuthField(symbol: "number", placeholder: "6-digit code", text: $code)
            .textContentType(.oneTimeCode)
            .keyboardType(.numberPad)
            .onChange(of: code) { _, new in
                let digits = String(new.filter(\.isNumber).prefix(6))
                if digits != new { code = digits }
            }
    }
}

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
                .fixedSize(horizontal: false, vertical: true)
                .modifier(Shake(amount: 6, animatableData: CGFloat(shakes)))
                .transition(.opacity)
        }
    }
}
