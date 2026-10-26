import Foundation
import Security

/// What is kept of a session: the refresh token and the email shown in Ajustes.
struct StoredSession: Codable, Equatable {
    let email: String
    var refreshToken: String
}

/// Where the session lives between uses of the app. The access token only lives in memory
/// (15 minutes); the refresh token survives restarts, in the keychain.
protocol TokenStore: AnyObject {
    var accessToken: String? { get set }
    func load() -> StoredSession?
    func save(_ session: StoredSession)
    func clear()
}

/// The refresh token and the email, in the keychain, readable after the first unlock and only
/// on this device (`ThisDeviceOnly`): they are left out of backups and never move to another phone.
final class KeychainTokenStore: TokenStore {
    var accessToken: String?

    private let service = "com.atmosferast.orbita.session"
    private let account = "session"

    init() {
        // The keychain survives uninstalling the app; a fresh install must start signed out.
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "orbita.hasLaunched") {
            clear()
            defaults.set(true, forKey: "orbita.hasLaunched")
        }
    }

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func load() -> StoredSession? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        // Unreadable: as if there was no session.
        return try? JSONDecoder().decode(StoredSession.self, from: data)
    }

    func save(_ session: StoredSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let update: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecSuccess { return }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    func clear() {
        accessToken = nil
        SecItemDelete(query as CFDictionary)
    }
}

/// Memory only, for previews and tests.
final class MemoryTokenStore: TokenStore {
    var accessToken: String?
    private var stored: StoredSession?

    func load() -> StoredSession? { stored }
    func save(_ session: StoredSession) { stored = session }
    func clear() {
        accessToken = nil
        stored = nil
    }
}
