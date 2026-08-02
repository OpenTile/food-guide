import ComposableArchitecture
import Foundation
import Security

/// Loads and saves the bearer token used to unlock the food log.
@DependencyClient
nonisolated struct TokenStorageClient {
    var load: @Sendable () throws -> BearerToken?
    var save: @Sendable (_ token: BearerToken) throws -> Void
}

extension TokenStorageClient: DependencyKey {
    static var liveValue: Self {
        Self(
            load: { try KeychainTokenStore.load() },
            save: { try KeychainTokenStore.save($0) }
        )
    }
}

private nonisolated enum KeychainTokenStore {
    private static let account = "bearer-token"

    static func load() throws -> BearerToken? {
        var query = baseQuery
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecItemNotFound:
            return nil

        case errSecSuccess:
            guard
                let data = item as? Data,
                let rawValue = String(data: data, encoding: .utf8)
            else {
                throw KeychainError(status: errSecDecode)
            }
            return BearerToken(rawValue)

        default:
            throw KeychainError(status: status)
        }
    }

    static func save(_ token: BearerToken) throws {
        let attributes: [String: Any] = [
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: Data(token.rawValue.utf8),
        ]
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            attributes as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            var item = baseQuery
            attributes.forEach { item[$0.key] = $0.value }
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError(status: addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError(status: updateStatus)
        }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "FoodGuide",
        ]
    }
}

private nonisolated struct KeychainError: Error {
    let status: OSStatus
}
