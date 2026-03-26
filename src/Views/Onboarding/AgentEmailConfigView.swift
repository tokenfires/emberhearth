// AgentEmailConfigView.swift
// EmberHearth
//
// Agent iCloud email configuration screen for onboarding. Directs users to
// create a dedicated iCloud account for their AI agent and captures the
// email address used to receive iMessages.

import SwiftUI
import os

// MARK: - View Model

/// View model for the agent email configuration screen.
///
/// Manages email input, basic format validation, and persistence via UserDefaults.
/// The agent email is the iCloud address that the user will text from their phone,
/// giving Ember a distinct iMessage identity separate from the user's own account.
@MainActor
final class AgentEmailConfigViewModel: ObservableObject {

    // MARK: - Constants

    /// UserDefaults key for the agent email address.
    static let agentEmailKey = "com.emberhearth.agentEmail"

    // MARK: - Published Properties

    /// The current email text entered by the user.
    @Published var emailText: String = ""

    /// Error message for invalid email input.
    @Published var errorMessage: String?

    /// Whether a valid email has been saved.
    @Published var isSaved: Bool = false

    // MARK: - Private Properties

    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "AgentEmailConfig"
    )

    private let defaults: UserDefaults

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Loads a previously saved agent email, if any.
    func loadExistingEmail() {
        guard let saved = defaults.string(forKey: Self.agentEmailKey), !saved.isEmpty else {
            return
        }
        emailText = saved
        isSaved = true
        Self.logger.info("Loaded existing agent email")
    }

    // MARK: - Computed Properties

    /// Whether the Continue button should be enabled.
    var canContinue: Bool {
        isSaved
    }

    /// Whether the Save button should be enabled.
    var canSave: Bool {
        !emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaved
    }

    // MARK: - Validation & Storage

    /// Validates and saves the entered email address.
    func saveEmail() {
        let trimmed = emailText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmed.isEmpty else {
            errorMessage = "Please enter an email address."
            return
        }

        guard isValidEmailFormat(trimmed) else {
            errorMessage = "Please enter a valid email address (e.g., ember@icloud.com)."
            return
        }

        defaults.set(trimmed, forKey: Self.agentEmailKey)
        emailText = trimmed
        isSaved = true
        errorMessage = nil
        Self.logger.info("Agent email saved")
    }

    /// Resets saved state so the user can edit.
    func editEmail() {
        isSaved = false
    }

    /// Basic email format validation.
    ///
    /// Checks for presence of `@` with content on both sides and a dot in the domain.
    /// This is intentionally lenient — we can't verify iMessage registration anyway.
    private func isValidEmailFormat(_ email: String) -> Bool {
        let parts = email.split(separator: "@", maxSplits: 1)
        guard parts.count == 2,
              !parts[0].isEmpty,
              parts[1].contains("."),
              parts[1].count >= 3 else {
            return false
        }
        return true
    }

    /// Retrieves the stored agent email, if any.
    static func storedEmail(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: agentEmailKey)
    }
}

// MARK: - Agent Email Config View

/// The agent iCloud email configuration screen in the onboarding flow.
///
/// Explains why a dedicated iCloud account is needed and captures the email
/// address the user creates. This address becomes Ember's iMessage identity,
/// enabling clean message separation (no self-chat loops).
///
/// Accessibility Compliance:
/// - [x] VoiceOver: Heading has .isHeader, field has label+hint, status announced
/// - [x] Dynamic Type: All text uses semantic font styles; ScrollView for overflow
/// - [x] Keyboard: Back has .cancelAction, Continue has .defaultAction, field submits on Return
/// - [x] Color: Status shown via icon+text+color; info note uses .secondary
/// - [x] Reduce Motion: No custom animations
/// - [x] UI Testing: All interactive elements have accessibilityIdentifier
struct AgentEmailConfigView: View {

    // MARK: - Properties

    @StateObject private var viewModel: AgentEmailConfigViewModel

    var onContinue: () -> Void
    var onBack: () -> Void

    // MARK: - Initialization

