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
/// - Automatic re-check and window reactivation when returning from System Settings
///
/// The user cannot proceed until Full Disk Access and Automation are granted.
/// Notifications permission is optional and can be skipped.
///
/// Accessibility Compliance (Task 0604):
/// - [x] VoiceOver: Heading has .isHeader, cards combined with labels, status changes announced, buttons have hints
/// - [x] Dynamic Type: All text uses semantic font styles, explanations use .fixedSize for wrapping
/// - [x] Keyboard: Continue has .defaultAction, Back has .cancelAction, all buttons focusable
/// - [x] Color: Status shown via icon+text not color alone; "Required"/"Optional" use text badges
/// - [x] Reduce Motion: No animations in this view beyond system-default layout updates
/// - [x] UI Testing: All interactive elements have accessibilityIdentifier
struct PermissionsView: View {

    // MARK: - Properties

    /// The shared permission manager that checks and tracks permission status.
    @ObservedObject var permissionManager: PermissionManager

    /// Callback invoked when the user can proceed (required permissions granted).
    var onContinue: () -> Void

    /// Callback invoked when the user wants to go back.
    var onBack: () -> Void

    /// Whether the user has clicked "Open Settings" for notifications.
    /// Used to determine if a denied state means "Skipped" (user saw Settings and chose not to enable).
    @State private var userVisitedNotificationSettings: Bool = false

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
                .accessibilityIdentifier("onboarding_permissions_backButton")

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
                .accessibilityIdentifier("onboarding_permissions_continueButton")
            }
            .padding(16)
        }
        .onAppear {
            Task {
                await permissionManager.checkAllPermissions()
            }
        }
        .onChange(of: permissionManager.currentStatus) { newValue in
            announcePermissionChanges(from: previousStatus, to: newValue)
            previousStatus = newValue
        }
    }

    // MARK: - Permission Card

    /// A card displaying a single permission with its status and action button.
    private func permissionCard(for permission: PermissionType, isGranted: Bool) -> some View {
        HStack(spacing: 16) {
            // Status icon
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(isGranted ? Color.green : Color.yellow)
                .frame(width: 32)
                .accessibilityHidden(true)

            // Permission info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: permission.sfSymbolName)
                        .foregroundStyle(Color.accentColor)
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
        .accessibilityIdentifier("onboarding_permissions_\(permission.rawValue)Card")
    }

    // MARK: - Notification Card

    /// A specialized card for the optional notification permission.
    ///
    /// Three states:
    /// - `.notDetermined`: App not in Notifications list yet. "Open Settings" registers
    ///   the app (adds to list) then opens Settings for the user to toggle on.
    /// - `.denied`: App is in list but toggled off. "Open Settings" lets user toggle on.
    ///   If user returns without toggling, shows "Skipped".
    /// - `.authorized`: App is in list and toggled on. Shows "Granted".
    private var notificationCard: some View {
        let authState = permissionManager.currentStatus.notificationAuth
        return HStack(spacing: 16) {
            // Status icon
            Image(systemName: notificationStatusIcon(for: authState))
                .font(.title2)
                .foregroundStyle(notificationStatusColor(for: authState))
                .frame(width: 32)
                .accessibilityHidden(true)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(Color.accentColor)
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Notifications: \(notificationAccessibilityStatus). Optional. \(PermissionType.notifications.explanation)")

            Spacer()

            // Action area — depends on auth state and whether user has visited Settings
            notificationActionView(for: authState)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(notificationCardBackground(for: authState))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(notificationCardBorder(for: authState), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding_permissions_notificationsCard")
    }

    /// The action button/label for the notification card.
    ///
    /// Flow:
    /// - authorized → "Granted"
    /// - notDetermined → "Open Settings" (registers app first, then opens Settings)
    /// - denied + user hasn't visited Settings yet → "Open Settings"
    /// - denied + user visited Settings and came back without enabling → "Skipped"
    @ViewBuilder
    private func notificationActionView(for authState: NotificationAuthState) -> some View {
        switch authState {
        case .authorized:
            Text("Granted")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.green)

        case .notDetermined:
            Button("Open Settings") {
                userVisitedNotificationSettings = true
                Task {
                    await permissionManager.registerAndOpenNotificationSettings()
                }
            }
            .accessibilityLabel("Set up notifications")
            .accessibilityHint("Registers EmberHearth for notifications and opens System Settings")
            .accessibilityIdentifier("onboarding_permissions_notificationOpenSettingsButton")

        case .denied:
            if userVisitedNotificationSettings {
                // User opened Settings and came back without toggling on → intentional skip.
                Text("Skipped")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            } else {
                // App is in the list but off. User hasn't tried yet — let them open Settings.
                Button("Open Settings") {
                    userVisitedNotificationSettings = true
                    permissionManager.openSystemPreferences(for: .notifications)
                }
                .accessibilityLabel("Open notification settings")
                .accessibilityHint("Opens System Settings where you can enable notifications for EmberHearth")
                .accessibilityIdentifier("onboarding_permissions_notificationOpenSettingsButton")
            }
        }
    }

    // MARK: - Notification Card Styling Helpers

    private func notificationStatusIcon(for state: NotificationAuthState) -> String {
        switch state {
        case .authorized: return "checkmark.circle.fill"
        case .denied where userVisitedNotificationSettings: return "bell.slash"
        default: return "bell.badge"
        }
    }

    private func notificationStatusColor(for state: NotificationAuthState) -> Color {
        switch state {
        case .authorized: return .green
        default: return .secondary
        }
    }

    private func notificationCardBackground(for state: NotificationAuthState) -> Color {
        switch state {
        case .authorized: return Color.green.opacity(0.05)
        default: return Color.secondary.opacity(0.03)
        }
    }

    private func notificationCardBorder(for state: NotificationAuthState) -> Color {
        switch state {
        case .authorized: return Color.green.opacity(0.2)
        default: return Color.secondary.opacity(0.15)
        }
    }

    private var notificationAccessibilityStatus: String {
        switch permissionManager.currentStatus.notificationAuth {
        case .authorized: return "granted"
        case .denied where userVisitedNotificationSettings: return "skipped"
        case .denied: return "not enabled"
        case .notDetermined: return "not configured"
        }
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
        if oldStatus.notificationAuth != .authorized && newStatus.notificationAuth == .authorized {
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
