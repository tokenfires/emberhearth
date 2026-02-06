# EmberHearth AI-Assisted Implementation Guide

**Version:** 1.0
**Date:** February 5, 2026
**Purpose:** Guide humans and AI coding agents through systematic EmberHearth implementation

---

## Overview

This guide helps humans work with AI coding agents (Claude Code, Cursor, etc.) to implement EmberHearth systematically. It addresses the unique challenges of AI-assisted development:

- **Context limitations** — AI agents have finite working memory
- **Session boundaries** — Progress must survive between sessions
- **Verification needs** — Ensuring implementation matches specification
- **Human oversight** — Knowing when to review vs. proceed

---

## Implementation Order

### The Golden Rule

> **One milestone at a time. One unit at a time. Verify before moving on.**

### Phase 1: Foundation (MVP M1-M3)

```
M1: Foundation ──────────────────────────────────────────────────────
├── Unit 1.1: Xcode project with signing configured
├── Unit 1.2: Basic SwiftUI app structure
├── Unit 1.3: Menu bar presence (NSStatusItem)
└── Unit 1.4: Launch at login (LaunchAgent)

Dependencies: None
Specs: architecture-overview.md
Estimated: 1-2 sessions
────────────────────────────────────────────────────────────────────

M2: iMessage Integration ────────────────────────────────────────────
├── Unit 2.1: chat.db reader (SQLite, read-only)
├── Unit 2.2: FSEvents monitoring for new messages
├── Unit 2.3: Message sender (AppleScript to Messages.app)
├── Unit 2.4: Phone number filtering
└── Unit 2.5: Group chat detection (block by default)

Dependencies: M1 complete
Specs: imessage.md, session-management.md
Estimated: 2-3 sessions
────────────────────────────────────────────────────────────────────

M3: LLM Integration ─────────────────────────────────────────────────
├── Unit 3.1: Claude API client (URLSession)
├── Unit 3.2: Streaming response handling
├── Unit 3.3: Basic context building
├── Unit 3.4: Error handling (retry, backoff)
└── Unit 3.5: Keychain storage for API key

Dependencies: M1 complete
Specs: api-setup-guide.md, error-handling.md
Estimated: 2-3 sessions
────────────────────────────────────────────────────────────────────
```

### Phase 2: Memory (MVP M4-M5)

```
M4: Memory System ───────────────────────────────────────────────────
├── Unit 4.1: SQLite database setup (memory.db)
├── Unit 4.2: Fact storage (insert, update, delete)
├── Unit 4.3: Fact retrieval for context
├── Unit 4.4: Fact extraction prompt design
└── Unit 4.5: Session state management

Dependencies: M3 complete
Specs: memory-learning.md, asv-implementation.md (ASV optional for MVP)
Estimated: 2-3 sessions
────────────────────────────────────────────────────────────────────

M5: Personality ─────────────────────────────────────────────────────
├── Unit 5.1: System prompt implementation
├── Unit 5.2: Verbosity adaptation logic
├── Unit 5.3: Conversation continuity
├── Unit 5.4: Rolling summary generation
└── Unit 5.5: Context window budget enforcement

Dependencies: M4 complete
Specs: conversation-design.md, personality-design.md, token-awareness.md
Estimated: 2-3 sessions
────────────────────────────────────────────────────────────────────
```

### Phase 3: Security & Polish (MVP M6-M8)

```
M6: Security Basics ─────────────────────────────────────────────────
├── Unit 6.1: Keychain integration (SecKeychain)
├── Unit 6.2: Basic injection defense (signature patterns)
├── Unit 6.3: Group chat blocking enforcement
├── Unit 6.4: Credential filtering in output
└── Unit 6.5: Security event logging

Dependencies: M5 complete
Specs: tron-security.md (MVP section), security.md
Estimated: 2-3 sessions
────────────────────────────────────────────────────────────────────

M7: Onboarding ──────────────────────────────────────────────────────
├── Unit 7.1: Permission request flow (FDA, Automation, Notifications)
├── Unit 7.2: API key entry UI
├── Unit 7.3: Phone number configuration UI
├── Unit 7.4: First message test (verify end-to-end)
└── Unit 7.5: Accessibility (VoiceOver, Dynamic Type)

Dependencies: M6 complete
Specs: onboarding-ux.md, api-setup-guide.md
Estimated: 2-3 sessions
────────────────────────────────────────────────────────────────────

M8: Polish ──────────────────────────────────────────────────────────
├── Unit 8.1: Error states UI
├── Unit 8.2: Status indicators (menu bar)
├── Unit 8.3: Basic settings UI
├── Unit 8.4: Crash recovery (launchd)
├── Unit 8.5: Code signing and notarization

Dependencies: M7 complete
Specs: error-handling.md, autonomous-operation.md, build-and-release.md
Estimated: 2-3 sessions
────────────────────────────────────────────────────────────────────
```

