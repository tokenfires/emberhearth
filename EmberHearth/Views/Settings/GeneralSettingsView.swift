// GeneralSettingsView.swift
// EmberHearth
//
// General preferences: launch at login, phone numbers, session timeout.

import SwiftUI
import os

/// General settings tab with launch behavior, phone numbers, and session timeout.
///
/// Settings changes take effect immediately — there is no "Apply" or "Save" button.
/// Uses `LaunchAtLoginManager` for system-level login item registration and
/// `PhoneNumberFilter` for authorized phone number management.
///
/// ## Accessibility
/// - All form controls have VoiceOver labels
/// - Toggle descriptions explain what each setting does
/// - Phone number list is navigable with VoiceOver
/// - Dynamic Type adjusts all text sizes
struct GeneralSettingsView: View {

    /// Logger for settings operations.
    private let logger = Logger(subsystem: "com.emberhearth.app", category: "GeneralSettings")

    /// Launch at login state, read from the system via LaunchAtLoginManager.
    @State private var launchAtLogin: Bool = LaunchAtLoginManager.shared.isEnabled

    /// Session timeout in hours (how long before a conversation session resets).
    @AppStorage("sessionTimeoutHours") private var sessionTimeoutHours: Double = 4.0

    /// Phone number filter — single source of truth for authorized numbers.
    /// Shared with onboarding and the message pipeline.
    private let phoneNumberFilter = PhoneNumberFilter()

    /// Cached list of authorized phone numbers, refreshed after mutations.
    @State private var authorizedPhoneNumbers: [String] = []

    /// New phone number being entered by the user.
    @State private var newPhoneNumber: String = ""

    /// Error message for invalid phone number entry.
    @State private var phoneNumberError: String?

    /// Whether the status banner is showing.
    @State private var showBanner: Bool = false

    /// The status banner message.
    @State private var bannerMessage: String = ""

    var body: some View {
        Form {
            // MARK: - Launch Behavior
            Section {
                Toggle("Launch EmberHearth at login", isOn: $launchAtLogin)
                    .accessibilityLabel("Launch at login")
                    .accessibilityHint("When enabled, EmberHearth starts automatically when you log into your Mac")
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLoginManager.shared.setEnabled(newValue)
                        logger.info("Launch at login changed to \(newValue)")
                    }
            } header: {
                Text("Startup")
            }

            // MARK: - Phone Numbers
            Section {
                if authorizedPhoneNumbers.isEmpty {
                    Text("No phone numbers configured. Add a number to start chatting with Ember.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                ForEach(authorizedPhoneNumbers, id: \.self) { number in
                    HStack {
                        Text(number)
                            .font(.body.monospaced())
                            .accessibilityLabel("Phone number \(number)")

                        Spacer()

                        Button {
                            removePhoneNumber(number)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(number)")
                    }
                }

                HStack {
                    TextField("Phone number (e.g., +15551234567)", text: $newPhoneNumber)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("New phone number")
                        .accessibilityHint("Enter a phone number in international format starting with plus sign")
                        .onSubmit {
                            addPhoneNumber()
                        }

                    Button("Add") {
                        addPhoneNumber()
                    }
                    .disabled(newPhoneNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Add phone number")
                    .keyboardShortcut(.defaultAction)
                }

                if let error = phoneNumberError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .accessibilityLabel("Error: \(error)")
                }
            } header: {
                Text("Phone Numbers")
            } footer: {
                Text("Ember only responds to messages from these numbers. Use international format (e.g., +15551234567).")
            }

            // MARK: - Session Timeout
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Session timeout:")
                        Spacer()
                        Text("\(Int(sessionTimeoutHours)) hour\(sessionTimeoutHours == 1.0 ? "" : "s")")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Session timeout: \(Int(sessionTimeoutHours)) hours")

                    Slider(value: $sessionTimeoutHours, in: 1...8, step: 1) {
                        Text("Session timeout")
                    }
                    .accessibilityLabel("Session timeout slider")
                    .accessibilityValue("\(Int(sessionTimeoutHours)) hours")
                    .accessibilityHint("Adjust how long before Ember starts a new conversation session")
                }
            } header: {
                Text("Conversations")
            } footer: {
                Text("After this period of inactivity, Ember will start a new conversation session. Your memories are always preserved.")
            }

            // MARK: - Response Style (Future, Disabled)
            Section {
                HStack {
                    Text("Response style")
                    Spacer()
                    Text("Default")
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Response style: Default. This setting will be available in a future update.")
            } header: {
                Text("Personality")
            } footer: {
                Text("More personality options coming in a future update.")
            }
        }
        .formStyle(.grouped)
        .onAppear { reloadPhoneNumbers() }
        .overlay(alignment: .top) {
            StatusBanner(
                message: bannerMessage,
                severity: .recovery,
                isPresented: $showBanner
            )
        }
    }

    // MARK: - Phone Number Management

    /// Reloads the cached phone number list from PhoneNumberFilter.
    private func reloadPhoneNumbers() {
        authorizedPhoneNumbers = phoneNumberFilter.getAllowedNumbers()
    }

    /// Validates and adds a new phone number to the authorized list.
    private func addPhoneNumber() {
        let raw = newPhoneNumber.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }

        guard let normalized = PhoneNumberFilter.normalize(raw) else {
            phoneNumberError = "Please enter a valid phone number (e.g., 555-123-4567 or +15551234567)"
            return
        }

        guard !authorizedPhoneNumbers.contains(normalized) else {
            phoneNumberError = "This number is already added."
            return
        }

        phoneNumberFilter.addAllowedNumber(normalized)
        reloadPhoneNumbers()

        newPhoneNumber = ""
        phoneNumberError = nil
        bannerMessage = "Phone number added"
        withAnimation { showBanner = true }
        logger.info("Phone number added (count: \(authorizedPhoneNumbers.count))")
    }

    /// Removes a phone number from the authorized list.
    private func removePhoneNumber(_ number: String) {
        phoneNumberFilter.removeAllowedNumber(number)
        reloadPhoneNumbers()
        bannerMessage = "Phone number removed"
        withAnimation { showBanner = true }
        logger.info("Phone number removed (count: \(authorizedPhoneNumbers.count))")
    }
}
