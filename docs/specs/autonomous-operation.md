# Autonomous Operation Specification

**Version:** 1.0
**Date:** February 3, 2026
**Status:** Research Complete

---

## Philosophy: The Grandmother Test

> "If my grandmother sees an error dialog, we've already failed."

EmberHearth is designed for users who:
- Don't know what a "log file" is
- Can't interpret error codes
- Won't (and shouldn't have to) contact support
- Just want their AI friend to work

This specification replaces traditional enterprise concepts with consumer-appropriate alternatives:

| Enterprise Concept | EmberHearth Equivalent |
|-------------------|------------------------|
| Observability | Self-Monitoring |
| Alerting | Self-Healing |
| Log analysis | Automatic diagnosis |
| Incident response | Automatic recovery |
| Configuration management | Seamless upgrades |
| Rollback procedures | Forward-compatible resilience |

---

## Part 1: Self-Monitoring & Self-Healing

### 1.1 Design Principles

**The Three Laws of EmberHearth Resilience:**

1. **Detect silently** — Know something is wrong before the user does
2. **Heal automatically** — Fix what can be fixed without asking
3. **Degrade gracefully** — When healing fails, reduce scope, don't stop entirely

### 1.2 Health State Machine

EmberHearth operates in one of four health states:

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   ┌──────────┐      issue      ┌──────────┐                 │
│   │          │ ─────────────►  │          │                 │
│   │ HEALTHY  │                 │ DEGRADED │                 │
│   │          │ ◄─────────────  │          │                 │
│   └──────────┘     healed      └──────────┘                 │
│        │                            │                       │
│        │ critical                   │ critical              │
│        ▼                            ▼                       │
│   ┌──────────┐                 ┌──────────┐                 │
│   │          │                 │          │                 │
│   │ HEALING  │ ─────────────►  │ IMPAIRED │                 │
│   │          │   if fails      │          │                 │
│   └──────────┘                 └──────────┘                 │
│        │                            │                       │
│        │ success                    │ recovery              │
│        └────────────► HEALTHY ◄─────┘                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**State Definitions:**

| State | User Experience | Internal Behavior |
|-------|-----------------|-------------------|
| **HEALTHY** | Everything works | All systems operational |
| **DEGRADED** | Everything works (some features limited) | Non-critical subsystem offline |
| **HEALING** | Brief pause, then works | Active recovery in progress |
| **IMPAIRED** | Ember explains limitation | Critical system unavailable |

**Key insight:** User only notices IMPAIRED state. The other three are invisible.

### 1.3 Component Health Monitors

Each subsystem has a dedicated health monitor that runs independently:

#### LLM Health Monitor
```
Check interval: 15 minutes (or on first failure)
Health signal: Successful API ping with minimal tokens

States:
  HEALTHY     → API responds < 5s, valid response
  DEGRADED    → API responds but slow (> 10s)
  HEALING     → Retry sequence in progress
  IMPAIRED    → 4+ retries failed, offline mode active

Auto-heal actions:
  1. Retry with exponential backoff (immediate, 2s, 4s, 8s)
  2. If rate-limited, enter cooldown (respects Retry-After header)
  3. If auth error, flag for user (only case requiring user action)
  4. If timeout, try smaller request
  5. If all fail, enter offline mode

Recovery trigger:
  - Background ping every 5 minutes during IMPAIRED
  - On success, process queued messages
  - Ember: "I'm back online! Let me catch up..."
```

#### iMessage Health Monitor
```
Check interval: 5 minutes
Health signal: FSEvents stream active, chat.db accessible

States:
  HEALTHY     → FSEvents firing, chat.db readable
  DEGRADED    → FSEvents working but chat.db slow
  HEALING     → Re-registering FSEvents stream
  IMPAIRED    → Permission revoked or Messages.app missing

Auto-heal actions:
  1. FSEvents stopped → Re-register stream
  2. chat.db locked → Retry with backoff (100ms intervals)
  3. chat.db missing → Check if path changed, attempt locate
  4. Messages.app not running → Launch via AppleScript
  5. Permission denied → Cannot auto-heal (user action needed)

Recovery trigger:
  - FSEvents naturally resume when available
  - On recovery, process any missed messages
```

