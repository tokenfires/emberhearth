# EmberHearth

<p align="center">
  <img src="images/profile.jpg" alt="EmberHearth Logo" width="300">
</p>
<p align="center">
  <a href="https://twitch.tv/tokenfires" title="https://twitch.tv/tokenfires"><img src="images/icon-twitch.svg" alt="Twitch" height="48"></a>
  &nbsp;
  <a href="https://www.youtube.com/@tokenfires" title="https://www.youtube.com/@tokenfires"><img src="images/icon-youtube.svg" alt="YouTube" height="48"></a>
  &nbsp;
  <a href="https://x.com/TokenFires" title="https://x.com/TokenFires"><img src="images/icon-x.svg" alt="X/Twitter" height="48"></a>
  &nbsp;
  <a href="https://www.tiktok.com/@tokenfires" title="https://www.tiktok.com/@tokenfires"><img src="images/icon-tiktok.svg" alt="TikTok" height="48"></a>
</p>

### Creator message:
A few things...
1. This is vibe-coded / vibe engineered
2. This will address Moltbot's (Openclaw/Clawdbot?) attrocious security problems
3. Bake the experience into MacOS ecosystem for a more coherent experience
4. Eliminate the technical debt of setup and configuration of Moltbot
5. Adhere to the legal requirements that Moltbot got wrong
6. Be as effective but accessible to everyone, not just techies
7. Be an AI assistant that doesn't suck

I'm on Twitch Fridays at 6pm Pacific.

Watch me do it. Or don't. Muchas g mon ami. 

