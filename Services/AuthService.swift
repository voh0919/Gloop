import Foundation
import Supabase

/// Everything about signing in, in one place.
///
/// With Supabase configured (see `SupabaseConfig`), accounts live on the server:
/// email and password, Google, and Sign in with Apple. Without it, Gloop falls
/// back to the on-phone `AccountStore`, so the prototype still runs.
enum AuthService {
    enum SignUpResult {
        case signedIn(Account)
        /// The server emailed a 6-digit code to confirm the address.
        case confirmEmail
    }

    private static var client: SupabaseClient? { SupabaseConfig.client }
    static var usesServer: Bool { client != nil }

    // MARK: Restore

    /// The account to show at launch, without waiting on the network.
    static var restoredAccount: Account? {
        guard let client else { return AccountStore.isLoggedIn ? AccountStore.account : nil }
        return client.auth.currentSession != nil ? AccountStore.cachedRemote : nil
    }

    /// Refreshes the cached account from the server. Nil means the session is gone.
    static func refresh() async -> Account? {
        guard let client else { return restoredAccount }
        guard let session = try? await client.auth.session else {
            AccountStore.cachedRemote = nil
            return nil
        }
        return try? await account(for: session.user)
    }

    // MARK: Email and password

    static func signUp(name: String, email: String, password: String) async throws -> SignUpResult {
        guard let client else {
            return .signedIn(try AccountStore.createAccount(name: name, email: email, password: password))
        }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !name.isEmpty else { throw AccountError.invalidName }
        guard AccountStore.isValidEmail(email) else { throw AccountError.invalidEmail }
        guard password.count >= 8 else { throw AccountError.weakPassword }

        let response = try await call {
            try await client.auth.signUp(email: email, password: password, data: ["name": .string(name)])
        }
        guard let session = response.session else { return .confirmEmail }
        return .signedIn(try await account(for: session.user))
    }

    static func confirmEmail(_ email: String, code: String) async throws -> Account {
        guard let client else { throw AccountError.needsServer }
        let response = try await call(code: true) {
            try await client.auth.verifyOTP(email: normalize(email), token: trimmed(code), type: .signup)
        }
        guard let session = response.session else { throw AccountError.wrongCode }
        return try await account(for: session.user)
    }

    static func resendConfirmation(_ email: String) async throws {
        guard let client else { throw AccountError.needsServer }
        try await call { try await client.auth.resend(email: normalize(email), type: .signup) }
    }

    static func logIn(email: String, password: String) async throws -> Account {
        guard let client else { return try AccountStore.logIn(email: email, password: password) }
        let session = try await call {
            try await client.auth.signIn(email: normalize(email), password: password)
        }
        return try await account(for: session.user)
    }

    // MARK: Forgot password

    /// Emails a 6-digit code for resetting the password.
    static func sendPasswordReset(_ email: String) async throws {
        guard let client else { throw AccountError.needsServer }
        guard AccountStore.isValidEmail(normalize(email)) else { throw AccountError.invalidEmail }
        try await call { try await client.auth.resetPasswordForEmail(normalize(email)) }
    }

    /// Checks the code, sets the new password, and signs you in.
    static func resetPassword(email: String, code: String, newPassword: String) async throws -> Account {
        guard let client else { throw AccountError.needsServer }
        guard newPassword.count >= 8 else { throw AccountError.weakPassword }
        let response = try await call(code: true) {
            try await client.auth.verifyOTP(email: normalize(email), token: trimmed(code), type: .recovery)
        }
        guard response.session != nil else { throw AccountError.wrongCode }
        let user = try await call { try await client.auth.update(user: UserAttributes(password: newPassword)) }
        return try await account(for: user)
    }

    // MARK: Google and Apple

    static func signInWithGoogle() async throws -> Account {
        guard let client else { throw AccountError.needsServer }
        let session = try await call {
            try await client.auth.signInWithOAuth(provider: .google, redirectTo: SupabaseConfig.redirectURL)
        }
        return try await account(for: session.user)
    }

