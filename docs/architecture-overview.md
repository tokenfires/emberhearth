# EmberHearth Architecture Overview

**Version:** 1.3
**Date:** February 3, 2026
**Status:** Pre-Prototype Review (Autonomous Operation Added)
**Diagram:** `diagrams/emberhearth-architecture.drawio`

### Diagram Pages

The draw.io file contains 10 pages:

| Page | Name | Description |
|------|------|-------------|
| 1 | System Overview | Main architecture with all components |
| 2 | Data Flow - Message Processing | Step-by-step message handling |
| 3 | MVP Scope | Visual breakdown of MVP vs later phases |
| 4 | Plugin System | Plugin Manager, Runtime, API, permissions |
| 5 | LLM Orchestration | Four modes, adaptive routing, local agents |
| 6 | Security Layers | Defense in depth (6 layers), Tron detail |
| 7 | Integration Services | Apple framework XPC services |
| 8 | Ember Personality System | Three-layer model, bounded needs, user understanding, attachment-informed algorithm, configuration |
| 9 | Error Handling and Resilience | Design principles, component failures, crash recovery, backup strategy, health monitoring |
| 10 | Autonomous Operation | Self-monitoring, self-healing, circuit breakers, offline mode, seamless upgrades, optional telemetry |

---

## Purpose

This document synthesizes all Phase 1 research into a comprehensive architectural view. It serves as:
1. A pre-prototype review to catch any gaps
2. A reference for implementation decisions
3. A visual map of MVP vs full system scope

**Color Coding (in diagram):**
- 🟢 **Green** — MVP (Phase 2-3)
- 🔵 **Blue** — Full system (later phases)
- ⚪ **Gray** — External dependencies
- 🟠 **Orange** — Future/earmarked features

---

## System Overview

EmberHearth is a personal AI assistant for macOS that uses iMessage as its primary interface. The system consists of:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER TOUCHPOINTS                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   📱 iMessage (Primary)              🖥️ MacOS App (Admin)                   │
│   ├── Personal phone number          ├── Onboarding                         │
│   ├── Work phone number (optional)   ├── Settings                           │
│   └── Group chats (social mode)      ├── Data browser                       │
│                                      └── Archive management                 │
│                                                                             │
│   🌐 Web UI (Future)                 🎙️ Voice (Future)                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              EMBERHEARTH CORE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│   │   Tron      │  │   Ember     │  │  Memory     │  │    LLM      │       │
│   │  Security   │  │ Personality │  │   System    │  │  Provider   │       │
│   └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           EXTERNAL DEPENDENCIES                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   💬 iMessage        🤖 LLM APIs       🍎 Apple Frameworks    🔐 Keychain   │
│   (chat.db)          (Claude, etc.)    (EventKit, etc.)       (Secrets)     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Detail

### 1. EmberHearth.app (Main Process) 🟢

The native macOS application that coordinates all other components.

| Aspect | Description |
|--------|-------------|
| **Technology** | Swift + SwiftUI |
| **Entitlements** | App Sandbox, Network Client, Calendars, Contacts |
| **Responsibilities** | UI rendering, onboarding, settings, XPC coordination |
| **MVP Scope** | Basic shell, onboarding, LLM config |

**UI Screens:**
- Onboarding flow (permission requests, LLM setup)
- Settings (API keys, preferences)
- Data browser (facts, conversation archive) — *identified in 1.9 research*
- Soft delete recovery — *identified in 1.9 research*

**Key Files (planned):**
```
src/
├── EmberHearthApp.swift          # App entry point
├── Views/
│   ├── OnboardingView.swift      # First-time setup
│   ├── SettingsView.swift        # Configuration
│   ├── DataBrowserView.swift     # Facts/archive browser
│   └── ChatPreviewView.swift     # Debug/testing
├── Services/
│   ├── XPCCoordinator.swift      # Manages XPC connections
│   └── PermissionManager.swift   # Permission checking
└── Models/
    └── AppState.swift            # Global state
```

---

### 2. MessageService.xpc 🟢

Handles all iMessage integration—reading incoming messages and sending responses.

