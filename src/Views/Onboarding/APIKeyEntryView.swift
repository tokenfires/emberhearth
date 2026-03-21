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
            let isValid = try await testAPIKey(trimmedKey)

            if isValid {
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
/// Accessibility Compliance (Task 0604):
/// - [x] VoiceOver: Heading has .isHeader, key icon hidden, SecureField has label+hint, validation results announced
/// - [x] Dynamic Type: All text uses semantic font styles, ScrollView prevents overflow at large sizes
/// - [x] Keyboard: Back has .cancelAction, Validate triggered by Return in field, Continue has .defaultAction
/// - [x] Color: Validation status shown via icon+text+color; security note uses .secondary system color
/// - [x] Reduce Motion: Auto-advance delay shortened when reduceMotion is true
/// - [x] UI Testing: All interactive elements have accessibilityIdentifier
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
                            .foregroundStyle(Color.accentColor)
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
        .onChange(of: viewModel.validationState) { newValue in
            if case .valid = newValue {
                announceToVoiceOver("API key validated successfully. Continuing to next step.")
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
        .accessibilityIdentifier("onboarding_apiKey_explanationSection")
    }

    /// A single bullet point in the explanation section.
    private func explanationBullet(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
                .foregroundStyle(Color.accentColor)
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
        .accessibilityIdentifier("onboarding_apiKey_getKeyLink")
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
                    .accessibilityIdentifier("onboarding_apiKey_keyField")
                    .onSubmit {
                        if viewModel.canValidate {
                            Task {
                                await viewModel.validateAPIKey()
                            }
                        }
                    }
                    .onChange(of: viewModel.apiKeyText) { _ in
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
                .accessibilityIdentifier("onboarding_apiKey_validateButton")
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
            .accessibilityIdentifier("onboarding_apiKey_validationSuccess")

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
            .accessibilityIdentifier("onboarding_apiKey_validationError")
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
            .accessibilityIdentifier("onboarding_apiKey_backButton")

            Spacer()

            Button("Skip for Now") {
                onContinue()
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Skip API key setup")
            .accessibilityHint("Continues without an API key. EmberHearth will have limited functionality. You can set this up later in Settings.")
            .accessibilityIdentifier("onboarding_apiKey_skipButton")

            if viewModel.validationState.isValid {
                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Continue to next step")
                .accessibilityHint("Proceeds to phone number configuration")
                .accessibilityIdentifier("onboarding_apiKey_continueButton")
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
