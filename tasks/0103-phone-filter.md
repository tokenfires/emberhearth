# Task 0103: Phone Number Filtering and Normalization

**Milestone:** M2 - iMessage Integration
**Unit:** 2.4 - Phone Number Filtering
**Phase:** 1
**Depends On:** 0100, 0101
**Estimated Effort:** 1-2 hours
**Complexity:** Small

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `src/Core/Models/ChatMessage.swift` — The `ChatMessage` model. You will filter based on the `phoneNumber` property.
2. `src/Core/MessageSender.swift` — Reference `isValidE164PhoneNumber()` for the E.164 format. Your normalization output must match this format.
3. `docs/research/imessage.md` — Phone numbers in chat.db handle table are in E.164 format.
4. `CLAUDE.md` — Project conventions.

> **Context Budget Note:** All context files are short. Read them in full.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing phone number filtering and normalization for EmberHearth, a macOS personal AI assistant. This component determines which phone numbers EmberHearth should respond to and normalizes various phone number formats to E.164.

## What You Are Building

A filter that:
1. Normalizes phone numbers from various formats to E.164 (+15551234567)
2. Stores a list of allowed phone numbers
3. Determines whether a given incoming message's phone number is on the allowed list
4. Is used by the message pipeline to decide whether to process an incoming message

## Files to Create

### 1. `src/Core/PhoneNumberFilter.swift`

```swift
import Foundation
import os.log

/// Filters incoming messages to only respond to configured phone numbers.
///
/// EmberHearth only responds to messages from phone numbers that the user has
/// explicitly added to the allowed list during onboarding. This prevents the
/// assistant from responding to unknown contacts.
///
/// Phone numbers are normalized to E.164 format before storage and comparison.
/// E.164 format: `+` followed by country code and subscriber number, with no
/// spaces, dashes, or parentheses. Example: `+15551234567`.
///
/// ## Usage
/// ```swift
/// let filter = PhoneNumberFilter()
/// filter.addAllowedNumber("(555) 123-4567")  // Stored as +15551234567
///
/// filter.shouldRespond(to: "+15551234567")     // true
/// filter.shouldRespond(to: "+15559999999")     // false
/// ```
final class PhoneNumberFilter {

    // MARK: - Properties

    /// The UserDefaults key for persisting allowed phone numbers.
    static let allowedNumbersKey = "com.emberhearth.phonenumberfilter.allowedNumbers"

    /// Logger for phone number filtering operations.
    private let logger = Logger(subsystem: "com.emberhearth.core", category: "PhoneNumberFilter")

    /// The set of allowed phone numbers in E.164 format.
    /// Loaded from and persisted to UserDefaults.
    private var allowedNumbers: Set<String> {
        didSet {
            // Persist to UserDefaults whenever the set changes
            let array = Array(allowedNumbers)
            UserDefaults.standard.set(array, forKey: Self.allowedNumbersKey)
            logger.info("Allowed numbers updated. Count: \(self.allowedNumbers.count)")
        }
    }

    // MARK: - Initialization

