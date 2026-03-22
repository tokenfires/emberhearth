import XCTest
@testable import EmberHearth

final class PhoneNumberFilterTests: XCTestCase {

    private var filter: PhoneNumberFilter!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: PhoneNumberFilter.allowedNumbersKey)
        filter = PhoneNumberFilter()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: PhoneNumberFilter.allowedNumbersKey)
        super.tearDown()
    }

    // MARK: - Normalization Tests

    func testNormalizeAlreadyE164() {
        XCTAssertEqual(PhoneNumberFilter.normalize("+15551234567"), "+15551234567")
    }

    func testNormalizeMissingPlus() {
        XCTAssertEqual(PhoneNumberFilter.normalize("15551234567"), "+15551234567")
    }

    func testNormalizeUSFormatWithParens() {
        XCTAssertEqual(PhoneNumberFilter.normalize("(555) 123-4567"), "+15551234567")
    }

    func testNormalizeDashedFormat() {
        XCTAssertEqual(PhoneNumberFilter.normalize("555-123-4567"), "+15551234567")
    }

    func testNormalizeDottedFormat() {
        XCTAssertEqual(PhoneNumberFilter.normalize("555.123.4567"), "+15551234567")
    }

    func testNormalize10Digits() {
        XCTAssertEqual(PhoneNumberFilter.normalize("5551234567"), "+15551234567")
    }

    func testNormalize11DigitsWithCountryCode() {
        XCTAssertEqual(PhoneNumberFilter.normalize("15551234567"), "+15551234567")
    }

    func testNormalizeInternationalWithPlus() {
        XCTAssertEqual(PhoneNumberFilter.normalize("+442071234567"), "+442071234567")
    }

    func testNormalizeInternationalWithPlusAndSpaces() {
        XCTAssertEqual(PhoneNumberFilter.normalize("+44 207 123 4567"), "+442071234567")
    }

    func testNormalizeWithLeadingTrailingWhitespace() {
        XCTAssertEqual(PhoneNumberFilter.normalize("  +15551234567  "), "+15551234567")
    }

    func testNormalizeEmptyString() {
        XCTAssertNil(PhoneNumberFilter.normalize(""))
    }

    func testNormalizeOnlySpaces() {
        XCTAssertNil(PhoneNumberFilter.normalize("   "))
    }

    func testNormalizeNonNumeric() {
        XCTAssertNil(PhoneNumberFilter.normalize("abc"))
    }

    func testNormalizeTooShort() {
        XCTAssertNil(PhoneNumberFilter.normalize("123"))
    }

    func testNormalizeTooLong() {
        XCTAssertNil(PhoneNumberFilter.normalize("+1234567890123456"))  // 16 digits
    }

    func testNormalizeStartingWithZero() {
        XCTAssertNil(PhoneNumberFilter.normalize("+05551234567"))
    }

    func testNormalizePlusOnly() {
        XCTAssertNil(PhoneNumberFilter.normalize("+"))
    }

    // MARK: - Extension Stripping Tests

    func testNormalizeStripsExtensionWithX() {
        XCTAssertEqual(PhoneNumberFilter.normalize("+15551234567x123"), "+15551234567")
    }

    func testNormalizeStripsExtensionWithUpperX() {
        XCTAssertEqual(PhoneNumberFilter.normalize("+15551234567X123"), "+15551234567")
    }

    func testNormalizeStripsExtensionWithSemicolon() {
        XCTAssertEqual(PhoneNumberFilter.normalize("+15551234567;123"), "+15551234567")
    }

    func testNormalizeStripsExtensionWithHash() {
        XCTAssertEqual(PhoneNumberFilter.normalize("+15551234567#123"), "+15551234567")
    }

    func testNormalizeStripsExtensionWithComma() {
        XCTAssertEqual(PhoneNumberFilter.normalize("+15551234567,123"), "+15551234567")
    }

    func testNormalizeStripsExtensionFromFormattedNumber() {
        XCTAssertEqual(PhoneNumberFilter.normalize("(555) 123-4567 x123"), "+15551234567")
    }

    func testNormalizeRejectsExtensionOnly() {
        XCTAssertNil(PhoneNumberFilter.normalize("x123"))
    }

    // MARK: - Unicode Digit Handling Tests

    func testNormalizeStripsUnicodeDigitsKeepingASCII() {
        // Arabic-Indic digit \u{0661} is stripped; remaining ASCII digits form a valid number
        XCTAssertEqual(PhoneNumberFilter.normalize("+\u{0661}5551234567"), "+5551234567")
    }

    func testNormalizeRejectsAllUnicodeDigits() {
        // Full-width digits only — no ASCII digits remain after filtering
        XCTAssertNil(PhoneNumberFilter.normalize("\u{FF11}\u{FF15}\u{FF15}\u{FF15}\u{FF11}\u{FF12}\u{FF13}\u{FF14}\u{FF15}\u{FF16}\u{FF17}"))
    }

    // MARK: - 7–9 Digit Number Tests (no leading +)

    func testNormalize7DigitNumber() {
        let result = PhoneNumberFilter.normalize("5551234")
        XCTAssertEqual(result, "+5551234")
    }

    func testNormalize8DigitNumber() {
        let result = PhoneNumberFilter.normalize("55512345")
        XCTAssertEqual(result, "+55512345")
    }

    func testNormalize9DigitNumber() {
        let result = PhoneNumberFilter.normalize("555123456")
        XCTAssertEqual(result, "+555123456")
    }

    func testNormalize7DigitStartingWithZeroRejected() {
        XCTAssertNil(PhoneNumberFilter.normalize("0551234"))
    }

    // MARK: - Minimum Length Tests

    func testNormalizePlusOneRejected() {
        XCTAssertNil(PhoneNumberFilter.normalize("+1"))
    }

    func testNormalizePlusTwoDigitsAccepted() {
        XCTAssertEqual(PhoneNumberFilter.normalize("+12"), "+12")
    }

    // MARK: - E.164 Validation Tests

    func testValidE164() {
        XCTAssertTrue(PhoneNumberFilter.isValidE164("+15551234567"))
        XCTAssertTrue(PhoneNumberFilter.isValidE164("+442071234567"))
        XCTAssertTrue(PhoneNumberFilter.isValidE164("+81312345678"))
        XCTAssertTrue(PhoneNumberFilter.isValidE164("+12"))
    }

    func testInvalidE164() {
        XCTAssertFalse(PhoneNumberFilter.isValidE164("5551234567"))
        XCTAssertFalse(PhoneNumberFilter.isValidE164("+0551234567"))
        XCTAssertFalse(PhoneNumberFilter.isValidE164("+"))
        XCTAssertFalse(PhoneNumberFilter.isValidE164("+1"))
        XCTAssertFalse(PhoneNumberFilter.isValidE164(""))
        XCTAssertFalse(PhoneNumberFilter.isValidE164("+1-555-123-4567"))
    }

    // MARK: - Filtering Tests

    func testShouldRespondToAllowedNumber() {
        filter.addAllowedNumber("+15551234567")
        XCTAssertTrue(filter.shouldRespond(to: "+15551234567"))
    }

    func testShouldNotRespondToUnknownNumber() {
        filter.addAllowedNumber("+15551234567")
        XCTAssertFalse(filter.shouldRespond(to: "+15559999999"))
    }

    func testShouldRespondWithDifferentFormats() {
        filter.addAllowedNumber("+15551234567")
        XCTAssertTrue(filter.shouldRespond(to: "+15551234567"))
        XCTAssertTrue(filter.shouldRespond(to: "15551234567"))
        XCTAssertTrue(filter.shouldRespond(to: "(555) 123-4567"))
        XCTAssertTrue(filter.shouldRespond(to: "555-123-4567"))
        XCTAssertTrue(filter.shouldRespond(to: "5551234567"))
    }

    func testShouldRespondWhenAddedInNonE164Format() {
        filter.addAllowedNumber("(555) 123-4567")
        XCTAssertTrue(filter.shouldRespond(to: "+15551234567"))
        XCTAssertTrue(filter.shouldRespond(to: "555-123-4567"))
        XCTAssertTrue(filter.shouldRespond(to: "5551234567"))
    }

    func testShouldNotRespondToEmptyNumber() {
        filter.addAllowedNumber("+15551234567")
        XCTAssertFalse(filter.shouldRespond(to: ""))
    }

    func testShouldNotRespondToInvalidNumber() {
        filter.addAllowedNumber("+15551234567")
        XCTAssertFalse(filter.shouldRespond(to: "not-a-number"))
    }

    // MARK: - Add/Remove Tests

    func testAddAllowedNumber() {
        let result = filter.addAllowedNumber("+15551234567")
        XCTAssertTrue(result)
        XCTAssertEqual(filter.allowedNumberCount, 1)
    }

    func testAddDuplicateNumber() {
        filter.addAllowedNumber("+15551234567")
        filter.addAllowedNumber("+15551234567")
        XCTAssertEqual(filter.allowedNumberCount, 1)
    }

    func testAddDuplicateInDifferentFormats() {
        filter.addAllowedNumber("+15551234567")
        filter.addAllowedNumber("(555) 123-4567")
        XCTAssertEqual(filter.allowedNumberCount, 1)
    }

    func testAddInvalidNumber() {
        let result = filter.addAllowedNumber("not-a-number")
        XCTAssertFalse(result)
        XCTAssertEqual(filter.allowedNumberCount, 0)
    }

    func testRemoveAllowedNumber() {
        filter.addAllowedNumber("+15551234567")
        let result = filter.removeAllowedNumber("+15551234567")
        XCTAssertTrue(result)
        XCTAssertEqual(filter.allowedNumberCount, 0)
    }

    func testRemoveInDifferentFormat() {
        filter.addAllowedNumber("+15551234567")
        let result = filter.removeAllowedNumber("555-123-4567")
        XCTAssertTrue(result)
        XCTAssertEqual(filter.allowedNumberCount, 0)
    }

    func testRemoveNonexistentNumber() {
        let result = filter.removeAllowedNumber("+15559999999")
        XCTAssertFalse(result)
    }

    func testRemoveAllAllowedNumbers() {
        filter.addAllowedNumber("+15551234567")
        filter.addAllowedNumber("+15559876543")
        filter.removeAllAllowedNumbers()
        XCTAssertEqual(filter.allowedNumberCount, 0)
    }

    func testGetAllowedNumbers() {
        filter.addAllowedNumber("+15559876543")
        filter.addAllowedNumber("+15551234567")
        let numbers = filter.getAllowedNumbers()
        XCTAssertEqual(numbers, ["+15551234567", "+15559876543"])
    }

    // MARK: - Persistence Tests

    func testNumbersPersistAcrossInstances() {
        filter.addAllowedNumber("+15551234567")
        filter.addAllowedNumber("+15559876543")

        let newFilter = PhoneNumberFilter()
        XCTAssertEqual(newFilter.allowedNumberCount, 2)
        XCTAssertTrue(newFilter.shouldRespond(to: "+15551234567"))
        XCTAssertTrue(newFilter.shouldRespond(to: "+15559876543"))
    }

    func testEmptyPersistence() {
        let newFilter = PhoneNumberFilter()
        XCTAssertEqual(newFilter.allowedNumberCount, 0)
    }

    func testCorruptedPersistenceIsDiscarded() {
        UserDefaults.standard.set(["not-e164", "+15551234567"], forKey: PhoneNumberFilter.allowedNumbersKey)
        let newFilter = PhoneNumberFilter()
        XCTAssertEqual(newFilter.allowedNumberCount, 1)
        XCTAssertTrue(newFilter.shouldRespond(to: "+15551234567"))
    }

    func testNonArrayPersistenceIsIgnored() {
        UserDefaults.standard.set(42, forKey: PhoneNumberFilter.allowedNumbersKey)
        let newFilter = PhoneNumberFilter()
        XCTAssertEqual(newFilter.allowedNumberCount, 0)
    }

    // MARK: - Multiple Numbers

    func testMultipleAllowedNumbers() {
        filter.addAllowedNumber("+15551234567")
        filter.addAllowedNumber("+15559876543")
        filter.addAllowedNumber("+442071234567")

        XCTAssertTrue(filter.shouldRespond(to: "+15551234567"))
        XCTAssertTrue(filter.shouldRespond(to: "+15559876543"))
        XCTAssertTrue(filter.shouldRespond(to: "+442071234567"))
        XCTAssertFalse(filter.shouldRespond(to: "+15550000000"))
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAddAndRead() {
        let expectation = expectation(description: "concurrent operations complete")
        expectation.expectedFulfillmentCount = 2

        let writeQueue = DispatchQueue(label: "test.write", attributes: .concurrent)
        let readQueue = DispatchQueue(label: "test.read", attributes: .concurrent)

        writeQueue.async {
            for i in 1000...1099 {
                self.filter.addAllowedNumber("+1555\(i)000")
            }
            expectation.fulfill()
        }

        readQueue.async {
            for i in 1000...1099 {
                _ = self.filter.shouldRespond(to: "+1555\(i)000")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
        XCTAssertEqual(filter.allowedNumberCount, 100)
    }

    func testConcurrentAddAndRemove() {
        for i in 1000...1049 {
            filter.addAllowedNumber("+1555\(i)000")
        }

        let expectation = expectation(description: "concurrent add/remove complete")
        expectation.expectedFulfillmentCount = 2

        let addQueue = DispatchQueue(label: "test.add")
        let removeQueue = DispatchQueue(label: "test.remove")

        addQueue.async {
            for i in 1050...1099 {
                self.filter.addAllowedNumber("+1555\(i)000")
            }
            expectation.fulfill()
        }

        removeQueue.async {
            for i in 1000...1049 {
                self.filter.removeAllowedNumber("+1555\(i)000")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
        XCTAssertEqual(filter.allowedNumberCount, 50)
    }
}
