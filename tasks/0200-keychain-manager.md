# Task 0200: Keychain Manager for Secure API Key Storage

**Milestone:** M3 - LLM Integration
**Unit:** 3.5 - Keychain Storage for API Key
**Phase:** 1
**Depends On:** 0004 (M1 complete)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; contains naming conventions (PascalCase for Swift files), security boundaries (Keychain for secrets, never log API keys), project structure
2. `docs/specs/api-setup-guide.md` — Focus on Part 2 sections 2.4-2.5 (lines ~159-266) for API key format validation patterns and the `APIKeyValidator` struct; also note the `LLMProvider` enum with `.claude` and `.openai` cases
3. `docs/architecture/decisions/0008-claude-api-primary-llm.md` — Focus on "API Key Management" section (lines ~80-85) for Keychain storage requirements and the `LLMProvider` protocol sketch
4. `docs/specs/error-handling.md` — Focus on "Health Monitoring > Startup Health Check" section (lines ~393-429) for how `KeychainManager.getAPIKey()` is referenced in the health check system

> **Context Budget Note:** api-setup-guide.md is ~650 lines. Focus only on lines 159-266 (API key entry and validation). error-handling.md is ~587 lines; focus only on lines 393-429 (startup health check referencing KeychainManager). Skip all UI wireframes, cost guidance, and FAQ sections.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the Keychain Manager for EmberHearth, a native macOS personal AI assistant. This component securely stores and retrieves API keys using the macOS Keychain. It is a foundational security component — tasks 0201-0204 depend on it.

IMPORTANT RULES (from CLAUDE.md):
- Swift files use PascalCase (e.g., KeychainManager.swift)
- NEVER log or print API keys, even partially
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- Use Keychain for all secrets
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line

PROJECT CONTEXT:
- This is a Swift Package Manager project (not Xcode project)
- Package.swift has the main target at path "src" and test target at path "tests"
- macOS 13.0+ deployment target
- No third-party dependencies — use only Apple frameworks

STEP 1: Create the LLMProvider enum

File: src/Security/LLMProvider.swift
```swift
// LLMProvider.swift
// EmberHearth
//
// Enumeration of supported LLM providers for API key management.

import Foundation

/// Represents the supported LLM providers.
/// Used as the key identifier when storing/retrieving API keys from Keychain.
enum LLMProvider: String, CaseIterable, Sendable {
    /// Anthropic's Claude API — primary MVP provider
    case claude = "claude"
    /// OpenAI's GPT API — reserved for future use
    case openai = "openai"

    /// The human-readable display name for this provider.
    var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .openai: return "OpenAI"
        }
    }

    /// The Keychain account identifier for this provider's API key.
    /// Format: "api-key-<provider>"
    var keychainAccount: String {
        return "api-key-\(rawValue)"
    }

    /// The expected prefix for this provider's API keys.
    /// Used for basic format validation before storing.
    var apiKeyPrefix: String {
        switch self {
        case .claude: return "sk-ant-"
        case .openai: return "sk-"
        }
    }
}
```

STEP 2: Create the KeychainError enum

File: src/Security/KeychainError.swift
```swift
// KeychainError.swift
// EmberHearth
//
// Error types for Keychain operations.

import Foundation
import Security

/// Errors that can occur during Keychain operations.
enum KeychainError: Error, Equatable, Sendable {
    /// The API key was not found in the Keychain for the specified provider.
    case itemNotFound

    /// A duplicate item already exists. This should not surface to callers
    /// because `store()` handles duplicates by updating instead.
    case duplicateItem

    /// The Keychain is locked and requires user authentication.
    case keychainLocked

    /// The application does not have permission to access this Keychain item.
    case accessDenied

    /// The provided API key is empty or contains only whitespace.
    case invalidKeyFormat(reason: String)

    /// An unexpected Keychain error with the raw OSStatus code.
    case unexpectedError(OSStatus)

    /// Human-readable description for logging (NEVER include the actual key).
    var localizedDescription: String {
        switch self {
        case .itemNotFound:
            return "No API key found in Keychain for this provider."
        case .duplicateItem:
            return "An API key already exists for this provider."
        case .keychainLocked:
            return "The Keychain is locked. Please unlock your Mac and try again."
        case .accessDenied:
            return "EmberHearth does not have permission to access the Keychain."
        case .invalidKeyFormat(let reason):
            return "Invalid API key format: \(reason)"
        case .unexpectedError(let status):
            return "Keychain error (code: \(status))."
        }
    }
}
```