| Aspect | Description |
|--------|-------------|
| **Technology** | Swift, SQLite, NSAppleScript |
| **Entitlements** | Automation (Messages.app), inherits Full Disk Access |
| **Responsibilities** | Read chat.db, send via Messages.app, context detection |
| **MVP Scope** | Basic read/write, personal context only |

**Subcomponents:**

```
MessageService.xpc
├── MessageReader
│   ├── Opens chat.db (read-only)
│   ├── Monitors via FSEvents for new messages
│   ├── Handles attributedBody decoding (macOS 13+)
│   └── Returns structured Message objects
│
├── MessageSender
│   ├── Executes AppleScript via NSAppleScript
│   ├── Normalizes phone numbers to E.164
│   └── Handles send failures gracefully
│
├── MessageRouter
│   ├── detectContext(phoneNumber) → .personal | .work
│   ├── detectGroupChat(chatID) → Bool
│   └── Routes to appropriate handler
│
└── GroupChatDetector 🔵
    ├── Detects participant count > 2
    ├── Enforces social-only mode
    └── Tracks group dynamics for archive
```

**Data Flow (Incoming Message):**
```
chat.db change (FSEvents)
    │
    ▼
MessageReader.getNewMessages()
    │
    ▼
MessageRouter.detectContext(message.handle)
    │
    ├── Personal → PersonalHandler
    └── Work → WorkHandler 🔵
    │
    ▼
Return to main app for processing
```

---

### 3. MemoryService.xpc 🟢🔵

Manages all persistent state: facts, conversation archive, session state.

| Aspect | Description |
|--------|-------------|
| **Technology** | Swift, SQLite, embeddings (future) |
| **Entitlements** | App Sandbox |
| **Responsibilities** | Memory DB, conversation archive, session state |
| **MVP Scope** | Basic fact storage, session state |

**Subcomponents:**

```
MemoryService.xpc
├── MemoryDatabase
│   ├── personal/memory.db — Personal context facts
│   ├── work/memory.db — Work context facts 🔵
│   ├── Fact extraction and storage
│   ├── Emotional intensity encoding
│   ├── Decay and reinforcement
│   └── Semantic search (embeddings) 🔵
│
├── ConversationArchive (Mini-RAG) 🔵
│   ├── Stores conversation chunks (not just facts)
│   ├── Embeddings for semantic retrieval
│   ├── Fallback if chat.db cleared
│   ├── 90-day retention (configurable)
│   └── Preserves conversational texture
│
├── SessionState
│   ├── Current conversation context
│   ├── Recent messages cache
│   ├── Rolling summary
│   ├── Active task state
│   └── User behavior tracking (for adaptive summarization)
│
└── Summarizer
    ├── Triggers at ~20 messages (adaptive)
    ├── Rolling summary generation
    └── Dynamic length based on user patterns
```

**Storage Layout:**
```
~/Library/Application Support/EmberHearth/
├── personal/
│   ├── memory.db              # Facts database
│   ├── archive.db             # Conversation archive 🔵
│   └── session.json           # Current session state
├── work/ 🔵
│   ├── memory.db
│   ├── archive.db
│   ├── session.json
│   └── audit.log              # Work context audit trail
└── shared/
    └── preferences.json       # Non-sensitive settings
```

---

### 4. LLMService.xpc 🟢🔵

Handles all LLM provider communication.

| Aspect | Description |
|--------|-------------|
| **Technology** | Swift, URLSession, MLX (future) |
| **Entitlements** | Network Client, App Sandbox |
| **Responsibilities** | API calls, local inference, context routing |
| **MVP Scope** | Claude API only |

**Subcomponents:**

```
LLMService.xpc
├── CloudProvider 🟢
│   ├── ClaudeProvider (Anthropic API)
│   ├── OpenAIProvider 🔵
│   └── Handles streaming responses
│
├── LocalProvider 🔵
│   ├── MLX runtime
│   ├── Model management
│   └── Quantization support
│
├── ContextBuilder
│   ├── Assembles context from components
│   ├── Budget allocation (10% system, 25% recent, etc.)
│   ├── Retrieves from MemoryService
│   └── Builds final prompt
│
└── PolicyEnforcer 🔵
    ├── Applies context-specific rules
    ├── Work context: may require local-only
    └── Coordinates with Tron
```

