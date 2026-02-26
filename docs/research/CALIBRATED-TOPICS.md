# Calibrated Research Topics

This file is EmberHearth's **live research topic registry** — the dynamic, phase-aware set of topics that research sweeps and assessment cycles use to find and evaluate relevant AI research.

**This file is regenerated at the start of each assessment cycle** (RUNBOOK Step 0: Topic Calibration) and can be refreshed before standalone research sweeps. After the first calibration, this file is the source of truth for what to search for — not the static baseline lists in the individual research guides.

---

## Calibration Metadata

- **Last calibrated:** _Pending first calibration_
- **Active phase at calibration:** —
- **Calibration trigger:** —
- **Calibrated by:** —

---

## How Calibration Works

Each calibration scans the repo to build a current-state snapshot, then adjusts the topic list based on:

1. **What's built** — Completed workplan items and implemented source files
2. **What's in progress** — Current milestone and active workplan items
3. **What's planned next** — Upcoming milestones in the workplan
4. **What specs exist** — Component specs, ADRs, and architecture docs
5. **What phase is active** — Current phase priorities from the phase doc
6. **Industry context** — Fast-moving areas where the AI landscape has shifted since last calibration

### What Changes Between Calibrations

| Change Type | Example |
|-------------|---------|
| **Priority shift** | "On-device LLMs" drops from HIGH to MEDIUM during MVP (no local fallback in scope yet) |
| **New topic** | A new spec introduces a subsystem not covered by existing topics |
| **Retired topic** | A topic becomes irrelevant as architecture solidifies or a decision is made |
| **Search term update** | Better keywords discovered from recent research or industry terminology shifts |
| **Dimension update** | A new component dimension is added as the architecture grows |

---

## Component Dimensions

These are the architectural dimensions research is evaluated against during triage. They evolve as EmberHearth grows — calibration may add, refine, or merge dimensions.

| Dimension | Current Scope |
|-----------|--------------|
| **Architecture** | XPC isolation, component design, data flow, single-process MVP vs full service model |
| **Messaging** | iMessage integration, chat.db reading, AppleScript sending, message routing, group chat handling |
| **LLM Integration** | Cloud/local providers, context building, token budget, SSE parsing, model selection |
| **Memory** | Fact extraction, SQLite storage, retrieval, decay, summarization, session state |
| **Personality** | Ember's voice, ASV dimensions, verbosity adaptation, conversation continuity, bounded needs |
| **Security** | Tron pipeline, prompt injection defense, credential/PII detection, tool authorization |
| **Privacy** | Local-first data, Keychain, sandbox entitlements, file access boundaries, no-cloud-sync |
| **Platform** | macOS APIs, Apple frameworks, distribution/notarization, accessibility/VoiceOver |
| **Resilience** | Error handling, crash recovery, offline mode, schema migration, circuit breakers |

_Dimensions should be added or refined during calibration when new components emerge that don't fit cleanly into existing categories._

---

## Project State Snapshot

_Populated during calibration. Provides the context that drives topic priority decisions._

### Completed Components

_List of workplan items and source modules that are built and committed._

### In-Progress Work

_Current milestone and active workplan items._

### Upcoming Milestones

_Next milestones in the workplan — topics supporting these should be prioritized._

### Key Specs & ADRs

_Recently added or updated specs and ADRs that may introduce new topic needs._

---

## Active Topic List

### High-Priority Topics

_Topics with direct, immediate relevance to in-progress or upcoming work._

| Topic | Search Terms | Rationale |
|-------|-------------|-----------|
| _Populated by calibration_ | | |

### Medium-Priority Topics

_Topics relevant to planned work or important background knowledge._

| Topic | Search Terms | Rationale |
|-------|-------------|-----------|
| _Populated by calibration_ | | |

### Emerging Topics

_Topics not in the original baseline but suggested by current architecture, specs, ADRs, or industry shifts. These represent areas the project is growing into._

| Topic | Search Terms | Rationale |
|-------|-------------|-----------|
| _Populated by calibration_ | | |

### Deprioritized Topics

_Topics that were previously higher priority but are currently less relevant given the active phase. Kept here so they aren't lost — future calibrations may re-elevate them._

| Topic | Previous Priority | Rationale for Deprioritization |
|-------|------------------|-------------------------------|
| _Populated by calibration_ | | |

---

## Calibration Changelog

_Running log of what changed each calibration, newest first._

| Date | Trigger | Key Changes |
|------|---------|-------------|
| _Pending_ | _First calibration_ | _Initial population from repo scan + baseline topics_ |

---

## Baseline Reference

The original static topic lists live in:

- [`papers/PaperResearchGuide.md`](papers/PaperResearchGuide.md) — Paper search terms
- [`youtube/discoverai/YouTubeResearchGuide.md`](youtube/discoverai/YouTubeResearchGuide.md) — Video search keywords

These serve as the **seed topics** for the first calibration and as a fallback if calibration hasn't run yet. After the first calibration, this file supersedes them for active research work.
