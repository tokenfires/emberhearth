# EmberHearth Build Tasks

This directory contains sequenced task documents for AI-assisted implementation of EmberHearth MVP.

## How to Use

### Workflow per Task

1. Open the task file (e.g., `0001-xcode-project-setup.md`) in Cursor IDE
2. Open the **Context Files** listed in the task using `@file` references in Cursor
3. Start a **new** Claude Sonnet 4.5 session (fresh context every time)
4. Copy/paste the **Sonnet Prompt** section into the chat
5. Let Sonnet complete the implementation
6. Run the **Verification Commands** listed in the task
7. If build/tests fail, fix in the same Sonnet session
8. If build/tests pass, start a **new** Claude Opus session
9. Copy/paste the **Opus Verification Prompt** into the Opus chat
10. Address any Opus findings
11. Commit using the suggested **Commit Message** format
12. Mark the task complete in GitHub Projects
13. Close all chat sessions before starting the next task

### Rules

- **One task per session** — Never carry Sonnet context across tasks
- **Fresh session every time** — Context rot is the enemy of quality
- **Build must pass** before Opus review — Don't waste Opus on broken code
- **Never skip verification** — Opus catches what Sonnet misses
- **Commit after each task** — Small, focused, verifiable commits

### Task Naming Convention

```
NNNN-short-description.md
```

- `NNNN` = 4-digit sequence number (sort order = build order)
- Tasks are grouped by milestone (M1-M8) matching the Implementation Guide
- Dependencies are explicit in each task

### Milestones

| Range | Milestone | Phase |
|-------|-----------|-------|
| 0001-0099 | M1: Foundation | Phase 1 |
| 0100-0199 | M2: iMessage Integration | Phase 1 |
| 0200-0299 | M3: LLM Integration | Phase 1 |
| 0300-0399 | M4: Memory System | Phase 2 |
| 0400-0499 | M5: Personality & Context | Phase 2 |
| 0500-0599 | M6: Security Basics | Phase 3 |
| 0600-0699 | M7: Onboarding | Phase 3 |
| 0700-0799 | M8: Polish & Release | Phase 3 |
| 0800-0899 | Integration & E2E Testing | Final |
| 0900-0999 | Crisis Safety & Compliance | Final |

### Context Budget

Each task is designed to stay under ~40K tokens of combined context (prompt + referenced files). This keeps Sonnet well within its quality threshold. If a referenced file is very long, the task prompt will specify which sections to focus on.

### Task Status Tracking

Track progress in GitHub Projects (see `tasks/github-import.csv` for import file).
