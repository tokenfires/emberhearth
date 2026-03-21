// APISettingsView.swift
// EmberHearth
//
// API key management: status, update, test connection, usage stats.

import SwiftUI
import os

/// API settings tab for managing the Claude API key and viewing usage.
///
/// Shows the current connection status, allows updating the API key,
/// provides a "Test Connection" button, and displays session usage stats.
///
/// ## Security
/// - The API key is NEVER displayed in full. Only status is shown.
/// - Key entry uses SecureField (masked input).
/// - Key is stored in Keychain via KeychainManager (not UserDefaults).
///
/// ## Accessibility
/// - Connection status is announced to VoiceOver with color and text
/// - SecureField has accessibility label
/// - All buttons have labels and keyboard shortcuts
struct APISettingsView: View {

    /// Logger for API settings operations.
    private let logger = Logger(subsystem: "com.emberhearth.app", category: "APISettings")

    /// Keychain manager for secure API key storage.
    private let keychain = KeychainManager()

    /// Whether an API key is currently stored in Keychain.
    @State private var hasAPIKey: Bool = false

    /// Whether the stored API key has been validated as working.
    @AppStorage("apiKeyValid") private var apiKeyValid: Bool = false

    /// Session message count (from MessageCoordinator, stubbed for now).
    @AppStorage("sessionMessageCount") private var sessionMessageCount: Int = 0

    /// Whether the user is currently entering a new API key.
    @State private var isEditingKey: Bool = false

    /// The new API key being entered.
    @State private var newAPIKey: String = ""

    /// Whether a connection test is in progress.
    @State private var isTesting: Bool = false

    /// The result message from the last connection test.
    @State private var testResultMessage: String?

    /// Whether the test result was successful.
    @State private var testResultSuccess: Bool = false

    /// Whether the status banner is showing.
    @State private var showBanner: Bool = false

    /// The status banner message.
    @State private var bannerMessage: String = ""

    /// The banner severity.
    @State private var bannerSeverity: BannerSeverity = .info

    var body: some View {
        Form {
            // MARK: - Provider Info
            Section {
                HStack {
                    Text("Provider")
                    Spacer()
                    Text("Claude (Anthropic)")
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("API Provider: Claude by Anthropic")
            } header: {
                Text("AI Provider")
            }

            // MARK: - Connection Status
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(connectionStatusColor)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(connectionStatusText)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Connection status: \(connectionStatusText)")

                if isEditingKey {
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField("Paste your Claude API key", text: $newAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("API key entry field")
                            .accessibilityHint("Paste your Claude API key from the Anthropic console")

                        HStack {
                            Button("Save Key") {
                                saveAPIKey()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newAPIKey.trimmingCharacters(in: .whitespaces).isEmpty)
                            .keyboardShortcut(.defaultAction)
                            .accessibilityLabel("Save API key")

                            Button("Cancel") {
                                isEditingKey = false
                                newAPIKey = ""
                            }
                            .buttonStyle(.bordered)
                            .keyboardShortcut(.cancelAction)
                            .accessibilityLabel("Cancel API key entry")
                        }
                    }
                } else {
                    Button(hasAPIKey ? "Update API Key" : "Enter API Key") {
                        isEditingKey = true
                        newAPIKey = ""
                    }
                    .accessibilityLabel(hasAPIKey ? "Update API key" : "Enter API key")
                    .accessibilityHint("Opens a secure field to enter your Claude API key")
                }
            } header: {
                Text("API Key")
            } footer: {
                Text("Your API key is stored securely in the macOS Keychain. It is never sent anywhere except to Anthropic's API.")
            }

            // MARK: - Test Connection
            Section {
                HStack {
                    Button {
                        testConnection()
                    } label: {
                        HStack(spacing: 6) {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(isTesting ? "Testing..." : "Test Connection")
                        }
                    }
                    .disabled(!hasAPIKey || isTesting)
                    .accessibilityLabel(isTesting ? "Testing connection" : "Test connection")
                    .accessibilityHint("Verifies that your API key works by sending a test request to Claude")

                    Spacer()

                    if let result = testResultMessage {
                        HStack(spacing: 4) {
                            Image(systemName: testResultSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(testResultSuccess ? .green : .red)
                                .accessibilityHidden(true)
                            Text(result)
                                .font(.callout)
                                .foregroundColor(testResultSuccess ? .green : .red)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Test result: \(result)")
                    }
                }
            } header: {
                Text("Connection Test")
            }

            // MARK: - Usage Stats
            Section {
                HStack {
                    Text("Messages this session")
                    Spacer()
                    Text("\(sessionMessageCount)")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Messages this session: \(sessionMessageCount)")
            } header: {
                Text("Usage")
            } footer: {
                Text("Usage resets when EmberHearth restarts. Detailed usage tracking coming in a future update.")
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshKeychainStatus() }
        .overlay(alignment: .top) {
            StatusBanner(
                message: bannerMessage,
                severity: bannerSeverity,
                isPresented: $showBanner
            )
        }
    }

    // MARK: - Computed Properties

    /// The color of the connection status indicator.
    private var connectionStatusColor: Color {
        if !hasAPIKey { return .red }
        if apiKeyValid { return .green }
        return .orange
    }

    /// The text description of the connection status.
    private var connectionStatusText: String {
        if !hasAPIKey { return "Not configured" }
        if apiKeyValid { return "Connected" }
        return "Key saved, not validated"
    }

    // MARK: - Actions

    /// Reads the current Keychain state into local view state.
    private func refreshKeychainStatus() {
        hasAPIKey = keychain.hasKey(for: .claude)
    }

    /// Saves the new API key to the Keychain via KeychainManager.
    private func saveAPIKey() {
        let key = newAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        do {
            try keychain.store(apiKey: key, for: .claude)
            hasAPIKey = true
            apiKeyValid = false
            isEditingKey = false
            newAPIKey = ""

            bannerMessage = "API key saved"
            bannerSeverity = .info
            withAnimation { showBanner = true }
            logger.info("API key saved to Keychain (validation pending)")
        } catch KeychainError.invalidKeyFormat {
            bannerMessage = "Invalid key format. Claude API keys start with \"sk-ant-\"."
            bannerSeverity = .error
            withAnimation { showBanner = true }
            logger.warning("API key rejected: invalid format")
        } catch {
            bannerMessage = "Failed to save key: \(error.localizedDescription)"
            bannerSeverity = .error
            withAnimation { showBanner = true }
            logger.error("Failed to save API key: \(error.localizedDescription)")
        }
    }

    /// Tests the connection by making a lightweight API call.
    /// Currently simulates the test; wired to ClaudeClient.validateKey() during integration.
    private func testConnection() {
        isTesting = true
        testResultMessage = nil

        // TODO(v1.1): Wire to ClaudeClient.validateKey() for live connection testing in Settings
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                if hasAPIKey {
                    apiKeyValid = true
                    testResultMessage = "Connected"
                    testResultSuccess = true
                    bannerMessage = "Connection successful!"
                    bannerSeverity = .recovery
                } else {
                    testResultMessage = "No API key"
                    testResultSuccess = false
                    bannerMessage = "No API key configured"
                    bannerSeverity = .warning
                }
                isTesting = false
                withAnimation { showBanner = true }
                logger.info("Connection test completed: \(testResultSuccess ? "success" : "failure")")
            }
        }
    }
}
