# EmberHearth UX Flow Model

> Generated 2025-03-25. Source of truth: codebase on `claude-desktop-attempt` branch.
> Purpose: Input for building a UX flow diagram.

---

## 1. File Tree Summary

```
src/
├── App/                              # Lifecycle, startup, menu bar
│   ├── EmberHearthApp.swift          # @main entry point
│   ├── AppDelegate.swift             # Startup sequence, service init
│   ├── AppState.swift                # Observable app status (ready/error/offline/etc.)
│   ├── ServiceContainer.swift        # Boots all services after onboarding
│   ├── StatusBarController.swift     # Menu bar icon + dropdown menu
│   ├── PermissionManager.swift       # Checks FDA, Automation, Notifications
│   ├── LaunchAtLoginManager.swift    # SMAppService toggle
│   ├── CrashRecoveryManager.swift    # Crash detection/recovery
│   └── HealthCheckService.swift      # System health monitoring
│
├── Core/                             # iMessage integration + message pipeline
│   ├── MessageWatcher.swift          # FSEvents monitor on chat.db
│   ├── ChatDatabaseReader.swift      # SQLite reader for chat.db
│   ├── MessageCoordinator.swift      # Central pipeline orchestrator
│   ├── MessageSender.swift           # AppleScript → Messages.app
│   ├── MessageQueue.swift            # Offline retry queue
│   ├── PhoneNumberFilter.swift       # E.164 phone matching
│   ├── GroupChatDetector.swift       # Blocks group chats (>2 participants)
│   ├── NetworkMonitor.swift          # Connectivity state
│   ├── OfflineCoordinator.swift      # Queues messages when offline
│   ├── SessionManager.swift          # Conversation session tracking
│   ├── SummaryGenerator.swift        # Rolling conversation summaries
│   ├── WebFetcher.swift              # URL content extraction (for URL tool)
│   └── Models/ChatMessage.swift      # Message data model
│
├── LLM/                             # Claude API client
│   ├── ClaudeAPIClient.swift         # HTTP + SSE streaming to Anthropic
│   ├── ContextBuilder.swift          # Token-budgeted prompt assembly
│   ├── SSEParser.swift               # Server-Sent Events parser
│   ├── RetryHandler.swift            # Exponential backoff
│   ├── CircuitBreaker.swift          # Graceful degradation
│   └── LLMProviderProtocol.swift     # Abstraction for future providers
│
├── Memory/                           # Fact extraction & retrieval
│   ├── FactExtractor.swift           # LLM-based fact extraction
│   ├── FactRetriever.swift           # Keyword-based retrieval (MVP)
│   ├── FactStore.swift               # SQLite fact storage
│   └── Fact.swift                    # Fact model (category, confidence)
│
├── Personality/                      # Ember's voice & behavior
│   ├── EmberSystemPrompt.swift       # Core identity prompt
│   ├── SystemPromptBuilder.swift     # Prompt + context assembly
│   └── VerbosityAdapter.swift        # Response length adaptation
│
├── Security/                         # "Tron" security pipeline
│   ├── TronPipeline.swift            # Inbound + outbound security orchestrator
│   ├── InjectionScanner.swift        # Prompt injection detection
│   ├── CredentialScanner.swift       # API keys, SSNs, credit cards
│   ├── CrisisDetector.swift          # Mental health crisis signals
│   ├── KeychainManager.swift         # Secure secret storage
│   └── CrisisResponseTemplates.swift # Pre-written crisis responses
│
├── Database/                         # App's own SQLite database
│   └── DatabaseManager.swift         # Schema + connection management
│
├── Logging/                          # Structured logging
│   ├── AppLogger.swift               # General logging (os.log)
│   └── SecurityLogger.swift          # Security event audit log
│
└── Views/                            # All user-facing UI
    ├── ContentView.swift             # Root router (onboarding vs. main)
    ├── ErrorStateView.swift          # Error presentation
    ├── Components/StatusBanner.swift  # Shared status component
    ├── Onboarding/                   # 7 views for first-run wizard
    │   ├── OnboardingContainerView.swift
    │   ├── WelcomeView.swift
    │   ├── PermissionsView.swift
    │   ├── APIKeyEntryView.swift
    │   ├── AgentEmailConfigView.swift
    │   ├── PhoneConfigView.swift
    │   └── FirstMessageTestView.swift
    └── Settings/                     # Preferences window
        ├── SettingsView.swift        # Tab container
        ├── GeneralSettingsView.swift
        ├── APISettingsView.swift
        └── AboutView.swift
```

