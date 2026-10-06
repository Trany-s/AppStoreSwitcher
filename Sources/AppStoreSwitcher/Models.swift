import Foundation
import Security
import Combine

struct StoredAccount: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var email: String
}

struct AccountCredentials {
    var email: String
    var password: String
}

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [StoredAccount] = []
    @Published var errorMessage: String?

    private let metadataKey = "stored-accounts"
    private let keychainService = "com.local.AppStoreSwitcher.credentials"

    init() { loadMetadata() }

    func add(name: String, email: String, password: String) {
        let account = StoredAccount(id: UUID(), name: name.isEmpty ? email : name, email: email)
        do {
            try saveCredentials(AccountCredentials(email: email, password: password), for: account.id)
            accounts.append(account)
            persistMetadata()
        } catch { errorMessage = error.localizedDescription }
    }

    func credentials(for account: StoredAccount) -> AccountCredentials? {
        do { return try readCredentials(for: account.id) }
        catch { errorMessage = error.localizedDescription; return nil }
    }

    func update(_ account: StoredAccount, name: String, email: String, password: String) {
        do {
            let payload = try JSONEncoder().encode([email, password])
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: key(for: account.id)
            ]
            let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: payload] as CFDictionary)
            guard status == errSecSuccess else { throw KeychainError(status: status) }
            if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                accounts[index] = StoredAccount(id: account.id, name: name.isEmpty ? email : name, email: email)
                persistMetadata()
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func remove(_ account: StoredAccount) {
        do {
            try deleteCredentials(for: account.id)
            accounts.removeAll { $0.id == account.id }
            persistMetadata()
        } catch { errorMessage = error.localizedDescription }
    }

    private func loadMetadata() {
        guard let data = UserDefaults.standard.data(forKey: metadataKey) else { return }
        accounts = (try? JSONDecoder().decode([StoredAccount].self, from: data)) ?? []
    }

    private func persistMetadata() {
        UserDefaults.standard.set(try? JSONEncoder().encode(accounts), forKey: metadataKey)
    }

    private func key(for id: UUID) -> String { id.uuidString }

    private func saveCredentials(_ credentials: AccountCredentials, for id: UUID) throws {
        let payload = try JSONEncoder().encode([credentials.email, credentials.password])
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key(for: id),
            kSecValueData as String: payload
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    private func readCredentials(for id: UUID) throws -> AccountCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key(for: id),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
        let values = try JSONDecoder().decode([String].self, from: data)
        guard values.count == 2 else { throw KeychainError(status: errSecDecode) }
        return AccountCredentials(email: values[0], password: values[1])
    }

    private func deleteCredentials(for id: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key(for: id)
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }
}

struct KeychainError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? { "Keychain 操作失败（错误码 \(status)）" }
}
