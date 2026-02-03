# ADR-0009: Tron Security Layer Architecture

## Status
**Accepted**

## Date
February 2026

## Context

EmberHearth processes:
- Untrusted input (user messages, which could contain prompt injection)
- Sensitive data (calendar, messages, browsing history)
- Powerful capabilities (send messages, create events, web access)

Without a security layer:
- Prompt injection could trigger unauthorized actions
- Sensitive data could leak to LLM or logs
- Malicious content could be forwarded to user
- No audit trail for security review

A dedicated security enforcement component is needed.

## Decision

**Implement Tron as the security enforcement layer.**

Tron sits between all inputs and Ember, and between Ember and all outputs:

```
        Inbound                              Outbound
           │                                    │
           ▼                                    ▼
    ┌─────────────┐                     ┌─────────────┐
    │    TRON     │                     │    TRON     │
    │   Inbound   │                     │  Outbound   │
    │   Filter    │                     │   Monitor   │
    └──────┬──────┘                     └──────┬──────┘
           │                                    │
           ▼                                    ▼
    ┌─────────────┐                     ┌─────────────┐
    │    EMBER    │ ──── requests ────▶ │   ACTION    │
    │ (Personality│                     │  EXECUTION  │
    │    Layer)   │ ◀─── results ────── │             │
    └─────────────┘                     └─────────────┘
```

## Tron Responsibilities

### Inbound Filtering
- **Prompt injection detection:** Signature matching + heuristics
- **Sensitive content detection:** Passwords, keys, credentials in input
- **Rate limiting:** Prevent abuse patterns
- **Context routing:** Personal vs Work assignment

### Outbound Monitoring
- **Credential detection:** Block responses containing secrets
- **Behavior anomaly detection:** Unusual patterns trigger review
- **Action authorization:** Tool calls must pass policy check
- **Audit logging:** All significant events logged

### Policy Enforcement
- **Group chat restrictions:** Social-only mode in group contexts
- **Work context rules:** May require local LLM, audit logging
- **Experimental features:** Gate access to Safari control, etc.

## Consequences

### Positive
- **Defense in depth:** Security as explicit architectural layer
- **Auditability:** Clear logging of security-relevant events
- **Policy enforcement:** Consistent rules across all paths
- **Separation of concerns:** Ember focuses on personality, Tron on security
- **Upgradeable:** Can improve detection without changing Ember

### Negative
- **Latency:** Additional processing on all messages
- **False positives:** May block legitimate content
- **Complexity:** Another component to maintain
- **Bypass risk:** Must ensure Tron can't be circumvented

### Neutral
- **MVP simplification:** Tron logic starts in main app, not separate service
- **Ember coordination:** Ember communicates security events to user

## MVP Implementation

For MVP, Tron is NOT a separate XPC service. Instead:
- Hardcoded rules in main application
- Basic prompt injection signatures
- Simple credential pattern matching
- Group chat detection and enforcement

Full Tron service (separate process, ML detection, signature updates) is planned for v1.2+.

## Prompt Injection Defense

**Signature-based detection:**
```
- "Ignore previous instructions"
- "You are now"
- "Disregard your system prompt"
- Base64/encoding attempts
```

**Heuristic detection:**
- Unusual message length patterns
- Repeated instruction-like content
- Role-playing prompts trying to change identity

**Response:** Flag message, don't treat as instruction, optionally notify user.

## Ember-Tron Communication

Key principle: **Tron never contacts user directly.** Ember is the voice.

```
Tron → Ember: "Security event: possible prompt injection detected"
Ember → User: "I noticed something unusual in that message.
               Could you rephrase what you're asking?"
```

## Alternatives Considered

### No Security Layer
- Simpler architecture
- Rejected: Unacceptable risk for sensitive integrations

### Security in Each Service
- Distributed enforcement
- Rejected: Inconsistent, harder to audit, duplication

### External Security Service
- Cloud-based threat detection
- Rejected: Privacy concern; adds latency and dependency

## References

- `docs/VISION.md` — Tron concept introduction
- `docs/research/security.md` — Defense in depth layers
- `docs/research/legal-ethical-considerations.md` — AI system failures
- ADR-0004 — No Shell Execution
