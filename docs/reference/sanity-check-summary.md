# EmberHearth: Internal Reference Summary

*Created for sanity check analysis. Not intended for external use.*

## What Is EmberHearth?

A macOS-native AI personal assistant that:
- Runs on user's own hardware (Mac Mini primary target)
- Uses iMessage as primary conversational interface
- Integrates with Apple ecosystem (Calendar, Reminders, Mail, Safari, etc.)
- Learns about the user over time (memories, preferences, patterns)
- Acts proactively based on anticipation (not just reactive queries)
- Prioritizes security and privacy over raw capability

## Target User

Non-technical users: "your grandmother, your spouse, your parent"
- No API keys to manage manually
- No config files to edit
- No terminal commands
- No Docker/containers to understand
- Just: Install → Permissions → API key (guided) → Text via iMessage

## Core Value Proposition

1. **Security by Design**: No shell execution, credentials never exposed to LLM, sandboxed operations
2. **Apple-Native**: Uses macOS security primitives, integrates with Apple apps, follows HIG
3. **True Memory**: Learns automatically, recalls temporally, understands salience
4. **Anticipatory**: Goes beyond reactive; knows what matters before you ask
5. **Relational**: Ember has bounded needs, feels genuine, adapts to user

## Key Architectural Components

### 1. Tron (Security Layer)
- Inbound filtering (prompt injection detection)
- Outbound monitoring (credential detection, behavior anomalies)
- Policy enforcement (work/personal, group chat restrictions)
- Sits between all inputs and Ember

### 2. XPC Services (Process Isolation)
- MessageService (iMessage)
- MemoryService (facts, archive)
- LLMService (API communication)
- CalendarService, MailService, etc.
- Each has minimal permissions for its function

### 3. Active Data Intake (Continuous Monitoring)
- FSEvents for file changes (chat.db, bookmarks, notes)
- EventKit notifications for Calendar/Reminders
- Event queue with normalized format
- Feeds anticipation engine

### 4. Memory System
- SQLite database with facts and conversation archive
- Automatic fact extraction from conversations
- Temporal linking (when/where learned)
- Decay model with emotional salience
- Semantic search via embeddings (future)

### 5. Anticipation Engine
- Pattern recognition across time
- Salience detection (what matters)
- Timing judgment (when to surface)
- Intrusion calibration (when NOT to interrupt)
- Action preparation (not just notification)

### 6. Ember (Personality)
- Three-layer model: Identity → Communication Style → Archetype
- Bounded needs (intrinsic to identity, not manipulative)
- Love languages framework (Acts of Service primary)
- Attachment-informed responses (internal only)
- Progressive disclosure in prompts

### 7. Sandboxed Web Tool (MCP)
- Fresh browser context (no user cookies/sessions)
- URL fetching and content extraction
- Ember's research pathway (isolated from user's Safari)

## What's NOT Included

- Shell/command execution (never, by design)
- Direct Safari control (experimental only)
- Multi-user support (single owner)
- Cloud sync of personal data
- Plugin/extension architecture (attack surface)
- Voice interface (future)

## Minimum Hardware

- Mac Mini (any M-series)
- iPhone (for iMessage, though not strictly required)
- Internet connection (for Claude API)

## LLM Strategy

- MVP: Claude API (user provides key)
- v1.1: OpenAI as alternative
- v2.0: Local models via MLX
- Hybrid approach possible: local for routing/compression, cloud for capability

## Security Philosophy

**Moltbot Lesson**: Other systems failed by being "too open"
- Shell execution = catastrophic
- Credentials in files = exposed
- No sandboxing = no containment

**EmberHearth Approach**:
- Structured operations only
- Credentials stay in Keychain
- Every component sandboxed
- Read access default; control requires explicit opt-in

## What Makes This Hard

1. **iMessage Integration**: Requires Full Disk Access, AppleScript automation, no official API
2. **Security vs Capability**: Every capability is an attack surface
3. **Anticipation Intelligence**: Knowing when to act vs when to stay quiet
4. **Memory Quality**: Extracting meaningful facts, not noise
5. **User Trust**: Building relationship without manipulation
6. **Cost**: API tokens add up for heavy users
7. **Terms of Service**: Anthropic ToS constrains automated use

## MVP Scope

1. Read/send iMessages
2. Basic memory (facts)
3. Claude API
4. Simple Ember personality
5. Basic Tron (signatures)
6. Mac app for settings
7. Group chat blocking

## Documentation Volume

- VISION.md: ~2200 lines
- Research docs: 15 files, ~500KB total
- ADRs: 11 decisions
- Architecture: Overview, diagrams, specs
- Releases: MVP scope, feature matrix

## Key Research Areas Covered

- iMessage integration (chat.db, AppleScript)
- macOS security (sandbox, XPC, Keychain, Hardened Runtime)
- Apple APIs (EventKit, Contacts, Mail, Notes, etc.)
- Local models (MLX, performance, models)
- Memory/learning (extraction, encoding, retrieval)
- Personality (voice, tone, relationship dynamics)
- Session management (context, groups, identity)
- Safari integration (read vs control, security)
- Legal/ethical (AI companion failures, regulations)
- Active data intake (monitoring, proactivity)

## Risks and Concerns

1. **Scope Creep**: The vision is ambitious; MVP must be disciplined
2. **iMessage Fragility**: Apple could change chat.db format, break AppleScript
3. **Regulatory**: AI companion laws emerging (CA SB 243, NY safeguards)
4. **Competition**: Apple could build this natively; others are trying
5. **Single Person**: Building this alone is a lot

## What Success Looks Like

User texts Ember from their iPhone while at the grocery store:
"What should I pick up for dinner?"

Ember responds based on:
- User's dietary preferences (learned)
- Calendar (dinner plans? guests?)
- Weather (comfort food if cold?)
- Recent conversations (did they mention wanting something?)
- Pantry context (if integrated)

...and the response feels like a helpful friend who knows them, not a search engine.

---

*This summary reflects documentation as of February 2026.*
