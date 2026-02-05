# EmberHearth - Claude Code Instructions

This file provides context and instructions for Claude Code when working on this repository.

## Project Overview

EmberHearth is a secure, accessible, always-on personal AI assistant for macOS. The primary interface is iMessage, with a native Mac app for configuration.

**Quick Navigation:**
- `README.md` — Full documentation index with links to all docs
- `docs/VISION.md` — Vision, architecture, design philosophy
- `docs/NEXT-STEPS.md` — Development roadmap and current tasks
- `docs/architecture-overview.md` — System design and components
- `docs/research/README.md` — Index of all research documents

## Project Structure

```
emberhearth/
├── README.md               # Project overview + DOCUMENTATION INDEX
├── CLAUDE.md               # This file - instructions for Claude
├── docs/
│   ├── VISION.md           # Vision document
│   ├── NEXT-STEPS.md       # Roadmap and tasks
│   ├── architecture-overview.md
│   ├── architecture/
│   │   └── decisions/      # ADRs (0001-0011+)
│   ├── releases/           # MVP.md, mvp-scope.md, feature-matrix.md
│   ├── specs/              # Implementation specifications
│   ├── research/           # Research findings (see README.md inside)
│   │   ├── README.md       # INDEX of all research docs
│   │   └── integrations/   # Apple app integration research
│   ├── reference/          # Analysis, sanity checks, guides
│   ├── deployment/         # Build and release docs
│   └── testing/            # Testing strategy
├── src/                    # Source code (Swift/SwiftUI)
├── tests/                  # Test files
└── .github/                # GitHub configuration
```

**Finding Documentation:**
1. Start at `README.md` for the master index
2. For research topics, check `docs/research/README.md`
3. For architectural decisions, see `docs/architecture/decisions/README.md`

## Core Principles (Always Follow)

1. **Security First** — Never implement shell execution. Use structured operations only.
2. **Accessibility** — All UI must support VoiceOver, Dynamic Type, keyboard navigation.
3. **Apple Quality** — Follow Human Interface Guidelines. Native feel, not web wrapper.
4. **Privacy** — All personal data stays local. No cloud sync of user memories.
5. **Simplicity** — If it requires explanation to non-technical users, simplify it.

## Naming Conventions

- **Product name:** EmberHearth (display) or `emberhearth` (code/paths)
- **Swift:** Follow Apple's Swift style guide
- **Files:** lowercase with hyphens for docs, PascalCase for Swift files

## Current Phase

**Phase 1: Research** — We're exploring:
- iMessage integration approaches
- macOS security primitives (sandbox, XPC, Keychain)
- Apple framework capabilities (EventKit, HomeKit, etc.)
- Local model feasibility

Research findings go in `docs/research/`.

## When Making Changes

1. **Read the vision first** — Understand why before implementing what
2. **Small, focused commits** — One logical change per commit
3. **Update docs** — Keep NEXT-STEPS.md progress tracking current
4. **Test accessibility** — VoiceOver should work on all UI

## Key Technical Decisions

- **Language:** Swift + SwiftUI (native macOS)
- **Primary Interface:** iMessage (inherits Apple accessibility)
- **Secondary Interface:** Native Mac app (configuration/admin)
- **Memory Storage:** SQLite with encryption
- **LLM Integration:** API-based initially, local model support planned

## Security Boundaries

**Never do:**
- Shell/command execution
- Expose credentials in logs or UI
- Send personal data to external services (except chosen LLM provider)
- Store API keys in plaintext

**Always do:**
- Use Keychain for secrets
- Validate all inputs
- Log security-relevant events
- Sandbox file access to approved locations

## Questions?

If unclear about direction, check:
1. `docs/VISION.md` — For philosophy and architecture
2. `docs/NEXT-STEPS.md` — For current priorities
3. Ask the user — When in doubt, clarify before implementing
