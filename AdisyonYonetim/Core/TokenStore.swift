import Foundation
#if canImport(Security)
import Security
#endif

struct StoredSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var user: AuthUser
}

protocol TokenStore: AnyObject {
    func load() -> StoredSession?
    func save(_ session: StoredSession)
    func clear()
}

/// Bellek içi depo (testler / Linux doğrulaması için).
final class InMemoryTokenStore: TokenStore {
    private var value: StoredSession?
    func load() -> StoredSession? { value }
    func save(_ session: StoredSession) { value = session }
    func clear() { value = nil }
}

#if canImport(Security)
/// Oturum belirteçlerini iOS Keychain'de saklar (yalnızca bu cihaz, kilit açıldıktan sonra).
final class KeychainTokenStore: TokenStore {
    private let service = "com.adisyonyonetim.app.session"
    private let account = "default"

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func load() -> StoredSession? {
        var q = baseQuery
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(StoredSession.self, from: data)
    }

    func save(_ session: StoredSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(baseQuery as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery
            attrs.forEach { add[$0.key] = $0.value }
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
#endif
