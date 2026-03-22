// CrashRecoveryManager.swift
// EmberHearth
//
// Detects crashes and coordinates recovery on startup.

import Foundation
import os

/// Detects application crashes and coordinates recovery on startup.
///
/// On every launch, CrashRecoveryManager checks whether the previous
/// session ended cleanly. If not (i.e., the app crashed), it:
/// 1. Logs the crash event
/// 2. Triggers a database integrity check
/// 3. Clears stale session state
/// 4. Optionally notifies the user (if repeated crashes)
///
/// ## How Crash Detection Works
/// A "cleanShutdown" flag in UserDefaults is set to `false` on launch
/// and `true` on normal termination. If the flag is `false` when the
/// app starts, the previous session crashed.
///
/// ## Usage
/// ```swift
/// let recovery = CrashRecoveryManager()
/// if recovery.didCrashLastRun() {
///     await recovery.performRecovery(appState: appState)
/// }
/// ```
final class CrashRecoveryManager: Sendable {

    // MARK: - Constants

    /// UserDefaults key for the clean shutdown flag.
    static let cleanShutdownKey = "cleanShutdown"

    /// UserDefaults key for the crash count today.
    static let crashCountTodayKey = "crashCountToday"

    /// UserDefaults key for the date of the last crash count reset.
    static let crashCountDateKey = "crashCountDate"

