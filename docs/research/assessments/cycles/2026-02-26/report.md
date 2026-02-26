# Research Assessment Cycle: 2026-02-26

## Cycle Metadata

- **Date Range:** Project inception to 2026-02-26
- **Previous Cycle:** Bootstrap (first cycle)
- **Papers Reviewed:** 14
- **Transcripts Reviewed:** 12
- **Carried-Forward Proposals:** None

---

## Phase 1: Intake

### Deduplication Map

12 of 14 papers have corresponding video transcripts. Two transcripts cover 2 papers each. After deduplication: **14 research units**.

| Paper(s) | Paired Transcript |
|----------|-------------------|
| `2026-02-17-geometry-of-alignment-collapse` | `2026-02-21-how-geometry-destroys-ai-safety` |
| `2026-02-18-multi-agent-cooperation-in-context-co-player-inference` | `2026-02-23-ai-agents-invent-algorithm-to-survive` |
| `2026-02-14-quantization-trap-multi-hop-reasoning` | `2026-02-18-quantization-breaks-4bit-ai-models` |
| `2026-02-05-dytopo-dynamic-topology-routing-multi-agent` | `2026-02-10-8b-outperforms-gpt-120b-on-multi-agents` |
| `2026-02-03-agentark-distilling-multi-agent-intelligence` | `2026-02-07-distill-5-ai-agents-into-one` |
| `2026-02-01-multi-agent-teams-hold-experts-back` | `2026-02-09-stanford-ai-agents-destroy-their-own-intelligence` |
| `2026-02-11-reinforcing-chain-of-thought-self-evolving-rubrics` | `2026-02-16-ai-self-corrects-its-reasoning-complexity` |
| `2026-02-04-language-models-struggle-representations-in-context` | `2026-02-06-googles-warning-icl-context-is-inert` |
| `2026-01-29-why-reasoning-fails-to-plan` + `2026-01-29-context-structure-reshapes-representational-geometry` | `2026-02-03-google-beyond-the-next-token-manifold` |
| `2026-01-26-pope-privileged-on-policy-exploration` + `2025-12-04-model-whisper-steering-vectors-test-time` | `2026-01-30-pope-rl-curriculum-learning-cmu` |

| Standalone | Type |
|------------|------|
| `2026-01-08-defense-indirect-prompt-injection-tool-result-parsing` | Paper only |
| `2026-01-08-know-thy-enemy-prompt-injection-instrucot` | Paper only |
| `2026-02-14-ai-belief-functions-deciding-under-absolute-uncertainty` | Transcript only |
| `2026-02-05-claude-opus-4-6-thinking-vs-non-thinking` | Transcript only |

### Carried-Forward Proposals

None (bootstrap cycle).

---

## Phase 2: Relevance Triage

| # | Research Unit | Arch | Msg | LLM | Mem | Pers | Sec | Priv | Plat | Resil | Overall |
|---|---------------|------|-----|-----|-----|------|-----|------|------|-------|---------|
| 1 | Geometry of Alignment Collapse | L | - | M | - | M | H | - | - | L | **H** |
| 2 | Multi-Agent Cooperation / Co-Player Inference | L | - | - | - | - | - | - | - | - | L |
| 3 | Quantization Trap / Multi-Hop Reasoning | - | - | H | - | - | - | - | M | M | **H** |
| 4 | DyToPo / Dynamic Topology Routing | L | - | - | - | - | - | - | - | - | L |
| 5 | AgentArk / Multi-Agent Distillation | M | - | M | - | - | - | - | - | - | **M** |
| 6 | Multi-Agent Teams Hold Experts Back | M | - | L | - | - | - | - | - | - | **M** |
| 7 | Reinforcing CoT / Self-Evolving Rubrics | - | - | M | - | L | - | - | - | - | **M** |
| 8 | Language Models Struggle with ICL Representations | - | - | H | H | M | - | - | - | - | **H** |
| 9 | Why Reasoning Fails to Plan + Context Structure | - | - | H | M | - | - | - | - | M | **H** |
| 10 | POPE + Model Whisper / Steering Vectors | - | - | M | - | - | - | - | - | - | **M** |
| 11 | AI Belief Functions / Uncertainty | M | - | - | - | M | - | - | - | M | **M** |
| 12 | Claude Opus 4.6 Thinking vs Non-Thinking | - | - | H | - | - | - | - | - | M | **H** |
| 13 | Defense Against Indirect Prompt Injection (Tool Result Parsing) | - | - | - | - | - | H | - | - | - | **H** |
| 14 | Know Thy Enemy: InstruCoT | - | - | - | - | - | H | - | - | - | **H** |

