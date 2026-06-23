import Foundation
import CryptoKit
import Security

/// Encrypts the text of sensitive clipboard entries at rest using an AES-GCM
/// key kept in the login Keychain. Plaintext only ever exists in memory; the
/// on-disk history holds ciphertext for entries from sensitive apps.
nonisolated final class HistoryCrypto: @unchecked Sendable {
    static let shared = HistoryCrypto()

    private let service = "com.clippy.encryption"
    private let account = "history-key"
    private let lock = NSLock()
    private var cachedKey: SymmetricKey?

    private init() {}

    /// Returns a base64 AES-GCM sealed box, or nil if a key is unavailable.
    func encrypt(_ plaintext: String) -> String? {
        guard let key = key() else { return nil }
        guard let sealed = try? AES.GCM.seal(Data(plaintext.utf8), using: key),
              let combined = sealed.combined else { return nil }
        return combined.base64EncodedString()
    }

    /// Decrypts a base64 sealed box back to its string, or nil on failure.
    func decrypt(_ ciphertext: String) -> String? {
        guard let key = key(),
              let data = Data(base64Encoded: ciphertext),
              let box = try? AES.GCM.SealedBox(combined: data),
              let plain = try? AES.GCM.open(box, using: key) else { return nil }
        return String(decoding: plain, as: UTF8.self)
    }

    // MARK: - Key management

    private func key() -> SymmetricKey? {
        lock.lock()
        defer { lock.unlock() }
        if let cachedKey { return cachedKey }
        let key = loadKey() ?? createKey()
        cachedKey = key
        return key
    }

    private func loadKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    private func createKey() -> SymmetricKey? {
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem { return loadKey() }
        guard status == errSecSuccess else { return nil }
        return key
    }
}