**Key directories by role:**

| Directory | Role |
|-----------|------|
| `App/` | Bootstrapping, lifecycle, menu bar presence |
| `Core/` | The iMessage read/write pipeline — the heart of the app |
| `LLM/` | Claude API communication layer |
| `Memory/` | Long-term fact storage and retrieval |
| `Personality/` | System prompt and response style |
| `Security/` | Input/output scanning, Keychain, crisis detection |
| `Views/` | Everything the user sees and interacts with |

---

## 2. Screen & State Inventory

### 2.1 Surfaces

EmberHearth has **three user-facing surfaces**:

| Surface | Type | When visible |
|---------|------|-------------|
| **Menu bar icon** | NSStatusItem (always present) | From app launch onward |
| **App window** | SwiftUI WindowGroup | During onboarding; hidden after setup |
| **iMessage thread** | Apple Messages.app | Ongoing — user texts, Ember replies |

There is **no iMessage extension**. The app reads `~/Library/Messages/chat.db` directly (requires Full Disk Access) and sends replies via AppleScript automation of Messages.app.

### 2.2 Menu Bar Icon States

The menu bar flame icon is the app's persistent presence. It changes appearance based on system health:

| State | Icon | Visual Treatment |
|-------|------|-----------------|
| **Ready** | `flame.fill` | System template color |
| **Processing** | `flame.fill` | Pulsing animation |
| **Degraded** | `flame.fill` | Yellow tint |
| **Error** | `exclamationmark.triangle.fill` | Red |
| **Offline** | `flame.fill` | Dimmed |
| **Paused** | `pause.circle.fill` | System template color |

**Menu bar dropdown contents:**
- Status label (e.g., "Running", "Processing...", "Error")
- Message count
- "Settings..." → opens Settings window
- "About" → opens About tab
- Separator
- "Quit"

### 2.3 Onboarding Screens (6 steps)

| Step | Screen | Purpose | Key Actions |
|------|--------|---------|-------------|
| 0 | **WelcomeView** | Introduce Ember, set security expectations | "Get Started" |
| 1 | **PermissionsView** | Request Full Disk Access + Automation + Notifications | "Open Settings" per permission, real-time re-check |
| 2 | **APIKeyEntryView** | Enter Claude API key | Paste key → Validate (live test call) → Keychain storage |
| 3 | **AgentEmailConfigView** | Set iCloud email for agent identity | Enter email → Save |
| 4 | **PhoneConfigView** | Configure which phone numbers Ember responds to | Enter number → normalize to E.164 → Add to list |
| 5 | **FirstMessageTestView** | End-to-end verification | Send iMessage → watch for detection → show result |

**Onboarding container** (`OnboardingContainerView`): progress bar, back/continue navigation, step animation.

### 2.4 Main App Window (Post-Onboarding)

After onboarding completes, the app window shows a minimal status view:
- Flame icon
- "Running" status indicator
- The window is typically hidden; the menu bar is the primary interface

### 2.5 Settings Window (3 tabs)

| Tab | Screen | Contents |
|-----|--------|----------|
| General | **GeneralSettingsView** | Launch at login toggle, auto-respond settings |
| API | **APISettingsView** | Current provider, API key management, token usage |
| About | **AboutView** | Version, copyright, links |

### 2.6 Error States

| Error surface | Trigger | What user sees |
|---------------|---------|----------------|
| **ContentView** | Prerequisites not met after onboarding | `ErrorStateView` with description |
| **Inline validation** | Bad API key format, invalid phone number | Red text below input field |
| **Menu bar icon** | API failure, offline, crash recovery | Icon changes to error state |
| **First message test** | Timeout or failure | Troubleshooting tips + retry option |

### 2.7 iMessage Interface (User's Perspective)

The user interacts with Ember **entirely through the standard Messages app**. There is no custom UI in Messages. The conversation looks like a normal iMessage thread:

- **User sends:** Regular text message to their own number (or the agent email)
- **Ember replies:** Text message appears in the same thread
- Messages are standard SMS/iMessage bubbles — no rich cards, no tapbacks, no custom UI

---

## 3. Interaction Flow Narrative

### 3.1 First Launch (Onboarding)

```
User double-clicks EmberHearth.app
    │
    ├── AppDelegate fires immediately:
    │   ├── App set to accessory mode (no dock icon)
    │   ├── Menu bar flame icon appears (template)
    │   └── Crash recovery check
    │
    ├── ContentView checks prerequisites:
    │   ├── Is onboarding complete? (UserDefaults flag)
    │   ├── Is API key in Keychain?
    │   └── Are permissions granted?
    │
    └── Prerequisites NOT met → Show OnboardingContainerView
```

