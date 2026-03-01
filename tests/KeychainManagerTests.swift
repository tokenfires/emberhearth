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