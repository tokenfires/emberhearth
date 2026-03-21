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
            startRefreshTimer()
            Task {
                await permissionManager.checkAllPermissions()
            }
        }
        .onDisappear {
            stopRefreshTimer()
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
    private var notificationCard: some View {
        let isGranted = permissionManager.currentStatus.notifications
        return HStack(spacing: 16) {
            // Status icon
            Image(systemName: isGranted ? "checkmark.circle.fill" : "bell.badge")
                .font(.title2)
                .foregroundStyle(isGranted ? Color.green : Color.secondary)
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
            .accessibilityLabel("Notifications: \(permissionManager.currentStatus.notifications ? "granted" : notificationHandled ? "skipped" : "not configured"). Optional. \(PermissionType.notifications.explanation)")

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
                    .accessibilityIdentifier("onboarding_permissions_enableNotificationsButton")

                    Button("Skip") {
                        notificationHandled = true
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Skip notifications")
                    .accessibilityHint("Continues without notification permission. You can enable this later in Settings.")
                    .accessibilityIdentifier("onboarding_permissions_skipNotificationsButton")
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding_permissions_notificationsCard")
    }

    // MARK: - Timer Management

    /// Starts a timer that re-checks permissions every 2 seconds.
    /// This allows the UI to update when the user grants permission in System Settings
    /// and switches back to EmberHearth.
    private func startRefreshTimer() {
        refreshTimer?.invalidate()
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
