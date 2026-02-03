# Error Handling and Resilience Specification

> *"The grandmother can't troubleshoot. The system must heal itself."*

## Overview

EmberHearth is a consumer application for non-technical users. Unlike enterprise software:
- No IT support team
- No on-call engineers
- No log ingestion pipeline
- No monitoring dashboards

The system must be **self-healing** and **self-diagnosing**. When things go wrong, the user's only options should be:
1. Wait for it to fix itself
2. Restart the app
3. Contact support (last resort)

This document specifies how EmberHearth handles failures at every level.

---

## Design Principles

### 1. Never Lose User Data

Memory.db contains years of user's relationship with Ember. Corruption or loss is catastrophic. Data integrity is paramount.

### 2. Fail Gracefully, Not Silently

When something fails:
- Acknowledge the failure to the user (via iMessage)
- Explain simply what's happening
- Indicate when things should be working again
- Never just go silent

### 3. Self-Heal When Possible

Many failures are transient:
- Network blips
- API rate limits
- Service restarts

The system should automatically recover without user intervention.

### 4. Preserve Functionality

When a subsystem fails, other subsystems should continue:
- Calendar integration down? iMessage still works.
- LLM API down? Acknowledge messages, queue for later.
- Memory database locked? Use in-memory cache, sync later.

### 5. Make Debugging Possible

When users do contact support, there must be something useful to look at. Local logs with appropriate retention and privacy.

---

## Component Failure Modes

### 1. LLM Provider (Claude API)

| Failure Mode | Detection | Response | User Communication |
|--------------|-----------|----------|-------------------|
| **Network timeout** | HTTP timeout (30s) | Retry 3x with exponential backoff (2s, 4s, 8s) | None if recovery succeeds |
| **Rate limited (429)** | HTTP 429 response | Backoff per `Retry-After` header, max 5 min | "I'm a bit busy right now. Give me a moment." |
| **Auth failure (401)** | HTTP 401 response | Surface to user, cannot self-heal | "There's an issue with my connection. Please check the API key in EmberHearth settings." |
| **Server error (5xx)** | HTTP 5xx response | Retry 3x, then queue message | "The AI service is having issues. I've saved your message and will respond when it's back." |
| **Extended outage** | >10 min of failures | Enter degraded mode | "I'm temporarily offline. Your messages are saved and I'll catch up soon." |
| **Invalid API key** | Persistent 401 | Disable LLM features, prompt reconfiguration | "I need you to update my API key. Open EmberHearth on your Mac to fix this." |

**Retry Policy:**
```
Attempt 1: Immediate
Attempt 2: 2 seconds delay
Attempt 3: 4 seconds delay
Attempt 4: 8 seconds delay
(Give up, queue message)
```

**Message Queue:**
- Store pending messages in SQLite with timestamp
- Process queue when connectivity restored
- FIFO order, oldest first
- Maximum queue size: 100 messages
- Queue age limit: 24 hours (older messages get "sorry for the delay" prefix)

### 2. iMessage Integration

| Failure Mode | Detection | Response | User Communication |
|--------------|-----------|----------|-------------------|
| **chat.db locked** | SQLite SQLITE_BUSY | Retry 5x with 100ms delay | None if recovery succeeds |
| **chat.db missing** | File not found | Check permissions, prompt user | Mac notification: "EmberHearth needs Full Disk Access" |
| **chat.db corrupted** | Integrity check fails | Fall back to last known good state | "I'm having trouble reading messages. Working on it..." |
| **Messages.app not running** | AppleScript error | Launch Messages.app automatically | None (seamless) |
| **AppleScript timeout** | osascript timeout (10s) | Retry 2x, then log error | "I'm having trouble sending. Will keep trying." |
| **AppleScript permission denied** | Authorization error | Surface to user | Mac notification: "EmberHearth needs Automation permission for Messages" |
| **FSEvents stopped** | No events for 5 min during active use | Re-register FSEvents stream | None (seamless) |

**FSEvents Health Check:**
- Every 5 minutes, touch a marker file in watched directory
- If no FSEvents callback within 10 seconds, restart monitoring
- Log anomalies for debugging

**Message Send Retry:**
```
Attempt 1: Immediate
Attempt 2: 500ms delay (AppleScript may be busy)
Attempt 3: 2 seconds delay
(Give up, mark as failed, notify user)
```

### 3. Memory Database (SQLite)