#### SQLite Health Monitor
```
Check interval: 1 hour (quick_check), daily (full integrity_check)
Health signal: PRAGMA quick_check returns "ok"

States:
  HEALTHY     → Integrity checks pass
  DEGRADED    → Minor issues detected, reads work
  HEALING     → Running recovery procedure
  IMPAIRED    → Database unusable, using backup

Auto-heal actions:
  1. Minor corruption → VACUUM, reindex
  2. WAL corruption → Checkpoint, recreate WAL
  3. Page corruption → Restore from backup
  4. Full corruption → Start fresh (last resort)

Recovery trigger:
  - Successful integrity check after repair
  - Database operations succeed
```

#### XPC Health Monitor
```
Check interval: 30 seconds (heartbeat)
Health signal: Heartbeat response within 5 seconds

States:
  HEALTHY     → All XPC services responding
  DEGRADED    → One service slow or restarting
  HEALING     → Service restart in progress
  IMPAIRED    → Service won't start after 3 attempts

Auto-heal actions:
  1. No heartbeat → Send wake signal
  2. Still no response → Kill and restart service
  3. Crash loop detected (>3/min) → Enter safe mode
  4. Code signature invalid → Flag for reinstall

Recovery trigger:
  - Service responds to heartbeat
  - Crash count resets after 5 minutes stability
```

### 1.4 Circuit Breaker Pattern

To prevent cascading failures and wasted resources, each external dependency uses a circuit breaker:

```
┌─────────────────────────────────────────────────────┐
│                  CIRCUIT BREAKER                    │
├─────────────────────────────────────────────────────┤
│                                                     │
│   CLOSED ──(failures > threshold)──► OPEN          │
│      ▲                                  │           │
│      │                                  │           │
│      │                            (timeout)         │
│      │                                  │           │
│      │                                  ▼           │
│      └────────(success)────────── HALF-OPEN        │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Configuration per service:**

| Service | Failure Threshold | Open Duration | Half-Open Attempts |
|---------|-------------------|---------------|-------------------|
| LLM API | 4 failures | 5 minutes | 1 |
| iMessage | 3 failures | 30 seconds | 2 |
| Calendar | 2 failures | 2 minutes | 1 |
| Contacts | 2 failures | 2 minutes | 1 |

**When circuit is OPEN:**
- Requests fail immediately (no network call)
- User gets instant "I'm having trouble with X" response
- Background recovery attempts continue

### 1.5 Offline Mode

When LLM API is unavailable, EmberHearth enters offline mode:

**Capabilities in offline mode:**
- ✅ Receive messages (queued for processing)
- ✅ Send acknowledgment: "I got your message but I'm having trouble connecting. I'll respond soon."
- ✅ Access local memory (for future local model fallback)
- ✅ Basic pattern responses for common queries (time, date, etc.)
- ❌ Generate AI responses
- ❌ Use tools requiring LLM reasoning

**Message queue behavior:**
```
Max queue size: 100 messages
Max message age: 24 hours
Oldest messages: Prefixed with "Sorry for the delay" when processed
Queue persistence: Survives app restart
```

**Recovery:**
```swift
// When coming back online
func processMessageQueue() {
    let queue = MessageQueue.shared.pending()

    for message in queue {
        let delay = Date().timeIntervalSince(message.receivedAt)

        if delay > 3600 { // > 1 hour
            // Add delay acknowledgment to context
            context.add("Note: This message arrived \(formatDelay(delay)) ago")
        }

        processMessage(message)
    }
}
```

### 1.6 Self-Diagnostic Capabilities

EmberHearth can diagnose and explain its own health:

**User asks:** "Ember, are you working okay?"

**Ember can report:**
```
I'm running well! Here's my status:
- Messages: Connected ✓
- Memory: 1,247 facts stored ✓
- Calendar: Connected ✓
- Response time: About 2 seconds ✓

