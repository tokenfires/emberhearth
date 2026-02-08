# Task 0600: Onboarding Flow with Permission Request Views

**Milestone:** M7 - Onboarding
**Unit:** 7.1 - Permission Request Flow
**Phase:** 3
**Depends On:** 0504 (M6 complete)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions (PascalCase for Swift), security boundaries, core principles (accessibility, Apple quality)
2. `docs/research/onboarding-ux.md` — Focus on Section 2: "The Onboarding Flow" (lines ~60-105) for the step sequence, Section 5: "Core Permissions" (lines ~283-425) for permission explanation patterns and walkthrough UI, and Section 13: "Implementation Notes" (lines ~793-869) for the OnboardingState enum and PermissionChecker code
3. `docs/research/security.md` — Focus on the macOS permission model section for how Full Disk Access, Automation, and Notification permissions work
4. `Package.swift` — Review the target structure (src path, tests path) so you understand how to add files that compile

> **Context Budget Note:** onboarding-ux.md is ~920 lines. Focus on Section 2 (flow overview), Section 5 (permissions screens and walkthrough), and Section 13 (implementation code). Skip Section 4 (LLM provider setup), Section 7 (deferred permissions), Section 11 (post-onboarding), and Section 14 (metrics).

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are creating the onboarding flow for EmberHearth, a native macOS personal AI assistant that communicates via iMessage. This is the first-time user experience — the screens a user sees when they launch EmberHearth for the first time. The goal is to get users to a working first interaction in under 5 minutes.

IMPORTANT RULES (from CLAUDE.md):
- Product display name: "EmberHearth"
- Swift files use PascalCase (e.g., OnboardingContainerView.swift)
- Security first: NEVER implement shell execution. No Process(), no /bin/bash, no NSTask.
- ALL UI must support VoiceOver, Dynamic Type, and keyboard navigation
- Follow Apple Human Interface Guidelines
- All source files go under src/, all test files go under tests/
- Every Swift file should have the filename as its first comment line

PROJECT CONTEXT:
- This is a Swift Package Manager project (not Xcode project)
- Package.swift has the main target at path "src" and test target at path "tests"
- macOS 14.0+ deployment target
- No third-party dependencies — use only Apple frameworks
- Prior milestones (M1-M6) created: Xcode project shell, iMessage integration (ChatDatabaseReader, MessageWatcher, PhoneNumberFilter, MessageSender), LLM integration (KeychainManager, ClaudeAPIClient), Memory system (DatabaseManager, FactStore), Personality/Context system, and Security pipeline (MessageCoordinator)
- src/ currently has subdirectories: App/, Core/, Database/, LLM/, Logging/, Memory/, Personality/, Security/, Views/
- KeychainManager is at src/Security/KeychainManager.swift with methods: store(apiKey:for:), retrieve(for:), delete(for:), hasKey(for:)
- LLMProvider enum is at src/Security/LLMProvider.swift with cases: .claude, .openai

YOU WILL CREATE:
1. src/App/PermissionManager.swift — Permission checking and System Settings navigation
2. src/Views/Onboarding/OnboardingContainerView.swift — Multi-step wizard container
3. src/Views/Onboarding/WelcomeView.swift — Welcome screen with security messaging
4. src/Views/Onboarding/PermissionsView.swift — Permission request UI
5. tests/PermissionManagerTests.swift — Unit tests for permission logic

STEP 1: Create src/App/PermissionManager.swift

This class checks the status of required macOS permissions and can open System Settings to the correct pane so the user can grant them.

