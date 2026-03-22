# EmberHearth MVP Work-Up

**Date:** February 3, 2026
**Author:** TokenFires
**Status:** Pre-Coding Review

---

## Executive Summary

This document is the decision point before coding begins. It outlines:

1. **Phase 0 (Prototype)** — The absolute minimum to prove the pipeline works
2. **Phase 1 (MVP)** — The first "usable" release
3. **What can be cut** — Scope reduction options if needed
4. **Technical approach** — How to build it
5. **Work breakdown** — Detailed task list

The goal: Get something working as fast as possible, then iterate.

---

## Phase 0: The Prototype ("Proof of Smoke")

> **Goal:** Send a text to your Mac, get a response from Claude, sent back via iMessage.
>
> **Nothing else.** No memory. No personality. No settings UI. Just the pipeline.

### Why Start Here

Before building the full MVP, we need to prove:
1. We can read from chat.db reliably
2. FSEvents fires when messages arrive
3. AppleScript can send messages
4. Claude API integration works
5. The whole loop completes in acceptable time

If any of these fail, we learn early.

### Prototype Scope

```
┌─────────────────────────────────────────────────────────────────┐
│                     PROTOTYPE SCOPE                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   iPhone                                                        │
│      │                                                          │
│      │ iMessage                                                 │
│      ▼                                                          │
│   ┌─────────────────┐                                           │
│   │   chat.db       │  (Full Disk Access required)              │
│   └────────┬────────┘                                           │
│            │ FSEvents                                           │
│            ▼                                                    │
│   ┌─────────────────┐                                           │
│   │  MessageWatcher │  Polls/watches for new messages           │
│   └────────┬────────┘                                           │
│            │                                                    │
│            ▼                                                    │
│   ┌─────────────────┐                                           │
│   │  Phone Filter   │  Only respond to configured number        │
│   └────────┬────────┘                                           │
│            │                                                    │
│            ▼                                                    │
│   ┌─────────────────┐     ┌─────────────────┐                   │
│   │  Claude Client  │────▶│  Anthropic API  │                   │
│   └────────┬────────┘     └─────────────────┘                   │
│            │                                                    │
│            ▼                                                    │
│   ┌─────────────────┐     ┌─────────────────┐                   │
│   │ MessageSender   │────▶│  Messages.app   │                   │
│   │ (AppleScript)   │     │  (AppleScript)  │                   │
│   └─────────────────┘     └─────────────────┘                   │
│            │                                                    │
│            ▼                                                    │
│   iPhone receives response                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Prototype Components

| Component | Description | Complexity |
|-----------|-------------|------------|
| **MessageWatcher** | Monitor chat.db via FSEvents, parse new messages | Medium |
| **PhoneFilter** | Check if message is from configured phone number | Trivial |
| **ClaudeClient** | Send message to Claude, get response | Easy |
| **MessageSender** | Send response via AppleScript | Easy |
| **Config** | Hardcoded phone number + API key (file or env var) | Trivial |

### Prototype Non-Goals

- No GUI (command line or background daemon only)
- No memory/facts
- No personality (use Claude's default)
- No session management
- No Keychain (API key in file/env is fine for prototype)
- No error recovery (crash and restart is fine)
- No signing/notarization (run from Xcode)

### Prototype Deliverable

A Swift command-line tool or minimal app that:
1. Reads your hardcoded phone number and API key
2. Watches chat.db for new messages
3. Filters to only your phone number
4. Sends message content to Claude
5. Sends response back via iMessage
6. Loops forever

**Success criteria:** Text "Hello" from iPhone, receive response from Claude within 10 seconds.

### Prototype Timeline

| Task | Estimated Effort |
|------|------------------|
| chat.db reading + parsing | 2-4 hours |
| FSEvents watcher | 1-2 hours |
| Claude API client | 1-2 hours |
| AppleScript message sending | 1-2 hours |
| Glue code + testing | 2-4 hours |
| **Total** | **1-2 days** |

### Prototype Risks

| Risk | Likelihood | Detection | Mitigation |
|------|------------|-----------|------------|
| chat.db schema differs from research | Medium | First run | Research was recent, but verify |
| FSEvents unreliable | Low | Testing | Fall back to polling |
| AppleScript rate limited | Low | High volume test | Add delays between sends |
| Full Disk Access hard to get | Low | Setup | Document clearly |

---

## Phase 1: MVP ("Spark")

> **Goal:** A usable personal assistant that remembers things.
>
> Everything in the prototype, plus: memory, personality, basic UI, proper security.

### MVP Feature Set

#### Must Have (P0)

| Feature | Description |
|---------|-------------|
| **iMessage Pipeline** | Read → Process → Respond (from prototype) |
| **Memory System** | Store facts, retrieve for context |
| **Ember Personality** | System prompt with character |
| **Session Continuity** | Maintain conversation context |
| **Onboarding UI** | Permission requests, API key entry, phone config |
| **Menu Bar App** | Status indicator, basic settings |
| **Keychain Storage** | API key secured properly |
| **Basic Security** | Group chat blocking, credential filtering |

#### Should Have (P1)

| Feature | Description |
|---------|-------------|
| **Rolling Summary** | Compress old context to save tokens |
| **Fact Extraction** | Automatically extract facts from conversation |
| **Error Recovery** | Handle API failures gracefully |
| **Status Indicator** | Show healthy/degraded/offline state |
| **Launch at Login** | Start with macOS |

#### Could Have (P2)

| Feature | Description |
|---------|-------------|
| **Web Fetcher** | Fetch URLs mentioned in conversation |
| **Token Tracking** | Basic usage display (from token-awareness spec) |
| **Verbosity Adaptation** | Match user's communication style |

#### Won't Have (MVP)

| Feature | Deferred To |
|---------|-------------|
| Work/personal contexts | v1.1 |
| Calendar/Reminders | v1.1 |
| Multiple LLM providers | v1.1 |
| Auto-updates (Sparkle) | v1.1 |
| Data browser UI | v1.1 |
| Semantic search | v1.2 |
| Proactive notifications | v1.2 |
| Local models | v1.2+ |
| Full Tron security | v1.2 |

### MVP Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           MVP ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                      EmberHearth.app                                │ │
│  │                                                                     │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │ │
│  │  │   AppMain   │  │  Settings   │  │  Onboarding │                 │ │
│  │  │  (SwiftUI)  │  │   (View)    │  │   (Flow)    │                 │ │
│  │  └──────┬──────┘  └─────────────┘  └─────────────┘                 │ │
│  │         │                                                          │ │
│  │  ┌──────┴──────────────────────────────────────────────────────┐   │ │
│  │  │                    MessageCoordinator                        │   │ │
│  │  │  Orchestrates the entire message flow                        │   │ │
│  │  └──────┬──────────────────────────────────────────────────────┘   │ │
│  │         │                                                          │ │
│  │  ┌──────┴──────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐ │ │
│  │  │MessageReader│  │  MemoryStore │  │ LLMService  │  │ Security  │ │ │
│  │  │(chat.db +   │  │  (SQLite)    │  │ (Claude)    │  │ (Basic)   │ │ │
│  │  │ FSEvents)   │  │              │  │             │  │           │ │ │
│  │  └──────┬──────┘  └──────┬───────┘  └──────┬──────┘  └─────┬─────┘ │ │
│  │         │                │                 │                │      │ │
│  │  ┌──────┴──────┐         │                 │                │      │ │
│  │  │MessageSender│         │                 │                │      │ │
│  │  │(AppleScript)│         │                 │                │      │ │
│  │  └─────────────┘         │                 │                │      │ │
│  │                          │                 │                │      │ │
│  └──────────────────────────┼─────────────────┼────────────────┼──────┘ │
│                             │                 │                │        │
│                             ▼                 ▼                ▼        │
│                      ┌────────────┐    ┌────────────┐   ┌────────────┐  │
│                      │ memory.db  │    │ Claude API │   │  Keychain  │  │
│                      │ (~/Library)│    │(Anthropic) │   │  (macOS)   │  │
│                      └────────────┘    └────────────┘   └────────────┘  │
│                             │                                           │
│                             ▼                                           │
│                      ┌────────────┐                                     │
│                      │  chat.db   │  (read-only)                        │
│                      │ (Messages) │                                     │
│                      └────────────┘                                     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### MVP Data Model

#### memory.db Schema

```sql
-- Core facts table
CREATE TABLE facts (
    id INTEGER PRIMARY KEY,
    content TEXT NOT NULL,           -- "User prefers morning meetings"
    source TEXT NOT NULL,            -- 'extracted' or 'explicit'
    created_at TEXT NOT NULL,        -- ISO 8601
    last_accessed TEXT,              -- For future decay
    access_count INTEGER DEFAULT 0,
    importance REAL DEFAULT 0.5      -- 0.0-1.0
);

