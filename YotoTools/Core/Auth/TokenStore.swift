import Foundation
import Security

/// Persistence seam for OAuth tokens. Mockable for tests.
protocol TokenStoring: Sendable {
    func load() async -> OAuthTokens?
    func save(_ tokens: OAuthTokens) async throws
    func clear() async throws
}

enum TokenStoreError: Error, Equatable {
    case keychain(OSStatus)
    case encoding
}

/// Keychain-backed token store. Tokens are stored as a single JSON blob under a
/// generic-password item keyed by `service`/`account`.
actor KeychainTokenStore: TokenStoring {
    private let service: String
    private let account: String

    init(service: String = "com.yototools.YotoTools.oauth", account: String = "default") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func load() async -> OAuthTokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(OAuthTokens.self, from: data)
    }

    func save(_ tokens: OAuthTokens) async throws {
        guard let data = try? JSONEncoder().encode(tokens) else {
            throw TokenStoreError.encoding
        }
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus == errSecItemNotFound {
            var insert = baseQuery
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw TokenStoreError.keychain(addStatus) }
            return
        }
        throw TokenStoreError.keychain(updateStatus)
    }

    func clear() async throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStoreError.keychain(status)
        }
    }
}

/// In-memory store used by previews and tests.
actor InMemoryTokenStore: TokenStoring {
    private var tokens: OAuthTokens?

    init(tokens: OAuthTokens? = nil) {
        self.tokens = tokens
    }

    func load() async -> OAuthTokens? { tokens }
    func save(_ tokens: OAuthTokens) async throws { self.tokens = tokens }
    func clear() async throws { tokens = nil }
}
