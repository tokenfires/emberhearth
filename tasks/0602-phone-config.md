# Task 0602: Phone Number Configuration View

**Milestone:** M7 - Onboarding
**Unit:** 7.3 - Phone Number Configuration UI
**Phase:** 3
**Depends On:** 0601 (APIKeyEntryView integrated into OnboardingContainerView), 0103 (PhoneNumberFilter)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions, security boundaries, accessibility requirements
2. `docs/research/onboarding-ux.md` — Focus on Section 6: "First Message Success" (lines ~428-458) for the flow after phone config, and Section 9: "Minimum Setup Before First Value" (lines ~586-624) for what's needed before the first message test
3. `src/Views/Onboarding/OnboardingContainerView.swift` — Read entirely; understand the `OnboardingStep` enum and the `.phoneConfig` placeholder that this view will replace
4. `src/Core/PhoneNumberFilter.swift` — Read entirely (if it exists from task 0103); understand the `addAllowedNumber()` and `normalizePhoneNumber()` methods you will call. If it does not exist yet, you will need to create inline normalization logic.

> **Context Budget Note:** onboarding-ux.md is ~920 lines. Focus only on Section 6 (lines ~428-458) and Section 9 (lines ~586-624). Skip all other sections. PhoneNumberFilter.swift should be relatively short — read it all.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are creating the Phone Number Configuration view for EmberHearth's onboarding flow. This is Step 4 of the onboarding wizard — the screen where users specify which phone number(s) they'll text EmberHearth from. Ember will only respond to messages from these numbers.

IMPORTANT RULES (from CLAUDE.md):
- Product display name: "EmberHearth"
- Swift files use PascalCase (e.g., PhoneConfigView.swift)
- Security first: NEVER implement shell execution
- ALL UI must support VoiceOver, Dynamic Type, and keyboard navigation
- Follow Apple Human Interface Guidelines
- All source files go under src/, all test files go under tests/

PROJECT CONTEXT:
- This is a Swift Package Manager project with main target at path "src" and test target at path "tests"
- macOS 14.0+ deployment target
- No third-party dependencies — use only Apple frameworks
- PhoneNumberFilter from task 0103 should exist at src/Core/PhoneNumberFilter.swift
  - It has: `addAllowedNumber(_ number: String)`, `removeAllowedNumber(_ number: String)`, `isAllowed(_ number: String) -> Bool`, `allowedNumbers: [String]`
  - It normalizes numbers to E.164 format (e.g., "+15551234567")
  - If PhoneNumberFilter does not exist, create inline normalization (strip non-digits, prepend +1 for 10-digit US numbers)
- OnboardingContainerView (from task 0600) has a `.phoneConfig` step that currently shows a placeholder

WHAT YOU WILL CREATE:
1. src/Views/Onboarding/PhoneConfigView.swift — Phone number configuration UI with view model
2. tests/PhoneConfigViewModelTests.swift — Unit tests for the view model
3. Update src/Views/Onboarding/OnboardingContainerView.swift — Replace the `.phoneConfig` placeholder

STEP 1: Create src/Views/Onboarding/PhoneConfigView.swift

