# Research Assessment Specification

## Overview

The research assessment process is EmberHearth's mechanism for turning AI research into actionable architecture improvements. It defines a structured, repeatable lifecycle where new research (academic papers, video transcripts, industry findings) is triaged against EmberHearth's current design, analyzed for gaps, and transformed into concrete change proposals that TK can accept, reject, or defer.

This process runs manually during all current phases (Claude Code + TK). The directory structure, classification schemes, and document formats are designed for long-term institutional memory — manual cycles build a decision history that informs future design work.

---

## Why This Exists

EmberHearth's research library is growing — academic papers, YouTube transcript analyses, industry findings — but research collection alone doesn't improve the architecture. Without a structured assessment process, four gaps remain:

1. **No triage step.** Research is saved but nothing systematically asks "what does this mean for our current design?"
2. **No proposal lifecycle.** There's no place where "this paper suggests we should change X" gets captured, evaluated, and decided upon.
3. **No cycle boundary.** Without a clear "this batch has been analyzed," there's no way to distinguish new research from already-processed research. Old findings clutter new analysis.
4. **No decision log.** When a proposal is accepted or rejected, that reasoning isn't captured anywhere that future cycles can reference.

The pace of AI research — measured in weeks, not years — means design decisions made now could be outdated before implementation begins. This specification closes the gap by defining a repeatable workflow that works today, builds institutional memory, and prevents architectural drift.

---

## Assessment Cycles

An assessment cycle is a discrete batch where research is analyzed, proposals are generated, decisions are made, and the cycle closes. Each cycle is atomic — once closed, future cycles don't revisit its research.

### How Cycles Work

1. Each cycle has a **date range**: starts from the end date of the previous cycle (or project inception for the first bootstrap cycle)
2. Papers and transcripts are a **permanent reference library** — cycles reference them by path but don't move or modify them
3. Once a cycle closes, its research is **done** — future cycles only analyze new material
4. **Deferred proposals** (items marked "not now, maybe later") carry forward automatically to the next cycle
5. Each cycle's **decisions become baseline context** for future cycles — if a change was rejected in February, the March cycle knows not to re-propose it unless new evidence changes the calculus

### Cadence

| Cadence | When to Use |
|---------|-------------|
| **Weekly** | During active research collection periods or fast-moving industry developments |
| **Biweekly** (default) | Normal operations — good balance of awareness and overhead |
| **Monthly** | During heavy implementation phases when research collection slows |
| **Manual** | Triggered when TK notices something particularly relevant |

TK sets the cadence based on research volume and implementation pace.

### Bootstrap

The first assessment cycle is a bootstrap cycle. Its date range covers "project inception through the cycle date." It treats all existing research as new (because none of it has been triaged). This produces a larger-than-normal cycle, but establishes the baseline for all future cycles.

---

## Lifecycle Phases

Each assessment cycle moves through eight phases. During manual operation (Claude Code + TK), all phases happen within one or two sessions.

### Phase 0: Topic Calibration

**Input:** Previous calibration (`docs/research/CALIBRATED-TOPICS.md`), or baseline topic lists from research guides (for the first calibration).

**Purpose:** Ensure the assessment cycle's triage uses a topic list that reflects the project's *current* state — not a static list that may have gone stale as the architecture, phase, or AI landscape evolved.

**Process:**
1. Scan the repo to build a current-state snapshot:
   - Active phase (from `CLAUDE.md` → phase doc)
   - Workplan progress (completed, in-progress, upcoming milestones)
   - Architecture components (from `docs/architecture-overview.md`)
   - Specs and ADRs (from `docs/specs/*.md` and `docs/architecture/decisions/*.md`)
   - Source code modules (from `src/**/*.swift`, if they exist)
2. Compare against the previous calibration (or the baseline topic lists from the research guides for the first run)
3. For each topic, determine priority (HIGH / MEDIUM / LOW / DEPRIORITIZED), update search terms, and note the rationale
4. Identify emerging topics not covered by existing lists (new subsystems, new industry trends)
5. Identify deprioritized topics (less relevant to the current phase)
6. Check whether the 9 component dimensions still cover the architecture, or if new dimensions are needed
7. Present calibration changes to TK for approval
8. Write approved calibration to `docs/research/CALIBRATED-TOPICS.md`

