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
/// Manages phone number input, validation, normalization to E.164 format,
/// adding/removing numbers, and persistence via PhoneNumberFilter.
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

    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "PhoneConfig"
    )

    private let phoneNumberFilter: PhoneNumberFilter

    // MARK: - Initialization

    init(phoneNumberFilter: PhoneNumberFilter = PhoneNumberFilter()) {
        self.phoneNumberFilter = phoneNumberFilter
    }

    /// Loads previously saved phone numbers from PhoneNumberFilter.
    func loadExistingNumbers() {
        let existing = phoneNumberFilter.getAllowedNumbers()
        guard !existing.isEmpty, phoneEntries.isEmpty else { return }
        for number in existing {
            phoneEntries.append(PhoneEntry(rawInput: number, normalized: number))
        }
        Self.logger.info("Loaded \(existing.count) existing phone number(s)")
    }

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

        guard let normalized = normalizePhoneNumber(trimmed) else {
            errorMessage = "Please enter a valid phone number (e.g., 555-123-4567)."
            return
        }

        if phoneEntries.contains(where: { $0.normalized == normalized }) {
            errorMessage = "This number has already been added."
            return
        }

        let entry = PhoneEntry(rawInput: trimmed, normalized: normalized)
        phoneEntries.append(entry)
        phoneNumberText = ""
        errorMessage = nil

        Self.logger.info("Phone number added (count: \(self.phoneEntries.count))")
    }

    /// Removes a phone number at the specified offsets.
    func removePhoneNumber(at offsets: IndexSet) {
        phoneEntries.remove(atOffsets: offsets)
        Self.logger.info("Phone number removed (count: \(self.phoneEntries.count))")
    }

    /// Removes a specific phone entry.
    func removePhoneNumber(_ entry: PhoneEntry) {
        phoneEntries.removeAll { $0.id == entry.id }
        Self.logger.info("Phone number removed (count: \(self.phoneEntries.count))")
    }

    /// Saves all phone numbers to the PhoneNumberFilter for use by the message pipeline.
    func savePhoneNumbers() {
        phoneNumberFilter.removeAllAllowedNumbers()
        for entry in phoneEntries {
            phoneNumberFilter.addAllowedNumber(entry.normalized)
        }
        Self.logger.info("Saved \(self.phoneEntries.count) phone numbers via PhoneNumberFilter")
    }

    // MARK: - Phone Number Normalization

    /// Normalizes a phone number string to E.164 format.
    ///
    /// Delegates to `PhoneNumberFilter.normalize(_:)` for consistent behavior
    /// between onboarding and message filtering.
    func normalizePhoneNumber(_ input: String) -> String? {
        return PhoneNumberFilter.normalize(input)
    }

    /// Formats a normalized E.164 number for display.
    ///
    /// "+15551234567" becomes "+1 (555) 123-4567"
    func formatForDisplay(_ normalized: String) -> String {
        let digits = normalized.filter { $0.isNumber }

        if digits.count == 11 && digits.hasPrefix("1") {
            let areaCode = digits.dropFirst().prefix(3)
            let exchange = digits.dropFirst(4).prefix(3)
            let subscriber = digits.dropFirst(7)
            return "+1 (\(areaCode)) \(exchange)-\(subscriber)"
        }

        return normalized
    }
}

// MARK: - Phone Config View

/// The phone number configuration screen in the onboarding flow.
///
/// Allows users to enter one or more phone numbers that Ember should
/// listen to. At least one number is required to proceed.
///
/// Accessibility Compliance (Task 0604):
/// - [x] VoiceOver: Heading has .isHeader, phone field has label+hint, add/remove buttons labeled, error announced
/// - [x] Dynamic Type: All text uses semantic font styles; ScrollView for overflow
/// - [x] Keyboard: Back has .cancelAction, Continue has .defaultAction, field submits on Return
/// - [x] Color: Error shown via icon+text; green check icon on entries accompanied by "verified" in label
/// - [x] Reduce Motion: Remove animation respects reduceMotion
/// - [x] UI Testing: All interactive elements have accessibilityIdentifier
struct PhoneConfigView: View {

    // MARK: - Properties

    @StateObject private var viewModel = PhoneConfigViewModel()

    var onContinue: () -> Void
    var onBack: () -> Void

    /// Respect the user's Reduce Motion preference.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Tracks the previous phone entry count for VoiceOver add/remove announcements.
    @State private var previousEntryCount: Int = 0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.accentColor)
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

                    phoneNumberInput

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

                    if !viewModel.phoneEntries.isEmpty {
                        addedNumbersList
                    }

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

            navigationButtons
        }
        .onAppear {
            viewModel.loadExistingNumbers()
        }
        .onChange(of: viewModel.errorMessage) { newValue in
            if let error = newValue {
                announceToVoiceOver("Error: \(error)")
            }
        }
        .onChange(of: viewModel.phoneEntries.count) { newCount in
            if newCount > previousEntryCount {
                announceToVoiceOver("Phone number added. \(newCount) number\(newCount == 1 ? "" : "s") configured.")
            } else if newCount < previousEntryCount {
                announceToVoiceOver("Phone number removed. \(newCount) number\(newCount == 1 ? "" : "s") configured.")
            }
            previousEntryCount = newCount
        }
    }

    // MARK: - Phone Number Input

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
                        .accessibilityIdentifier("onboarding_phone_numberField")
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
                .accessibilityIdentifier("onboarding_phone_addButton")
            }
        }
    }

    // MARK: - Added Numbers List

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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Phone number \(viewModel.formatForDisplay(entry.normalized)), verified")

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.body)
                .accessibilityHidden(true)

            Button {
                withAnimation(reduceMotion ? nil : .default) {
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
            .accessibilityIdentifier("onboarding_phone_removeButton_\(entry.normalized)")
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

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack {
            Button("Back") {
                onBack()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Go back")
            .accessibilityHint("Returns to the agent email step")
            .accessibilityIdentifier("onboarding_phone_backButton")

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
            .accessibilityIdentifier("onboarding_phone_continueButton")
        }
        .padding(16)
    }
}
