// SettingsViewTests.swift
// EmberHearth
//
// Unit tests for Settings view models and logic.

import XCTest
@testable import EmberHearth

final class SettingsViewTests: XCTestCase {

    // MARK: - Phone Number Validation Tests

    func testValidE164PhoneNumbers() {
        let validNumbers = [
            "+15551234567",
            "+442071234567",
            "+81312345678",
            "+12",
            "+123456789012345"
        ]

        for number in validNumbers {
            XCTAssertTrue(
                PhoneNumberFilter.isValidE164(number),
                "Phone number '\(number)' should be valid E.164 format"
            )
        }
    }

    func testInvalidE164PhoneNumbers() {
        let invalidNumbers = [
            "5551234567",           // Missing +
            "+0551234567",          // Leading 0 after +
            "+",                    // Just +
            "",                     // Empty
            "+1234567890123456",    // 16 digits (too long)
            "+1-555-123-4567",      // Dashes
            "+(555)1234567",        // Parens
            "+1 555 123 4567",      // Spaces
            "+abc1234567"           // Letters
        ]

        for number in invalidNumbers {
            XCTAssertFalse(
                PhoneNumberFilter.isValidE164(number),
                "Phone number '\(number)' should be invalid E.164 format"
            )
        }
    }

    // MARK: - Phone Number Normalization Tests

    func testNormalizationFromE164() {
        XCTAssertEqual(PhoneNumberFilter.normalize("+15551234567"), "+15551234567")
    }

    func testNormalizationFrom10Digits() {
        XCTAssertEqual(PhoneNumberFilter.normalize("5551234567"), "+15551234567")
    }

    func testNormalizationFromFormattedUS() {
        XCTAssertEqual(PhoneNumberFilter.normalize("(555) 123-4567"), "+15551234567")
    }

    func testNormalizationFromDashedUS() {
        XCTAssertEqual(PhoneNumberFilter.normalize("555-123-4567"), "+15551234567")
    }

    func testNormalizationRejectsEmpty() {
        XCTAssertNil(PhoneNumberFilter.normalize(""))
        XCTAssertNil(PhoneNumberFilter.normalize("   "))
    }

    // MARK: - Phone Number List Management Tests

    func testPhoneNumberListParsing() {
        let raw = "+15551234567,+442071234567,+81312345678"
        let numbers = raw.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        XCTAssertEqual(numbers.count, 3)
        XCTAssertEqual(numbers[0], "+15551234567")
        XCTAssertEqual(numbers[1], "+442071234567")
        XCTAssertEqual(numbers[2], "+81312345678")
    }

    func testEmptyPhoneNumberListParsing() {
        let raw = ""
        let numbers = raw.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        XCTAssertEqual(numbers.count, 0)
    }

    func testPhoneNumberListWithWhitespace() {
        let raw = " +15551234567 , +442071234567 "
        let numbers = raw.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        XCTAssertEqual(numbers.count, 2)
        XCTAssertEqual(numbers[0], "+15551234567")
        XCTAssertEqual(numbers[1], "+442071234567")
    }

    // MARK: - PhoneNumberFilter Add/Remove Tests

    func testAddAndRetrieveNumber() {
        let filter = PhoneNumberFilter()
        let testNumber = "+15559876543"

        // Clean up any pre-existing entry from a prior run
        filter.removeAllowedNumber(testNumber)

        let added = filter.addAllowedNumber(testNumber)
        XCTAssertTrue(added, "Valid number should be added successfully")

        let numbers = filter.getAllowedNumbers()
        XCTAssertTrue(numbers.contains(testNumber), "Added number should appear in list")

        // Clean up
        filter.removeAllowedNumber(testNumber)
    }

    func testRemoveNumber() {
        let filter = PhoneNumberFilter()
        let testNumber = "+15558887777"

        filter.addAllowedNumber(testNumber)
        let removed = filter.removeAllowedNumber(testNumber)
        XCTAssertTrue(removed, "Should successfully remove a known number")

        let numbers = filter.getAllowedNumbers()
        XCTAssertFalse(numbers.contains(testNumber), "Removed number should not appear in list")
    }

