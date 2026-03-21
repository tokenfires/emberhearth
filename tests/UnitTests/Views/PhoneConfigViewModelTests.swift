// PhoneConfigViewModelTests.swift
// EmberHearth
//
// Unit tests for PhoneConfigViewModel.

import XCTest
@testable import EmberHearth

@MainActor
final class PhoneConfigViewModelTests: XCTestCase {

    private var viewModel: PhoneConfigViewModel!
    private var phoneNumberFilter: PhoneNumberFilter!

    override func setUp() {
        super.setUp()
        phoneNumberFilter = PhoneNumberFilter()
        phoneNumberFilter.removeAllAllowedNumbers()
        viewModel = PhoneConfigViewModel(phoneNumberFilter: phoneNumberFilter)
    }

    override func tearDown() {
        phoneNumberFilter.removeAllAllowedNumbers()
        viewModel = nil
        phoneNumberFilter = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertTrue(viewModel.phoneNumberText.isEmpty)
        XCTAssertTrue(viewModel.phoneEntries.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.canContinue)
        XCTAssertFalse(viewModel.canAddNumber)
    }

    // MARK: - canContinue Tests

    func testCanContinueIsFalseWithNoEntries() {
        XCTAssertFalse(viewModel.canContinue)
    }

    func testCanContinueIsTrueWithEntries() {
        viewModel.phoneNumberText = "5551234567"
        viewModel.addPhoneNumber()
        XCTAssertTrue(viewModel.canContinue)
    }

    // MARK: - canAddNumber Tests

    func testCanAddNumberWithEmptyText() {
        viewModel.phoneNumberText = ""
        XCTAssertFalse(viewModel.canAddNumber)
    }

    func testCanAddNumberWithText() {
        viewModel.phoneNumberText = "555"
        XCTAssertTrue(viewModel.canAddNumber)
    }

    func testCanAddNumberWithWhitespaceOnly() {
        viewModel.phoneNumberText = "   "
        XCTAssertFalse(viewModel.canAddNumber)
    }

    // MARK: - addPhoneNumber Tests

