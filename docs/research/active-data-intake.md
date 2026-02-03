# Active Data Intake System

> *"The personality is the theater. The data pipeline is the play."*

## Overview

This document describes EmberHearth's **Active Data Intake System**—the continuous monitoring layer that transforms a reactive chatbot into a genuinely proactive assistant. This is arguably the most important architectural component for delivering the core value proposition.

**The fundamental insight:** Users don't just use their Apple devices—they *generate data* constantly. Notes, reminders, calendar events, browser bookmarks, text conversations, app notifications. A personal assistant that only responds to queries is missing 90% of the opportunity. The value comes from being system-aware and acting on new information before being asked.

**What this document covers:**
- The data ecosystem users generate
- How EmberHearth monitors each data source
- Cross-device sync via iCloud
- Security controls on active monitoring
- The architecture that ties intake to anticipation

---

## The Value Proposition

### Why This Matters

The "AI promise" people actually want:

| What users SAY they want | What they ACTUALLY want |
|--------------------------|------------------------|
| "Answer my questions" | "Know things before I ask" |
| "Help me manage tasks" | "Notice when things fall through cracks" |
| "Remember what I tell you" | "Pay attention to my whole digital life" |
| "Be available when I need you" | "Be watching, so you catch what I miss" |

A personal assistant that waits for instructions is just a chatbot. A personal assistant that **notices**—that sees the calendar conflict, the forgotten follow-up, the research pattern, the deadline approaching—is what people are paying for.

### The Moltbot Validation

Moltbot proved this value proposition works. Users loved that "the AI promise was finally being delivered." The system:
- Watched Gmail for incoming messages
- Monitored calendar for upcoming events
- Ran scheduled "heartbeat" checks
- Triggered proactive notifications

**The problem:** Moltbot achieved this by opening the floodgates—shell execution, unrestricted browser control, no security boundaries. Decades of security best practices abandoned.

**EmberHearth's challenge:** Deliver the same value with proper security controls.

---

## The Data Ecosystem

### Minimal Setup: Mac Mini + iPhone

A user with the minimal EmberHearth setup generates data across two devices:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        USER'S DATA ECOSYSTEM                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────────────────────┐     ┌─────────────────────────────┐  │
│   │         MAC MINI            │     │          iPHONE             │  │
│   │    (EmberHearth runs)       │     │    (Data generation)        │  │
│   │                             │     │                             │  │
│   │  • Calendar.app             │     │  • Calendar.app             │  │
│   │  • Reminders.app            │     │  • Reminders.app            │  │
│   │  • Notes.app                │     │  • Notes.app                │  │
│   │  • Mail.app                 │     │  • Mail.app                 │  │
│   │  • Safari                   │     │  • Safari                   │  │
│   │  • Messages (iMessage)      │←────│  • Messages (iMessage)      │  │
│   │  • Third-party apps         │     │  • Third-party apps         │  │
│   │                             │     │  • Push notifications       │  │
│   │                             │     │  • Location data            │  │
│   └──────────────┬──────────────┘     └──────────────┬──────────────┘  │
│                  │                                    │                 │
│                  │        ┌────────────────┐          │                 │
│                  └───────▶│    iCLOUD      │◀─────────┘                 │
│                           │                │                            │
│                           │  Sync bridge   │                            │
│                           │  • CloudKit    │                            │
│                           │  • Key-Value   │                            │
│                           │  • Documents   │                            │
│                           └────────────────┘                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Sources and Generation Patterns

| Source | What Gets Generated | Generation Frequency | Value to Assistant |
|--------|--------------------|--------------------|-------------------|
| **Calendar** | Events, meetings, deadlines | Multiple times/day | High—scheduling, conflicts, preparation |
| **Reminders** | Tasks, due dates, lists | Multiple times/day | High—task management, follow-up |
| **Notes** | Ideas, research, lists | Several times/week | Medium—context, projects, interests |
| **Mail** | Correspondence, receipts, confirmations | Constant | High—commitments, action items |
| **Safari** | Bookmarks, history, Reading List | Constant | Medium—interests, research patterns |
| **Messages** | Conversations with others | Constant | High—commitments, context, relationships |
| **App Notifications** | Alerts from all apps | Constant | Medium—time-sensitive information |
| **Location** | Where user is/goes | Continuous (iOS) | Medium—context, travel, routines |

