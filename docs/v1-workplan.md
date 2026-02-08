# EmberHearth V1 Workplan

**Purpose:** Session-sized work items for Claude Code. Each item fits comfortably in a single conversation without hitting context limits.

**How to use:** Start a session, say "Work on the next unchecked item in v1-workplan.md", build it, test it, commit it. Start a new session for the next item.

**Rule of thumb:** If a session touches more than ~3 implementation files + tests, commit and start fresh.

**Caution:** If a workplan item takes more than two sessions, that's a signal to revisit the spec rather than push through.

---

## 1.0 "Spark" — MVP

### M1: Foundation

- [ ] **M1.1 — Xcode project scaffolding**
  Create the Xcode project with proper bundle ID, signing configuration, minimum deployment target (macOS 13), and basic directory structure matching `architecture-overview.md`. Set up the Swift package structure. No UI yet — just a buildable, signable app that launches.
  - Files: Xcode project, Package.swift (if SPM), Info.plist, entitlements
  - Verify: App builds, signs, and launches on macOS 13+

- [ ] **M1.2 — Menu bar app + Launch at Login**
  Convert to a menu bar app (NSStatusItem). Add "Launch at Login" via SMAppService (macOS 13+). Menu bar icon with basic dropdown: status label, quit button.
  - Files: AppDelegate or App entry point, MenuBarView, Assets (icon)
  - Verify: App appears in menu bar, persists across restarts if launch-at-login enabled

- [ ] **M1.3 — Basic SwiftUI app structure**
  Add the main window with tab-based navigation shell: Settings, Status. No content yet — just the structural skeleton. Wire menu bar "Open EmberHearth" to show the window.
  - Files: MainWindow, SettingsView (stub), StatusView (stub)
  - Verify: Window opens from menu bar, tabs switch correctly

### M2: iMessage Integration

- [ ] **M2.1 — chat.db reader**
  Implement read-only SQLite access to `~/Library/Messages/chat.db`. Parse the schema (handle, message, chat tables). Decode `attributedBody` for macOS 13+ format. Return structured `Message` objects. Handle Full Disk Access permission check gracefully.
  - Files: MessageReader.swift, Message model, ChatDatabase.swift
  - Verify: Can read recent messages from chat.db in a test harness
  - Reference: `docs/research/imessage.md`

- [ ] **M2.2 — FSEvents message monitoring**
  Watch chat.db for changes using FSEvents (with polling fallback). Detect new messages by tracking last-seen ROWID. Emit new messages to a callback/publisher.
  - Files: MessageMonitor.swift, FSEventsWatcher.swift
  - Verify: New iMessages are detected within seconds of arrival

- [ ] **M2.3 — AppleScript message sending**
  Send iMessages via NSAppleScript controlling Messages.app. Normalize phone numbers to E.164 format. Handle send failures with retry logic. Request Automation permission for Messages.app.
  - Files: MessageSender.swift, PhoneNumberUtils.swift
  - Verify: Can send a test message to a configured phone number
  - Reference: `docs/research/imessage.md`

- [ ] **M2.4 — Phone number filtering + group chat detection**
  Filter incoming messages to only process those from configured phone numbers. Detect group chats (participant count > 2) and block them (MVP behavior). Wire M2.1-M2.3 together into a cohesive message pipeline.
  - Files: MessageRouter.swift, MessagePipeline.swift
  - Verify: Only messages from configured numbers trigger processing; group chats are ignored

### M3: LLM Integration

- [ ] **M3.1 — Claude API client**
  Implement the Anthropic Messages API client using URLSession. Support streaming (SSE parsing). Handle API errors (rate limits, auth failures, network errors) with exponential backoff. Abstract behind a `LLMProvider` protocol for future providers.
  - Files: ClaudeProvider.swift, LLMProvider protocol, SSEParser.swift, APIError types
  - Verify: Can send a prompt and stream back a response
  - Reference: `docs/architecture/decisions/0008-claude-api-primary-llm.md`

- [ ] **M3.2 — Context builder**
  Assemble the LLM prompt from components using the token budget from architecture docs (10% system, 25% recent, 10% summary, 15% memories, 5% tasks, 35% response). Build system prompt, inject recent messages, placeholder slots for memory/summary (wired later).
  - Files: ContextBuilder.swift, ContextBudget.swift, SystemPrompt.swift
  - Verify: Assembled prompt respects token budget; system prompt includes Ember's core identity

- [ ] **M3.3 — End-to-end message flow**
  Wire iMessage pipeline (M2) → context builder (M3.2) → Claude API (M3.1) → send response (M2.3). This is the first "it works" moment. No memory yet — just receive, think, respond.
  - Files: MessageOrchestrator.swift (or similar coordinator)
  - Verify: Text Ember via iMessage, get a response back