**Column key:** Arch = Architecture, Msg = Messaging, LLM = LLM Integration, Mem = Memory, Pers = Personality, Sec = Security, Priv = Privacy, Plat = Platform, Resil = Resilience

**Proceeding to gap analysis (12 items):** #1, #3, #5, #6, #7, #8, #9, #10, #11, #12, #13, #14

**Skipped (LOW across all dimensions):** #2 (Multi-Agent Cooperation), #4 (DyToPo) — both are pure multi-agent research with minimal relevance to EmberHearth's current or near-term architecture.

---

## Phase 3: Gap Analysis

### CONFIRMS (current design validated)

| Finding | Evidence | Component | Notes |
|---------|----------|-----------|-------|
| Using base API models (not fine-tuned) avoids alignment collapse risk | #1 Geometry of Alignment Collapse | LLM Integration | ADR-0008's choice of Claude API (base model) avoids the quartic alignment degradation from fine-tuning. Validates current approach. |
| Steering vectors confirm local model enhancement path | #10 POPE + Model Whisper | LLM Integration | Test-Time Steering Vectors show 45.88% gains with frozen parameters. Validates Phase 2.0 MLX strategy — local models can be steered without fine-tuning. |
| Explicit memory injection is better than relying on ICL learning | #8 ICL Representations | Memory | EmberHearth's FactRetriever injecting structured facts into context is validated. Models cannot learn new patterns from context alone — they need explicit instruction. |

### SUGGESTS CHANGE (modification recommended)

| Finding | Evidence | Component | Severity | Notes |
|---------|----------|-----------|----------|-------|
| Context structure actively reshapes model behavior — order and organization matter | #9 Context Structure | LLM Integration (ContextBuilder) | HIGH | ContextBuilder's budget allocation (10/25/10/15/5/35%) doesn't account for how context ordering affects representational geometry. Structure should be deliberate, not just budgeted. |
| Memories should be framed as instructions, not informational context | #8 ICL Representations | Memory, LLM Integration | HIGH | LLMs encode novel semantics but fail to deploy them for prediction. Memory injection should use imperative framing ("The user prefers X, always do Y") rather than informational ("The user has mentioned X"). |
| Prompts should avoid requiring long-horizon logical chains | #12 Claude Opus 4.6 evaluation | LLM Integration, Personality | MEDIUM | Claude Opus 4.6 fails on complex multi-step logic. Ember's system prompt and task handling should decompose complex requests rather than relying on single-shot reasoning. |

### SUGGESTS ADDITION (new capability needed)

| Finding | Evidence | Component | Severity | Notes |
|---------|----------|-----------|----------|-------|
| Tool result parsing as injection defense layer | #13 Tool Result Parsing | Security (Tron) | HIGH | Tron spec covers input injection defense but doesn't specifically address tool result parsing. MVP web tool (M8.3) returns external content that could contain injected instructions. |
| InstruCoT methodology for future ML-based injection detection | #14 InstruCoT | Security (Tron) | MEDIUM | Provides three evaluation dimensions (Behavior Deviation, Privacy Leakage, Harmful Output) and a concrete training methodology for when Tron evolves beyond hardcoded patterns. |
| Self-evolving rubrics as quality assessment mechanism | #7 RLCER | LLM Integration (Ralph Loop) | MEDIUM | Self-generated rubrics could serve as the evaluation mechanism for the Ralph Loop. Also: rubrics as in-prompt hints could improve current prompt design. |
| POMDP/belief-state framework for act-vs-ask decisions | #11 Belief Functions | Resilience (Autonomous Operation) | MEDIUM | Autonomous operation spec doesn't formally model uncertainty. POMDP framework provides mathematical basis for when Ember should act vs. ask for confirmation. |

### WARNING (new threat or failure mode)

