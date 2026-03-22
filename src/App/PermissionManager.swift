// PermissionManager.swift
// EmberHearth
//
// Checks and manages macOS permissions required for EmberHearth to function.
// Full Disk Access and Automation are required; Notifications is optional.

import AppKit
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

// MARK: - Notification Authorization State

/// The three possible states for notification authorization.
/// Maps directly to `UNAuthorizationStatus` but simplified for our use.
enum NotificationAuthState: Equatable, Sendable, CustomStringConvertible {
    /// The app has never requested notification permission.
    /// It does not appear in the Notifications list in System Settings.
    case notDetermined
    /// The app appears in the Notifications list but is toggled off.
    case denied
    /// The app appears in the Notifications list and is toggled on.
    case authorized

    var description: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
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
    /// The notification authorization state (notDetermined / denied / authorized).
    var notificationAuth: NotificationAuthState

    /// Convenience: whether notifications are authorized.
    var notifications: Bool {
        notificationAuth == .authorized
    }

    /// Returns true if all required permissions (Full Disk Access and Automation) are granted.
    var allRequiredGranted: Bool {
        return fullDiskAccess && automation
    }

    /// Returns true if all permissions (including optional) are granted.
    var allGranted: Bool {
        return fullDiskAccess && automation && notifications
    }

    /// Returns a fresh status with all permissions in their initial state.
    static var allDenied: PermissionStatus {
        return PermissionStatus(fullDiskAccess: false, automation: false, notificationAuth: .notDetermined)
    }
}

// MARK: - PermissionManager

/// Manages checking and requesting macOS permissions for EmberHearth.
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

    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "PermissionManager"
    )

    /// Observer for System Settings deactivation (to bring our window back).
    private var workspaceObserver: NSObjectProtocol?

    // MARK: - Public API

    /// Checks the status of all permissions and updates `currentStatus`.
    @discardableResult
    func checkAllPermissions() async -> PermissionStatus {
        isChecking = true
        defer { isChecking = false }

        let fdaStatus = checkFullDiskAccess()
        let automationStatus = checkAutomation()
        let notifAuth = await checkNotificationAuthState()

        let status = PermissionStatus(
            fullDiskAccess: fdaStatus,
            automation: automationStatus,
            notificationAuth: notifAuth
        )

        currentStatus = status

        Self.logger.info(
            "Permission check: FDA=\(fdaStatus), Automation=\(automationStatus), Notifications=\(notifAuth)"
        )

        return status
    }

    /// Opens System Settings to the appropriate pane for the given permission,
    /// then watches for System Settings to lose focus so we can bring our window back.
    func openSystemPreferences(for permission: PermissionType) {
        let urlString: String
        switch permission {
        case .fullDiskAccess:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        case .automation:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        case .notifications:
            urlString = "x-apple.systempreferences:com.apple.preference.notifications"
        }

        guard let url = URL(string: urlString) else {
            Self.logger.error("Failed to create URL for System Settings pane: \(permission.rawValue)")
            return
        }

        NSWorkspace.shared.open(url)
        Self.logger.info("Opened System Settings for: \(permission.rawValue)")

        // Watch for System Settings to lose focus — when it does, bring EmberHearth back.
        startWatchingForSystemSettingsDeactivation()
    }

    /// Registers the app for notifications (adds it to the system list) then opens
    /// Notification settings so the user can toggle it on.
    ///
    /// This is the correct flow for `.notDetermined` state:
    /// 1. `requestAuthorization()` adds the app to the Notifications list in System Settings
    /// 2. Opening the settings pane lets the user toggle it on
    func registerAndOpenNotificationSettings() async {
        // Request authorization to register the app in the notifications list.
        // The user may grant directly from the system prompt, or they may deny
        // and toggle it on manually in Settings.
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            Self.logger.info("Notification registration result: \(granted ? "granted" : "denied/dismissed")")
        } catch {
            Self.logger.error("Notification registration failed: \(error.localizedDescription)")
        }

        // Re-check to pick up whatever the user chose in the system prompt.
        await checkAllPermissions()

        // If not yet authorized, open Settings so they can toggle it on.
        if currentStatus.notificationAuth != .authorized {
            openSystemPreferences(for: .notifications)
        }
    }

    // MARK: - System Settings Watcher

    /// Observes NSWorkspace for System Settings being deactivated.
    /// When detected, activates EmberHearth and re-checks permissions.
    private func startWatchingForSystemSettingsDeactivation() {
        stopWatchingForSystemSettingsDeactivation()

        let workspace = NSWorkspace.shared
        workspaceObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            let systemSettingsBundleIDs = [
                "com.apple.systempreferences",
                "com.apple.Preferences"
            ]

            let activatedBundleID = activatedApp.bundleIdentifier ?? ""
            if !systemSettingsBundleIDs.contains(activatedBundleID) {
                self?.bringWindowToFront()
                self?.stopWatchingForSystemSettingsDeactivation()

                Task { @MainActor [weak self] in
                    await self?.checkAllPermissions()
                }
            }
        }
    }

    private func stopWatchingForSystemSettingsDeactivation() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
    }

    /// Brings the EmberHearth window to front.
    private func bringWindowToFront() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.isVisible {
            window.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Individual Permission Checks

    /// Checks whether Full Disk Access is granted by attempting to open
    /// ~/Library/Messages/chat.db. Using FileHandle triggers TCC registration,
    /// which causes the app to appear in the Full Disk Access list in System Settings.
    func checkFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let chatDBPath = "\(home)/Library/Messages/chat.db"
        let chatDBURL = URL(fileURLWithPath: chatDBPath)

        do {
            let handle = try FileHandle(forReadingFrom: chatDBURL)
            handle.closeFile()
            Self.logger.debug("Full Disk Access check: granted")
            return true
        } catch {
            Self.logger.debug("Full Disk Access check: denied (\(error.localizedDescription))")
            return false
        }
    }

    /// Checks whether Automation permission is granted by running a harmless
    /// AppleScript against the Messages app.
    func checkAutomation() -> Bool {
        let script = NSAppleScript(source: "tell application \"Messages\" to get name")
        var errorInfo: NSDictionary?
        script?.executeAndReturnError(&errorInfo)

        let isGranted = (errorInfo == nil)
        Self.logger.debug("Automation check: \(isGranted ? "granted" : "denied")")
        return isGranted
    }

    /// Checks the notification authorization state, distinguishing between
    /// notDetermined (not in list), denied (in list but off), and authorized (in list and on).
    func checkNotificationAuthState() async -> NotificationAuthState {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let state: NotificationAuthState
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            state = .authorized
        case .denied:
            state = .denied
        case .notDetermined:
            state = .notDetermined
        @unknown default:
            state = .notDetermined
        }
        Self.logger.debug("Notification check: \(String(describing: state))")
        return state
    }

    /// Removes the workspace observer. Call when the manager is no longer needed.
    func cleanup() {
        stopWatchingForSystemSettingsDeactivation()
    }
}