-- Conversation sessions
CREATE TABLE sessions (
    id INTEGER PRIMARY KEY,
    phone_number TEXT NOT NULL,
    started_at TEXT NOT NULL,
    last_message_at TEXT NOT NULL,
    summary TEXT,                    -- Rolling summary
    message_count INTEGER DEFAULT 0
);

-- Session messages (recent only, for context)
CREATE TABLE messages (
    id INTEGER PRIMARY KEY,
    session_id INTEGER NOT NULL,
    role TEXT NOT NULL,              -- 'user' or 'assistant'
    content TEXT NOT NULL,
    timestamp TEXT NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);

-- Configuration
CREATE TABLE config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Indexes
CREATE INDEX idx_facts_content ON facts(content);
CREATE INDEX idx_messages_session ON messages(session_id);
CREATE INDEX idx_sessions_phone ON sessions(phone_number);
```

#### Keychain Items

| Key | Value |
|-----|-------|
| `com.emberhearth.anthropic-api-key` | Claude API key |
| `com.emberhearth.encryption-key` | DB encryption key (future) |

### MVP Message Flow

```
1. FSEvents fires: chat.db modified
           │
           ▼
2. MessageReader: Query for new messages
           │
           ▼
3. PhoneFilter: Is this from configured number?
           │ No → Ignore
           ▼ Yes
