# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for EmberHearth. ADRs document significant architectural decisions, including the context, decision, and consequences.

## Index

| ADR | Title | Status |
|-----|-------|--------|
| [0001](0001-xpc-service-isolation.md) | Use XPC Services for Component Isolation | Accepted |
| [0002](0002-distribute-outside-app-store.md) | Distribute Outside Mac App Store | Accepted |
| [0003](0003-imessage-primary-interface.md) | iMessage as Primary Interface | Accepted |
| [0004](0004-no-shell-execution.md) | No Shell/Command Execution | Accepted |
| [0005](0005-safari-read-only-default.md) | Safari Read-Only Access by Default | Accepted |
| [0006](0006-sandboxed-web-tool.md) | Sandboxed Web Tool for Ember's Research | Accepted |
| [0007](0007-sqlite-memory-storage.md) | SQLite for Memory and Conversation Storage | Accepted |
| [0008](0008-claude-api-primary-llm.md) | Claude API as Primary LLM Provider | Accepted |
| [0009](0009-tron-security-layer.md) | Tron Security Layer Architecture | Accepted |
| [0010](0010-fsevents-data-monitoring.md) | FSEvents for Active Data Monitoring | Accepted |
| [0011](0011-bounded-needs-personality.md) | Bounded Needs Personality Model | Accepted |

## ADR Status Definitions

- **Proposed:** Under discussion, not yet decided
- **Accepted:** Decision made and in effect
- **Deprecated:** No longer applies but kept for history
- **Superseded:** Replaced by another ADR (link provided)

## Creating New ADRs

When adding a new ADR:

1. Copy the template below
2. Use the next sequential number (e.g., `0012-*.md`)
3. Fill in all sections
4. Update this README index
5. Commit with message: `docs: Add ADR-XXXX <title>`

## Template

```markdown
# ADR-XXXX: Title

## Status
**Proposed** | **Accepted** | **Deprecated** | **Superseded by [ADR-YYYY](link)**

## Date
Month Year

## Context
What is the issue that we're seeing that is motivating this decision?

## Decision
What is the change that we're proposing and/or doing?

## Consequences

### Positive
- Good things that happen as a result

### Negative
- Trade-offs and downsides

### Neutral
- Things that are neither good nor bad

## Alternatives Considered
What other options were evaluated?

## References
- Links to related documents, research, external resources
```

## References

- [ADR GitHub Organization](https://adr.github.io/)
- [Michael Nygard's ADR Article](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [Architecture Decision Records at Spotify](https://engineering.atspotify.com/2020/04/when-should-i-write-an-architecture-decision-record/)
