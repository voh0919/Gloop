import Foundation
import CryptoKit
import Security

/// A Gloop account.
struct Account: Codable, Equatable {
    var name: String
    var email: String
    let createdAt: Date
    /// Friends join with this code; it's also the end of your join link.
    let referralCode: String
    /// How they signed in: "email", "google" or "apple". Nil for older local accounts.
    var provider: String? = nil

    var usesPassword: Bool { provider == nil || provider == "email" }

    /// Where join links point. A placeholder until Gloop has its own domain.
    /// `.example` is reserved and never belongs to anyone, so a placeholder link
    /// can't send friends to someone else's website. (gloop.app is a real,
    /// unrelated site.) Replace this with Gloop's real domain before launch.
    static let joinBase = "https://gloop.example/join/"

    var joinLink: URL { URL(string: Self.joinBase + referralCode)! }
}

enum AccountError: LocalizedError {
    case invalidName, invalidEmail, weakPassword, noAccount, wrongPassword
    case emailTaken, notConfirmed, wrongCode, needsServer, appleNotSetUp, offline
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidName: "Please enter your name."
        case .invalidEmail: "That doesn't look like an email address."
        case .weakPassword: "Use at least 8 characters for your password."
        case .noAccount: "No account with that email on this phone. Create one instead?"
        case .wrongPassword: "That email and password don't match."
        case .emailTaken: "There's already an account with that email. Log in instead?"
        case .notConfirmed: "Confirm your email first. We sent you a code."
        case .wrongCode: "That code didn't work. Check it, or send a new one."
        case .needsServer: "This needs Gloop's server, which isn't connected yet."
        case .appleNotSetUp: "Sign in with Apple isn't set up for this build yet."
        case .offline: "You're offline. Check your connection and try again."
        case .server(let message): message
        }
    }
}

/// Stores the account on this phone.
///
/// Gloop has no server yet, so accounts are local: profile details live in
/// UserDefaults, and the password is never stored as typed. It's salted and
/// hashed (SHA-256) and only the hash goes in the Keychain. When there's a
/// backend, these functions become network calls and the screens stay the same.
enum AccountStore {
    private static let accountKey = "gloop.account"
    private static let sessionKey = "gloop.loggedIn"
    private static let keychainService = "app.gloop.account"

    // MARK: Server account cache

    /// With the server connected, the account is cached here so the app opens
    /// straight to your stuff while the session refreshes in the background.
    private static let remoteKey = "gloop.remoteAccount"

    static var cachedRemote: Account? {
        get {
            guard let data = UserDefaults.standard.data(forKey: remoteKey) else { return nil }
            return try? JSONDecoder().decode(Account.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: remoteKey)
            } else {
                UserDefaults.standard.removeObject(forKey: remoteKey)
            }
        }
    }

    // MARK: Session

    static var account: Account? {
        guard let data = UserDefaults.standard.data(forKey: accountKey) else { return nil }
        return try? JSONDecoder().decode(Account.self, from: data)
    }

    static var isLoggedIn: Bool {
        get { UserDefaults.standard.bool(forKey: sessionKey) && account != nil }
        set { UserDefaults.standard.set(newValue, forKey: sessionKey) }
    }

    private static func save(_ account: Account) {
        if let data = try? JSONEncoder().encode(account) {
            UserDefaults.standard.set(data, forKey: accountKey)
        }
    }

    // MARK: Sign up, log in

    static func createAccount(name: String, email: String, password: String) throws -> Account {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = normalize(email)
        guard !name.isEmpty else { throw AccountError.invalidName }
        guard isValidEmail(email) else { throw AccountError.invalidEmail }
        guard password.count >= 8 else { throw AccountError.weakPassword }

        // One account per phone in this prototype: a new sign-up replaces any old one.
        deleteAccount()
        let account = Account(name: name, email: email, createdAt: .now,
                              referralCode: makeReferralCode(for: name))
        storePassword(password)
        save(account)
        isLoggedIn = true
        return account
    }

    static func logIn(email: String, password: String) throws -> Account {
        guard let account, account.email == normalize(email) else { throw AccountError.noAccount }
        guard checkPassword(password) else { throw AccountError.wrongPassword }
        isLoggedIn = true
        return account
    }

    static func logOut() {
        isLoggedIn = false
    }

    // MARK: Changes

    static func updateName(_ name: String) throws -> Account {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw AccountError.invalidName }
        guard var account else { throw AccountError.noAccount }
        account.name = name
        save(account)
        return account
    }

    static func changePassword(current: String, new: String) throws {
        guard checkPassword(current) else { throw AccountError.wrongPassword }
        guard new.count >= 8 else { throw AccountError.weakPassword }
        storePassword(new)
    }

    static func deleteAccount() {
        UserDefaults.standard.removeObject(forKey: accountKey)
        UserDefaults.standard.removeObject(forKey: sessionKey)
        keychainDelete()
    }

    // MARK: Helpers

    static func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@")
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !email.contains(" ")
    }

    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// e.g. "ALEX-7K2Q": a readable first name plus four random characters.
    static func makeReferralCode(for name: String) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? "GLOOP"
        let letters = first.uppercased().filter { $0.isLetter }.prefix(6)
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let suffix = String((0..<4).map { _ in alphabet.randomElement()! })
        return "\(letters.isEmpty ? "GLOOP" : String(letters))-\(suffix)"
    }

    // MARK: Password hashing + Keychain

    private static func storePassword(_ password: String) {
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        keychainSet(salt + hash(password, salt: salt))
    }

    private static func checkPassword(_ password: String) -> Bool {
        guard let stored = keychainGet(), stored.count > 16 else { return false }
        let salt = stored.prefix(16)
        return stored.suffix(from: 16) == hash(password, salt: Data(salt))
    }

    private static func hash(_ password: String, salt: Data) -> Data {
        Data(SHA256.hash(data: salt + Data(password.utf8)))
    }

    private static var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: keychainService,
         kSecAttrAccount as String: "password"]
    }

    private static func keychainSet(_ data: Data) {
        keychainDelete()
        var query = keychainQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func keychainGet() -> Data? {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func keychainDelete() {
        SecItemDelete(keychainQuery as CFDictionary)
    }
}