**Context Budget (from 1.9 research):**
```
┌─────────────────────────────────────┐
│  CONTEXT WINDOW ALLOCATION          │
├─────────────────────────────────────┤
│  System prompt           ~10%       │
│  Recent messages         ~25%       │
│  Conversation summary    ~10%       │
│  Retrieved memories      ~15%       │
│  Active task state       ~5%        │
│  Reserve for response    ~35%       │
└─────────────────────────────────────┘
```

---

### 5. Tron (Security Layer) 🔵🟠

The security enforcement layer that sits between user input and Ember.

| Aspect | Description |
|--------|-------------|
| **Technology** | TBD (may be separate process or integrated) |
| **Responsibilities** | Prompt injection defense, tool authorization, anomaly detection |
| **MVP Scope** | Hardcoded rules in main app |

**From VISION.md:**
```
Tron Responsibilities:
├── Inbound filtering (signature + ML for prompt injection)
├── Outbound monitoring (credential detection, behavior anomalies)
├── Retrospective scanning (continuous threat hunting)
├── Community signature database (auto-updated)
├── Tool call authorization
├── Group chat restriction enforcement
└── Audit logging
```

**Ember-Tron Coordination (from 1.9 research):**
```
┌─────────────────────────────────────────────────────────────────┐
│  EMBER-TRON RELATIONSHIP                                         │
│                                                                 │
│  Tron → Ember:                                                  │
│  ├── Flags security events for user communication               │
│  ├── Authorizes/blocks tool calls                               │
│  └── Enforces group chat restrictions                           │
│                                                                 │
│  Ember → Tron:                                                  │
│  ├── Requests tool call authorization                           │
│  └── Reports context for policy evaluation                      │
│                                                                 │
│  Key: Tron NEVER contacts user directly. Ember is the voice.    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**MVP Approach:** Tron logic is hardcoded in main app. No separate process. Rules:
- Group chat detected → social-only mode
- Tool calls → basic validation only
- No ML-based detection yet

---

### 6. Ember (Personality Layer)

Not a separate service—Ember is the personality that emerges from the system prompt and conversation patterns.

| Aspect | Description |
|--------|-------------|
| **Defined In** | `conversation-design.md` |
| **Responsibilities** | Personality, voice, tone, emotional awareness |
| **Implementation** | System prompt + behavior rules |

**Key Personality Traits (from research):**
- Warm, curious, capable, present, honest, evolving
- Inspired by Samantha from *Her*
- Adapts verbosity to user signals
- Uses emotional encoding for memory salience
- Has public (group) vs private (1:1) awareness

**System Prompt Components:**
```
1. Core identity (who Ember is)
2. Voice characteristics (direct but not blunt, etc.)
3. Verbosity guidelines
4. Memory retrieval instructions (with emotional metadata)
5. Current context (personal vs work)
6. Group chat restrictions (if applicable)
7. Active task state (if any)
```

---

## Data Flows

### Flow 1: Incoming Message Processing

```
┌─────────┐    ┌───────────────┐    ┌──────┐    ┌───────┐    ┌─────────┐
│ iMessage│───▶│MessageService │───▶│ Tron │───▶│ Ember │───▶│LLMService│
│ chat.db │    │    .xpc       │    │      │    │       │    │   .xpc   │
└─────────┘    └───────────────┘    └──────┘    └───────┘    └─────────┘
                      │                              │              │
                      │                              ▼              │
                      │                        ┌─────────┐         │
                      │                        │ Memory  │◀────────┘
                      │                        │ Service │   (context
                      │                        │  .xpc   │   retrieval)
                      │                        └─────────┘
                      │                              │
                      │                              ▼
                      │                     ┌──────────────┐
                      │◀────────────────────│   Response   │
                      │    (send reply)     └──────────────┘
                      │
                      ▼
                ┌─────────┐
                │ iMessage│
                │  Send   │
                └─────────┘