    func testAddValidUSNumber() {
        viewModel.phoneNumberText = "5551234567"
        viewModel.addPhoneNumber()
        XCTAssertEqual(viewModel.phoneEntries.count, 1)
        XCTAssertEqual(viewModel.phoneEntries.first?.normalized, "+15551234567")
        XCTAssertTrue(viewModel.phoneNumberText.isEmpty, "Text field should be cleared after adding")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddFormattedUSNumber() {
        viewModel.phoneNumberText = "(555) 123-4567"
        viewModel.addPhoneNumber()
        XCTAssertEqual(viewModel.phoneEntries.count, 1)
        XCTAssertEqual(viewModel.phoneEntries.first?.normalized, "+15551234567")
    }

    func testAddDashedUSNumber() {
        viewModel.phoneNumberText = "555-123-4567"
        viewModel.addPhoneNumber()
        XCTAssertEqual(viewModel.phoneEntries.count, 1)
        XCTAssertEqual(viewModel.phoneEntries.first?.normalized, "+15551234567")
    }

    func testAddNumberWithCountryCode() {
        viewModel.phoneNumberText = "1-555-123-4567"
        viewModel.addPhoneNumber()
        XCTAssertEqual(viewModel.phoneEntries.count, 1)
        XCTAssertEqual(viewModel.phoneEntries.first?.normalized, "+15551234567")
    }

    func testAddAlreadyNormalizedNumber() {
        viewModel.phoneNumberText = "+15551234567"
        viewModel.addPhoneNumber()
        XCTAssertEqual(viewModel.phoneEntries.count, 1)
        XCTAssertEqual(viewModel.phoneEntries.first?.normalized, "+15551234567")
    }

    func testAddEmptyNumberShowsError() {
        viewModel.phoneNumberText = ""
        viewModel.addPhoneNumber()
        XCTAssertTrue(viewModel.phoneEntries.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testAddTooShortNumberShowsError() {
        viewModel.phoneNumberText = "12345"
        viewModel.addPhoneNumber()
        XCTAssertTrue(viewModel.phoneEntries.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testAddDuplicateNumberShowsError() {
        viewModel.phoneNumberText = "5551234567"
        viewModel.addPhoneNumber()
        viewModel.phoneNumberText = "(555) 123-4567"
        viewModel.addPhoneNumber()
        XCTAssertEqual(viewModel.phoneEntries.count, 1, "Should not add duplicate")
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("already") == true)
    }

    func testAddMultipleDistinctNumbers() {
        viewModel.phoneNumberText = "5551234567"
        viewModel.addPhoneNumber()
        viewModel.phoneNumberText = "5559876543"
        viewModel.addPhoneNumber()
        XCTAssertEqual(viewModel.phoneEntries.count, 2)
    }

    func testErrorClearsOnSuccessfulAdd() {
        viewModel.phoneNumberText = "123"
        viewModel.addPhoneNumber()
        XCTAssertNotNil(viewModel.errorMessage)

        viewModel.phoneNumberText = "5551234567"
        viewModel.addPhoneNumber()
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - removePhoneNumber Tests

    func testRemovePhoneNumber() {
        viewModel.phoneNumberText = "5551234567"
        viewModel.addPhoneNumber()
        XCTAssertEqual(viewModel.phoneEntries.count, 1)

        let entry = viewModel.phoneEntries[0]
        viewModel.removePhoneNumber(entry)
        XCTAssertTrue(viewModel.phoneEntries.isEmpty)
    }

    func testRemovePhoneNumberAtOffset() {
        viewModel.phoneNumberText = "5551234567"
        viewModel.addPhoneNumber()
        viewModel.phoneNumberText = "5559876543"
        viewModel.addPhoneNumber()
        XCTAssertEqual(viewModel.phoneEntries.count, 2)

        viewModel.removePhoneNumber(at: IndexSet(integer: 0))
        XCTAssertEqual(viewModel.phoneEntries.count, 1)
        XCTAssertEqual(viewModel.phoneEntries[0].normalized, "+15559876543")
    }

    func testCanContinueBecomesFalseAfterRemovingAllNumbers() {
        viewModel.phoneNumberText = "5551234567"
        viewModel.addPhoneNumber()
        XCTAssertTrue(viewModel.canContinue)

        let entry = viewModel.phoneEntries[0]
        viewModel.removePhoneNumber(entry)
        XCTAssertFalse(viewModel.canContinue)
    }

    // MARK: - Normalization Tests

    func testNormalize10DigitUS() {
        XCTAssertEqual(viewModel.normalizePhoneNumber("5551234567"), "+15551234567")
    }

    func testNormalize11DigitUSWithCountryCode() {
        XCTAssertEqual(viewModel.normalizePhoneNumber("15551234567"), "+15551234567")
    }

    func testNormalizeWithFormatting() {
        XCTAssertEqual(viewModel.normalizePhoneNumber("(555) 123-4567"), "+15551234567")
    }

    func testNormalizeWithDashes() {
        XCTAssertEqual(viewModel.normalizePhoneNumber("555-123-4567"), "+15551234567")
    }

    func testNormalizeWithPlus() {
        XCTAssertEqual(viewModel.normalizePhoneNumber("+15551234567"), "+15551234567")
    }

    func testNormalizeTooShort() {
        XCTAssertNil(viewModel.normalizePhoneNumber("12345"))
    }

    func testNormalizeEmptyString() {
        XCTAssertNil(viewModel.normalizePhoneNumber(""))
    }

    func testNormalizeNonNumeric() {
        XCTAssertNil(viewModel.normalizePhoneNumber("abcdefghij"))
    }

    func testNormalizeWithDots() {
        XCTAssertEqual(viewModel.normalizePhoneNumber("555.123.4567"), "+15551234567")
    }

    // MARK: - Display Formatting Tests

    func testFormatUSNumber() {
        let formatted = viewModel.formatForDisplay("+15551234567")
        XCTAssertEqual(formatted, "+1 (555) 123-4567")
    }

    func testFormatNonUSNumber() {
        let formatted = viewModel.formatForDisplay("+442071234567")
        XCTAssertEqual(formatted, "+442071234567")
    }

    // MARK: - Save Tests

    func testSavePhoneNumbersPersistsViaFilter() {
        viewModel.phoneNumberText = "5551234567"
        viewModel.addPhoneNumber()
        viewModel.phoneNumberText = "5559876543"
        viewModel.addPhoneNumber()

        viewModel.savePhoneNumbers()

        let saved = phoneNumberFilter.getAllowedNumbers()
        XCTAssertEqual(saved.count, 2)
        XCTAssertTrue(saved.contains("+15551234567"))
        XCTAssertTrue(saved.contains("+15559876543"))
    }

    func testSaveReplacesExistingNumbers() {
        phoneNumberFilter.addAllowedNumber("+15550000000")

        viewModel.phoneNumberText = "5551234567"
        viewModel.addPhoneNumber()
        viewModel.savePhoneNumbers()

        let saved = phoneNumberFilter.getAllowedNumbers()
        XCTAssertEqual(saved.count, 1)
        XCTAssertTrue(saved.contains("+15551234567"))
        XCTAssertFalse(saved.contains("+15550000000"))
    }

    // MARK: - PhoneEntry Tests

    func testPhoneEntryEquality() {
        let entry1 = PhoneEntry(rawInput: "555-123-4567", normalized: "+15551234567")
        let entry2 = PhoneEntry(rawInput: "555-123-4567", normalized: "+15551234567")
        XCTAssertNotEqual(entry1, entry2, "Entries with different UUIDs should not be equal")
    }
}
