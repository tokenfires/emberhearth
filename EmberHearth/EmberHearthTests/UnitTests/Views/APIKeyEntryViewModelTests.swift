// APIKeyEntryViewModelTests.swift
// EmberHearth
//
// Unit tests for APIKeyEntryViewModel validation logic.

import XCTest
@testable import EmberHearthCore

@MainActor
final class APIKeyEntryViewModelTests: XCTestCase {

    // Use a test-specific Keychain service name to avoid touching production keys.
    private let testServiceName = "com.emberhearth.api-keys.test.onboarding"
    private var testKeychainManager: KeychainManager!
    private var viewModel: APIKeyEntryViewModel!

    override func setUp() {
        super.setUp()
        testKeychainManager = KeychainManager(serviceName: testServiceName)
        try? testKeychainManager.deleteAll()
        viewModel = APIKeyEntryViewModel(keychainManager: testKeychainManager)
    }

    override func tearDown() {
        try? testKeychainManager.deleteAll()
        testKeychainManager = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialStateIsIdle() {
        XCTAssertEqual(viewModel.validationState, .idle)
        XCTAssertTrue(viewModel.apiKeyText.isEmpty)
        XCTAssertFalse(viewModel.isExplanationExpanded)
    }

    // MARK: - canValidate Tests

    func testCanValidateWithEmptyKey() {
        viewModel.apiKeyText = ""
        XCTAssertFalse(viewModel.canValidate, "Should not be able to validate with empty key")
    }

    func testCanValidateWithWhitespaceOnly() {
        viewModel.apiKeyText = "   \n  "
        XCTAssertFalse(viewModel.canValidate, "Should not be able to validate with whitespace-only key")
    }

    func testCanValidateWithValidText() {
        viewModel.apiKeyText = TestCredentialFactory.anthropicKey("some-test-key-value")
        XCTAssertTrue(viewModel.canValidate, "Should be able to validate with non-empty key text")
    }

    func testCanValidateIsFalseWhenAlreadyValid() async {
        viewModel.validationState = .valid
        viewModel.apiKeyText = TestCredentialFactory.anthropicKey("some-test-key-value")
        XCTAssertFalse(viewModel.canValidate, "Should not be able to validate when already valid")
    }

    // MARK: - Format Validation Tests

    func testValidateEmptyKey() async {
        viewModel.apiKeyText = ""
        await viewModel.validateAPIKey()
        if case .invalid(let message) = viewModel.validationState {
            XCTAssertTrue(message.contains("enter"), "Error message should ask user to enter key")
        } else {
            XCTFail("Expected .invalid state for empty key")
        }
    }

    func testValidateWrongPrefix() async {
        viewModel.apiKeyText = "sk-wrong-prefix-key-that-is-long-enough-1234567890"
        await viewModel.validateAPIKey()
        if case .invalid(let message) = viewModel.validationState {
            XCTAssertTrue(message.contains("sk-ant-"), "Error should mention the correct prefix")
        } else {
            XCTFail("Expected .invalid state for wrong prefix")
        }
    }

    func testValidateTooShortKey() async {
        viewModel.apiKeyText = "sk-ant-short"
        await viewModel.validateAPIKey()
        if case .invalid(let message) = viewModel.validationState {
            XCTAssertTrue(message.contains("short"), "Error should mention the key is too short")
        } else {
            XCTFail("Expected .invalid state for too-short key")
        }
    }

    // MARK: - Validation State Tests

    func testValidationStateEquality() {
        XCTAssertEqual(APIKeyValidationState.idle, APIKeyValidationState.idle)
        XCTAssertEqual(APIKeyValidationState.validating, APIKeyValidationState.validating)
        XCTAssertEqual(APIKeyValidationState.valid, APIKeyValidationState.valid)
        XCTAssertEqual(
            APIKeyValidationState.invalid(message: "test"),
            APIKeyValidationState.invalid(message: "test")
        )
        XCTAssertNotEqual(APIKeyValidationState.idle, APIKeyValidationState.validating)
    }

    func testValidationStateIsValidating() {
        XCTAssertFalse(APIKeyValidationState.idle.isValidating)
        XCTAssertTrue(APIKeyValidationState.validating.isValidating)
        XCTAssertFalse(APIKeyValidationState.valid.isValidating)
        XCTAssertFalse(APIKeyValidationState.invalid(message: "err").isValidating)
    }

    func testValidationStateIsValid() {
        XCTAssertFalse(APIKeyValidationState.idle.isValid)
        XCTAssertFalse(APIKeyValidationState.validating.isValid)
        XCTAssertTrue(APIKeyValidationState.valid.isValid)
        XCTAssertFalse(APIKeyValidationState.invalid(message: "err").isValid)
    }

    // MARK: - Reset Tests

    func testResetValidation() {
        viewModel.validationState = .invalid(message: "some error")
        viewModel.resetValidation()
        XCTAssertEqual(viewModel.validationState, .idle)
    }
}