Everything looks good!
```

**Or if there's an issue:**
```
I'm mostly working, but I'm having some trouble connecting to my
brain (the AI service). Messages might be a bit delayed right now.
I'll let you know when things are back to normal!
```

**Never say:**
- "API error 429 rate limit exceeded"
- "XPC service MessageService.xpc failed to launch"
- "SQLite PRAGMA integrity_check returned SQLITE_CORRUPT"

---

## Part 2: Seamless Upgrades

### 2.1 Philosophy

> "The user should never know an update happened—except that things got better."

Traditional rollback is a fallacy for consumer apps:
- Users don't know what version they're on
- Rolling back data is dangerous (loses new memories)
- Sparkle 2 doesn't support downgrade anyway

**Our approach:** Forward-compatible resilience
- Protect data before changes
- Make changes reversible at the data level
- If something breaks, heal forward, don't roll back

### 2.2 Update Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                     UPDATE PIPELINE                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Sparkle detects update]                                       │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │ PRE-UPDATE HOOK │◄── Backup databases                        │
│  │                 │◄── Export critical config                  │
│  │                 │◄── Record current version                  │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │ SPARKLE UPDATE  │◄── Download, verify, install               │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │ POST-UPDATE     │◄── Run migrations                          │
│  │ FIRST LAUNCH    │◄── Verify integrity                        │
│  │                 │◄── Validate config                         │
│  │                 │◄── Health check all services               │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│      [Resume normal operation]                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 Pre-Update Safety

Before any update installs, EmberHearth automatically:

```swift
func prepareForUpdate() {
    // 1. Create point-in-time backup
    let backupPath = BackupManager.createUpdateBackup(
        tag: "pre-update-\(currentVersion)"
    )

    // 2. Export configuration to JSON
    let configExport = ConfigManager.exportToJSON()
    try configExport.write(to: backupPath.appendingPathComponent("config.json"))

    // 3. Record migration state
    MigrationTracker.record(
        fromVersion: currentVersion,
        databases: DatabaseManager.checksums(),
        timestamp: Date()
    )

    // 4. Flush pending writes
    MemoryStore.shared.checkpoint()
    ConversationArchive.shared.checkpoint()
}
```

**Backup retention for updates:**
- Keep last 3 update backups
- Auto-delete after 30 days if no issues reported
- Never delete if health checks failing

### 2.4 Configuration Migration

#### Schema Versioning

Every config and database has an explicit schema version:

```swift
// Config schema
struct EmberHearthConfig: Codable {
    static let schemaVersion = 5

    let schemaVersion: Int
    let llmProvider: LLMProvider
    let personality: PersonalityConfig
    // ...
}

// Database schema tracked in metadata table
// CREATE TABLE schema_info (version INTEGER, migrated_at TEXT)
```

#### Migration Registry

```swift
class MigrationRegistry {
    static let migrations: [Migration] = [
        Migration(from: 1, to: 2, run: migrateV1toV2),
        Migration(from: 2, to: 3, run: migrateV2toV3),
        Migration(from: 3, to: 4, run: migrateV3toV4),
        Migration(from: 4, to: 5, run: migrateV4toV5),
    ]