    /// Creates a new PhoneNumberFilter, loading any previously saved allowed numbers.
    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: Self.allowedNumbersKey) {
            self.allowedNumbers = Set(saved)
            // Do not use logger in init (self not fully initialized)
        } else {
            self.allowedNumbers = Set()
        }
    }

    // MARK: - Filtering

    /// Determines whether EmberHearth should respond to a message from this phone number.
    ///
    /// The phone number is normalized to E.164 before comparison. If normalization
    /// fails (invalid format), returns false.
    ///
    /// - Parameter phoneNumber: The phone number to check, in any supported format.
    /// - Returns: True if the number is in the allowed list.
    func shouldRespond(to phoneNumber: String) -> Bool {
        guard let normalized = Self.normalize(phoneNumber) else {
            logger.debug("Cannot normalize phone number, rejecting: \(phoneNumber, privacy: .private)")
            return false
        }
        let result = allowedNumbers.contains(normalized)
        logger.debug("shouldRespond(to: \(phoneNumber, privacy: .private)) = \(result)")
        return result
    }

    // MARK: - Managing Allowed Numbers

    /// Adds a phone number to the allowed list.
    ///
    /// The number is normalized to E.164 format before storing. If the number
    /// cannot be normalized, it is not added and the method returns false.
    ///
    /// - Parameter number: The phone number in any supported format.
    /// - Returns: True if the number was successfully added (or already present).
    @discardableResult
    func addAllowedNumber(_ number: String) -> Bool {
        guard let normalized = Self.normalize(number) else {
            logger.warning("Cannot add invalid phone number: \(number, privacy: .private)")
            return false
        }
        allowedNumbers.insert(normalized)
        logger.info("Added allowed number: \(normalized, privacy: .private)")
        return true
    }

    /// Removes a phone number from the allowed list.
    ///
    /// The number is normalized to E.164 format before removal.
    ///
    /// - Parameter number: The phone number in any supported format.
    /// - Returns: True if the number was found and removed.
    @discardableResult
    func removeAllowedNumber(_ number: String) -> Bool {
        guard let normalized = Self.normalize(number) else {
            logger.warning("Cannot remove invalid phone number: \(number, privacy: .private)")
            return false
        }
        let removed = allowedNumbers.remove(normalized) != nil
        if removed {
            logger.info("Removed allowed number: \(normalized, privacy: .private)")
        }
        return removed
    }

    /// Returns all currently allowed phone numbers in E.164 format.
    ///
    /// - Returns: An array of E.164 phone numbers.
    func getAllowedNumbers() -> [String] {
        return Array(allowedNumbers).sorted()
    }

    /// Removes all allowed phone numbers.
    func removeAllAllowedNumbers() {
        allowedNumbers.removeAll()
        logger.info("Removed all allowed numbers")
    }

    /// Returns the number of allowed phone numbers.
    var allowedNumberCount: Int {
        return allowedNumbers.count
    }

    // MARK: - Phone Number Normalization

    /// Normalizes a phone number to E.164 format.
    ///
    /// Handles the following input formats:
    /// - `+15551234567` — Already E.164, returned as-is
    /// - `15551234567` — Missing +, prepend +
    /// - `(555) 123-4567` — US formatted, strip formatting, prepend +1
    /// - `555-123-4567` — Dashed, strip dashes, prepend +1
    /// - `555.123.4567` — Dotted, strip dots, prepend +1
    /// - `5551234567` — 10 digits, assume US (+1)
    ///
    /// For non-US numbers, the + and country code must be provided.
    ///
    /// - Parameter phoneNumber: The phone number in any supported format.
    /// - Returns: The phone number in E.164 format, or nil if it cannot be normalized.
    static func normalize(_ phoneNumber: String) -> String? {
        // Strip all non-digit characters except the leading +
        var stripped = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        // Early return for empty strings
        guard !stripped.isEmpty else { return nil }

        // Preserve the leading + if present, then strip everything non-numeric
        let hasLeadingPlus = stripped.hasPrefix("+")
        stripped = stripped.filter { $0.isNumber }

        // Must have at least some digits
        guard !stripped.isEmpty else { return nil }

        // Reconstruct with leading +
        if hasLeadingPlus {
            // Already had +, just put it back
            let result = "+" + stripped
            return isValidE164(result) ? result : nil
        }

        // No leading +: determine what we have
        if stripped.count == 10 {
            // 10 digits: assume US number, prepend +1
            let result = "+1" + stripped
            return isValidE164(result) ? result : nil
        } else if stripped.count == 11 && stripped.hasPrefix("1") {
            // 11 digits starting with 1: US number with country code, prepend +
            let result = "+" + stripped
            return isValidE164(result) ? result : nil
        } else if stripped.count >= 7 && stripped.count <= 15 {
            // Could be an international number without +; prepend +
            // But only if it starts with a valid country code (1-9)
            if let first = stripped.first, first != "0" {
                let result = "+" + stripped
                return isValidE164(result) ? result : nil
            }
            return nil
        }

        return nil
    }

    /// Validates that a string is in correct E.164 format.
    ///
    /// - Parameter number: The number to validate.
    /// - Returns: True if it matches E.164: + followed by 1-15 digits, first digit 1-9.
    static func isValidE164(_ number: String) -> Bool {
        let pattern = #"^\+[1-9]\d{1,14}$"#
        return number.range(of: pattern, options: .regularExpression) != nil
    }
}
```

## Implementation Rules

1. **NEVER use Process() or /bin/bash or any shell execution.** Hard security rule per ADR-0004.
2. All Swift files use PascalCase naming.
3. All classes and methods must have documentation comments.
4. Use `os.Logger` for logging (subsystem: "com.emberhearth.core", category: "PhoneNumberFilter").
5. Phone numbers in logs use `privacy: .private`.
6. Store only normalized E.164 format numbers — never raw user input.
7. The normalization function is `static` so it can be used without an instance (useful for other components).

## Directory Structure

Create these files:
- `src/Core/PhoneNumberFilter.swift`
- `tests/Core/PhoneNumberFilterTests.swift`

## Unit Tests

Create `tests/Core/PhoneNumberFilterTests.swift`:

```swift
import XCTest
@testable import EmberHearth