| Finding | Evidence | Component | Severity | Notes |
|---------|----------|-----------|----------|-------|
| Alignment concentrates in fragile low-dimensional subspaces | #1 Alignment Collapse | Security, LLM Integration | MEDIUM | Even benign fine-tuning can degrade safety with quartic scaling. Risk if EmberHearth ever uses fine-tuned model variants or if providers fine-tune models between versions. |
| 4-bit quantization breaks multi-hop reasoning and increases energy | #3 Quantization Trap | LLM Integration, Platform | MEDIUM | Phase 2.0 MLX strategy should not default to aggressive quantization. Multi-hop reasoning degrades non-linearly; energy savings are illusory for complex tasks. |
| Multi-agent teams degrade expert performance by up to 37.6% | #6 Teams Hold Experts Back | Architecture | MEDIUM | Phase 2.0 multi-agent design must avoid naive team consensus. Explicit role specification and workflow design are required. |
| Multi-agent distillation may eliminate need for some agent roles | #5 AgentArk | Architecture | LOW | If multi-agent reasoning can be distilled into a single model, some planned Cognitive Agents may be unnecessary. Monitor this research. |
| Claude Opus 4.6 fails on complex multi-step reasoning | #12 Claude Evaluation | LLM Integration, Resilience | HIGH | Primary LLM exhibits trial-and-error without strategy on complex logic, thinking mode crashes. Error handling must account for these specific failure modes. |
| Step-wise reasoning creates greedy policies that fail over long horizons | #9 Why Reasoning Fails | LLM Integration, Resilience | MEDIUM | If Ember is asked to plan multi-step tasks, step-by-step reasoning may produce locally optimal but globally suboptimal results. Future autonomous operation needs look-ahead. |

---

## Phase 4: Proposals

### Proposal 2026-02-26-01: Update ContextBuilder Design for Structure-Aware Context Assembly

- **Category:** SUGGESTS CHANGE
- **Severity:** HIGH
- **Affected Components:** LLM Integration (ContextBuilder, ContextBudget), Memory (FactRetriever)
- **Evidence:** [ICL Representations](../../papers/2026-02-04-language-models-struggle-representations-in-context.md), [Context Structure Reshapes Geometry](../../papers/2026-01-29-context-structure-reshapes-representational-geometry.md), [Why Reasoning Fails to Plan](../../papers/2026-01-29-why-reasoning-fails-to-plan.md)
- **Current State:** `docs/architecture-overview.md` defines ContextBuilder budget allocation (10% system, 25% recent, 10% summary, 15% memories, 5% tasks, 35% response) as a token budget. No guidance on ordering, framing, or structural effects.
- **Proposed Change:** Update ContextBuilder section of `docs/architecture-overview.md` to add:
  1. **Ordering guidance:** System prompt first, then memories framed as instructions, then recent conversation, then task state. Document that ordering affects representational geometry.
  2. **Memory framing principle:** FactRetriever should output memories as imperative instructions ("Always remember: user prefers X") rather than informational statements ("User has mentioned X"). Update `docs/research/memory-learning.md` to reference ICL limitation findings.
  3. **Decomposition principle:** Complex requests should be decomposed into steps rather than handled as single-shot prompts. Note in personality spec that Ember should break down multi-step requests.
- **Effort Estimate:** small
- **Risk to In-Flight Work:** low (design doc updates, informs M3.2 ContextBuilder implementation)
- **Workplan Impact:** M3.2 (Context builder), M4.3 (Fact retrieval + context injection)

### Proposal 2026-02-26-02: Document Claude-Specific Failure Modes and Design Resilience

- **Category:** WARNING
- **Severity:** HIGH
- **Affected Components:** LLM Integration (ClaudeProvider), Resilience (error handling)
- **Evidence:** [Claude Opus 4.6 Thinking vs Non-Thinking](../../youtube/discoverai/2026-02-05-claude-opus-4-6-thinking-vs-non-thinking.md)
- **Current State:** `docs/specs/error-handling.md` covers generic component failures and crash recovery. ADR-0008 selects Claude API as primary LLM. No documentation of Claude-specific failure modes.
- **Proposed Change:**
  1. Add a "Claude Provider Failure Modes" section to `docs/specs/error-handling.md` documenting: thinking mode crashes/loops, trial-and-error degradation on complex logic, lack of strategic planning on multi-step tasks.
  2. Update `docs/specs/error-handling.md` to specify graceful degradation when thinking mode returns errors: retry without thinking mode, then fall back to simplified prompt.
  3. Add a note in `docs/research/conversation-design.md` that prompt design should avoid requiring long-horizon logical chains from a single Claude call.