### The iCloud Bridge

iPhone data reaches the Mac via iCloud sync:

| Data Type | Sync Mechanism | Latency | Mac Access |
|-----------|---------------|---------|------------|
| Calendar | CloudKit | Near-instant | EventKit API |
| Reminders | CloudKit | Near-instant | EventKit API |
| Notes | CloudKit | Near-instant | AppleScript / SQLite |
| Safari Bookmarks | CloudKit | Near-instant | Bookmarks.plist |
| Safari History | Local only | N/A | History.db (Mac only) |
| Messages | CloudKit | Near-instant | chat.db (requires FDA) |
| Mail | IMAP/CloudKit | Varies | AppleScript / Mail.app |
| Photos | CloudKit | Background | PhotoKit API |

**Key insight:** Most user data syncs automatically to the Mac where EmberHearth runs. We don't need an iOS companion app for basic functionality—iCloud does the work.

---

## Monitoring Architecture

### The Intake Daemon

EmberHearth runs a persistent background process that monitors all configured data sources:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      ACTIVE INTAKE DAEMON                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    DATA SOURCE MONITORS                          │   │
│   │                                                                 │   │
│   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │   │
│   │  │ Calendar │ │Reminders │ │  Notes   │ │   Mail   │           │   │
│   │  │ Monitor  │ │ Monitor  │ │ Monitor  │ │ Monitor  │           │   │
│   │  │          │ │          │ │          │ │          │           │   │
│   │  │EventKit  │ │EventKit  │ │FSEvents  │ │AppleScrpt│           │   │
│   │  │Notif.    │ │Notif.    │ │+AppleSc. │ │Polling   │           │   │
│   │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │   │
│   │       │            │            │            │                  │   │
│   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │   │
│   │  │ Safari   │ │ Messages │ │Notific.  │ │ Files    │           │   │
│   │  │ Monitor  │ │ Monitor  │ │ Monitor  │ │ Monitor  │           │   │
│   │  │          │ │          │ │          │ │          │           │   │
│   │  │FSEvents  │ │FSEvents  │ │UNUser    │ │FSEvents  │           │   │
│   │  │Plist/DB  │ │chat.db   │ │NotifCtr  │ │Watched   │           │   │
│   │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │   │
│   │       │            │            │            │                  │   │
│   └───────┼────────────┼────────────┼────────────┼──────────────────┘   │
│           │            │            │            │                      │
│           └────────────┴─────┬──────┴────────────┘                      │
│                              │                                          │
│                      ┌───────▼───────┐                                  │
│                      │  EVENT QUEUE  │                                  │
│                      │               │                                  │
│                      │ Normalized    │                                  │
│                      │ data events   │                                  │
│                      └───────┬───────┘                                  │
│                              │                                          │
│           ┌──────────────────┼──────────────────┐                       │
│           │                  │                  │                       │
│   ┌───────▼───────┐  ┌───────▼───────┐  ┌───────▼───────┐              │
│   │ TRON FILTER   │  │   CONTEXT     │  │ ANTICIPATION  │              │
│   │               │  │   BUILDER     │  │   ENGINE      │              │
│   │ Security      │  │               │  │               │              │
│   │ screening     │  │ Enrichment    │  │ Pattern       │              │
│   │               │  │               │  │ matching      │              │
│   └───────────────┘  └───────────────┘  └───────────────┘              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Per-Source Monitoring Strategies

#### Calendar & Reminders (EventKit)

**Method:** Native notification-based monitoring

```swift
// Register for EventStore changes
NotificationCenter.default.addObserver(
    self,
    selector: #selector(eventStoreChanged),
    name: .EKEventStoreChanged,
    object: eventStore
)

@objc func eventStoreChanged(_ notification: Notification) {
    // Fetch changes since last sync
    // Compare with known state
    // Emit new/modified/deleted events to queue
}
```

**What triggers:**
- New event created (on any synced device)
- Event modified
- Event deleted
- Reminder completed
- Reminder due date approaching

**Latency:** Near-instant via CloudKit push

#### Notes (AppleScript + FSEvents)