final class PhoneNumberFilterTests: XCTestCase {

    private var filter: PhoneNumberFilter!

    override func setUp() {
        super.setUp()
        // Clear any persisted data before each test
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
        // Leading 0 after + is not valid E.164
        XCTAssertNil(PhoneNumberFilter.normalize("+05551234567"))
    }

    func testNormalizePlusOnly() {
        XCTAssertNil(PhoneNumberFilter.normalize("+"))
    }

    // MARK: - E.164 Validation Tests

    func testValidE164() {
        XCTAssertTrue(PhoneNumberFilter.isValidE164("+15551234567"))
        XCTAssertTrue(PhoneNumberFilter.isValidE164("+442071234567"))
        XCTAssertTrue(PhoneNumberFilter.isValidE164("+81312345678"))
    }

    func testInvalidE164() {
        XCTAssertFalse(PhoneNumberFilter.isValidE164("5551234567"))
        XCTAssertFalse(PhoneNumberFilter.isValidE164("+0551234567"))
        XCTAssertFalse(PhoneNumberFilter.isValidE164("+"))
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
        // Add in E.164 format
        filter.addAllowedNumber("+15551234567")
        // Check with various formats — all should match after normalization
        XCTAssertTrue(filter.shouldRespond(to: "+15551234567"))
        XCTAssertTrue(filter.shouldRespond(to: "15551234567"))
        XCTAssertTrue(filter.shouldRespond(to: "(555) 123-4567"))
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
        // Should still be 1 (set deduplication)
        XCTAssertEqual(filter.allowedNumberCount, 1)
    }

    func testAddDuplicateInDifferentFormats() {
        filter.addAllowedNumber("+15551234567")
        filter.addAllowedNumber("(555) 123-4567")
        // Same number, just different format — should deduplicate
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
        // Remove using a different format
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
        // Should be sorted
        XCTAssertEqual(numbers, ["+15551234567", "+15559876543"])
    }

    // MARK: - Persistence Tests

    func testNumbersPersistAcrossInstances() {
        filter.addAllowedNumber("+15551234567")
        filter.addAllowedNumber("+15559876543")

        // Create a new instance — it should load the persisted numbers
        let newFilter = PhoneNumberFilter()
        XCTAssertEqual(newFilter.allowedNumberCount, 2)
        XCTAssertTrue(newFilter.shouldRespond(to: "+15551234567"))
        XCTAssertTrue(newFilter.shouldRespond(to: "+15559876543"))
    }

