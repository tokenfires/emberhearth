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
    case unexpectedStatus(OSStatus)
}

// MARK: - KeychainManager

/// Manages reading and writing API keys in the system Keychain.
/// Each instance is scoped to a specific service name for test isolation.
public final class KeychainManager {

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
    /// Overwrites any existing key for that provider.
    /// - Parameters:
    ///   - apiKey: The plaintext API key to store. Not logged.
    ///   - provider: The LLM provider this key belongs to.
    public func store(apiKey: String, for provider: LLMProvider) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete any existing item first to avoid duplicateItem errors
        try? delete(for: provider)

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: provider.rawValue,
            kSecValueData:   data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Retrieves the stored API key for the given provider.
    /// - Parameter provider: The LLM provider whose key to retrieve.
    /// - Returns: The plaintext API key.
    /// - Throws: `KeychainError.itemNotFound` if no key is stored.
    public func retrieve(for provider: LLMProvider) throws -> String {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      serviceName,
            kSecAttrAccount:      provider.rawValue,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }

        return key
    }

    /// Deletes the stored API key for a specific provider.
    /// - Parameter provider: The LLM provider whose key to remove.
    public func delete(for provider: LLMProvider) throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: provider.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Deletes all API keys stored under this manager's service name.
    public func deleteAll() throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}