File: src/Views/Onboarding/PhoneConfigView.swift
```swift
// PhoneConfigView.swift
// EmberHearth
//
// Phone number configuration screen for onboarding. Allows users to add
// the phone number(s) they will text Ember from.

import SwiftUI
import os

// MARK: - Phone Entry

/// Represents a phone number that has been added by the user.
struct PhoneEntry: Identifiable, Equatable, Sendable {
    let id = UUID()
    /// The original text entered by the user.
    let rawInput: String
    /// The normalized E.164 format (e.g., "+15551234567").
    let normalized: String
}

// MARK: - View Model

/// View model for the phone number configuration screen.
///
/// Manages:
/// - Phone number input and validation
/// - Normalization to E.164 format
/// - Adding/removing numbers from the allowed list
/// - Persistence via PhoneNumberFilter
@MainActor
final class PhoneConfigViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The current text in the phone number input field.
    @Published var phoneNumberText: String = ""

    /// The list of phone numbers the user has added.
    @Published var phoneEntries: [PhoneEntry] = []

    /// Error message for invalid phone number input.
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// Logger for phone config events. NEVER logs actual phone numbers.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "PhoneConfig"
    )

    // MARK: - Computed Properties

    /// Whether the user can proceed (at least one phone number added).
    var canContinue: Bool {
        !phoneEntries.isEmpty
    }

    /// Whether the Add Number button should be enabled.
    var canAddNumber: Bool {
        !phoneNumberText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Phone Number Management

    /// Attempts to add the current phone number text to the list.
    ///
    /// Validates the input, normalizes it to E.164 format, checks for
    /// duplicates, and adds it to the list.
    func addPhoneNumber() {
        let trimmed = phoneNumberText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a phone number."
            return
        }

        // Normalize the phone number
        guard let normalized = normalizePhoneNumber(trimmed) else {
            errorMessage = "Please enter a valid phone number (e.g., 555-123-4567)."
            return
        }

        // Check for duplicates
        if phoneEntries.contains(where: { $0.normalized == normalized }) {
            errorMessage = "This number has already been added."
            return
        }

        // Add to list
        let entry = PhoneEntry(rawInput: trimmed, normalized: normalized)
        phoneEntries.append(entry)
        phoneNumberText = ""
        errorMessage = nil

        Self.logger.info("Phone number added (count: \(self.phoneEntries.count))")
    }

    /// Removes a phone number at the specified offsets.
    ///
    /// - Parameter offsets: The index set of entries to remove.
    func removePhoneNumber(at offsets: IndexSet) {
        phoneEntries.remove(atOffsets: offsets)
        Self.logger.info("Phone number removed (count: \(self.phoneEntries.count))")
    }

    /// Removes a specific phone entry.
    ///
    /// - Parameter entry: The entry to remove.
    func removePhoneNumber(_ entry: PhoneEntry) {
        phoneEntries.removeAll { $0.id == entry.id }
        Self.logger.info("Phone number removed (count: \(self.phoneEntries.count))")
    }

    /// Saves all phone numbers to the PhoneNumberFilter for use by the message pipeline.
    ///
    /// Call this when the user taps Continue to persist the allowed numbers.
    func savePhoneNumbers() {
        // The PhoneNumberFilter from task 0103 handles persistence.
        // If it is not yet available, store in UserDefaults as a fallback.
        let numbers = phoneEntries.map { $0.normalized }
        UserDefaults.standard.set(numbers, forKey: "allowedPhoneNumbers")
        Self.logger.info("Saved \(numbers.count) phone numbers")

        // TODO: When PhoneNumberFilter is available, use:
        // for number in numbers {
        //     PhoneNumberFilter.shared.addAllowedNumber(number)
        // }
    }

    // MARK: - Phone Number Normalization

    /// Normalizes a phone number string to E.164 format.
    ///
    /// Handles common US phone number formats:
    /// - "555-123-4567" → "+15551234567"
    /// - "(555) 123-4567" → "+15551234567"
    /// - "5551234567" → "+15551234567"
    /// - "+15551234567" → "+15551234567" (already normalized)
    /// - "1-555-123-4567" → "+15551234567"
    ///
    /// - Parameter input: The raw phone number string.
    /// - Returns: The normalized E.164 format, or nil if invalid.
    func normalizePhoneNumber(_ input: String) -> String? {
        // Strip everything except digits and leading +
        let hasPlus = input.hasPrefix("+")
        let digitsOnly = input.filter { $0.isNumber }

        guard !digitsOnly.isEmpty else { return nil }

        // Handle different digit counts
        switch digitsOnly.count {
        case 10:
            // US number without country code: 5551234567 → +15551234567
            return "+1\(digitsOnly)"
        case 11:
            // US number with country code: 15551234567 → +15551234567
            if digitsOnly.hasPrefix("1") {
                return "+\(digitsOnly)"
            }
            return nil
        case 12...15:
            // International number
            if hasPlus {
                return "+\(digitsOnly)"
            }
            // Assume the leading digits are country code
            return "+\(digitsOnly)"
        default:
            // Too short or too long
            if digitsOnly.count < 10 {
                return nil
            }
            // Try with + prefix for longer numbers
            return "+\(digitsOnly)"
        }
    }

    /// Formats a normalized E.164 number for display.
    ///
    /// "+15551234567" → "+1 (555) 123-4567"
    ///
    /// - Parameter normalized: The E.164 phone number.
    /// - Returns: A formatted display string, or the original if formatting fails.
    func formatForDisplay(_ normalized: String) -> String {
        let digits = normalized.filter { $0.isNumber }

        if digits.count == 11 && digits.hasPrefix("1") {
            let areaCode = digits.dropFirst().prefix(3)
            let exchange = digits.dropFirst(4).prefix(3)
            let subscriber = digits.dropFirst(7)
            return "+1 (\(areaCode)) \(exchange)-\(subscriber)"
        }

        // For non-US numbers, just return as-is
        return normalized
    }
}

// MARK: - Phone Config View

/// The phone number configuration screen in the onboarding flow.
///
/// Allows users to enter one or more phone numbers that Ember should
/// listen to. At least one number is required to proceed.
///
/// UI elements:
/// - "Who should Ember listen to?" heading
/// - Explanation text
/// - Phone number text field with US formatting hint
/// - "Add Number" button
/// - List of added numbers with delete option
/// - Continue button (disabled until at least one number added)
///
/// Accessibility:
/// - VoiceOver labels on all interactive elements
/// - Remove buttons announce the number being removed
/// - Dynamic Type support throughout
/// - Keyboard navigation for all actions
struct PhoneConfigView: View {

    // MARK: - Properties

    /// View model managing phone number state.
    @StateObject private var viewModel = PhoneConfigViewModel()

    /// Callback when the user taps Continue (numbers saved).
    var onContinue: () -> Void

    /// Callback when the user taps Back.
    var onBack: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Heading
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.accent)
                            .accessibilityHidden(true)

                        Text("Who should Ember listen to?")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        Text("Enter the phone number(s) you'll text Ember from. Ember will only respond to messages from these numbers.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                    // Phone number input
                    phoneNumberInput

                    // Error message
                    if let error = viewModel.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.subheadline)
                                .accessibilityHidden(true)
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Error: \(error)")
                    }

                    // Added numbers list
                    if !viewModel.phoneEntries.isEmpty {
                        addedNumbersList
                    }

                    // Helper text
                    if viewModel.phoneEntries.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text("You need at least one phone number to continue. You can add more numbers later in Settings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }

            Divider()

            // Navigation buttons
            navigationButtons
        }
    }

    // MARK: - Phone Number Input

    /// The text field and Add Number button.
    private var phoneNumberInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phone Number")
                .font(.headline)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("+1")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    TextField("(555) 123-4567", text: $viewModel.phoneNumberText)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .accessibilityLabel("Phone number")
                        .accessibilityHint("Enter the phone number you'll text Ember from. Use format like 555-123-4567.")
                        .accessibilityIdentifier("phoneNumberTextField")
                        .onSubmit {
                            viewModel.addPhoneNumber()
                        }
                }

                Button {
                    viewModel.addPhoneNumber()
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canAddNumber)
                .accessibilityLabel("Add phone number")
                .accessibilityHint("Adds the entered phone number to the list of numbers Ember will respond to")
                .accessibilityIdentifier("addPhoneNumberButton")
            }
        }
    }

    // MARK: - Added Numbers List

    /// The list of phone numbers that have been added.
    private var addedNumbersList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Numbers")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            ForEach(viewModel.phoneEntries) { entry in
                phoneEntryRow(entry)
            }
        }
    }

    /// A single row displaying an added phone number with a remove button.
    private func phoneEntryRow(_ entry: PhoneEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "phone.fill")
                .foregroundStyle(.green)
                .font(.body)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.formatForDisplay(entry.normalized))
                    .font(.body)
                    .fontWeight(.medium)

                if entry.rawInput != entry.normalized {
                    Text(entry.normalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.body)
                .accessibilityHidden(true)

            Button {
                withAnimation {
                    viewModel.removePhoneNumber(entry)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove phone number \(viewModel.formatForDisplay(entry.normalized))")
            .accessibilityHint("Removes this phone number from the list")
            .accessibilityIdentifier("removePhoneNumber_\(entry.normalized)")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.green.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Phone number \(viewModel.formatForDisplay(entry.normalized)), verified")
    }

    // MARK: - Navigation

    /// Back and Continue buttons at the bottom.
    private var navigationButtons: some View {
        HStack {
            Button("Back") {
                onBack()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Go back")
            .accessibilityHint("Returns to the API key setup step")

            Spacer()

            Button("Continue") {
                viewModel.savePhoneNumbers()
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canContinue)
            .accessibilityLabel("Continue to next step")
            .accessibilityHint(
                viewModel.canContinue
                ? "Saves your phone numbers and proceeds to test Ember"
                : "Add at least one phone number to continue"
            )
            .accessibilityIdentifier("phoneConfigContinueButton")
        }
        .padding(16)
    }
}
```