STEP 3: Create the KeychainManager

File: src/Security/KeychainManager.swift
```swift
// KeychainManager.swift
// EmberHearth
//
// Manages secure storage and retrieval of API keys using macOS Keychain.

import Foundation
import Security
import os

/// Manages secure storage and retrieval of API keys in the macOS Keychain.
///
/// Usage:
/// ```swift
/// let manager = KeychainManager()
/// try manager.store(apiKey: "sk-ant-api03-...", for: .claude)
/// let key = try manager.retrieve(for: .claude)
/// ```
///
/// Security guarantees:
/// - Keys are stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
///   (not available when device is locked, not included in backups)
/// - Keys are NEVER logged or printed, even partially
/// - The service name isolates EmberHearth keys from other apps
final class KeychainManager: Sendable {

    // MARK: - Constants

    /// The Keychain service identifier for all EmberHearth API keys.
    /// All keys are stored under this service name.
    let serviceName: String

    /// Logger for security-related events. NEVER logs key values.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "KeychainManager"
    )

    // MARK: - Initialization

    /// Creates a KeychainManager with the specified service name.
    ///
    /// - Parameter serviceName: The Keychain service identifier.
    ///   Defaults to "com.emberhearth.api-keys" for production use.
    ///   Tests should pass a different service name to avoid polluting the real Keychain.
    init(serviceName: String = "com.emberhearth.api-keys") {
        self.serviceName = serviceName
    }

    // MARK: - Public API

    /// Stores an API key securely in the Keychain for the specified provider.
    ///
    /// If a key already exists for this provider, it is updated (not duplicated).
    /// The key is validated for basic format before storing.
    ///
    /// - Parameters:
    ///   - apiKey: The API key string to store. Must not be empty or whitespace-only.
    ///   - provider: The LLM provider this key belongs to.
    /// - Throws: `KeychainError` if the operation fails.
    func store(apiKey: String, for provider: LLMProvider) throws {
        // Validate the key is not empty or whitespace-only
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw KeychainError.invalidKeyFormat(reason: "API key cannot be empty.")
        }

        // Validate minimum length (API keys are typically 40+ characters)
        guard trimmedKey.count >= 20 else {
            throw KeychainError.invalidKeyFormat(reason: "API key is too short. Expected at least 20 characters.")
        }

        // Validate the key starts with the expected prefix for this provider
        guard trimmedKey.hasPrefix(provider.apiKeyPrefix) else {
            throw KeychainError.invalidKeyFormat(
                reason: "API key should start with \"\(provider.apiKeyPrefix)\" for \(provider.displayName)."
            )
        }

        guard let keyData = trimmedKey.data(using: .utf8) else {
            throw KeychainError.invalidKeyFormat(reason: "API key contains invalid characters.")
        }

        // Build the query dictionary for this provider's key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Attempt to add the item
        var status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // Key already exists — update it instead
            Self.logger.info("Updating existing API key for provider: \(provider.rawValue)")
            let searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: provider.keychainAccount
            ]
            let updateAttributes: [String: Any] = [
                kSecValueData as String: keyData,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            status = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)
        }

        guard status == errSecSuccess else {
            Self.logger.error("Failed to store API key for provider: \(provider.rawValue), status: \(status)")
            throw mapOSStatus(status)
        }

        Self.logger.info("Successfully stored API key for provider: \(provider.rawValue)")
    }

    /// Retrieves the stored API key for the specified provider.
    ///
    /// - Parameter provider: The LLM provider to retrieve the key for.
    /// - Returns: The API key string, or `nil` if no key is stored for this provider.
    /// - Throws: `KeychainError` if the Keychain is locked or inaccessible.
    func retrieve(for provider: LLMProvider) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            Self.logger.info("No API key found for provider: \(provider.rawValue)")
            return nil
        }

        guard status == errSecSuccess else {
            Self.logger.error("Failed to retrieve API key for provider: \(provider.rawValue), status: \(status)")
            throw mapOSStatus(status)
        }

        guard let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            Self.logger.error("Failed to decode API key data for provider: \(provider.rawValue)")
            throw KeychainError.unexpectedError(errSecDecode)
        }

        Self.logger.info("Successfully retrieved API key for provider: \(provider.rawValue)")
        return key
    }

    /// Deletes the stored API key for the specified provider.
    ///
    /// - Parameter provider: The LLM provider whose key should be deleted.
    /// - Throws: `KeychainError.itemNotFound` if no key exists, or other errors on failure.
    func delete(for provider: LLMProvider) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: provider.keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound {
            Self.logger.info("No API key to delete for provider: \(provider.rawValue)")
            throw KeychainError.itemNotFound
        }

        guard status == errSecSuccess else {
            Self.logger.error("Failed to delete API key for provider: \(provider.rawValue), status: \(status)")
            throw mapOSStatus(status)
        }

        Self.logger.info("Successfully deleted API key for provider: \(provider.rawValue)")
    }

    /// Checks whether an API key is stored for the specified provider.
    ///
    /// This is a lightweight check that does NOT retrieve the key data.
    ///
    /// - Parameter provider: The LLM provider to check.
    /// - Returns: `true` if a key exists, `false` otherwise.
    func hasKey(for provider: LLMProvider) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Deletes ALL EmberHearth API keys from the Keychain.
    /// Used during app uninstall/reset. Use with caution.
    ///
    /// - Throws: `KeychainError` if any deletion fails.
    func deleteAll() throws {
        for provider in LLMProvider.allCases {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: provider.keychainAccount
            ]
            let status = SecItemDelete(query as CFDictionary)
            // Ignore "not found" — it's fine if some providers don't have keys
            if status != errSecSuccess && status != errSecItemNotFound {
                Self.logger.error("Failed to delete API key for provider: \(provider.rawValue) during deleteAll, status: \(status)")
                throw mapOSStatus(status)
            }
        }
        Self.logger.info("Successfully deleted all EmberHearth API keys.")
    }

    // MARK: - Private Helpers

    /// Maps an OSStatus code to a KeychainError.
    private func mapOSStatus(_ status: OSStatus) -> KeychainError {
        switch status {
        case errSecItemNotFound:
            return .itemNotFound
        case errSecDuplicateItem:
            return .duplicateItem
        case errSecInteractionNotAllowed:
            return .keychainLocked
        case errSecAuthFailed, errSecMissingEntitlement:
            return .accessDenied
        default:
            return .unexpectedError(status)
        }
    }
}
```

STEP 4: Create unit tests

File: tests/Security/KeychainManagerTests.swift
```swift
// KeychainManagerTests.swift
// EmberHearth
//
// Unit tests for KeychainManager.