### M4: Memory System

- [ ] **M4.1 — SQLite memory database**
  Create the memory.db schema: facts table (content, category, confidence, source, timestamps, emotional_intensity), session state table. Use the storage layout from architecture docs (`~/Library/Application Support/EmberHearth/personal/`). Include schema versioning for future migrations.
  - Files: MemoryDatabase.swift, schema SQL, MemoryModels.swift
  - Verify: Can CRUD facts, schema version tracked
  - Reference: `docs/research/memory-learning.md`

- [ ] **M4.2 — Fact extraction prompt**
  Design and implement the LLM prompt that extracts facts from conversations. Categories: preferences, relationships, biographical, events, opinions, contextual. Each fact gets confidence score and category. Run extraction asynchronously after each conversation turn.
  - Files: FactExtractor.swift, extraction prompt template
  - Verify: Given a conversation snippet, extracts reasonable facts with categories
  - Reference: `docs/research/memory-learning.md` (fact taxonomy)

- [ ] **M4.3 — Fact retrieval + context injection**
  Implement keyword-based fact retrieval (MVP — no embeddings). Wire retrieved facts into the context builder's memory slot. Facts should be formatted as natural language for the system prompt.
  - Files: FactRetriever.swift, update ContextBuilder.swift
  - Verify: Remembered facts appear in Ember's responses when relevant

### M5: Personality

- [ ] **M5.1 — Ember system prompt**
  Implement the full system prompt based on conversation-design.md research. Core identity, voice characteristics, verbosity guidelines, memory instructions, group chat rules. Make it configurable but with sensible defaults.
  - Files: EmberPrompt.swift (or SystemPrompt.swift update), prompt templates
  - Verify: Ember's responses match the designed personality traits
  - Reference: `docs/research/conversation-design.md`, `docs/research/personality-design.md`

- [ ] **M5.2 — Conversation continuity + rolling summary**
  Implement the rolling summary system: trigger at ~20 messages, summarize older messages, keep summary in session state. Ensure conversation feels continuous across summary boundaries. Store session state in memory.db.
  - Files: Summarizer.swift, SessionState.swift, update ContextBuilder
  - Verify: Long conversations maintain coherence; summary triggers are observable in logs

- [ ] **M5.3 — Verbosity adaptation**
  Track implicit user signals for preferred response length. Short questions get short answers. Detailed questions get detailed answers. Adapt over time based on user patterns (store preference in facts).
  - Files: VerbosityTracker.swift, update SystemPrompt
  - Verify: Ember naturally adjusts response length based on user input style

### M6: Security Basics

- [ ] **M6.1 — Keychain integration**
  Store and retrieve the Anthropic API key via Keychain Services. Secure Enclave for key wrapping if available. Never log or display the key. Provide a clean API for the rest of the app.
  - Files: KeychainManager.swift
  - Verify: API key persists across app restarts, never appears in logs
  - Reference: `docs/research/security.md`

- [ ] **M6.2 — Basic Tron: injection defense + credential filtering**
  Implement hardcoded Tron rules in the main app (no XPC for MVP). Inbound: scan for known prompt injection patterns. Outbound: scan responses for credential-like patterns (API keys, passwords, SSNs). Log detections.
  - Files: TronFilter.swift, InjectionPatterns.swift, CredentialPatterns.swift
  - Verify: Known injection patterns are caught; credentials in responses are redacted
  - Reference: `docs/specs/tron-security.md`

- [ ] **M6.3 — Group chat blocking**
  Enforce group chat restrictions: detect group chats, refuse to process commands or access memory. Log the block. This may already be partially done in M2.4 — this task hardens it and adds logging.
  - Files: Update MessageRouter, TronFilter
  - Verify: Group chat messages never reach the LLM with tool access or memory context

### M7: Onboarding

- [ ] **M7.1 — Permission request flow**
  Guide the user through requesting Full Disk Access, Automation (Messages.app), and Notifications permissions. Show clear explanations before each request. Handle denied permissions gracefully with recovery instructions.
  - Files: OnboardingView.swift, PermissionManager.swift
  - Verify: Fresh install walks through permissions correctly; denied permissions show recovery path
  - Reference: `docs/research/onboarding-ux.md`

- [ ] **M7.2 — API key entry + phone number config**
  Onboarding screens for entering the Anthropic API key (stored via M6.1) and configuring which phone number(s) to respond to. Validate the API key with a test call. Show cost expectations.
  - Files: APIKeySetupView.swift, PhoneConfigView.swift
  - Verify: API key validates successfully; phone number is saved and used by message router