- **Effort Estimate:** small
- **Risk to In-Flight Work:** none (documentation updates)
- **Workplan Impact:** M3.1 (Claude API client), M8.1 (Error states + recovery)

### Proposal 2026-02-26-03: Add Tool Result Parsing to Tron Security Design

- **Category:** SUGGESTS ADDITION
- **Severity:** HIGH
- **Affected Components:** Security (Tron, TronFilter)
- **Evidence:** [Defense Against Indirect Prompt Injection via Tool Result Parsing](../../papers/2026-01-08-defense-indirect-prompt-injection-tool-result-parsing.md)
- **Current State:** `docs/specs/tron-security.md` defines inbound pipeline (injection defense, known-bad patterns, PII scanning) focused on user-initiated messages. MVP includes web tool (M8.3 WebFetcher) that returns external content. Tron doesn't specifically address parsing/sanitizing tool results before they enter the LLM context.
- **Proposed Change:**
  1. Add a "Tool Result Sanitization" section to `docs/specs/tron-security.md` specifying that all external content (web fetches, future Apple framework results) must pass through Tron's inbound pipeline before context injection.
  2. Define tool result parsing rules: strip instruction-like content from web page text, flag embedded prompts, extract only requested data.
  3. Add to M8.3 (Web tool) implementation requirements: WebFetcher output must be Tron-filtered before reaching ContextBuilder.
- **Effort Estimate:** small (spec update now, implementation in M6.2 + M8.3)
- **Risk to In-Flight Work:** low (aligns with existing security design direction)
- **Workplan Impact:** M6.2 (Basic Tron injection/credential filtering), M8.3 (Web tool)

### Proposal 2026-02-26-04: Document Alignment Collapse Risk in Model Selection Criteria

- **Category:** CONFIRMS
- **Severity:** MEDIUM
- **Affected Components:** LLM Integration, Security
- **Evidence:** [Geometry of Alignment Collapse](../../papers/2026-02-17-geometry-of-alignment-collapse.md)
- **Current State:** ADR-0008 selects Claude API as primary LLM. No explicit documentation of why base API models are preferred over fine-tuned variants from a safety perspective.
- **Proposed Change:** Add a "Model Selection Safety Criteria" note to `docs/architecture-overview.md` LLMService section documenting: (1) fine-tuned models have geometrically fragile safety (quartic degradation), (2) base API models are preferred for safety-critical applications, (3) if future phases evaluate fine-tuned or third-party models, alignment stability must be a selection criterion.
- **Effort Estimate:** small
- **Risk to In-Flight Work:** none
- **Workplan Impact:** None (future model selection guidance)

### Proposal 2026-02-26-05: Document Quantization Constraints for Local Model Strategy

- **Category:** WARNING
- **Severity:** MEDIUM
- **Affected Components:** LLM Integration (LocalProvider), Platform
- **Evidence:** [Quantization Trap](../../papers/2026-02-14-quantization-trap-multi-hop-reasoning.md)
- **Current State:** `docs/research/local-models.md` covers MLX and model selection. Architecture overview mentions MLX runtime for Phase 2.0. No guidance on quantization constraints for reasoning tasks.
- **Proposed Change:** Update `docs/research/local-models.md` to add a "Quantization Constraints" section documenting: (1) 4-bit quantization breaks multi-hop reasoning non-linearly, (2) paradoxically increases energy consumption due to dequantization overhead, (3) minimum 8-bit precision recommended for reasoning tasks, (4) quantization acceptable only for simple classification/extraction tasks.
- **Effort Estimate:** small
- **Risk to In-Flight Work:** none (Phase 2.0 planning)
- **Workplan Impact:** Phase 2.0 "Hearth" (MLX runtime, model management)

### Proposal 2026-02-26-06: Document Multi-Agent Design Warnings

- **Category:** WARNING
- **Severity:** MEDIUM
- **Affected Components:** Architecture (Multi-Agent)
- **Evidence:** [Multi-Agent Teams Hold Experts Back](../../papers/2026-02-01-multi-agent-teams-hold-experts-back.md), [AgentArk Distillation](../../papers/2026-02-03-agentark-distilling-multi-agent-intelligence.md)
- **Current State:** `docs/research/multi-agent-orchestration.md` describes Task Agents + Cognitive Agents. `docs/architecture-overview.md` plans multi-agent for Phase 2.0.
- **Proposed Change:** Update `docs/research/multi-agent-orchestration.md` to add a "Known Risks" section documenting: (1) team consensus degrades expert performance by up to 37.6% — require explicit role specification and workflow design, (2) distillation may eliminate the need for some agent roles — evaluate single-model distillation as a lighter alternative before committing to full multi-agent deployment.
- **Effort Estimate:** small
- **Risk to In-Flight Work:** none (Phase 2.0 planning)
- **Workplan Impact:** Phase 2.0 "Hearth" (multi-agent foundation)

