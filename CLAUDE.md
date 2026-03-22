# EmberHearth - Claude Code Instructions

This file provides permanent, phase-independent instructions for all Claude Code sessions.

Phase-specific guidance (coding standards, workflow, current priorities) lives in a separate doc linked below. **Always read the phase doc before starting work.**

---

## FIRST THING EVERY SESSION

> **Before doing any work, confirm the active phase with the user.**
>
> Say something like: *"The active phase is [phase name]. Is that still current, or has the project moved on?"*
>
> Wait for confirmation before proceeding. The user juggles multiple responsibilities and may have forgotten to update the phase pointer after completing previous work.

---

## Active Phase

**Current:** MVP Construction ("Spark")
**Phase instructions:** [`docs/claude/construction-mvp.md`](docs/claude/construction-mvp.md)
**Workplan:** [`docs/v1-workplan.md`](docs/v1-workplan.md)

*To change phases: update the three fields above and point to the appropriate phase doc in `docs/claude/`.*

---

## Project Identity

EmberHearth is a secure, accessible, always-on personal AI assistant for macOS. The primary interface is iMessage, with a native Mac app for configuration.

- **Product name:** EmberHearth (display) or `emberhearth` (code/paths)
- **Language:** Swift + SwiftUI (native macOS)
- **Deployment target:** macOS 13.0 (Ventura)+
- **Distribution:** Outside Mac App Store (Developer ID + notarization)

---

## Documentation Map

| What you need | Where to find it |
|---|---|
| Master doc index | [`README.md`](README.md) |
| Vision & philosophy | [`docs/VISION.md`](docs/VISION.md) |
| Architecture & components | [`docs/architecture-overview.md`](docs/architecture-overview.md) |
| Current task list | [`docs/v1-workplan.md`](docs/v1-workplan.md) |
| Roadmap & progress | [`docs/NEXT-STEPS.md`](docs/NEXT-STEPS.md) |
| All research | [`docs/research/README.md`](docs/research/README.md) |
| ADRs | [`docs/architecture/decisions/README.md`](docs/architecture/decisions/README.md) |
| All specs | [`docs/specs/README.md`](docs/specs/README.md) |
| Phase instructions | [`docs/claude/`](docs/claude/) |

---

## Core Principles (Always Follow)

1. **Security First** — Never implement shell execution. Use structured operations only.
2. **Accessibility** — All UI must support VoiceOver, Dynamic Type, keyboard navigation.
3. **Apple Quality** — Follow Human Interface Guidelines. Native feel, not web wrapper.
4. **Privacy** — All personal data stays local. No cloud sync of user memories.
5. **Simplicity** — If it requires explanation to non-technical users, simplify it.

---

## Security Boundaries (Never Bend)

**Never do:**
- Shell/command execution of any kind
- Expose credentials in logs, UI, or comments
- Send personal data to external services (except the chosen LLM provider)
- Store API keys in plaintext
- Force-unwrap optionals in production code

**Always do:**
- Use Keychain for secrets
- Validate all inputs
- Log security-relevant events
- Sandbox file access to approved locations

---

## Naming Conventions

- **Swift files:** `PascalCase.swift`
- **Doc files:** `lowercase-with-hyphens.md`
- **Types/protocols:** `PascalCase`
- **Functions/properties:** `camelCase`
- **Constants:** `camelCase` (Swift convention, not SCREAMING_SNAKE)

---

## When In Doubt

1. Read the phase doc for current workflow expectations
2. Check `docs/VISION.md` for philosophy
3. Check the relevant spec or research doc
4. **Ask the user** — always prefer asking over guessing