    /// Finishes Sign in with Apple. Apple only shares the name the first time,
    /// so it's saved to the profile right away.
    static func signInWithApple(idToken: String, nonce: String, name: String?) async throws -> Account {
        guard let client else { throw AccountError.needsServer }
        let session = try await call {
            try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
        }
        if let name, !name.isEmpty {
            _ = try? await client.auth.update(user: UserAttributes(data: ["name": .string(name)]))
            try? await client.from("profiles").update(["name": name]).eq("id", value: session.user.id).execute()
        }
        return try await account(for: session.user)
    }

    // MARK: Account changes

    static func updateName(_ name: String) async throws -> Account {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw AccountError.invalidName }
        guard let client else { return try AccountStore.updateName(name) }
        let user = try await call { try await client.auth.update(user: UserAttributes(data: ["name": .string(name)])) }
        try await call { try await client.from("profiles").update(["name": name]).eq("id", value: user.id).execute() }
        return try await account(for: user)
    }

    static func changePassword(email: String, current: String, new: String) async throws {
        guard let client else { return try AccountStore.changePassword(current: current, new: new) }
        guard new.count >= 8 else { throw AccountError.weakPassword }
        // Prove it's really you before changing it.
        _ = try await call { try await client.auth.signIn(email: normalize(email), password: current) }
        _ = try await call { try await client.auth.update(user: UserAttributes(password: new)) }
    }

    static func logOut() async {
        guard let client else { return AccountStore.logOut() }
        try? await client.auth.signOut()
        AccountStore.cachedRemote = nil
    }

    static func deleteAccount() async throws {
        guard let client else { return AccountStore.deleteAccount() }
        // A database function (see supabase/setup.sql) deletes your own user.
        try await call { try await client.rpc("delete_my_account").execute() }
        try? await client.auth.signOut()
        AccountStore.cachedRemote = nil
    }

    // MARK: Helpers

    private struct Profile: Decodable {
        let name: String
        let referral_code: String
        let created_at: Date
    }

    /// Builds the app's Account from the server user and their profile row.
    private static func account(for user: User) async throws -> Account {
        guard let client else { throw AccountError.needsServer }
        let profile: Profile? = try? await client.from("profiles")
            .select("name, referral_code, created_at")
            .eq("id", value: user.id)
            .single()
            .execute()
            .value
        let metaName = user.userMetadata["name"]?.stringValue
            ?? user.userMetadata["full_name"]?.stringValue
        let name = profile?.name ?? metaName ?? "Gloop friend"
        let provider = user.appMetadata["provider"]?.stringValue ?? "email"
        let account = Account(name: name,
                              email: user.email ?? "",
                              createdAt: profile?.created_at ?? user.createdAt,
                              referralCode: profile?.referral_code ?? AccountStore.makeReferralCode(for: name),
                              provider: provider)
        AccountStore.cachedRemote = account
        return account
    }

    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func trimmed(_ code: String) -> String {
        code.filter(\.isNumber)
    }

    /// Runs a server call and turns its errors into short, friendly ones.
    @discardableResult
    private static func call<T>(code: Bool = false, _ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch let error as AccountError {
            throw error
        } catch let error as URLError {
            throw error.code == .notConnectedToInternet || error.code == .networkConnectionLost
                ? AccountError.offline : AccountError.server(error.localizedDescription)
        } catch {
            if (error as NSError).domain == "com.apple.AuthenticationServices.WebAuthenticationSession",
               (error as NSError).code == 1 {
                throw CancellationError() // closed the Google window
            }
            throw friendly(error, code: code)
        }
    }

    private static func friendly(_ error: Error, code: Bool) -> AccountError {
        let message = "\(error)".lowercased()
        if code && (message.contains("otp") || message.contains("token") || message.contains("expired")) {
            return .wrongCode
        }
        if message.contains("invalid login credentials") || message.contains("invalid_credentials") {
            return .wrongPassword
        }
        if message.contains("already registered") || message.contains("user_already_exists") {
            return .emailTaken
        }
        if message.contains("email not confirmed") || message.contains("email_not_confirmed") {
            return .notConfirmed
        }
        if message.contains("weak") || message.contains("password should be") {
            return .weakPassword
        }
        return .server((error as? LocalizedError)?.errorDescription ?? "Something went wrong. Try again.")
    }
}
