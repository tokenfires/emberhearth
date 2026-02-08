# Phase: MVP Construction ("Spark")

**Status:** Active
**Workplan:** [`../v1-workplan.md`](../v1-workplan.md) — the session-by-session task list
**Scope:** [`../releases/mvp-scope.md`](../releases/mvp-scope.md) — what's in and out
**Architecture:** [`../architecture-overview.md`](../architecture-overview.md) — system design

---

## Session Workflow

### Starting a Session

1. Read this doc (you're doing it now)
2. Open [`../v1-workplan.md`](../v1-workplan.md) and find the next unchecked item
3. Read the spec/research docs listed in that item's `Reference:` field
4. State your plan before writing code
5. Build, test, commit

### During a Session

- **One workplan item per session.** If it's done early, you may start the next.
- **Commit after each logical unit.** Don't batch an entire workplan item into one commit.
- If a session touches more than ~3 implementation files + tests, commit and suggest starting fresh.

### Ending a Session

1. Commit all working code
2. Check off completed items in `v1-workplan.md`
3. Log the session in the Session Log table at the bottom of `v1-workplan.md`
4. If anything is half-done, leave a clear note in the Session Log for the next session

---

## Source Code Layout

MVP is a single-process app (no XPC services yet). Organize `src/` by component:

```
src/
├── App/
│   ├── EmberHearthApp.swift           # Entry point
│   └── AppState.swift                 # Global app state
├── Views/
│   ├── MenuBar/                       # Menu bar UI
│   ├── Onboarding/                    # First-run flow
│   ├── Settings/                      # Configuration screens
│   └── Status/                        # Status/health display
├── Messages/
│   ├── MessageReader.swift            # chat.db access
│   ├── MessageSender.swift            # AppleScript sending
│   ├── MessageMonitor.swift           # FSEvents watcher
│   ├── MessageRouter.swift            # Phone filtering, group detection
│   └── Models/                        # Message, Chat types
├── LLM/
│   ├── LLMProvider.swift              # Protocol
│   ├── ClaudeProvider.swift           # Anthropic API client
│   ├── SSEParser.swift                # Streaming response parser
│   ├── ContextBuilder.swift           # Prompt assembly
│   └── ContextBudget.swift            # Token budget enforcement
├── Memory/
│   ├── MemoryDatabase.swift           # SQLite operations
│   ├── FactExtractor.swift            # LLM-driven extraction
│   ├── FactRetriever.swift            # Query and retrieval
│   └── Models/                        # Fact, Session types
├── Personality/
│   ├── EmberPrompt.swift              # System prompt templates
│   ├── Summarizer.swift               # Rolling summary
│   └── VerbosityTracker.swift         # Adaptive response length
├── Security/
│   ├── KeychainManager.swift          # Keychain read/write
│   ├── TronFilter.swift               # Inbound/outbound scanning
│   ├── InjectionPatterns.swift        # Known injection signatures
│   └── CredentialPatterns.swift       # Credential detection regexes
└── Utilities/
    ├── PhoneNumberUtils.swift         # E.164 normalization
    ├── WebFetcher.swift               # Sandboxed URL fetching
    ├── ContentExtractor.swift         # HTML → text
    └── ErrorHandler.swift             # Centralized error handling
```

**Rule:** If a new file doesn't fit cleanly in this structure, create it where it makes sense and note the deviation in the commit message. Don't force it.

---

## Swift Coding Standards

### Error Handling

- Use `async throws` for operations that can fail. Prefer structured concurrency over callbacks.
- Define domain-specific error enums (e.g., `MessageError`, `LLMError`, `MemoryError`).
- Never use `try!` or force-unwraps in production code. `try?` is acceptable only when the failure is genuinely ignorable.
- Catch errors at the boundary where you can do something useful (retry, show UI, log).

```swift
// Good
enum MessageError: LocalizedError {
    case databaseNotFound
    case accessDenied(reason: String)
    case decodingFailed(messageID: Int64)

    var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            return "Messages database not found. Full Disk Access may be required."
        case .accessDenied(let reason):
            return "Cannot access messages: \(reason)"
        case .decodingFailed(let id):
            return "Failed to decode message \(id)"
        }
    }
}
```

### Concurrency

- Use Swift structured concurrency (`async/await`, `Task`, `TaskGroup`).
- Mark UI-updating code with `@MainActor`.
- Use `actor` for shared mutable state (e.g., the message monitor, memory database).
- Avoid `DispatchQueue` unless interfacing with APIs that require it.

### Protocols & Dependency Injection

- Define protocols for testable boundaries: `LLMProvider`, `MessageReading`, `MessageSending`, `MemoryStoring`.
- Inject dependencies through initializers, not singletons.
- This enables testing with mocks and swapping implementations later (e.g., OpenAI provider in v1.1).

```swift
// Good — protocol + injection
protocol LLMProvider {
    func complete(prompt: [Message], systemPrompt: String) async throws -> AsyncStream<String>
}

final class MessageOrchestrator {
    private let llm: LLMProvider
    private let memory: MemoryStoring

    init(llm: LLMProvider, memory: MemoryStoring) {
        self.llm = llm
        self.memory = memory
    }
}
```

### Logging

- Use Apple's `os.Logger` framework (not `print()`).
- Create per-subsystem loggers: `Logger(subsystem: "com.emberhearth", category: "messages")`
- Log levels: `.debug` for development, `.info` for operational events, `.error` for failures, `.fault` for things that should never happen.
- **Never log credentials, API keys, or message content at `.info` or above.** Message content may appear in `.debug` only.

### Access Control

- Default to `internal` (Swift's default). Use `private` for implementation details.
- Use `public` only for things that would cross module boundaries (not applicable in MVP's single-target, but good habit).
- Mark classes `final` unless designed for inheritance.

### SwiftUI Patterns

- Use `@Observable` (macOS 14+) or `@ObservableObject` (macOS 13 compat) for view models.
- Keep views thin — business logic belongs in services/managers, not views.
- Every interactive element needs an `.accessibilityLabel()`.
- Support Dynamic Type — avoid hardcoded font sizes.

---

## Testing Expectations

### What to Test

- **Business logic:** Message parsing, phone number normalization, fact extraction parsing, context budget math, injection pattern matching, credential detection.
- **Integration points:** Database operations (use in-memory SQLite), API request/response construction.
- **Don't test:** SwiftUI view layout, Apple framework behavior, things you'd have to mock six layers deep.

### Test Structure

```
tests/
├── MessagesTests/
│   ├── MessageReaderTests.swift
│   ├── MessageRouterTests.swift
│   └── PhoneNumberUtilsTests.swift
├── LLMTests/
│   ├── SSEParserTests.swift
│   ├── ContextBuilderTests.swift
│   └── ContextBudgetTests.swift
├── MemoryTests/
│   ├── MemoryDatabaseTests.swift
│   └── FactExtractorTests.swift
├── SecurityTests/
│   ├── InjectionPatternsTests.swift
│   └── CredentialPatternsTests.swift
└── Mocks/
    ├── MockLLMProvider.swift
    ├── MockMemoryStore.swift
    └── MockMessageSender.swift
```

### Naming Convention

```swift
func test_methodName_condition_expectedResult() {
    // Given
    let parser = SSEParser()
    let input = "data: {\"type\": \"content_block_delta\"}\n\n"

    // When
    let events = parser.parse(input)

    // Then
    XCTAssertEqual(events.count, 1)
}
```

---

## Dependencies

### Approved for MVP

- **None.** MVP uses only Apple frameworks and the Swift standard library.
- SQLite access via the system `libsqlite3` (no wrapper library).
- HTTP via `URLSession`.
- JSON via `Codable`.

### Why No Third-Party Dependencies

This is a deliberate MVP choice: zero supply chain risk, zero version conflicts, zero licensing concerns. It also keeps the build simple for early sessions.

### For Later Phases

- **Sparkle** (auto-updates) — approved for v1.1
- Third-party libraries require explicit approval before adding.

---

## Commit Messages

Use this format:

```
<type>(<scope>): <short description>

<optional body explaining why, not what>
```

**Types:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
**Scopes:** `messages`, `llm`, `memory`, `security`, `personality`, `onboarding`, `ui`, `build`

Examples:
```
feat(messages): add chat.db reader with attributedBody decoding
fix(llm): handle SSE reconnection on network timeout
test(security): add injection pattern detection tests
docs: update v1-workplan session log
```

---

## MVP Simplifications to Remember

These are *intentional* shortcuts for MVP. Don't over-engineer past them:

- **Single process** — no XPC services yet (comes in v1.2 for full Tron)
- **Tron is hardcoded** — pattern matching in-app, not a separate security service
- **No Apple integrations** beyond iMessage (Calendar, Contacts, etc. come in v1.1)
- **No proactive features** — Ember only responds when messaged
- **No work/personal separation** — single context only
- **Keyword-based memory retrieval** — no embeddings or semantic search
- **Claude API only** — no OpenAI, no local models
- **Manual distribution** — no auto-updates

If you find yourself building infrastructure for a later phase, stop and check with the user.

---

## Key Specs by Milestone

Read the relevant specs before starting each milestone:

| Milestone | Read These First |
|---|---|
| M1: Foundation | [`architecture-overview.md`](../architecture-overview.md) |
| M2: iMessage | [`research/imessage.md`](../research/imessage.md), [`research/session-management.md`](../research/session-management.md) |
| M3: LLM Integration | [`specs/api-setup-guide.md`](../specs/api-setup-guide.md), [`specs/error-handling.md`](../specs/error-handling.md) |
| M4: Memory | [`research/memory-learning.md`](../research/memory-learning.md) |
| M5: Personality | [`research/conversation-design.md`](../research/conversation-design.md), [`research/personality-design.md`](../research/personality-design.md), [`specs/token-awareness.md`](../specs/token-awareness.md) |
| M6: Security | [`specs/tron-security.md`](../specs/tron-security.md), [`research/security.md`](../research/security.md) |
| M7: Onboarding | [`research/onboarding-ux.md`](../research/onboarding-ux.md), [`specs/api-setup-guide.md`](../specs/api-setup-guide.md) |
| M8: Polish | [`specs/error-handling.md`](../specs/error-handling.md), [`specs/autonomous-operation.md`](../specs/autonomous-operation.md), [`deployment/build-and-release.md`](../deployment/build-and-release.md) |

---

## Implementation Guide

For the full checkpoint-driven development workflow, session templates, verification checklists, and human review protocols, see:

[`../IMPLEMENTATION-GUIDE.md`](../IMPLEMENTATION-GUIDE.md)

That doc is complementary to this one — it covers *process*, this doc covers *standards*.