File: src/App/PermissionManager.swift
```swift
// PermissionManager.swift
// EmberHearth
//
// Checks and manages macOS permissions required for EmberHearth to function.
// Full Disk Access and Automation are required; Notifications is optional.

import Foundation
import UserNotifications
import os

// MARK: - Permission Types

/// The types of macOS permissions EmberHearth requires.
enum PermissionType: String, CaseIterable, Sendable {
    /// Full Disk Access — required to read ~/Library/Messages/chat.db
    case fullDiskAccess = "fullDiskAccess"
    /// Automation (Apple Events) — required to send messages via Messages.app
    case automation = "automation"
    /// Notifications — optional, for proactive reminders
    case notifications = "notifications"

    /// Human-readable name for display in the UI.
    var displayName: String {
        switch self {
        case .fullDiskAccess: return "Full Disk Access"
        case .automation: return "Automation"
        case .notifications: return "Notifications"
        }
    }

    /// Plain-language explanation of why this permission is needed.
    var explanation: String {
        switch self {
        case .fullDiskAccess:
            return "EmberHearth needs to read your iMessage conversations to respond to you."
        case .automation:
            return "EmberHearth needs to send messages through the Messages app."
        case .notifications:
            return "EmberHearth can send you reminders and alerts when something needs your attention."
        }
    }

    /// Whether this permission is required for core functionality.
    var isRequired: Bool {
        switch self {
        case .fullDiskAccess, .automation: return true
        case .notifications: return false
        }
    }

    /// SF Symbol name for this permission type.
    var sfSymbolName: String {
        switch self {
        case .fullDiskAccess: return "lock.open.fill"
        case .automation: return "bubble.left.and.bubble.right.fill"
        case .notifications: return "bell.fill"
        }
    }
}

// MARK: - Permission Status

/// Represents the current status of all required permissions.
struct PermissionStatus: Equatable, Sendable {
    /// Whether Full Disk Access is granted (can read ~/Library/Messages/chat.db).
    var fullDiskAccess: Bool
    /// Whether Automation permission is granted (can control Messages.app via AppleScript).
    var automation: Bool
    /// Whether Notification permission is granted.
    var notifications: Bool

    /// Returns true if all required permissions (Full Disk Access and Automation) are granted.
    var allRequiredGranted: Bool {
        return fullDiskAccess && automation
    }

    /// Returns true if all permissions (including optional) are granted.
    var allGranted: Bool {
        return fullDiskAccess && automation && notifications
    }

    /// Returns a fresh status with all permissions set to false.
    static var allDenied: PermissionStatus {
        return PermissionStatus(fullDiskAccess: false, automation: false, notifications: false)
    }
}

// MARK: - PermissionManager

/// Manages checking and requesting macOS permissions for EmberHearth.
///
/// Usage:
/// ```swift
/// let manager = PermissionManager()
/// let status = await manager.checkAllPermissions()
/// if !status.allRequiredGranted {
///     manager.openSystemPreferences(for: .fullDiskAccess)
/// }
/// ```
///
/// Note: macOS does not allow programmatic granting of Full Disk Access or
/// Automation permissions. The user must manually toggle them in System Settings.
/// This manager can only check their status and open the relevant settings pane.
@MainActor
final class PermissionManager: ObservableObject {

    // MARK: - Published Properties

    /// The current permission status, updated by checkAllPermissions().
    @Published var currentStatus: PermissionStatus = .allDenied

    /// Whether a permission check is currently in progress.
    @Published var isChecking: Bool = false

    // MARK: - Private Properties

    /// Logger for permission-related events.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "PermissionManager"
    )

    // MARK: - Public API

    /// Checks the status of all permissions and updates `currentStatus`.
    ///
    /// - Returns: The current `PermissionStatus`.
    @discardableResult
    func checkAllPermissions() async -> PermissionStatus {
        isChecking = true
        defer { isChecking = false }

        let fdaStatus = checkFullDiskAccess()
        let automationStatus = checkAutomation()
        let notificationStatus = await checkNotifications()

        let status = PermissionStatus(
            fullDiskAccess: fdaStatus,
            automation: automationStatus,
            notifications: notificationStatus
        )

        currentStatus = status

        Self.logger.info(
            "Permission check: FDA=\(fdaStatus), Automation=\(automationStatus), Notifications=\(notificationStatus)"
        )

        return status
    }

    /// Opens System Settings to the appropriate pane for the given permission.
    ///
    /// - Parameter permission: The permission type to open settings for.
    func openSystemPreferences(for permission: PermissionType) {
        let urlString: String
        switch permission {
        case .fullDiskAccess:
            // System Settings > Privacy & Security > Full Disk Access
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        case .automation:
            // System Settings > Privacy & Security > Automation
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        case .notifications:
            // System Settings > Notifications
            urlString = "x-apple.systempreferences:com.apple.preference.notifications"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            Self.logger.info("Opened System Settings for: \(permission.rawValue)")
        } else {
            Self.logger.error("Failed to create URL for System Settings pane: \(permission.rawValue)")
        }
    }

    // MARK: - Individual Permission Checks

    /// Checks whether Full Disk Access is granted by attempting to read
    /// ~/Library/Messages/chat.db. This file is only readable with FDA.
    ///
    /// - Returns: true if the file is readable (FDA granted), false otherwise.
    func checkFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let chatDBPath = "\(home)/Library/Messages/chat.db"
        let isReadable = FileManager.default.isReadableFile(atPath: chatDBPath)
        Self.logger.debug("Full Disk Access check: \(isReadable ? "granted" : "denied")")
        return isReadable
    }

    /// Checks whether Automation permission is granted by running a harmless
    /// AppleScript against the Messages app.
    ///
    /// Note: This uses NSAppleScript, which is allowed per the security model
    /// because it is a structured Apple API — not shell execution.
    ///
    /// - Returns: true if Automation is granted, false otherwise.
    func checkAutomation() -> Bool {
        let script = NSAppleScript(source: "tell application \"Messages\" to get name")
        var errorInfo: NSDictionary?
        script?.executeAndReturnError(&errorInfo)

        let isGranted = (errorInfo == nil)
        Self.logger.debug("Automation check: \(isGranted ? "granted" : "denied")")
        return isGranted
    }

    /// Checks whether Notification permission is granted.
    ///
    /// - Returns: true if notifications are authorized, false otherwise.
    func checkNotifications() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let isAuthorized = settings.authorizationStatus == .authorized
        Self.logger.debug("Notification check: \(isAuthorized ? "granted" : "denied")")
        return isAuthorized
    }

    /// Requests notification permission from the user.
    ///
    /// - Returns: true if the user granted permission, false otherwise.
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            Self.logger.info("Notification permission request result: \(granted ? "granted" : "denied")")
            return granted
        } catch {
            Self.logger.error("Notification permission request failed: \(error.localizedDescription)")
            return false
        }
    }
}
```

STEP 2: Create src/Views/Onboarding/OnboardingContainerView.swift

This is the multi-step wizard that manages the onboarding flow. It uses a NavigationStack with a progress bar and supports forward/backward navigation.

File: src/Views/Onboarding/OnboardingContainerView.swift
```swift
// OnboardingContainerView.swift
// EmberHearth
//
// Multi-step onboarding wizard container. Manages navigation between
// onboarding steps and displays a progress bar.

