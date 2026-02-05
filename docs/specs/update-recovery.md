# Update Recovery Specification

**Version:** 1.0
**Date:** February 5, 2026
**Status:** Pre-Implementation
**Depends On:** `specs/autonomous-operation.md`

---

## Overview

This specification addresses user-facing recovery paths when updates go wrong. While `autonomous-operation.md` covers the technical mechanisms (self-healing, migrations, forward compatibility), this document answers:

> "What does the user actually do if my update breaks things?"

---

## Philosophy

### The Reality of Consumer Software Updates

Users don't think about software updates until something breaks. When it does:

1. **They don't know what happened** — "It was working yesterday"
2. **They can't diagnose** — "I'm not a computer person"
3. **They want it fixed, not explained** — "Just make it work again"
4. **They remember bad experiences** — One botched update = lost trust

### Our Commitments

| Commitment | Implementation |
|------------|----------------|
| Updates never lose data | Pre-update backup, forward-compatible migrations |
| Users are never stuck | Recovery options at every level |
| Problems are explained, not hidden | Ember communicates issues naturally |
| Manual override exists | Power users can export/restore |

---

## Part 1: Update Verification

### 1.1 Post-Update Health Check

After every update, EmberHearth runs a comprehensive verification sequence:

```
┌─────────────────────────────────────────────────────────────────┐
│                   POST-UPDATE VERIFICATION                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [App Launches After Update]                                    │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │ VERSION CHECK   │◄── Compare running version to expected     │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │ DATABASE CHECK  │◄── PRAGMA integrity_check                  │
│  │                 │◄── Schema version matches expectations     │
│  │                 │◄── Migration completed successfully        │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │ CONFIG CHECK    │◄── Config loads without error              │
│  │                 │◄── Required fields present                 │
│  │                 │◄── API key still valid                     │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │ SERVICE CHECK   │◄── All XPC services launch                 │
│  │                 │◄── iMessage access works                   │
│  │                 │◄── Health monitors start                   │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│      [Pass]───────────────────[Fail]                            │
│        │                         │                              │
│        ▼                         ▼                              │
│   Normal Operation         Recovery Mode                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Verification Results

```swift
struct UpdateVerification {
    enum Result {
        case success
        case partialSuccess(issues: [Issue])  // Works, but with limitations
        case recoveryNeeded(reason: RecoveryReason)
        case criticalFailure(reason: CriticalReason)
    }

    enum Issue {
        case migrationWarning(String)      // Data migrated but some loss
        case configReset(fields: [String]) // Some settings reset to default
        case permissionChange(String)      // May need re-authorization
    }

    enum RecoveryReason {
        case databaseCorruption
        case migrationFailed
        case configInvalid
        case serviceWontStart
    }

    enum CriticalReason {
        case appWontLaunch        // Caught by Sparkle, rolls back install
        case dataUnrecoverable    // Backup restore required
    }
}
```

### 1.3 Silent vs. Communicated Issues

| Verification Result | User Experience |
|--------------------|-----------------|
| **Success** | Nothing visible. App works normally. |
| **Partial Success** | Ember mentions it naturally in first conversation |
| **Recovery Needed** | App enters recovery mode, shows simple options |
| **Critical Failure** | Sparkle rolls back install (rare) |

**Partial Success Example (Ember's first message after update):**

> "Hey! I just got an update. Everything's working, though I noticed a few of my older memories might be slightly fuzzy now. Nothing important lost though!"

---

## Part 2: Recovery Modes

### 2.1 Automatic Recovery (Invisible to User)

Most issues heal automatically per `autonomous-operation.md`:

```
┌─────────────────────────────────────────────────────────┐
│  AUTOMATIC RECOVERY (User Never Knows)                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  • Minor database corruption → Repair via VACUUM        │
│  • Migration interrupted → Resume from checkpoint       │
│  • Config field missing → Apply sensible default        │
│  • Service crash → Restart via launchd                  │
│  • Temporary file corruption → Regenerate               │
│                                                         │
│  Logged internally, never shown to user                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Assisted Recovery (Minimal User Involvement)

When automatic recovery can't fully heal, the app guides the user:

