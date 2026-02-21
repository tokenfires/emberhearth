// LaunchAtLoginManager.swift
// EmberHearth
//
// Manages Launch at Login registration using SMAppService (macOS 13+).
// Provides a simple API for toggling and querying the launch-at-login state.

import Foundation
import OSLog
import ServiceManagement

/// Manages whether EmberHearth launches automatically when the user logs in.
///
/// Uses Apple's SMAppService API (available macOS 13.0+) for proper
/// system integration. Falls back gracefully if registration fails.
///
/// Usage:
/// ```swift
/// // Check current state
/// let isEnabled = LaunchAtLoginManager.shared.isEnabled
///
/// // Toggle
/// LaunchAtLoginManager.shared.setEnabled(true)
/// ```
final class LaunchAtLoginManager {

    // MARK: - Singleton

    /// Shared instance for app-wide access.
    static let shared = LaunchAtLoginManager()

    // MARK: - Properties

    /// Logger for launch-at-login events.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "LaunchAtLogin"
    )

    /// UserDefaults key for storing the user's launch-at-login preference.
    /// This tracks what the user WANTS, which may differ from actual system state
    /// (e.g., if the user revoked permission in System Settings).
    private let preferenceKey = "launchAtLoginEnabled"

    /// The SMAppService instance for this app's login item.
    private let service = SMAppService.mainApp

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Whether launch-at-login is currently enabled at the system level.
    ///
    /// This checks the actual SMAppService status, not just the stored preference.
    /// The two can diverge if the user changes settings in System Settings > General > Login Items.
    var isEnabled: Bool {
        return service.status == .enabled
    }

    /// Whether the user has expressed a preference for launch-at-login.
    /// Returns `nil` if the user has never been asked (first launch).
    var userPreference: Bool? {
        guard UserDefaults.standard.object(forKey: preferenceKey) != nil else {
            return nil
        }
        return UserDefaults.standard.bool(forKey: preferenceKey)
    }

    /// Enables or disables launch at login.
    ///
    /// - Parameter enabled: Whether the app should launch at login.
    /// - Returns: `true` if the operation succeeded, `false` if it failed.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        // Store the user's preference regardless of whether the system call succeeds.
        // This lets us retry on next launch if the system call failed.
        UserDefaults.standard.set(enabled, forKey: preferenceKey)

        do {
            if enabled {
                try service.register()
                logger.info("Launch at login enabled successfully")
            } else {
                try service.unregister()
                logger.info("Launch at login disabled successfully")
            }
            return true
        } catch {
            logger.error("Failed to \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            return false
        }
    }

    /// Toggles the current launch-at-login state.
    ///
    /// - Returns: `true` if the operation succeeded, `false` if it failed.
    @discardableResult
    func toggle() -> Bool {
        return setEnabled(!isEnabled)
    }

    /// Ensures launch-at-login state matches the user's preference.
    ///
    /// Call this on app launch to handle cases where:
    /// - First launch: enables by default
    /// - System state diverged from preference (user changed in System Settings)
    /// - Previous registration attempt failed
    func synchronize() {
        let currentStatus = service.status

        // First launch: default to enabled
        if userPreference == nil {
            logger.info("First launch — enabling launch at login by default")
            setEnabled(true)
            return
        }

        // Check if system state matches user preference
        guard let preference = userPreference else { return }
        let systemEnabled = currentStatus == .enabled

        if preference != systemEnabled {
            logger.info("Launch at login state mismatch — preference: \(preference), system: \(systemEnabled). Attempting to sync.")

            // Only try to re-register if the user wants it enabled.
            // If they disabled it but system shows enabled, that's unusual
            // and likely means they re-enabled in System Settings, which is fine.
            if preference && !systemEnabled {
                setEnabled(true)
            }
        }

        // Log current state for debugging
        logger.debug("Launch at login status: \(currentStatus.rawValue) (preference: \(preference))")
    }

    /// Returns a human-readable description of the current status.
    /// Useful for logging and debugging.
    var statusDescription: String {
        switch service.status {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Not registered"
        case .notFound:
            return "Not found (app may have moved)"
        case .requiresApproval:
            return "Requires user approval in System Settings"
        @unknown default:
            return "Unknown status"
        }
    }
}
