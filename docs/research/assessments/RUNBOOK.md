# Research Assessment Runbook (EmberHearth)

This runbook enables any Claude Code session to execute a research assessment cycle — triaging new AI research against EmberHearth's architecture and producing actionable change proposals for TK's review.

For the full specification, see [specs/research-assessment.md](../../specs/research-assessment.md).

---

## Prerequisites

Before starting, read or confirm familiarity with:

1. **[ASSESSMENT-LOG.md](ASSESSMENT-LOG.md)** — Check the last cycle date to determine the current window
2. **[specs/research-assessment.md](../../specs/research-assessment.md)** — The specification (classification scheme, proposal format, lifecycle)
3. **[CLAUDE.md](../../../CLAUDE.md)** — Project identity, naming conventions, documentation map

### Key Files to Reference During Analysis

| What | Where |
|------|-------|
| Architecture overview | `docs/architecture-overview.md` |
| Tron security spec | `docs/specs/tron-security.md` |
| ASV implementation spec | `docs/specs/asv-implementation.md` |
| Token awareness spec | `docs/specs/token-awareness.md` |
| Error handling spec | `docs/specs/error-handling.md` |
| Autonomous operation spec | `docs/specs/autonomous-operation.md` |
| Crisis safety protocols | `docs/specs/crisis-safety-protocols.md` |
| Offline mode spec | `docs/specs/offline-mode.md` |
| V1 workplan | `docs/v1-workplan.md` |
| Vision & philosophy | `docs/VISION.md` |
| ADRs | `docs/architecture/decisions/` |
| Core research docs | `docs/research/*.md` |
| Integration research | `docs/research/integrations/*.md` |

---

## Step-by-Step Process

### Step 1: Determine Cycle Window

Read `ASSESSMENT-LOG.md`. Find the most recent cycle date in the Cycle History table.

- **If a previous cycle exists:** The new cycle's window starts from that date
- **If no previous cycle exists:** This is a bootstrap cycle covering all existing research (date range: "project inception through today")

Record the date range for the new cycle.

### Step 2: Build Intake Manifest

Scan the research directories for items within the window.

**Tool calls:**
```
Glob: docs/research/papers/2026-*.md
Glob: docs/research/youtube/discoverai/2026-*.md
```

Filter results to items dated within the cycle window. For the bootstrap cycle, include everything.

**Deduplication:** Many papers have corresponding video transcripts linked via "Referenced in:" metadata. Build a deduplication map:

```
Grep: "Referenced in:" in docs/research/papers/
```

Paper-transcript pairs should be treated as a single research unit during triage. Don't triage them separately — you'll double-count the same findings.

**Carry-forward:** Check `ASSESSMENT-LOG.md`'s "Deferred Proposals" table for items to carry forward into this cycle.

### Step 3: Triage Each Item

For each research unit in the manifest:

1. Read the file's metadata header (`Relevance:`, `Why This Matters for EmberHearth`)
2. Read the `Key Findings` section (for papers) or scan the transcript summary
3. Rate relevance to each EmberHearth component dimension:

| Dimension | What to Ask |
|-----------|-------------|
| **Architecture** | Does this affect XPC isolation, component design, data flow, or the single-process MVP vs full service model? |
| **Messaging** | Does this affect iMessage integration, chat.db reading, AppleScript sending, message routing, or group chat handling? |
| **LLM Integration** | Does this affect cloud/local providers, context building, token budget, SSE parsing, or model selection? |
| **Memory** | Does this affect fact extraction, storage schema, retrieval, decay, summarization, or session state? |
| **Personality** | Does this affect Ember's voice, ASV dimensions, verbosity adaptation, conversation continuity, or bounded needs? |
| **Security** | Does this identify new threats, suggest better injection defenses, or affect credential/PII detection? |
| **Privacy** | Does this affect local-first data architecture, Keychain usage, sandbox entitlements, or the no-cloud-sync policy? |
| **Platform** | Does this affect macOS API usage, Apple framework integrations, distribution, or accessibility? |
| **Resilience** | Does this introduce new failure modes or suggest better error handling, crash recovery, or offline patterns? |

Rate each dimension: HIGH (H), MEDIUM (M), LOW (L), or NONE (-).

**Speed tip:** The existing `Relevance:` metadata on each file gives you a head start. Many items already have topic tags that map to dimensions (e.g., "Prompt injection defense" maps to security, "Context window management" maps to LLM integration + memory).

Items rated NONE across ALL dimensions are noted and skipped. Don't spend analysis time on them.

### Step 4: Gap Analysis

For each item rated HIGH or MEDIUM in at least one dimension:

1. **Read the relevant EmberHearth doc.** If the item relates to security, read `docs/specs/tron-security.md` and the security sections of `docs/architecture-overview.md`. If it relates to memory, read `docs/research/memory-learning.md` and the MemoryService section of the architecture overview. Match the dimension to the right reference doc.

2. **Compare the finding to current design.** Ask: does this validate what we're doing, suggest a change, suggest something new, or warn about a threat?

3. **Classify:**
   - **CONFIRMS** — our design is validated by new evidence
   - **SUGGESTS CHANGE** — a modification would improve the system
   - **SUGGESTS ADDITION** — a new capability is needed
   - **WARNING** — a new threat or failure mode affects us

4. **Rate severity:**
   - **HIGH** — strong evidence, significant impact, should act
   - **MEDIUM** — worth addressing but not urgent
   - **LOW** — interesting but no immediate action needed

5. **Map to specific components.** Be precise — "affects ContextBuilder token budget allocation" is better than "affects LLM integration."

Record results in the gap analysis tables (grouped by classification).

### Step 5: Generate Proposals

