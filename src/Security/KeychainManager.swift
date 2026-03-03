// KeychainManager.swift
// EmberHearth
//
// Secure storage and retrieval of API keys via the system Keychain.

import Foundation
import Security

// MARK: - KeychainError

/// Errors thrown by KeychainManager operations.
public enum KeychainError: Error, Equatable {
    case itemNotFound
    case duplicateItem
    case encodingFailed
    case decodingFailed
    case invalidKeyFormat
    case unexpectedStatus(OSStatus)
}

// MARK: - KeychainManager

/// Manages reading and writing API keys in the system Keychain.
/// Each instance is scoped to a specific service name for test isolation.
public final class KeychainManager {

    // MARK: - Constants

    private static let minimumKeyLength = 20

    // MARK: - Properties

    private let serviceName: String

    // MARK: - Init

    /// Creates a KeychainManager scoped to the given service name.
    /// - Parameter serviceName: The Keychain service identifier.
    ///   Defaults to the production service name.
    public init(serviceName: String = "com.emberhearth.api-keys") {
        self.serviceName = serviceName
    }

    // MARK: - Public API

    /// Stores an API key for the given provider.
    /// Trims whitespace, validates format, then overwrites any existing key.
    /// - Parameters:
    ///   - apiKey: The plaintext API key to store. Not logged.
    ///   - provider: The LLM provider this key belongs to.
    /// - Throws: `KeychainError.invalidKeyFormat` if the key is empty, too short, or has the wrong prefix.
    public func store(apiKey: String, for provider: LLMProvider) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              trimmed.count >= Self.minimumKeyLength,
              trimmed.hasPrefix(provider.apiKeyPrefix) else {
            throw KeychainError.invalidKeyFormat
        }

        guard let data = trimmed.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete any existing item first to avoid duplicateItem errors
        try? deleteItem(for: provider)

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: provider.keychainAccount,
            kSecValueData:   data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Retrieves the stored API key for the given provider.
    /// - Parameter provider: The LLM provider whose key to retrieve.
    /// - Returns: The plaintext API key, or `nil` if no key is stored.
    public func retrieve(for provider: LLMProvider) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: provider.keychainAccount,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }

        return key
    }

    /// Returns `true` if a key is stored for the given provider.
    public func hasKey(for provider: LLMProvider) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: provider.keychainAccount,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    /// Deletes the stored API key for a specific provider.
    /// - Throws: `KeychainError.itemNotFound` if no key exists for this provider.
    public func delete(for provider: LLMProvider) throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: provider.keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status == errSecItemNotFound {
            throw KeychainError.itemNotFound
        }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Deletes all API keys stored under this manager's service name.
    /// Iterates all known providers explicitly — macOS batch deletion via service
    /// name alone is unreliable without kSecMatchLimitAll.
    public func deleteAll() throws {
        for provider in LLMProvider.allCases {
            let query: [CFString: Any] = [
                kSecClass:       kSecClassGenericPassword,
                kSecAttrService: serviceName,
                kSecAttrAccount: provider.keychainAccount
            ]
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }

    // MARK: - Private

    private func deleteItem(for provider: LLMProvider) throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: provider.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