```
┌─────────────────────────────────────────────────────────┐
│  ASSISTED RECOVERY (Simple Choices)                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Ember had trouble with the recent update.              │
│                                                         │
│  Your memories and conversations are safe.              │
│                                                         │
│  [Let Ember Fix It]     ← Recommended                   │
│  [Show Me Options]      ← For curious users             │
│                                                         │
│  ─────────────────────────────────────────────────      │
│  What happened: Your settings needed to be updated      │
│  but something went wrong. Ember can restore your       │
│  previous settings and try again.                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**"Let Ember Fix It" does:**
1. Restore from pre-update backup
2. Retry migration with more conservative settings
3. If still fails, apply defaults and preserve what data we can
4. Report anonymously if telemetry enabled

**"Show Me Options" reveals:**
```
┌─────────────────────────────────────────────────────────┐
│  Recovery Options                                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [ ] Restore from backup (Feb 5, 2026 2:30 PM)          │
│      Returns everything to how it was before the update │
│                                                         │
│  [ ] Start fresh                                        │
│      Keeps your API key but resets other settings       │
│                                                         │
│  [ ] Export my data                                     │
│      Download all your memories and settings            │
│                                                         │
│  [ ] Contact support                                    │
│      Opens email with diagnostic info attached          │
│                                                         │
│                                [Cancel]  [Continue]     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 2.3 Manual Recovery (Power Users)

For users who want full control, available in Settings → Advanced:

```
Settings → Advanced → Data Management

┌─────────────────────────────────────────────────────────┐
│  Data Management                                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Backups                                                │
│  ────────                                               │
│  Automatic backups: ON                                  │
│  Last backup: Today at 3:00 PM                          │
│  Backup location: ~/Library/Application Support/       │
│                    EmberHearth/Backups                  │
│                                                         │
│  [View Backups]  [Create Backup Now]                    │
│                                                         │
│  Export & Import                                        │
│  ───────────────                                        │
│  [Export All Data]  ← ZIP file with memories, config   │
│  [Import Data]      ← Restore from export              │
│                                                         │
│  Recovery                                               │
│  ────────                                               │
│  [Restore from Backup...]                               │
│  [Reset to Defaults]  ← Preserves API key only         │
│  [View Diagnostics]   ← Technical health info          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Part 3: Backup System

### 3.1 Backup Types

| Type | Trigger | Retention | Contents |
|------|---------|-----------|----------|
| **Update Backup** | Before each update | 3 versions | Full snapshot |
| **Daily Backup** | 3 AM if app ran that day | 7 days | Incremental |
| **Manual Backup** | User request | Forever | Full snapshot |
| **Export** | User request | Forever | Portable format |

### 3.2 Backup Contents

```
EmberHearth-Backup-2026-02-05/
├── manifest.json           ← Backup metadata
├── memory.db               ← SQLite database (memories)
├── conversations.db        ← Conversation archive
├── config.json             ← Settings and preferences
├── keychain-reference.txt  ← "API key in Keychain" (not actual key)
└── checksums.sha256        ← Integrity verification
```

**manifest.json:**
```json
{
  "backupVersion": 1,
  "appVersion": "1.2.3",
  "schemaVersion": 5,
  "created": "2026-02-05T15:30:00Z",
  "type": "update",
  "trigger": "pre-update-1.2.3-to-1.2.4",
  "memoriesCount": 1247,
  "conversationsCount": 89,
  "checksumAlgorithm": "SHA-256"
}
```

### 3.3 Backup Storage

```swift
struct BackupManager {
    // Default location (inside app support)
    static let defaultLocation = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("EmberHearth/Backups")

    // Backup retention policy
    static let retentionPolicy = RetentionPolicy(
        updateBackups: 3,       // Keep last 3 update backups
        dailyBackups: 7,        // Keep 7 days of daily backups
        manualBackups: .forever // Never auto-delete manual backups
    )

    // Disk space management
    static let maxBackupSize = 500_000_000  // 500 MB limit