STEP 2: Update OnboardingContainerView.swift to use PhoneConfigView

Open `src/Views/Onboarding/OnboardingContainerView.swift` and replace the `.phoneConfig` placeholder case in the `switch currentStep` block.

Find this code:
```swift
                case .phoneConfig:
                    // Placeholder — will be implemented in task 0602
                    placeholderView(title: "Phone Number Setup", step: .phoneConfig)
```

Replace it with:
```swift
                case .phoneConfig:
                    PhoneConfigView(
                        onContinue: { advanceToStep(.test) },
                        onBack: { goBackToStep(.apiKey) }
                    )
```

STEP 3: Create tests/PhoneConfigViewModelTests.swift

File: tests/PhoneConfigViewModelTests.swift
```swift
// PhoneConfigViewModelTests.swift
// EmberHearth
//
// Unit tests for PhoneConfigViewModel.

import XCTest
@testable import EmberHearth

@MainActor
final class PhoneConfigViewModelTests: XCTestCase {

    private var viewModel: PhoneConfigViewModel!

    override func setUp() {
        super.setUp()
        viewModel = PhoneConfigViewModel()
    }

    override func tearDown() {
        viewModel = nil
        // Clean up any saved phone numbers from tests
        UserDefaults.standard.removeObject(forKey: "allowedPhoneNumbers")
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

    // MARK: - Display Formatting Tests

    func testFormatUSNumber() {
        let formatted = viewModel.formatForDisplay("+15551234567")
        XCTAssertEqual(formatted, "+1 (555) 123-4567")
    }

    func testFormatNonUSNumber() {
        let formatted = viewModel.formatForDisplay("+442071234567")
        // Non-US numbers are returned as-is
        XCTAssertEqual(formatted, "+442071234567")
    }

    // MARK: - Save Tests

    func testSavePhoneNumbers() {
        viewModel.phoneNumberText = "5551234567"
        viewModel.addPhoneNumber()
        viewModel.phoneNumberText = "5559876543"
        viewModel.addPhoneNumber()

        viewModel.savePhoneNumbers()

        let saved = UserDefaults.standard.stringArray(forKey: "allowedPhoneNumbers")
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.count, 2)
        XCTAssertTrue(saved?.contains("+15551234567") == true)
        XCTAssertTrue(saved?.contains("+15559876543") == true)
    }

    // MARK: - PhoneEntry Tests

    func testPhoneEntryEquality() {
        let entry1 = PhoneEntry(rawInput: "555-123-4567", normalized: "+15551234567")
        let entry2 = PhoneEntry(rawInput: "555-123-4567", normalized: "+15551234567")
        // PhoneEntry uses UUID for id, so two entries with same data are NOT equal
        XCTAssertNotEqual(entry1, entry2, "Entries with different UUIDs should not be equal")
    }
}
```