| Failure Mode | Detection | Response | User Communication |
|--------------|-----------|----------|-------------------|
| **Database locked** | SQLITE_BUSY | Retry 5x with 100ms delay | None |
| **Disk full** | SQLITE_FULL | Alert user, pause non-critical writes | Mac notification: "Your Mac is running low on storage" |
| **Corruption detected** | PRAGMA integrity_check | Attempt recovery, restore from backup | "I'm restoring my memory from backup. Some recent things might be forgotten." |
| **Backup not available** | No backup files | Start fresh, preserve what's possible | "I had to reset my memory. I'm sorry—let's start fresh." |
| **Migration failure** | Schema mismatch | Rollback, keep old version | "Please update EmberHearth to the latest version." |
| **WAL checkpoint failure** | Checkpoint error | Log warning, retry on next idle | None |

**Database Health:**
```sql
-- Run on startup and daily
PRAGMA integrity_check;
PRAGMA foreign_key_check;
PRAGMA quick_check; -- Fast check, run every hour
```

**Backup Strategy:**
```
Location: ~/Library/Application Support/EmberHearth/Backups/
Retention:
  - Hourly: Last 24 hours (24 backups)
  - Daily: Last 7 days (7 backups)
  - Weekly: Last 4 weeks (4 backups)

Backup process:
  1. PRAGMA wal_checkpoint(TRUNCATE);  -- Flush WAL
  2. Copy database file to backup location
  3. PRAGMA integrity_check on backup
  4. Delete old backups per retention policy
```

**Corruption Recovery:**
```
Step 1: Run PRAGMA integrity_check
Step 2: If partial corruption, use sqlite3 recover command
Step 3: If recovery fails, restore from most recent backup
Step 4: If no backup, export what's readable, create fresh database
Step 5: Log incident with details for debugging
```

### 4. Apple Integrations (Calendar, Reminders, etc.)

| Failure Mode | Detection | Response | User Communication |
|--------------|-----------|----------|-------------------|
| **Permission denied** | EventKit authorization error | Disable feature, prompt re-authorization | "I don't have access to your calendar. You can enable this in System Settings." |
| **EventStore unavailable** | EKEventStore error | Retry on next request | None |
| **AppleScript timeout** | osascript timeout | Retry 2x, then skip | "I couldn't check your [mail/notes]. I'll try again later." |
| **iCloud sync conflict** | Duplicate/missing events | Use local state as source of truth | None |

**Graceful Degradation:**
- Each integration is independent
- Failure in one doesn't affect others
- Core functionality (iMessage + LLM) must work even if all integrations fail

### 5. XPC Services

| Failure Mode | Detection | Response | User Communication |
|--------------|-----------|----------|-------------------|
| **Service crashed** | XPC connection invalidated | Automatically restart via launchd | None if restart succeeds |
| **Service hung** | No response within 30s | Kill and restart | None if restart succeeds |
| **Code signing mismatch** | Connection rejected | Log security event, fail operation | Mac notification: "EmberHearth integrity check failed. Please reinstall." |
| **Multiple restart failures** | >3 crashes in 1 minute | Enter safe mode, disable service | "Some of my features are temporarily unavailable." |

**XPC Health Monitoring:**
```swift
// Heartbeat every 30 seconds
func checkServiceHealth(service: XPCService) async -> Bool {
    do {
        let response = try await service.ping(timeout: 5.0)
        return response == .pong
    } catch {
        return false
    }
}

// If heartbeat fails 3x consecutively, restart service
```

### 6. Network Connectivity

| Failure Mode | Detection | Response | User Communication |
|--------------|-----------|----------|-------------------|
| **No internet** | NWPathMonitor reports unsatisfied | Enter offline mode | "I'm offline right now. I'll respond when you're back online." |
| **Intermittent connectivity** | Requests failing >50% | Reduce request frequency, batch operations | None |
| **DNS failure** | Hostname resolution fails | Use cached IP if available, retry | None if recovery succeeds |
| **TLS/SSL error** | Certificate validation fails | Do NOT bypass, fail safely | "I'm having a secure connection issue. This should resolve soon." |

**Offline Mode:**
- Acknowledge incoming messages: "I'm offline. I'll respond when connectivity returns."
- Queue outgoing messages locally
- Continue operations that don't require network (local memory queries)
- Check connectivity every 30 seconds
- When restored, process queue and notify user: "I'm back online. Catching up now..."

### 7. Application Crashes

**Prevention:**
- Structured error handling throughout
- Never force-unwrap optionals in production
- Catch all exceptions at XPC boundaries
- Validate all external input

**Recovery:**

EmberHearth uses launchd for automatic restart:

```xml
<!-- ~/Library/LaunchAgents/com.emberhearth.agent.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.emberhearth.agent</string>
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
</dict>
</plist>
```