**Method:** Hybrid—FSEvents for file changes, AppleScript for content

**File to watch:**
```
~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite
```

**Monitoring approach:**
1. FSEvents detects database modification
2. Query database for changes since last check
3. AppleScript can fetch note content if needed

**Latency:** Near-instant for local changes; iCloud sync adds ~1-5 seconds

#### Mail (AppleScript + Polling)

**Method:** Periodic AppleScript queries (Mail.app lacks change notifications)

```applescript
tell application "Mail"
    set unreadMessages to messages of inbox whose read status is false
    repeat with msg in unreadMessages
        -- Check if we've seen this message before
        -- Extract sender, subject, date
    end repeat
end tell
```

**Polling interval:** 60-120 seconds (configurable)

**Why polling:** Mail.app doesn't expose change notifications. AppleScript is the only automation interface.

#### Safari (FSEvents + Periodic Read)

**Method:** FSEvents for file changes, periodic content extraction

**Files to monitor:**
```
~/Library/Safari/Bookmarks.plist
~/Library/Safari/History.db
~/Library/Safari/ReadingList.plist
```

**Monitoring approach:**
1. FSEvents detects file modification
2. Parse changed file to identify new/modified items
3. Compare with known state

**Note:** History.db is locked while Safari runs—may need to copy file first.

#### Messages/iMessage (FSEvents on chat.db)

**Method:** FSEvents monitoring of chat.db

**File to monitor:**
```
~/Library/Messages/chat.db
```

**Monitoring approach:**
1. FSEvents detects database change
2. Query for messages newer than last known ROWID
3. Extract new messages and metadata

**Latency:** Near-instant

**Requires:** Full Disk Access permission

#### System Notifications (UNUserNotificationCenter)

**Method:** Request notification access, observe delivered notifications

**Approach:**
1. Request notification authorization
2. Implement UNUserNotificationCenterDelegate
3. Capture notifications as they arrive

**Limitations:**
- Only captures notifications delivered while EmberHearth is running
- Cannot access other apps' notification history
- Requires user permission

---

## The FSEvents Foundation

### How FSEvents Works

FSEvents is macOS's native file system change notification system:

```
┌───────────────────────────────────────────────────────────────────┐
│                         FSEvents FLOW                              │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│   File System Change                                              │
│         │                                                         │
│         ▼                                                         │
│   ┌─────────────┐                                                 │
│   │   Kernel    │  Passes notification via /dev/fsevents          │
│   └──────┬──────┘                                                 │
│          │                                                        │
│          ▼                                                        │
│   ┌─────────────┐                                                 │
│   │  fseventsd  │  System daemon (runs as root)                   │
│   └──────┬──────┘                                                 │
│          │                                                        │
│          ▼                                                        │
│   ┌─────────────┐                                                 │
│   │ FSEventStr- │  Application's event stream                     │
│   │    eam      │                                                 │
│   └──────┬──────┘                                                 │
│          │                                                        │
│          ▼                                                        │
│   ┌─────────────┐                                                 │
│   │  Callback   │  Your code handles the event                    │
│   └─────────────┘                                                 │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

### Swift Implementation Pattern

```swift
import Foundation

class FileSystemMonitor {
    private var stream: FSEventStreamRef?

    func startMonitoring(paths: [String], callback: @escaping ([String]) -> Void) {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents  // Per-file events
        )

        stream = FSEventStreamCreate(
            nil,
            { (stream, info, numEvents, eventPaths, eventFlags, eventIds) in
                // Handle events
                let paths = Unmanaged<CFArray>.fromOpaque(eventPaths)
                    .takeUnretainedValue() as! [String]
                // Call handler
            },
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,  // Latency in seconds
            flags
        )