import SwiftUI

// MARK: - Onboarding Step Enum

/// The sequential steps in the onboarding flow.
enum OnboardingStep: Int, CaseIterable, Comparable {
    case welcome = 0
    case permissions = 1
    case apiKey = 2
    case phoneConfig = 3
    case test = 4

    /// Human-readable title for each step.
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .permissions: return "Permissions"
        case .apiKey: return "API Key"
        case .phoneConfig: return "Phone Number"
        case .test: return "Test"
        }
    }

    /// Total number of steps (for progress calculation).
    static var totalSteps: Int { allCases.count }

    /// Progress fraction (0.0 to 1.0) for this step.
    var progressFraction: Double {
        return Double(rawValue + 1) / Double(Self.totalSteps)
    }

    static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Onboarding Container View

/// The top-level container for the onboarding flow.
///
/// Displays a progress bar at the top, manages navigation between steps,
/// and stores onboarding completion state in UserDefaults.
///
/// Accessibility:
/// - Progress bar has a VoiceOver label announcing "Step X of 5"
/// - All navigation uses keyboard-accessible controls
/// - Back navigation is available via a button or Escape key
struct OnboardingContainerView: View {

    // MARK: - State

    /// The current onboarding step.
    @State private var currentStep: OnboardingStep = .welcome

    /// Whether onboarding is complete and the main app should be shown.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    /// The permission manager shared across onboarding views.
    @StateObject private var permissionManager = PermissionManager()

    /// Callback invoked when onboarding is finished.
    var onComplete: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar (not shown on welcome step for cleaner first impression)
            if currentStep != .welcome {
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }

            // Step content
            Group {
                switch currentStep {
                case .welcome:
                    WelcomeView(onContinue: { advanceToStep(.permissions) })

                case .permissions:
                    PermissionsView(
                        permissionManager: permissionManager,
                        onContinue: { advanceToStep(.apiKey) },
                        onBack: { goBackToStep(.welcome) }
                    )

                case .apiKey:
                    // Placeholder — will be implemented in task 0601
                    placeholderView(title: "API Key Setup", step: .apiKey)

                case .phoneConfig:
                    // Placeholder — will be implemented in task 0602
                    placeholderView(title: "Phone Number Setup", step: .phoneConfig)

                case .test:
                    // Placeholder — will be implemented in task 0603
                    placeholderView(title: "First Message Test", step: .test)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .onKeyPress(.escape) {
            if currentStep != .welcome {
                goBack()
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Progress Bar

    /// A horizontal progress bar showing the current step out of total steps.
    private var progressBar: some View {
        VStack(spacing: 4) {
            // Step indicator text
            Text("Step \(currentStep.rawValue + 1) of \(OnboardingStep.totalSteps)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Progress track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    // Filled progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(
                            width: geometry.size.width * currentStep.progressFraction,
                            height: 6
                        )
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .frame(height: 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Onboarding progress")
            .accessibilityValue("Step \(currentStep.rawValue + 1) of \(OnboardingStep.totalSteps)")
        }
    }

    // MARK: - Placeholder Views

    /// A placeholder view for steps not yet implemented (tasks 0601-0603).
    private func placeholderView(title: String, step: OnboardingStep) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Text(title)
                .font(.title)
                .fontWeight(.bold)

            Text("This step will be implemented in a future task.")
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("Back") {
                    goBack()
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Go back to previous step")
                .accessibilityHint("Returns to the previous onboarding step")

                if step == .test {
                    Button("Finish Onboarding") {
                        completeOnboarding()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Finish onboarding")
                    .accessibilityHint("Completes setup and opens the main app")
                } else {
                    Button("Continue") {
                        advanceToNextStep()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Continue to next step")
                    .accessibilityHint("Advances to the next onboarding step")
                }
            }

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Navigation

    /// Advances to a specific onboarding step.
    private func advanceToStep(_ step: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
        }
    }

    /// Advances to the next sequential step.
    private func advanceToNextStep() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            completeOnboarding()
            return
        }
        advanceToStep(nextStep)
    }

    /// Goes back to a specific step.
    private func goBackToStep(_ step: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
        }
    }

    /// Goes back one step.
    private func goBack() {
        guard let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else {
            return
        }
        goBackToStep(previousStep)
    }

    /// Marks onboarding as complete and invokes the completion callback.
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        onComplete?()
    }
}
```

STEP 3: Create src/Views/Onboarding/WelcomeView.swift

The first screen the user sees. Shows the EmberHearth branding, a brief description, and three security bullet points.

File: src/Views/Onboarding/WelcomeView.swift
```swift
// WelcomeView.swift
// EmberHearth
//
// Welcome screen shown as the first step of onboarding.
// Introduces EmberHearth with security messaging and a "Get Started" button.

import SwiftUI

/// The welcome screen shown when a user launches EmberHearth for the first time.
///
/// Design principles (from onboarding-ux.md):
/// - Warm, not corporate
/// - Set expectations: time estimate, what's needed
/// - Three-layer security explanation (Layer 1: one-sentence reassurance)
/// - The "grandmother test": keep it simple enough for anyone
///
/// Accessibility:
/// - VoiceOver reads the heading, description, security points, and button
/// - Dynamic Type scales all text with semantic font styles
/// - Keyboard: Tab to the button, Enter/Space to activate
/// - Supports both light and dark mode
struct WelcomeView: View {

    // MARK: - Properties

    /// Callback invoked when the user taps "Get Started".
    var onContinue: () -> Void

    /// Respect the user's Reduce Motion preference.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Flame icon
            Image(systemName: "flame.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .accessibilityLabel("EmberHearth flame icon")
                .accessibilityAddTraits(.isImage)
                .padding(.bottom, 16)

            // Heading
            Text("Welcome to EmberHearth")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 8)

            // Subtitle
            Text("Your personal AI assistant, right in iMessage")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)

            // Security bullet points
            VStack(alignment: .leading, spacing: 16) {
                securityBullet(
                    icon: "lock.shield",
                    text: "Your data stays on your Mac"
                )
                securityBullet(
                    icon: "eye.slash",
                    text: "We never see your conversations"
                )
                securityBullet(
                    icon: "hand.raised",
                    text: "You control what Ember remembers"
                )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)

            // Time estimate
            Text("Setup takes about 5 minutes")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 24)