**Step 0 — Welcome:**
- User sees flame icon, "Welcome to EmberHearth" heading, security bullets
- Action: Click "Get Started" → advance to Step 1

**Step 1 — Permissions:**
- Three permission cards shown with granted/not-granted status
- Full Disk Access (required): "Open Settings" → System Settings → FDA pane
- Automation (required): "Open Settings" → System Settings → Automation pane
- Notifications (optional): "Open Settings" → System Settings → Notifications
- Permission status updates in real time when user grants in System Settings
- Action: Both required permissions granted → "Continue" becomes active → advance

**Step 2 — API Key:**
- User sees "Connect to Claude" heading, explanation of API vs. subscription
- Link to console.anthropic.com for key creation
- SecureField input (masked)
- Action: Paste key → Click "Validate"
  - Format check: must start with `sk-ant-`, >= 20 chars
  - Live test: POST to Anthropic API with minimal payload
  - **Success:** Green checkmark animation → key saved to Keychain → auto-advance
  - **Failure:** Error message shown inline (invalid key, network error, etc.)
- "Skip for Now" option available (allows deferring)

**Step 3 — Agent Email:**
- User enters iCloud email address for Ember's agent identity
- Basic format validation (contains `@`)
- Saved to UserDefaults
- Action: Enter email → "Save" → advance

**Step 4 — Phone Number:**
- User enters phone number(s) Ember should respond to
- "+1" prefix pre-filled, placeholder "(555) 123-4567"
- Action: Enter number → "Add"
  - Number normalized to E.164 format (+1XXXXXXXXXX)
  - Added to list with green checkmark
  - Can add multiple numbers
  - Can remove numbers with minus button
- Action: At least one number added → "Continue" → advance

**Step 5 — First Message Test:**
- Instructions shown: "Open Messages, send a text, say 'Hey Ember, are you there?'"
- 60-second countdown timer starts
- Status indicator updates in real time:
  1. **Waiting** (blue, antenna) — watching chat.db
  2. **Message Received** (orange, envelope) — new message detected
  3. **Processing** (purple, brain) — sending to Claude API
  4. **Response Sent** (green, checkmark) — reply delivered
- **On success:**
  - Celebration display with message bubbles showing the exchange
  - "Finish Setup" button → marks onboarding complete → transition to main state
- **On timeout (60s):**
  - Troubleshooting tips shown (check Messages, FDA, phone number, internet, API key)
  - "Retry" button resets the timer
  - "Skip Test" button → marks onboarding complete anyway
- **On failure:**
  - Error details shown
  - "Retry" or "Skip Test" available

**Post-onboarding transition:**
- UserDefaults flag set → ContentView re-evaluates → shows main status view
- AppDelegate initializes ServiceContainer → all services boot
- MessageCoordinator starts watching chat.db → Ember is live

### 3.2 Steady-State Operation (After Onboarding)

```
User opens Messages.app on any Apple device
    │
    └── Sends text to configured phone number
         │
         chat.db updated
              │
              MessageWatcher (FSEvents) detects change
              │
              ChatDatabaseReader queries new message
              │
              PhoneNumberFilter: is sender in allowed list?
              ├── NO → Message ignored (silent)
              │
              └── YES
                   │
                   GroupChatDetector: is this a group chat?
                   ├── YES (>2 participants) → Message blocked (silent)
                   │
                   └── NO (1:1 conversation)
                        │
                        TronPipeline INBOUND scan
                        ├── InjectionScanner: prompt injection attempt?
                        │   └── HIGH threat → Message blocked, security event logged
                        ├── CredentialScanner: contains secrets?
                        │   └── Found → Credentials redacted from context
                        └── CrisisDetector: mental health crisis signals?
                            └── Detected → Crisis response template used instead of LLM
                        │
                        PASSED
                        │
                        ContextBuilder assembles prompt:
                        ├── System prompt (Ember personality) — 10% token budget
                        ├── Retrieved facts from FactStore — 15%
                        ├── Conversation summary — 10%
                        ├── Recent messages — 25%
                        ├── Task state — 5%
                        └── Response reserve — 35%
                        │
                        ClaudeAPIClient → POST to Anthropic API (SSE streaming)
                        │
                        ├── SUCCESS: Response accumulated from stream
                        │    │
                        │    TronPipeline OUTBOUND scan
                        │    ├── CredentialScanner: response contains secrets?
                        │    │   └── Found → Redacted before sending
                        │    └── Content checks pass
                        │    │
                        │    MessageSender → AppleScript → Messages.app
                        │    │
                        │    └── Reply appears in user's iMessage thread
                        │
                        │    ASYNC (background):
                        │    ├── FactExtractor: extract facts from this exchange
                        │    ├── FactStore: save new facts to memory.db
                        │    ├── SessionManager: update conversation state
                        │    └── SummaryGenerator: update rolling summary (if >20 messages)
                        │
                        ├── FAILURE (API error):
                        │    RetryHandler: exponential backoff (up to N retries)
                        │    ├── Retry succeeds → proceed as above
                        │    └── All retries exhausted:
                        │         CircuitBreaker opens
                        │         AppState → .degraded or .error
                        │         Menu bar icon changes
                        │         (No reply sent to user — silent failure)
                        │
                        └── OFFLINE (no network):
                             OfflineCoordinator queues message
                             NetworkMonitor watches for reconnection
                             └── Online again → MessageQueue retries queued messages
```

