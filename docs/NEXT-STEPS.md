# EmberHearth: Next Steps

**Version:** 1.0  
**Date:** January 30, 2026  
**Status:** Planning  
**Related:** [VISION.md](VISION.md)

---

## Overview

This document captures the concrete next steps for developing EmberHearth, organized into phases. Each phase builds on the previous, with clear deliverables and research questions to answer.

---

## Phase 0: Project Setup

### GitHub Repository

- [ ] Create new GitHub repository (name TBD - avoid Apple trademarks)
- [ ] Initialize with MIT or Apache 2.0 license
- [ ] Move MACBOT-VISION.md to `docs/VISION.md`
- [ ] Move this file to `docs/NEXT-STEPS.md`
- [ ] Create initial README with project overview
- [ ] Set up basic directory structure:

```
emberhearth/                      # or chosen name
├── README.md                # Project overview, quick start
├── LICENSE                  # MIT or Apache 2.0
├── CLAUDE.md               # Instructions for Claude Code
├── docs/
│   ├── VISION.md           # The vision document
│   ├── NEXT-STEPS.md       # This document
│   └── research/           # Research notes
│       ├── imessage.md     # iMessage integration research
│       ├── macos-apis.md   # Apple API exploration
│       ├── local-models.md # Local LLM research
│       └── security.md     # Security primitives research
├── src/                    # Source code
│   └── .gitkeep
├── tests/                  # Test files
│   └── .gitkeep
└── .github/
    └── FUNDING.yml         # Optional: sponsorship
```

### Development Environment

- [ ] Decide on primary language: Swift (native) vs TypeScript (cross-platform tooling)
- [ ] Set up Xcode project (if Swift)
- [ ] Configure Claude Code access to repository
- [ ] Create CLAUDE.md with project-specific instructions

---

## Phase 1: Research (Can Be Done on Mobile)

*These tasks are ideal for Claude Code mobile or conversational Claude. They're about gathering information and documenting findings.*

### 1.1 iMessage Integration Research

**Goal:** Understand the viable approaches for sending/receiving iMessages programmatically.

**Research Questions:**
- [ ] How does Messages.app automation work via AppleScript?
- [ ] What are the sandboxing implications for accessing Messages?
- [ ] Are there documented approaches using Swift/MessageKit?
- [ ] What private APIs exist and what are the risks of using them?
- [ ] How do existing projects (if any) handle this?

**Deliverable:** `docs/research/imessage.md` with findings and recommendation

### 1.2 macOS Security Primitives

**Goal:** Understand what macOS provides for secure app architecture.

**Research Questions:**
- [ ] App Sandbox: What can and cannot be sandboxed?
- [ ] Entitlements: Which entitlements are needed for various capabilities?
- [ ] XPC Services: How to use XPC for process isolation?
- [ ] Keychain Services: API for secure credential storage/retrieval
- [ ] Code signing and notarization requirements

**Deliverable:** `docs/research/security.md` with findings

### 1.3 Apple API Exploration

**Goal:** Catalog what's available through Apple's frameworks for the MCP server.

**Starting Point:** https://developer.apple.com/documentation

**Frameworks to Explore:**
- [ ] EventKit (Calendar, Reminders)
- [ ] Contacts framework
- [ ] MailKit / Mail.app scripting
- [ ] Notes (is there an API?)
- [ ] Safari/WebKit (bookmarks, reading list)
- [ ] HomeKit (smart home control)
- [ ] Shortcuts/Automator integration

**Deliverable:** `docs/research/macos-apis.md` with capability matrix

### 1.4 Local Model Feasibility

**Goal:** Determine if local models can handle assistant tasks acceptably.

**Research Questions:**
- [ ] What models run well on Apple Silicon (M1/M2/M4)?
- [ ] MLX vs llama.cpp vs Ollama performance comparison
- [ ] What's the latency for a typical assistant query?
- [ ] Can a Mac Mini M2 (base) run useful models?
- [ ] What quantization levels are practical?

**Deliverable:** `docs/research/local-models.md` with benchmarks and recommendations

---

## Phase 2: First Prototype

*Build the simplest possible vertical slice to prove the foundation works.*

### 2.1 Minimal Mac App Shell

**Goal:** A native macOS app that can receive text input and display responses.

**Requirements:**
- [ ] SwiftUI Mac app
- [ ] Simple chat interface (text input, message history)
- [ ] Proper app signing for development
- [ ] Basic sandboxing configured

**Not included yet:** iMessage, memory, security layers

### 2.2 LLM Provider Integration

**Goal:** Connect to a single LLM provider and get responses.

**Requirements:**
- [ ] API key storage in Keychain
- [ ] Claude API integration (or OpenAI)
- [ ] Basic error handling (rate limits, network errors)
- [ ] Response streaming to UI

### 2.3 Proof of Concept

**Goal:** End-to-end flow working.

```
User types in app → App calls LLM API → Response displays in app
```