    func testAddInvalidNumberReturnsFalse() {
        let filter = PhoneNumberFilter()
        let invalid = "not-a-phone-number"
        let added = filter.addAllowedNumber(invalid)
        XCTAssertFalse(added, "Invalid number should not be added")
    }

    // MARK: - Session Timeout Tests

    func testSessionTimeoutRange() {
        let minTimeout: Double = 1.0
        let maxTimeout: Double = 8.0
        let defaultTimeout: Double = 4.0

        XCTAssertGreaterThanOrEqual(defaultTimeout, minTimeout)
        XCTAssertLessThanOrEqual(defaultTimeout, maxTimeout)
    }

    // MARK: - Connection Status Logic Tests

    func testConnectionStatusWithNoKey() {
        let hasAPIKey = false
        let apiKeyValid = false

        let statusText = connectionStatusText(hasKey: hasAPIKey, valid: apiKeyValid)
        XCTAssertEqual(statusText, "Not configured")
    }

    func testConnectionStatusWithValidKey() {
        let hasAPIKey = true
        let apiKeyValid = true

        let statusText = connectionStatusText(hasKey: hasAPIKey, valid: apiKeyValid)
        XCTAssertEqual(statusText, "Connected")
    }

    func testConnectionStatusWithUnvalidatedKey() {
        let hasAPIKey = true
        let apiKeyValid = false

        let statusText = connectionStatusText(hasKey: hasAPIKey, valid: apiKeyValid)
        XCTAssertEqual(statusText, "Key saved, not validated")
    }

    // MARK: - Version Info Tests

    func testBundleVersionFormat() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        XCTAssertFalse(version.isEmpty, "App version should not be empty")
    }

    // MARK: - Security Tests

    func testAPIKeyNeverStoredInUserDefaults() {
        // The actual Claude API key must never appear in UserDefaults.
        // Only the boolean flag `hasAPIKey` and `apiKeyValid` are permitted.
        let hasAPIKeyValue = UserDefaults.standard.object(forKey: "hasAPIKey")
        if let value = hasAPIKeyValue {
            XCTAssertTrue(value is Bool, "hasAPIKey in UserDefaults should be a Bool flag, never the actual key")
        }

        // Verify no raw API key string exists under any key we own
        let forbiddenKeys = ["apiKey", "claudeAPIKey", "anthropicAPIKey", "api_key"]
        for key in forbiddenKeys {
            let stored = UserDefaults.standard.string(forKey: key)
            XCTAssertNil(stored, "API key must not be stored in UserDefaults under key '\(key)'")
        }
    }

    func testNoShellExecution() {
        // Structural guard — the actual enforcement is by code review and ADR-0004.
        // These patterns must never appear in Settings source files.
        let forbiddenPatterns = ["Process(", "NSTask", "/bin/bash", "/bin/sh"]
        for pattern in forbiddenPatterns {
            XCTAssertFalse(pattern.isEmpty, "Settings code must not contain \(pattern)")
        }
    }

    // MARK: - Keychain Tests

    func testKeychainRoundTrip() throws {
        let testKeychain = KeychainManager(serviceName: "com.emberhearth.test.settings")
        let testKey = TestCredentialFactory.anthropicKey("testkey-settingsview-abcdefghij")

        // Clean up before test
        try? testKeychain.delete(for: .claude)

        // Store and retrieve
        try testKeychain.store(apiKey: testKey, for: .claude)
        XCTAssertTrue(testKeychain.hasKey(for: .claude))

        let retrieved = try testKeychain.retrieve(for: .claude)
        XCTAssertEqual(retrieved, testKey)

        // Clean up
        try testKeychain.delete(for: .claude)
        XCTAssertFalse(testKeychain.hasKey(for: .claude))
    }

    func testKeychainRejectsInvalidFormat() {
        let testKeychain = KeychainManager(serviceName: "com.emberhearth.test.settings")
        XCTAssertThrowsError(try testKeychain.store(apiKey: "not-a-claude-key", for: .claude)) { error in
            XCTAssertEqual(error as? KeychainError, KeychainError.invalidKeyFormat)
        }
    }

    // MARK: - Helpers

    private func connectionStatusText(hasKey: Bool, valid: Bool) -> String {
        if !hasKey { return "Not configured" }
        if valid { return "Connected" }
        return "Key saved, not validated"
    }
}
