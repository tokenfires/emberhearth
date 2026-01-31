# iMessage Integration Research

**Status:** Complete
**Priority:** High (Phase 1)
**Last Updated:** January 31, 2026

---

## Executive Summary

There are three primary approaches to integrating with iMessage on macOS:

1. **AppleScript + Database Polling** (Recommended) — Safe, documented, no private APIs
2. **Private API (IMCore)** — More capable but fragile, undocumented, risky
3. **Database-Only** — Read-only, cannot send messages

For EmberHearth, **Approach 1 (AppleScript + Database)** is recommended as it aligns with our security-first principles while providing full send/receive capability.

---

## Research Questions — Answered

### How does Messages.app automation work via AppleScript?

AppleScript can control Messages.app through Apple's automation framework. The basic pattern:

```applescript
tell application "Messages"
    set targetBuddy to buddy "+1234567890" of service "iMessage"
    send "Hello from EmberHearth" to targetBuddy
end tell
```

**Key points:**
- Uses Apple's public scripting dictionary (no private APIs)
- Works with both iMessage and SMS (if iPhone Text Forwarding enabled)
- Buddies can be identified by phone number, email, or name
- Service must be specified (iMessage vs SMS)
- Phone numbers should be normalized to E.164 format for reliable lookup

**Limitations:**
- Cannot read messages (only send)
- Cannot access typing indicators, read receipts, or reactions
- Requires Automation permission from user

### What are the sandboxing implications?

**Required Permissions:**

| Permission | Purpose | How to Request |
|------------|---------|----------------|
| Full Disk Access | Read `~/Library/Messages/chat.db` | System Settings → Privacy & Security → Full Disk Access |
| Automation | Control Messages.app for sending | Prompted automatically on first AppleScript execution |

**Sandbox Considerations:**
- The `~/Library/Messages` directory is protected since macOS Mojave (10.14)
- Sandboxed apps **cannot** access this directory without Full Disk Access
- Apps distributed via Mac App Store may have difficulty obtaining these permissions
- For EmberHearth (distributed outside App Store), this is manageable

**Important:** App Sandbox and Accessibility permissions can conflict. If App Sandbox is enabled, AXIsProcessTrusted may always return false, and permission prompts may not appear.

### Are there documented approaches using Swift?

No official Apple API exists for iMessage integration. However, Swift can:

1. **Execute AppleScript** via `NSAppleScript` or `Process` with `osascript`
2. **Read SQLite database** via `sqlite3` or libraries like GRDB
3. **Monitor filesystem** via `FSEvents` or `DispatchSource` for new messages

Example Swift approach for sending:
```swift
let script = """
tell application "Messages"
    set targetBuddy to buddy "\(phoneNumber)" of service "iMessage"
    send "\(message)" to targetBuddy
end tell
"""
var error: NSDictionary?
NSAppleScript(source: script)?.executeAndReturnError(&error)
```

### What private APIs exist and what are the risks?

**IMCore Framework** (`/System/Library/PrivateFrameworks/IMCore.framework`)

This is Apple's internal framework for iMessage/SMS handling. It provides deeper functionality:
- Send/receive with full features (reactions, typing indicators, read receipts)
- Tapbacks and message effects
- Group chat management
- Message editing/deletion

**Risks of using IMCore:**

| Risk | Impact |
|------|--------|
| **Crashes** | Exceptions crash the entire iMessage process |
| **No documentation** | Development is guesswork and reverse engineering |
| **Version breaking** | Each macOS update may break functionality |
| **Security checks** | `imagent` daemon verifies process permissions |
| **App Store rejection** | Private API use = automatic rejection |

**Architecture complexity:** Message sending involves multiple daemons via XPC:
```
Messages.app → imagent → identityservicesd → apsd
```

**Recommendation:** Avoid private APIs for EmberHearth. The stability and security risks contradict our core principles.

### How do existing projects handle this?