### 3.3 Settings Interaction

```
User clicks menu bar flame icon
    │
    └── Dropdown menu appears
         │
         ├── "Settings..." clicked
         │    └── Settings window opens (tab view)
         │         ├── General tab: toggle launch-at-login
         │         ├── API tab: view/change API key, see token usage
         │         └── About tab: version, links
         │
         ├── "About" clicked → About tab of Settings
         │
         └── "Quit" clicked → App terminates
```

### 3.4 Background State Changes (No User Action Required)

| Event | System response | User-visible effect |
|-------|----------------|-------------------|
| Network lost | OfflineCoordinator activates, messages queued | Menu bar → dimmed (offline) |
| Network restored | Queued messages retried | Menu bar → ready |
| API errors accumulate | CircuitBreaker opens | Menu bar → yellow (degraded) |
| CircuitBreaker resets | Normal processing resumes | Menu bar → ready |
| Crash detected on relaunch | CrashRecoveryManager runs | Recovery logged, services restart |

---

## 4. Integration Boundaries

### 4.1 Anthropic Claude API

| Aspect | Detail |
|--------|--------|
| **Endpoint** | `https://api.anthropic.com/v1/messages` |
| **Protocol** | REST + Server-Sent Events (streaming) |
| **Auth** | `x-api-key` header |
| **Model** | `claude-sonnet-4-6` |
| **Touchpoints** | `ClaudeAPIClient.swift`, `SSEParser.swift`, `RetryHandler.swift`, `CircuitBreaker.swift` |
| **Validation call** | Test POST with `max_tokens: 10` during onboarding |
| **Error handling** | Exponential backoff → circuit breaker → degraded state |

### 4.2 Apple iMessage / Messages.app

| Aspect | Detail |
|--------|--------|
| **Read path** | SQLite queries on `~/Library/Messages/chat.db` (read-only) |
| **Write path** | AppleScript: `tell application "Messages" to send` |
| **Detection** | FSEvents file system monitor on chat.db |
| **Permissions required** | Full Disk Access (read chat.db) + Automation (control Messages.app) |
| **Touchpoints** | `ChatDatabaseReader.swift`, `MessageWatcher.swift`, `MessageSender.swift` |

### 4.3 macOS Keychain

| Aspect | Detail |
|--------|--------|
| **Purpose** | Store Claude API key securely |
| **Touchpoints** | `KeychainManager.swift` |
| **Operations** | Save, retrieve, delete, exists-check |

### 4.4 macOS System Services

| Service | Purpose | Touchpoint |
|---------|---------|------------|
| **SMAppService** | Launch at login | `LaunchAtLoginManager.swift` |
| **UNUserNotificationCenter** | Desktop notifications (optional) | `PermissionManager.swift` |
| **NSStatusItem** | Menu bar icon | `StatusBarController.swift` |
| **os.log** | Structured logging | `AppLogger.swift` |

### 4.5 NOT Present (Mentioned in Project Docs but Not in Code)

| System | Status | Notes |
|--------|--------|-------|
| **OpenClaw** | Not referenced in code | May be planned for future phases |
| **Mem0** | Not referenced in code | Custom memory system built instead (`FactStore`) |
| **TTS / Speech Synthesis** | Not referenced in code | No voice features in MVP |
| **Embeddings / Vector DB** | Not in code | `FactRetriever` uses keyword search (MVP) |

---

## 5. Ambiguities & Open Questions

