# Local Model Feasibility Research

**Status:** Complete
**Priority:** High (Phase 1)
**Last Updated:** February 2, 2026

---

## Overview

This document evaluates the feasibility of running LLMs locally on Apple Silicon for EmberHearth's assistant functionality. The goal is to determine if local models can provide acceptable quality and performance for users who prefer not to use cloud APIs.

---

## Executive Summary

**Local LLM feasibility depends heavily on RAM:**

| RAM | Feasibility | Best Models | User Experience |
|-----|-------------|-------------|-----------------|
| **8GB** | Limited | Phi-3 Mini, Llama 3.2 3B | Basic assistant tasks only |
| **16GB** | Moderate | Llama 3.2 8B, Gemma 3 12B | Good for most tasks |
| **24GB** | Good | Qwen 2.5 14B, Mistral Small 24B | Near cloud-quality |
| **32GB+** | Excellent | Qwen3 30B, Llama 3.3 70B (Q4) | Full assistant capability |

**Recommendation:** Support cloud APIs as primary, with local models as an optional feature for users with 16GB+ RAM.

---

## Hardware Landscape

### Apple Silicon Memory Architecture

Apple Silicon uses Unified Memory Architecture (UMA) where CPU, GPU, and Neural Engine share one memory pool. This eliminates the GPU VRAM bottleneck found in discrete GPU setups—models can use nearly all available RAM.

Key insight: **Memory bandwidth is as important as capacity** for token generation speed. The M4 Pro's 275GB/s bandwidth significantly outperforms base M4's 120GB/s.

### Mac Hardware Tiers

| Configuration | RAM | Bandwidth | LLM Suitability |
|---------------|-----|-----------|-----------------|
| Mac Mini M4 (base) | 16GB | 120GB/s | Entry-level local LLM |
| Mac Mini M4 (upgraded) | 32GB | 120GB/s | Mid-range models |
| Mac Mini M4 Pro | 24-64GB | 273GB/s | Excellent performance |
| MacBook Pro M4 Pro | 24-48GB | 273GB/s | Mobile + fast |
| Mac Studio M3 Ultra | 64-192GB | 800GB/s | Run anything locally |
| Mac Studio M4 Ultra | 128-512GB | 800GB/s | DeepSeek 671B feasible |

### M5 Neural Accelerators (Late 2025+)

Apple's M5 chips include dedicated Neural Accelerators that provide **up to 4x speedup** for time-to-first-token compared to M4. This significantly improves local LLM viability for future hardware.

---

## Runtime Comparison

### Benchmark Results (October 2025 Research Paper)

Testing on Mac Studio M2 Ultra with Qwen-2.5 models:

| Runtime | Throughput | Notes |
|---------|------------|-------|
| **MLX** | ~230 tok/s | Highest sustained throughput |
| **MLC-LLM** | ~190 tok/s | Best time-to-first-token |
| **llama.cpp** | ~150 tok/s | Short context only |
| **Ollama** | 20-40 tok/s | Easy setup, but slower |
| **PyTorch MPS** | ~7-9 tok/s | Not recommended |

### Recommendation: MLX

MLX is Apple's machine learning framework, specifically optimized for Apple Silicon. Benefits:

1. **Highest performance** on Mac hardware
2. **Memory efficient** - uses unified memory effectively
3. **Active development** by Apple ML Research
4. **Wide model support** - Qwen, Llama, Mistral, and more

**Caveat:** MLX requires more technical setup than Ollama. For user-friendly deployment, consider wrapping MLX in a service or using LM Studio (which supports MLX models).

### Ollama: Simple but Slower

Ollama offers the easiest setup but runs 5-10x slower than MLX because it uses llama.cpp's Metal backend rather than native MLX optimization.

**Important:** Running Ollama in Docker on Mac provides only CPU access (no GPU), resulting in even slower performance. Always run Ollama natively.

---

## Model Recommendations by RAM Tier

### 8GB RAM (Mac Mini M4 Base, MacBook Air)

**Reality check:** 8GB is severely limiting. Only ~6GB is usable for models after system overhead.

| Model | Parameters | Quantization | Quality |
|-------|------------|--------------|---------|
| **Phi-3 Mini** | 3.8B | Q4 | Good for simple tasks |
| **Llama 3.2 3B** | 3B | Q4 | Fast, reasonable quality |
| **Qwen 2.5 3B** | 3B | Q4 | Good instruction following |

**Expected performance:** ~12 tok/s on M-series base chips.

**Limitations:**
- No complex reasoning
- Limited context window (often 4K tokens practical)
- May struggle with multi-step tasks
- Not suitable as primary assistant

### 16GB RAM