import XCTest
@testable import EmberHearth

final class KeychainManagerTests: XCTestCase {

    // Use a test-specific service name to avoid polluting the real Keychain.
    // This ensures tests don't interfere with production keys.
    private let testServiceName = "com.emberhearth.api-keys.test"
    private var manager: KeychainManager!

    override func setUp() {
        super.setUp()
        manager = KeychainManager(serviceName: testServiceName)
        // Clean up any leftover test keys from previous runs
        try? manager.deleteAll()
    }

    override func tearDown() {
        // Always clean up test keys after each test
        try? manager.deleteAll()
        manager = nil
        super.tearDown()
    }

    // MARK: - Store Tests

    func testStoreClaudeAPIKey() throws {
        let testKey = "sk-ant-api03-test-key-for-unit-testing-1234567890"
        try manager.store(apiKey: testKey, for: .claude)
        XCTAssertTrue(manager.hasKey(for: .claude))
    }

    func testStoreOpenAIAPIKey() throws {
        let testKey = "sk-test-key-for-openai-unit-testing-1234567890abcdef"
        try manager.store(apiKey: testKey, for: .openai)
        XCTAssertTrue(manager.hasKey(for: .openai))
    }

    func testStoreAndRetrieveClaudeKey() throws {
        let testKey = "sk-ant-api03-test-key-for-unit-testing-1234567890"
        try manager.store(apiKey: testKey, for: .claude)

        let retrieved = try manager.retrieve(for: .claude)
        XCTAssertEqual(retrieved, testKey)
    }