### Proposal 2026-02-26-07: Reference Self-Evolving Rubrics for Ralph Loop Design

- **Category:** SUGGESTS ADDITION
- **Severity:** MEDIUM
- **Affected Components:** LLM Integration (Ralph Loop)
- **Evidence:** [Reinforcing CoT with Self-Evolving Rubrics](../../papers/2026-02-11-reinforcing-chain-of-thought-self-evolving-rubrics.md)
- **Current State:** `docs/research/iterative-quality-loops.md` describes the Ralph Loop (spec → action → review → iterate) but doesn't specify a concrete evaluation mechanism.
- **Proposed Change:** Update `docs/research/iterative-quality-loops.md` to reference RLCER's self-evolving rubrics as a candidate evaluation mechanism for the Ralph Loop's review step. Note that rubrics can also serve as in-prompt hints during inference to improve reasoning quality.
- **Effort Estimate:** small
- **Risk to In-Flight Work:** none (Phase 2.0 planning)
- **Workplan Impact:** Phase 2.0 "Hearth" (Ralph Loop)

### Proposal 2026-02-26-08: Add Uncertainty Framework Reference to Autonomous Operation Spec

- **Category:** SUGGESTS ADDITION
- **Severity:** MEDIUM
- **Affected Components:** Resilience (Autonomous Operation), Personality
- **Evidence:** [AI Belief Functions / Deciding Under Absolute Uncertainty](../../youtube/discoverai/2026-02-14-ai-belief-functions-deciding-under-absolute-uncertainty.md)
- **Current State:** `docs/specs/autonomous-operation.md` covers self-healing and circuit breakers. No formal uncertainty model for "when to act vs. when to ask" decisions. `docs/VISION.md` describes the Anticipation Engine's Intrusion Gate but without mathematical grounding.
- **Proposed Change:** Add a "Decision Under Uncertainty" subsection to `docs/specs/autonomous-operation.md` referencing the POMDP/belief-state framework as a design principle: (1) Ember should maintain a confidence estimate for each proposed action, (2) actions below a confidence threshold should prompt user confirmation, (3) the threshold can be adaptive based on action reversibility and user preferences.
- **Effort Estimate:** small
- **Risk to In-Flight Work:** none (future phase planning)
- **Workplan Impact:** Phase 1.2 "Flame" (proactive features), future autonomous operation

### Proposal 2026-02-26-09: Reference InstruCoT for Future ML-Based Tron

- **Category:** SUGGESTS ADDITION
- **Severity:** MEDIUM
- **Affected Components:** Security (Tron)
- **Evidence:** [Know Thy Enemy: InstruCoT](../../papers/2026-01-08-know-thy-enemy-prompt-injection-instrucot.md)
- **Current State:** `docs/specs/tron-security.md` specifies hardcoded patterns for MVP with future ML-based detection planned. No specific methodology referenced for the ML evolution.
- **Proposed Change:** Add a "Future: ML-Based Detection" subsection to `docs/specs/tron-security.md` referencing InstruCoT's approach: (1) diverse data synthesis for training injection detectors, (2) instruction-level chain-of-thought for detection reasoning, (3) three evaluation dimensions (Behavior Deviation, Privacy Leakage, Harmful Output) as useful test categories for Tron.
- **Effort Estimate:** small
- **Risk to In-Flight Work:** none
- **Workplan Impact:** Phase 1.2 "Flame" (full Tron XPC)

---

## Summary

- **Total items triaged:** 14
- **Items with relevance:** 12
- **CONFIRMS findings:** 3
- **Change proposals:** 3 (Proposals 01, 02, 04)
- **Addition proposals:** 4 (Proposals 03, 07, 08, 09)
- **Warnings:** 4 (Proposals 02, 05, 06, and 2 LOW-severity noted in gap analysis)
- **Proposals generated:** 9