**Output:** Updated `docs/research/CALIBRATED-TOPICS.md` with current priorities, search terms, dimensions, and project state snapshot. This file is used by Phase 2 (Relevance Triage) for the remainder of the cycle.

**Note:** Calibration can also be run independently of an assessment cycle — for example, before a standalone research sweep. The research guides reference `CALIBRATED-TOPICS.md` as the preferred topic source.

### Phase 1: Intake Cutoff

**Input:** Date of last cycle (from `ASSESSMENT-LOG.md`), or "project inception" for bootstrap.

**Process:**
1. Determine the date range: everything since the last cycle's close date
2. Scan `docs/research/papers/` for papers dated within the window
3. Scan `docs/research/youtube/discoverai/` for transcripts dated within the window
4. Check `ASSESSMENT-LOG.md` deferred proposals table for carry-forward items
5. Build a deduplication map: papers with "Referenced in:" links to transcripts are treated as single research units
6. Produce an intake manifest listing all items to triage

**Output:** Intake manifest (list of file paths, titles, dates, and any carry-forward proposals).

### Phase 2: Relevance Triage

**Input:** Intake manifest from Phase 1. Calibrated topics and dimensions from Phase 0.

**Process:**
1. For each research unit (paper, transcript, or paper-transcript pair):
   - Read the metadata, "Why This Matters for EmberHearth" section, and key findings
   - Rate relevance to each EmberHearth component dimension on a HIGH/MEDIUM/LOW/NONE scale
   - Use the calibrated topic priorities from `docs/research/CALIBRATED-TOPICS.md` to inform ratings — research that aligns with HIGH-priority calibrated topics should be weighted accordingly
2. Record ratings in the triage table
3. Items rated NONE across all dimensions are noted and skipped from further analysis

