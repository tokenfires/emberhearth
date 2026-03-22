// PermissionManager.swift
// EmberHearth
//
// Checks and manages macOS permissions required for EmberHearth to function.
// Full Disk Access and Automation are required; Notifications is optional.

import AppKit
import Combine
import Foundation
import UserNotifications
import os
import Carbon

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

    /// The raw notification authorization status, used to distinguish
    /// .notDetermined (can prompt) from .denied (must open Settings).
    @Published var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

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
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        case .automation:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        case .notifications:
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

    /// Checks whether Full Disk Access is granted by attempting to open
    /// ~/Library/Messages/chat.db via FileHandle.
    ///
    /// `FileManager.isReadableFile` is unreliable for TCC-gated paths — it
    /// can return false even when FDA is granted. FileHandle(forReadingAtPath:)
    /// performs the actual open(2) syscall that TCC gates, so it accurately
    /// reflects whether FDA has been granted.
    ///
    /// - Returns: true if the file can be opened (FDA granted), false otherwise.
    func checkFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let chatDBPath = "\(home)/Library/Messages/chat.db"
        if let fh = FileHandle(forReadingAtPath: chatDBPath) {
            fh.closeFile()
            Self.logger.debug("Full Disk Access check: granted")
            return true
        }
        Self.logger.debug("Full Disk Access check: denied")
        return false
    }

    /// Checks whether Automation permission is granted for the Messages app,
    /// prompting the user via the system TCC dialog if not yet decided.
    ///
    /// Passes `askUserIfNeeded: true` to `AEDeterminePermissionToAutomateTarget`
    /// so macOS shows the permission prompt on first call without requiring
    /// Messages to be running. This is the correct API for requesting automation
    /// permission — it does not launch Messages or send any actual Apple Events.
    ///
    /// - Returns: true if Automation for Messages is granted, false otherwise.
    func checkAutomation() -> Bool {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.MobileSMS")
        let status = AEDeterminePermissionToAutomateTarget(
            target.aeDesc, typeWildCard, typeWildCard, true
        )

        switch status {
        case noErr:
            Self.logger.debug("Automation check: granted")
            return true
        case -1744: // errAEEventNotPermitted — explicitly denied
            Self.logger.debug("Automation check: denied")
            return false
        case -600: // procNotFound — Messages not running, permission not yet determined
            Self.logger.debug("Automation check: not determined (Messages not running)")
            return false
        default:
            Self.logger.debug("Automation check: unknown status \(status)")
            return false
        }
    }

    /// Checks whether Notification permission is granted.
    ///
    /// - Returns: true if notifications are authorized, false otherwise.
    func checkNotifications() async -> Bool {
        guard Bundle.main.bundleIdentifier != nil else {
            Self.logger.warning("Skipping notification check: no bundle identifier")
            return false
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationAuthorizationStatus = settings.authorizationStatus
        // Include .provisional — macOS 26 may grant provisional authorization.
        let isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        Self.logger.debug("Notification check: \(isAuthorized ? "granted" : "denied") (raw=\(settings.authorizationStatus.rawValue))")
        return isAuthorized
    }

    /// Requests notification permission from the user.
    ///
    /// - Returns: true if the user granted permission, false otherwise.
    func requestNotificationPermission() async -> Bool {
        guard Bundle.main.bundleIdentifier != nil else {
            Self.logger.warning("Skipping notification request: no bundle identifier")
            return false
        }
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