- `KeepAlive` with `SuccessfulExit=false`: Only restart on crash, not clean exit
- `ThrottleInterval=10`: Wait 10 seconds between restarts (prevents crash loop)
- If >3 crashes in 5 minutes, launchd will throttle further

**Post-Crash Recovery:**
```swift
func applicationDidFinishLaunching() {
    if CrashDetector.didCrashLastRun() {
        // Log crash occurrence
        Logger.log(.crash, "Recovered from crash")

        // Check database integrity
        if !MemoryStore.shared.verifyIntegrity() {
            // Attempt recovery
            MemoryStore.shared.attemptRecovery()
        }

        // Clear any potentially corrupted state
        SessionManager.shared.resetToSafeState()

        // Notify user if this is the 2nd+ crash today
        if CrashDetector.crashCountToday() > 1 {
            NotificationManager.send(
                title: "EmberHearth Recovered",
                body: "I had some trouble but I'm back now. If this keeps happening, please contact support."
            )
        }
    }
}
```

---

## Logging Strategy

### What Gets Logged

| Category | Logged | Retention | Sensitive Data |
|----------|--------|-----------|----------------|
| **Crashes** | Yes | 30 days | Stack trace only |
| **Errors** | Yes | 14 days | No user content |
| **Warnings** | Yes | 7 days | No user content |
| **API calls** | Metadata only | 7 days | No request/response bodies |
| **Messages** | Never | N/A | User content is private |
| **Facts** | Never | N/A | User content is private |

### Log Format

```
[2026-02-03T14:32:01Z] [ERROR] [LLMService] API call failed: timeout after 30s
[2026-02-03T14:32:01Z] [INFO] [LLMService] Retrying (attempt 2 of 4)
[2026-02-03T14:32:03Z] [INFO] [LLMService] Retry succeeded
```

### Log Location

```
~/Library/Logs/EmberHearth/
├── emberhearth.log       # Current log
├── emberhearth.1.log     # Previous (rotated)
├── emberhearth.2.log     # Older
└── crash/
    ├── 2026-02-03_143201.crash
    └── 2026-02-01_091532.crash
```

### Log Rotation

- Maximum log file size: 10 MB
- Maximum log files: 5 (50 MB total)
- Rotate on size limit reached
- Delete oldest when limit reached

### User Access to Logs

The Mac app provides:
- "Export Diagnostic Report" button
- Collects: logs, system info, anonymized usage stats
- User reviews before sending
- No automatic telemetry

### Privacy Guarantees

- **Never log message content**
- **Never log fact content**
- **Never log API request/response bodies**
- Logs are local-only (no cloud upload without explicit user action)
- User can delete all logs at any time

---

## User Communication Patterns

### Via iMessage

For failures that affect the conversation:

```
[Network outage]
"I'm having trouble connecting right now. I've saved your message and will respond when I'm back online."

[Extended outage]
"I've been offline for a while. I'm catching up on your messages now..."

[API key issue]
"There's a problem with my connection to the AI service. Could you check the API key in EmberHearth settings on your Mac?"

[Recovery from crash]
(Only if user sent messages during downtime)
"Sorry for the delay—I had to restart. What were you saying?"
```

### Via Mac Notifications

For system-level issues:

```
[Permission needed]
Title: "EmberHearth needs access"
Body: "To read your messages, please grant Full Disk Access in System Settings."
Action: "Open System Settings"

[Storage warning]
Title: "Low storage space"
Body: "EmberHearth needs storage for memories. Please free up space."

[Multiple crashes]
Title: "EmberHearth recovered"
Body: "I had some trouble but I'm back. Contact support if this continues."
Action: "Get Help"
```

### Never Communicate

- Technical details ("SQLite error code 11")
- Internal states ("XPC service MessageService crashed")
- Scary language ("Corruption detected")

Always translate to human terms: "I'm having trouble" not "Error 500 in LLMService.sendRequest()"

---

## Health Monitoring

### Startup Health Check

Run on every launch:

```swift
struct HealthCheck {
    func runStartupChecks() async -> HealthStatus {
        var issues: [HealthIssue] = []

        // 1. Check database integrity
        if !await MemoryStore.verifyIntegrity() {
            issues.append(.databaseCorruption)
        }

        // 2. Check permissions
        if !PermissionManager.hasFullDiskAccess() {
            issues.append(.missingPermission(.fullDiskAccess))
        }
        if !PermissionManager.hasAutomationAccess() {
            issues.append(.missingPermission(.automation))
        }

        // 3. Check API key validity
        if let apiKey = KeychainManager.getAPIKey() {
            if !await LLMService.validateKey(apiKey) {
                issues.append(.invalidAPIKey)
            }
        } else {
            issues.append(.missingAPIKey)
        }

        // 4. Check Messages.app
        if !MessageService.isMessagesAppAvailable() {
            issues.append(.messagesAppNotAvailable)
        }

        return HealthStatus(issues: issues)
    }
}
```

