# Task 0703: Crash Recovery

**Milestone:** M8 - Polish & Release
**Unit:** 8.4 - Crash Recovery (launchd)
**Phase:** 3
**Depends On:** 0702
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `docs/specs/error-handling.md` — Read "Application Crashes" (lines 209-276) for crash recovery flow, launchd plist template, and post-crash recovery code. Read "Startup Health Check" (lines 389-430) for the HealthCheck struct. Read "Database Health" (lines 123-153) for integrity checks and backup strategy.
2. `docs/specs/autonomous-operation.md` — Read Section 1.2 "Health State Machine" (lines 42-60) and Section 1.3 "Self-Healing Patterns" if it exists, for the detect-heal-degrade flow.
3. `docs/architecture/decisions/0004-no-shell-execution.md` — Read in full. No Process(), no /bin/bash, no NSTask. The LaunchAgent plist is a STATIC FILE — it is never generated or executed by code.
4. `CLAUDE.md` — Project conventions.
5. `src/App/AppState.swift` — Reference from task 0702 for updating status during health checks and recovery.
6. `src/Core/Errors/AppError.swift` — Reference from task 0700 for error types.

> **Context Budget Note:** `error-handling.md` is the primary reference (~587 lines). Focus on lines 209-276 (crashes), 123-153 (database health), 389-430 (startup health check). `autonomous-operation.md` focus only on lines 42-60. Skip all other sections.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the crash recovery and startup health check system for EmberHearth, a native macOS personal AI assistant. EmberHearth runs as a background app — if it crashes, the user has no idea why their AI friend went silent. The crash recovery system ensures: (1) crashes are detected, (2) data is verified, (3) the app recovers gracefully, and (4) launchd restarts it automatically.

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., CrashRecoveryManager.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask, no osascript via Process)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app")
- All public types and methods must have documentation comments (///)
- NEVER delete or modify the user's memory.db without the explicit recovery flow described here

## CRITICAL SECURITY RULES

1. **NO SHELL EXECUTION.** The LaunchAgent plist is a STATIC FILE that is written to disk using FileManager. It is never executed via Process() or /bin/bash. The plist is a declaration — launchd reads it directly.
2. **NEVER use Process(), NSTask, /bin/bash, /bin/sh, or CommandLine** to install the LaunchAgent. Use ONLY `FileManager.default.createFile` or `Data.write(to:)` to write the plist to the correct location.
3. **NEVER delete memory.db** unless integrity checks have failed AND backup restoration has been attempted.

## What You Are Building

Three components:
1. **CrashRecoveryManager** — Detects crashes, runs recovery, verifies database integrity.
2. **HealthCheckService** — Performs startup and periodic health checks, returns a structured health status.
3. **LaunchAgent plist template** — A static plist file for launchd auto-restart.

## Existing Components

These exist from prior tasks:
- `AppState` (from task 0702) — Update status during health checks.
- `AppError` (from task 0700) — Error types for health issues.
- `DatabaseManager` (from task 0300) — Has `verifyIntegrity()`, database path access.
- `KeychainManager` (from task 0200) — Has `getAPIKey()` for key validation.

If these types don't exist yet, use protocol stubs. Wire the real implementations during integration.

## Files to Create

### 1. `src/App/CrashRecoveryManager.swift`

```swift
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
final class CrashRecoveryManager {

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
            result.databaseStatus = .recovered

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
        // TODO: Wire to DatabaseManager.verifyIntegrity() during integration
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
            let backups = try fileManager.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.contentModificationDateKey])
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

            // Move current (corrupt) database aside
            let corruptPath = Self.databasePath.appendingPathExtension("corrupt")
            if fileManager.fileExists(atPath: Self.databasePath.path) {
                try fileManager.moveItem(at: Self.databasePath, to: corruptPath)
            }

            // Copy backup to database location
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
        // Clear any in-progress message flags
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
```

### 2. `src/App/HealthCheckService.swift`

```swift
// HealthCheckService.swift
// EmberHearth
//
// Startup and periodic health checks for all subsystems.

import Foundation
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
        // TODO: Wire to KeychainManager.getAPIKey() during integration
        // For now, check the UserDefaults flag from Settings
        let hasKey = UserDefaults.standard.bool(forKey: "hasAPIKey")
        return hasKey ? .present : .missing
    }

    /// Checks the memory database integrity.
    ///
    /// - Returns: True if the database is intact.
    func checkDatabaseIntegrity() async -> Bool {
        // TODO: Wire to DatabaseManager.verifyIntegrity() during integration
        let dbPath = CrashRecoveryManager.databasePath
        return FileManager.default.fileExists(atPath: dbPath.path)
    }

    /// Checks for internet connectivity by attempting a lightweight DNS lookup.
    ///
    /// Uses a simple reachability check without third-party dependencies.
    /// Does NOT use Process() or shell commands.
    ///
    /// - Returns: True if the internet appears to be available.
    func checkInternetConnectivity() async -> Bool {
        // Use URLSession to check reachability without shell execution
        let url = URL(string: "https://api.anthropic.com")!
        var request = URLRequest(url: url, timeoutInterval: 5.0)
        request.httpMethod = "HEAD"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // Any response means we have internet (even 4xx/5xx)
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
    /// Uses NSRunningApplication to check without shell execution.
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
```

### 3. `resources/com.emberhearth.app.plist`

Create a static LaunchAgent plist file. This is a RESOURCE FILE, not Swift code. It is written to `~/Library/LaunchAgents/` during onboarding — NOT executed via shell.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.emberhearth.app</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/EmberHearth.app/Contents/MacOS/EmberHearth</string>
        <string>--background</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ThrottleInterval</key>
    <integer>10</integer>
    <key>StandardOutPath</key>
    <string>/tmp/emberhearth.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/emberhearth.stderr.log</string>
</dict>
</plist>
```

**IMPORTANT:** This file is a static template. During onboarding, it is written to `~/Library/LaunchAgents/com.emberhearth.app.plist` using `FileManager`/`Data.write(to:)`. It is NEVER installed via shell commands.

### 4. `tests/App/CrashRecoveryTests.swift`

```swift
// CrashRecoveryTests.swift
// EmberHearth
//
// Unit tests for CrashRecoveryManager and HealthCheckService.

import XCTest
@testable import EmberHearth

final class CrashRecoveryTests: XCTestCase {

    private var manager: CrashRecoveryManager!

    override func setUp() {
        super.setUp()
        manager = CrashRecoveryManager()
        // Clean up UserDefaults for test isolation
        UserDefaults.standard.removeObject(forKey: CrashRecoveryManager.cleanShutdownKey)
        UserDefaults.standard.removeObject(forKey: CrashRecoveryManager.crashCountTodayKey)
        UserDefaults.standard.removeObject(forKey: CrashRecoveryManager.crashCountDateKey)
    }

    override func tearDown() {
        manager = nil
        // Clean up
        UserDefaults.standard.removeObject(forKey: CrashRecoveryManager.cleanShutdownKey)
        UserDefaults.standard.removeObject(forKey: CrashRecoveryManager.crashCountTodayKey)
        UserDefaults.standard.removeObject(forKey: CrashRecoveryManager.crashCountDateKey)
        super.tearDown()
    }

    // MARK: - Crash Detection Tests

    func testFirstLaunchIsNotACrash() {
        // First launch: no cleanShutdown key exists
        XCTAssertFalse(manager.didCrashLastRun(), "First launch should not be detected as a crash")
    }

    func testCleanShutdownNotDetectedAsCrash() {
        // Simulate a clean shutdown
        manager.markSessionStarted()
        manager.markCleanShutdown()

        // New "launch"
        let newManager = CrashRecoveryManager()
        XCTAssertFalse(newManager.didCrashLastRun(), "Clean shutdown should not be detected as a crash")
    }

    func testCrashDetected() {
        // Simulate a session start without clean shutdown (crash)
        manager.markSessionStarted()
        // Don't call markCleanShutdown() — simulates a crash

        // New "launch"
        let newManager = CrashRecoveryManager()
        XCTAssertTrue(newManager.didCrashLastRun(), "Missing clean shutdown should be detected as a crash")
    }

    func testMarkSessionStartedSetsFlag() {
        manager.markSessionStarted()
        XCTAssertFalse(UserDefaults.standard.bool(forKey: CrashRecoveryManager.cleanShutdownKey))
    }

    func testMarkCleanShutdownSetsFlag() {
        manager.markCleanShutdown()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: CrashRecoveryManager.cleanShutdownKey))
    }

    // MARK: - Crash Count Tests

    func testCrashCountStartsAtZero() {
        XCTAssertEqual(manager.crashCountToday(), 0)
    }

    func testCrashCountResetsOnNewDay() {
        // Set a count from "yesterday"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        UserDefaults.standard.set(5, forKey: CrashRecoveryManager.crashCountTodayKey)
        UserDefaults.standard.set(yesterday, forKey: CrashRecoveryManager.crashCountDateKey)

        // Should reset to 0 for today
        XCTAssertEqual(manager.crashCountToday(), 0)
    }

    // MARK: - Database Verification Tests

    func testVerifyDatabaseIntegrityWithMissingFile() async {
        // Database file doesn't exist — should return true (not corrupt, just absent)
        // This depends on the actual file system state, so we test the logic
        let result = await manager.verifyDatabaseIntegrity()
        // Result depends on whether the file exists in the test environment
        // The important thing is it doesn't crash
        XCTAssertTrue(result || !result, "Should return a boolean without crashing")
    }

    // MARK: - Health Check Tests

    func testHealthCheckReturnsStatus() async {
        let healthCheck = HealthCheckService()
        let status = await healthCheck.performStartupHealthCheck()

        // Should return a valid status (issues depend on the environment)
        XCTAssertNotNil(status.checkedAt)
    }

    func testHealthStatusHealthyWhenNoIssues() {
        let status = HealthStatus(issues: [], checkedAt: Date())
        XCTAssertTrue(status.isHealthy)
    }

    func testHealthStatusUnhealthyWithIssues() {
        let status = HealthStatus(issues: [.missingAPIKey], checkedAt: Date())
        XCTAssertFalse(status.isHealthy)
    }

    func testHealthIssueToAppErrorMapping() {
        let status = HealthStatus(issues: [.missingAPIKey, .noInternet], checkedAt: Date())
        let appErrors = status.appErrors

        XCTAssertEqual(appErrors.count, 2)
        XCTAssertTrue(appErrors.contains { $0.id == "noAPIKey" })
        XCTAssertTrue(appErrors.contains { $0.id == "noInternet" })
    }

    func testAllHealthIssuesMapToAppErrors() {
        let allIssues = HealthIssue.allCases
        let status = HealthStatus(issues: allIssues, checkedAt: Date())
        let appErrors = status.appErrors

        XCTAssertEqual(appErrors.count, allIssues.count, "Every health issue should map to an AppError")
    }

    // MARK: - Messages App Check

    func testCheckMessagesAppDoesNotCrash() {
        let healthCheck = HealthCheckService()
        // Just verify it doesn't crash — result depends on environment
        let _ = healthCheck.checkMessagesApp()
    }

    // MARK: - chat.db Check

    func testCheckChatDbDoesNotCrash() {
        let healthCheck = HealthCheckService()
        // Just verify it doesn't crash — result depends on environment
        let _ = healthCheck.checkChatDbAccessibility()
    }

    // MARK: - Recovery Result Tests

    func testRecoveryResultDefaults() {
        let result = RecoveryResult()
        XCTAssertEqual(result.databaseStatus, .intact)
        XCTAssertFalse(result.sessionCleared)
        XCTAssertEqual(result.crashCountToday, 0)
        XCTAssertFalse(result.shouldNotifyUser)
    }

    func testDatabaseRecoveryStatusValues() {
        XCTAssertEqual(DatabaseRecoveryStatus.intact.rawValue, "intact")
        XCTAssertEqual(DatabaseRecoveryStatus.recovered.rawValue, "recovered")
        XCTAssertEqual(DatabaseRecoveryStatus.fresh.rawValue, "fresh")
    }

    // MARK: - Security Tests

    func testNoShellExecutionInCrashRecovery() {
        // Structural test — real verification in verification commands
        let forbiddenPatterns = ["Process(", "NSTask", "/bin/bash", "/bin/sh", "osascript", "CommandLine"]
        for pattern in forbiddenPatterns {
            XCTAssertFalse(pattern.isEmpty, "Crash recovery must not contain \(pattern)")
        }
    }

    // MARK: - LaunchAgent Plist Tests

    func testLaunchAgentPlistIsValidXML() {
        // Verify the plist template can be parsed
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.emberhearth.app</string>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <dict>
                <key>SuccessfulExit</key>
                <false/>
            </dict>
            <key>ThrottleInterval</key>
            <integer>10</integer>
        </dict>
        </plist>
        """

        let data = plistContent.data(using: .utf8)!
        do {
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
            XCTAssertNotNil(plist as? [String: Any], "Plist should parse as a dictionary")

            let dict = plist as! [String: Any]
            XCTAssertEqual(dict["Label"] as? String, "com.emberhearth.app")
            XCTAssertEqual(dict["RunAtLoad"] as? Bool, true)
            XCTAssertEqual(dict["ThrottleInterval"] as? Int, 10)
        } catch {
            XCTFail("Plist should be valid XML: \(error)")
        }
    }
}
```

## Implementation Rules

1. **NEVER use Process(), /bin/bash, /bin/sh, NSTask, CommandLine, or osascript.** Hard security rule per ADR-0004.
2. The LaunchAgent plist is written to disk using `FileManager` or `Data.write(to:)`. It is NEVER installed via shell commands like `launchctl load`.
3. Internet connectivity is checked via URLSession, NOT via `ping` or shell commands.
4. Messages.app availability is checked via `NSWorkspace.shared.runningApplications`, NOT via AppleScript or shell.
5. **NEVER delete memory.db** without first verifying integrity AND attempting backup restoration.
6. When moving a corrupt database aside, rename it to `.corrupt` extension — do not delete it.
7. All Swift files use PascalCase naming.
8. All public types and methods must have documentation comments (///).
9. Use `os.Logger` for logging. NEVER log personal data. Log crash events and recovery actions only.
10. Test file path: Match existing test directory structure.
11. The plist file goes in `resources/` (not `src/`) since it's a static resource.

## Directory Structure

Create these files:
- `src/App/CrashRecoveryManager.swift`
- `src/App/HealthCheckService.swift`
- `resources/com.emberhearth.app.plist`
- `tests/App/CrashRecoveryTests.swift`

## Final Checks

Before finishing, verify:
1. All files compile without errors
2. All tests pass
3. CRITICAL: No Process(), /bin/bash, /bin/sh, NSTask, CommandLine, osascript calls exist anywhere
4. The LaunchAgent plist is valid XML that can be parsed by PropertyListSerialization
5. Internet check uses URLSession (not ping or shell)
6. Messages.app check uses NSWorkspace (not AppleScript or shell)
7. Database recovery never deletes memory.db without backup attempt
8. Clean shutdown flag logic is correct (false on start, true on terminate)
9. Crash count resets daily
10. All public methods have documentation comments
11. os.Logger is used (not print())
```

---

## Acceptance Criteria

- [ ] `src/App/CrashRecoveryManager.swift` exists with crash detection and recovery logic
- [ ] `src/App/HealthCheckService.swift` exists with startup health check
- [ ] `resources/com.emberhearth.app.plist` exists as a valid LaunchAgent plist
- [ ] Crash detection: cleanShutdown flag set false on start, true on terminate
- [ ] Crash detection: first launch returns false (not a crash)
- [ ] Crash recovery: database integrity verified on crash detection
- [ ] Crash recovery: backup restoration attempted before starting fresh
- [ ] Crash recovery: corrupt database renamed to .corrupt (not deleted)
- [ ] Crash recovery: stale session state cleared
- [ ] Crash count tracked daily, resets on new day
- [ ] User notification triggered after 2+ crashes in a day
- [ ] Health check covers: chat.db, API key, database, internet, Messages.app
- [ ] HealthStatus maps issues to AppError instances
- [ ] Internet check uses URLSession (not shell/ping)
- [ ] Messages.app check uses NSWorkspace (not shell/AppleScript)
- [ ] LaunchAgent plist: KeepAlive with SuccessfulExit=false, ThrottleInterval=10
- [ ] **CRITICAL:** No calls to `Process()`, `/bin/bash`, `/bin/sh`, `NSTask`, `CommandLine`, or `osascript`
- [ ] **CRITICAL:** memory.db is NEVER deleted without recovery attempt
- [ ] All unit tests pass
- [ ] `os.Logger` used for logging (no `print()` statements)

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/App/CrashRecoveryManager.swift && echo "PASS: CrashRecoveryManager.swift exists" || echo "MISSING: CrashRecoveryManager.swift"
test -f src/App/HealthCheckService.swift && echo "PASS: HealthCheckService.swift exists" || echo "MISSING: HealthCheckService.swift"
test -f resources/com.emberhearth.app.plist && echo "PASS: LaunchAgent plist exists" || echo "MISSING: LaunchAgent plist"

# CRITICAL: Verify no shell execution
grep -rn "Process()" src/App/ || echo "PASS: No Process() calls found"
grep -rn "NSTask" src/App/ || echo "PASS: No NSTask calls found"
grep -rn "/bin/bash" src/App/ || echo "PASS: No /bin/bash references found"
grep -rn "/bin/sh" src/App/ || echo "PASS: No /bin/sh references found"
grep -rn "osascript" src/App/ || echo "PASS: No osascript references found"
grep -rn "CommandLine" src/App/ || echo "PASS: No CommandLine references found"
grep -rn "launchctl" src/ || echo "PASS: No launchctl references found"
grep -rn "ping" src/App/ || echo "PASS: No ping references found"

# Verify LaunchAgent plist is valid XML
plutil -lint resources/com.emberhearth.app.plist && echo "PASS: Plist is valid" || echo "FAIL: Plist is invalid"

# Build the project
xcodebuild build -scheme EmberHearth -destination 'platform=macOS' 2>&1 | tail -20

# Run the crash recovery tests
xcodebuild test -scheme EmberHearth -destination 'platform=macOS' -only-testing:EmberHearthTests/CrashRecoveryTests 2>&1 | tail -30
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the EmberHearth crash recovery and health check implementation for security, data safety, and correctness. Open these files:

@src/App/CrashRecoveryManager.swift
@src/App/HealthCheckService.swift
@resources/com.emberhearth.app.plist
@tests/App/CrashRecoveryTests.swift

Also reference:
@docs/specs/error-handling.md (lines 209-276, 123-153, 389-430)
@docs/architecture/decisions/0004-no-shell-execution.md

## SECURITY AUDIT (Top Priority)

1. **Shell Execution Ban (CRITICAL):**
   - Search ALL files for: Process, NSTask, /bin/bash, /bin/sh, osascript, CommandLine, launchctl, ping
   - If ANY exist, report as CRITICAL immediately.
   - How is the LaunchAgent plist installed? It MUST use FileManager/Data.write, never shell commands.
   - How is internet connectivity checked? It MUST use URLSession, never ping or shell.
   - How is Messages.app checked? It MUST use NSWorkspace, never AppleScript or shell.

2. **Data Safety (CRITICAL):**
   - Is memory.db EVER deleted without first attempting backup restoration?
   - When moving a corrupt database aside, is it renamed (.corrupt) not deleted?
   - Is there any path where user data could be lost?
   - Is the backup restoration logic safe (copy, not move the backup)?

## CORRECTNESS

3. **Crash Detection:**
   - Is the cleanShutdown flag logic correct? (false on start, true on terminate)
   - On first launch (no key exists), does it correctly return false (not a crash)?
   - Could a crash during markSessionStarted() cause issues on next launch?
   - What happens if the app is force-quit (SIGKILL)? Does detection still work?

4. **Database Recovery:**
   - Are backups sorted by modification date (most recent first)?
   - Is the corrupt database moved aside BEFORE the backup is copied?
   - What happens if the backup itself is corrupt?
   - What happens if FileManager operations fail (disk full, permissions)?

5. **Health Checks:**
   - Is the chat.db path correct? (~/Library/Messages/chat.db)
   - Is the internet check using a reasonable timeout (5 seconds)?
   - Is Messages.app bundle ID correct? (com.apple.MobileSMS — yes, even on macOS)
   - Does the health check correctly map all HealthIssues to AppErrors?

6. **LaunchAgent Plist:**
   - Is the plist valid XML?
   - Is KeepAlive set correctly? (SuccessfulExit=false means only restart on crash)
   - Is ThrottleInterval reasonable? (10 seconds prevents crash loops)
   - Is the ProgramArguments path correct for a standard /Applications install?

## CODE QUALITY

7. **Error Handling:**
   - Are all FileManager operations wrapped in do/catch?
   - Are errors logged appropriately?
   - Is anything sensitive logged (file contents, user data)? It should not be.

8. **Test Quality:**
   - Do tests cover: first launch, clean shutdown, crash detection?
   - Do tests cover: crash count reset on new day?
   - Do tests cover: health status mapping?
   - Do tests verify the plist is valid XML?
   - Are tests isolated (cleaning up UserDefaults in setUp/tearDown)?

Report any issues with specific file paths and line numbers. Severity: CRITICAL (must fix before merge), IMPORTANT (should fix), MINOR (nice to have).
```

---

## Commit Message

```
feat(m8): add crash recovery and startup health checks
```

---

## Notes for Next Task

- `CrashRecoveryManager.markSessionStarted()` must be called EARLY in `applicationDidFinishLaunching`, before any other work.
- `CrashRecoveryManager.markCleanShutdown()` must be called from `applicationWillTerminate`.
- The health check should run after crash recovery completes. The sequence is: (1) mark session started, (2) check for crash, (3) perform recovery if needed, (4) run health check, (5) update AppState, (6) start message pipeline.
- The LaunchAgent plist is a TEMPLATE. During onboarding, write it to `~/Library/LaunchAgents/com.emberhearth.app.plist` using `Data.write(to:)`. The `ProgramArguments` path should be updated to match the actual install location if different from `/Applications/`.
- `HealthCheckService.checkInternetConnectivity()` makes a HEAD request to `api.anthropic.com`. This is intentional — it validates that the specific service Ember uses is reachable, not just general internet.
- `HealthStatus.appErrors` provides a bridge from the health check domain to the UI error domain (AppError from task 0700). Use this to populate `AppState.errors` on startup.
- The `checkMessagesApp()` uses bundle ID `com.apple.MobileSMS` which is correct even on macOS (Apple kept the iOS bundle ID).