4. GroupFilter: Is this a group chat?
           │ Yes → Ignore (MVP)
           ▼ No
5. Security.preProcess: Check for injection attempts
           │ Blocked → Send warning, stop
           ▼ Pass
6. MemoryStore: Retrieve relevant facts
           │
           ▼
7. ContextBuilder: Assemble prompt
           │ - System prompt (Ember personality)
           │ - Relevant facts
           │ - Session summary (if exists)
           │ - Recent messages
           │ - Current message
           ▼
8. LLMService: Send to Claude, stream response
           │
           ▼
9. Security.postProcess: Filter credentials, validate
           │
           ▼
10. MessageSender: Send via AppleScript
           │
           ▼
11. MemoryStore: Extract and store new facts
           │
           ▼
12. SessionManager: Update session, maybe summarize
```

---

## Scope Reduction Options

If time or complexity becomes an issue, here's what can be cut:

### Option A: "Echo Chamber" (Minimal Viable)

Cut memory entirely. Just echo messages through Claude with personality.

| Keep | Cut |
|------|-----|
| iMessage pipeline | Memory system |
| Claude integration | Fact extraction |
| Basic personality | Session management |
| Menu bar app | Rolling summary |
| Keychain | Token tracking |

**Result:** A dumber assistant that forgets everything, but works.

### Option B: "Goldfish" (Short-Term Memory Only)

Keep recent messages, no long-term facts.

| Keep | Cut |
|------|-----|
| Everything in Option A | Fact storage |
| Recent message context | Fact extraction |
| | Long-term retrieval |

**Result:** Remembers current conversation, forgets between sessions.

### Option C: "Full MVP Minus Polish"

Build everything but skip UI polish.

| Keep | Cut |
|------|-----|
| All core features | Pretty settings UI |
| Basic onboarding | Token tracking |
| Command-line friendly | Error state UI |
| Functional settings | Status animations |

**Result:** Ugly but fully functional.

**Recommendation:** Start with Option A mindset (get pipeline working), then add memory (Option B → Full MVP).

---

## Technical Approach

### Project Structure

```
EmberHearth/
├── EmberHearth.xcodeproj
├── Sources/
│   ├── App/
│   │   ├── EmberHearthApp.swift      # App entry point
│   │   ├── AppDelegate.swift         # Menu bar, lifecycle
│   │   └── ContentView.swift         # Main view
│   ├── Core/
│   │   ├── MessageCoordinator.swift  # Orchestration
│   │   ├── MessageReader.swift       # chat.db access
│   │   ├── MessageSender.swift       # AppleScript
│   │   └── SessionManager.swift      # Context management
│   ├── LLM/
│   │   ├── LLMService.swift          # Protocol
│   │   ├── ClaudeProvider.swift      # Anthropic API
│   │   └── ContextBuilder.swift      # Prompt assembly
│   ├── Memory/
│   │   ├── MemoryStore.swift         # SQLite wrapper
│   │   ├── FactExtractor.swift       # LLM-based extraction
│   │   └── FactRetriever.swift       # Relevance matching
│   ├── Security/
│   │   ├── SecurityFilter.swift      # Input/output validation
│   │   ├── KeychainManager.swift     # Secrets
│   │   └── GroupChatDetector.swift   # Block groups
│   ├── Personality/
│   │   ├── EmberPrompt.swift         # System prompt
│   │   └── ResponseAdapter.swift     # Style matching
│   └── Views/
│       ├── OnboardingView.swift
│       ├── SettingsView.swift
│       └── StatusView.swift
├── Resources/
│   ├── Assets.xcassets
│   └── Localizable.strings
└── Tests/
    ├── MessageReaderTests.swift
    ├── ClaudeProviderTests.swift
    └── MemoryStoreTests.swift
