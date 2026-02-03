# ADR-0005: Safari Read-Only Access by Default

## Status
**Accepted**

## Date
February 2026

## Context

Browser integration provides valuable context:
- Bookmarks reveal long-term interests
- History shows research patterns
- Open tabs indicate current focus
- Page content enables summarization

However, browser control creates significant risks:
- User's authenticated sessions are exposed
- Prompt injection could trigger unintended actions
- Purchases, posts, account changes possible
- Trust violation if Ember acts unexpectedly

Other AI systems (Moltbot, etc.) provided full browser control and suffered consequences.

## Decision

**Safari integration is READ-ONLY by default.**

Ember can:
- Read bookmarks and Reading List (`Bookmarks.plist`)
- Read browsing history (`History.db`)
- Enumerate open tabs (URLs and titles)
- Extract page content for summarization

Ember CANNOT (by default):
- Navigate to URLs
- Open new tabs
- Execute JavaScript for interaction
- Fill forms or click buttons
- Control the browser in any way

**Browser control is an experimental opt-in feature** requiring explicit user acknowledgment.

## Consequences

### Positive
- **Security:** User's authenticated sessions protected
- **Trust:** Users comfortable granting read access
- **Prompt injection safe:** Malicious prompts can't control browser
- **Privacy:** Ember observes but doesn't act
- **Reversible:** Easy to explain, easy to disable

### Negative
- **Limited automation:** Cannot perform web tasks for user
- **Manual handoff:** User must navigate themselves
- **Capability gap:** Less powerful than unrestricted systems

### Neutral
- **Sandboxed web tool:** Ember's own web research uses isolated tool (ADR-0006)

## The Two Paths

```
User's Safari                    Ember's Web Tool
┌─────────────┐                 ┌─────────────────┐
│             │                 │                 │
│  READ ONLY  │                 │  SANDBOXED      │
│             │                 │                 │
│  Bookmarks  │                 │  Fresh context  │
│  History    │                 │  No cookies     │
│  Open Tabs  │                 │  No auth        │
│             │                 │                 │
│  Ember      │                 │  Ember uses     │
│  LEARNS     │                 │  for RESEARCH   │
│             │                 │                 │
└─────────────┘                 └─────────────────┘
```

## Experimental: Browser Control

For power users who want Ember to control Safari:

**Requirements:**
- Explicit opt-in: Settings → Experimental → Safari Control
- Warning acknowledgment about security implications
- Separate from read access permission

**Safeguards:**
- Audit logging of all control actions
- Tron reviews navigation requests
- User can revoke at any time
- Consider per-action confirmation initially

**Why experimental:**
- Higher risk surface
- Prompt injection vulnerability
- Better alternatives exist (sandboxed web tool)

## Alternatives Considered

### Full Browser Control by Default
- Maximum capability
- Rejected: Unacceptable security risk; violates user trust

### No Browser Integration
- Maximum safety
- Rejected: Loses valuable context; significantly less useful assistant

### Control with Per-Action Confirmation
- User approves each action
- Rejected for default: Friction too high; users can't evaluate safety

## References

- `docs/research/safari-integration.md` — Technical implementation
- `docs/research/legal-ethical-considerations.md` — AI companion failures
- ADR-0006 — Sandboxed Web Tool