#### 1. imsg (CLI Tool)
**Repository:** [steipete/imsg](https://github.com/steipete/imsg)

- **Approach:** AppleScript for sending + SQLite for reading
- **Detection:** Filesystem events (not polling) for new messages
- **Features:** JSON output, attachment handling, phone normalization
- **Permissions:** Full Disk Access + Automation
- **No private APIs** — aligns with our approach

#### 2. BlueBubbles
**Repository:** [BlueBubblesApp/bluebubbles-server](https://github.com/BlueBubblesApp/bluebubbles-server)

- **Approach:** Hybrid — AppleScript for basic ops, Private API bundle for advanced features
- **Language:** TypeScript (Electron-based server)
- **Detection:** Database polling + filesystem events
- **Features:** Full iMessage feature set with Private API, Firebase push notifications
- **Compatibility:** macOS Sierra+ (10.12+)

#### 3. OSXMessageProxy
**Repository:** [ezhes/OSXMessageProxy](https://github.com/ezhes/OSXMessageProxy)

- **Approach:** Full Private API (IMCore)
- **Risk level:** High — crashes and version compatibility issues

---

## Technical Deep Dive

### The chat.db Database

**Location:** `~/Library/Messages/chat.db`

**Related files:**
- `chat.db-shm` — Shared memory file (WAL mode)
- `chat.db-wal` — Write-ahead log
- `~/Library/Messages/Attachments/` — Media files

**Key Tables:**

| Table | Purpose |
|-------|---------|
| `message` | Message content, timestamps, metadata |
| `handle` | Contact identifiers (phone/email) |
| `chat` | Conversation threads |
| `attachment` | File attachments with local paths |
| `chat_message_join` | Links messages to chats |
| `chat_handle_join` | Links handles to chats |
| `message_attachment_join` | Links attachments to messages |

**Important Schema Notes:**

1. **Timestamps** are in Apple epoch (seconds since January 1, 2001), not Unix epoch
   ```sql
   datetime(message.date / 1000000000 + strftime("%s", "2001-01-01"), "unixepoch", "localtime")
   ```

2. **Message text** changed in macOS Ventura — now stored as hex blob in `attributedBody` column, not plain text in `text` column

3. **Database is locked** during writes — always open in read-only mode:
   ```swift
   sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil)
   ```

### Detecting New Messages

**Option A: Filesystem Events (Recommended)**
```swift
let source = DispatchSource.makeFileSystemObjectSource(
    fileDescriptor: fd,
    eventMask: .write,
    queue: .main
)
source.setEventHandler { /* Query for new messages */ }
source.resume()
```

**Option B: Polling**
- Query database every N seconds
- Less efficient, but simpler
- BlueBubbles uses this approach

**Option C: FSEvents API**
- Lower-level macOS API
- Can monitor entire directory tree
- Used by `imsg` tool

### SMS Support

iMessage-only is simpler, but SMS support requires:
1. iPhone with "Text Message Forwarding" enabled (Settings → Messages → Text Message Forwarding)
2. Same Apple ID on Mac and iPhone
3. Both devices on same network during initial setup

SMS messages appear in the same database with different `service` value.

---

## Recommended Architecture for EmberHearth

```
┌─────────────────────────────────────────────────────────────┐
│                      EmberHearth App                         │
├─────────────────────────────────────────────────────────────┤
│  MessageService                                              │
│  ├── MessageReader (SQLite, read-only)                      │
│  │   └── Monitors chat.db via FSEvents                      │
│  ├── MessageSender (AppleScript via NSAppleScript)          │
│  │   └── Sends via Messages.app automation                  │
│  └── MessageParser                                          │
│       └── Handles attributedBody decoding (Ventura+)        │
├─────────────────────────────────────────────────────────────┤
│  Permissions                                                 │
│  ├── Full Disk Access (required)                            │
│  └── Automation - Messages.app (required)                   │
└─────────────────────────────────────────────────────────────┘
```

### Implementation Steps

1. **Create MessageReader service**
   - Open `chat.db` in read-only mode
   - Query for messages after last-seen timestamp
   - Monitor via FSEvents for real-time detection
   - Handle both `text` and `attributedBody` columns

2. **Create MessageSender service**
   - Execute AppleScript via NSAppleScript
   - Normalize phone numbers to E.164
   - Handle send failures gracefully

3. **Build permission onboarding flow**
   - Guide user through Full Disk Access
   - Explain why permissions are needed
   - Verify permissions before proceeding

4. **Handle edge cases**
   - Group chats (multiple handles)
   - Attachments (images, files)
   - Message reactions (if needed, may require Private API)

---

## Permissions Onboarding UX

Since EmberHearth requires sensitive permissions, the onboarding must be clear and trustworthy:

```
┌────────────────────────────────────────┐
│  EmberHearth needs permission to       │
│  read and send messages.               │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ 1. Open System Settings          │  │
│  │ 2. Go to Privacy & Security      │  │
│  │ 3. Select Full Disk Access       │  │
│  │ 4. Enable EmberHearth            │  │
│  └──────────────────────────────────┘  │
│                                        │
│  Why is this needed?                   │
│  Messages are stored in a protected    │
│  location. This permission lets        │
│  EmberHearth read your conversations.  │
│                                        │
│  [Open System Settings]  [I've Done It]│
└────────────────────────────────────────┘
```

---

## Security Considerations

| Concern | Mitigation |
|---------|------------|
| Message data access | All processing local; no cloud sync |
| AppleScript injection | Sanitize all message content before sending |
| Database corruption | Read-only access; never write to chat.db |
| Permission escalation | Request minimum necessary permissions |
| Credential exposure | Never log message content |

---

## Compatibility Matrix

| macOS Version | Database Location | Message Text | Notes |
|---------------|-------------------|--------------|-------|
| 10.12 Sierra | `~/Library/Messages/chat.db` | `text` column | Oldest supported |
| 10.13 High Sierra | Same | `text` column | |
| 10.14 Mojave | Same | `text` column | Full Disk Access required |
| 10.15 Catalina | Same | `text` column | |
| 11 Big Sur | Same | `text` column | |
| 12 Monterey | Same | `text` column | |
| 13 Ventura | Same | `attributedBody` (hex blob) | Schema change |
| 14 Sonoma | Same | `attributedBody` | |
| 15 Sequoia | Same | `attributedBody` | Current |

---

## Resources

### Official Documentation
- [Apple Developer: Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
- [Apple Developer: Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)

### Open Source Projects
- [steipete/imsg](https://github.com/steipete/imsg) — CLI tool, AppleScript + SQLite approach
- [BlueBubblesApp/bluebubbles-server](https://github.com/BlueBubblesApp/bluebubbles-server) — Full-featured server
- [niftycode/imessage_reader](https://github.com/niftycode/imessage_reader) — Python library for reading
- [MacPaw/PermissionsKit](https://github.com/MacPaw/PermissionsKit) — Permission checking library

### Community Resources
- [BlueBubbles Private API Docs](https://docs.bluebubbles.app/private-api/imcore-documentation)
- [The Apple Wiki: IMCore.framework](https://theapplewiki.com/wiki/Dev:IMCore.framework)
- [Accessing Your iMessages with SQL](https://davidbieber.com/snippets/2020-05-20-imessage-sql-db/)
- [Searching Your iMessage Database with SQL](https://spin.atomicobject.com/search-imessage-sql/)

---

## Recommendation

**Use AppleScript + SQLite database polling.**

This approach:
- Uses only public, documented APIs
- Provides full send/receive capability
- Aligns with EmberHearth's security-first principles
- Is stable across macOS versions (with minor adjustments for Ventura+)
- Can be distributed outside the Mac App Store without issues

**Do NOT use:**
- Private APIs (IMCore) — Too fragile, undocumented, security risks
- Accessibility permission hacks — Conflicts with sandbox
- Third-party relay services — Privacy concerns

**Next Steps:**
1. Prototype `MessageReader` with SQLite + FSEvents
2. Prototype `MessageSender` with AppleScript
3. Design permission onboarding flow
4. Test on macOS Ventura+ for `attributedBody` handling