```

### Key Dependencies

| Dependency | Purpose | Source |
|------------|---------|--------|
| **SQLite.swift** | Database wrapper | SPM |
| **KeychainAccess** | Keychain wrapper | SPM |
| None for Claude | Use URLSession | Built-in |
| None for AppleScript | Use NSAppleScript | Built-in |

### Development Environment

| Tool | Version |
|------|---------|
| Xcode | 15.0+ |
| macOS | 14.0+ (for development) |
| Target | macOS 13.0+ (Ventura) |
| Swift | 5.9+ |

### Signing & Notarization

For prototype: Run from Xcode, no signing needed.

For MVP release:
1. Apple Developer account ($99/year)
2. Developer ID certificate
3. Hardened runtime enabled
4. Notarization via `notarytool`

Entitlements needed:
```xml
<key>com.apple.security.app-sandbox</key>
<false/>  <!-- Can't sandbox due to Full Disk Access -->
<key>com.apple.security.automation.apple-events</key>
<true/>  <!-- AppleScript -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

---

## Work Breakdown

### Phase 0: Prototype (1-2 days)

| # | Task | Hours | Dependencies |
|---|------|-------|--------------|
| 0.1 | Create Xcode project (command line tool) | 0.5 | - |
| 0.2 | Implement chat.db reader | 3 | 0.1 |
| 0.3 | Implement FSEvents watcher | 2 | 0.1 |
| 0.4 | Implement Claude API client | 2 | 0.1 |
| 0.5 | Implement AppleScript sender | 1 | 0.1 |
| 0.6 | Implement phone number filter | 0.5 | 0.2 |
| 0.7 | Glue: MessageCoordinator | 2 | 0.2, 0.3, 0.4, 0.5, 0.6 |
| 0.8 | Test end-to-end | 2 | 0.7 |
| 0.9 | Document learnings | 1 | 0.8 |

**Prototype subtotal: ~14 hours (1-2 days)**

### Phase 1a: MVP Core (3-5 days)

| # | Task | Hours | Dependencies |
|---|------|-------|--------------|
| 1.1 | Convert to app target | 1 | Prototype complete |
| 1.2 | Basic SwiftUI shell | 2 | 1.1 |
| 1.3 | Menu bar integration | 2 | 1.2 |
| 1.4 | SQLite setup (memory.db) | 2 | 1.1 |
| 1.5 | MemoryStore implementation | 4 | 1.4 |
| 1.6 | Fact extraction prompt | 2 | 1.5 |
| 1.7 | Fact retrieval for context | 3 | 1.5 |
| 1.8 | Session management | 3 | 1.5 |
| 1.9 | Rolling summary | 2 | 1.8 |
| 1.10 | Ember personality prompt | 2 | - |
| 1.11 | Context builder (assemble prompt) | 3 | 1.7, 1.9, 1.10 |
| 1.12 | Integrate memory into flow | 2 | 1.11 |

**Core subtotal: ~28 hours (3-5 days)**

### Phase 1b: MVP Security (1-2 days)

| # | Task | Hours | Dependencies |
|---|------|-------|--------------|
| 1.13 | KeychainManager | 2 | - |
| 1.14 | Migrate API key to Keychain | 1 | 1.13 |
| 1.15 | Group chat detector | 2 | - |
| 1.16 | Basic injection defense | 3 | - |
| 1.17 | Credential filtering (output) | 2 | - |
| 1.18 | Security integration | 1 | 1.15, 1.16, 1.17 |

**Security subtotal: ~11 hours (1-2 days)**

### Phase 1c: MVP UI (2-3 days)

| # | Task | Hours | Dependencies |
|---|------|-------|--------------|
| 1.19 | Onboarding flow design | 2 | - |
| 1.20 | Permission request screens | 4 | 1.19 |
| 1.21 | API key entry screen | 2 | 1.19 |
| 1.22 | Phone number config | 2 | 1.19 |
| 1.23 | Settings view | 3 | 1.13 |
| 1.24 | Status indicator | 2 | 1.3 |
| 1.25 | Launch at login | 1 | 1.3 |
| 1.26 | Error state handling | 3 | - |