    func testStoreAndRetrieveOpenAIKey() throws {
        let testKey = "sk-test-key-for-openai-unit-testing-1234567890abcdef"
        try manager.store(apiKey: testKey, for: .openai)

        let retrieved = try manager.retrieve(for: .openai)
        XCTAssertEqual(retrieved, testKey)
    }

    func testStoreDuplicateKeyUpdatesExisting() throws {
        let originalKey = "sk-ant-api03-original-key-1234567890abcdef"
        let updatedKey = "sk-ant-api03-updated-key-0987654321fedcba"

        try manager.store(apiKey: originalKey, for: .claude)
        try manager.store(apiKey: updatedKey, for: .claude)

        let retrieved = try manager.retrieve(for: .claude)
        XCTAssertEqual(retrieved, updatedKey, "Storing a duplicate key should update, not create a second entry.")
    }

    func testStoreMultipleProviders() throws {
        let claudeKey = "sk-ant-api03-claude-test-key-1234567890abcdef"
        let openaiKey = "sk-test-openai-key-1234567890abcdefghijklmnop"

        try manager.store(apiKey: claudeKey, for: .claude)
        try manager.store(apiKey: openaiKey, for: .openai)

        XCTAssertEqual(try manager.retrieve(for: .claude), claudeKey)
        XCTAssertEqual(try manager.retrieve(for: .openai), openaiKey)
    }

    // MARK: - Validation Tests

    func testStoreEmptyKeyThrows() {
        XCTAssertThrowsError(try manager.store(apiKey: "", for: .claude)) { error in
            guard let keychainError = error as? KeychainError,
                  case .invalidKeyFormat = keychainError else {
                XCTFail("Expected KeychainError.invalidKeyFormat, got \(error)")
                return
            }
        }
    }

    func testStoreWhitespaceOnlyKeyThrows() {
        XCTAssertThrowsError(try manager.store(apiKey: "   \n\t  ", for: .claude)) { error in
            guard let keychainError = error as? KeychainError,
                  case .invalidKeyFormat = keychainError else {
                XCTFail("Expected KeychainError.invalidKeyFormat, got \(error)")
                return
            }
        }
    }

    func testStoreTooShortKeyThrows() {
        XCTAssertThrowsError(try manager.store(apiKey: "sk-ant-short", for: .claude)) { error in
            guard let keychainError = error as? KeychainError,
                  case .invalidKeyFormat = keychainError else {
                XCTFail("Expected KeychainError.invalidKeyFormat, got \(error)")
                return
            }
        }
    }

    func testStoreWrongPrefixClaudeThrows() {
        let wrongPrefixKey = "sk-wrong-prefix-key-that-is-long-enough-1234567890"
        XCTAssertThrowsError(try manager.store(apiKey: wrongPrefixKey, for: .claude)) { error in
            guard let keychainError = error as? KeychainError,
                  case .invalidKeyFormat = keychainError else {
                XCTFail("Expected KeychainError.invalidKeyFormat, got \(error)")
                return
            }
        }
    }