| Model | Parameters | Quantization | RAM Usage | Quality |
|-------|------------|--------------|-----------|---------|
| **Gemma 3 12B** | 12B | Q4 | ~8GB | Good general chat |
| **Llama 3.2 8B** | 8B | Q4 | ~5GB | Solid all-around |
| **Qwen 2.5 7B** | 7B | Q4 | ~5GB | Strong instruction following |
| **Mistral 7B** | 7B | Q4 | ~5GB | Fast, capable |

**Expected performance:** 10-15 tok/s with quantized models.

**Good for:**
- Calendar queries
- Simple reminders
- Weather/information lookup
- Basic note-taking

**Struggles with:**
- Complex multi-step planning
- Nuanced conversation
- Long context (>8K tokens)

### 24GB RAM (M4 Pro Base)

| Model | Parameters | Quantization | RAM Usage | Quality |
|-------|------------|--------------|-----------|---------|
| **Qwen 2.5 14B** | 14B | Q4 | ~10GB | Excellent all-around |
| **Mistral Small 24B** | 24B | Q4 | ~14GB | Near GPT-4 quality |
| **Gemma 3 27B** | 27B | Q4 | ~16GB | Strong vision + chat |
| **Llama 3.1 8B** | 8B | BF16 | ~16GB | Full precision option |

**Expected performance:** 15-25 tok/s depending on model and bandwidth.

**Sweet spot for most users.** These models can handle:
- Complex scheduling
- Email drafting
- Multi-step task planning
- Reasonable conversation quality

### 32GB+ RAM

| Model | Parameters | Quantization | RAM Usage | Quality |
|-------|------------|--------------|-----------|---------|
| **Qwen3 30B A3B** | 30B (3B active) | Q4 | ~17GB | MoE efficiency |
| **Qwen 2.5 32B** | 32B | Q4 | ~18GB | Top-tier coding |
| **Llama 3.3 70B** | 70B | Q4 | ~42GB | GPT-4 class |
| **DeepSeek V3** | 685B | Q4 | ~400GB | SOTA (Mac Studio only) |

**64GB+** unlocks Llama 3.3 70B and other frontier-class models that rival cloud APIs.

---

## Function Calling / Tool Use

Not all local models support function calling well. For EmberHearth's MCP-style tool use:

### Models with Good Tool Support

| Model | Function Calling | Notes |
|-------|------------------|-------|
| **Qwen 2.5** (all sizes) | Excellent | Native tool support |
| **Qwen3** | Excellent | Supports function calling |
| **GLM-4** | Good | Designed for agents |
| **Mistral** (large) | Good | Reliable tool use |
| **Llama 3.1/3.2/3.3** | Moderate | Requires careful prompting |

### Models with Limited Tool Support

| Model | Function Calling | Notes |
|-------|------------------|-------|
| **Phi-3** | Basic | Not designed for tools |
| **Gemma** | Limited | Better for chat |

**Recommendation:** Prioritize Qwen 2.5 family for EmberHearth's local model support due to excellent function calling capabilities.

---

## Performance Benchmarks

### Assistant Task Latency (Target: <3 seconds for first response)

| Task | 8B Model | 14B Model | 32B Model |
|------|----------|-----------|-----------|
| "What's on my calendar?" | ~1.5s | ~2s | ~3s |
| "Draft an email reply" | ~3s | ~4s | ~6s |
| "Plan my morning routine" | ~4s | ~5s | ~8s |

### Quality Assessment (Subjective, 1-5 scale)

| Task | 3B Model | 8B Model | 14B Model | Cloud API |
|------|----------|----------|-----------|-----------|
| Simple queries | 3/5 | 4/5 | 5/5 | 5/5 |
| Complex reasoning | 2/5 | 3/5 | 4/5 | 5/5 |
| Natural conversation | 2/5 | 3/5 | 4/5 | 5/5 |
| Tool use accuracy | 2/5 | 3/5 | 4/5 | 5/5 |

---

## Thermal Considerations

Running LLM inference generates significant heat:

| Device | Sustained Load Behavior |
|--------|-------------------------|
| MacBook Air | Throttles after 5-10 min |
| MacBook Pro | Fan noise, stable performance |
| Mac Mini | Good thermals, sustained load OK |
| Mac Studio | Excellent, designed for continuous load |

For an always-on assistant like EmberHearth, **Mac Mini or Mac Studio** is recommended over laptops.

---

## EmberHearth Integration Strategy

### Recommended Approach

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         EmberHearth LLM Layer                                │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌─────────────────────┐    │
│  │ Cloud API  │  │ Local Only │  │  Simple    │  │ Orchestrated Hybrid │    │
│  │ (Default)  │  │ (Privacy)  │  │  Hybrid    │  │ (Recommended v2+)   │    │
│  └────────────┘  └────────────┘  └────────────┘  └─────────────────────┘    │
│                                                                              │
│  - Claude API    - Qwen 2.5 14B+ - Route by     - Cloud = Planner          │
│  - OpenAI API    - Requires 16GB+  complexity   - Local = Executors         │
│  - Works on all  - Full privacy  - Auto-detect  - Privacy + Cost savings    │
│    hardware      - No API needed - Cost savings - Best of both worlds       │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Mode 1: Cloud API Only (Default)