STEP 4: Verify the build

After creating/updating all files, run from the project root (/Users/robault/Documents/GitHub/emberhearth):

```bash
swift build
swift test
```

Both must succeed. If the build fails, debug the issue. Common problems:
- If PhoneNumberFilter does not exist yet (task 0103 not complete), the savePhoneNumbers() method uses UserDefaults as a fallback. This is fine — the TODO comment marks where to integrate PhoneNumberFilter later.
- TextField: Available in SwiftUI on macOS. Import SwiftUI.
- onSubmit: Available in macOS 12.0+.
- The PhoneEntry struct uses UUID for its id. Two entries with the same raw/normalized values will have different IDs — this is intentional so each entry is uniquely identifiable in the list.

IMPORTANT NOTES:
- Do NOT modify Package.swift.
- Do NOT modify any existing files except OnboardingContainerView.swift (and only the one `.phoneConfig` placeholder case).
- Phone numbers are NOT considered sensitive like API keys — they can be displayed in the UI and stored in UserDefaults. However, do NOT log the actual phone numbers (log counts instead).
- The "+1" country code prefix is shown as a visual hint next to the text field, but the normalization logic handles both with and without country code.
- At least one phone number must be added before the Continue button is enabled.
- The "Back" button returns to the API Key step.
```

---

## Acceptance Criteria

- [ ] `src/Views/Onboarding/PhoneConfigView.swift` exists and compiles
- [ ] `tests/PhoneConfigViewModelTests.swift` exists and all tests pass
- [ ] `OnboardingContainerView.swift` updated to use `PhoneConfigView` instead of placeholder
- [ ] `PhoneEntry` struct has `rawInput` and `normalized` properties
- [ ] Phone number normalization handles: 10-digit, 11-digit, formatted, dashed, with +, international
- [ ] Invalid numbers (too short, empty, non-numeric) are rejected with user-friendly error messages
- [ ] Duplicate numbers (same normalized form) are rejected
- [ ] At least one number required to continue (button disabled otherwise)
- [ ] Multiple numbers can be added (work + personal phone)
- [ ] Numbers can be removed via a remove button
- [ ] Normalized E.164 format shown after entry (e.g., "+15551234567")
- [ ] Display formatting shows user-friendly format (e.g., "+1 (555) 123-4567")
- [ ] Green checkmark shown next to valid numbers
- [ ] Phone icon (SF Symbol: phone.fill) shown next to each number
- [ ] Numbers persisted via UserDefaults (fallback) or PhoneNumberFilter (when available)
- [ ] VoiceOver: Text field has label "Phone number" with format hint
- [ ] VoiceOver: Remove buttons announce the number being removed
- [ ] VoiceOver: Error messages are displayed visually and accessible
- [ ] All text uses semantic font styles (Dynamic Type support)
- [ ] Keyboard: Enter/Return in text field triggers Add Number
- [ ] Keyboard: Enter/Return for Continue, Escape to go back
- [ ] `swift build` succeeds
- [ ] `swift test` succeeds

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify files exist
test -f src/Views/Onboarding/PhoneConfigView.swift && echo "PhoneConfigView.swift exists" || echo "MISSING: PhoneConfigView.swift"
test -f tests/PhoneConfigViewModelTests.swift && echo "Tests exist" || echo "MISSING: Tests"

# Verify no shell execution
grep -rn "Process()" src/Views/Onboarding/PhoneConfigView.swift && echo "WARNING: Found Process()" || echo "OK: No Process()"
grep -rn "/bin/bash" src/Views/Onboarding/PhoneConfigView.swift && echo "WARNING: Found /bin/bash" || echo "OK: No /bin/bash"

# Verify accessibility labels exist
grep -c "accessibilityLabel" src/Views/Onboarding/PhoneConfigView.swift

# Verify the container was updated
grep "PhoneConfigView" src/Views/Onboarding/OnboardingContainerView.swift && echo "OK: Container updated"

# Verify E.164 normalization
grep "normalizePhoneNumber" src/Views/Onboarding/PhoneConfigView.swift && echo "OK: Normalization exists"

# Build
swift build 2>&1

# Run tests
swift test --filter PhoneConfigViewModelTests 2>&1
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the Phone Number Configuration view created in task 0602 for EmberHearth. Open these files:

@src/Views/Onboarding/PhoneConfigView.swift
@src/Views/Onboarding/OnboardingContainerView.swift
@tests/PhoneConfigViewModelTests.swift

Also reference:
@CLAUDE.md
@docs/research/onboarding-ux.md (briefly, for flow context)

Check for these specific issues:

1. PHONE NUMBER NORMALIZATION:
   - Verify "5551234567" → "+15551234567"
   - Verify "(555) 123-4567" → "+15551234567"
   - Verify "555-123-4567" → "+15551234567"
   - Verify "+15551234567" → "+15551234567" (no change)
   - Verify "1-555-123-4567" → "+15551234567"
   - Verify too-short numbers are rejected
   - Verify empty input is rejected
   - Verify letters-only input is rejected
   - Are there any edge cases that could crash (force unwraps, out-of-bounds)?

2. DUPLICATE DETECTION:
   - Verify duplicate detection compares NORMALIZED forms, not raw input
   - "555-123-4567" and "(555) 123-4567" should be detected as duplicates
   - Verify the error message mentions "already added"

3. ACCESSIBILITY:
   - Phone number text field has accessibilityLabel and accessibilityHint
   - "Add Number" button has descriptive label
   - Remove buttons include the phone number in the accessibilityLabel
   - Error messages are accessible
   - All text uses semantic font styles (no fixed sizes)
   - Tab order is logical: text field → add button → entries → continue

4. UI QUALITY:
   - At least one number required to continue (button disabled)
   - Green checkmark next to valid numbers
   - Phone icon (phone.fill) next to each number
   - "+1" country code shown as a visual hint
   - Numbers can be removed (minus/remove button)
   - Text field clears after successful add

5. DATA PERSISTENCE:
   - Numbers are saved to UserDefaults (or PhoneNumberFilter if available)
   - Save is called when Continue is tapped
   - Numbers are stored in normalized E.164 format

6. INTEGRATION:
   - OnboardingContainerView updated correctly
   - onContinue advances to .test
   - onBack returns to .apiKey

7. BUILD VERIFICATION:
   - Run `swift build` and verify success
   - Run `swift test --filter PhoneConfigViewModelTests` and verify all tests pass
   - Run `swift test` and verify no existing tests are broken

Report issues with exact file paths and line numbers. Severity: CRITICAL, IMPORTANT, MINOR.
```

---

## Commit Message

```
feat(m7): add phone number configuration view
```

---

## Notes for Next Task

- Phone numbers are saved to `UserDefaults` key `"allowedPhoneNumbers"` as an array of E.164 strings. When `PhoneNumberFilter` (task 0103) is available, update `savePhoneNumbers()` to use it instead.
- The `OnboardingContainerView` now has real implementations for steps 1-4 (Welcome, Permissions, API Key, Phone Config). Only step 5 (Test) still shows a placeholder.
- The `onContinue` callback from `PhoneConfigView` advances to `.test` in the container.
- Task 0603 (FirstMessageTestView) will need to read the configured phone numbers to display them in the test instructions. It should read from `UserDefaults` key `"allowedPhoneNumbers"`.
- The `PhoneConfigViewModel.formatForDisplay()` method can be reused in task 0603 if needed.