**UI subtotal: ~19 hours (2-3 days)**

### Phase 1d: MVP Polish (1-2 days)

| # | Task | Hours | Dependencies |
|---|------|-------|--------------|
| 1.27 | Error recovery (API failures) | 3 | - |
| 1.28 | Offline handling | 2 | 1.27 |
| 1.29 | End-to-end testing | 4 | All above |
| 1.30 | Code signing setup | 2 | - |
| 1.31 | Notarization | 2 | 1.30 |
| 1.32 | Fresh Mac install test | 2 | 1.31 |
| 1.33 | Documentation | 3 | All above |

**Polish subtotal: ~18 hours (1-2 days)**

### Total Estimate

| Phase | Hours | Days |
|-------|-------|------|
| Prototype | 14 | 1-2 |
| MVP Core | 28 | 3-5 |
| MVP Security | 11 | 1-2 |
| MVP UI | 19 | 2-3 |
| MVP Polish | 18 | 1-2 |
| **Total** | **90** | **8-14 days** |

**Buffer for unknowns: +50% = 12-21 days**

---

## Testing Strategy

### Prototype Testing

- Manual: Send texts, verify responses
- Happy path only
- Document any issues for MVP

### MVP Testing

| Test Type | Scope | Automation |
|-----------|-------|------------|
| Unit | MemoryStore, ContextBuilder, Security | Yes |
| Integration | chat.db reading, Claude API | Mocked |
| End-to-end | Full message flow | Manual |
| Install | Fresh Mac | Manual |

### Beta Testing

- 3 users minimum
- 1 week usage
- Daily check-in on issues
- Focus: reliability, not features

---

## Stream Integration

### What's Streamable

| Phase | Stream Value | Notes |
|-------|--------------|-------|
| Prototype | High | Exciting—will it work? |
| MVP Core | Medium | More tedious, but educational |
| MVP Security | Medium | Good explainer content |
| MVP UI | High | Visual progress |
| Testing | High | Live debugging is engaging |

### Stream Milestones

Natural "episodes" for streaming:

1. **Episode: "First Light"** — Prototype end-to-end test
2. **Episode: "Memory Palace"** — First fact remembered
3. **Episode: "She's Alive"** — Ember personality working
4. **Episode: "Fort Knox"** — Security layer demo
5. **Episode: "Onboarding"** — First-time user experience
6. **Episode: "Ship It"** — Notarization and first external test

---

## Decision Points

Before proceeding, confirm:

1. **Prototype first?** (Recommended: Yes)
2. **Scope level?** (Full MVP / Option A / Option B / Option C)
3. **Beta testers identified?** (Need 3 minimum)
4. **Streaming from day 1?** (Adds pressure but accountability)
5. **Phone number for testing?** (Your personal? A test SIM?)

---

## Risks Summary

| Risk | Impact | Mitigation |
|------|--------|------------|
| chat.db access blocked | Critical | Test on fresh macOS first |
| AppleScript unreliable | High | Build retry logic, have backup |
| Claude rate limits | Medium | Token tracking from start |
| Notarization rejected | High | Test early, follow guidelines |
| Scope creep | High | This document exists |
| Streaming pressure | Medium | Prototype off-stream if needed |

---

## Next Steps

1. **You:** Review this document, decide on scope
2. **You:** Set up development Mac (if not ready)
3. **You:** Get Twitch/OBS ready (see streaming guide)
4. **Me:** Start coding based on your decision
5. **Stream:** First coding session (prototype?)

---

## Appendix: Quick Reference

### Key File Locations

| What | Where |
|------|-------|
| chat.db | `~/Library/Messages/chat.db` |
| memory.db | `~/Library/Application Support/EmberHearth/memory.db` |
| Logs | `~/Library/Logs/EmberHearth/` |
| Config | `~/Library/Application Support/EmberHearth/config.json` |

### Key API Endpoints

| Service | Endpoint |
|---------|----------|
| Claude | `https://api.anthropic.com/v1/messages` |

### Useful Commands

```bash
# Check chat.db access
sqlite3 ~/Library/Messages/chat.db "SELECT COUNT(*) FROM message;"

# Test AppleScript message sending
osascript -e 'tell application "Messages" to send "Test" to buddy "+1234567890"'

# Open Full Disk Access settings
open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
```

---

*This document will evolve. Current version: Pre-coding review.*