- Support Claude, OpenAI, and OpenAI-compatible APIs
- User provides API key
- Works on all hardware configurations
- Best quality and reliability
- **Use case:** Users with 8GB Macs, users who want simplest setup

### Mode 2: Local Model Only (Privacy Mode)

- MLX runtime with Qwen 2.5 family
- Requires 16GB+ RAM for acceptable quality
- Zero data leaves the device
- No API key or subscription required
- **Use case:** Privacy-focused users, offline operation

### Mode 3: Simple Hybrid (Auto-Routing)

- Route simple queries locally, complex queries to cloud
- Based on query complexity heuristics
- User-configurable threshold
- Basic cost optimization
- **Use case:** Cost-conscious users who want good quality

### Mode 4: Orchestrated Hybrid (Recommended for v2+)

**This is the most sophisticated and potentially most cost-effective approach.**

The cloud foundation model acts as an **orchestrator/planner** while local LLMs serve as **specialized executors**. This keeps sensitive data local while leveraging the superior reasoning of frontier models.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Orchestrated Hybrid Architecture                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   User: "What's on my calendar tomorrow and draft a response to            │
│          John's email about the project deadline"                          │
│                              │                                              │
│                              ▼                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                    CLOUD FOUNDATION MODEL                            │  │
│   │                    (Claude / GPT-4 / etc.)                           │  │
│   │                                                                       │  │
│   │   Role: Planner & Orchestrator                                       │  │
│   │   - Understands user intent                                          │  │
│   │   - Breaks task into subtasks                                        │  │
│   │   - Decides which local agents to invoke                             │  │
│   │   - Synthesizes final response                                       │  │
│   │   - Reviews/refines agent outputs                                    │  │
│   └──────────────────────────┬──────────────────────────────────────────┘  │
│                              │                                              │
│          ┌───────────────────┼───────────────────┐                         │
│          │                   │                   │                         │
│          ▼                   ▼                   ▼                         │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                  │
│   │ LOCAL AGENT │     │ LOCAL AGENT │     │ LOCAL AGENT │                  │
│   │ Calendar    │     │ Email       │     │ Draft       │                  │
│   │ Reader      │     │ Reader      │     │ Writer      │                  │
│   │             │     │             │     │             │                  │
│   │ Qwen 2.5 7B │     │ Qwen 2.5 7B │     │ Qwen 2.5 7B │                  │
│   │ (tool-tuned)│     │ (tool-tuned)│     │ (instruct)  │                  │
│   └──────┬──────┘     └──────┬──────┘     └──────┬──────┘                  │
│          │                   │                   │                         │
│          ▼                   ▼                   ▼                         │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                  │
│   │  EventKit   │     │  Mail.app   │     │  Structured │                  │
│   │  API        │     │  AppleScript│     │  Output     │                  │
│   └─────────────┘     └─────────────┘     └─────────────┘                  │
│                                                                             │
│   Data flow: Sensitive content (email body, calendar details) stays        │
│   LOCAL. Only structured summaries/metadata go to cloud when needed.       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Benefits:**

1. **Privacy**: Personal data (email content, calendar details, notes) processed by local agents—never sent to cloud API
2. **Cost Efficiency**: Cloud model only receives:
   - User's original request
   - Structured summaries from local agents (not raw data)
   - Its own reasoning/planning tokens
3. **Quality**: Foundation model's superior reasoning for planning while local models handle execution
4. **Latency**: Local agents can execute in parallel; no network round-trip for data retrieval

**Token Flow Example:**

```
WITHOUT Orchestrated Hybrid:
┌────────────────────────────────────────────────────────────────┐
│ Tokens to Cloud API:                                           │
│ - User prompt: ~50 tokens                                      │
│ - Full email content: ~500 tokens                              │
│ - Full calendar data: ~200 tokens                              │
│ - System prompt: ~200 tokens                                   │
│ - Response: ~300 tokens                                        │
│ TOTAL: ~1,250 tokens                                           │
└────────────────────────────────────────────────────────────────┘

WITH Orchestrated Hybrid:
┌────────────────────────────────────────────────────────────────┐
│ Tokens to Cloud API:                                           │
│ - User prompt: ~50 tokens                                      │
│ - Planning prompt: ~100 tokens                                 │
│ - Agent summaries: ~150 tokens (structured, not raw)           │
│ - Response: ~300 tokens                                        │
│ TOTAL: ~600 tokens                                             │
│                                                                │
│ Tokens to Local Agents (FREE):                                 │
│ - Calendar agent: ~300 tokens                                  │
│ - Email agent: ~600 tokens                                     │
│ - Draft agent: ~400 tokens                                     │
└────────────────────────────────────────────────────────────────┘

Savings: ~50% reduction in cloud API tokens
```

