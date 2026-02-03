# ADR-0010: FSEvents for Active Data Monitoring

## Status
**Accepted**

## Date
February 2026

## Context

EmberHearth needs to detect changes across multiple data sources:
- iMessage database (`chat.db`)
- Safari files (`History.db`, `Bookmarks.plist`)
- Notes database (`NoteStore.sqlite`)
- Calendar/Reminders (EventKit has built-in notifications)

Monitoring approaches:
1. **Polling:** Check files periodically
2. **FSEvents:** OS-level file system change notifications
3. **EventKit notifications:** For Calendar/Reminders specifically
4. **Hybrid:** Combine approaches per source

## Decision

**Use FSEvents as the primary monitoring mechanism for file-based data sources.**

```
┌─────────────────────────────────────────────────────┐
│           Active Data Intake Daemon                  │
├─────────────────────────────────────────────────────┤
│                                                     │
│  FSEvents Monitors:                                 │
│  ├── ~/Library/Messages/chat.db                    │
│  ├── ~/Library/Safari/History.db                   │
│  ├── ~/Library/Safari/Bookmarks.plist              │
│  └── ~/Library/Group Containers/.../NoteStore.sqlite│
│                                                     │
│  EventKit Notifications:                            │
│  ├── EKEventStoreChanged (Calendar)                │
│  └── EKEventStoreChanged (Reminders)               │
│                                                     │
│  Polling Fallback:                                  │
│  └── Mail.app (no change notifications)            │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Consequences

### Positive
- **Efficiency:** No CPU waste on unchanged files
- **Low latency:** Events fire within ~1 second of change
- **OS-native:** Leverages macOS's built-in infrastructure
- **Battery-friendly:** No constant polling loops
- **Scalable:** Can monitor many paths efficiently

### Negative
- **File-level granularity:** Knows file changed, not what changed
- **Requires parsing:** Must read and diff to find actual changes
- **Coalescing:** Multiple rapid changes may coalesce
- **Persistence:** Must track lastEventId across restarts

### Neutral
- **Latency tuning:** Can adjust coalescing latency (0.5-2s typical)
- **Fallback needed:** Some sources (Mail) need polling

## Implementation Pattern

```swift
class FileSystemMonitor {
    private var stream: FSEventStreamRef?

    func startMonitoring(paths: [String],
                         latency: TimeInterval = 1.0,
                         callback: @escaping ([String]) -> Void) {
        var context = FSEventStreamContext(...)

        let flags: FSEventStreamCreateFlags = [
            .useCFTypes,
            .fileEvents,      // Per-file events (not just directory)
            .noDefer          // Don't defer initial events
        ]

        stream = FSEventStreamCreate(
            nil,
            eventCallback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        )

        FSEventStreamScheduleWithRunLoop(stream!, ...)
        FSEventStreamStart(stream!)
    }

    func stop() {
        FSEventStreamStop(stream!)
        FSEventStreamInvalidate(stream!)
        FSEventStreamRelease(stream!)
    }
}
```

## Per-Source Strategy

| Source | Primary | Fallback | Notes |
|--------|---------|----------|-------|
| iMessage | FSEvents on chat.db | Polling (5s) | Lock-free read via copy |
| Safari History | FSEvents | Polling (30s) | Locked while Safari runs |
| Safari Bookmarks | FSEvents | - | Plist, always readable |
| Notes | FSEvents | Polling (30s) | SQLite, may need copy |
| Calendar | EventKit notification | - | Native API preferred |
| Reminders | EventKit notification | - | Native API preferred |
| Mail | Polling (60-120s) | - | No change notification API |

## Change Detection Pattern

When FSEvents fires, we need to determine what actually changed:

```swift
func handleFileChange(path: String) async {
    switch path {
    case chatDBPath:
        // Query for messages with ROWID > lastKnownRowID
        let newMessages = try await queryNewMessages(since: lastRowID)
        for message in newMessages {
            await eventQueue.enqueue(.newMessage(message))
        }
        lastRowID = newMessages.last?.rowID ?? lastRowID

    case bookmarksPath:
        // Parse plist, diff against cached state
        let current = try parseBookmarks(at: path)
        let changes = diff(cached: cachedBookmarks, current: current)
        cachedBookmarks = current
        for change in changes {
            await eventQueue.enqueue(.bookmarkChange(change))
        }
    }
}
```

## Alternatives Considered

### Polling Only
- Simpler implementation
- Rejected: Wastes resources; higher latency

### Dispatch Sources (GCD)
- Fine-grained file descriptor watching
- Rejected: FSEvents more appropriate for our use case

### kqueue
- Lower-level BSD API
- Rejected: FSEvents is higher-level and sufficient

### Third-Party Library
- May add features
- Rejected for MVP: FSEvents API is straightforward

## References

- `docs/research/active-data-intake.md` — Intake daemon architecture
- `docs/research/imessage.md` — chat.db monitoring
- `docs/research/safari-integration.md` — Safari file monitoring
- Apple Documentation — FSEvents Programming Guide