    func testEmptyPersistence() {
        // Fresh filter with no persisted data
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
}
```

## Final Checks

Before finishing, verify:
1. All files compile without errors
2. All tests pass
3. There are no calls to Process(), /bin/bash, or any shell execution
4. Phone numbers are always stored in E.164 format
5. Normalization handles all specified input formats
6. Invalid inputs return nil from normalize()
7. Filtering works across different input formats (normalization before comparison)
8. Numbers persist in UserDefaults
9. All public methods have documentation comments
10. os.Logger is used with privacy: .private for phone numbers
```

---

## Acceptance Criteria

- [ ] `src/Core/PhoneNumberFilter.swift` exists with all specified methods
- [ ] `normalize()` handles: +15551234567, 15551234567, (555) 123-4567, 555-123-4567, 5551234567
- [ ] `normalize()` returns nil for: empty string, non-numeric, too short, too long, leading zero
- [ ] `shouldRespond(to:)` normalizes input before comparing to allowed list
- [ ] `addAllowedNumber()` normalizes before storing; returns false for invalid
- [ ] `removeAllowedNumber()` normalizes before comparing; works across formats
- [ ] Duplicate numbers (same number in different formats) are deduplicated
- [ ] Allowed numbers persist in UserDefaults across instances
- [ ] `getAllowedNumbers()` returns sorted E.164 numbers
- [ ] No calls to `Process()`, `/bin/bash`, or shell execution
- [ ] All unit tests pass (including persistence test with new instance)
- [ ] `os.Logger` used with `privacy: .private` for phone numbers

---

## Verification Commands

```bash
# Build the project
cd /Users/robault/Documents/GitHub/emberhearth
xcodebuild build -scheme EmberHearth -destination 'platform=macOS' 2>&1 | tail -20

# Run the PhoneNumberFilter tests
xcodebuild test -scheme EmberHearth -destination 'platform=macOS' -only-testing:EmberHearthTests/PhoneNumberFilterTests 2>&1 | tail -30

# Verify no shell execution
grep -rn "Process()" src/ || echo "PASS: No Process() calls found"
grep -rn "/bin/bash" src/ || echo "PASS: No /bin/bash references found"

# Verify E.164 normalization exists
grep -n "func normalize" src/Core/PhoneNumberFilter.swift && echo "PASS: normalize() found"
grep -n "func shouldRespond" src/Core/PhoneNumberFilter.swift && echo "PASS: shouldRespond() found"
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the EmberHearth PhoneNumberFilter implementation for correctness and completeness. Open these files:

@src/Core/PhoneNumberFilter.swift
@tests/Core/PhoneNumberFilterTests.swift

Check for these specific issues:

1. **Normalization Correctness:**
   - Does +15551234567 pass through unchanged?
   - Does (555) 123-4567 become +15551234567?
   - Does 555-123-4567 become +15551234567?
   - Does 5551234567 (10 digits) become +15551234567?
   - Does 15551234567 (11 digits starting with 1) become +15551234567?
   - Does it reject empty string, "abc", "+", "123" (too short)?
   - Does +442071234567 (UK) pass through correctly?
   - Is there a risk of false positives (normalizing invalid numbers to valid ones)?

2. **Format Comparison:**
   - If I add "+15551234567" and then check shouldRespond("(555) 123-4567"), does it return true?
   - If I add "(555) 123-4567" and then check shouldRespond("+15551234567"), does it return true?
   - If I add "555-123-4567" and remove "+15551234567", is it removed?

3. **Edge Cases:**
   - What happens with numbers that have extension markers (e.g., "+15551234567x123")?
   - What about numbers with unicode digits?
   - What about very long numbers (>15 digits)?
   - What about the number "+1"? (Valid E.164 technically, but not a real number)
   - What happens if UserDefaults contains corrupted data?

4. **Thread Safety:**
   - Is the allowedNumbers set accessed from multiple threads?
   - Could concurrent add/remove/shouldRespond calls cause a race condition?
   - Should the set be protected by a lock or actor?

5. **Testing:**
   - Are all normalization paths tested?
   - Is persistence tested with a fresh instance?
   - Are deduplication scenarios tested?

Report issues with severity: CRITICAL, IMPORTANT, MINOR.
```

---

## Commit Message

```
feat(m2): add phone number filtering and normalization
```

---

## Notes for Next Task

- `PhoneNumberFilter` is now available for the message pipeline. It should be used between the `MessageWatcher` output and the LLM processing stage.
- The `normalize()` function is static and can be reused by any component that needs phone number normalization.
- The filter currently uses UserDefaults for storage. Future tasks may move this to the encrypted SQLite memory database for better security.
- Currently assumes US (+1) for 10-digit numbers without a country code. International users who provide numbers without + will need to include their country code.
- Thread safety is not explicitly handled. For MVP, the filter is accessed from the watcher's serial queue. If multi-threaded access is needed later, wrap the set in an actor or add a lock.
