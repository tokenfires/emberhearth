# Task 0601: API Key Entry View

**Milestone:** M7 - Onboarding
**Unit:** 7.2 - API Key Entry UI
**Phase:** 3
**Depends On:** 0600 (OnboardingContainerView, OnboardingStep enum), 0200 (KeychainManager)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions, security boundaries (Keychain for secrets, NEVER log API keys), accessibility requirements
2. `docs/research/onboarding-ux.md` — Focus on Section 4: "LLM Provider Setup" (lines ~143-248) for the API key entry UI wireframes, the "What's an API key?" expandable section, and the step-by-step instructions for users without a key
3. `src/Security/KeychainManager.swift` — Read entirely; understand the `store(apiKey:for:)` and `hasKey(for:)` methods you will call
4. `src/Security/LLMProvider.swift` — Read entirely; understand the `LLMProvider` enum (.claude, .openai) and the `apiKeyPrefix` property
5. `src/Views/Onboarding/OnboardingContainerView.swift` — Focus on the `OnboardingStep` enum and the `.apiKey` case placeholder that this view will replace

> **Context Budget Note:** onboarding-ux.md is ~920 lines. Focus only on Section 4 (lines ~143-248) for the API key entry screen designs. Skip the LLM provider selection screen (we are implementing Claude-only for MVP). KeychainManager.swift is ~380 lines — read it all since it's the primary dependency.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are creating the API Key Entry view for EmberHearth's onboarding flow. This is Step 3 of the onboarding wizard — the screen where users enter their Anthropic API key so EmberHearth can communicate with Claude.

IMPORTANT RULES (from CLAUDE.md):
- Product display name: "EmberHearth"
- Swift files use PascalCase (e.g., APIKeyEntryView.swift)
- Security first: NEVER log, print, or display API keys in plaintext
- NEVER implement shell execution. No Process(), no /bin/bash, no NSTask.
- ALL UI must support VoiceOver, Dynamic Type, and keyboard navigation
- Follow Apple Human Interface Guidelines
- All source files go under src/, all test files go under tests/

PROJECT CONTEXT:
- This is a Swift Package Manager project with main target at path "src" and test target at path "tests"
- macOS 14.0+ deployment target
- No third-party dependencies — use only Apple frameworks
- KeychainManager is at src/Security/KeychainManager.swift with methods:
  - `store(apiKey: String, for: LLMProvider) throws` — stores key in Keychain
  - `retrieve(for: LLMProvider) throws -> String?` — retrieves key
  - `hasKey(for: LLMProvider) -> Bool` — checks if key exists
- LLMProvider enum is at src/Security/LLMProvider.swift:
  - `.claude` has `apiKeyPrefix` = "sk-ant-"
  - `.openai` has `apiKeyPrefix` = "sk-"
- OnboardingContainerView (from task 0600) has an `.apiKey` step that currently shows a placeholder

WHAT YOU WILL CREATE:
1. src/Views/Onboarding/APIKeyEntryView.swift — The API key entry UI
2. tests/APIKeyEntryViewModelTests.swift — Unit tests for the view model logic
3. Update src/Views/Onboarding/OnboardingContainerView.swift — Replace the `.apiKey` placeholder with APIKeyEntryView

STEP 1: Create src/Views/Onboarding/APIKeyEntryView.swift

This file contains both the view and its view model. The view model handles validation logic and Keychain storage.