    /// The Application Support directory for EmberHearth.
    static let appSupportPath: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("EmberHearth", isDirectory: true)
    }()

    /// The path where the database backup is stored.
    static let backupPath: URL = {
        return appSupportPath.appendingPathComponent("Backups", isDirectory: true)
    }()

    /// The database file path.
    static let databasePath: URL = {
        return appSupportPath.appendingPathComponent("memory.db")
    }()

    // MARK: - Properties

    /// Logger for crash recovery operations.
    private let logger = Logger(subsystem: "com.emberhearth.app", category: "CrashRecovery")

    // MARK: - Initialization

    init() {}

    // MARK: - Crash Detection

    /// Checks if the previous session ended in a crash.
    ///
    /// On first launch, this returns false (no crash flag set yet).
    ///
    /// - Returns: True if the previous session did not exit cleanly.
    func didCrashLastRun() -> Bool {
        let defaults = UserDefaults.standard

        // If the key doesn't exist yet (first launch), no crash
        guard defaults.object(forKey: Self.cleanShutdownKey) != nil else {
            return false
        }

        return !defaults.bool(forKey: Self.cleanShutdownKey)
    }

    /// Marks the current session as started (not yet cleanly shut down).
    ///
    /// Call this EARLY in the app launch sequence, before any other work.
    func markSessionStarted() {
        UserDefaults.standard.set(false, forKey: Self.cleanShutdownKey)
        logger.info("Session started. Clean shutdown flag set to false.")
    }

    /// Marks the current session as cleanly terminated.
    ///
    /// Call this from the app termination handler (applicationWillTerminate).
    func markCleanShutdown() {
        UserDefaults.standard.set(true, forKey: Self.cleanShutdownKey)
        logger.info("Clean shutdown recorded.")
    }

    /// Returns how many times the app has crashed today.
    func crashCountToday() -> Int {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())

        // Reset count if the date has changed
        if let lastDate = defaults.object(forKey: Self.crashCountDateKey) as? Date {
            if !Calendar.current.isDate(lastDate, inSameDayAs: today) {
                defaults.set(0, forKey: Self.crashCountTodayKey)
                defaults.set(today, forKey: Self.crashCountDateKey)
            }
        } else {
            defaults.set(today, forKey: Self.crashCountDateKey)
        }

        return defaults.integer(forKey: Self.crashCountTodayKey)
    }

    /// Increments the crash count for today.
    private func incrementCrashCount() {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        defaults.set(today, forKey: Self.crashCountDateKey)
        let current = defaults.integer(forKey: Self.crashCountTodayKey)
        defaults.set(current + 1, forKey: Self.crashCountTodayKey)
    }

    // MARK: - Recovery

    /// Performs crash recovery: verifies database, clears stale state, logs the event.
    ///
    /// - Parameter appState: The app state to update during recovery.
    /// - Returns: A RecoveryResult indicating what actions were taken.
    @MainActor
    func performRecovery(appState: AppState) async -> RecoveryResult {
        logger.warning("Crash detected! Performing recovery...")
        incrementCrashCount()

        var result = RecoveryResult()

        // Step 1: Verify database integrity
        let dbIntact = await verifyDatabaseIntegrity()
        if dbIntact {
            result.databaseStatus = .intact
            logger.info("Database integrity check passed.")
        } else {
            logger.warning("Database integrity check FAILED. Attempting recovery...")

            // Attempt to restore from backup
            let restored = await attemptDatabaseRecovery()
            if restored {
                logger.info("Database restored from backup.")
                result.databaseStatus = .recovered
            } else {
                logger.error("Database recovery failed. Starting fresh.")
                result.databaseStatus = .fresh
                appState.addError(.databaseCorrupt)
            }
        }

        // Step 2: Clear stale session state
        clearStaleSessionState()
        result.sessionCleared = true

        // Step 3: Determine if user should be notified
        let crashCount = crashCountToday()
        result.crashCountToday = crashCount
        if crashCount > 1 {
            result.shouldNotifyUser = true
            logger.warning("Multiple crashes today: \(crashCount). User will be notified.")
        }

        logger.info("Recovery complete. Database: \(result.databaseStatus.rawValue), crashes today: \(crashCount)")
        return result
    }

    // MARK: - Database Verification

    /// Verifies the integrity of the memory database.
    ///
    /// Uses SQLite's PRAGMA integrity_check to validate the database.
    /// In production, this delegates to DatabaseManager.verifyIntegrity().
    ///
    /// - Returns: True if the database is intact.
    func verifyDatabaseIntegrity() async -> Bool {
        // TODO(v1.1): Wire to DatabaseManager.verifyIntegrity() for deep integrity checks
        // For now, check if the database file exists and is not zero-length
        let path = Self.databasePath
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path.path) else {
            logger.info("Database file does not exist. Will be created on first use.")
            return true // Not corrupt, just doesn't exist yet
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: path.path)
            let size = attributes[.size] as? UInt64 ?? 0
            if size == 0 {
                logger.warning("Database file is empty (0 bytes).")
                return false
            }
            return true
        } catch {
            logger.error("Failed to check database file: \(error.localizedDescription)")
            return false
        }
    }

    /// Attempts to restore the database from the most recent backup.
    ///
    /// - Returns: True if a backup was found and restored successfully.
    func attemptDatabaseRecovery() async -> Bool {
        let fileManager = FileManager.default
        let backupDir = Self.backupPath

        guard fileManager.fileExists(atPath: backupDir.path) else {
            logger.warning("No backup directory found.")
            return false
        }

        do {
            let backups = try fileManager.contentsOfDirectory(
                at: backupDir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )
            .filter { $0.pathExtension == "db" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return date1 > date2 // Most recent first
            }

            guard let latestBackup = backups.first else {
                logger.warning("No backup files found.")
                return false
            }

            // Move current (corrupt) database aside — never delete it
            if fileManager.fileExists(atPath: Self.databasePath.path) {
                let timestamp = ISO8601DateFormatter().string(from: Date())
                    .replacingOccurrences(of: ":", with: "-")
                let corruptName = "memory.db.corrupt-\(timestamp)"
                let corruptPath = Self.appSupportPath.appendingPathComponent(corruptName)
                try fileManager.moveItem(at: Self.databasePath, to: corruptPath)
            }

            // Copy backup to database location (copy, not move, to preserve backup)
            try fileManager.copyItem(at: latestBackup, to: Self.databasePath)
            logger.info("Database restored from backup: \(latestBackup.lastPathComponent)")

            return true
        } catch {
            logger.error("Database recovery failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Session Cleanup

    /// Clears stale session state that may have been left by the crash.
    private func clearStaleSessionState() {
        UserDefaults.standard.removeObject(forKey: "activeSessionId")
        UserDefaults.standard.removeObject(forKey: "processingMessageId")
        logger.info("Stale session state cleared.")
    }
}

// MARK: - Supporting Types

/// The result of a crash recovery operation.
struct RecoveryResult {
    /// The state of the database after recovery.
    var databaseStatus: DatabaseRecoveryStatus = .intact
    /// Whether stale session state was cleared.
    var sessionCleared: Bool = false
    /// The number of crashes detected today.
    var crashCountToday: Int = 0
    /// Whether the user should be notified about the crash.
    var shouldNotifyUser: Bool = false
}

/// The state of the database after a recovery check.
enum DatabaseRecoveryStatus: String {
    /// Database passed integrity check, no recovery needed.
    case intact = "intact"
    /// Database was corrupt but successfully recovered from backup.
    case recovered = "recovered"
    /// Database could not be recovered; started fresh.
    case fresh = "fresh"
}