**When to Use Each Agent Type:**

| Task | Cloud Orchestrator | Local Agent |
|------|-------------------|-------------|
| Understanding intent | ✓ | |
| Multi-step planning | ✓ | |
| Reading calendar/email | | ✓ |
| Extracting structured data | | ✓ |
| Generating first drafts | | ✓ |
| Complex reasoning | ✓ | |
| Final response synthesis | ✓ | |
| Quality review/refinement | ✓ | |

---

## Cost & Performance Monitoring

**Critical for validating the orchestrated hybrid approach.** The macOS app should include a monitoring dashboard to track efficiency gains during development and in production.

### Metrics to Track

```swift
struct UsageMetrics {
    // Token usage
    var cloudInputTokens: Int
    var cloudOutputTokens: Int
    var localInputTokens: Int
    var localOutputTokens: Int

    // Cost
    var estimatedCloudCost: Decimal  // Based on provider pricing
    var estimatedSavings: Decimal    // vs. cloud-only approach

    // Performance
    var cloudLatencyMs: Int
    var localLatencyMs: Int
    var totalResponseTimeMs: Int

    // Quality (user feedback)
    var userRating: Int?             // Optional thumbs up/down
    var wasEdited: Bool              // Did user modify the response?
}
```

### Monitoring Dashboard (macOS App)

```
┌─────────────────────────────────────────────────────────────────┐
│  EmberHearth > Settings > Usage & Monitoring                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  This Week's Usage                                              │
│  ─────────────────                                              │
│  Total conversations: 127                                       │
│  Cloud API tokens: 45,230 (↓ 48% vs cloud-only estimate)       │
│  Local agent tokens: 89,450                                     │
│                                                                 │
│  Estimated Costs                                                │
│  ───────────────                                                │
│  Cloud API cost: $2.14                                          │
│  Estimated if cloud-only: $4.12                                 │
│  Savings this week: $1.98 (48%)                                │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Token Usage Over Time                                    │  │
│  │                                                           │  │
│  │  4k ┤                                    ╭─╮              │  │
│  │     │                              ╭─────╯ │              │  │
│  │  2k ┤    ╭───╮   ╭─────╮     ╭────╯       │              │  │
│  │     │╭───╯   ╰───╯     ╰─────╯            ╰──            │  │
│  │   0 ┼─────────────────────────────────────────           │  │
│  │      Mon   Tue   Wed   Thu   Fri   Sat   Sun             │  │
│  │                                                           │  │
│  │  ▬ Cloud tokens  ▬ Local tokens                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Performance                                                    │
│  ───────────                                                    │
│  Avg response time: 1.8s                                        │
│  Cloud latency: 0.9s | Local processing: 0.7s | Overhead: 0.2s │
│                                                                 │
│  Agent Utilization                                              │
│  ─────────────────                                              │
│  Calendar agent: 34 calls (avg 0.3s)                           │
│  Email agent: 28 calls (avg 0.5s)                              │
│  Notes agent: 19 calls (avg 0.2s)                              │
│  Draft agent: 45 calls (avg 0.8s)                              │
│                                                                 │
│  [Export Data]  [Clear History]  [Compare Modes]               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### A/B Testing Mode

For development validation, support running both modes and comparing:

```
┌─────────────────────────────────────────────────────────────────┐
│  Mode Comparison (Last 7 Days)                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                    Cloud-Only    Orchestrated    Difference     │
│  ──────────────    ──────────    ────────────    ──────────     │
│  Token usage       89,450        45,230          -49%          │
│  Est. cost         $4.12         $2.14           -48%          │
│  Avg latency       1.2s          1.8s            +50%          │
│  Quality score     4.5/5         4.3/5           -4%           │
│                                                                 │
│  Recommendation: Orchestrated hybrid provides significant       │
│  cost savings with minimal quality impact. Latency increase     │
│  is acceptable for most use cases.                              │
│                                                                 │
│  [Enable A/B Testing]  [Set Sample Rate: 20%]                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Comparison to Moltbot

| Feature | EmberHearth (Orchestrated) | Moltbot |
|---------|---------------------------|---------|
| Local agent execution | ✓ (MLX native) | ✓ (Ollama) |
| Cloud orchestration | ✓ | ✓ |
| Privacy preservation | ✓ (data stays local) | Varies by skill |
| Cost tracking | ✓ (built-in dashboard) | Manual |
| Token optimization | ✓ (structured summaries) | Basic |
| macOS integration | ✓ (native APIs) | Generic |
| A/B testing | ✓ | ✗ |

EmberHearth's advantage: **Deep macOS integration** means local agents can access native APIs (EventKit, Contacts, etc.) directly, rather than relying on generic file/shell access.

---

## Self-Tuning Architecture

