# ADR-0001: Use XPC Services for Component Isolation

## Status
**Accepted**

## Date
February 2026

## Context

EmberHearth integrates with sensitive system APIs:
- iMessage (chat.db access)
- Calendar and Reminders (EventKit)
- Mail and Notes (AppleScript automation)
- Safari data (bookmarks, history)
- LLM providers (API keys, conversation data)

A single-process architecture would mean:
- Any vulnerability exposes all capabilities
- A crash in one component crashes everything
- All code runs with maximum permissions

We need an architecture that provides defense-in-depth while remaining practical for a small team to implement.

## Decision

**Use XPC services for major functional domains:**

```
EmberHearth.app (Main Process)
├── MessageService.xpc      # iMessage read/write
├── MemoryService.xpc       # Facts, conversation archive
├── LLMService.xpc          # LLM provider communication
├── CalendarService.xpc     # EventKit integration
├── MailService.xpc         # Mail.app automation
├── NotesService.xpc        # Notes.app automation
└── IntegrationService.xpc  # Other Apple frameworks
```

Each XPC service:
- Runs in its own process
- Has minimal entitlements for its function
- Validates connections via code signing
- Can crash without taking down the app

## Consequences

### Positive
- **Process isolation:** Compromise of one service doesn't expose others
- **Minimal permissions:** Each service requests only what it needs
- **Crash resilience:** Service crashes are recoverable
- **Security boundaries:** Clear attack surface per component
- **Scalability:** Can add new services without modifying core
- **Apple-native:** XPC is the macOS-sanctioned IPC mechanism

### Negative
- **Complexity:** More code than single-process
- **IPC overhead:** Cross-process calls have latency (minimal in practice)
- **Debugging:** Harder to trace issues across process boundaries
- **Code signing:** All services must be signed with same team ID

### Neutral
- **Build system:** Xcode supports XPC targets natively
- **Testing:** Can test services in isolation

## Alternatives Considered

### Single Process
- Simpler to implement
- Rejected: Unacceptable security posture for sensitive integrations

### Microservices (HTTP)
- Maximum isolation
- Rejected: Overkill for local-only app; unnecessary network exposure

### App Groups + Shared Memory
- Fast IPC
- Rejected: Doesn't provide process isolation

## Implementation Notes

- All XPC connections must verify code signing before accepting
- Use `NSXPCConnection` with proper error handling
- Services should be stateless where possible (state in MemoryService)
- Consider async/await for cleaner XPC code in Swift

## References

- `docs/research/security.md` — XPC architecture details
- `docs/research/macos-apis.md` — Service model recommendation
- `docs/VISION.md` — Tron security layer concept
