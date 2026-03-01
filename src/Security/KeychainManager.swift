// KeychainManager.swift
// EmberHearth
//
// Manages secure storage and retrieval of LLM API keys using the system Keychain.

import Foundation
import Security

/// Minimum character length for a valid API key after trimming whitespace.
private let minimumAPIKeyLength = 20

/// Manages LLM provider API keys in the macOS/iOS Keychain.
///
/// Uses dependency-injected `serviceName` so tests can use an isolated
/// service name without polluting production Keychain entries.
public final class KeychainManager {

    // MARK: - Properties

    /// The Keychain service name used to namespace all entries managed by this instance.
    private let serviceName: String

    // MARK: - Initialiser

    /// Creates a new `KeychainManager` scoped to the given service name.
    ///
    /// - Parameter serviceName: The Keychain service identifier. Use a test-specific
    ///   value in unit tests to avoid touching production data.
    public init(serviceName: String) {
        self.serviceName = serviceName
    }

    // MARK: - Public API

    /// Stores (or updates) an API key for the given provider.
    ///
    /// Leading and trailing whitespace is trimmed before validation and storage.
    ///
    /// - Parameters:
    ///   - apiKey: The raw API key string (may have surrounding whitespace).
    ///   - provider: The LLM provider this key belongs to.
    /// - Throws: `KeychainError.invalidKeyFormat` if the key fails validation,
    ///           `KeychainError.unexpectedStatus` for other Keychain failures.
    public func store(apiKey: String, for provider: LLMProvider) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        try validate(apiKey: trimmed, for: provider)

        guard let data = trimmed.data(using: .utf8) else {
            throw KeychainError.dataCorrupted
        }

        // Attempt an update first; if the item doesn't exist, add it.
        if try itemExists(for: provider) {
            let query = baseQuery(for: provider)
            let attributes: [CFString: Any] = [
                kSecValueData: data
            ]
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                throw KeychainError.unexpectedStatus(status)
            }
        } else {
            var query = baseQuery(for: provider)
            query[kSecValueData] = data
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }

    /// Retrieves the stored API key for the given provider.
    ///
    /// - Parameter provider: The LLM provider whose key to retrieve.
    /// - Returns: The stored API key, or `nil` if no key is stored for this provider.
    /// - Throws: `KeychainError.dataCorrupted` if the stored data cannot be decoded,
    ///           `KeychainError.unexpectedStatus` for other Keychain failures.
    public func retrieve(for provider: LLMProvider) throws -> String? {
        var query = baseQuery(for: provider)
        query[kSecReturnData] = kCFBooleanTrue
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let key = String(data: data, encoding: .utf8) else {
                throw KeychainError.dataCorrupted
            }
            return key

        case errSecItemNotFound:
            return nil

        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Deletes the stored API key for the given provider.
    ///
    /// - Parameter provider: The LLM provider whose key to delete.
    /// - Throws: `KeychainError.itemNotFound` if no key exists for this provider,
    ///           `KeychainError.unexpectedStatus` for other Keychain failures.
    public func delete(for provider: LLMProvider) throws {
        let query = baseQuery(for: provider)
        let status = SecItemDelete(query as CFDictionary)

        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Deletes all API keys stored under this manager's service name.
    ///
    /// Silently ignores providers that have no stored key.
    ///
    /// - Throws: `KeychainError.unexpectedStatus` if a Keychain error other than
    ///           "item not found" occurs during deletion.
    public func deleteAll() throws {
        for provider in LLMProvider.allCases {
            let query = baseQuery(for: provider)
            let status = SecItemDelete(query as CFDictionary)
            switch status {
            case errSecSuccess, errSecItemNotFound:
                break
            default:
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }

    /// Returns `true` if a key is currently stored for the given provider.
    ///
    /// This is a non-throwing convenience; any Keychain error is treated as "no key".
    ///
    /// - Parameter provider: The LLM provider to check.
    /// - Returns: `true` if a key exists, `false` otherwise.
    public func hasKey(for provider: LLMProvider) -> Bool {
        (try? itemExists(for: provider)) ?? false
    }

    // MARK: - Private Helpers

    /// Builds the base Keychain query dictionary for the given provider.
    private func baseQuery(for provider: LLMProvider) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: provider.keychainAccount
        ]
    }

    /// Returns `true` if a Keychain item exists for the given provider.
    private func itemExists(for provider: LLMProvider) throws -> Bool {
        var query = baseQuery(for: provider)
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnData] = kCFBooleanFalse

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Validates an already-trimmed API key against the rules for the given provider.
    ///
    /// - Parameters:
    ///   - apiKey: Trimmed API key string.
    ///   - provider: The provider whose rules to validate against.
    /// - Throws: `KeychainError.invalidKeyFormat` with a descriptive reason if invalid.
    private func validate(apiKey: String, for provider: LLMProvider) throws {
        guard !apiKey.isEmpty else {
            throw KeychainError.invalidKeyFormat(reason: "API key must not be empty.")
        }

        guard apiKey.count >= minimumAPIKeyLength else {
            throw KeychainError.invalidKeyFormat(
                reason: "API key is too short (minimum \(minimumAPIKeyLength) characters)."
            )
        }

        guard apiKey.hasPrefix(provider.apiKeyPrefix) else {
            throw KeychainError.invalidKeyFormat(
                reason: "API key for \(provider.displayName) must start with '\(provider.apiKeyPrefix)'."
            )
        }
    }
}