        FSEventStreamScheduleWithRunLoop(
            stream!,
            CFRunLoopGetCurrent(),
            CFRunLoopMode.defaultMode.rawValue
        )
        FSEventStreamStart(stream!)
    }
}
```

### Best Practices

1. **Watch directories, not individual files** — More efficient
2. **Use coalescing latency** — 0.5-2 seconds reduces event spam
3. **Handle kFSEventStreamEventFlagMustScanSubDirs** — Full rescan needed
4. **Persist lastEventId** — Resume monitoring across app restarts
5. **Be mindful of CPU** — Large numbers of monitored paths can cause issues

---

## Security Controls: Tron Integration

### The Security Model for Active Monitoring

Active data intake is powerful—and potentially dangerous. Tron enforces security controls:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    TRON INTAKE SECURITY LAYER                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    PERMISSION GATES                              │   │
│   │                                                                 │   │
│   │  Before ANY data source is monitored:                           │   │
│   │  ✓ User has granted access in Settings                          │   │
│   │  ✓ Appropriate system permission exists (FDA, Calendar, etc.)   │   │
│   │  ✓ Source is not in "blocked" list                              │   │
│   │                                                                 │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    DATA FILTERING                                │   │
│   │                                                                 │   │
│   │  All incoming data is screened:                                 │   │
│   │  ✓ Sensitive content detection (passwords, keys, credentials)   │   │
│   │  ✓ Work/Personal context routing                                │   │
│   │  ✓ PII handling according to policy                             │   │
│   │  ✓ Injection attempt detection (for message content)            │   │
│   │                                                                 │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    ACTION AUTHORIZATION                          │   │
│   │                                                                 │   │
│   │  Intake is READ-ONLY by default. Actions require:               │   │
│   │  ✓ Explicit user configuration allowing the action type         │   │
│   │  ✓ Tron authorization for each specific action                  │   │
│   │  ✓ Audit logging of all actions taken                           │   │
│   │                                                                 │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Read vs. React

The intake system has two modes:

**Read Mode (Default):**
- Ember observes data changes
- Builds context and understanding
- Updates memory with learned information
- Does NOT take action

**React Mode (Requires Configuration):**
- Ember can respond to observations
- Send proactive messages ("You have a conflict...")
- Create derived content (summaries, suggestions)
- Still cannot modify source data without explicit tool call

**Action Mode (Requires Explicit Authorization):**
- Ember can modify data (create reminders, events, etc.)
- Each action type configured separately
- All actions logged
- User can disable at any time

### What Tron Blocks

| Scenario | Tron Response |
|----------|---------------|
| Intake detects password in note | Redact from context; never send to LLM |
| Message contains potential prompt injection | Flag for review; don't process as instruction |
| Calendar event in "Work" calendar | Route to work context only |
| User has disabled Mail monitoring | Silently skip Mail intake |
| Intake volume spike (possible attack) | Rate limit; alert user |

---

## The Event Queue

### Normalized Event Format

All monitors emit events in a standard format:

```swift
struct IntakeEvent {
    let id: UUID
    let timestamp: Date
    let source: DataSource          // .calendar, .reminders, .notes, etc.
    let eventType: EventType        // .created, .modified, .deleted
    let context: Context            // .personal, .work
    let summary: String             // Human-readable summary
    let contentHash: String         // For deduplication
    let rawData: [String: Any]      // Source-specific data
    let priority: Priority          // .low, .normal, .high, .urgent
    let requiresAction: Bool        // Does this need response?
}

enum DataSource {
    case calendar
    case reminders
    case notes
    case mail
    case safari
    case messages
    case notifications
    case files
}
```

### Event Processing Pipeline

```
Event arrives
     │
     ▼
┌────────────────┐
│  Deduplication │  Have we seen this content hash recently?
└───────┬────────┘
        │ (new event)
        ▼
┌────────────────┐
│ Tron Screening │  Security checks, sensitive content filtering
└───────┬────────┘
        │ (cleared)
        ▼
┌────────────────┐
│Context Routing │  Personal or Work? Route appropriately.
└───────┬────────┘
        │
        ▼
┌────────────────┐
│Priority Assess │  How urgent? Does it need immediate attention?
└───────┬────────┘
        │
   ┌────┴────┐
   │         │
   ▼         ▼
┌─────┐   ┌──────────────┐
│Queue│   │ Anticipation │  High-priority events trigger
│     │   │ Engine       │  immediate evaluation
└──┬──┘   └──────────────┘
   │
   ▼