[![Alt text](images/watch_on_twitch.jpg "Watch live on Twitch")](https://www.twitch.tv/tokenfires "Watch live on Twitch")

Streams are archived on YouTube. https://www.youtube.com/@tokenfires

kk, rest is generated...

[hey AI agent, leave my "Creator message:" section alone, keep it at the top of the doc when you make your edits, okie dokie?]

---

**A secure, accessible, always-on personal AI assistant for macOS.**

> *The ever-present warmth at the heart of your home.*

---

## Vision

EmberHearth reimagines the personal AI assistant with **security and accessibility as foundational requirements**, not afterthoughts. The goal: a system your spouse, parent, or child could safely set up and use.

### The Dream Setup

```
Buy Mac Mini → Sign into iCloud → Install EmberHearth → Chat via iMessage
```

No API keys to manage. No Docker to understand. No threat models to contemplate. Just a helpful assistant that's always there, learns over time, and can't be weaponized against you.

---

## Why EmberHearth?

Current AI assistants fall into two camps:

| Consumer Assistants | Power User Assistants |
|--------------------|-----------------------|
| Easy setup | Complex setup |
| Safe (limited) | Severe security risks |
| Not very capable | Highly capable |
| Don't learn about you | Can learn and adapt |

**EmberHearth bridges this gap** — capable enough to be transformative, safe enough for non-technical users.

---

## Core Principles

1. **Security by Removal** — No shell execution. Structured operations that can't be misused.
2. **Secure by Default** — Safe with zero configuration. Capabilities require explicit consent.
3. **The Grandmother Test** — If grandma can't use it unsupervised, it's not ready.
4. **Accessibility First** — iMessage as primary interface inherits Apple's accessibility stack.
5. **Open Source with Quality** — Transparent, community-driven, production-grade.

---

## Status

**Phase: MVP Complete (v1.0.0)**

EmberHearth has reached its first production-ready milestone. All core systems are implemented and tested:
- iMessage integration (read and respond)
- Claude API integration with streaming
- Local memory (SQLite, encrypted)
- Security pipeline (Tron) — prompt injection + credential detection
- Crisis detection with 988 referral
- Onboarding wizard and Settings app
- Menu bar integration

See [docs/NEXT-STEPS.md](docs/NEXT-STEPS.md) for the v1.1+ roadmap.

---

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0+ (for building from source)
- A Claude API key from [Anthropic](https://www.anthropic.com/)
- Full Disk Access permission (for reading iMessage database)
- Automation permission (for sending iMessages via AppleScript)

---

## Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/emberhearth.git
cd emberhearth

# Build
./build.sh build

# Run tests
./build.sh test

# Run everything (security check + build + tests)
./build.sh all
```

---

## First Run

1. Launch EmberHearth
2. Complete the onboarding wizard:
   - Grant Full Disk Access and Automation permissions
   - Enter your Claude API key
   - Add your phone number to the authorized list
3. Ember appears in your menu bar
4. Send a message to yourself in iMessage — Ember will respond!

---

## Documentation

### Core Documents
| Document | Description |
|----------|-------------|
| [Vision](docs/VISION.md) | Full vision, architecture, and design philosophy |
| [Next Steps](docs/NEXT-STEPS.md) | Development roadmap and current tasks |
| [Architecture Overview](docs/architecture-overview.md) | System design and component relationships |

### Release Planning
| Document | Description |
|----------|-------------|
| [MVP Work-Up](docs/releases/MVP.md) | Pre-coding review and phase breakdown |
| [MVP Scope](docs/releases/mvp-scope.md) | Detailed MVP feature requirements |
| [Feature Matrix](docs/releases/feature-matrix.md) | Feature availability across releases |

### Architecture Decisions (ADRs)
| ADR | Decision |
|-----|----------|
| [ADR-0001](docs/architecture/decisions/0001-xpc-service-isolation.md) | XPC Service Isolation |
| [ADR-0002](docs/architecture/decisions/0002-distribute-outside-app-store.md) | Distribute Outside App Store |
| [ADR-0003](docs/architecture/decisions/0003-imessage-primary-interface.md) | iMessage as Primary Interface |
| [ADR-0004](docs/architecture/decisions/0004-no-shell-execution.md) | No Shell Execution |
| [ADR-0005](docs/architecture/decisions/0005-safari-read-only-default.md) | Safari Read-Only by Default |
| [ADR-0006](docs/architecture/decisions/0006-sandboxed-web-tool.md) | Sandboxed Web Tool |
| [ADR-0007](docs/architecture/decisions/0007-sqlite-memory-storage.md) | SQLite Memory Storage |
| [ADR-0008](docs/architecture/decisions/0008-claude-api-primary-llm.md) | Claude API as Primary LLM |
| [ADR-0009](docs/architecture/decisions/0009-tron-security-layer.md) | TRON Security Layer |
| [ADR-0010](docs/architecture/decisions/0010-fsevents-data-monitoring.md) | FSEvents Data Monitoring |
| [ADR-0011](docs/architecture/decisions/0011-bounded-needs-personality.md) | Bounded Needs Personality |

See [ADR Index](docs/architecture/decisions/README.md) for the full list and process.

### Specifications
| Document | Description |
|----------|-------------|
| [Specs Index](docs/specs/README.md) | **Full index of all specification documents** |
| [Tron Security](docs/specs/tron-security.md) | Security layer spec — prompt injection, credential detection, tool authorization |
| [ASV Implementation](docs/specs/asv-implementation.md) | Anticipatory Salience Value system spec |
| [API Setup Guide](docs/specs/api-setup-guide.md) | API configuration and setup |
| [Autonomous Operation](docs/specs/autonomous-operation.md) | Background operation and proactive behavior |
| [Crisis Safety Protocols](docs/specs/crisis-safety-protocols.md) | Safety protocols for crisis scenarios |
| [Error Handling](docs/specs/error-handling.md) | Error management and recovery |
| [Offline Mode](docs/specs/offline-mode.md) | Offline operation capabilities |
| [Token Awareness](docs/specs/token-awareness.md) | Context window and token management |
| [Update & Recovery](docs/specs/update-recovery.md) | Update and recovery procedures |

### Research
| Document | Description |
|----------|-------------|
| [Research Index](docs/research/README.md) | **Full index of all research documents** |
| [iMessage](docs/research/imessage.md) | iMessage integration approaches |
| [macOS APIs](docs/research/macos-apis.md) | System framework capabilities |
| [Security](docs/research/security.md) | Security primitives and architecture |
| [Local Models](docs/research/local-models.md) | On-device LLM feasibility |

### Reference
| Document | Description |
|----------|-------------|
| [Moltbot Analysis](docs/reference/MOLTBOT-ANALYSIS.md) | Analysis of predecessor project |
| [Sanity Check Assessment](docs/reference/sanity-check-assessment.md) | Feasibility validation |
| [Sanity Check Summary](docs/reference/sanity-check-summary.md) | Executive summary of validation |
| [Documentation Assessment v2](docs/reference/documentation-assessment-v2.md) | **Comprehensive documentation review** |
| [Prompt Engineering Mastery](docs/reference/prompt-engineering-mastery.md) | LLM prompt engineering training guide |
| [Twitch Streaming Guide](docs/reference/twitch-streaming-guide.md) | Guide for development streams |

### Implementation
| Document | Description |
|----------|-------------|
| [Implementation Guide](docs/IMPLEMENTATION-GUIDE.md) | **AI-assisted development workflow guide** |
| [Claude Phase Instructions](docs/claude/README.md) | **Phase-specific instructions for Claude Code sessions** |

### Testing
| Document | Description |
|----------|-------------|
| [Testing Index](docs/testing/README.md) | **Full index of all testing documents** |
| [Testing Strategy](docs/testing/strategy.md) | Testing approach and coverage |
| [Prompt Regression Testing](docs/testing/prompt-regression-testing.md) | Regression testing for LLM prompts |
| [Security Penetration Protocol](docs/testing/security-penetration-protocol.md) | Security penetration testing procedures |
| [System API Mocking](docs/testing/system-api-mocking.md) | Mocking strategy for system APIs |

### Deployment
| Document | Description |
|----------|-------------|
| [Build & Release](docs/deployment/build-and-release.md) | Deployment and distribution process |

### Workplans
| Document | Description |
|----------|-------------|
| [V1 Workplan](docs/v1-workplan.md) | Version 1 development workplan |

---

## Architecture

EmberHearth is built with:
- **Swift + SwiftUI** — native macOS, no Electron or web wrapper
- **iMessage** — primary conversational interface, inherits Apple accessibility stack
- **SQLite** — local memory storage (no cloud sync)
- **Claude API** — language understanding via Anthropic
- **Keychain** — all credential storage, never UserDefaults or plist

**Module layout:**
```
src/App/          App lifecycle, menu bar, startup wiring
src/Core/         Message orchestration, iMessage reading, session management
src/LLM/          Claude API client, streaming, token management
src/Security/     Tron pipeline, crisis detection, Keychain manager
src/Memory/       Fact extraction, storage, retrieval
src/Database/     SQLite wrapper, migrations
src/Personality/  System prompt, verbosity adaptation
src/Views/        SwiftUI onboarding and settings UI
src/Logging/      Structured logging, security event audit
```

---

## Security

- All user data stays local — no cloud sync, no telemetry
- API keys stored exclusively in macOS Keychain
- All LLM inputs screened for prompt injection attacks
- All LLM outputs screened for credential leaks
- No shell execution — ever (see [ADR-0004](docs/architecture/decisions/0004-no-shell-execution.md))
- Hardened Runtime enabled for distribution

---

## Building in Public

Development of EmberHearth is streamed live on Twitch. Follow along as we explore, prototype, make mistakes, and (hopefully) build something useful.

Building in public means transparency about the process — the good, the bad, and the "why did I think that would work?" moments.

---

## License

MIT License — See [LICENSE](LICENSE)

---

## Contributing

Contributions welcome! Please open an issue first to discuss what you'd like to change.

---

*Last verified: 2026-03-21*