File: src/Views/Onboarding/APIKeyEntryView.swift
```swift
// APIKeyEntryView.swift
// EmberHearth
//
// API key entry screen for onboarding. Allows users to enter, validate,
// and securely store their Anthropic API key.

import SwiftUI
import os

// MARK: - Validation State

/// The possible states of API key validation.
enum APIKeyValidationState: Equatable {
    /// No validation has been attempted yet.
    case idle
    /// Validation is in progress (checking format and making test API call).
    case validating
    /// The API key is valid and has been stored in Keychain.
    case valid
    /// The API key failed validation with a specific error message.
    case invalid(message: String)

    /// Whether the validation is currently in progress.
    var isValidating: Bool {
        if case .validating = self { return true }
        return false
    }

    /// Whether the key has been validated successfully.
    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

// MARK: - View Model

/// View model for the API key entry screen.
///
/// Handles:
/// - API key format validation (must start with "sk-ant-")
/// - Live API call validation (sends a minimal test request)
/// - Secure storage in Keychain via KeychainManager
/// - Error state management
///
/// Security: The API key is NEVER logged, printed, or stored outside of
/// SecureField and Keychain. The validationState error messages describe
/// the problem without revealing the key.
@MainActor
final class APIKeyEntryViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The current API key text entered by the user.
    /// This is bound to a SecureField — the value is never displayed in plaintext.
    @Published var apiKeyText: String = ""

    /// The current validation state.
    @Published var validationState: APIKeyValidationState = .idle

    /// Whether the "What's the difference?" section is expanded.
    @Published var isExplanationExpanded: Bool = false

    // MARK: - Dependencies

    /// The Keychain manager used to store the validated API key.
    private let keychainManager: KeychainManager

    /// Logger for API key operations. NEVER logs the key value.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "APIKeyEntry"
    )

    // MARK: - Initialization

    /// Creates a new APIKeyEntryViewModel.
    ///
    /// - Parameter keychainManager: The Keychain manager to use. Defaults to a new instance
    ///   with the production service name. Pass a custom instance for testing.
    init(keychainManager: KeychainManager = KeychainManager()) {
        self.keychainManager = keychainManager
    }

    // MARK: - Validation

    /// Validates the entered API key.
    ///
    /// Validation is a two-step process:
    /// 1. Format check: Must start with "sk-ant-" and be at least 20 characters
    /// 2. Live test: Makes a minimal API call to verify the key works
    ///
    /// On success, the key is stored in Keychain.
    func validateAPIKey() async {
        let trimmedKey = apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Step 1: Format validation
        guard !trimmedKey.isEmpty else {
            validationState = .invalid(message: "Please enter your API key.")
            return
        }

        guard trimmedKey.hasPrefix(LLMProvider.claude.apiKeyPrefix) else {
            validationState = .invalid(
                message: "Invalid key format. Claude API keys start with \"sk-ant-\". Make sure you're using an API key, not a subscription login."
            )
            return
        }

        guard trimmedKey.count >= 20 else {
            validationState = .invalid(message: "This key looks too short. Please check that you copied the full key.")
            return
        }

        // Step 2: Live validation
        validationState = .validating
        Self.logger.info("Starting API key validation (format check passed)")

        do {
            // Make a minimal API call to test the key
            let isValid = try await testAPIKey(trimmedKey)

            if isValid {
                // Store in Keychain
                try keychainManager.store(apiKey: trimmedKey, for: .claude)
                validationState = .valid
                Self.logger.info("API key validated and stored successfully")
            } else {
                validationState = .invalid(message: "Key was rejected by Anthropic. Please check that your key is correct and your account is active.")
                Self.logger.warning("API key was rejected by the API")
            }
        } catch let error as KeychainError {
            validationState = .invalid(message: "Failed to save the key securely: \(error.localizedDescription)")
            Self.logger.error("Keychain storage failed during validation")
        } catch {
            // Distinguish network errors from API errors
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                validationState = .invalid(
                    message: "Network error — check your internet connection and try again."
                )
                Self.logger.error("Network error during API key validation: \(nsError.code)")
            } else {
                validationState = .invalid(
                    message: "Validation failed: \(error.localizedDescription)"
                )
                Self.logger.error("Unexpected error during API key validation")
            }
        }
    }

    /// Makes a minimal API call to test whether the API key is valid.
    ///
    /// Sends a simple "Hello" message with max_tokens: 10 to minimize cost.
    /// Returns true if the API responds successfully.
    ///
    /// - Parameter apiKey: The API key to test. NEVER logged.
    /// - Returns: true if the API accepted the key.
    /// - Throws: Network or URL errors.
    private func testAPIKey(_ apiKey: String) async throws -> Bool {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 10,
            "messages": [
                ["role": "user", "content": "Hello"]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        switch httpResponse.statusCode {
        case 200:
            return true
        case 401:
            validationState = .invalid(message: "Key was rejected by Anthropic. Please verify your API key is correct.")
            return false
        case 403:
            validationState = .invalid(message: "Your API key doesn't have permission to access this service. Check your Anthropic account.")
            return false
        case 429:
            // Rate limited but key is valid
            return true
        default:
            validationState = .invalid(message: "Anthropic returned an unexpected response (code \(httpResponse.statusCode)). Please try again.")
            return false
        }
    }

    /// Resets the validation state so the user can try again.
    func resetValidation() {
        validationState = .idle
    }

    /// Whether the Validate button should be enabled.
    var canValidate: Bool {
        !apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !validationState.isValidating
        && !validationState.isValid
    }
}

// MARK: - API Key Entry View

/// The API key entry screen in the onboarding flow.
///
/// UI elements:
/// - "Connect to Claude" heading
/// - Explanation of what an API key is
/// - Expandable "What's the difference?" section (API key vs subscription)
/// - Link to console.anthropic.com
/// - SecureField for masked key entry
/// - Validate button with validation states (idle, validating, valid, invalid)
/// - Success animation on valid key
///
/// Accessibility:
/// - SecureField has descriptive VoiceOver label
/// - Validation errors are announced to VoiceOver
/// - All interactive elements are keyboard accessible
/// - Dynamic Type support throughout
struct APIKeyEntryView: View {

    // MARK: - Properties

    /// View model managing validation state and Keychain storage.
    @StateObject private var viewModel: APIKeyEntryViewModel

    /// Callback invoked when the API key is successfully validated and stored.
    var onContinue: () -> Void

    /// Callback invoked when the user wants to go back.
    var onBack: () -> Void

    /// Tracks whether the success animation has completed (for auto-advance).
    @State private var shouldAutoAdvance: Bool = false

    /// Respect the user's Reduce Motion preference.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Initialization

    /// Creates an APIKeyEntryView.
    ///
    /// - Parameters:
    ///   - keychainManager: Optional custom KeychainManager for testing. Uses default if nil.
    ///   - onContinue: Callback when the key is validated and stored.
    ///   - onBack: Callback to go back to the previous step.
    init(
        keychainManager: KeychainManager? = nil,
        onContinue: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: APIKeyEntryViewModel(
            keychainManager: keychainManager ?? KeychainManager()
        ))
        self.onContinue = onContinue
        self.onBack = onBack
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Heading
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.accent)
                            .accessibilityHidden(true)

                        Text("Connect to Claude")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .accessibilityAddTraits(.isHeader)

                        Text("EmberHearth uses Anthropic's Claude AI to understand and respond to your messages. You'll need an API key (not a subscription).")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                    // Expandable explanation
                    explanationSection

                    // Link to get an API key
                    getKeyLink

                    // API key entry field
                    apiKeyField

                    // Validation status
                    validationStatus

                    // Security reassurance
                    securityNote
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }

            Divider()

            // Navigation buttons
            navigationButtons
        }
        .onChange(of: viewModel.validationState) { oldValue, newValue in
            if case .valid = newValue {
                announceToVoiceOver("API key validated successfully. Continuing to next step.")
                // Auto-advance after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.5 : 1.0)) {
                    onContinue()
                }
            } else if case .invalid(let message) = newValue {
                announceToVoiceOver("Validation error: \(message)")
            }
        }
    }

    // MARK: - Expandable Explanation

    /// An expandable section explaining the difference between API keys and subscriptions.
    private var explanationSection: some View {
        DisclosureGroup(
            isExpanded: $viewModel.isExplanationExpanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                explanationBullet(
                    text: "An API key lets EmberHearth talk to Claude directly"
                )
                explanationBullet(
                    text: "It's different from a claude.ai subscription"
                )
                explanationBullet(
                    text: "You pay per message (typically $1-5/month for normal use)"
                )
            }
            .padding(.top, 8)
        } label: {
            Text("What's the difference between an API key and a subscription?")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.05))
        )
        .accessibilityIdentifier("apiKeyExplanationSection")
    }

    /// A single bullet point in the explanation section.
    private func explanationBullet(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
                .foregroundStyle(.accent)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Get Key Link

    /// A button that opens the Anthropic console in the user's browser.
    private var getKeyLink: some View {
        Button {
            if let url = URL(string: "https://console.anthropic.com/settings/keys") {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack {
                Image(systemName: "safari")
                    .accessibilityHidden(true)
                Text("Get an API key at console.anthropic.com")
                    .font(.subheadline)
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.link)
        .accessibilityLabel("Get an API key at console.anthropic.com")
        .accessibilityHint("Opens the Anthropic console website in your browser where you can create an API key")
        .accessibilityIdentifier("getAPIKeyLink")
    }

    // MARK: - API Key Field

    /// The secure text field for API key entry and the Validate button.
    private var apiKeyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Key")
                .font(.headline)

            HStack(spacing: 12) {
                SecureField("Paste your API key here", text: $viewModel.apiKeyText)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .disabled(viewModel.validationState.isValid)
                    .accessibilityLabel("API key entry field")
                    .accessibilityHint("Paste your Anthropic API key. The key will be hidden for security.")
                    .accessibilityIdentifier("apiKeySecureField")
                    .onChange(of: viewModel.apiKeyText) { _, _ in
                        // Reset validation when the user changes the key
                        if viewModel.validationState != .idle && !viewModel.validationState.isValidating {
                            viewModel.resetValidation()
                        }
                    }

                Button {
                    Task {
                        await viewModel.validateAPIKey()
                    }
                } label: {
                    if viewModel.validationState.isValidating {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 70)
                    } else {
                        Text("Validate")
                            .frame(width: 70)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canValidate)
                .accessibilityLabel(
                    viewModel.validationState.isValidating
                    ? "Validating API key"
                    : "Validate API key"
                )
                .accessibilityHint("Tests your API key by making a small request to Anthropic")
                .accessibilityIdentifier("validateAPIKeyButton")
            }
        }
    }

    // MARK: - Validation Status

    /// Shows the current validation result (success, error, or nothing).
    @ViewBuilder
    private var validationStatus: some View {
        switch viewModel.validationState {
        case .idle, .validating:
            EmptyView()

        case .valid:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text("API key is valid! Continuing...")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.08))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("API key validated successfully")
            .accessibilityIdentifier("validationSuccess")

        case .invalid(let message):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.08))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Validation error: \(message)")
            .accessibilityIdentifier("validationError")
        }
    }

    // MARK: - Security Note

    /// A small security reassurance note below the key entry field.
    private var securityNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Your API key is stored securely in your Mac's Keychain and never sent anywhere except to Anthropic.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your API key is stored securely in your Mac's Keychain and never sent anywhere except to Anthropic.")
    }

    // MARK: - Navigation Buttons

    /// Back and Continue/Skip buttons at the bottom.
    private var navigationButtons: some View {
        HStack {
            Button("Back") {
                onBack()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Go back")
            .accessibilityHint("Returns to the permissions step")

            Spacer()

            Button("Skip for Now") {
                onContinue()
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Skip API key setup")
            .accessibilityHint("Continues without an API key. EmberHearth will have limited functionality. You can set this up later in Settings.")
            .accessibilityIdentifier("skipAPIKeyButton")

            if viewModel.validationState.isValid {
                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Continue to next step")
                .accessibilityHint("Proceeds to phone number configuration")
            }
        }
        .padding(16)
    }

    // MARK: - VoiceOver

    /// Posts a VoiceOver announcement.
    private func announceToVoiceOver(_ message: String) {
        NSAccessibility.post(
            element: NSApp.mainWindow as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high]
        )
    }
}
```