```

**Step-by-step:**
1. FSEvents detects change in chat.db
2. MessageService reads new message(s)
3. MessageRouter determines context (personal/work) and type (1:1/group)
4. **If group chat:** Tron enforces social-only mode
5. Main app requests context from MemoryService
6. ContextBuilder assembles prompt with budget allocation
7. LLMService sends to provider (Claude API)
8. Response streams back
9. MessageService sends via AppleScript
10. **Async:** MemoryService extracts facts, updates archive

### Flow 2: Memory Extraction (Async)

```
Conversation
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│  Memory Extraction Pipeline                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Conversation → LLM for fact extraction                      │
│     "Extract facts, preferences, relationships"                 │
│                                                                 │
│  2. Each fact gets:                                             │
│     ├── Confidence score                                        │
│     ├── Emotional intensity (0.0-1.0)                           │
│     ├── Category (preference, relationship, etc.)               │
│     └── Source reference                                        │
│                                                                 │
│  3. Store in memory.db (context-specific)                       │
│                                                                 │
│  4. Archive conversation chunk (separate from facts)            │
│     ├── Timestamp range                                         │
│     ├── Summary                                                 │
│     ├── Emotional tone                                          │
│     └── Embeddings (for retrieval) 🔵                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Flow 3: Tool Call (Future)

