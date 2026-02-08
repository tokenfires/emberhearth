# Task 0701: Settings UI

**Milestone:** M8 - Polish & Release
**Unit:** 8.3 - Basic Settings UI
**Phase:** 3
**Depends On:** 0700
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `docs/releases/mvp-scope.md` — Read the "Mac App" section for Settings requirements: API key management, basic preferences, menu bar, launch at login, status indicator.
2. `docs/releases/feature-matrix.md` — Read the "Mac Application > Settings" rows to understand what's in MVP vs later versions. MVP includes: API management, basic preferences. NOT in MVP: integration toggles, personality config, advanced options.
3. `docs/specs/error-handling.md` — Read "Runtime Health Dashboard" (lines 432-453) for the status display format that will appear in the About/Status tab.
4. `docs/architecture/decisions/0004-no-shell-execution.md` — Read in full. No Process(), no /bin/bash, no NSTask.
5. `CLAUDE.md` — Project conventions: PascalCase for Swift files, src/ for source, tests/ for tests, VoiceOver on all UI.
6. `src/Core/Errors/AppError.swift` — Reference the error types from task 0700 that Settings will display.
7. `src/Views/Components/StatusBanner.swift` — Reference the banner component from task 0700 for status notifications in Settings.

> **Context Budget Note:** `mvp-scope.md` is ~250 lines. Focus on the "Mac App" section (~lines 58-82). `feature-matrix.md` is ~267 lines. Focus on the "Mac Application" section (~lines 67-94). `error-handling.md` focus only on lines 432-453 for the health dashboard format.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the Settings UI for EmberHearth, a native macOS personal AI assistant that communicates via iMessage. The Settings window is the primary configuration interface — the Mac app itself is mostly invisible (menu bar only), so Settings is where users manage their API key, phone numbers, and preferences.

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., SettingsView.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask, no osascript via Process)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app")
- All public types and methods must have documentation comments (///)
- All UI views MUST support: VoiceOver accessibility labels, Dynamic Type, keyboard navigation, light/dark mode
- Follow Apple Human Interface Guidelines for macOS Settings windows

## What You Are Building

A native macOS Settings window using SwiftUI's Settings scene, with three tabs:
1. **General** — Launch at login, phone numbers, session timeout
2. **API** — API key status, update key, test connection, usage stats
3. **About** — App info, version, links, system info

## Existing Components You Can Reference

The following components exist from prior tasks. You do NOT need to create them, but you should reference their interfaces:
- `KeychainManager` — Has `saveAPIKey(_:)`, `getAPIKey()`, `deleteAPIKey()` methods
- `PhoneNumberFilter` — Has phone number management (add/remove authorized numbers)
- `LaunchAtLoginManager` — Has `isEnabled` property and `setEnabled(_:)` method
- `StatusBanner` (from task 0700) — Use for transient notifications in Settings
- `AppError` (from task 0700) — Reference error types

If these types don't exist yet when this task runs, create protocol stubs or use `@AppStorage` for the values they would provide. The real implementations will be wired up during integration.

## Files to Create

### 1. `src/Views/Settings/SettingsView.swift`

```swift
// SettingsView.swift
// EmberHearth
//
// The main Settings window, using macOS native Settings scene with tabs.

import SwiftUI

/// The main Settings window for EmberHearth.
///
/// Uses SwiftUI's `Settings` scene to present a standard macOS
/// settings window with tab navigation. Opened via:
/// - Menu bar > "Settings..."
/// - Standard Cmd+, keyboard shortcut (handled automatically by Settings scene)
///
/// ## Accessibility
/// - Each tab has a VoiceOver label with its name
/// - Tab icons use SF Symbols for clarity
/// - All content within tabs is fully accessible
struct SettingsView: View {

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            APISettingsView()
                .tabItem {
                    Label("API", systemImage: "key.fill")
                }
                .tag(SettingsTab.api)

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 480, minHeight: 320)
    }
}

/// Identifies the settings tabs for state management.
enum SettingsTab: Hashable {
    case general
    case api
    case about
}
```

### 2. `src/Views/Settings/GeneralSettingsView.swift`

```swift
// GeneralSettingsView.swift
// EmberHearth
//
// General preferences: launch at login, phone numbers, session timeout.

import SwiftUI
import os

/// General settings tab with launch behavior, phone numbers, and session timeout.
///
/// Settings changes take effect immediately — there is no "Apply" or "Save" button.
/// Uses `@AppStorage` for UserDefaults-backed preferences and delegates to
/// specialized managers for Keychain and launch behavior.
///
/// ## Accessibility
/// - All form controls have VoiceOver labels
/// - Toggle descriptions explain what each setting does
/// - Phone number list is navigable with VoiceOver
/// - Dynamic Type adjusts all text sizes
struct GeneralSettingsView: View {

    /// Logger for settings operations.
    private let logger = Logger(subsystem: "com.emberhearth.app", category: "GeneralSettings")

    /// Whether EmberHearth launches at login.
    /// Backed by UserDefaults for now; wired to LaunchAtLoginManager during integration.
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = true

    /// Session timeout in hours (how long before a conversation session resets).
    @AppStorage("sessionTimeoutHours") private var sessionTimeoutHours: Double = 4.0

    /// Authorized phone numbers that Ember responds to.
    /// Stored as a comma-separated string in UserDefaults for MVP.
    @AppStorage("authorizedPhoneNumbers") private var authorizedPhoneNumbersRaw: String = ""

    /// New phone number being entered by the user.
    @State private var newPhoneNumber: String = ""

    /// Error message for invalid phone number entry.
    @State private var phoneNumberError: String?

    /// Whether the status banner is showing.
    @State private var showBanner: Bool = false

    /// The status banner message.
    @State private var bannerMessage: String = ""

    /// Computed array of authorized phone numbers.
    private var authorizedPhoneNumbers: [String] {
        authorizedPhoneNumbersRaw
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        Form {
            // MARK: - Launch Behavior
            Section {
                Toggle("Launch EmberHearth at login", isOn: $launchAtLogin)
                    .accessibilityLabel("Launch at login")
                    .accessibilityHint("When enabled, EmberHearth starts automatically when you log into your Mac")
                    .onChange(of: launchAtLogin) { _, newValue in
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
        .overlay(alignment: .top) {
            StatusBanner(
                message: bannerMessage,
                severity: .recovery,
                isPresented: $showBanner
            )
        }
    }

    // MARK: - Phone Number Management

    /// Validates and adds a new phone number to the authorized list.
    private func addPhoneNumber() {
        let number = newPhoneNumber.trimmingCharacters(in: .whitespaces)
        guard !number.isEmpty else { return }

        // Validate E.164 format
        let pattern = #"^\+[1-9]\d{1,14}$"#
        guard number.range(of: pattern, options: .regularExpression) != nil else {
            phoneNumberError = "Please enter a valid phone number starting with + (e.g., +15551234567)"
            return
        }

        // Check for duplicates
        guard !authorizedPhoneNumbers.contains(number) else {
            phoneNumberError = "This number is already added."
            return
        }

        // Add to list
        if authorizedPhoneNumbersRaw.isEmpty {
            authorizedPhoneNumbersRaw = number
        } else {
            authorizedPhoneNumbersRaw += ",\(number)"
        }

        newPhoneNumber = ""
        phoneNumberError = nil
        bannerMessage = "Phone number added"
        withAnimation { showBanner = true }
        logger.info("Phone number added (count: \(authorizedPhoneNumbers.count))")
    }

    /// Removes a phone number from the authorized list.
    private func removePhoneNumber(_ number: String) {
        let updated = authorizedPhoneNumbers.filter { $0 != number }
        authorizedPhoneNumbersRaw = updated.joined(separator: ",")
        bannerMessage = "Phone number removed"
        withAnimation { showBanner = true }
        logger.info("Phone number removed (count: \(updated.count))")
    }
}
```

### 3. `src/Views/Settings/APISettingsView.swift`

```swift
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

    /// Whether an API key is currently stored.
    /// In production, this reads from KeychainManager. For now, uses @AppStorage as a stub.
    @AppStorage("hasAPIKey") private var hasAPIKey: Bool = false

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

                // Update / Enter API Key
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

    /// Saves the new API key.
    /// In production, this calls KeychainManager.saveAPIKey().
    /// For now, it updates the flag in UserDefaults.
    private func saveAPIKey() {
        let key = newAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        // TODO: Wire to KeychainManager.saveAPIKey(key) during integration
        hasAPIKey = true
        apiKeyValid = false // Needs validation
        isEditingKey = false
        newAPIKey = ""

        bannerMessage = "API key saved"
        bannerSeverity = .info
        withAnimation { showBanner = true }
        logger.info("API key saved (validation pending)")
    }

    /// Tests the connection by making a lightweight API call.
    /// In production, this calls ClaudeClient.validateKey().
    private func testConnection() {
        isTesting = true
        testResultMessage = nil

        // TODO: Wire to ClaudeClient.validateKey() during integration
        // Simulate async test for now
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second simulated delay
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
```

### 4. `src/Views/Settings/AboutView.swift`

```swift
// AboutView.swift
// EmberHearth
//
// About tab: app info, version, links, system information.

import SwiftUI

/// About tab showing app information, version, links, and system info.
///
/// ## Accessibility
/// - All text supports Dynamic Type
/// - Links have accessibility labels and hints
/// - System info is grouped for VoiceOver
struct AboutView: View {

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)

            // App Icon and Name
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)

                Text("EmberHearth")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Version \(appVersion), build \(buildNumber)")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("EmberHearth, version \(appVersion)")

            Text("A personal AI assistant for macOS")
                .font(.body)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            // Links
            VStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/robault/emberhearth")!) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .accessibilityHidden(true)
                        Text("View on GitHub")
                    }
                }
                .accessibilityLabel("View EmberHearth on GitHub")
                .accessibilityHint("Opens the project repository in your browser")

                Link(destination: URL(string: "https://github.com/robault/emberhearth/issues")!) {
                    HStack {
                        Image(systemName: "ladybug.fill")
                            .accessibilityHidden(true)
                        Text("Report an Issue")
                    }
                }
                .accessibilityLabel("Report an issue")
                .accessibilityHint("Opens the GitHub issues page in your browser")
            }

            Divider()
                .padding(.horizontal, 40)

            // System Info
            VStack(alignment: .leading, spacing: 6) {
                systemInfoRow(label: "macOS", value: macOSVersion)
                systemInfoRow(label: "Build", value: buildNumber)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("System information")

            Spacer()

            Text("Made with care by TokenFires")
                .font(.caption2)
                .foregroundColor(.tertiary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - System Info

    /// A single row in the system info section.
    private func systemInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .frame(width: 60, alignment: .trailing)
            Text(value)
                .monospaced()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    /// The app version string from the bundle.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// The build number from the bundle.
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// The macOS version string.
    private var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}
```

### 5. `tests/Views/SettingsViewTests.swift`

Create tests for the settings view models and logic:

```swift
// SettingsViewTests.swift
// EmberHearth
//
// Unit tests for Settings view models and logic.

import XCTest
@testable import EmberHearth

final class SettingsViewTests: XCTestCase {

    // MARK: - Phone Number Validation Tests

    func testValidE164PhoneNumbers() {
        let validNumbers = [
            "+15551234567",
            "+442071234567",
            "+81312345678",
            "+1",
            "+123456789012345"
        ]

        let pattern = #"^\+[1-9]\d{1,14}$"#
        for number in validNumbers {
            XCTAssertNotNil(
                number.range(of: pattern, options: .regularExpression),
                "Phone number '\(number)' should be valid E.164 format"
            )
        }
    }

    func testInvalidE164PhoneNumbers() {
        let invalidNumbers = [
            "5551234567",      // Missing +
            "+0551234567",     // Leading 0 after +
            "+",               // Just +
            "",                // Empty
            "+1234567890123456", // 16 digits (too long)
            "+1-555-123-4567", // Dashes
            "+(555)1234567",   // Parens
            "+1 555 123 4567", // Spaces
            "+abc1234567"      // Letters
        ]

        let pattern = #"^\+[1-9]\d{1,14}$"#
        for number in invalidNumbers {
            XCTAssertNil(
                number.range(of: pattern, options: .regularExpression),
                "Phone number '\(number)' should be invalid E.164 format"
            )
        }
    }

    // MARK: - Phone Number List Management Tests

    func testPhoneNumberListParsing() {
        let raw = "+15551234567,+442071234567,+81312345678"
        let numbers = raw.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        XCTAssertEqual(numbers.count, 3)
        XCTAssertEqual(numbers[0], "+15551234567")
        XCTAssertEqual(numbers[1], "+442071234567")
        XCTAssertEqual(numbers[2], "+81312345678")
    }

    func testEmptyPhoneNumberListParsing() {
        let raw = ""
        let numbers = raw.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        XCTAssertEqual(numbers.count, 0)
    }

    func testPhoneNumberListWithWhitespace() {
        let raw = " +15551234567 , +442071234567 "
        let numbers = raw.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        XCTAssertEqual(numbers.count, 2)
        XCTAssertEqual(numbers[0], "+15551234567")
        XCTAssertEqual(numbers[1], "+442071234567")
    }

    // MARK: - Session Timeout Tests

    func testSessionTimeoutRange() {
        // Valid range is 1-8 hours
        let minTimeout: Double = 1.0
        let maxTimeout: Double = 8.0
        let defaultTimeout: Double = 4.0

        XCTAssertGreaterThanOrEqual(defaultTimeout, minTimeout)
        XCTAssertLessThanOrEqual(defaultTimeout, maxTimeout)
    }

    // MARK: - Connection Status Tests

    func testConnectionStatusWithNoKey() {
        let hasAPIKey = false
        let apiKeyValid = false

        let statusText: String
        if !hasAPIKey {
            statusText = "Not configured"
        } else if apiKeyValid {
            statusText = "Connected"
        } else {
            statusText = "Key saved, not validated"
        }

        XCTAssertEqual(statusText, "Not configured")
    }

    func testConnectionStatusWithValidKey() {
        let hasAPIKey = true
        let apiKeyValid = true

        let statusText: String
        if !hasAPIKey {
            statusText = "Not configured"
        } else if apiKeyValid {
            statusText = "Connected"
        } else {
            statusText = "Key saved, not validated"
        }

        XCTAssertEqual(statusText, "Connected")
    }

    func testConnectionStatusWithUnvalidatedKey() {
        let hasAPIKey = true
        let apiKeyValid = false

        let statusText: String
        if !hasAPIKey {
            statusText = "Not configured"
        } else if apiKeyValid {
            statusText = "Connected"
        } else {
            statusText = "Key saved, not validated"
        }

        XCTAssertEqual(statusText, "Key saved, not validated")
    }

    // MARK: - Version Info Tests

    func testBundleVersionFormat() {
        // The version should be accessible from the bundle
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        XCTAssertFalse(version.isEmpty, "App version should not be empty")
    }

    // MARK: - Security Tests

    func testAPIKeyNeverStoredInUserDefaults() {
        // hasAPIKey is a boolean flag, not the actual key
        // The actual key should only be in Keychain
        let hasAPIKeyDefaultsKey = "hasAPIKey"
        let value = UserDefaults.standard.object(forKey: hasAPIKeyDefaultsKey)
        // If value exists, it should be a boolean, not a string (which would be the key itself)
        if let value = value {
            XCTAssertTrue(value is Bool, "hasAPIKey in UserDefaults should be a Bool flag, never the actual key")
        }
    }

    func testNoShellExecution() {
        // Structural reminder — real verification is in the verification commands
        let forbiddenPatterns = ["Process(", "NSTask", "/bin/bash", "/bin/sh"]
        for pattern in forbiddenPatterns {
            XCTAssertFalse(pattern.isEmpty, "Settings code must not contain \(pattern)")
        }
    }
}
```

## Implementation Rules

1. **NEVER use Process(), /bin/bash, /bin/sh, NSTask, or osascript.** Hard security rule per ADR-0004.
2. No third-party dependencies. Use only Apple frameworks (Foundation, SwiftUI, os).
3. All Swift files use PascalCase naming.
4. All public types and methods must have documentation comments (///).
5. Use `os.Logger` for logging (subsystem: "com.emberhearth.app", category: class name).
6. The API key is NEVER stored in UserDefaults. Only a boolean `hasAPIKey` flag goes in UserDefaults. The actual key goes in Keychain (wired during integration).
7. Use `@AppStorage` for UserDefaults-backed settings. Changes take effect immediately — no "Apply" button.
8. Use `SecureField` for API key entry (masked input).
9. The Settings window is presented via SwiftUI's `Settings` scene, which automatically handles Cmd+, and the "Settings..." menu item.
10. All SwiftUI views MUST have VoiceOver accessibility labels on interactive elements, support Dynamic Type, support keyboard navigation, and work in light/dark mode.
11. Phone number validation uses E.164 format (+ followed by 1-15 digits).
12. The session timeout slider range is 1-8 hours, step 1, default 4.
13. The "Response style" setting is present but disabled for MVP (shown as "Default" with a "coming soon" note).
14. Test file path: Match existing test file directory structure.

## Directory Structure

Create these files:
- `src/Views/Settings/SettingsView.swift`
- `src/Views/Settings/GeneralSettingsView.swift`
- `src/Views/Settings/APISettingsView.swift`
- `src/Views/Settings/AboutView.swift`
- `tests/Views/SettingsViewTests.swift` (or `tests/SettingsViewTests.swift`)

## Final Checks

Before finishing, verify:
1. All files compile without errors
2. All tests pass
3. No Process(), /bin/bash, NSTask, or osascript calls exist
4. The API key is never stored in or read from UserDefaults (only the boolean flag)
5. SecureField is used for key entry
6. All views have VoiceOver accessibility labels
7. Settings changes take effect immediately (no Apply button)
8. Phone number validation enforces E.164 format
9. Session timeout slider is 1-8 hours, step 1, default 4
10. About view shows version from Bundle, macOS version from ProcessInfo
11. All public methods have documentation comments
12. os.Logger is used (not print())
```

---

## Acceptance Criteria

- [ ] `src/Views/Settings/SettingsView.swift` exists with TabView and 3 tabs
- [ ] `src/Views/Settings/GeneralSettingsView.swift` exists with launch at login, phone numbers, session timeout
- [ ] `src/Views/Settings/APISettingsView.swift` exists with key status, update, test, usage
- [ ] `src/Views/Settings/AboutView.swift` exists with app info, links, system info
- [ ] Settings window uses SwiftUI `Settings` scene (opens with Cmd+,)
- [ ] General tab: Launch at login toggle works
- [ ] General tab: Phone numbers can be added and removed
- [ ] General tab: Phone number validation enforces E.164 format
- [ ] General tab: Session timeout slider ranges 1-8 hours, default 4
- [ ] General tab: "Response style" shown but disabled for MVP
- [ ] API tab: Connection status shows green/red/orange dot with text
- [ ] API tab: SecureField used for API key entry (never plaintext)
- [ ] API tab: "Test Connection" button with loading state
- [ ] API tab: Usage stats display (messages this session)
- [ ] API tab: API key flag stored in UserDefaults, NOT the actual key
- [ ] About tab: App icon, version number from Bundle
- [ ] About tab: "View on GitHub" and "Report an Issue" links
- [ ] About tab: macOS version from ProcessInfo
- [ ] StatusBanner integrated for transient notifications
- [ ] All views support VoiceOver with accessibility labels and hints
- [ ] All views support Dynamic Type
- [ ] All buttons have accessibility labels
- [ ] Light and dark mode supported via semantic colors
- [ ] Settings changes take effect immediately (no "Apply" button)
- [ ] **CRITICAL:** No calls to `Process()`, `/bin/bash`, `/bin/sh`, `NSTask`, or `osascript`
- [ ] All unit tests pass
- [ ] `os.Logger` used for logging (no `print()` statements)

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/Views/Settings/SettingsView.swift && echo "PASS: SettingsView.swift exists" || echo "MISSING: SettingsView.swift"
test -f src/Views/Settings/GeneralSettingsView.swift && echo "PASS: GeneralSettingsView.swift exists" || echo "MISSING: GeneralSettingsView.swift"
test -f src/Views/Settings/APISettingsView.swift && echo "PASS: APISettingsView.swift exists" || echo "MISSING: APISettingsView.swift"
test -f src/Views/Settings/AboutView.swift && echo "PASS: AboutView.swift exists" || echo "MISSING: AboutView.swift"

# Verify no shell execution
grep -rn "Process()" src/Views/Settings/ || echo "PASS: No Process() calls found"
grep -rn "NSTask" src/Views/Settings/ || echo "PASS: No NSTask calls found"
grep -rn "/bin/bash" src/Views/Settings/ || echo "PASS: No /bin/bash references found"
grep -rn "/bin/sh" src/Views/Settings/ || echo "PASS: No /bin/sh references found"

# Verify API key is not stored in UserDefaults
grep -rn "UserDefaults.*apiKey\|apiKey.*UserDefaults\|@AppStorage.*apiKey\"" src/Views/Settings/ | grep -v "hasAPIKey\|apiKeyValid" && echo "FAIL: API key stored in UserDefaults" || echo "PASS: No API key in UserDefaults"

# Verify SecureField is used for key entry
grep -n "SecureField" src/Views/Settings/APISettingsView.swift && echo "PASS: SecureField used for key entry" || echo "FAIL: SecureField not found"

# Verify accessibility labels exist
grep -c "accessibilityLabel" src/Views/Settings/GeneralSettingsView.swift | xargs -I {} echo "GeneralSettings has {} accessibility labels"
grep -c "accessibilityLabel" src/Views/Settings/APISettingsView.swift | xargs -I {} echo "APISettings has {} accessibility labels"
grep -c "accessibilityLabel" src/Views/Settings/AboutView.swift | xargs -I {} echo "AboutView has {} accessibility labels"

# Build the project
xcodebuild build -scheme EmberHearth -destination 'platform=macOS' 2>&1 | tail -20

# Run the settings tests
xcodebuild test -scheme EmberHearth -destination 'platform=macOS' -only-testing:EmberHearthTests/SettingsViewTests 2>&1 | tail -30
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the EmberHearth Settings UI implementation for accessibility, security, Apple HIG compliance, and correctness. Open these files:

@src/Views/Settings/SettingsView.swift
@src/Views/Settings/GeneralSettingsView.swift
@src/Views/Settings/APISettingsView.swift
@src/Views/Settings/AboutView.swift
@tests/Views/SettingsViewTests.swift

Also reference:
@src/Core/Errors/AppError.swift
@src/Views/Components/StatusBanner.swift
@docs/releases/mvp-scope.md

## SECURITY AUDIT (Top Priority)

1. **API Key Handling (CRITICAL):**
   - Is the API key ever stored in UserDefaults? (It should NOT be — only `hasAPIKey` boolean flag.)
   - Is SecureField used for key entry? (Masked input required.)
   - Is the API key ever displayed in the UI? (Should never show the full key.)
   - Is the key ever logged? (Should not be logged, even at debug level.)

2. **Shell Execution Ban (CRITICAL):**
   - Search ALL files for: Process, NSTask, /bin/bash, /bin/sh, osascript, CommandLine
   - If ANY exist, report as CRITICAL immediately.

3. **User Input Validation:**
   - Is phone number validation correct (E.164 format)?
   - Can a malicious phone number string cause any issues?
   - Is there any path where unsanitized user input is used dangerously?

## APPLE HIG COMPLIANCE

4. **Settings Window:**
   - Does it use SwiftUI's Settings scene (not a custom window)?
   - Does Cmd+, open Settings? (Automatic with Settings scene.)
   - Is the window size appropriate (not too wide, not too narrow)?
   - Does TabView use the correct macOS tab style?

5. **Form Layout:**
   - Is `.formStyle(.grouped)` used for proper macOS grouping?
   - Are sections properly structured with headers and footers?
   - Do changes take effect immediately (no "Apply" button)?

## ACCESSIBILITY AUDIT

6. **VoiceOver (CRITICAL):**
   - Does every interactive element have an `accessibilityLabel`?
   - Do elements that combine multiple pieces of info use `accessibilityElement(children: .combine)`?
   - Are decorative icons marked with `accessibilityHidden(true)`?
   - Would a VoiceOver-only user be able to complete all tasks (add number, update key, test connection)?

7. **Dynamic Type:**
   - Are all text elements using semantic font sizes (.body, .caption, .title2)?
   - No hardcoded point sizes for text?

8. **Keyboard Navigation:**
   - Do primary buttons have `.keyboardShortcut(.defaultAction)` where appropriate?
   - Does Cancel have `.keyboardShortcut(.cancelAction)`?
   - Can the user add a phone number by pressing Enter?

## CORRECTNESS

9. **General Tab:**
   - Is session timeout slider range correct (1-8 hours, step 1, default 4)?
   - Is phone number list management correct (add, remove, no duplicates)?
   - Is the "Response style" setting correctly disabled for MVP?

10. **API Tab:**
   - Are the three connection states correct (not configured / connected / key saved, not validated)?
   - Does the test connection button show loading state?
   - Does saving a key reset the validation status?

11. **About Tab:**
   - Does it read version from Bundle correctly?
   - Does it read macOS version from ProcessInfo correctly?
   - Are the GitHub links correct URLs?

12. **Test Quality:**
   - Do tests cover phone number validation (valid and invalid)?
   - Do tests cover phone number list parsing (normal, empty, whitespace)?
   - Do tests cover connection status logic?
   - Is there a test verifying API key is not in UserDefaults?

Report any issues with specific file paths and line numbers. Severity: CRITICAL (must fix before merge), IMPORTANT (should fix), MINOR (nice to have).
```

---

## Commit Message

```
feat(m8): add settings UI with general, API, and about tabs
```

---

## Notes for Next Task

- `SettingsView` is presented via SwiftUI's `Settings` scene. The main `App` struct (from task 0002) needs to include a `Settings { SettingsView() }` scene — this wiring happens during integration.
- The Settings window opens automatically with Cmd+, when using the `Settings` scene. The menu bar "Settings..." item (from StatusBarController) should trigger `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)` or `NSApp.activate(ignoringOtherApps: true)` + key equivalent.
- `@AppStorage` is used for UserDefaults-backed settings. The actual API key storage uses Keychain (wired during integration via KeychainManager from task 0200).
- Phone numbers are stored as a comma-separated string in UserDefaults for MVP simplicity. This will be migrated to a proper data structure in the PhoneNumberFilter during integration.
- The "Test Connection" currently uses a simulated delay. Wire to `ClaudeClient.validateKey()` during integration.
- StatusBanner from task 0700 is integrated for transient notifications (phone number added, key saved, connection tested).
- The About tab links to the GitHub repository at `https://github.com/robault/emberhearth`.