**Problem:** Users configure their model preferences during onboarding, then forget about it. If local model performance degrades, quality drops, or latency becomes unacceptable, users may not realize the fix is in settings they configured months ago.

**Solution:** EmberHearth should be **self-healing and self-annealing**—automatically adjusting the local/cloud balance based on observed performance and user satisfaction signals.

### Performance Signals

The system continuously monitors:

```swift
struct PerformanceSignals {
    // Latency
    var avgResponseTimeMs: Double
    var p95ResponseTimeMs: Double
    var timeoutsCount: Int

    // Reliability
    var localModelFailures: Int
    var retryCount: Int
    var fallbackToCloudCount: Int

    // Resource pressure
    var memoryPressureEvents: Int
    var thermalThrottlingDetected: Bool
}
```

### Quality Signals

Implicit and explicit indicators of user satisfaction:

```swift
struct QualitySignals {
    // Explicit feedback
    var thumbsUp: Int
    var thumbsDown: Int
    var feedbackRatio: Double  // thumbsUp / total

    // Implicit signals
    var responseEditedByUser: Bool      // User modified the response
    var queryRepeatedImmediately: Bool  // User asked same thing again
    var conversationAbandoned: Bool     // User stopped mid-task

    // Frustration detection
    var shortFollowUpResponses: Int     // "no", "wrong", "try again"
    var multipleRetries: Int            // Same query rephrased
    var responseTime: Double            // Long pause = thinking/frustration?
}
```

### Mood Detection (Lightweight)

Not full sentiment analysis, but pattern recognition for frustration:

| Pattern | Signal | Action |
|---------|--------|--------|
| "No, I meant..." | Misunderstanding | Log for quality review |
| Same query 3x in 5 min | Frustration | Escalate to cloud |
| "Forget it" / abandonment | Failure | Log + escalate future similar queries |
| Quick thumbs down | Poor quality | Immediate cloud retry option |
| Consistently slow responses | Latency issue | Shift more to cloud |

### Adaptive Routing Engine

**Related:** `docs/research/work-personal-contexts.md`

The routing engine must be context-aware. Work and personal contexts may have different routing policies.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Context-Aware Adaptive Routing Engine                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   User Query + Context                                                      │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     CONTEXT POLICY CHECK                             │  │
│   │                                                                       │  │
│   │   if context == .work && workPolicy.requireLocalOnly:               │  │
│   │       → Force local routing (skip adaptive decision)                │  │
│   │   else:                                                              │  │
│   │       → Continue to adaptive routing                                 │  │
│   │                                                                       │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     ROUTING DECISION                                 │  │
│   │                                                                       │  │
│   │   Inputs:                                                            │  │
│   │   ├── Context (.personal | .work)                 ← NEW             │  │
│   │   ├── Context-specific policy constraints         ← NEW             │  │
│   │   ├── Query complexity score (heuristic)                            │  │
│   │   ├── Recent local model performance (rolling window)               │  │
│   │   ├── Recent quality signals (last 24h, per context)                │  │
│   │   ├── Current system state (memory, thermal)                        │  │
│   │   ├── User's configured preferences (privacy weight, per context)  │  │
│   │   └── Historical success rate for similar queries (per context)    │  │
│   │                                                                       │  │
│   │   Output: { route: "local" | "cloud" | "hybrid", confidence: 0-1 }  │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                    │
│        ├──────────────────┬──────────────────┐                             │
│        ▼                  ▼                  ▼                             │
│   ┌─────────┐        ┌─────────┐        ┌─────────┐                        │
│   │  Local  │        │  Cloud  │        │ Hybrid  │                        │
│   │  Agent  │        │   API   │        │  (Both) │                        │
│   └─────────┘        └─────────┘        └─────────┘                        │
│        │                  │                  │                             │
│        └──────────────────┴──────────────────┘                             │
│                           │                                                │
│                           ▼                                                │
│               Context-Scoped Feedback Loop                                 │
│               (Learning is per-context, never crossed)                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Per-Context LLM Configuration

Each context can have different LLM settings:

```swift
struct ContextLLMConfig {
    var context: Context

    // Provider settings
    var cloudProvider: LLMProvider?     // nil = local only
    var cloudAPIKey: String?
    var localModelPath: String?

    // Routing constraints
    var allowCloudAPI: Bool             // false = local only (work policy)
    var preferLocal: Bool               // Bias toward local even when cloud allowed

    // Self-tuning
    var performanceHistory: PerformanceHistory  // Per-context metrics
    var qualitySignals: QualitySignals          // Per-context feedback
}

// Example configurations:
let personalConfig = ContextLLMConfig(
    context: .personal,
    cloudProvider: .claude,
    cloudAPIKey: "sk-...",
    localModelPath: "/models/qwen2.5-14b",
    allowCloudAPI: true,
    preferLocal: false
)

let workConfig = ContextLLMConfig(
    context: .work,
    cloudProvider: nil,           // Local only - corporate policy
    cloudAPIKey: nil,
    localModelPath: "/models/qwen2.5-14b",
    allowCloudAPI: false,         // Enforced by policy
    preferLocal: true
)
```