            // Get Started button
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel("Get Started")
            .accessibilityHint("Begins the EmberHearth setup process")
            .accessibilityIdentifier("welcomeGetStartedButton")

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Security Bullet Point

    /// A single security bullet point with an SF Symbol icon and text.
    private func securityBullet(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.accent)
                .frame(width: 32, alignment: .center)
                .accessibilityHidden(true)

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}
```

STEP 4: Create src/Views/Onboarding/PermissionsView.swift

This view explains and requests the core permissions. It shows the status of each permission, lets the user open System Settings, and auto-refreshes every 2 seconds.

File: src/Views/Onboarding/PermissionsView.swift
```swift
// PermissionsView.swift
// EmberHearth
//
// Permission request screen shown during onboarding. Explains each permission
// in plain language, shows real-time grant status, and opens System Settings.

import SwiftUI

/// The permissions step of onboarding.
///
/// Displays each required permission with:
/// - A plain-language explanation of why it's needed
/// - Current status (granted / not granted)
/// - A button to open the relevant System Settings pane
/// - Auto-refresh of status every 2 seconds
///
/// The user cannot proceed until Full Disk Access and Automation are granted.
/// Notifications permission is optional and can be skipped.
///
/// Accessibility:
/// - VoiceOver announces permission status changes
/// - All buttons have descriptive labels and hints
/// - Dynamic Type scales all text
/// - Keyboard navigation through all interactive elements
struct PermissionsView: View {

    // MARK: - Properties

    /// The shared permission manager that checks and tracks permission status.
    @ObservedObject var permissionManager: PermissionManager

    /// Callback invoked when the user can proceed (required permissions granted).
    var onContinue: () -> Void

    /// Callback invoked when the user wants to go back.
    var onBack: () -> Void

    /// Timer that triggers permission re-checks every 2 seconds.
    @State private var refreshTimer: Timer?

    /// Whether the notification permission has been explicitly handled (granted or skipped).
    @State private var notificationHandled: Bool = false

    /// Tracks the previous permission status for VoiceOver announcements.
    @State private var previousStatus: PermissionStatus = .allDenied

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Heading
                    VStack(spacing: 8) {
                        Text("Permissions")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .accessibilityAddTraits(.isHeader)

                        Text("EmberHearth needs a few permissions to work. We'll explain each one.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Permission cards
                    VStack(spacing: 16) {
                        permissionCard(for: .fullDiskAccess, isGranted: permissionManager.currentStatus.fullDiskAccess)
                        permissionCard(for: .automation, isGranted: permissionManager.currentStatus.automation)
                        notificationCard
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
            }

            Divider()

            // Navigation buttons
            HStack {
                Button("Back") {
                    onBack()
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Go back")
                .accessibilityHint("Returns to the welcome screen")

                Spacer()

                if permissionManager.isChecking {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                }

                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!permissionManager.currentStatus.allRequiredGranted)
                .accessibilityLabel("Continue to next step")
                .accessibilityHint(
                    permissionManager.currentStatus.allRequiredGranted
                    ? "Proceeds to API key setup"
                    : "Grant Full Disk Access and Automation permissions to continue"
                )
                .accessibilityIdentifier("permissionsContinueButton")
            }
            .padding(16)
        }
        .onAppear {
            startRefreshTimer()
            Task {
                await permissionManager.checkAllPermissions()
            }
        }
        .onDisappear {
            stopRefreshTimer()
        }
        .onChange(of: permissionManager.currentStatus) { oldValue, newValue in
            announcePermissionChanges(from: oldValue, to: newValue)
        }
    }