    static func migrate(from current: Int, to target: Int) throws {
        var version = current

        while version < target {
            guard let migration = migrations.first(where: { $0.from == version }) else {
                throw MigrationError.noPathFound(from: version, to: target)
            }

            try migration.run()
            version = migration.to

            // Record progress (allows resume if interrupted)
            MigrationTracker.recordStep(completed: version)
        }
    }
}
```

#### Migration Safety Rules

1. **Additive only when possible**
   ```sql
   -- GOOD: Add column with default
   ALTER TABLE memories ADD COLUMN importance REAL DEFAULT 0.5;

   -- AVOID: Rename column (breaks old code reading new data)
   -- Instead: Add new column, copy data, deprecate old
   ```

2. **Never delete data in migration**
   ```swift
   // GOOD: Mark as deprecated, clean up later
   func migrateV4toV5() {
       db.execute("ALTER TABLE memories ADD COLUMN deprecated_old_field_cleanup INTEGER DEFAULT 0")
       // Actual cleanup happens in background job after 30 days
   }
   ```

3. **Transactions for atomicity**
   ```swift
   func migrateV3toV4() throws {
       try db.transaction {
           try db.execute("ALTER TABLE ...")
           try db.execute("UPDATE ...")
           try db.execute("UPDATE schema_info SET version = 4")
       }
   }
   ```

4. **Resumable migrations**
   ```swift
   // For large data migrations, process in batches with checkpoints
   func migrateLargeTable() throws {
       let lastProcessed = MigrationTracker.checkpoint(for: "large_table") ?? 0

       let batch = db.query("SELECT * FROM large_table WHERE id > ? LIMIT 1000", lastProcessed)

       for row in batch {
           try processRow(row)
           MigrationTracker.setCheckpoint("large_table", row.id)
       }
   }
   ```

### 2.5 Configuration Compatibility

#### Forward Compatibility

New versions must read old configs:

```swift
struct EmberHearthConfig: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Read with defaults for missing fields
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        self.llmProvider = try container.decodeIfPresent(LLMProvider.self, forKey: .llmProvider) ?? .claude

        // Handle renamed fields
        if let oldName = try container.decodeIfPresent(String.self, forKey: .deprecatedEmberName) {
            self.personality.name = oldName
        } else {
            self.personality = try container.decode(PersonalityConfig.self, forKey: .personality)
        }
    }
}
```

#### Backward Compatibility (Limited)

If user needs to downgrade (rare, manual process):

```swift
// Config export includes compatibility layer
func exportForVersion(_ version: Int) -> Data {
    var export = self.toJSON()

    if version < 5 {
        // Flatten new nested structure for old versions
        export["emberName"] = export["personality"]["name"]
        export.removeValue(forKey: "personality")
    }

    return export
}
```

### 2.6 Handling Migration Failures

When a migration fails, EmberHearth doesn't crash or show an error. It heals:

```swift
func handleMigrationFailure(_ error: MigrationError) {
    Logger.log(.migration, "Migration failed: \(error)")

    switch error {
    case .databaseCorruption:
        // Try to recover from backup
        if BackupManager.restoreLatest(for: .database) {
            Logger.log(.migration, "Restored from backup, retrying migration")
            retryMigration()
        } else {
            // Start fresh with import of readable data
            attemptDataRecovery()
        }

    case .configInvalid:
        // Reset to defaults, preserve what we can
        let preserved = ConfigManager.extractValidFields(from: currentConfig)
        ConfigManager.resetToDefaults()
        ConfigManager.applyPreserved(preserved)

    case .insufficientDiskSpace:
        // Clean up temp files, old backups
        DiskManager.emergencyCleanup()
        retryMigration()

    case .interrupted:
        // Resume from checkpoint
        MigrationRegistry.resumeFromCheckpoint()
    }
}
```

**User experience during failure:**
- App launches normally
- If data was lost, Ember mentions it naturally:
  > "I had a bit of a hiccup during my update and lost some recent memories.
  > I'm sorry about that! I still remember the important stuff though."

---

## Part 3: Optional Health Reporting

### 3.1 Philosophy

> "Telemetry should help the developer help users—not spy on users."

EmberHearth is privacy-first. But a completely isolated app has problems:
- Developer can't know if updates are causing issues
- Common bugs affect many users who never report them
- No way to prioritize fixes

**Solution:** Opt-in, anonymous, minimal health telemetry.

### 3.2 What We Could Collect (If User Opts In)

**Allowed (anonymous health metrics only):**
```json
{
  "event": "health_report",
  "app_version": "1.2.3",
  "os_version": "15.0",
  "health_state": "DEGRADED",
  "degraded_systems": ["llm"],
  "crash_count_24h": 0,
  "migration_status": "success",
  "timestamp": "2026-02-03T12:00:00Z"
}
```

**Never collected:**
- Message content
- Memory/fact content
- User's name or phone number
- API keys
- IP address (not even logged server-side)
- Device identifiers
- Contact information
- Anything that could identify the specific user

### 3.3 Implementation Approach

Using [TelemetryDeck](https://telemetrydeck.com/) or similar privacy-first service:

```swift
class HealthReporter {
    static let shared = HealthReporter()

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "healthReportingEnabled")
    }

    func reportHealthState() {
        guard isEnabled else { return }

        // Generate anonymous session (not tied to device)
        let anonymousSession = UUID().uuidString

        TelemetryManager.send(
            "health_state",
            with: [
                "state": HealthMonitor.currentState.rawValue,
                "degraded": HealthMonitor.degradedSystems.joined(separator: ","),
                "app_version": Bundle.main.version,
                "os_version": ProcessInfo.processInfo.operatingSystemVersionString
            ],
            floatValue: Double(HealthMonitor.healthScore)
        )
    }

    func reportCrashRecovery() {
        guard isEnabled else { return }

        TelemetryManager.send(
            "crash_recovery",
            with: [
                "recovery_success": String(CrashRecovery.lastRecoverySucceeded),
                "app_version": Bundle.main.version
            ]
        )
    }

    func reportMigrationResult(_ result: MigrationResult) {
        guard isEnabled else { return }

        TelemetryManager.send(
            "migration",
            with: [
                "from_version": result.fromVersion,
                "to_version": result.toVersion,
                "success": String(result.succeeded),
                "duration_ms": String(result.durationMs)
            ]
        )
    }
}
```

### 3.4 User Control

**Onboarding (first launch):**
```
EmberHearth can send anonymous health reports to help improve
the app for everyone. No personal information is ever collected.