    func testStoreWrongPrefixOpenAIThrows() {
        let wrongPrefixKey = "not-an-openai-key-that-is-long-enough-1234567890"
        XCTAssertThrowsError(try manager.store(apiKey: wrongPrefixKey, for: .openai)) { error in
            guard let keychainError = error as? KeychainError,
                  case .invalidKeyFormat = keychainError else {
                XCTFail("Expected KeychainError.invalidKeyFormat, got \(error)")
                return
            }
        }
    }

    func testStoreKeyWithLeadingTrailingWhitespace() throws {
        let testKey = "sk-ant-api03-test-key-with-whitespace-1234567890"
        let keyWithWhitespace = "  \(testKey)  \n"

        try manager.store(apiKey: keyWithWhitespace, for: .claude)
        let retrieved = try manager.retrieve(for: .claude)
        XCTAssertEqual(retrieved, testKey, "Leading/trailing whitespace should be trimmed before storing.")
    }

    // MARK: - Retrieve Tests

    func testRetrieveNonExistentKeyReturnsNil() throws {
        let result = try manager.retrieve(for: .claude)
        XCTAssertNil(result, "Retrieving a key that was never stored should return nil.")
    }

    func testRetrieveAfterDeleteReturnsNil() throws {
        let testKey = "sk-ant-api03-test-key-for-delete-test-1234567890"
        try manager.store(apiKey: testKey, for: .claude)
        try manager.delete(for: .claude)

        let result = try manager.retrieve(for: .claude)
        XCTAssertNil(result, "Retrieving a deleted key should return nil.")
    }

    // MARK: - Delete Tests

    func testDeleteExistingKey() throws {
        let testKey = "sk-ant-api03-test-key-for-deletion-1234567890abc"
        try manager.store(apiKey: testKey, for: .claude)
        XCTAssertTrue(manager.hasKey(for: .claude))

        try manager.delete(for: .claude)
        XCTAssertFalse(manager.hasKey(for: .claude))
    }

    func testDeleteNonExistentKeyThrows() {
        XCTAssertThrowsError(try manager.delete(for: .claude)) { error in
            guard let keychainError = error as? KeychainError,
                  case .itemNotFound = keychainError else {
                XCTFail("Expected KeychainError.itemNotFound, got \(error)")
                return
            }
        }
    }

    func testDeleteAllRemovesAllProviderKeys() throws {
        let claudeKey = "sk-ant-api03-claude-test-key-1234567890abcdef"
        let openaiKey = "sk-test-openai-key-1234567890abcdefghijklmnop"

        try manager.store(apiKey: claudeKey, for: .claude)
        try manager.store(apiKey: openaiKey, for: .openai)

        try manager.deleteAll()

        XCTAssertFalse(manager.hasKey(for: .claude))
        XCTAssertFalse(manager.hasKey(for: .openai))
    }

    // MARK: - HasKey Tests

    func testHasKeyReturnsFalseWhenNoKey() {
        XCTAssertFalse(manager.hasKey(for: .claude))
    }

    func testHasKeyReturnsTrueWhenKeyExists() throws {
        let testKey = "sk-ant-api03-test-key-for-haskey-test-1234567890"
        try manager.store(apiKey: testKey, for: .claude)
        XCTAssertTrue(manager.hasKey(for: .claude))
    }

    func testHasKeyReturnsFalseAfterDelete() throws {
        let testKey = "sk-ant-api03-test-key-for-haskey-delete-1234567890"
        try manager.store(apiKey: testKey, for: .claude)
        try manager.delete(for: .claude)
        XCTAssertFalse(manager.hasKey(for: .claude))
    }

    // MARK: - Isolation Tests

    func testDifferentServiceNamesAreIsolated() throws {
        let otherManager = KeychainManager(serviceName: "com.emberhearth.api-keys.test-other")
        defer { try? otherManager.deleteAll() }

        let testKey = "sk-ant-api03-isolation-test-key-1234567890abcde"
        try manager.store(apiKey: testKey, for: .claude)

        // The other manager should NOT see this key
        XCTAssertFalse(otherManager.hasKey(for: .claude))
        XCTAssertNil(try otherManager.retrieve(for: .claude))
    }