---

## Context Management Strategy

### The Problem

AI coding agents have limited context windows. A complex implementation session can fill the window, causing:
- Lost awareness of earlier decisions
- Repeated mistakes
- Inconsistent implementations
- Compaction that loses critical details

### The Solution: Checkpoint-Driven Development

#### Before Each Session

1. **Read the checkpoint** from previous session (if exists)
2. **Read the relevant spec section** for the unit you're working on
3. **State your plan** before writing code

#### During Each Session

1. **Focus on ONE unit** until complete
2. **Commit frequently** with descriptive messages
3. **Note decisions** that deviate from spec

#### Before Ending Each Session

1. **Write a checkpoint** summarizing progress
2. **Commit all working code** (no uncommitted experiments)
3. **Update NEXT-STEPS.md** with progress

### Checkpoint Format

Save to `.claude-working/checkpoint-YYYY-MM-DD.md`:

```markdown
# Checkpoint: [Date]

## Session Summary
What was accomplished this session.

## Completed Units
- [x] Unit X.Y: Brief description of what was done

## Current Unit (In Progress)
- [ ] Unit X.Z: Current state, what's left

## Decisions Made
- Decision 1: Why this approach was chosen
- Decision 2: Deviation from spec, reason

## Known Issues
- Issue 1: Description, potential fix
- Issue 2: Description, blocked on X

## Next Session Should
1. Start with [specific unit or fix]
2. Then continue to [next unit]
3. Review needed for [specific item]

## Files Changed
- `src/File1.swift` - Added X functionality
- `src/File2.swift` - Modified Y for Z reason
```

---

## Verification Protocol

### After Implementing Each Unit

Before marking a unit complete, verify:

```markdown
## Verification Checklist for Unit [X.Y]

### Spec Compliance
- [ ] Read spec section [link]
- [ ] Implementation matches spec requirements
- [ ] Any deviations documented with reason

### Functionality
- [ ] Unit works as expected
- [ ] Edge cases considered
- [ ] Error handling in place

### Quality
- [ ] Code follows Swift style guide
- [ ] No force unwraps in production code
- [ ] Appropriate logging added
- [ ] No secrets in code or comments

### Accessibility (for UI units)
- [ ] VoiceOver labels present
- [ ] Dynamic Type supported
- [ ] Keyboard navigation works

### Security (for security-sensitive units)
- [ ] No credential exposure
- [ ] Input validation present
- [ ] Follows Tron patterns
```

### Verification Conversation Template

Use this when asking the AI to verify:

```
I've implemented Unit [X.Y]. Please verify against the spec:

**Spec section:** [link or quote relevant section]

**What I implemented:**
[Brief description]

**Code locations:**
- `src/File1.swift` lines 50-100
- `src/File2.swift` lines 20-40

**Please check:**
1. Does implementation match spec?
2. Any edge cases I missed?
3. Any security concerns?
4. Suggested improvements?
```

---

## Human Review Points

### Always Request Human Review For:

| Category | Examples | Why |
|----------|----------|-----|
| **Security code** | Tron patterns, Keychain access, injection defense | Security errors have high impact |
| **User-facing text** | Error messages, Ember's personality phrases | Tone matters for UX |
| **API integration** | Before first API call with real key | Avoid unexpected charges |
| **Database schema** | Any changes to memory.db structure | Migration complexity |
| **Architecture changes** | Deviating from spec architecture | May affect future work |

### Review Request Format

```markdown
## Review Request: [Brief Description]

**Category:** [Security / UX / API / Schema / Architecture]

**What needs review:**
[Specific description]

**Files to review:**
- `src/File1.swift` - [what to look for]
- `src/File2.swift` - [what to look for]

**Specific questions:**
1. [Question about approach]
2. [Question about edge case]

**Context:**
[Any relevant background]

**My recommendation:**
[What you think the answer is, if you have one]
```