- [ ] **M7.3 — First message test**
  Final onboarding step: send a test message to verify the full pipeline works. "Text me to say hello!" flow. Show success/failure clearly. Transition to normal operation.
  - Files: FirstMessageTestView.swift, OnboardingCoordinator.swift
  - Verify: User receives Ember's first message; onboarding completes

### M8: Polish

- [ ] **M8.1 — Error states + recovery**
  Audit all error paths. API failures show user-friendly messages. Network errors queue messages for retry. chat.db access failures suggest permission fix. Crash recovery via launchd (if applicable at this stage).
  - Files: ErrorHandler.swift, update various views with error states
  - Verify: Each major failure mode has a clear user-facing message and recovery path
  - Reference: `docs/specs/error-handling.md`

- [ ] **M8.2 — Status indicators + basic settings UI**
  Menu bar icon reflects current state (connected, processing, error). Settings view allows changing API key, phone numbers, and basic preferences. Status view shows connection health.
  - Files: StatusIndicator.swift, SettingsView.swift (flesh out), StatusView.swift
  - Verify: Menu bar icon changes with state; settings changes take effect immediately

- [ ] **M8.3 — Web tool (URL fetching)**
  Sandboxed HTTP client for fetching URLs on Ember's behalf. Extract article content (strip HTML). Basic rate limiting. This is Ember's only "tool" in MVP beyond conversation.
  - Files: WebFetcher.swift, ContentExtractor.swift
  - Verify: Ember can fetch and summarize a URL when asked
  - Reference: `docs/architecture/decisions/0006-sandboxed-web-tool.md`

- [ ] **M8.4 — Code signing + notarization**
  Configure for Developer ID distribution. Set up notarization workflow (manual or CI). Verify the app installs and runs on a fresh Mac without Gatekeeper warnings.
  - Files: Build configuration, notarization scripts
  - Verify: App passes notarization; installs cleanly on fresh macOS
  - Reference: `docs/deployment/build-and-release.md`

---

## 1.1 "Glow" — Apple Integrations

*Each item below is one session. Items within a group can be done in any order.*

### Apple Framework Integration

- [ ] **G1.1 — EventKit: Calendar read/create**
- [ ] **G1.2 — EventKit: Reminders read/create/complete**
- [ ] **G1.3 — Contacts: lookup + name resolution**
- [ ] **G1.4 — WeatherKit integration**
- [ ] **G1.5 — Safari bookmarks + reading list**

### Mac App Enhancements

- [ ] **G2.1 — Data browser: view/edit/delete facts**
- [ ] **G2.2 — Auto-updates via Sparkle**
- [ ] **G2.3 — Crash reporting (opt-in)**

### Core Enhancements

- [ ] **G3.1 — OpenAI API provider**
- [ ] **G3.2 — Conversation archive (mini-RAG)**
- [ ] **G3.3 — Memory decay (access-based)**
- [ ] **G3.4 — Encrypted database (Data Protection)**
- [ ] **G3.5 — Love language learning**
- [ ] **G3.6 — Active data monitoring (Calendar, Reminders, Safari bookmarks)**

---

## 1.2 "Flame" — Proactive Features

- [ ] **F1.1 — Work/personal context separation**
- [ ] **F1.2 — Full Tron security layer (XPC service)**
- [ ] **F1.3 — Proactive messaging engine**
- [ ] **F1.4 — Notes integration (AppleScript)**
- [ ] **F1.5 — Mail integration (read unread)**
- [ ] **F1.6 — Safari history + current tabs**
- [ ] **F1.7 — Maps/directions (MapKit)**
- [ ] **F1.8 — Semantic search (embeddings)**
- [ ] **F1.9 — Emotional encoding for memories**
- [ ] **F1.10 — Personality customization + archetypes**
- [ ] **F1.11 — Audit logging**
- [ ] **F1.12 — Group chat social mode**

---

## 2.0 "Hearth" — Local Models + Plugins

- [ ] **H1.1 — MLX local model runtime**
- [ ] **H1.2 — Model management UI (download, select, delete)**
- [ ] **H1.3 — Plugin system architecture**
- [ ] **H1.4 — HomeKit integration**
- [ ] **H1.5 — Shortcuts / App Intents**
- [ ] **H1.6 — ML-based injection detection**
- [ ] **H1.7 — Community signature updates**
- [ ] **H1.8 — Rich messages (images, links)**
- [ ] **H1.9 — Ralph Loop quality cycles for local models**
- [ ] **H1.10 — Multi-agent orchestration foundation**

---

## Session Log

*Record completed sessions here so future sessions have context.*

| Date | Item | Notes |
|------|------|-------|
| — | — | — |

---

*Created February 7, 2026. Update this file as work progresses.*