    // MARK: - LLMProvider Tests

    func testLLMProviderKeychainAccounts() {
        XCTAssertEqual(LLMProvider.claude.keychainAccount, "api-key-claude")
        XCTAssertEqual(LLMProvider.openai.keychainAccount, "api-key-openai")
    }

    func testLLMProviderAPIKeyPrefixes() {
        XCTAssertEqual(LLMProvider.claude.apiKeyPrefix, "sk-ant-")
        XCTAssertEqual(LLMProvider.openai.apiKeyPrefix, "sk-")
    }

    func testLLMProviderDisplayNames() {
        XCTAssertEqual(LLMProvider.claude.displayName, "Claude (Anthropic)")
        XCTAssertEqual(LLMProvider.openai.displayName, "OpenAI")
    }

    func testLLMProviderAllCases() {
        XCTAssertEqual(LLMProvider.allCases.count, 2)
        XCTAssertTrue(LLMProvider.allCases.contains(.claude))
        XCTAssertTrue(LLMProvider.allCases.contains(.openai))
    }
}
```

IMPORTANT NOTES:
- Do NOT create any directories that don't exist yet. The `src/Security/` directory already exists with a `SecurityModule.swift` placeholder file. Place the new files alongside it.
- The `tests/Security/` directory may not exist yet. Create it if needed.
- The test service name "com.emberhearth.api-keys.test" is different from the production service name "com.emberhearth.api-keys" to ensure tests never touch real keys.
- Tests clean up after themselves in both setUp() and tearDown().
- The KeychainManager is marked `final class` and `Sendable` because it has no mutable state (the serviceName is a let constant).
- All log messages reference the provider name (e.g., "claude") but NEVER the actual key value.
- The `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` accessibility level means:
  - Keys are only accessible when the device is unlocked
  - Keys are NOT included in device backups
  - Keys are NOT transferred to new devices
- After creating all files, verify the build and tests with:
  1. `swift build` from project root
  2. `swift test` from project root
- If the tests/ directory structure doesn't support subdirectories in SPM, put the test file at `tests/KeychainManagerTests.swift` instead of `tests/Security/KeychainManagerTests.swift`. SPM flattens the test directory by default unless configured otherwise. Check the existing test file location (`tests/EmberHearthTests.swift`) and match that pattern.
```

---

## Acceptance Criteria

- [ ] `src/Security/LLMProvider.swift` exists with `LLMProvider` enum containing `.claude` and `.openai` cases
- [ ] `src/Security/KeychainError.swift` exists with all error cases: `itemNotFound`, `duplicateItem`, `keychainLocked`, `accessDenied`, `invalidKeyFormat`, `unexpectedError`
- [ ] `src/Security/KeychainManager.swift` exists with `store()`, `retrieve()`, `delete()`, `hasKey()`, and `deleteAll()` methods
- [ ] Keychain service name is `"com.emberhearth.api-keys"`
- [ ] Uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for all stored items
- [ ] API key validation: rejects empty, too short, wrong prefix
- [ ] Duplicate key storage triggers update (not error)
- [ ] `retrieve()` returns `nil` for missing keys (not throw)
- [ ] API keys are NEVER logged or printed
- [ ] Tests use a separate service name (`"com.emberhearth.api-keys.test"`)
- [ ] Tests clean up Keychain entries in setUp/tearDown
- [ ] `swift build` succeeds
- [ ] `swift test` passes all KeychainManager tests

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/Security/LLMProvider.swift && echo "LLMProvider.swift exists" || echo "MISSING: LLMProvider.swift"
test -f src/Security/KeychainError.swift && echo "KeychainError.swift exists" || echo "MISSING: KeychainError.swift"
test -f src/Security/KeychainManager.swift && echo "KeychainManager.swift exists" || echo "MISSING: KeychainManager.swift"

# Verify test file exists (check both possible locations)
test -f tests/KeychainManagerTests.swift && echo "Test file exists (flat)" || test -f tests/Security/KeychainManagerTests.swift && echo "Test file exists (nested)" || echo "MISSING: KeychainManagerTests.swift"