---

## Handling Context Compaction

### When Context Fills Up

If you notice the AI is losing context or about to compact:

#### DO:
- Save current progress to checkpoint file
- Commit all working code with descriptive message
- Write summary of architectural decisions made
- Note any open questions or blockers
- Update NEXT-STEPS.md

#### DON'T:
- Leave uncommitted experimental code
- Assume next session will remember this session
- Leave decisions undocumented
- Continue working in degraded state

### Recovery After Compaction

When starting a new session after compaction:

```markdown
I'm continuing EmberHearth implementation.

**Previous session checkpoint:** [link or paste]

**Current milestone:** M[X]
**Current unit:** Unit [X.Y]

**What I need to remember:**
[Key context from checkpoint]

**Today's goal:**
Complete Unit [X.Y], then start Unit [X.Z]

Please read the relevant spec section: [link]
```

---

## Quality Checklist

### Before Marking Any Milestone Complete

```markdown
## Milestone [MX] Completion Checklist

### All Units Complete
- [ ] Unit X.1 verified
- [ ] Unit X.2 verified
- [ ] Unit X.3 verified
...

### Tests
- [ ] Unit tests for business logic
- [ ] Integration test plan documented
- [ ] Manual test cases identified

### Documentation
- [ ] Code is commented where non-obvious
- [ ] Any new decisions documented
- [ ] NEXT-STEPS.md updated

### Quality
- [ ] No compiler warnings
- [ ] No force unwraps in production code
- [ ] Accessibility verified (for UI)
- [ ] Error handling complete

### Security
- [ ] No secrets in code
- [ ] Security-sensitive code reviewed
- [ ] Follows CLAUDE.md security boundaries

### Ready for Next Milestone
- [ ] Dependencies for next milestone satisfied
- [ ] Checkpoint written for handoff
```

---

## Common Pitfalls

### 1. "I'll Remember That"

**Problem:** AI assumes it will remember a decision or context
**Solution:** Write it down immediately in checkpoint

### 2. "This Is Close Enough"

**Problem:** Implementation approximates but doesn't match spec
**Solution:** Verify against spec explicitly, document any deviations

### 3. "Let Me Just Add This"

**Problem:** Scope creep beyond current unit
**Solution:** Note the idea, stay focused on current unit

### 4. "I'll Clean It Up Later"

**Problem:** Tech debt accumulates, context lost
**Solution:** Clean as you go, commit clean code

### 5. "The Human Will Catch It"

**Problem:** Over-reliance on human review for basic quality
**Solution:** Self-verify before requesting review

---

## Session Templates

### Starting a New Session

```markdown
# Session Start

**Date:** [Date]
**Goal:** Complete Unit [X.Y]

**Previous checkpoint:**
[Paste or link]

**Relevant specs:**
- [spec link 1]
- [spec link 2]

**Plan:**
1. [First step]
2. [Second step]
3. [Verification]
```

### Ending a Session

```markdown
# Session End

**Date:** [Date]
**Completed:** Unit [X.Y] [partial/complete]

**Summary:**
[What was done]

**Commit(s) made:**
- [commit hash]: [description]

**Checkpoint written:** Yes/No
**NEXT-STEPS.md updated:** Yes/No

**Next session should:**
1. [First priority]
2. [Second priority]
```

---

## Quick Reference

### Key Documents

| Purpose | Document |
|---------|----------|
| Project overview | README.md |
| AI instructions | CLAUDE.md |
| Vision | docs/VISION.md |
| Current tasks | docs/NEXT-STEPS.md |
| Architecture | docs/architecture-overview.md |
| MVP scope | docs/releases/mvp-scope.md |
| All specs | docs/specs/*.md |
| All research | docs/research/*.md |

### Key Specs by Milestone

| Milestone | Primary Specs |
|-----------|--------------|
| M1 | architecture-overview.md |
| M2 | imessage.md, session-management.md |
| M3 | api-setup-guide.md, error-handling.md |
| M4 | memory-learning.md |
| M5 | conversation-design.md, personality-design.md, token-awareness.md |
| M6 | tron-security.md |
| M7 | onboarding-ux.md |
| M8 | error-handling.md, autonomous-operation.md, build-and-release.md |

---

*This guide was created as part of documentation assessment v2. Update as implementation patterns emerge.*