**Success Criteria:**
- [ ] Can have a basic conversation
- [ ] API key never appears in logs or UI
- [ ] App runs reliably for extended periods
- [ ] Errors are handled gracefully

---

## Phase 3: Core Architecture

*Build out the key architectural components.*

### 3.1 MCP Server Foundation

**Goal:** Implement the Mac MCP server with initial structured operations.

**Initial Operations:**
- [ ] Calendar: List events, create events
- [ ] Reminders: List reminders, create reminders
- [ ] Files: Read/write to sandboxed locations
- [ ] Notifications: Send system notifications

### 3.2 Tron Foundation

**Goal:** Basic prompt injection filtering.

**Requirements:**
- [ ] Signature-based detection (known attack patterns)
- [ ] Inbound content scanning
- [ ] Outbound response validation
- [ ] Logging of detections

### 3.3 iMessage Integration

**Goal:** Send and receive messages via iMessage.

**Requirements:**
- [ ] Receive incoming messages
- [ ] Send outgoing responses
- [ ] Handle message threading
- [ ] Graceful handling of unsupported message types (images, etc.)

---

## Phase 4: Memory System

*Implement the personal knowledge store.*

### 4.1 Storage Architecture

**Goal:** Implement the SQLite-based memory system.

**Requirements:**
- [ ] Schema implementation (interactions, knowledge, events)
- [ ] Vector embeddings storage
- [ ] Encryption layer
- [ ] Temporal linking

### 4.2 Automatic Memory

**Goal:** Extract and store knowledge without explicit user instruction.

**Requirements:**
- [ ] Fact extraction from conversations
- [ ] Privacy level classification
- [ ] Temporal association building
- [ ] Retrieval engine

### 4.3 Consolidation Cycle

**Goal:** Background processing for memory optimization.

**Requirements:**
- [ ] Scheduled consolidation (overnight)
- [ ] Emotional encoding (if implemented)
- [ ] Pattern detection
- [ ] Graceful handling of interruptions

---

## Phase 5: Polish and Hardening

*Production readiness.*

### 5.1 Error Handling

- [ ] All error scenarios handled gracefully
- [ ] Clear user messaging for common issues
- [ ] Automatic recovery where possible
- [ ] Logging for diagnostics

### 5.2 Backup System

- [ ] iCloud storage integration
- [ ] Automated backups
- [ ] Point-in-time restore capability

### 5.3 Accessibility

- [ ] VoiceOver support throughout
- [ ] Dynamic Type support
- [ ] Keyboard navigation
- [ ] High contrast support

### 5.4 Security Hardening

- [ ] Penetration testing
- [ ] Tron ML component (if viable)
- [ ] Security audit
- [ ] Documentation of security model

---

## Phase 6: Launch Preparation

### 6.1 Documentation

- [ ] User documentation
- [ ] Developer documentation
- [ ] Security documentation for non-technical users

### 6.2 Distribution

- [ ] Decide: Mac App Store vs direct download vs both
- [ ] Code signing for distribution
- [ ] Notarization
- [ ] Update mechanism

### 6.3 Open Source

- [ ] Clean up codebase for public release
- [ ] Contribution guidelines
- [ ] Community signature database setup
- [ ] Issue templates

---

## Mobile Development Workflow

*Using Claude Code on iOS for EmberHearth development.*

### Setup

1. **Install Claude iOS app** with Pro/Max subscription
2. **Go to Code section** in the app
3. **Connect GitHub account** when prompted
4. **Authorize repository access** for the EmberHearth repo

### Effective Mobile Workflow

**Good for mobile:**
- Research tasks (exploring Apple docs, reading code)
- Writing documentation
- Small, well-defined code changes
- Bug fixes with clear scope
- Code review and refactoring
- Creating issues and PRs

**Better on desktop:**
- Large architectural changes
- Complex debugging sessions
- Running and testing builds
- Xcode-specific tasks

### Tips for Mobile Development

1. **Use Projects** to maintain context across sessions
2. **Be specific** in task descriptions - Claude works better with clear scope
3. **Review PRs carefully** before merging - mobile preview can be limited
4. **Chunk large tasks** into smaller, mergeable pieces
5. **Use the queue** - kick off multiple tasks and review later

---

## Open Items

### Naming

The project needs a legally defensible name that:
- Doesn't reference Mac, Apple, or related trademarks
- Stands on its own
- Conveys helpfulness
- Is memorable

**Candidates to consider:** (TBD)

### License Decision

- **MIT**: Simple, permissive, widely understood
- **Apache 2.0**: Includes patent protection

**Recommendation:** MIT for simplicity unless patent concerns arise

---

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 0: Setup | Not Started | |
| Phase 1: Research | Not Started | Can begin on mobile |
| Phase 2: Prototype | Not Started | |
| Phase 3: Architecture | Not Started | |
| Phase 4: Memory | Not Started | |
| Phase 5: Polish | Not Started | |
| Phase 6: Launch | Not Started | |

---

*This document will be updated as work progresses.*