### Runtime Health Dashboard

Internal status (viewable in Mac app Settings → Status):

```
System Status
─────────────
iMessage:        ● Connected
LLM Provider:    ● Connected (Claude)
Memory:          ● Healthy (1,247 facts)
Calendar:        ○ Not configured
Reminders:       ● Connected
Mail:            ● Connected
Safari:          ○ Not configured

Last 24 Hours
─────────────
Messages received: 47
Messages sent: 43
API calls: 89
Errors: 2 (recovered)
```

### Periodic Health Checks

| Check | Frequency | Action on Failure |
|-------|-----------|-------------------|
| Database quick_check | Every hour | Full integrity check |
| FSEvents alive | Every 5 minutes | Re-register stream |
| LLM connectivity | Every 15 minutes (idle) | Update status display |
| XPC service heartbeat | Every 30 seconds | Restart service |
| Disk space | Every hour | Warn at <1GB, critical at <500MB |

---

## Recovery Procedures

### Manual Recovery Options

Available in Mac app → Settings → Troubleshooting:

**1. "Restart EmberHearth"**
- Graceful shutdown
- Clear temporary state
- Restart all services

**2. "Rebuild Message Connection"**
- Re-register FSEvents
- Restart MessageService
- Re-sync recent messages

**3. "Verify Memory Database"**
- Run integrity check
- Display results
- Offer repair if issues found

**4. "Restore from Backup"**
- Show available backups with dates
- User selects backup point
- Restore with confirmation
- Warn about data loss

**5. "Reset to Factory"** (last resort)
- Confirm multiple times
- Export current data first (offer)
- Delete all data
- Return to onboarding

**6. "Export Diagnostic Report"**
- Collect logs (sanitized)
- System information
- User reviews before saving
- For support requests

---

## Testing Requirements

### Error Simulation

Test suite must cover:

- [ ] LLM API timeout, 429, 401, 5xx responses
- [ ] Network disconnection during operation
- [ ] Database corruption (inject invalid data)
- [ ] Database lock contention
- [ ] XPC service crash and restart
- [ ] FSEvents stream interruption
- [ ] AppleScript timeout
- [ ] Disk full simulation
- [ ] Crash and recovery cycle

### Chaos Testing

Before release:
- Kill random XPC services during operation
- Disconnect network during API calls
- Corrupt database files
- Fill disk to capacity
- Crash app during database write

Verify: System recovers without data loss, user sees appropriate message.

---

## Implementation Checklist

### MVP Requirements

- [ ] LLM retry logic with exponential backoff
- [ ] Message queue for offline/error states
- [ ] Database backup (daily minimum)
- [ ] Database integrity check on startup
- [ ] launchd plist for crash recovery
- [ ] Basic logging (errors and crashes)
- [ ] User-facing error messages via iMessage
- [ ] Permission-denied handling with guidance
- [ ] Network connectivity monitoring

### Post-MVP (v1.1)

- [ ] Hourly database backups
- [ ] Full health check system
- [ ] XPC service heartbeat monitoring
- [ ] Diagnostic export feature
- [ ] Troubleshooting UI in Mac app
- [ ] Backup browser and restore UI

### Future (v1.2+)

- [ ] Anomaly detection in error patterns
- [ ] Self-diagnostic reports
- [ ] Automatic recovery suggestions
- [ ] Backup to iCloud (optional, encrypted)

---

## References

**macOS Auto-Restart:**
- [Restarting macOS apps automatically on crash](https://notes.alinpanaitiu.com/Restarting-macOS-apps-automatically-on-crash)
- [Apple launchd documentation](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
- [launchd.info tutorial](https://www.launchd.info/)

**SQLite Resilience:**
- [SQLite recovery documentation](https://sqlite.org/recovery.html)
- [SQLite corruption prevention](https://www.sqlite.org/howtocorrupt.html)

**Error Handling Philosophy:**
- [Graceful Failure: How Smart Error Handling Turns Crashes into Customer Trust](https://www.bettrsw.com/blogs/graceful-error-handling-software-failure-recovery-trust)

---

*Document created: February 2026*
*Status: Specification complete*