    func createBackup(type: BackupType) throws -> URL {
        // Check disk space first
        guard DiskManager.availableSpace > requiredSpace(for: type) else {
            // Clean up old backups to make room
            try enforceRetentionPolicy()
        }

        let backupDir = createBackupDirectory(type: type)

        // Copy databases
        try copyDatabasesWithIntegrityCheck(to: backupDir)

        // Export config (without sensitive data)
        try exportConfig(to: backupDir)

        // Write manifest
        try writeManifest(to: backupDir, type: type)

        // Generate checksums
        try generateChecksums(for: backupDir)

        return backupDir
    }
}
```

### 3.4 Restore Process

```swift
func restoreFromBackup(_ backup: URL) throws {
    // 1. Verify backup integrity
    guard try verifyChecksums(backup) else {
        throw RestoreError.backupCorrupted
    }

    // 2. Check compatibility
    let manifest = try loadManifest(from: backup)
    guard manifest.schemaVersion <= currentSchemaVersion else {
        throw RestoreError.backupFromNewerVersion
    }

    // 3. Create safety backup of current state
    let safetyBackup = try BackupManager.createBackup(type: .preRestore)

    // 4. Stop all services
    ServiceManager.stopAll()

    // 5. Replace databases
    try replaceDatabases(from: backup)

    // 6. Restore config
    try restoreConfig(from: backup)

    // 7. Run any needed migrations
    if manifest.schemaVersion < currentSchemaVersion {
        try MigrationRegistry.migrate(
            from: manifest.schemaVersion,
            to: currentSchemaVersion
        )
    }

    // 8. Restart services
    try ServiceManager.startAll()

    // 9. Verify health
    let health = HealthMonitor.runFullCheck()
    if health != .healthy {
        // Restore failed, roll back to safety backup
        try restoreFromBackup(safetyBackup)
        throw RestoreError.postRestoreHealthCheckFailed
    }

    // 10. Clean up safety backup (restore succeeded)
    try FileManager.default.removeItem(at: safetyBackup)
}
```

---

## Part 4: Data Export (Portability)

### 4.1 Export Format

User-exportable data in open formats:

```
EmberHearth-Export-2026-02-05/
├── README.txt              ← Explains contents
├── memories.json           ← All facts in readable JSON
├── conversations/          ← Conversation logs
│   ├── index.json
│   ├── 2026-01.json
│   ├── 2026-02.json
│   └── ...
├── settings.json           ← Non-sensitive settings
└── export-info.json        ← Export metadata
```

**memories.json:**
```json
{
  "exportVersion": 1,
  "exportedAt": "2026-02-05T16:00:00Z",
  "memoriesCount": 1247,
  "memories": [
    {
      "id": "mem_abc123",
      "content": "User prefers tea over coffee",
      "category": "preference",
      "confidence": 0.95,
      "firstLearned": "2025-12-15T10:30:00Z",
      "lastAccessed": "2026-02-03T14:22:00Z",
      "accessCount": 12,
      "source": "conversation"
    },
    // ...
  ]
}
```

### 4.2 Export Privacy

Exports include:
- ✅ Memories (facts about user)
- ✅ Conversations (user's messages + Ember's responses)
- ✅ Preferences and settings

Exports exclude:
- ❌ API keys (security)
- ❌ System tokens (security)
- ❌ Internal state (not useful to user)
- ❌ Debug logs (privacy)

### 4.3 Import from Export

Users can import their exported data into a new EmberHearth installation:

```swift
func importFromExport(_ exportPath: URL) throws {
    let exportInfo = try loadExportInfo(from: exportPath)

    // Show user what will be imported
    let preview = ImportPreview(
        memoriesCount: exportInfo.memoriesCount,
        conversationsCount: exportInfo.conversationsCount,
        dateRange: exportInfo.dateRange
    )

    // User confirms
    guard await showImportConfirmation(preview) else { return }

    // Merge or replace?
    let mode = await askImportMode() // .merge or .replace

    switch mode {
    case .merge:
        // Add imported memories to existing
        try mergeMemories(from: exportPath)
        try mergeConversations(from: exportPath)

    case .replace:
        // Backup current, then replace
        try BackupManager.createBackup(type: .preImport)
        try replaceAllData(from: exportPath)
    }
}
```

---

## Part 5: Communicating Issues to Users

### 5.1 In-App Communication

When something goes wrong, Ember communicates naturally:

**Example: Migration caused some data loss**
```
User: "Hey Ember"

Ember: "Hey! I'm glad you're here. I should mention - I had a
bit of a hiccup during my last update. I might have lost some
memories from the past week or so. Nothing major, but if I seem
to have forgotten something recent, that's why. Sorry about that!"
```

**Example: Update restored from backup**
```
User: "Good morning!"