### Context Policy Enforcement

Work context may have strict requirements that override self-tuning:

```swift
func route(query: Query, context: Context) -> LLMRoute {
    let policy = getPolicy(for: context)

    // Policy constraints override adaptive routing
    if !policy.allowCloudAPI {
        return .localOnly(reason: "Work policy requires local processing")
    }

    // Otherwise, adaptive routing proceeds
    return adaptiveRouter.decide(query, context: context)
}
```

### Self-Annealing Behavior

The system adjusts its local/cloud balance over time:

**Initial State (Post-Onboarding):**
```
User chose: "Hybrid mode, prefer privacy"
Initial weights: Local 70% / Cloud 30%
```

**After 1 Week (Good Performance):**
```
Local success rate: 92%
Avg latency: 1.4s
Quality score: 4.2/5
→ Maintain: Local 70% / Cloud 30%
```

**After 1 Month (Degradation Detected):**
```
Local success rate: 78% (↓)
Avg latency: 2.8s (↑)
Quality score: 3.4/5 (↓)
→ Auto-adjust: Local 50% / Cloud 50%
→ Notify user: "I've shifted some tasks to cloud for better responses"
```

**After User Upgrades RAM:**
```
System detects: 32GB RAM (was 16GB)
→ Offer: "You now have more memory. Want to try running more locally?"
→ If accepted, gradually increase local weight with monitoring
```

### Graceful Degradation

When local models fail, the system should recover transparently:

```
┌────────────────────────────────────────────────────────────────┐
│ Failure Scenario                    │ Automatic Response       │
├────────────────────────────────────────────────────────────────┤
│ Local model timeout (>5s)           │ Retry with cloud         │
│ Local model error                   │ Fallback to cloud        │
│ Memory pressure detected            │ Pause local, use cloud   │
│ Thermal throttling                  │ Reduce local load        │
│ Repeated low quality                │ Shift query type to cloud│
│ API key expired/invalid             │ Use local if possible    │
│ Network offline                     │ Local only (with warning)│
└────────────────────────────────────────────────────────────────┘
```

### User Transparency

Users should know when the system adapts, but not be overwhelmed:

**Subtle Notification (Default):**
```
EmberHearth: "I used cloud AI for this response to give you a faster answer."
[Gear icon] Tap to adjust preferences
```

**Monthly Summary (Optional):**
```
EmberHearth > Settings > Usage & Monitoring

This Month's Routing:
├── 340 queries routed locally (68%)
├── 160 queries routed to cloud (32%)
└── 12 automatic fallbacks (cloud saved the day!)

The system made 3 automatic adjustments:
• Feb 5: Shifted complex queries to cloud (quality improved 18%)
• Feb 12: Detected memory pressure, reduced local load
• Feb 18: Restored local routing after system stabilized
```

**Privacy-Sensitive Notification:**
```
⚠️ This query involves personal data. Processing locally for privacy.
   Response may take a moment longer. [Always do this] [Ask each time]
```

### Learning from Patterns

Over time, the system learns which query *types* work best where:

```swift
struct QueryTypePerformance {
    var queryCategory: String  // "calendar", "email_draft", "research", etc.
    var localSuccessRate: Double
    var cloudSuccessRate: Double
    var avgLocalLatency: Double
    var avgCloudLatency: Double
    var preferredRoute: Route
}

// Example learned patterns:
// "calendar_lookup"   → Local preferred (95% success, 0.3s)
// "email_draft"       → Local preferred (88% success, 1.2s)
// "complex_planning"  → Cloud preferred (72% local vs 94% cloud)
// "creative_writing"  → Cloud preferred (quality difference notable)
```

### Configuration Options

Users who *do* want control can access it:

```
EmberHearth > Settings > AI Routing

Automatic Optimization: [ON] / OFF
├── Let EmberHearth adjust routing based on performance
└── You'll be notified of significant changes

Privacy Weight: [────●───] More Privacy ←→ More Speed
├── Higher = prefer local even if slower
└── Lower = use cloud more freely

Manual Overrides:
├── Calendar queries: [Auto] / Local Only / Cloud Only
├── Email drafting:   [Auto] / Local Only / Cloud Only
├── Research:         [Auto] / Local Only / Cloud Only
└── Creative writing: [Auto] / Local Only / Cloud Only

Advanced:
├── Show routing decisions: OFF / [ON]
├── Fallback timeout: [5 seconds]
└── Reset learned preferences: [Reset]
```

---

## Implementation Phases

### Phase 1: Cloud API Only