**Component Dimensions** (aligned with EmberHearth's architecture — may be updated during Phase 0 calibration):

| Dimension | What's Evaluated |
|-----------|-----------------|
| **Architecture** | XPC isolation, component design, data flow, communication patterns, single-process MVP vs full service model |
| **Messaging** | iMessage integration, chat.db reading, AppleScript sending, message routing, group chat handling, phone filtering |
| **LLM Integration** | Cloud/local providers, API clients, context building, token budget allocation, SSE parsing, model selection |
| **Memory** | SQLite storage, fact extraction, retrieval, decay, summarization, session state, conversation archive |
| **Personality** | Ember's voice and identity, ASV dimensions, verbosity adaptation, conversation continuity, bounded needs |
| **Security** | Tron pipeline, prompt injection defense, credential detection, PII scanning, tool authorization, audit logging |
| **Privacy** | Local-first data architecture, Keychain usage, sandbox entitlements, file access boundaries, no-cloud-sync policy |
| **Platform** | macOS APIs, Apple framework integrations, distribution/notarization, accessibility/VoiceOver, system resource usage |
| **Resilience** | Error handling, crash recovery, offline mode, schema migration, update/rollback, circuit breakers |

**Output:** Triage table with per-item relevance ratings. List of items proceeding to gap analysis (those with at least one HIGH or MEDIUM rating).

### Phase 3: Gap Analysis

**Input:** Triaged items rated HIGH or MEDIUM in at least one dimension.

**Process:**
1. For each item, read the relevant EmberHearth spec, ADR, or architecture doc
2. Compare the research finding against EmberHearth's current design
3. Classify each gap:
   - **CONFIRMS** — our design is validated by new evidence
   - **SUGGESTS CHANGE** — a modification would improve the system
   - **SUGGESTS ADDITION** — a new capability is needed
   - **WARNING** — a new threat or failure mode affects us
4. Rate severity:
   - **HIGH** — should act (evidence is strong, impact is significant)
   - **MEDIUM** — should plan (worth addressing but not urgent)
   - **LOW** — note for later (interesting but no immediate action needed)
5. Map each gap to specific EmberHearth components affected

**Output:** Gap analysis tables grouped by classification, with severity and component mappings.

### Phase 4: Proposal Generation

**Input:** Gap analysis results (HIGH and MEDIUM severity items only).

**Process:**
1. Write one concrete change proposal per distinct change, even if multiple research items support it
2. Merge evidence when multiple items point to the same change
3. Use the proposal format defined below
4. Assign sequential IDs: `YYYY-MM-DD-NN` (cycle date + number)
5. Ensure each proposal is actionable — "we should think about this" is not a proposal; "update `docs/specs/tron-security.md` section X to add Y" is

**Output:** Numbered proposals in the cycle report.

**Note:** LOW severity gaps do not become proposals. They are recorded in the gap analysis for reference but require no action. If they accumulate across multiple cycles, that pattern may elevate them to MEDIUM in a future cycle.

### Phase 5: Decision

**Input:** Proposals from Phase 4.

**Process:**
1. TK reviews each proposal
2. For each proposal, decide:
   - **ACCEPTED** — change should be made; action items created
   - **REJECTED** — change is not appropriate; reasoning recorded
   - **DEFERRED** — not now, but should be reconsidered; defer conditions specified
3. Record all decisions with reasoning in `decisions.md`

**Output:** Completed `decisions.md` in the cycle directory.

**Note:** Deferred proposals must include **defer conditions** — what would trigger reconsideration. "Revisit later" is not sufficient; "revisit when memory system is implemented" or "revisit if a second paper confirms this finding" gives future cycles a clear trigger.

### Phase 6: Action

**Input:** Accepted proposals with action items.

**Process:**
1. For design document updates: execute immediately (spec changes, ADR additions, architecture updates)
2. For code changes: file as tasks in the workplan for the appropriate milestone
3. For research follow-ups: add to the research backlog for future collection
4. Record what was done for each accepted proposal

**Output:** Updated documents and/or filed tasks.

### Phase 7: Close

**Input:** All decisions made, actions initiated for accepted proposals.

**Process:**
1. Finalize the cycle's `report.md` and `decisions.md`
2. Update `ASSESSMENT-LOG.md` with the cycle's summary row
3. Add deferred proposals to the carry-forward table in `ASSESSMENT-LOG.md`
4. Remove any previously-deferred proposals that were addressed in this cycle from the carry-forward table

**Output:** Closed cycle. `ASSESSMENT-LOG.md` updated. Ready for the next cycle.

---

## Proposal Format

Each proposal uses a structured format for consistency and traceability:

| Field | Description |
|-------|-------------|
| **ID** | Cycle date + sequential number (e.g., `2026-02-26-01`) |
| **Title** | Short descriptive name |
| **Category** | CONFIRMS / SUGGESTS CHANGE / SUGGESTS ADDITION / WARNING |
| **Severity** | HIGH / MEDIUM |
| **Affected Components** | List of EmberHearth components (architecture, messaging, LLM, etc.) |
| **Evidence** | Links to papers and/or transcripts that support this proposal |
| **Current State** | What EmberHearth does now (reference specific files/specs/ADRs) |
| **Proposed Change** | What should change (be specific about files, sections, approaches) |
| **Effort Estimate** | small / medium / large |
| **Risk to In-Flight Work** | none / low / medium / high |
| **Workplan Impact** | Which milestones or future phases are affected |

---

## Decision Log Format

Each decision records the reasoning for future reference:

| Field | Description |
|-------|-------------|
| **Proposal ID** | Reference to the proposal |
| **Decision** | ACCEPTED / REJECTED / DEFERRED |
| **Reasoning** | Why this decision was made |
| **Action Items** | If accepted: what specifically happens (files to update, tasks to create) |
| **Defer Conditions** | If deferred: what would trigger reconsideration |

---

## Approval Flow

```
Topic calibration (Phase 0) → TK approves topics
        |
        v
Assessment cycle completes (Phases 1-4)
        |
        v
TK reviews proposals
        |
        +-- ACCEPTED --> action items created, changes executed
        |
        +-- REJECTED --> reasoning logged, no action
        |
        +-- DEFERRED --> tagged for carry-forward to next cycle
                          |
                          v
                 Deferred proposals appear in the next cycle's
                 Phase 1 intake alongside new research
                          |
                          v
                 TK can escalate any deferred item
                 to immediate action at any time
```

Accepted proposals become work in the appropriate context:
- **During pre-implementation:** Design document updates, spec revisions, ADR additions, architecture changes
- **During MVP construction:** Tasks added to v1-workplan.md milestones
- **During future phases:** Tasks filed for the appropriate phase (Glow, Flame, Hearth)

---

## Directory Structure

```
docs/research/
  CALIBRATED-TOPICS.md                 # Live calibrated topic list (updated each cycle)

  papers/                              # Permanent reference library (papers)
    PaperResearchGuide.md              # Runbook for finding papers (baseline topics)
    2026-MM-DD-paper-title.md          # Individual papers
    downloads/                         # PDF downloads

  youtube/discoverai/                  # Permanent reference library (transcripts)
    YouTubeResearchGuide.md            # Runbook for capturing transcripts (baseline topics)
    2026-MM-DD-video-title.md          # Individual transcripts

  assessments/                         # Assessment cycle infrastructure
    ASSESSMENT-LOG.md                  # Running index of all cycles
    RUNBOOK.md                         # Repeatable process guide
    templates/
      cycle-report-template.md         # Template for new cycle reports
    cycles/
      YYYY-MM-DD/                      # One directory per cycle
        report.md                      # Full cycle report (intake -> proposals)
        decisions.md                   # Accept/reject/defer with reasoning
```

**Key principle:** Research files (papers, transcripts) stay in place permanently. They are a reference library. Assessment cycles reference them by path but never move or modify them. It is the cycle that completes, not the research files.

---

## What Gets Updated

When proposals from an assessment cycle are accepted and implemented:

| File/Area | What Changes |
|-----------|-------------|
| `docs/architecture-overview.md` | Architectural changes, component design updates |
| `docs/specs/*.md` | Spec updates based on new research findings |
| `docs/architecture/decisions/*.md` | New ADRs for significant design changes |
| `docs/v1-workplan.md` | New tasks added to milestones |
| `docs/NEXT-STEPS.md` | Phase adjustments based on new capabilities or priorities |
| `docs/VISION.md` | Vision refinements (rare — only for fundamental shifts) |
| `docs/research/*.md` | New failure modes, patterns, or findings appended to research docs |
| `docs/research/CALIBRATED-TOPICS.md` | Updated topic priorities, search terms, dimensions, and project state snapshot |
| `src/**/*.swift` | Code changes (filed as workplan tasks, not executed during assessment) |

Every assessment cycle also records what was reviewed and decided in `ASSESSMENT-LOG.md`, building institutional memory about how and why EmberHearth evolves.

---

## Metrics

Track over time to measure the assessment process's value:

| Metric | What It Measures | Good Signal |
|--------|-----------------|-------------|
| **Items triaged per cycle** | Volume of incoming research | Consistent with research collection cadence |
| **Proposals per cycle** | How much is actionable | Steady flow, not zero (we're paying attention) and not overwhelming (we're focused) |
| **Acceptance rate** | Fraction of proposals accepted | No fixed target — depends on research quality and architecture maturity |
| **Defer rate** | Fraction deferred vs. rejected | Low — most items should get a clear yes or no |
| **Time to action** | Days from proposal to implemented change | Shorter is better, but not at the expense of quality |
| **Component coverage** | Which dimensions are being assessed | Broad coverage — not just LLM and memory |
| **Carry-forward accumulation** | Deferred items piling up | Should stay small — a growing backlog signals cadence or decision issues |
| **Cycle duration** | How long each cycle takes to complete | Should stabilize or decrease as the process matures |

---

*Research without assessment is a library. Assessment without action is a report. The research assessment lifecycle turns knowledge into evolution — and gives EmberHearth the ability to grow with the industry it operates in.*