Ember: "Good morning! Quick heads up - there was an issue with
my update yesterday, so I rolled back to how things were on
Monday. Any conversations we had between Monday and yesterday
might be a bit fuzzy for me. But I'm all fixed up now!"
```

**Never say:**
- "SQLite PRAGMA integrity_check failed"
- "Migration from schema version 4 to 5 threw exception"
- "XPC service com.emberhearth.llmservice crashed"

### 5.2 Known Issues Communication

If an update has known problems, Ember can proactively inform users:

```swift
struct KnownIssues {
    // Bundled with app updates, checked on launch
    static let issues: [KnownIssue] = [
        KnownIssue(
            version: "1.2.4",
            severity: .minor,
            description: "Calendar sync may be slow for users with 1000+ events",
            workaround: "This resolves within 24 hours as the calendar indexes",
            affectedUsers: .some("Users with very large calendars"),
            fixVersion: "1.2.5"
        )
    ]
}
```

**Ember mentions if relevant:**
```
User: "Why is my calendar taking forever?"

Ember: "Oh, I know what this is! There's a known issue with the
current version where calendars with lots of events take a while
to sync. It should sort itself out within a day. Sorry for the
inconvenience - this is getting fixed in the next update!"
```

### 5.3 Status in Mac App

Settings → About → System Status:

```
┌─────────────────────────────────────────────────────────┐
│  System Status                                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  EmberHearth 1.2.4                                      │
│  Status: Healthy ✓                                      │
│                                                         │
│  Components:                                            │
│  • Messages: Connected ✓                                │
│  • Calendar: Connected ✓                                │
│  • AI Service: Connected ✓                              │
│  • Memory: 1,247 facts ✓                                │
│                                                         │
│  Last Update: Feb 5, 2026                               │
│  Update Status: Successful ✓                            │
│                                                         │
│  [View Update History]                                  │
│                                                         │
│  Known Issues for 1.2.4:                                │
│  • Calendar sync slow for large calendars (minor)       │
│    Fix coming in 1.2.5                                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Part 6: Edge Cases

### 6.1 Corrupted Backup

What if the backup itself is corrupted?

```swift
func restoreFromBackup(_ backup: URL) throws {
    // Verify before attempting restore
    switch verifyBackup(backup) {
    case .valid:
        try performRestore(backup)

    case .partiallyCorrupted(let recoverableData):
        // Some data recoverable
        let choice = await askUser(
            "This backup has some corruption. I can recover about " +
            "\(recoverableData.percentage)% of the data. Continue?"
        )
        if choice == .continue {
            try performPartialRestore(recoverableData)
        }

    case .fullyCorrupted:
        // Try older backups
        if let olderBackup = findNextOldestBackup() {
            let choice = await askUser(
                "This backup is corrupted. Would you like to try " +
                "an older backup from \(olderBackup.date)?"
            )
            if choice == .tryOlder {
                try restoreFromBackup(olderBackup.url)
            }
        } else {
            throw RestoreError.noValidBackupsAvailable
        }
    }
}
```

### 6.2 Disk Full During Update

```swift
func prepareForUpdate() throws {
    let requiredSpace = estimateUpdateSpace()
    let availableSpace = DiskManager.availableSpace

    if availableSpace < requiredSpace {
        // Try to free space
        try BackupManager.cleanOldBackups()
        try CacheManager.clearTemporary()

        // Still not enough?
        if DiskManager.availableSpace < requiredSpace {
            // Defer update, notify user
            SparkleUpdater.deferUpdate()
            notifyUser(
                "I need about \(requiredSpace.formatted) free to update. " +
                "I'll try again when there's more space!"
            )
            return
        }
    }

    // Proceed with backup
    try createPreUpdateBackup()
}
```

### 6.3 User Downgrades Manually

Users shouldn't downgrade, but if they do (by manually installing old DMG):

```swift
func handleVersionMismatch() {
    let installedVersion = Bundle.main.version
    let expectedVersion = UserDefaults.lastRunVersion

    if installedVersion < expectedVersion {
        // User downgraded!
        logger.warning("Downgrade detected: \(expectedVersion) → \(installedVersion)")

        // Check if database is compatible
        let dbSchema = DatabaseManager.currentSchemaVersion
        let appExpectedSchema = Self.schemaVersion

        if dbSchema > appExpectedSchema {
            // Database was migrated to newer version
            let choice = await showDowngradeWarning(
                "You're running an older version of EmberHearth. " +
                "Your data may not work correctly.\n\n" +
                "Options:\n" +
                "• Download the latest version (recommended)\n" +
                "• Continue anyway (may cause issues)\n" +
                "• Restore from an older backup"
            )

            switch choice {
            case .downloadLatest:
                NSWorkspace.shared.open(URL(string: "https://emberhearth.app/download")!)
            case .continueAnyway:
                // User's choice, log and proceed
                logger.warning("User continuing with downgraded version")
            case .restoreOlderBackup:
                showBackupPicker(maxVersion: installedVersion)
            }
        }
    }
}
```