- Support Claude, OpenAI, and OpenAI-compatible APIs
- User provides API key
- Works on all hardware configurations
- Basic usage tracking (tokens, cost estimate)

### Phase 2: Local Model Support

- Add MLX runtime integration
- Support Qwen 2.5 family (best tool use)
- Automatic hardware detection
- Download models via UI
- Local-only privacy mode

### Phase 3: Simple Hybrid

- Query complexity detection
- Automatic routing (simple → local, complex → cloud)
- User-configurable preferences
- Combined usage tracking

### Phase 4: Orchestrated Hybrid

- Agent framework for local execution
- Cloud model as orchestrator
- Structured data summaries (privacy-preserving)
- Full monitoring dashboard
- A/B testing infrastructure

### Phase 5: Self-Tuning Architecture

- Performance and quality signal collection
- Adaptive routing based on observed behavior
- Automatic fallback and graceful degradation
- Query-type learning (which tasks work best where)
- User-transparent adjustments with optional notifications
- Self-healing when local models underperform

---

## User Experience Design

### Hardware Detection

On first launch, detect:
1. Total RAM
2. Available RAM
3. Chip generation (M1/M2/M3/M4/M5)

Present appropriate options:

```
8GB RAM:
"Your Mac has 8GB of memory. For the best experience, we recommend
using a cloud API like Claude or OpenAI. Local models are available
but limited to basic tasks."

16GB RAM:
"Your Mac can run local AI models for basic assistant tasks. For more
complex reasoning, cloud APIs are recommended. You can use both!"

24GB+ RAM:
"Your Mac is well-suited for local AI models. You can run a capable
assistant entirely offline, or combine local and cloud for best results."
```

### Model Download Experience

```
EmberHearth > Settings > Local Models

Available Models:
┌────────────────────────────────────────────────────────────┐
│ Qwen 2.5 14B (Recommended)                                 │
│ Size: 8.2 GB  |  RAM: 24GB+  |  Quality: ★★★★☆            │
│ Best for: General assistant tasks, tool use                │
│ [Download]                                                 │
├────────────────────────────────────────────────────────────┤
│ Qwen 2.5 7B                                                │
│ Size: 4.5 GB  |  RAM: 16GB+  |  Quality: ★★★☆☆            │
│ Best for: Simple queries, quick responses                  │
│ [Download]                                                 │
├────────────────────────────────────────────────────────────┤
│ Llama 3.2 3B (Lightweight)                                 │
│ Size: 2.1 GB  |  RAM: 8GB+   |  Quality: ★★☆☆☆            │
│ Best for: Basic tasks on limited hardware                  │
│ [Download]                                                 │
└────────────────────────────────────────────────────────────┘
```

---

## Limitations & Honest Messaging

### What Local Models Cannot Do (As Well)

1. **Complex reasoning chains** - Multi-step logic suffers
2. **Very long contexts** - 32K+ token conversations
3. **Nuanced language** - Subtle tone, humor, emotional intelligence
4. **Rare knowledge** - Smaller models have less world knowledge
5. **Code generation** - Smaller models struggle with complex code

### Honest User Messaging

```
User: "Analyze this 50-page document and summarize it"
EmberHearth (local): "This task works best with a cloud API due to
the document length. Would you like me to:
1. Process just the first few pages locally
2. Switch to Claude API for this task
3. Break this into smaller chunks"
```

---

## Cost Comparison

### Cloud API Costs (Typical Usage: 1000 messages/month)

| Provider | Model | Est. Monthly Cost |
|----------|-------|-------------------|
| Anthropic | Claude 3 Sonnet | $5-15 |
| Anthropic | Claude 3 Opus | $15-40 |
| OpenAI | GPT-4o | $10-25 |
| OpenAI | GPT-4o mini | $2-5 |

### Local Model Costs

| Item | One-Time Cost | Monthly Cost |
|------|---------------|--------------|
| Mac Mini M4 16GB | $599 | $0 |
| Mac Mini M4 24GB | $799 | $0 |
| Mac Mini M4 Pro 24GB | $1,399 | $0 |
| Electricity | - | ~$5-10 |

**Break-even:** 6-18 months depending on usage and hardware choice.

---

## Security & Privacy Benefits

Local models provide:

1. **Data never leaves device** - True privacy
2. **No API keys to manage** - Reduced attack surface
3. **Works offline** - No internet dependency
4. **No rate limits** - Unlimited queries
5. **No vendor lock-in** - Switch models freely

This aligns well with EmberHearth's security-first philosophy.

---

## Implementation Checklist

### Phase 1 (Cloud APIs)
- [ ] Claude API integration
- [ ] OpenAI API integration
- [ ] OpenAI-compatible endpoint support
- [ ] API key secure storage (Keychain)
- [ ] Graceful error handling
- [ ] Basic token usage tracking