    // MARK: - Permission Card

    /// A card displaying a single permission with its status and action button.
    private func permissionCard(for permission: PermissionType, isGranted: Bool) -> some View {
        HStack(spacing: 16) {
            // Status icon
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(isGranted ? .green : .yellow)
                .frame(width: 32)
                .accessibilityHidden(true)

            // Permission info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: permission.sfSymbolName)
                        .foregroundStyle(.accent)
                        .accessibilityHidden(true)

                    Text(permission.displayName)
                        .font(.headline)

                    if permission.isRequired {
                        Text("Required")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.8), in: Capsule())
                    }
                }

                Text(permission.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Action button
            if isGranted {
                Text("Granted")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
            } else {
                Button("Open Settings") {
                    permissionManager.openSystemPreferences(for: permission)
                }
                .accessibilityLabel("Open System Settings for \(permission.displayName)")
                .accessibilityHint("Opens System Settings where you can grant \(permission.displayName) to EmberHearth")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isGranted
                    ? Color.green.opacity(0.05)
                    : Color.yellow.opacity(0.05)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isGranted ? Color.green.opacity(0.2) : Color.yellow.opacity(0.2),
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(permission.displayName): \(isGranted ? "granted" : "not granted"). \(permission.explanation)")
        .accessibilityIdentifier("permissionCard_\(permission.rawValue)")
    }

    // MARK: - Notification Card

    /// A specialized card for the optional notification permission.
    private var notificationCard: some View {
        HStack(spacing: 16) {
            // Status icon
            let isGranted = permissionManager.currentStatus.notifications
            Image(systemName: isGranted ? "checkmark.circle.fill" : "bell.badge")
                .font(.title2)
                .foregroundStyle(isGranted ? .green : .secondary)
                .frame(width: 32)
                .accessibilityHidden(true)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.accent)
                        .accessibilityHidden(true)

                    Text("Notifications")
                        .font(.headline)

                    Text("Optional")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }

                Text(PermissionType.notifications.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Action buttons
            if isGranted || notificationHandled {
                Text(isGranted ? "Granted" : "Skipped")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isGranted ? .green : .secondary)
            } else {
                VStack(spacing: 4) {
                    Button("Enable") {
                        Task {
                            let granted = await permissionManager.requestNotificationPermission()
                            if granted {
                                await permissionManager.checkAllPermissions()
                            }
                            notificationHandled = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Enable notifications")
                    .accessibilityHint("Requests permission to send you notifications")

                    Button("Skip") {
                        notificationHandled = true
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Skip notifications")
                    .accessibilityHint("Continues without notification permission. You can enable this later in Settings.")
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notifications: \(permissionManager.currentStatus.notifications ? "granted" : notificationHandled ? "skipped" : "not configured"). Optional. \(PermissionType.notifications.explanation)")
        .accessibilityIdentifier("permissionCard_notifications")
    }

    // MARK: - Timer Management

    /// Starts a timer that re-checks permissions every 2 seconds.
    /// This allows the UI to update when the user grants permission in System Settings
    /// and switches back to EmberHearth.
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                await permissionManager.checkAllPermissions()
            }
        }
    }

    /// Stops the permission refresh timer.
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - VoiceOver Announcements

    /// Announces permission status changes to VoiceOver users.
    private func announcePermissionChanges(from oldStatus: PermissionStatus, to newStatus: PermissionStatus) {
        if !oldStatus.fullDiskAccess && newStatus.fullDiskAccess {
            announceToVoiceOver("Full Disk Access permission granted")
        }
        if !oldStatus.automation && newStatus.automation {
            announceToVoiceOver("Automation permission granted")
        }
        if !oldStatus.notifications && newStatus.notifications {
            announceToVoiceOver("Notification permission granted")
        }
        if newStatus.allRequiredGranted && !oldStatus.allRequiredGranted {
            announceToVoiceOver("All required permissions granted. You can now continue.")
        }
    }

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

STEP 5: Create tests/PermissionManagerTests.swift

Unit tests for the PermissionManager logic. Note that actual permission checks depend on system state, so we test the data structures and logic rather than the system calls.

File: tests/PermissionManagerTests.swift
```swift
// PermissionManagerTests.swift
// EmberHearth
//
// Unit tests for PermissionManager data structures and logic.

import XCTest
@testable import EmberHearth

final class PermissionManagerTests: XCTestCase {

    // MARK: - PermissionStatus Tests

    func testAllDeniedStatus() {
        let status = PermissionStatus.allDenied
        XCTAssertFalse(status.fullDiskAccess)
        XCTAssertFalse(status.automation)
        XCTAssertFalse(status.notifications)
        XCTAssertFalse(status.allRequiredGranted)
        XCTAssertFalse(status.allGranted)
    }

    func testAllRequiredGrantedWithoutNotifications() {
        let status = PermissionStatus(
            fullDiskAccess: true,
            automation: true,
            notifications: false
        )
        XCTAssertTrue(status.allRequiredGranted, "Should be true when FDA and Automation are granted")
        XCTAssertFalse(status.allGranted, "Should be false when notifications are not granted")
    }

    func testAllGranted() {
        let status = PermissionStatus(
            fullDiskAccess: true,
            automation: true,
            notifications: true
        )
        XCTAssertTrue(status.allRequiredGranted)
        XCTAssertTrue(status.allGranted)
    }

    func testPartialRequiredPermissions() {
        let fdaOnly = PermissionStatus(fullDiskAccess: true, automation: false, notifications: false)
        XCTAssertFalse(fdaOnly.allRequiredGranted, "Should be false with only FDA granted")

        let automationOnly = PermissionStatus(fullDiskAccess: false, automation: true, notifications: false)
        XCTAssertFalse(automationOnly.allRequiredGranted, "Should be false with only Automation granted")
    }

    func testPermissionStatusEquality() {
        let status1 = PermissionStatus(fullDiskAccess: true, automation: true, notifications: false)
        let status2 = PermissionStatus(fullDiskAccess: true, automation: true, notifications: false)
        XCTAssertEqual(status1, status2)
    }

    func testPermissionStatusInequality() {
        let status1 = PermissionStatus(fullDiskAccess: true, automation: true, notifications: false)
        let status2 = PermissionStatus(fullDiskAccess: true, automation: true, notifications: true)
        XCTAssertNotEqual(status1, status2)
    }

    // MARK: - PermissionType Tests

    func testPermissionTypeDisplayNames() {
        XCTAssertEqual(PermissionType.fullDiskAccess.displayName, "Full Disk Access")
        XCTAssertEqual(PermissionType.automation.displayName, "Automation")
        XCTAssertEqual(PermissionType.notifications.displayName, "Notifications")
    }

    func testPermissionTypeIsRequired() {
        XCTAssertTrue(PermissionType.fullDiskAccess.isRequired)
        XCTAssertTrue(PermissionType.automation.isRequired)
        XCTAssertFalse(PermissionType.notifications.isRequired)
    }

    func testPermissionTypeExplanations() {
        for permission in PermissionType.allCases {
            XCTAssertFalse(permission.explanation.isEmpty, "\(permission.displayName) should have a non-empty explanation")
        }
    }

    func testPermissionTypeSFSymbols() {
        XCTAssertEqual(PermissionType.fullDiskAccess.sfSymbolName, "lock.open.fill")
        XCTAssertEqual(PermissionType.automation.sfSymbolName, "bubble.left.and.bubble.right.fill")
        XCTAssertEqual(PermissionType.notifications.sfSymbolName, "bell.fill")
    }

    func testPermissionTypeAllCases() {
        XCTAssertEqual(PermissionType.allCases.count, 3)
        XCTAssertTrue(PermissionType.allCases.contains(.fullDiskAccess))
        XCTAssertTrue(PermissionType.allCases.contains(.automation))
        XCTAssertTrue(PermissionType.allCases.contains(.notifications))
    }

    // MARK: - OnboardingStep Tests

    func testOnboardingStepOrder() {
        XCTAssertLessThan(OnboardingStep.welcome, OnboardingStep.permissions)
        XCTAssertLessThan(OnboardingStep.permissions, OnboardingStep.apiKey)
        XCTAssertLessThan(OnboardingStep.apiKey, OnboardingStep.phoneConfig)
        XCTAssertLessThan(OnboardingStep.phoneConfig, OnboardingStep.test)
    }

    func testOnboardingStepTotalSteps() {
        XCTAssertEqual(OnboardingStep.totalSteps, 5)
    }

    func testOnboardingStepProgressFractions() {
        XCTAssertEqual(OnboardingStep.welcome.progressFraction, 0.2, accuracy: 0.01)
        XCTAssertEqual(OnboardingStep.permissions.progressFraction, 0.4, accuracy: 0.01)
        XCTAssertEqual(OnboardingStep.apiKey.progressFraction, 0.6, accuracy: 0.01)
        XCTAssertEqual(OnboardingStep.phoneConfig.progressFraction, 0.8, accuracy: 0.01)
        XCTAssertEqual(OnboardingStep.test.progressFraction, 1.0, accuracy: 0.01)
    }

    func testOnboardingStepTitles() {
        XCTAssertEqual(OnboardingStep.welcome.title, "Welcome")
        XCTAssertEqual(OnboardingStep.permissions.title, "Permissions")
        XCTAssertEqual(OnboardingStep.apiKey.title, "API Key")
        XCTAssertEqual(OnboardingStep.phoneConfig.title, "Phone Number")
        XCTAssertEqual(OnboardingStep.test.title, "Test")
    }

    func testOnboardingStepRawValues() {
        XCTAssertEqual(OnboardingStep.welcome.rawValue, 0)
        XCTAssertEqual(OnboardingStep.permissions.rawValue, 1)
        XCTAssertEqual(OnboardingStep.apiKey.rawValue, 2)
        XCTAssertEqual(OnboardingStep.phoneConfig.rawValue, 3)
        XCTAssertEqual(OnboardingStep.test.rawValue, 4)
    }
}
```

STEP 6: Verify the build

After creating all files, ensure the directory structure exists:
- src/App/ should already exist
- src/Views/Onboarding/ — create this directory if it doesn't exist

Then run from the project root (/Users/robault/Documents/GitHub/emberhearth):

```bash
swift build
swift test
```

Both must succeed. If the build fails, debug the issue. Common problems:
- Missing import: SwiftUI views need `import SwiftUI`
- UserNotifications framework: needs `import UserNotifications`
- NSWorkspace: Available via AppKit, which is implicitly available in macOS SwiftUI apps
- onKeyPress: Available in macOS 14.0+. If the deployment target is lower, use .onExitCommand() instead.
- onChange with two parameters (oldValue, newValue): Available in macOS 14.0+. If needed, use the single-parameter version.
- If tests/ doesn't support subdirectories in SPM, place test files directly in tests/ (check existing test file locations and match that pattern).

IMPORTANT NOTES:
- Do NOT modify Package.swift unless absolutely necessary to add a framework.
- Do NOT modify any existing files except those specified.
- The PermissionManager uses NSAppleScript to check Automation permission — this is a structured Apple API, NOT shell execution. It is allowed under ADR-0004.
- The openSystemPreferences method uses URL schemes (x-apple.systempreferences:) which are the Apple-approved way to deep-link into System Settings.
- ALL views must support VoiceOver (accessibilityLabel, accessibilityHint), Dynamic Type (semantic font styles), and keyboard navigation (keyboardShortcut, focusable elements).
- The 2-second permission refresh timer in PermissionsView is critical for UX: the user opens System Settings, grants permission, then switches back to EmberHearth and sees the status update automatically.
```

---

## Acceptance Criteria

- [ ] `src/App/PermissionManager.swift` exists and compiles
- [ ] `src/Views/Onboarding/OnboardingContainerView.swift` exists and compiles
- [ ] `src/Views/Onboarding/WelcomeView.swift` exists and compiles
- [ ] `src/Views/Onboarding/PermissionsView.swift` exists and compiles
- [ ] `tests/PermissionManagerTests.swift` exists and all tests pass
- [ ] `PermissionType` enum has three cases: `fullDiskAccess`, `automation`, `notifications`
- [ ] `PermissionStatus` struct has `allRequiredGranted` and `allGranted` computed properties
- [ ] `PermissionManager.checkAllPermissions()` checks all three permission types
- [ ] `PermissionManager.openSystemPreferences(for:)` opens the correct System Settings pane
- [ ] Full Disk Access check reads `~/Library/Messages/chat.db` readability
- [ ] Automation check uses `NSAppleScript` (not shell execution)
- [ ] Notifications check uses `UNUserNotificationCenter`
- [ ] `OnboardingContainerView` has 5 steps: Welcome, Permissions, API Key, Phone Config, Test
- [ ] Progress bar shows "Step X of 5" with visual fill
- [ ] Onboarding completion stored in `UserDefaults` key `"hasCompletedOnboarding"`
- [ ] `WelcomeView` shows flame icon, heading, description, 3 security bullet points, and "Get Started" button
- [ ] Security bullets use correct SF Symbols: `lock.shield`, `eye.slash`, `hand.raised`
- [ ] `PermissionsView` shows status (green check / yellow warning) for each permission
- [ ] `PermissionsView` has "Open Settings" button for each ungrantled permission
- [ ] `PermissionsView` auto-refreshes permission status every 2 seconds
- [ ] Continue button is disabled until Full Disk Access and Automation are granted
- [ ] Notifications permission has a "Skip" option
- [ ] ALL views have VoiceOver `accessibilityLabel` on interactive elements
- [ ] ALL views use semantic font styles (`.body`, `.headline`, `.title`, etc.)
- [ ] Keyboard shortcuts: Enter/Return for primary action, Escape to go back
- [ ] Permission status changes are announced to VoiceOver
- [ ] `swift build` succeeds
- [ ] `swift test` succeeds

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify files exist
test -f src/App/PermissionManager.swift && echo "PermissionManager.swift exists" || echo "MISSING: PermissionManager.swift"
test -f src/Views/Onboarding/OnboardingContainerView.swift && echo "OnboardingContainerView.swift exists" || echo "MISSING: OnboardingContainerView.swift"
test -f src/Views/Onboarding/WelcomeView.swift && echo "WelcomeView.swift exists" || echo "MISSING: WelcomeView.swift"
test -f src/Views/Onboarding/PermissionsView.swift && echo "PermissionsView.swift exists" || echo "MISSING: PermissionsView.swift"
test -f tests/PermissionManagerTests.swift && echo "PermissionManagerTests.swift exists" || echo "MISSING: PermissionManagerTests.swift"

# Verify no shell execution (security check)
grep -rn "Process()" src/App/PermissionManager.swift && echo "WARNING: Found Process() call" || echo "OK: No Process() calls"
grep -rn "/bin/bash" src/App/PermissionManager.swift && echo "WARNING: Found /bin/bash" || echo "OK: No /bin/bash"
grep -rn "/bin/sh" src/App/PermissionManager.swift && echo "WARNING: Found /bin/sh" || echo "OK: No /bin/sh"

# Verify accessibility labels exist in views
grep -c "accessibilityLabel" src/Views/Onboarding/WelcomeView.swift
grep -c "accessibilityLabel" src/Views/Onboarding/PermissionsView.swift
grep -c "accessibilityLabel" src/Views/Onboarding/OnboardingContainerView.swift

# Verify VoiceOver announcement support
grep "announcementRequested" src/Views/Onboarding/PermissionsView.swift

# Verify permission refresh timer
grep "Timer.scheduledTimer" src/Views/Onboarding/PermissionsView.swift

# Build the project
swift build 2>&1

# Run tests
swift test --filter PermissionManagerTests 2>&1

# Run all tests to ensure nothing is broken
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the onboarding flow implementation created in task 0600 for EmberHearth. Open these files:

@src/App/PermissionManager.swift
@src/Views/Onboarding/OnboardingContainerView.swift
@src/Views/Onboarding/WelcomeView.swift
@src/Views/Onboarding/PermissionsView.swift
@tests/PermissionManagerTests.swift

Also reference:
@CLAUDE.md
@docs/research/onboarding-ux.md (focus on Sections 2, 5, 12, 13)

Check for these specific issues:

1. SECURITY (Critical):
   - Verify NO calls to Process(), /bin/bash, /bin/sh, or NSTask anywhere in these files
   - Verify the Automation check uses NSAppleScript (a structured Apple API), not shell execution
   - Verify openSystemPreferences uses URL schemes, not shell commands
   - Verify no credentials or API keys are handled in this task (that's task 0601)

2. ACCESSIBILITY (Critical — every item must pass):
   - WelcomeView: Every interactive element has accessibilityLabel. The flame icon has an image description. The heading has .isHeader trait.
   - PermissionsView: Permission status changes trigger VoiceOver announcements. All "Open Settings" buttons have descriptive labels and hints. The Continue button's disabled state is communicated to VoiceOver.
   - OnboardingContainerView: The progress bar has an accessibilityLabel and accessibilityValue. Escape key navigates back. Tab order is logical.
   - ALL views: No fixed font sizes — only semantic styles (.body, .headline, .title, .largeTitle). All text handles Dynamic Type at the largest accessibility size without truncation.

3. PERMISSION LOGIC:
   - Verify Full Disk Access is checked by reading ~/Library/Messages/chat.db
   - Verify Automation is checked via NSAppleScript against Messages app
   - Verify Notifications is checked via UNUserNotificationCenter
   - Verify allRequiredGranted returns true only when BOTH fullDiskAccess AND automation are true
   - Verify the 2-second refresh timer starts on appear and stops on disappear (no leaked timers)
   - Verify notification permission can be skipped (not required to proceed)

4. ONBOARDING FLOW:
   - Verify there are exactly 5 steps: welcome, permissions, apiKey, phoneConfig, test
   - Verify steps 3-5 have placeholder views (they'll be implemented in tasks 0601-0603)
   - Verify onboarding completion is stored in UserDefaults with key "hasCompletedOnboarding"
   - Verify backward navigation works (Escape key, Back button)
   - Verify the progress bar correctly shows "Step X of 5"

5. UI QUALITY:
   - Verify light and dark mode support (no hardcoded colors — use system colors)
   - Verify the WelcomeView security bullets match the spec: lock.shield, eye.slash, hand.raised
   - Verify the permission cards show green for granted and yellow for not granted
   - Verify minimum window size is set (at least 600x500)

6. BUILD VERIFICATION:
   - Run `swift build` and verify success
   - Run `swift test --filter PermissionManagerTests` and verify all tests pass
   - Run `swift test` and verify no existing tests are broken

Report any issues found with exact file paths and line numbers. For each issue, indicate severity: CRITICAL (must fix), IMPORTANT (should fix), or MINOR (nice to have).
```

---

## Commit Message

```
feat(m7): add onboarding flow with permission request views
```

---

## Notes for Next Task

- The `OnboardingContainerView` has placeholder views for steps 3-5 (API Key, Phone Config, Test). Task 0601 will replace the API Key placeholder with `APIKeyEntryView`.
- The `PermissionManager` is created as a `@StateObject` in `OnboardingContainerView` and passed as `@ObservedObject` to child views. Task 0601 does NOT need the PermissionManager.
- The `OnboardingStep` enum is defined in `OnboardingContainerView.swift`. Tasks 0601-0603 will need to reference it for navigation callbacks.
- The `@AppStorage("hasCompletedOnboarding")` key is used to determine whether to show onboarding or the main app. The main app entry point should check this value.
- The `KeychainManager` (from task 0200) is available at `src/Security/KeychainManager.swift` and will be used by task 0601 for API key storage.
- The `LLMProvider` enum is at `src/Security/LLMProvider.swift` with `.claude` and `.openai` cases. Task 0601 will use `.claude` for API key validation.