### Flow Ambiguities

1. **Silent failures in steady state.** When the LLM call fails after all retries, the user gets no reply in iMessage. There's no "sorry, I couldn't process that" fallback message. The only signal is the menu bar icon changing — which the user may not notice.

2. **Group chat blocking is silent.** Messages from group chats (>2 participants) are dropped without any notification to the sender. It's unclear if this is intentional UX or a gap.

3. **"Skip" paths in onboarding.** API key entry has "Skip for Now" — but the app requires a key to function. What happens if the user skips? ContentView would loop back to onboarding (no key in Keychain), creating a potential stuck state unless the check is soft.

4. **Agent email purpose is unclear from code alone.** `AgentEmailConfigView` captures an iCloud email, but its downstream usage isn't visible in the message pipeline. Is it used for sending, identity verification, or future iMessage relay setup?

5. **Phone number = user's own number?** The onboarding says "Who should Ember listen to?" — implying the user enters their own phone number. But `MessageSender` sends replies to a phone number too. The relationship between "listen to" numbers and "reply to" numbers needs clarification.

6. **No explicit "pause/resume" UI.** `AppState` has a `.paused` state and the menu bar shows a pause icon, but there's no visible toggle in Settings or the menu bar dropdown to pause/resume Ember.

7. **Crash recovery UX.** `CrashRecoveryManager` detects crashes on relaunch, but it's not clear if the user sees anything (a notification? a banner?) or if recovery is entirely silent.

8. **Multiple phone numbers behavior.** The UI allows adding multiple numbers. Does Ember respond to all of them? Are responses differentiated per number? Is there per-number session tracking?

### Architecture Ambiguities

9. **Onboarding completion flag vs. actual readiness.** `ContentView` checks a UserDefaults flag AND the Keychain AND permissions. If the user revokes FDA after onboarding, what do they see — onboarding again, or an error state?

10. **Window lifecycle after onboarding.** The app window shows a status view post-onboarding, but the app is set to accessory mode (no dock icon). How does the user reopen the window if they close it? Only via the menu bar?

11. **First message test scope.** The test step detects a message via `MessageWatcher` but the code comments suggest it doesn't test the full LLM round-trip during MVP. If the test only verifies message detection (not response), the user might think everything works when the API integration hasn't been validated end-to-end.

---

## Appendix: Screen Navigation Map

```
┌─────────────────────────────────────────────────────┐
│                    APP LAUNCH                        │
│              EmberHearthApp (@main)                  │
│                      │                               │
│        AppDelegate: menu bar icon appears            │
│                      │                               │
│              ContentView (router)                    │
│              ┌───────┴────────┐                      │
│              │                │                      │
│        Prerequisites     Prerequisites               │
│          NOT met            MET                       │
│              │                │                      │
│     OnboardingContainer   Main Status View           │
│      ┌───┬───┬───┬───┐    (flame + "Running")       │
│      │   │   │   │   │                               │
│     S0  S1  S2  S3  S4  S5                           │
│     Welc Perm API  Email Phone Test                  │
│      │   │   │   │   │   │                           │
│      └───┴───┴───┴───┴───┘                           │
│              │                                       │
│       Onboarding Complete                            │
│              │                                       │
│       → Main Status View                             │
│       → ServiceContainer boots                       │
│       → MessageCoordinator starts                    │
│       → Ember is LIVE                                │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│               MENU BAR (always present)              │
│                                                      │
│    🔥 (flame icon — reflects AppState)              │
│     │                                                │
│     └── Click → Dropdown Menu                        │
│          ├── Status: "Running"                       │
│          ├── Messages: 42                            │
│          ├── ─────────────                           │
│          ├── Settings... → Settings Window           │
│          │     ├── General tab                       │
│          │     ├── API tab                           │
│          │     └── About tab                         │
│          ├── About → Settings (About tab)            │
│          ├── ─────────────                           │
│          └── Quit                                    │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│            iMESSAGE (external surface)               │
│                                                      │
│    User's Messages.app (any Apple device)            │
│     │                                                │
│     ├── User sends text ─────────────────────────┐   │
│     │                                            │   │
│     │   (behind the scenes: chat.db → pipeline   │   │
│     │    → Claude API → pipeline → AppleScript)  │   │
│     │                                            │   │
│     └── Ember's reply appears ◄──────────────────┘   │
│                                                      │
│    Looks like a normal iMessage conversation.        │
│    No custom UI, no rich cards, no extensions.       │
└─────────────────────────────────────────────────────┘
```
