# ADR-0003: iMessage as Primary Interface

## Status
**Accepted**

## Date
February 2026

## Context

EmberHearth needs a user interface for conversation. Options include:
- Native Mac app with chat UI
- Web interface
- Existing messaging platforms (iMessage, Telegram, Discord, etc.)
- Voice interface

Target users are non-technical people who want an always-available assistant.

## Decision

**Use iMessage as the primary conversational interface.**

Users text Ember via iMessage to their own phone number (or a dedicated number). EmberHearth reads incoming messages from `chat.db` and sends responses via Messages.app automation.

A native Mac app exists for:
- Onboarding and configuration
- Settings management
- Data browsing (facts, conversation archive)
- Administrative tasks

The Mac app is NOT the primary conversation interface.

## Consequences

### Positive
- **Zero learning curve:** Users already know iMessage
- **Always available:** Works from any device with iMessage (iPhone, iPad, Mac, Apple Watch)
- **Accessibility built-in:** Inherits Apple's VoiceOver, Dynamic Type, etc.
- **No new app to check:** Assistant lives where user already communicates
- **Cross-device:** Message from iPhone, response visible everywhere
- **Rich messages:** Supports images, links, reactions (future)

### Negative
- **Requires Full Disk Access:** To read chat.db (see ADR-0002)
- **AppleScript dependency:** Sending requires Messages.app automation
- **No Private API:** Cannot use Apple's private iMessage APIs
- **Single platform:** Only works within Apple ecosystem
- **Latency:** Message detection has slight delay (FSEvents + polling)

### Neutral
- **Phone number required:** User needs a phone number for iMessage
- **iCloud sync:** Messages sync across devices (benefit for user, complexity for us)

## Alternatives Considered

### Native Chat UI in Mac App
- Full control over interface
- Rejected: Requires user to open another app; doesn't follow them across devices

### Web Interface
- Cross-platform
- Rejected: Requires server component; doesn't integrate with user's device

### Telegram/Discord Bot
- Established bot APIs
- Rejected: Requires user to adopt new platform; data leaves Apple ecosystem

### Voice-Only (Siri-like)
- Natural interaction
- Rejected for MVP: Complex to implement well; accessibility concerns for deaf users

### SMS via Twilio
- Works on any phone
- Rejected: Requires cloud service; ongoing costs; not as rich as iMessage

## Technical Implementation

**Reading messages:**
```
~/Library/Messages/chat.db (SQLite, read-only)
├── Monitor via FSEvents
├── Query for new messages by ROWID
└── Parse attributedBody for rich content
```

**Sending messages:**
```applescript
tell application "Messages"
    send "Response text" to buddy "+1234567890" of service "iMessage"
end tell
```

**Phone number routing:**
- User configures which phone numbers Ember responds to
- Personal vs Work context based on phone number mapping

## References

- `docs/research/imessage.md` — Technical implementation details
- `docs/research/work-personal-contexts.md` — Phone number routing
- `docs/VISION.md` — User touchpoints architecture
