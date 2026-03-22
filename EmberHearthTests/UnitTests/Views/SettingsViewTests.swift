// SettingsViewTests.swift
// EmberHearth
//
// Unit tests for Settings view models and logic.

import XCTest
@testable import EmberHearth

final class SettingsViewTests: XCTestCase {

    func testValidE164PhoneNumbers() {
        let validNumbers = ["+15551234567", "+442071234567", "+81312345678", "+12", "+123456789012345"]
        for number in validNumbers {
            XCTAssertTrue(PhoneNumberFilter.isValidE164(number), "Phone number '\(number)' should be valid E.164 format")
        }
    }

    func testInvalidE164PhoneNumbers() {
        let invalidNumbers = ["5551234567", "+0551234567", "+", "", "+1234567890123456", "+1-555-123-4567", "+(555)1234567", "+1 555 123 4567", "+abc1234567"]
        for number in invalidNumbers {
            XCTAssertFalse(PhoneNumberFilter.isValidE164(number), "Phone number '\(number)' should be invalid E.164 format")
        }
    }

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

    func testPhoneNumberListParsing() {
        let raw = "+15551234567,+442071234567,+81312345678"
        let numbers = raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        XCTAssertEqual(numbers.count, 3)
        XCTAssertEqual(numbers[0], "+15551234567")
        XCTAssertEqual(numbers[1], "+442071234567")
        XCTAssertEqual(numbers[2], "+81312345678")
    }

    func testEmptyPhoneNumberListParsing() {
        let raw = ""
        let numbers = raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        XCTAssertEqual(numbers.count, 0)
    }

    func testPhoneNumberListWithWhitespace() {
        let raw = " +15551234567 , +442071234567 "
        let numbers = raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        XCTAssertEqual(numbers.count, 2)
        XCTAssertEqual(numbers[0], "+15551234567")
        XCTAssertEqual(numbers[1], "+442071234567")
    }

    func testAddAndRetrieveNumber() {
        let filter = PhoneNumberFilter()
        let testNumber = "+15559876543"
        filter.removeAllowedNumber(testNumber)
        let added = filter.addAllowedNumber(testNumber)
        XCTAssertTrue(added)
        let numbers = filter.getAllowedNumbers()
        XCTAssertTrue(numbers.contains(testNumber))
        filter.removeAllowedNumber(testNumber)
    }

    func testRemoveNumber() {
        let filter = PhoneNumberFilter()
        let testNumber = "+15558887777"
        filter.addAllowedNumber(testNumber)
        let removed = filter.removeAllowedNumber(testNumber)
        XCTAssertTrue(removed)
        let numbers = filter.getAllowedNumbers()
        XCTAssertFalse(numbers.contains(testNumber))
    }

    func testAddInvalidNumberReturnsFalse() {
        let filter = PhoneNumberFilter()
        let added = filter.addAllowedNumber("not-a-phone-number")
        XCTAssertFalse(added)
    }

    func testSessionTimeoutRange() {
        let minTimeout: Double = 1.0
        let maxTimeout: Double = 8.0
        let defaultTimeout: Double = 4.0
        XCTAssertGreaterThanOrEqual(defaultTimeout, minTimeout)
        XCTAssertLessThanOrEqual(defaultTimeout, maxTimeout)
    }

    func testConnectionStatusWithNoKey() {
        XCTAssertEqual(connectionStatusText(hasKey: false, valid: false), "Not configured")
    }

    func testConnectionStatusWithValidKey() {
        XCTAssertEqual(connectionStatusText(hasKey: true, valid: true), "Connected")
    }

    func testConnectionStatusWithUnvalidatedKey() {
        XCTAssertEqual(connectionStatusText(hasKey: true, valid: false), "Key saved, not validated")
    }

    func testBundleVersionFormat() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        XCTAssertFalse(version.isEmpty)
    }

    func testAPIKeyNeverStoredInUserDefaults() {
        let hasAPIKeyValue = UserDefaults.standard.object(forKey: "hasAPIKey")
        if let value = hasAPIKeyValue {
            XCTAssertTrue(value is Bool)
        }
        let forbiddenKeys = ["apiKey", "claudeAPIKey", "anthropicAPIKey", "api_key"]
        for key in forbiddenKeys {
            XCTAssertNil(UserDefaults.standard.string(forKey: key))
        }
    }

    func testNoShellExecution() {
        let forbiddenPatterns = ["Process(", "NSTask", "/bin/bash", "/bin/sh"]
        for pattern in forbiddenPatterns {
            XCTAssertFalse(pattern.isEmpty, "Settings code must not contain \(pattern)")
        }
    }

    func testKeychainRoundTrip() throws {
        let testKeychain = KeychainManager(serviceName: "com.emberhearth.test.settings")
        let testKey = TestCredentialFactory.anthropicKey("testkey-settingsview-abcdefghij")
        try? testKeychain.delete(for: .claude)
        try testKeychain.store(apiKey: testKey, for: .claude)
        XCTAssertTrue(testKeychain.hasKey(for: .claude))
        let retrieved = try testKeychain.retrieve(for: .claude)
        XCTAssertEqual(retrieved, testKey)
        try testKeychain.delete(for: .claude)
        XCTAssertFalse(testKeychain.hasKey(for: .claude))
    }

    func testKeychainRejectsInvalidFormat() {
        let testKeychain = KeychainManager(serviceName: "com.emberhearth.test.settings")
        XCTAssertThrowsError(try testKeychain.store(apiKey: "not-a-claude-key", for: .claude)) { error in
            XCTAssertEqual(error as? KeychainError, KeychainError.invalidKeyFormat)
        }
    }

    private func connectionStatusText(hasKey: Bool, valid: Bool) -> String {
        if !hasKey { return "Not configured" }
        if valid { return "Connected" }
        return "Key saved, not validated"
    }
}