[Learn More]

( ) Don't send reports
(•) Send anonymous health reports

[Continue]
```

**Settings → Privacy:**
```
Anonymous Health Reports          [ON/OFF]
────────────────────────────────────────
Help improve EmberHearth by sending anonymous
crash and health information. This data cannot
be used to identify you.

What's collected:
• App version
• Whether systems are working
• Crash counts (not crash content)
• Update success/failure

Never collected:
• Your messages
• Your memories
• Your contacts
• Anything personal

[View sample report]
```

### 3.5 Future: Community Health Dashboard

If telemetry is implemented, a public status page could show:

```
EmberHearth Community Health
────────────────────────────

Overall Health: 98.7% of users healthy

Version 1.2.3 (current)
├── Migration success rate: 99.9%
├── Average health score: 97/100
└── Known issues: None

Version 1.2.2
├── Migration success rate: 99.8%
├── Known issues: Calendar sync delay (fixed in 1.2.3)
└── Recommendation: Update available

API Status
├── Claude API: Operational
├── OpenAI: Operational
└── Local Models: N/A (not yet released)
```

**Benefits:**
- Users can check if others have same issue
- Developer prioritizes fixes by impact
- Transparency about app health

### 3.6 Fallback: No Telemetry Mode

If user opts out or telemetry isn't implemented, EmberHearth still works:

- Self-healing continues locally
- Diagnostic export available for manual sharing
- No degradation in functionality
- User can still manually report issues (email, GitHub)

---

## Implementation Checklist

### MVP Requirements

**Self-Monitoring:**
- [ ] Health state machine (4 states)
- [ ] LLM health monitor with circuit breaker
- [ ] iMessage health monitor
- [ ] SQLite quick_check (hourly)
- [ ] Basic offline mode (acknowledge + queue)
- [ ] Self-diagnostic via conversation

**Seamless Upgrades:**
- [ ] Pre-update backup hook
- [ ] Schema versioning for config
- [ ] Schema versioning for databases
- [ ] Migration registry pattern
- [ ] Migration failure recovery

**Health Reporting:**
- [ ] Skip for MVP (implement in v1.1+)

### Post-MVP (v1.1)

**Self-Monitoring:**
- [ ] Full circuit breaker for all services
- [ ] XPC heartbeat monitoring
- [ ] Automatic FSEvents recovery
- [ ] Health score calculation
- [ ] Status dashboard in Mac app

**Seamless Upgrades:**
- [ ] Resumable migrations for large datasets
- [ ] Config export/import for backup
- [ ] Update rollout pause if errors spike

**Health Reporting:**
- [ ] TelemetryDeck integration
- [ ] Opt-in flow in onboarding
- [ ] Settings control
- [ ] Sample report viewer

### Future (v1.2+)

- [ ] Predictive health (detect degradation before failure)
- [ ] Community health dashboard
- [ ] Automatic issue reporting to GitHub
- [ ] Local model fallback when LLM offline

---

## Testing Requirements

### Self-Healing Tests

```swift
// Test: LLM circuit breaker
func testLLMCircuitBreaker() {
    // Simulate 4 consecutive failures
    mockLLM.failNextRequests(4)

    // Verify circuit opens
    XCTAssertEqual(llmHealthMonitor.circuitState, .open)

    // Verify immediate fail (no network call)
    let startTime = Date()
    let result = try? llmService.query("test")
    XCTAssertNil(result)
    XCTAssertLessThan(Date().timeIntervalSince(startTime), 0.1)

    // Wait for half-open
    wait(for: 5.minutes)

    // Verify recovery attempt
    mockLLM.succeedNextRequests(1)
    let recovered = try? llmService.query("test")
    XCTAssertNotNil(recovered)
    XCTAssertEqual(llmHealthMonitor.circuitState, .closed)
}