### Phase 2 (Local Models)
- [ ] MLX runtime integration
- [ ] Hardware detection (RAM, chip generation)
- [ ] Model download manager
- [ ] Model selection UI
- [ ] Local-only privacy mode
- [ ] Performance monitoring (tokens/sec, latency)

### Phase 3 (Simple Hybrid)
- [ ] Query complexity estimation heuristics
- [ ] Automatic routing logic
- [ ] User preferences for routing threshold
- [ ] Combined cloud + local usage tracking
- [ ] Basic cost tracking

### Phase 4 (Orchestrated Hybrid)
- [ ] Agent framework for local LLM execution
- [ ] Structured data extraction from local agents
- [ ] Cloud orchestrator integration (planning/synthesis)
- [ ] Privacy-preserving summaries (not raw data to cloud)
- [ ] Full monitoring dashboard
- [ ] Token savings calculator (vs cloud-only)
- [ ] A/B testing infrastructure
- [ ] Quality feedback collection (thumbs up/down)
- [ ] Export/analytics for usage data

### Phase 5 (Self-Tuning / Self-Annealing)
- [ ] Performance signal collection (latency, errors, retries)
- [ ] Quality signal detection (user edits, repeated queries, abandonment)
- [ ] Frustration pattern recognition (lightweight mood detection)
- [ ] Adaptive routing engine with configurable weights
- [ ] Query-type performance learning (which queries work best where)
- [ ] Automatic fallback on local model failure
- [ ] Graceful degradation under memory/thermal pressure
- [ ] User notification system for routing changes
- [ ] Monthly routing summary generation
- [ ] Privacy weight slider in settings
- [ ] Per-query-type manual overrides
- [ ] Hardware change detection (RAM upgrades)
- [ ] "Reset learned preferences" functionality

---

## Resources

### Frameworks & Tools
- [MLX](https://github.com/ml-explore/mlx) - Apple's ML framework
- [MLX-LM](https://github.com/ml-explore/mlx-examples/tree/main/llms) - LLM inference with MLX
- [Ollama](https://ollama.ai) - Simple local LLM runner
- [LM Studio](https://lmstudio.ai) - GUI for local models

### Models (MLX Format)
- [Qwen MLX Models](https://huggingface.co/collections/Qwen/qwen25-mlx) - Recommended
- [MLX Community](https://huggingface.co/mlx-community) - Community conversions

### Research
- [Production-Grade Local LLM Inference on Apple Silicon](https://arxiv.org/abs/2511.05502) - Comparative study
- [Apple MLX M5 Research](https://machinelearning.apple.com/research/exploring-llms-mlx-m5) - Neural Accelerator benchmarks

### Community
- [llama.cpp Apple Silicon Discussion](https://github.com/ggml-org/llama.cpp/discussions/4167) - Performance data
- [MacStories AI Benchmarks](https://www.macstories.net/notes/notes-on-early-mac-studio-ai-benchmarks-with-qwen3-235b-a22b-and-qwen2-5-vl-72b/) - Real-world testing

---

## Conclusion

**Local models are feasible for EmberHearth, with caveats:**

1. **Not for base 8GB Macs** - Quality too limited for good UX
2. **16GB is entry-level** - Works for simple assistant tasks
3. **24GB+ recommended** - Good quality, responsive experience
4. **MLX is the right runtime** - 5-10x faster than Ollama

**Strategy (Four Modes):**

| Mode | Target Users | Hardware | Key Benefit |
|------|--------------|----------|-------------|
| Cloud API | Everyone | Any | Best quality, simplest setup |
| Local Only | Privacy-focused | 16GB+ | Zero data exposure |
| Simple Hybrid | Cost-conscious | 16GB+ | Automatic cost savings |
| **Orchestrated Hybrid** | Power users | 16GB+ | Privacy + cost + quality |

**The Orchestrated Hybrid approach is the most promising long-term strategy:**
- Cloud foundation model handles planning and reasoning (what it's best at)
- Local LLMs execute data retrieval and drafting (keeping sensitive data local)
- Potentially 40-60% token cost reduction vs cloud-only
- Built-in monitoring validates actual savings during development

**Self-Tuning is essential for non-technical users:**
- Users configure preferences during onboarding and forget about them
- System must detect degradation (latency, quality, user frustration)
- Automatic adjustment of local/cloud balance based on observed performance
- Graceful degradation when local models fail or resources are constrained
- Transparent notifications keep users informed without overwhelming them

**Key differentiator vs Moltbot:** EmberHearth's deep macOS integration means local agents access native APIs (EventKit, Contacts, Mail) directly, not through generic file/shell access. This enables better privacy boundaries and richer structured data extraction. The self-tuning architecture ensures the system remains optimal over time without user intervention.

The local LLM landscape is improving rapidly. What requires 24GB today may run on 16GB next year. EmberHearth should architect for this flexibility, with self-annealing behavior that adapts to hardware changes, model improvements, and user needs over time.
