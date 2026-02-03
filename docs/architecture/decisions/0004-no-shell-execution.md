# ADR-0004: No Shell/Command Execution

## Status
**Accepted**

## Date
February 2026

## Context

Many AI agent systems provide shell execution capabilities, allowing the AI to run arbitrary commands. This enables powerful automation but creates severe security risks:

- **Command injection:** Malicious prompts can execute harmful commands
- **Privilege escalation:** Shell access can bypass application sandboxing
- **Data exfiltration:** Commands can send data to external servers
- **System damage:** `rm -rf`, ransomware deployment, etc.

Moltbot and similar systems have demonstrated these risks in practice. The "too open" approach trades security for capability.

EmberHearth targets non-technical users who cannot evaluate whether a shell command is safe.

## Decision

**EmberHearth will NEVER execute shell commands or arbitrary code.**

All system interactions are through:
- **Structured Apple APIs** (EventKit, Contacts, etc.)
- **AppleScript automation** (Mail, Notes, Messages—predefined scripts only)
- **XPC services** with defined interfaces

The LLM cannot request or execute:
- Shell commands (`bash`, `zsh`, `sh`)
- Python/Node/Ruby scripts
- AppleScript beyond predefined templates
- Any form of `eval()` or dynamic code execution

## Consequences

### Positive
- **Security by design:** Entire class of attacks eliminated
- **User safety:** Non-technical users protected from harmful commands
- **Auditability:** All actions are through known, reviewable interfaces
- **App Store compatible:** No dynamic code execution
- **Trust:** Users can trust Ember won't damage their system

### Negative
- **Limited automation:** Cannot do everything a shell can
- **Predefined operations:** New capabilities require code changes
- **Power user frustration:** Technical users may want shell access
- **Integration gaps:** Some tasks only possible via shell

### Neutral
- **API coverage matters:** Value depends on Apple API capabilities
- **Future flexibility:** Could add sandboxed execution later (experimental)

## What This Means in Practice

**Ember CAN:**
- Create calendar events (via EventKit)
- Set reminders (via EventKit)
- Send messages (via AppleScript template)
- Read emails (via AppleScript)
- Fetch web content (via sandboxed web tool)
- Manage files in approved directories (via FileManager)

**Ember CANNOT:**
- Run `brew install`
- Execute `git` commands
- Run arbitrary scripts
- Modify system configuration
- Install software
- Access files outside sandbox

## Alternatives Considered

### Sandboxed Shell (Docker/VM)
- Provides shell with isolation
- Rejected for MVP: Complexity; still has escape risks; not needed for target users

### Allowlist of Safe Commands
- Permit specific commands only
- Rejected: Too easy to miss dangerous combinations; ongoing maintenance burden

### User Confirmation for Each Command
- Show command, user approves
- Rejected: Users cannot evaluate command safety; "confirm fatigue"

### Full Shell Access (Moltbot approach)
- Maximum capability
- Rejected: Unacceptable security risk for non-technical users

## Future Consideration

A future "Workbench" feature (v2+) could provide:
- Docker-based sandboxed environment
- Isolated from main system
- Explicit opt-in for technical users
- Still no access to main filesystem/credentials

This would be a separate, experimental feature—not the default.

## References

- `docs/VISION.md` — Security philosophy, Tron architecture
- `docs/research/security.md` — Defense in depth
- `docs/research/legal-ethical-considerations.md` — AI system failures
- CLAUDE.md — "Never implement shell execution"