// Test: Offline mode queue
func testOfflineModeQueue() {
    llmHealthMonitor.forceState(.impaired)

    // Send messages while offline
    messageService.receive("Message 1")
    messageService.receive("Message 2")

    // Verify queue
    XCTAssertEqual(MessageQueue.shared.count, 2)

    // Verify acknowledgment sent
    XCTAssertTrue(mockMessages.sentMessages.contains {
        $0.contains("having trouble connecting")
    })

    // Recover
    llmHealthMonitor.forceState(.healthy)

    // Verify queue processed
    wait(for: MessageQueue.shared.isEmpty)
    XCTAssertEqual(mockMessages.sentMessages.count, 4) // 2 acks + 2 responses
}
```

### Migration Tests

```swift
// Test: Migration with interruption
func testMigrationResumesAfterInterrupt() {
    // Start migration
    let migration = MigrationRegistry.migrate(from: 3, to: 5)

    // Interrupt mid-way
    migration.interrupt(afterStep: 1)

    // Verify checkpoint saved
    XCTAssertEqual(MigrationTracker.checkpoint, 4)

    // Resume
    let resumed = MigrationRegistry.resumeFromCheckpoint()

    // Verify completed
    XCTAssertEqual(currentSchemaVersion, 5)
}

// Test: Config forward compatibility
func testOldConfigLoadsInNewVersion() {
    let oldConfigJSON = """
    {
        "schemaVersion": 2,
        "emberName": "Ember",
        "llmProvider": "claude"
    }
    """

    let config = try! JSONDecoder().decode(EmberHearthConfig.self, from: oldConfigJSON.data(using: .utf8)!)

    // Verify migrated correctly
    XCTAssertEqual(config.personality.name, "Ember")
    XCTAssertEqual(config.schemaVersion, 5) // Upgraded
    XCTAssertNotNil(config.personality.traits) // Has defaults
}
```

---

## References

- [Microsoft Azure Well-Architected Framework: Self-Healing](https://learn.microsoft.com/en-us/azure/well-architected/reliability/self-preservation)
- [Azure Architecture: Design for Self-Healing](https://learn.microsoft.com/en-us/azure/architecture/guide/design-principles/self-healing)
- [Sparkle Framework Documentation](https://sparkle-project.org/documentation/)
- [Sparkle Customization](https://sparkle-project.org/documentation/customization/)
- [TelemetryDeck Privacy FAQ](https://telemetrydeck.com/docs/guides/privacy-faq/)
- [VS Code Telemetry Approach](https://code.visualstudio.com/docs/configure/telemetry)
- [Self-Healing Software: Lessons from Nature](https://arxiv.org/pdf/2504.20093)

---

## Glossary

| Term | Definition |
|------|------------|
| Circuit Breaker | Pattern that fails fast when a service is known to be down |
| Forward Compatibility | New code can read old data |
| Backward Compatibility | Old code can read new data |
| Health Score | 0-100 measure of system health |
| Migration | Code that transforms data from old format to new |
| Self-Annealing | System that improves over time through automatic adjustment |
| Telemetry | Automatic collection of usage/health data |