For each HIGH or MEDIUM severity gap, write a proposal using the format from the spec:

```markdown
### Proposal YYYY-MM-DD-NN: <Title>

- **Category:** <CONFIRMS / SUGGESTS CHANGE / SUGGESTS ADDITION / WARNING>
- **Severity:** <HIGH / MEDIUM>
- **Affected Components:** <list>
- **Evidence:** <links to papers/transcripts>
- **Current State:** <what EmberHearth does now — cite specific files/specs/ADRs>
- **Proposed Change:** <what should change — be specific>
- **Effort Estimate:** <small / medium / large>
- **Risk to In-Flight Work:** <none / low / medium / high>
- **Workplan Impact:** <which milestones or future phases>
```

**Key rules:**
- One proposal per distinct change, even if multiple research items support it
- Merge evidence when multiple items point to the same change
- Be actionable: "update `docs/specs/tron-security.md` section X to add Y" is a proposal; "we should think about this" is not
- LOW severity gaps don't become proposals — they're recorded in gap analysis only

### Step 6: Create Cycle Directory and Report

```
Bash: mkdir -p docs/research/assessments/cycles/YYYY-MM-DD
```

Copy the template and fill in all sections:
- Copy from `docs/research/assessments/templates/cycle-report-template.md`
- Fill in cycle metadata, intake tables, triage table, gap analysis, and proposals
- Create an empty `decisions.md` ready for Step 7

### Step 7: Present Proposals for Decision

Summarize proposals for TK. For each proposal, present:
- What the research says (brief)
- What EmberHearth does now
- What should change
- Effort and risk assessment

Group proposals by component area. Present highest-severity items first.

**Wait for TK's decision on each proposal:** ACCEPTED / REJECTED / DEFERRED

For deferred items, ask TK to specify defer conditions (what would trigger reconsideration).

### Step 8: Record Decisions

Fill in `decisions.md` with each decision:

```markdown
| Proposal ID | Title | Decision | Reasoning | Action Items | Defer Conditions |
|-------------|-------|----------|-----------|-------------|------------------|
```

### Step 9: Close Cycle

Update `ASSESSMENT-LOG.md`:
1. Add a row to the Cycle History table with final counts
2. Add any DEFERRED proposals to the "Deferred Proposals" table
3. Remove any previously-deferred proposals that were addressed in this cycle

The cycle is now closed. The next cycle starts from this cycle's date.

---

## Known Issues & Workarounds

### 1. Bootstrap Cycle Is Large

The first cycle covers all existing research (~25+ items). This is expected and normal.

**Workaround:** Do a fast initial triage pass. Items with existing `Relevance:` metadata that clearly maps to NONE across all dimensions can be skipped quickly. Spend analysis time on the HIGH/MEDIUM items, not on comprehensive rating of LOW-relevance papers.

### 2. Paired Papers and Transcripts

Many papers have corresponding video transcripts (linked via "Referenced in:" metadata). If you triage both separately, you'll double-count the same research.

**Workaround:** Before starting triage, run:
```
Grep: "Referenced in:" in docs/research/papers/
```
Build a map of paper-transcript pairs. Triage each pair as a single unit.

### 3. Cross-Session Context Loss

If an assessment cycle spans multiple Claude Code sessions (e.g., TK steps away before decisions are made), the partially-filled cycle directory persists on disk.

**Workaround:** A new session can pick up by reading the existing `report.md` in the cycle directory. The triage and gap analysis sections show what's been done. If `decisions.md` is empty or incomplete, resume at Step 7.

### 4. Proposals That Span Multiple Components

Some research findings affect multiple EmberHearth components (e.g., a paper on context window efficiency might affect LLM integration, memory, AND personality). This is fine — list all affected components in the proposal. But write ONE proposal per change, not one per component.

### 5. Conflicting Research

Two papers may suggest contradictory changes. When this happens, note both in the gap analysis and let the evidence strength and severity rating determine which becomes a proposal. If they're roughly equal, present both to TK as competing proposals with a recommendation.

### 6. Research That Targets Future Phases

Some research will be highly relevant to features not in the current MVP (e.g., multi-agent orchestration, local MLX models). These should still be triaged and analyzed — they inform future phase planning. Proposals targeting future phases should note which phase in the "Workplan Impact" field.

---

## Tips for Future Sessions

- **Check ASSESSMENT-LOG.md FIRST** to know when the last cycle ran
- **Paired research = single unit.** Paper + transcript about the same topic are one triage item
- **Triage should be fast.** Don't agonize over NONE-rated items. Spend time on gap analysis and proposals
- **Proposals must be actionable.** If you can't name a specific file or section that would change, it's not a proposal yet — it's a finding
- **The decision phase is interactive.** Present proposals clearly and wait for TK's input. Don't assume decisions
- **After the first cycle, each cycle should be smaller and faster.** If cycles keep being large, the cadence may need to increase
- **CONFIRMS findings are valuable too.** They validate design decisions and reduce uncertainty. Don't skip them just because they don't suggest changes
- **Deferred is not rejected.** Deferred proposals carry forward. They get reconsidered every cycle until they're either accepted or explicitly rejected
- **MVP vs future:** Be clear in proposals whether a change affects current MVP work or future phases. Both are valid but have different urgency

---

## Repeatable Prompt

Use this prompt to run a research assessment cycle in any Claude Code session:

```
Read docs/research/assessments/RUNBOOK.md and follow its workflow to
execute a research assessment cycle. Check ASSESSMENT-LOG.md for the
last cycle date, then triage all new research since that date. Produce
a cycle report with relevance triage, gap analysis, and proposals.
Present the proposals for my review and decision.
```