```
Ember needs to check calendar
     │
     ▼
┌──────────────────────────────────────────────────────────────────┐
│  Tool Call Flow                                                   │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Ember generates tool call request                            │
│     { tool: "calendar.listEvents", params: { range: "today" } }  │
│                                                                  │
│  2. Tron evaluates:                                              │
│     ├── Is this tool allowed in current context?                 │
│     ├── Is this a group chat? (block if so)                      │
│     ├── Does request look suspicious?                            │
│     └── Authorize or deny                                        │
│                                                                  │
│  3. If authorized:                                               │
│     └── Execute via appropriate Apple framework (EventKit)       │
│                                                                  │
│  4. Return result to Ember for incorporation into response       │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## MVP vs Full System

### MVP Scope (Phase 2-3) 🟢

| Component | MVP Implementation |
|-----------|-------------------|
| **EmberHearth.app** | Basic SwiftUI shell, onboarding, settings |
| **MessageService** | Read/write iMessage, personal context only |
| **MemoryService** | Basic fact storage, session state, no embeddings |
| **LLMService** | Claude API only, basic context building |
| **Tron** | Hardcoded rules in main app |
| **Contexts** | Personal only |
| **Group chat** | Detect and block (or very basic social) |
| **Apple integrations** | None initially |

### Full System (Phase 4+) 🔵

| Component | Full Implementation |
|-----------|---------------------|
| **EmberHearth.app** | Complete UI, data browser, archive management |
| **MessageService** | Work context, full group chat social mode |
| **MemoryService** | Embeddings, semantic search, conversation archive |
| **LLMService** | Multiple providers, local models (MLX) |
| **Tron** | Separate security layer, ML detection, audit |
| **Contexts** | Personal + Work with full isolation |
| **Group chat** | Full social mode with tracking |
| **Apple integrations** | Calendar, Contacts, Reminders, etc. |

### Future/Earmarked 🟠

| Feature | Phase |
|---------|-------|
| Multi-user roles | Phase 5+ |
| Family group exception | Future |
| Work re-validation (SMS) | Future (needs server) |
| Web UI | Future |
| Voice interface | Future |
| Workbench (Docker sandbox) | Future |
| 911/emergency safeguards | Future |

---

## External Dependencies

### iMessage (chat.db)

| Aspect | Detail |
|--------|--------|
| **Location** | `~/Library/Messages/chat.db` |
| **Access** | Requires Full Disk Access |
| **Mode** | Read-only (SQLite) |
| **Detection** | FSEvents or polling |

### LLM APIs

| Provider | Status | Notes |
|----------|--------|-------|
| Claude (Anthropic) | MVP | Primary provider |
| OpenAI | Full | Alternative |
| Local (MLX) | Full | Privacy-focused option |

### Apple Frameworks

| Framework | Purpose | MVP? |
|-----------|---------|------|
| EventKit | Calendar, Reminders | No |
| Contacts | Contact lookup | No |
| MapKit | Location, directions | No |
| HomeKit | Smart home | No |
| Shortcuts | Automation | No |

### Security Infrastructure

| Component | Technology |
|-----------|------------|
| API Keys | Keychain (per-context access groups) |
| Encryption Keys | Secure Enclave |
| Preferences | UserDefaults (non-sensitive) |

---

## Identified Gaps and Questions

During this architecture review, the following items were noted:

### Confirmed Coverage

✅ iMessage read/write mechanics (imessage.md)
✅ Security primitives (security.md)
✅ Memory system design (memory-learning.md)
✅ Conversation design (conversation-design.md)
✅ Onboarding flow (onboarding-ux.md)
✅ Session and context management (session-management.md)
✅ Work/personal separation (work-personal-contexts.md)
✅ Local model feasibility (local-models.md)

### Questions for Prototype Phase

1. **XPC Service Boundaries:** Should Tron be a separate XPC service or integrated into main app for MVP?
   - *Current decision: Integrated for MVP, separate later*

2. **Embedding Generation:** Where does embedding happen—locally or via API?
   - *Research shows local is possible (MLX) but adds complexity*

3. **Message Polling vs FSEvents:** Which is more reliable for chat.db monitoring?
   - *Research suggests FSEvents but with polling fallback*

4. **AppleScript Reliability:** How robust is Messages.app automation?
   - *Known to work but may need error recovery*

### Not Yet Researched (May Need Attention)

✅ **Crash Recovery:** ~~What happens if EmberHearth crashes mid-response?~~
- **RESOLVED** — See `docs/specs/error-handling.md`: launchd auto-restart, post-crash integrity checks, safe state recovery

✅ **Rate Limiting:** ~~How do we handle LLM API rate limits?~~
- **RESOLVED** — See `docs/specs/error-handling.md`: exponential backoff, message queuing, offline mode

✅ **Observability/Logging:** ~~How do we monitor health without enterprise tooling?~~
- **RESOLVED** — See `docs/specs/autonomous-operation.md`: self-monitoring health state machine, circuit breakers, self-diagnostic via chat

✅ **Configuration Migration:** ~~How do we handle config/schema changes across versions?~~
- **RESOLVED** — See `docs/specs/autonomous-operation.md`: schema versioning, migration registry, forward compatibility, resumable migrations

✅ **Update/Rollback Strategy:** ~~What if an update breaks something?~~
- **RESOLVED** — See `docs/specs/autonomous-operation.md`: pre-update backups, migration failure recovery, forward-compatible resilience (no rollback needed)

⚠️ **Attachment Handling:** Images, files in iMessage
- Research mentions it's complex; may defer to later phase

⚠️ **Message Reactions:** Tapbacks in iMessage
- May require Private API; defer to later phase

---

## Cross-Reference to Research Documents

| Document | Primary Topics |
|----------|----------------|
| `VISION.md` | Overall philosophy, Tron concept, architecture vision |
| `imessage.md` | chat.db schema, reading/sending, work/personal routing |
| `security.md` | XPC services, Keychain, Secure Enclave, sandboxing |
| `memory-learning.md` | Fact extraction, emotional encoding, decay, storage |
| `specs/error-handling.md` | Component failures, crash recovery, backup strategy, logging |
| `specs/autonomous-operation.md` | Self-healing, circuit breakers, seamless upgrades, optional telemetry |
| `conversation-design.md` | Ember's personality, voice, tone, error handling |
| `personality-design.md` | Three-layer model, bounded needs, love languages, attachment patterns |
| `onboarding-ux.md` | Permission flow, LLM setup, first-time experience |
| `session-management.md` | Context window, sessions, groups, identity |
| `local-models.md` | MLX, model selection, performance |
| `work-personal-contexts.md` | Dual context architecture |
| `macos-apis.md` | Apple framework capabilities |
| `safari-integration.md` | Bookmarks, history, AppleScript, Safari extensions |
| `legal-ethical-considerations.md` | AI companion failures, legal frameworks, ethical design, safeguards |
| `active-data-intake.md` | Continuous monitoring, FSEvents, event queue, Anticipation Engine feed |

---

## Next Steps

1. ✅ Review this document for gaps
2. ✅ Create draw.io diagram with color coding (7 pages)
3. ⏳ Break work into trackable units (Pivotal Tracker discussion)
4. ⏳ Proceed to Phase 2 prototyping

---

*Architecture overview compiled February 3, 2026.*