# Verify no API keys are logged/printed (search for print or os_log with "key" in the value)
grep -n "print(" src/Security/KeychainManager.swift | grep -iv "logger\|log\|description" && echo "WARNING: Found print statements" || echo "OK: No suspicious print statements"

# Build the project
swift build 2>&1

# Run tests (filter to just KeychainManager tests for speed)
swift test --filter KeychainManagerTests 2>&1

# Run all tests to ensure nothing is broken
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the KeychainManager implementation created in task 0200 for EmberHearth. Check for these specific issues:

1. SECURITY REVIEW:
   - Open src/Security/KeychainManager.swift
   - Verify kSecAttrAccessibleWhenUnlockedThisDeviceOnly is used (not kSecAttrAccessibleAfterFirstUnlock or kSecAttrAccessibleAlways — these are less secure)
   - Verify API keys are NEVER logged, printed, or included in error messages. Search all files in src/Security/ for any string interpolation that could leak a key value.
   - Verify the store() method applies the accessibility attribute on BOTH the initial add AND the update path
   - Verify no force-unwraps (!) exist in KeychainManager.swift

2. KEYCHAIN CORRECTNESS:
   - Verify store() handles errSecDuplicateItem by calling SecItemUpdate (not deleting and re-adding — delete+add is not atomic)
   - Verify retrieve() returns nil for errSecItemNotFound (not throwing an error)
   - Verify delete() throws KeychainError.itemNotFound for errSecItemNotFound
   - Verify hasKey() does NOT retrieve the actual key data (uses kSecReturnData: false)
   - Verify the query dictionaries use consistent key types (kSecClass, kSecAttrService, etc.)

3. SENDABILITY AND THREAD SAFETY:
   - Verify KeychainManager is marked Sendable
   - Verify it has no mutable stored properties (all lets, no vars)
   - Verify LLMProvider is marked Sendable
   - Verify KeychainError is marked Sendable

4. NAMING AND CONVENTIONS:
   - All Swift files must be PascalCase
   - File header comments must match the filename
   - The LLMProvider enum should use rawValue strings (not ints)
   - Service name must be exactly "com.emberhearth.api-keys"

5. TEST QUALITY:
   - Verify tests use a DIFFERENT service name from production
   - Verify setUp() and tearDown() both clean up test keys
   - Verify there is a test for the "store duplicate updates" behavior
   - Verify there is a test for isolation between different service names
   - Verify there is a test for whitespace trimming
   - Verify there is at least one test per public method

6. BUILD VERIFICATION:
   - Run `swift build` and verify it succeeds with no warnings
   - Run `swift test --filter KeychainManagerTests` and verify all tests pass
   - Run `swift test` to verify no existing tests are broken

Report any issues found with exact file paths and line numbers. If everything passes, confirm the implementation is solid.
```

---

## Commit Message

```
feat(m3): add Keychain manager for secure API key storage
```

---

## Notes for Next Task

- The `LLMProvider` enum is defined in `src/Security/LLMProvider.swift`. Task 0201 will create an `LLMProviderProtocol` in `src/LLM/` — this is a different concept. `LLMProvider` is the enum for identifying which provider (used for Keychain keys), while `LLMProviderProtocol` is the protocol for the actual API client interface. If there is a naming conflict, 0201 should use `LLMProviderProtocol` for the protocol name.
- `KeychainManager` is initialized with a default service name but accepts a custom one. Task 0201's `ClaudeAPIClient` should create a `KeychainManager()` (using the default) to retrieve the API key.
- The `retrieve()` method returns `String?` (optional) — callers should handle `nil` as "no key configured" and prompt the user to set one up.
- The `hasKey()` method is lightweight (no data retrieval) — use it for quick checks like the startup health check.
- Tests demonstrate the pattern for Keychain testing: use a test-specific service name, clean up in setUp/tearDown. Future tasks should follow this pattern.