STEP 2: Update OnboardingContainerView.swift to use APIKeyEntryView

Open `src/Views/Onboarding/OnboardingContainerView.swift` and replace the `.apiKey` placeholder case in the `switch currentStep` block.

Find this code in the body:
```swift
                case .apiKey:
                    // Placeholder — will be implemented in task 0601
                    placeholderView(title: "API Key Setup", step: .apiKey)
```

Replace it with:
```swift
                case .apiKey:
                    APIKeyEntryView(
                        onContinue: { advanceToStep(.phoneConfig) },
                        onBack: { goBackToStep(.permissions) }
                    )
```

STEP 3: Create tests/APIKeyEntryViewModelTests.swift

Tests for the view model logic. Note: The live API validation test is excluded from CI since it requires a real API key.

File: tests/APIKeyEntryViewModelTests.swift
```swift
// APIKeyEntryViewModelTests.swift
// EmberHearth
//
// Unit tests for APIKeyEntryViewModel validation logic.

import XCTest
@testable import EmberHearth

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
        viewModel.apiKeyText = "sk-ant-api03-some-test-key-value"
        XCTAssertTrue(viewModel.canValidate, "Should be able to validate with non-empty key text")
    }

    func testCanValidateIsFalseWhenAlreadyValid() async {
        // Simulate a valid state
        viewModel.validationState = .valid
        viewModel.apiKeyText = "sk-ant-api03-some-test-key-value"
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
```