### 6.4 Sparkle Rollback

Sparkle 2 can detect if an update fails to launch and roll back:

```swift
// In SparkleDelegate
func updater(_ updater: SPUUpdater,
             didAbortWithError error: Error) {
    // Sparkle automatically reverts to previous version

    // We should:
    // 1. Log what happened
    logger.error("Update aborted: \(error)")

    // 2. Restore pre-update backup if database was touched
    if MigrationTracker.inProgress {
        try? BackupManager.restoreLatest(type: .update)
    }

    // 3. Report if telemetry enabled
    if TelemetryManager.isEnabled {
        TelemetryManager.report("update_rollback", error: error)
    }

    // 4. Show simple message on next launch
    UserDefaults.showUpdateRollbackMessage = true
}
```

---

## Part 7: Testing Requirements

### 7.1 Update Scenarios to Test

| Scenario | Test Method | Pass Criteria |
|----------|-------------|---------------|
| Clean update | Automated | Health check passes |
| Update with migration | Automated | Schema updated, data preserved |
| Update interrupted mid-migration | Kill app during migration | Resumes correctly on next launch |
| Update with disk full | Mock disk full | Defers gracefully, notifies user |
| Update with corrupted backup | Corrupt backup file | Falls back to older backup |
| Manual downgrade | Install older version | Warning shown, options offered |
| Sparkle rollback | Crash on launch after update | Reverts to previous version |

### 7.2 Recovery Tests

```swift
@Test func testBackupRestoreRoundtrip() async throws {
    // Create some data
    let store = MemoryStore.shared
    try await store.save(Fact(content: "Test fact"))

    // Create backup
    let backup = try BackupManager.createBackup(type: .manual)

    // Delete data
    try store.deleteAll()
    #expect(try await store.count() == 0)

    // Restore
    try BackupManager.restore(from: backup)

    // Verify
    #expect(try await store.count() == 1)
    let fact = try await store.fetchAll().first
    #expect(fact?.content == "Test fact")
}

@Test func testCorruptedBackupFallback() async throws {
    // Create two backups
    let older = try BackupManager.createBackup(type: .manual)
    // ... time passes ...
    let newer = try BackupManager.createBackup(type: .manual)

    // Corrupt the newer one
    try corruptFile(newer.appendingPathComponent("memory.db"))

    // Attempt restore - should fall back to older
    let result = try await BackupManager.restoreWithFallback(from: newer)

    #expect(result.usedFallback == true)
    #expect(result.restoredFrom == older)
}

@Test func testMigrationInterruptionRecovery() async throws {
    // Start migration
    let migration = MigrationRegistry.startMigration(from: 4, to: 6)

    // Simulate crash after first step
    migration.simulateCrashAfterStep(1)

    // Verify checkpoint saved
    #expect(MigrationTracker.lastCompletedVersion == 5)

    // "Relaunch" and resume
    try MigrationRegistry.resumeIfNeeded()

    // Verify completed
    #expect(DatabaseManager.currentSchemaVersion == 6)
}
```

---

## Implementation Checklist

### MVP

- [ ] Pre-update backup creation
- [ ] Post-update health verification
- [ ] Basic backup/restore UI in Settings
- [ ] Ember communicates update issues naturally
- [ ] Schema version tracking

### v1.1

- [ ] Daily automatic backups
- [ ] Backup retention enforcement
- [ ] Export to portable JSON format
- [ ] Import from export
- [ ] Known issues communication
- [ ] Update history view

### v1.2+

- [ ] Cloud backup option (iCloud)
- [ ] Backup encryption option
- [ ] Migration dry-run capability
- [ ] Community health dashboard integration

---

## References

- `specs/autonomous-operation.md` — Self-healing, migrations, forward compatibility
- `specs/error-handling.md` — Component failure modes
- [Sparkle Customization](https://sparkle-project.org/documentation/customization/) — Pre/post update hooks
- [Apple File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/) — Atomic writes, backup locations

---

*Specification complete. February 5, 2026.*
