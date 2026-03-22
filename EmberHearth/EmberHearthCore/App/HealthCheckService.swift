// HealthCheckService.swift
// EmberHearth
//
// Startup and periodic health checks for all subsystems.

import Foundation
import AppKit
import os

/// Performs structured health checks on all EmberHearth subsystems.
///
/// The health check runs on every app launch and can be triggered
/// periodically. It checks:
/// - chat.db accessibility (Full Disk Access)
/// - API key presence and validity
/// - Database integrity
/// - Internet connectivity
/// - Messages.app availability
///
/// The result is a structured `HealthStatus` that the app uses to
/// determine its initial state and surface any issues to the user.
///
/// ## Usage
/// ```swift
/// let health = HealthCheckService()
/// let status = await health.performStartupHealthCheck()
/// // Use status to update AppState
/// ```
final class HealthCheckService {

    // MARK: - Properties

    /// Logger for health check operations.
    private let logger = Logger(subsystem: "com.emberhearth.app", category: "HealthCheck")

    // MARK: - Initialization

    init() {}

    // MARK: - Startup Health Check

    /// Performs a comprehensive health check of all subsystems.
    ///
    /// This should be called early in the app launch sequence, after
    /// crash recovery but before starting the message pipeline.
    ///
    /// - Returns: A structured health status with any issues found.
    func performStartupHealthCheck() async -> HealthStatus {
        logger.info("Starting health check...")
        var issues: [HealthIssue] = []

        // 1. Check chat.db accessibility (Full Disk Access)
        let chatDbAccessible = checkChatDbAccessibility()
        if !chatDbAccessible {
            issues.append(.chatDbInaccessible)
            logger.warning("Health check: chat.db not accessible")
        }

        // 2. Check API key
        let apiKeyStatus = checkAPIKey()
        switch apiKeyStatus {
        case .missing:
            issues.append(.missingAPIKey)
            logger.warning("Health check: API key missing")
        case .present:
            // Key exists but not validated yet (validation requires network)
            break
        }

        // 3. Check database integrity
        let dbIntact = await checkDatabaseIntegrity()
        if !dbIntact {
            issues.append(.databaseCorruption)
            logger.warning("Health check: database integrity issue")
        }

        // 4. Check internet connectivity
        let hasInternet = await checkInternetConnectivity()
        if !hasInternet {
            issues.append(.noInternet)
            logger.warning("Health check: no internet connectivity")
        }

        // 5. Check Messages.app
        let messagesAvailable = checkMessagesApp()
        if !messagesAvailable {
            issues.append(.messagesAppNotAvailable)
            logger.warning("Health check: Messages.app not available")
        }

        let status = HealthStatus(issues: issues, checkedAt: Date())
        logger.info("Health check complete. Issues found: \(issues.count)")
        return status
    }

    // MARK: - Individual Checks

    /// Checks if chat.db is accessible (requires Full Disk Access).
    ///
    /// - Returns: True if the chat database file exists and is readable.
    func checkChatDbAccessibility() -> Bool {
        let chatDbPath = NSHomeDirectory() + "/Library/Messages/chat.db"
        return FileManager.default.isReadableFile(atPath: chatDbPath)
    }

    /// Checks if an API key is stored in the Keychain.
    ///
    /// - Returns: The API key status.
    func checkAPIKey() -> APIKeyStatus {
        let hasKey = KeychainManager().hasKey(for: .claude)
        return hasKey ? .present : .missing
    }

    /// Checks the memory database integrity.
    ///
    /// - Returns: True if the database is intact.
    func checkDatabaseIntegrity() async -> Bool {
        // TODO(v1.1): Wire to DatabaseManager.verifyIntegrity() for deep integrity checks
        let dbPath = CrashRecoveryManager.databasePath
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: dbPath.path) else {
            return true // Not corrupt, just doesn't exist yet
        }
        let attributes = try? fileManager.attributesOfItem(atPath: dbPath.path)
        let size = attributes?[.size] as? UInt64 ?? 0
        return size > 0
    }

    /// Checks for internet connectivity by attempting a lightweight request.
    ///
    /// Uses URLSession to check reachability — no shell execution, no ping.
    /// Targets api.anthropic.com specifically to validate the service Ember uses.
    ///
    /// - Returns: True if the internet appears to be available.
    func checkInternetConnectivity() async -> Bool {
        guard let url = URL(string: "https://api.anthropic.com") else {
            return false
        }
        var request = URLRequest(url: url, timeoutInterval: 5.0)
        request.httpMethod = "HEAD"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // Any HTTP response means we reached the server
                return httpResponse.statusCode > 0
            }
            return false
        } catch {
            logger.debug("Internet check failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Checks if Messages.app is running.
    ///
    /// Uses NSWorkspace.shared.runningApplications — no shell execution, no AppleScript.
    /// Bundle ID is com.apple.MobileSMS (Apple retained the iOS bundle ID on macOS).
    ///
    /// - Returns: True if Messages.app is currently running.
    func checkMessagesApp() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == "com.apple.MobileSMS" }
    }
}

// MARK: - Supporting Types

/// The result of a health check.
struct HealthStatus {
    /// Issues found during the health check.
    let issues: [HealthIssue]

    /// When the health check was performed.
    let checkedAt: Date

    /// Whether all checks passed with no issues.
    var isHealthy: Bool { issues.isEmpty }

    /// Maps health issues to AppError instances for display.
    var appErrors: [AppError] {
        issues.map { issue in
            switch issue {
            case .chatDbInaccessible:
                return .chatDbInaccessible
            case .missingAPIKey:
                return .noAPIKey
            case .databaseCorruption:
                return .databaseCorrupt
            case .noInternet:
                return .noInternet
            case .messagesAppNotAvailable:
                return .messagesAppUnavailable
            }
        }
    }
}

/// Individual health issues that can be detected.
enum HealthIssue: String, CaseIterable {
    /// chat.db is not readable (Full Disk Access not granted).
    case chatDbInaccessible = "chatDbInaccessible"
    /// No API key in Keychain.
    case missingAPIKey = "missingAPIKey"
    /// Database integrity check failed.
    case databaseCorruption = "databaseCorruption"
    /// No internet connection.
    case noInternet = "noInternet"
    /// Messages.app is not running.
    case messagesAppNotAvailable = "messagesAppNotAvailable"
}

/// The status of the API key.
enum APIKeyStatus {
    /// No API key found.
    case missing
    /// An API key is stored (validity not checked yet).
    case present
}