STEP 4: Verify the build

After creating/updating all files, run from the project root (/Users/robault/Documents/GitHub/emberhearth):

```bash
swift build
swift test
```

Both must succeed. If the build fails, debug the issue. Common problems:
- SecureField: Available in SwiftUI on macOS. Import SwiftUI.
- URLSession.shared.data(for:): Available in macOS 12.0+. Ensure deployment target is macOS 13.0 or higher.
- @MainActor on tests: XCTestCase methods marked @MainActor must use the async test pattern. If the compiler complains, remove @MainActor from individual test methods and keep it only on the class.
- NSWorkspace: Available via AppKit. In macOS SwiftUI, AppKit is implicitly available.
- The OnboardingContainerView update: Make sure you only change the `.apiKey` case, nothing else.

IMPORTANT NOTES:
- Do NOT modify Package.swift.
- Do NOT modify KeychainManager.swift, LLMProvider.swift, or any other existing files except OnboardingContainerView.swift (and only the one placeholder case).
- The API key MUST use SecureField — NEVER a plain TextField. The key should never be visible in plaintext in the UI.
- NEVER log, print, or include the API key value in error messages.
- The "Skip for Now" button lets users proceed without an API key. EmberHearth will run in limited mode — this is handled by the LLM integration layer, not this view.
- The live validation test (testAPIKey) makes a real API call. In CI, you may want to skip this test. For local testing, it validates that a correctly-formatted key reaches the API.
- The auto-advance after validation uses a 1-second delay (0.5s with Reduce Motion) to let the user see the success state before moving on.
```

---

## Acceptance Criteria

- [ ] `src/Views/Onboarding/APIKeyEntryView.swift` exists and compiles
- [ ] `tests/APIKeyEntryViewModelTests.swift` exists and all tests pass
- [ ] `OnboardingContainerView.swift` updated to use `APIKeyEntryView` instead of placeholder
- [ ] `APIKeyValidationState` enum has 4 cases: `idle`, `validating`, `valid`, `invalid(message:)`
- [ ] SecureField is used for API key entry (NEVER plain TextField)
- [ ] API key is NEVER logged, printed, or displayed in plaintext
- [ ] Format validation: rejects empty, wrong prefix, too short
- [ ] Format validation error messages are user-friendly (mention "sk-ant-", explain API key vs subscription)
- [ ] Live validation: makes a minimal API call (`max_tokens: 10`)
- [ ] Live validation handles: 200 (success), 401 (invalid key), 403 (no permission), 429 (rate limited = valid), network errors
- [ ] On successful validation, key is stored in Keychain via `KeychainManager.store(apiKey:for:)`
- [ ] Success state shows green checkmark with "API key is valid!"
- [ ] Error state shows red X with specific error message
- [ ] "What's the difference?" expandable section explains API key vs subscription
- [ ] Link to `console.anthropic.com` opens in browser
- [ ] "Skip for Now" button allows proceeding without a key
- [ ] Auto-advance to next step 1 second after successful validation
- [ ] Reduce Motion: auto-advance delay is shorter (0.5s)
- [ ] VoiceOver: SecureField has label "API key entry field"
- [ ] VoiceOver: Validation errors are announced
- [ ] VoiceOver: Success is announced
- [ ] All text uses semantic font styles (Dynamic Type support)
- [ ] Keyboard: Enter/Return triggers Validate, Escape goes back
- [ ] Security note mentions Keychain storage
- [ ] `swift build` succeeds
- [ ] `swift test` succeeds

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify files exist
test -f src/Views/Onboarding/APIKeyEntryView.swift && echo "APIKeyEntryView.swift exists" || echo "MISSING: APIKeyEntryView.swift"
test -f tests/APIKeyEntryViewModelTests.swift && echo "Tests exist" || echo "MISSING: Tests"

# Verify SecureField is used (not TextField for the key)
grep "SecureField" src/Views/Onboarding/APIKeyEntryView.swift && echo "OK: SecureField used"
grep -n "TextField.*apiKey\|TextField.*key" src/Views/Onboarding/APIKeyEntryView.swift && echo "WARNING: Found TextField for key — should be SecureField" || echo "OK: No plain TextField for key"

# Verify API key is never logged
grep -n "print.*apiKey\|logger.*apiKey\|print.*key" src/Views/Onboarding/APIKeyEntryView.swift | grep -v "logger\|Logger\|comment" && echo "WARNING: API key may be logged" || echo "OK: No key logging found"

# Verify Keychain storage
grep "keychainManager.store" src/Views/Onboarding/APIKeyEntryView.swift && echo "OK: Keychain storage used"

# Verify accessibility labels
grep -c "accessibilityLabel" src/Views/Onboarding/APIKeyEntryView.swift

# Verify the OnboardingContainerView was updated
grep "APIKeyEntryView" src/Views/Onboarding/OnboardingContainerView.swift && echo "OK: Container updated"

# Build the project
swift build 2>&1

# Run tests
swift test --filter APIKeyEntryViewModelTests 2>&1
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the API Key Entry view created in task 0601 for EmberHearth. Open these files:

@src/Views/Onboarding/APIKeyEntryView.swift
@src/Views/Onboarding/OnboardingContainerView.swift
@tests/APIKeyEntryViewModelTests.swift
@src/Security/KeychainManager.swift
@src/Security/LLMProvider.swift

Also reference:
@CLAUDE.md
@docs/research/onboarding-ux.md (focus on Section 4: LLM Provider Setup)

Check for these specific issues:

1. SECURITY (Critical):
   - Verify SecureField is used, NOT TextField, for the API key input
   - Search the entire file for any print(), NSLog(), Logger, or string interpolation that could leak the API key VALUE. The logger should only log events ("validation started", "validation failed") — NEVER the key itself.
   - Verify the API key is stored via KeychainManager.store(apiKey:for:), not UserDefaults or any other storage
   - Verify the test API call sends the key ONLY in the x-api-key header, not in the URL or body
   - Verify error messages do NOT include the API key (e.g., "Invalid key: sk-ant-..." would be a security issue)
   - Verify NO calls to Process(), /bin/bash, or shell execution

2. VALIDATION LOGIC:
   - Verify format check: empty string rejected, wrong prefix rejected, too-short rejected
   - Verify the expected prefix is "sk-ant-" (matching LLMProvider.claude.apiKeyPrefix)
   - Verify the live test API call uses max_tokens: 10 (minimal cost)
   - Verify HTTP 200 = valid, 401 = invalid key, 403 = no permission, 429 = valid (rate limited)
   - Verify network errors are distinguished from API errors
   - Verify the timeout is set (15 seconds is reasonable)

3. ACCESSIBILITY:
   - SecureField has accessibilityLabel "API key entry field"
   - Validate button has accessibilityLabel and accessibilityHint
   - Error messages are announced to VoiceOver via announcement notification
   - Success is announced to VoiceOver
   - "Skip for Now" has accessibilityHint explaining the consequence
   - DisclosureGroup (expandable section) is accessible
   - All text uses semantic font styles (no fixed sizes)
   - Tab order is logical

4. UX FLOW:
   - Verify the "What's the difference?" section explains API key vs subscription
   - Verify the console.anthropic.com link opens in the browser
   - Verify the security note mentions Keychain
   - Verify auto-advance happens after successful validation (with delay)
   - Verify Reduce Motion preference shortens the delay
   - Verify "Skip for Now" allows proceeding without a key
   - Verify resetting validation when the user changes the key text

5. INTEGRATION:
   - Verify OnboardingContainerView was updated to replace the placeholder with APIKeyEntryView
   - Verify the onContinue callback advances to .phoneConfig
   - Verify the onBack callback goes to .permissions

6. BUILD VERIFICATION:
   - Run `swift build` and verify success
   - Run `swift test --filter APIKeyEntryViewModelTests` and verify all tests pass
   - Run `swift test` and verify no existing tests are broken

Report any issues with exact file paths and line numbers. Severity: CRITICAL (must fix), IMPORTANT (should fix), MINOR (nice to have).
```

---

## Commit Message

```
feat(m7): add API key entry view with validation
```

---

## Notes for Next Task

- The `APIKeyEntryView` stores the validated key in Keychain via `KeychainManager.store(apiKey:for: .claude)`. Task 0602 does NOT need to interact with the API key.
- The `OnboardingContainerView` now has a real implementation for the `.apiKey` step. The `.phoneConfig` step still shows a placeholder that task 0602 will replace.
- The `onContinue` callback from `APIKeyEntryView` advances to `.phoneConfig` in the container.
- The "Skip for Now" button also calls `onContinue`, so the onboarding flow continues regardless. The LLM integration layer (task 0201) handles the case where no API key is configured.
- The `APIKeyEntryViewModel` is a good pattern reference: `@StateObject` in the view, `@MainActor`, published state, async validation. Task 0602's `PhoneConfigView` should follow a similar pattern.
