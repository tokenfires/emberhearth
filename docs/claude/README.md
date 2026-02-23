# Claude Phase Instructions

Phase-specific instruction files for Claude Code sessions. The active phase is set in [`CLAUDE.md`](../../CLAUDE.md) at the project root.

---

## How This Works

1. `CLAUDE.md` contains permanent instructions (principles, security, naming) and a pointer to the active phase doc
2. The active phase doc (this directory) contains everything specific to the current work mode
3. When a phase completes, its doc moves to `archive/` and the pointer updates

## Active Phase

See `CLAUDE.md` for the current active phase.

## Available Phase Docs

| Phase Doc | For When |
|---|---|
| [construction-mvp.md](construction-mvp.md) | Building the MVP ("Spark") |

## Archived Phases

| Phase Doc | Period |
|---|---|
| [research-phase-1.md](archive/research-phase-1.md) | Project inception through Feb 2026 |

## Future Phase Docs (Create When Needed)

| Phase Doc | For When |
|---|---|
| `task-decomposition-glow.md` | Planning V1.1 ("Glow") work items |
| `construction-glow.md` | Building V1.1 ("Glow") |
| `task-decomposition-flame.md` | Planning V1.2 ("Flame") work items |
| `construction-flame.md` | Building V1.2 ("Flame") |
| `construction-hearth.md` | Building V2.0 ("Hearth") |

## Requirements for All Task Decomposition Phases

When creating a task decomposition phase doc, the workplan it produces **must** include:

1. **Workflow test items at milestone boundaries** — automated tests that exercise the full pipeline for that milestone's additions (not just unit tests)
2. **A user journey test item as the final task** — automated end-to-end scenarios covering the release's success criteria
3. **Reference to the Task Decomposition Checklist** in `docs/IMPLEMENTATION-GUIDE.md`

This requirement exists because unit tests alone do not verify that the app works. Components that pass individually can fail when wired together. This lesson was learned the hard way — don't skip it.