    init(
        defaults: UserDefaults? = nil,
        onContinue: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: AgentEmailConfigViewModel(
            defaults: defaults ?? .standard
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
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)

                        Text("Create Ember's iMessage Identity")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        Text("Ember needs its own iCloud email address so you can text it like a real contact — no awkward self-messaging.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                    // Instructions
                    instructionsSection

                    // Create account link
                    createAccountLink

                    // Email entry
                    emailField

                    // Saved status
                    savedStatus

                    // Info note
                    infoNote
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }

            Divider()

            navigationButtons
        }
        .onAppear {
            viewModel.loadExistingEmail()
        }
        .onChange(of: viewModel.errorMessage) { newValue in
            if let error = newValue {
                announceToVoiceOver("Error: \(error)")
            }
        }
        .onChange(of: viewModel.isSaved) { newValue in
            if newValue {
                announceToVoiceOver("Email address saved. You can continue to the next step.")
            }
        }
    }

    // MARK: - Instructions

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            instructionStep(number: "1", text: "Create a free iCloud email address for your agent (e.g., my-ember@icloud.com)")
            instructionStep(number: "2", text: "On your Mac, open Messages → Settings → iMessage and add the new address under \"You can be reached at\"")
            instructionStep(number: "3", text: "Enter the address below")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.05))
        )
        .accessibilityIdentifier("onboarding_agentEmail_instructionsSection")
    }

    private func instructionStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20, alignment: .center)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(text)")
    }

    // MARK: - Create Account Link

    private var createAccountLink: some View {
        Button {
            if let url = URL(string: "https://appleid.apple.com/account") {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack {
                Image(systemName: "safari")
                    .accessibilityHidden(true)
                Text("Create a free Apple ID at appleid.apple.com")
                    .font(.subheadline)
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.link)
        .accessibilityLabel("Create a free Apple ID at appleid.apple.com")
        .accessibilityHint("Opens the Apple ID creation page in your browser")
        .accessibilityIdentifier("onboarding_agentEmail_createAccountLink")
    }

    // MARK: - Email Field

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agent Email Address")
                .font(.headline)

            HStack(spacing: 12) {
                TextField("ember@icloud.com", text: $viewModel.emailText)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .textContentType(.emailAddress)
                    .disabled(viewModel.isSaved)
                    .accessibilityLabel("Agent email address")
                    .accessibilityHint("Enter the iCloud email address you created for Ember")
                    .accessibilityIdentifier("onboarding_agentEmail_emailField")
                    .onSubmit {
                        if viewModel.canSave {
                            viewModel.saveEmail()
                        }
                    }
                    .onChange(of: viewModel.emailText) { _ in
                        if viewModel.isSaved {
                            // Don't reset if saved — user must tap Edit
                        } else {
                            viewModel.errorMessage = nil
                        }
                    }

                if viewModel.isSaved {
                    Button("Edit") {
                        viewModel.editEmail()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Edit email address")
                    .accessibilityHint("Allows you to change the saved email address")
                    .accessibilityIdentifier("onboarding_agentEmail_editButton")
                } else {
                    Button("Save") {
                        viewModel.saveEmail()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canSave)
                    .accessibilityLabel("Save email address")
                    .accessibilityHint("Validates and saves the email address")
                    .accessibilityIdentifier("onboarding_agentEmail_saveButton")
                }
            }

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
        }
    }

    // MARK: - Saved Status

    @ViewBuilder
    private var savedStatus: some View {
        if viewModel.isSaved {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text("Email address saved")
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
            .accessibilityLabel("Email address saved successfully")
            .accessibilityIdentifier("onboarding_agentEmail_savedStatus")
        }
    }

    // MARK: - Info Note

    private var infoNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("This email becomes Ember's identity in Messages. When you text this address from your phone, your Mac receives it as a separate conversation — no echo loops or self-chat confusion.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack {
            Button("Back") {
                onBack()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Go back")
            .accessibilityHint("Returns to the API key step")
            .accessibilityIdentifier("onboarding_agentEmail_backButton")

            Spacer()

            Button("Continue") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canContinue)
            .accessibilityLabel("Continue to next step")
            .accessibilityHint(
                viewModel.canContinue
                ? "Proceeds to phone number configuration"
                : "Save an email address to continue"
            )
            .accessibilityIdentifier("onboarding_agentEmail_continueButton")
        }
        .padding(16)
    }

    // MARK: - VoiceOver

    private func announceToVoiceOver(_ message: String) {
        NSAccessibility.post(
            element: NSApp.mainWindow as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high]
        )
    }
}