Background processing
(memory updates, pattern learning)
```

---

## Connecting Intake to Anticipation

### The Full Pipeline

The Active Data Intake System feeds the Anticipation Engine described in VISION.md:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    INTAKE → ANTICIPATION PIPELINE                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   DATA SOURCES                    INTAKE DAEMON                         │
│   ┌─────────────┐                ┌─────────────┐                        │
│   │ Calendar    │───────────────▶│             │                        │
│   │ Reminders   │───────────────▶│   Event     │                        │
│   │ Notes       │───────────────▶│   Queue     │                        │
│   │ Mail        │───────────────▶│             │                        │
│   │ Safari      │───────────────▶│   (Tron     │                        │
│   │ Messages    │───────────────▶│   screened) │                        │
│   │ Notifs      │───────────────▶│             │                        │
│   └─────────────┘                └──────┬──────┘                        │
│                                         │                               │
│                                         ▼                               │
│                          ┌──────────────────────────┐                   │
│                          │   ANTICIPATION ENGINE    │                   │
│                          │                          │                   │
│                          │  • Pattern Detector      │                   │
│                          │  • Knowledge Graph       │                   │
│                          │  • Opportunity Detector  │                   │
│                          │  • Salience Filter       │                   │
│                          │  • Timing Judgment       │                   │
│                          │  • Intrusion Gate        │                   │
│                          │                          │                   │
│                          └────────────┬─────────────┘                   │
│                                       │                                 │
│                    ┌──────────────────┼──────────────────┐              │
│                    │                  │                  │              │
│                    ▼                  ▼                  ▼              │
│              ┌──────────┐      ┌──────────┐      ┌──────────┐          │
│              │ Memory   │      │ Proactive│      │ Prepared │          │
│              │ Update   │      │ Message  │      │ Response │          │
│              │          │      │ to User  │      │ (Ready)  │          │
│              └──────────┘      └──────────┘      └──────────┘          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Example Flow: Calendar Conflict Detected

1. **Intake:** User creates event on iPhone calendar
2. **iCloud Sync:** Event syncs to Mac (~1 second)
3. **EventKit Notification:** EmberHearth receives EKEventStoreChanged
4. **Monitor:** Calendar Monitor fetches new event
5. **Event Queue:** Normalized event enters queue
6. **Tron:** Screens event (passes—no sensitive content)
7. **Context:** Routes to personal context
8. **Anticipation Engine:**
   - Pattern Detector: Checks for conflicts with existing events
   - Finds conflict: Two events at same time
   - Salience Filter: High salience (scheduling conflict)
   - Timing: User should know now (conflict is tomorrow)
   - Intrusion Gate: User has proactive notifications enabled
9. **Proactive Message:** "I noticed you have two events scheduled at 2pm tomorrow: [Event A] and [Event B]. Would you like me to help reschedule one?"

**Total latency:** ~5-10 seconds from event creation to proactive notification

---

## iOS Companion App (Future)

### What iCloud Doesn't Provide

Some iOS data doesn't sync to Mac:

| Data Type | iCloud Sync? | Needs iOS App? |
|-----------|--------------|----------------|
| Calendar events | ✅ Yes | No |
| Reminders | ✅ Yes | No |
| Notes | ✅ Yes | No |
| Safari bookmarks | ✅ Yes | No |
| Messages | ✅ Yes | No |
| Health data | ❌ No | Yes |
| Location (real-time) | ❌ No | Yes |
| App notifications | ❌ No | Yes |
| Screen time | ❌ No | Yes |
| Fitness/Activity | ❌ No | Yes |

### Future: EmberHearth iOS Companion

For users who want deeper integration:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    iOS COMPANION ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────────────────────┐     ┌─────────────────────────────┐  │
│   │         iPHONE              │     │         MAC MINI            │  │
│   │                             │     │                             │  │
│   │  EmberHearth Companion      │     │  EmberHearth Core           │  │
│   │  ┌───────────────────────┐  │     │                             │  │
│   │  │ Health Monitor        │  │     │                             │  │
│   │  │ Location Monitor      │──┼─────│──▶ Intake Daemon           │  │
│   │  │ Notification Capture  │  │     │                             │  │
│   │  │ Activity Monitor      │  │     │                             │  │
│   │  └───────────────────────┘  │     │                             │  │
│   │            │                │     │                             │  │
│   │            ▼                │     │                             │  │
│   │  ┌───────────────────────┐  │     │                             │  │
│   │  │ CloudKit Private DB   │──┼─────│──▶ CloudKit Listener       │  │
│   │  │ (Encrypted sync)      │  │     │                             │  │
│   │  └───────────────────────┘  │     │                             │  │
│   │                             │     │                             │  │
│   └─────────────────────────────┘     └─────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Privacy model:** All data encrypted in CloudKit private database. Only user's devices can decrypt.

---

## Implementation Checklist

### Phase 1: Core Intake (MVP)

**File System Monitoring:**
- [ ] FSEvents infrastructure for watching paths
- [ ] Reliable event coalescing and debouncing
- [ ] Cross-app-restart persistence (lastEventId)

**Source Monitors:**
- [ ] Calendar monitor (EventKit notifications)
- [ ] Reminders monitor (EventKit notifications)
- [ ] Messages monitor (FSEvents on chat.db)
- [ ] Safari monitor (FSEvents on Bookmarks.plist, History.db)

**Event Processing:**
- [ ] Normalized event format
- [ ] Event queue with priority handling
- [ ] Deduplication by content hash
- [ ] Tron integration for security screening

**Output:**
- [ ] Memory system updates from intake
- [ ] Context building for conversations

### Phase 2: Enhanced Intake

**Additional Monitors:**
- [ ] Notes monitor (FSEvents + AppleScript)
- [ ] Mail monitor (AppleScript polling)
- [ ] Files monitor (user-configured directories)

**Anticipation Connection:**
- [ ] Pattern detector receiving events
- [ ] Salience filtering
- [ ] Proactive notification generation
- [ ] Intrusion calibration learning

### Phase 3: Cross-Device

**iCloud Integration:**
- [ ] CKSyncEngine for custom data
- [ ] CloudKit change notifications
- [ ] iOS companion app (if pursued)

---

## Configuration Surface

### User-Facing Settings

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SETTINGS → DATA AWARENESS                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Ember monitors your data to provide proactive assistance.              │
│  All data stays on your device. Configure what Ember can see:           │
│                                                                         │
│  DATA SOURCES                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ ☑ Calendar          [Personal ▼] [Work ▼]                       │   │
│  │ ☑ Reminders         [All Lists ▼]                               │   │
│  │ ☑ Messages          [Requires Full Disk Access]                 │   │
│  │ ☑ Safari Bookmarks  [Enabled]                                   │   │
│  │ ☐ Safari History    [Disabled—enable for research awareness]    │   │
│  │ ☐ Notes             [Disabled]                                  │   │
│  │ ☐ Mail              [Disabled]                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  PROACTIVE NOTIFICATIONS                                                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ ☑ Calendar conflicts                                            │   │
│  │ ☑ Upcoming deadlines                                            │   │
│  │ ☐ Research patterns ("You've been reading about X...")          │   │
│  │ ☐ Message follow-ups                                            │   │
│  │                                                                 │   │
│  │ Notification frequency: [Balanced ▼]                            │   │
│  │   Conservative | Balanced | Proactive                           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Open Questions

1. **Mail polling frequency:** What's the right balance between responsiveness and battery/API load?

2. **iCloud sync latency:** How reliably can we depend on near-instant sync? What's the fallback if sync is slow?

3. **FSEvents reliability:** Are there edge cases where FSEvents misses changes? Do we need periodic full scans as backup?

4. **Notification capture legality:** Can we capture notifications from other apps? What are the privacy implications?

5. **iOS companion necessity:** Is the iPhone data that doesn't sync (Health, Location) important enough to justify an iOS app?

6. **Event volume management:** How do we handle users with very high data generation (100+ emails/day, constant calendar changes)?

7. **Background execution limits:** How does macOS App Nap affect our monitoring? Do we need to request exemptions?

---

## Related Documents

- `VISION.md` — Anticipation Engine architecture
- `security.md` — Tron security layer
- `macos-apis.md` — Apple framework capabilities
- `safari-integration.md` — Safari-specific monitoring details
- `imessage.md` — Messages/chat.db monitoring
- `reference/MOLTBOT-ANALYSIS.md` — How Moltbot implemented always-on

---

*Document created: February 2026*
*Status: Initial architecture defined*
