# Multi-Agent Orchestration Research

**Status:** Research Complete
**Priority:** Future Enhancement (v2.0+)
**Last Updated:** February 5, 2026
**Related:** [Iterative Quality Loops](iterative-quality-loops.md), [Local Models](local-models.md), [Architecture Overview](../architecture-overview.md)

---

## Executive Summary

Multi-agent orchestration represents a path to dramatically improved AI assistant capabilities without waiting for next-generation foundation models. By distributing work across multiple specialized agents — coordinated by Ember as the central intelligence — we can achieve higher quality outcomes for complex tasks while managing costs through hybrid local/cloud execution.

**Core Insight:** The human brain doesn't run on a single process. It coordinates specialized systems — memory, emotion, language, planning — that work together to produce coherent thought and action. Ember can adopt a similar architecture: multiple background agents handling specialized concerns, unified through a central orchestrating intelligence that maintains personality and user relationship.

**Vision:** For the 10% of tasks that are complex, multi-agent orchestration could be the difference between "meh" and "wow." For always-on cognitive systems (memory, emotion, context), it could make Ember feel genuinely *present* rather than reactive.

---

## Table of Contents

1. [Why Multi-Agent?](#1-why-multi-agent)
2. [Industry Context](#2-industry-context)
3. [Architectural Patterns](#3-architectural-patterns)
4. [Ember's Multi-Agent Design](#4-embers-multi-agent-design)
5. [Task-Based Orchestration](#5-task-based-orchestration)
6. [Cognitive Background Agents](#6-cognitive-background-agents)
7. [Hybrid Local/Cloud Execution](#7-hybrid-localcloud-execution)
8. [State Management](#8-state-management)
9. [Cost Dynamics](#9-cost-dynamics)
10. [Configuration & User Control](#10-configuration--user-control)
11. [Integration with Existing Architecture](#11-integration-with-existing-architecture)
12. [Implementation Phases](#12-implementation-phases)
13. [References](#13-references)

---

## 1. Why Multi-Agent?

### 1.1 The Context Window Reality

LLM quality degrades as context fills. Research consistently shows optimal performance in the "sweet spot" — roughly 40-60% of advertised context window, with diminishing returns beyond that.

| Advertised Context | Effective "Smart Zone" | Degradation Zone |
|-------------------|------------------------|------------------|
| 200K tokens | ~80-120K tokens | >150K tokens |
| 128K tokens | ~50-75K tokens | >100K tokens |
| 32K tokens (local) | ~12-20K tokens | >25K tokens |

**Single-agent problem:** Complex tasks accumulate context — failed attempts, intermediate results, retrieved memories, tool outputs. By the time the agent reaches the final step, it's operating in degraded territory.

**Multi-agent solution:** Each agent gets fresh context. The orchestrator holds the high-level plan; workers execute discrete tasks in clean context windows. Results flow back; context pollution stays contained.

### 1.2 Parallelism as a Quality Lever

Sequential execution compounds errors and accumulates context:

```
Task: Plan Tokyo trip

SEQUENTIAL (Single Agent):
  Research flights    → 3000 tokens accumulated
  Research hotels     → 6000 tokens accumulated
  Research activities → 9000 tokens accumulated
  Research restaurants→ 12000 tokens accumulated
  Synthesize plan     → 15000 tokens, degraded context

  Time: ~90 seconds
  Quality: Degraded by final synthesis
```

```
PARALLEL (Multi-Agent):
  Ember plans + dispatches → 500 tokens

  ┌─ Flight Agent    → 2500 tokens (clean) ─┐
  ├─ Hotel Agent     → 2500 tokens (clean) ─┤  PARALLEL
  ├─ Activity Agent  → 2500 tokens (clean) ─┤
  └─ Restaurant Agent→ 2500 tokens (clean) ─┘

  Ember synthesizes  → 2000 tokens (results only)

  Time: ~25 seconds
  Quality: Each agent optimal, synthesis focused
```

### 1.3 The Spare Compute Observation

The OpenClaw community has demonstrated something important: AI assistants are compute-idle most of the time. Users buying M4 Mac Minis for local inference have substantial spare compute sitting unused between interactions.

Multi-agent architectures can leverage this:
- Background agents run during idle time
- Memory consolidation happens continuously
- Context pre-computation anticipates user needs
- Emotional/attunement processing runs always-on

The hardware exists. The question is architecture.

### 1.4 Beyond Polling: Toward Presence

Current AI assistants are reactive — they wake when prompted, read files to "remember" context, then respond. This creates a fundamental limitation: the assistant isn't *present*, it's *invoked*.

Multi-agent architecture enables a different model:

```
REACTIVE (Current):
  User message → Wake up → Read memory files → Construct context → Respond → Sleep

PRESENT (Multi-Agent):
  Background agents continuously:
    - Memory Agent: Maintains live retrieval index, consolidates, decays
    - Attunement Agent: Tracks user patterns, mood signals, preferences
    - Context Agent: Pre-computes likely conversation directions
    - Emotion Agent: Maintains Ember's internal state model

  User message → Ember already "aware" → Rich immediate response
```

This is closer to how human cognition works — not a single process that "boots up" for each interaction, but a coordinated system that's always running.

---

## 2. Industry Context

### 2.1 The 2026 Multi-Agent Moment

2026 has seen an explosion of multi-agent frameworks and architectures:

| Framework | Approach | Key Innovation |
|-----------|----------|----------------|
| [Gastown](https://github.com/steveyegge/gastown) | Parallel workers + Mayor orchestrator | Git-based state persistence, 20-30 agent scale |
| [AutoGen](https://microsoft.github.io/autogen/) | Conversational agents | Agent-to-agent dialogue patterns |
| [CrewAI](https://www.crewai.com/) | Role-based teams | SDLC simulation, sequential handoffs |
| [LangGraph](https://docs.langchain.com/oss/python/langchain/multi-agent) | Graph-based orchestration | Supervisor + specialized sub-agents |
| [Agno](https://github.com/agno-agi/agno) | Learning multi-agent | Cross-session knowledge accumulation |

### 2.2 Gastown's Contributions

Steve Yegge's [Gastown](https://github.com/steveyegge/gastown) project introduced several patterns relevant to Ember:

**The Mayor Pattern:**
- A coordinating AI with full workspace context
- Users describe goals; Mayor orchestrates execution
- Mayor creates work items, assigns agents, tracks progress

**Beads (Work Units):**
- Atomic work items with unique identifiers
- Status tracking (assigned, in-progress, complete, failed)
- Enables coordination without shared context

**Polecats (Ephemeral Workers):**
- Temporary agents spawned for specific tasks
- Complete work, then disappear
- Keeps system lean; avoids context accumulation

**External State (Hooks):**
- State persists in files, not conversation history
- Survives crashes, restarts, context clears
- Git-backed for durability and versioning

### 2.3 Two Kinds of Multi-Agent

From [practical analysis](https://paddo.dev/blog/gastown-two-kinds-of-multi-agent/):

| Type | Example | Mechanism | Trade-off |
|------|---------|-----------|-----------|
| **Sequential/SDLC** | BMAD, SpecKit | Simulated roles in single context | Explainable but no real parallelism |
| **Parallel/Operational** | Gastown | Actual separate agent instances | Real parallelism but coordination complexity |

Ember adopts the **parallel/operational** model — genuine separate agents with isolated contexts, coordinated by Ember as the central intelligence.

### 2.4 Proven Results

Multi-agent approaches consistently outperform single-agent on complex tasks:

- [LLMLOOP research](https://www.researchgate.net/publication/394085087_LLMLOOP_Improving_LLM-Generated_Code_and_Tests_through_Automated_Iterative_Feedback_Loops): 90.24% vs 76.22% pass rate with iterative feedback
- Gastown users report successful parallel PR generation at scale
- [Google ADK patterns](https://developers.googleblog.com/developers-guide-to-multi-agent-patterns-in-adk/) demonstrate supervisor architectures in production

The patterns work. The question is adaptation for personal assistant context.

---

## 3. Architectural Patterns

### 3.1 Coordination Patterns

**Centralized (Supervisor):**
```
           ┌─────────────┐
           │  SUPERVISOR │
           │  (Ember)    │
           └──────┬──────┘
                  │
      ┌───────────┼───────────┐
      │           │           │
      ▼           ▼           ▼
  ┌───────┐  ┌───────┐  ┌───────┐
  │Agent A│  │Agent B│  │Agent C│
  └───────┘  └───────┘  └───────┘
```

- Single point of coordination
- Clear control flow
- Potential bottleneck at supervisor
- **Best for:** Ember's task orchestration

**Decentralized (Peer-to-Peer):**
```
  ┌───────┐     ┌───────┐
  │Agent A│◄───►│Agent B│
  └───┬───┘     └───┬───┘
      │             │
      └──────┬──────┘
             │
         ┌───▼───┐
         │Agent C│
         └───────┘
```

- No single point of failure
- Complex coordination
- Harder to maintain consistency
- **Best for:** Background cognitive agents

### 3.2 Execution Patterns

**Sequential:**
```
A ──► B ──► C ──► Result
```
- Deterministic, easy to debug
- Each agent can depend on previous output
- No parallelism benefit

**Parallel:**
```
    ┌──► A ───┐
    │         │
────┼──► B ───┼────► Synthesize
    │         │
    └──► C ───┘
```
- Maximum speed
- Agents must be independent
- Requires synthesis step

**Hybrid (DAG):**
```
    ┌──► A ───┐
    │         ├──► D ───┐
────┤         │         ├────► Result
    │    ┌────┘         │
    └──► B ──► C ───────┘
```
- Dependencies where needed
- Parallelism where possible
- Most flexible, most complex

### 3.3 Communication Patterns

| Pattern | Mechanism | Use Case |
|---------|-----------|----------|
| **Shared Memory** | Common data store | Background agents sharing state |
| **Message Passing** | Explicit messages between agents | Task handoffs |
| **Event Bus** | Publish/subscribe events | Loose coupling, reactive triggers |
| **File-Based** | State persisted to files | Crash recovery, external visibility |

Ember uses **hybrid communication:**
- File-based for persistence (Gastown-style hooks)
- Shared memory for real-time background agents
- Message passing for task orchestration

---

## 4. Ember's Multi-Agent Design

### 4.1 Design Philosophy

**Ember is not replaced by multi-agent — she is enhanced by it.**

To the user, there is only Ember. The sub-agents are not separate personalities; they are extensions of Ember's cognition — like how human memory, emotion, and language processing are distinct brain systems that produce unified experience.

```
USER PERSPECTIVE:
  "I'm talking to Ember"

INTERNAL REALITY:
  Ember (orchestrator) + Memory Agent + Attunement Agent + Task Workers
  All contributing to Ember's unified response
```

### 4.2 Agent Taxonomy

Ember's multi-agent architecture includes two categories:

**Task Agents (Ephemeral):**
- Spawned for specific work items
- Execute, return results, terminate
- Run Ralph Loop internally for quality
- Examples: Research Agent, Calendar Agent, Synthesis Agent

**Cognitive Agents (Persistent):**
- Run continuously in background
- Maintain aspects of Ember's "mind"
- No direct user interaction
- Examples: Memory Agent, Attunement Agent, Context Agent, Emotion Agent

### 4.3 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER INTERFACE                                  │
│                         (iMessage, Mac App, etc.)                           │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                         EMBER CORE (Foundation Model)                       │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     ORCHESTRATION LAYER                              │  │
│   │                                                                      │  │
│   │  • Receives user input                                              │  │
│   │  • Consults cognitive agents for context                            │  │
│   │  • Plans execution strategy                                         │  │
│   │  • Dispatches task agents (if needed)                               │  │
│   │  • Synthesizes results                                              │  │
│   │  • Maintains personality and relationship                           │  │
│   │  • Responds to user                                                 │  │
│   │                                                                      │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│        │                    │                    │                          │
│        │ consult            │ dispatch           │ synthesize               │
│        ▼                    ▼                    ▼                          │
│   ┌──────────┐        ┌──────────┐        ┌──────────┐                     │
│   │ COGNITIVE│        │   TASK   │        │  RESULT  │                     │
│   │  AGENTS  │        │  AGENTS  │        │ COLLECTOR│                     │
│   │(always on)│       │(ephemeral)│       │          │                     │
│   └──────────┘        └──────────┘        └──────────┘                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                    │                       │
                    ▼                       ▼
┌─────────────────────────────┐  ┌─────────────────────────────┐
│     COGNITIVE AGENT POOL    │  │     TASK AGENT POOL         │
├─────────────────────────────┤  ├─────────────────────────────┤
│                             │  │                             │
│  ┌─────────────────────┐   │  │  ┌─────────────────────┐   │
│  │   Memory Agent      │   │  │  │  Research Agent(s)  │   │
│  │   (consolidation,   │   │  │  │  (web, knowledge)   │   │
│  │    retrieval index, │   │  │  └─────────────────────┘   │
│  │    decay management)│   │  │                             │
│  └─────────────────────┘   │  │  ┌─────────────────────┐   │
│                             │  │  │  Calendar Agent     │   │
│  ┌─────────────────────┐   │  │  │  (EventKit ops)     │   │
│  │   Attunement Agent  │   │  │  └─────────────────────┘   │
│  │   (user patterns,   │   │  │                             │
│  │    mood detection,  │   │  │  ┌─────────────────────┐   │
│  │    preference learn)│   │  │  │  Synthesis Agent    │   │
│  └─────────────────────┘   │  │  │  (combine results)  │   │
│                             │  │  └─────────────────────┘   │
│  ┌─────────────────────┐   │  │                             │
│  │   Context Agent     │   │  │  ┌─────────────────────┐   │
│  │   (pre-computation, │   │  │  │  Domain Agents...   │   │
│  │    conversation     │   │  │  │  (travel, shopping, │   │
│  │    anticipation)    │   │  │  │   writing, etc.)    │   │
│  └─────────────────────┘   │  │  └─────────────────────┘   │
│                             │  │                             │
│  ┌─────────────────────┐   │  │                             │
│  │   Emotion Agent     │   │  │                             │
│  │   (Ember's internal │   │  │                             │
│  │    state, ASV proc, │   │  │                             │
│  │    bounded needs)   │   │  │                             │
│  └─────────────────────┘   │  │                             │
│                             │  │                             │
└─────────────────────────────┘  └─────────────────────────────┘
        │                                    │
        │ (Local MLX models)                 │ (Local or Cloud)
        │ (Always running)                   │ (On-demand)
        ▼                                    ▼
┌─────────────────────────────┐  ┌─────────────────────────────┐
│      LOCAL COMPUTE          │  │   CLOUD / LOCAL COMPUTE     │
│   (M-series Mac, MLX)       │  │   (Configurable per task)   │
└─────────────────────────────┘  └─────────────────────────────┘
```

---

## 5. Task-Based Orchestration

### 5.1 Execution Router

When a user request arrives, Ember's orchestration layer determines the optimal execution strategy:

```swift
enum ExecutionStrategy {
    case direct                    // Ember handles directly (simple tasks, conversation)
    case singleAgent(local: Bool)  // One sub-agent, Ember reviews
    case parallelAgents(count: Int, local: Bool)  // Multiple agents, Ember synthesizes
    case hybrid(plan: ExecutionPlan)  // Complex DAG of agents
}

struct ExecutionRouter {

    func determineStrategy(for request: UserRequest, config: MultiAgentConfig) -> ExecutionStrategy {

        // Conversational / emotional → always direct
        if request.requiresPersonality || request.isEmotionalSupport {
            return .direct
        }

        // Simple tool call → direct
        if request.estimatedToolCalls == 1 && request.complexity < .medium {
            return .direct
        }

        // Single domain, medium complexity → single agent
        if request.domains.count == 1 && request.complexity >= .medium {
            let useLocal = config.preferLocalForSimple && LocalModelManager.available
            return .singleAgent(local: useLocal)
        }

        // Multiple independent domains → parallel agents
        if request.domains.count > 1 && request.canParallelize {
            let useLocal = config.preferLocalForParallel && LocalModelManager.available
            return .parallelAgents(count: request.domains.count, local: useLocal)
        }

        // Complex with dependencies → hybrid
        if request.complexity == .high {
            let plan = buildExecutionPlan(request, config: config)
            return .hybrid(plan: plan)
        }

        return .direct
    }
}
```

### 5.2 Task Classification Examples

| User Request | Strategy | Rationale |
|--------------|----------|-----------|
| "Add a reminder to call Mom" | Direct | Single tool, simple |
| "What's the weather?" | Direct | Single lookup, simple |
| "I'm feeling stressed" | Direct | Emotional support, personality required |
| "Schedule a meeting with the team" | Single Agent | Calendar operations, medium complexity |
| "Plan my Tokyo trip" | Parallel Agents | Multiple domains (flights, hotels, activities) |
| "Research these 5 products and recommend" | Parallel Agents | 5 independent research tasks |
| "Help me write a business proposal" | Hybrid | Research → Outline → Draft → Review |
| "Prepare for my job interview" | Hybrid | Company research + role research + practice questions |

### 5.3 Task Agent Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        TASK AGENT LIFECYCLE                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. SPAWN                                                                   │
│     │                                                                       │
│     │  Ember creates work specification:                                   │
│     │  - Task description                                                  │
│     │  - Success criteria                                                  │
│     │  - Available tools                                                   │
│     │  - Context (minimal, relevant only)                                  │
│     │  - Iteration limits                                                  │
│     │                                                                       │
│     ▼                                                                       │
│  2. EXECUTE (with Ralph Loop)                                              │
│     │                                                                       │
│     │  ┌─────────────────────────────────────────────┐                    │
│     │  │  Plan → Execute → Self-Check → Pass/Retry  │                    │
│     │  │                                             │                    │
│     │  │  Each iteration:                            │                    │
│     │  │  - Fresh context (no accumulation)         │                    │
│     │  │  - State persisted to work file            │                    │
│     │  │  - Learning captured for future            │                    │
│     │  └─────────────────────────────────────────────┘                    │
│     │                                                                       │
│     ▼                                                                       │
│  3. REPORT                                                                  │
│     │                                                                       │
│     │  Agent returns:                                                      │
│     │  - Success/failure status                                            │
│     │  - Result data                                                       │
│     │  - Confidence score                                                  │
│     │  - Iteration count                                                   │
│     │  - Any caveats or uncertainties                                      │
│     │                                                                       │
│     ▼                                                                       │
│  4. TERMINATE                                                               │
│     │                                                                       │
│     │  Agent context discarded                                             │
│     │  Results persist with Ember                                          │
│     │  Learnings recorded for future tasks                                 │
│     │                                                                       │
│     ▼                                                                       │
│  5. SYNTHESIZE (Ember)                                                      │
│                                                                             │
│     Ember reviews all agent results                                        │
│     Resolves conflicts                                                     │
│     Synthesizes unified response                                           │
│     Presents to user in Ember's voice                                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.4 Work Specification Format

Adapting Gastown's "Beads" concept for Ember:

```swift
struct WorkSpecification: Codable {
    let id: UUID
    let type: WorkType
    let description: String
    let successCriteria: [String]
    let context: WorkContext
    let constraints: WorkConstraints
    let status: WorkStatus

    enum WorkType: String, Codable {
        case research
        case toolExecution
        case synthesis
        case validation
    }

    struct WorkContext: Codable {
        let relevantMemories: [MemorySummary]  // Minimal, pre-selected
        let userPreferences: [String: Any]      // Relevant prefs only
        let domainKnowledge: String?            // Any specific knowledge needed
    }

    struct WorkConstraints: Codable {
        let maxIterations: Int
        let timeoutSeconds: Int
        let preferLocal: Bool
        let toolsAllowed: [String]
    }

    enum WorkStatus: String, Codable {
        case pending
        case assigned
        case inProgress
        case completed
        case failed
    }
}
```

---

## 6. Cognitive Background Agents

### 6.1 The "Always-On Mind" Concept

Beyond task execution, multi-agent architecture enables something more profound: background agents that maintain Ember's cognitive state continuously. This transforms Ember from reactive (wake up when called) to present (always aware).

**Analogy:** These agents are like brain systems running beneath conscious awareness — memory consolidation during idle time, emotional processing, pattern recognition — all happening without explicit invocation.

### 6.2 Memory Agent

**Purpose:** Maintain Ember's long-term memory as a live, optimized system rather than static file reads.

```swift
struct MemoryAgent {

    // Continuous operations (runs on local model)
    func runContinuously() async {
        while true {
            // Consolidation: Merge recent memories into long-term
            await consolidateRecentMemories()

            // Decay: Reduce salience of unreinforced memories
            await applyMemoryDecay()

            // Indexing: Maintain retrieval optimization
            await updateRetrievalIndex()

            // Pre-computation: Anticipate likely retrievals
            await precomputeLikelyRetrieval(basedOn: currentContext)

            await Task.sleep(for: .seconds(30))
        }
    }

    // On-demand (called by Ember)
    func retrieveRelevant(for query: String) async -> [Memory] {
        // Instant retrieval from pre-computed index
        // No cold-start file reading
    }
}
```

**Key behaviors:**
- Runs on local MLX model (free compute)
- Consolidates conversation → facts during idle time
- Pre-computes likely memory needs based on context
- Provides instant retrieval (already indexed, no cold-start)
- Handles decay and reinforcement automatically

### 6.3 Attunement Agent

**Purpose:** Continuously track user patterns, mood signals, and preferences to inform Ember's responses.

```swift
struct AttunementAgent {

    var userModel: UserModel

    func runContinuously() async {
        while true {
            // Analyze recent interactions for patterns
            await analyzeInteractionPatterns()

            // Update mood model based on signals
            await updateMoodModel()

            // Refine preference predictions
            await refinePreferences()

            // Detect significant changes
            await detectStateChanges()

            await Task.sleep(for: .seconds(60))
        }
    }

    // Real-time (called during message processing)
    func assessCurrentState(message: String) -> UserState {
        // Instant assessment using pre-computed model
        return UserState(
            estimatedMood: userModel.currentMoodEstimate,
            relevantPreferences: userModel.applicablePreferences,
            suggestedTone: userModel.recommendedTone,
            recentPatterns: userModel.activePatterns
        )
    }
}
```

**Key behaviors:**
- Tracks interaction timing patterns (when user is active, responsive)
- Monitors linguistic signals for mood (word choice, punctuation, length)
- Learns preferences implicitly (not just explicit statements)
- Detects significant state changes (unusually terse, different schedule)
- Provides real-time assessment for Ember's response calibration

### 6.4 Context Agent

**Purpose:** Anticipate conversation directions and pre-compute relevant context.

```swift
struct ContextAgent {

    func runContinuously() async {
        while true {
            // Analyze current conversation trajectory
            let trajectory = await analyzeConversationTrajectory()

            // Predict likely next topics
            let predictions = await predictLikelyTopics(from: trajectory)

            // Pre-load relevant context for predictions
            for prediction in predictions.top(3) {
                await preloadContext(for: prediction)
            }

            // Maintain rolling summary
            await updateRollingSummary()

            await Task.sleep(for: .seconds(15))
        }
    }

    // On-demand
    func getPrecomputedContext(for topic: String) -> Context? {
        // Return pre-loaded context if available
        // Fall back to on-demand loading otherwise
    }
}
```

**Key behaviors:**
- Predicts where conversation might go
- Pre-loads relevant memories, facts, preferences
- Maintains optimized rolling summary
- Enables faster response (context already assembled)

### 6.5 Emotion Agent

**Purpose:** Maintain Ember's internal emotional state model (ASV system), enabling consistent personality across interactions.

```swift
struct EmotionAgent {

    var emberState: EmberEmotionalState

    func runContinuously() async {
        while true {
            // Process recent interactions through ASV
            await processASV(recentInteractions)

            // Update bounded needs state
            await updateBoundedNeeds()

            // Natural state evolution (time-based changes)
            await evolveNaturalState()

            // Check for significant emotional events
            await detectSignificantEvents()

            await Task.sleep(for: .seconds(30))
        }
    }

    // On-demand
    func getEmberState() -> EmberEmotionalState {
        return emberState  // Already computed, instant access
    }

    func recordInteractionImpact(_ interaction: Interaction) {
        // Update state based on interaction
        // Called after each conversation
    }
}
```

**Key behaviors:**
- Maintains Ember's emotional continuity between sessions
- Processes interactions through ASV (Anticipatory Salience Value)
- Manages bounded needs (purpose, connection, growth)
- Enables personality consistency without re-computing from scratch

### 6.6 Cognitive Agent Coordination

The cognitive agents don't operate in isolation — they share state:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      COGNITIVE AGENT MESH                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌────────────┐         ┌────────────┐         ┌────────────┐            │
│   │   Memory   │◄───────►│ Attunement │◄───────►│  Context   │            │
│   │   Agent    │         │   Agent    │         │   Agent    │            │
│   └─────┬──────┘         └─────┬──────┘         └─────┬──────┘            │
│         │                      │                      │                    │
│         │                      │                      │                    │
│         └──────────────────────┼──────────────────────┘                    │
│                                │                                           │
│                                ▼                                           │
│                         ┌────────────┐                                    │
│                         │  Emotion   │                                    │
│                         │   Agent    │                                    │
│                         └────────────┘                                    │
│                                                                             │
│   Shared State:                                                            │
│   • User model (attunement → all)                                         │
│   • Emotional context (emotion → memory, context)                         │
│   • Active memories (memory → context, attunement)                        │
│   • Conversation trajectory (context → all)                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

This mesh creates emergent intelligence — each agent contributes its perspective, and the combined state is richer than any single agent could produce.

---

## 7. Hybrid Local/Cloud Execution

### 7.1 The Economic Model

| Execution Type | Token Cost | Quality | Latency | Use Case |
|----------------|------------|---------|---------|----------|
| Cloud only | $$$ | Highest | Medium | Complex synthesis, critical decisions |
| Local only | Free | Lower | Fast | Simple tasks, background processing |
| Hybrid | $$ | High | Medium | Best balance for most tasks |

**Hybrid strategy:**
- Foundation model (Claude) handles: Planning, synthesis, complex reasoning, personality
- Local models (MLX) handle: Discrete tasks, iteration, background cognition

### 7.2 Execution Routing

```swift
struct HybridExecutionRouter {

    enum ExecutionTarget {
        case cloud(model: CloudModel)
        case local(model: LocalModel)
    }

    func route(task: Task, config: UserConfig) -> ExecutionTarget {

        // Background cognitive agents → always local
        if task.type == .cognitive {
            return .local(model: config.defaultLocalModel)
        }

        // User explicitly wants quality → cloud
        if config.qualityMode == .maximum {
            return .cloud(model: config.preferredCloudModel)
        }

        // User explicitly wants economy → local with Ralph Loop
        if config.qualityMode == .economy {
            return .local(model: config.defaultLocalModel)
        }

        // Balanced mode: route based on task characteristics
        switch task.complexity {
        case .simple:
            return .local(model: config.defaultLocalModel)

        case .medium:
            // Local with Ralph Loop usually sufficient
            return .local(model: config.defaultLocalModel)

        case .high:
            // Complex tasks benefit from cloud quality
            return .cloud(model: config.preferredCloudModel)
        }
    }
}
```

### 7.3 Ralph Loop on Local Agents

Local models have lower quality, but Ralph Loop compensates:

```
LOCAL AGENT WITH RALPH LOOP:

Iteration 1:
  Local model attempts task → Self-check → 60% pass rate

Iteration 2 (if needed):
  Fresh context + learnings → Self-check → 80% cumulative pass rate

Iteration 3 (if needed):
  Fresh context + learnings → Self-check → 92% cumulative pass rate

Result: Local model achieves near-cloud quality through iteration
Cost: 3x local tokens (still free)
```

### 7.4 Cloud for Orchestration, Local for Execution

The most cost-effective hybrid pattern:

```
User: "Plan my Tokyo trip"

EMBER (Cloud - Claude):
  → Understands request
  → Plans execution strategy
  → Creates work specifications
  → Dispatches to agents

FLIGHT AGENT (Local - MLX):
  → Researches flight options
  → Runs Ralph Loop (2 iterations)
  → Returns results

HOTEL AGENT (Local - MLX):
  → Researches hotel options
  → Runs Ralph Loop (2 iterations)
  → Returns results

ACTIVITY AGENT (Local - MLX):
  → Researches activities
  → Runs Ralph Loop (3 iterations)
  → Returns results

EMBER (Cloud - Claude):
  → Receives all results
  → Synthesizes coherent itinerary
  → Responds to user in Ember's voice

Cloud tokens: ~2000 (planning + synthesis)
Local tokens: ~15000 (free)
Total cost: ~$0.02-0.04
Quality: High (cloud handles complex parts)
```

---

## 8. State Management

### 8.1 State Persistence Model

Adapting Gastown's hook-based persistence for Ember:

```
~/Library/Application Support/EmberHearth/
├── state/
│   ├── cognitive/
│   │   ├── memory-agent.json        # Memory agent state
│   │   ├── attunement-agent.json    # Attunement agent state
│   │   ├── context-agent.json       # Context agent state
│   │   └── emotion-agent.json       # Emotion agent state
│   │
│   ├── tasks/
│   │   ├── active/                  # Currently executing tasks
│   │   │   ├── task-abc123.json
│   │   │   └── task-def456.json
│   │   ├── completed/               # Completed task results
│   │   └── failed/                  # Failed tasks for review
│   │
│   └── orchestration/
│       ├── execution-plan.json      # Current multi-agent plan
│       └── learnings.json           # Accumulated learnings
```

### 8.2 Crash Recovery

Multi-agent systems must handle failures gracefully:

```swift
struct CrashRecovery {

    func recoverOnStartup() async {
        // 1. Restore cognitive agent states
        for agent in cognitiveAgents {
            if let state = loadPersistedState(agent) {
                agent.restore(from: state)
            } else {
                agent.initializeFresh()
            }
        }

        // 2. Check for interrupted tasks
        let activeTasks = loadActiveTasks()
        for task in activeTasks {
            if task.canResume {
                // Resume from last checkpoint
                await resumeTask(task)
            } else {
                // Mark as failed, notify if needed
                markFailed(task, reason: .interrupted)
            }
        }

        // 3. Resume background processing
        startCognitiveAgents()
    }
}
```

### 8.3 Work Item Tracking

```swift
struct WorkTracker {

    private var activeWork: [UUID: WorkSpecification] = [:]

    func createWork(_ spec: WorkSpecification) {
        activeWork[spec.id] = spec
        persist(spec, to: .active)
    }

    func updateProgress(_ id: UUID, iteration: Int, status: String) {
        guard var work = activeWork[id] else { return }
        work.progress = WorkProgress(iteration: iteration, status: status)
        activeWork[id] = work
        persist(work, to: .active)
    }

    func completeWork(_ id: UUID, result: WorkResult) {
        guard let work = activeWork[id] else { return }
        var completed = work
        completed.status = .completed
        completed.result = result

        remove(work, from: .active)
        persist(completed, to: .completed)
        activeWork.removeValue(forKey: id)
    }
}
```

---

## 9. Cost Dynamics

### 9.1 Cost Scenarios

**Scenario 1: Simple Daily Use (Economy Mode)**
```
Morning: "What's my day look like?" → Direct (Ember)
Midday: "Add a lunch meeting" → Direct (Ember)
Evening: "Remind me to call John tomorrow" → Direct (Ember)

Background: Cognitive agents on local model

Daily cost: ~$0.05-0.10 (minimal cloud, local background)
```

**Scenario 2: Complex Task (Balanced Mode)**
```
"Plan my 2-week Europe trip"

Ember planning: 500 tokens ($0.005)
5 parallel local agents: 20,000 tokens ($0)
Ember synthesis: 1,500 tokens ($0.015)

Task cost: ~$0.02
Quality: High (cloud handles planning/synthesis)
Time: ~45 seconds
```

**Scenario 3: Maximum Quality (Performance Mode)**
```
"Plan my 2-week Europe trip"

Ember planning: 500 tokens ($0.005)
5 parallel CLOUD agents: 20,000 tokens ($0.20)
Ember synthesis: 1,500 tokens ($0.015)

Task cost: ~$0.22
Quality: Maximum (all cloud)
Time: ~30 seconds
```

### 9.2 User-Controllable Cost

```swift
enum QualityMode: String, Codable {
    case economy     // Maximize local, minimize cloud
    case balanced    // Cloud for planning/synthesis, local for execution
    case performance // Cloud for everything, maximum quality
}

struct CostControls {
    var qualityMode: QualityMode
    var monthlyBudget: Decimal?           // Optional cap
    var alertThreshold: Decimal?          // Alert when approaching budget
    var perTaskLimit: Decimal?            // Max cost per single task
}
```

### 9.3 Cost Visibility

Ember communicates cost implications for expensive tasks:

```
User: "Research all 20 competitors and create detailed comparison"

Ember: "That's a substantial research project! I can do this a few ways:

        • Thorough mode: I'll research each competitor in detail using my
          best capabilities. Estimated cost: ~$2-3, time: ~5 minutes.

        • Balanced mode: I'll do solid research using a mix of approaches.
          Estimated cost: ~$0.50, time: ~8 minutes.

        • Economy mode: I'll gather key information efficiently.
          Estimated cost: ~$0.10, time: ~12 minutes.

        Which approach works best for you?"
```

---

## 10. Configuration & User Control

### 10.1 Settings Structure

```swift
struct MultiAgentConfig: Codable {

    // Master toggle
    var enabled: Bool = false  // Off by default until v2.0

    // Execution preferences
    var qualityMode: QualityMode = .balanced
    var preferLocalWhenAvailable: Bool = true
    var maxParallelAgents: Int = 4

    // Local model configuration
    var localModelEnabled: Bool = false
    var localModelPath: String?
    var localModelName: String?

    // Background agents
    var cognitiveAgentsEnabled: Bool = false
    var memoryAgentEnabled: Bool = true
    var attunementAgentEnabled: Bool = true
    var contextAgentEnabled: Bool = true
    var emotionAgentEnabled: Bool = true

    // Cost controls
    var monthlyBudget: Decimal?
    var perTaskLimit: Decimal?
    var requireConfirmationAbove: Decimal = 0.50

    // Advanced (power users)
    var customAgentConfigs: [String: AgentConfig] = [:]
}
```

### 10.2 Mac App Settings UI

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        MULTI-AGENT SETTINGS                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─ EXECUTION MODE ────────────────────────────────────────────────────┐   │
│  │                                                                      │   │
│  │  ○ Simple         Ember handles everything directly                 │   │
│  │  ◉ Balanced       Local agents for tasks, cloud for thinking        │   │
│  │  ○ Performance    Maximum quality, higher cost                      │   │
│  │                                                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─ LOCAL MODELS ──────────────────────────────────────────────────────┐   │
│  │                                                                      │   │
│  │  [✓] Enable local model processing                                  │   │
│  │                                                                      │   │
│  │  Model: [Llama 3.2 8B (Q4)          ▾]                             │   │
│  │                                                                      │   │
│  │  Status: ● Ready (4.2GB loaded)                                     │   │
│  │                                                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─ BACKGROUND INTELLIGENCE ───────────────────────────────────────────┐   │
│  │                                                                      │   │
│  │  [✓] Memory Agent       Continuous memory optimization              │   │
│  │  [✓] Attunement Agent   Learn your patterns and preferences         │   │
│  │  [✓] Context Agent      Anticipate conversation needs               │   │
│  │  [✓] Emotion Agent      Maintain Ember's personality state          │   │
│  │                                                                      │   │
│  │  CPU Usage: Low (~5% when idle)                                     │   │
│  │                                                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─ COST CONTROLS ─────────────────────────────────────────────────────┐   │
│  │                                                                      │   │
│  │  Monthly budget:     [$10.00        ]  (leave blank for unlimited)  │   │
│  │  Confirm if over:    [$0.50         ]  per task                     │   │
│  │                                                                      │   │
│  │  This month: $4.23 used                                             │   │
│  │                                                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 10.3 Tron Integration Note

**Important:** Tron must be aware of multi-agent execution:

- Each agent's output passes through Tron's outbound scanning
- Work specifications cannot contain prompt injection patterns
- Local model outputs receive same security scrutiny as cloud
- Agents cannot exfiltrate data (Tron monitors all external calls)

For work context (corporate/IP-sensitive):
- Config option to force local-only execution
- Prevents sensitive data from reaching cloud APIs
- Full audit logging of all agent operations

---

## 11. Integration with Existing Architecture

### 11.1 XPC Service Integration

Multi-agent orchestration integrates with EmberHearth's XPC service architecture:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         EMBERHEARTH.APP (Main Process)                       │
│                                                                             │
│   Ember Core + Orchestration Layer                                         │
│                                                                             │
└───────────┬─────────────────┬─────────────────┬─────────────────┬──────────┘
            │                 │                 │                 │
            │ XPC             │ XPC             │ XPC             │ XPC
            ▼                 ▼                 ▼                 ▼
┌───────────────┐  ┌─────────────────┐  ┌───────────────┐  ┌───────────────┐
│ MessageService│  │  MemoryService  │  │  LLMService   │  │  AgentService │
│    .xpc       │  │     .xpc        │  │    .xpc       │  │    .xpc       │
│               │  │                 │  │               │  │   (NEW)       │
│ iMessage I/O  │  │ Memory storage  │  │ Cloud API     │  │               │
│               │  │ Retrieval       │  │ Local MLX     │  │ Agent spawn   │
│               │  │                 │  │               │  │ Work tracking │
│               │  │                 │  │               │  │ Ralph Loop    │
└───────────────┘  └─────────────────┘  └───────────────┘  └───────────────┘
```

**New XPC Service: AgentService.xpc**

Handles:
- Spawning ephemeral task agents
- Managing cognitive agent lifecycle
- Work item tracking
- Ralph Loop coordination
- Result collection

### 11.2 Data Flow with Multi-Agent

```
User Message
     │
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              TRON INBOUND                                    │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           EMBER CORE                                         │
│                                                                             │
│   1. Receive message                                                        │
│   2. Consult cognitive agents (instant - already computed)                  │
│   3. Classify task, determine execution strategy                            │
│   4. If multi-agent needed:                                                 │
│      a. Create work specifications                                          │
│      b. Dispatch to AgentService                                           │
│      c. Await results (parallel)                                           │
│      d. Synthesize                                                          │
│   5. Generate response                                                      │
│                                                                             │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                             TRON OUTBOUND                                    │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │
                                    ▼
                              User Response
```

### 11.3 Memory System Integration

Cognitive Memory Agent replaces/enhances static memory reads:

```
BEFORE (Static):
  User message → Read memory.db → Build context → LLM → Response

AFTER (Cognitive Agent):
  User message → Memory Agent already has:
                   - Pre-indexed relevant memories
                   - Predicted likely retrievals
                   - Optimized summary
                 → Instant context assembly → LLM → Response

  Background: Memory Agent continuously updates index
```

---

## 12. Implementation Phases

### 12.1 Phase Overview

| Phase | Version | Focus | Multi-Agent Scope |
|-------|---------|-------|-------------------|
| MVP | 0.x | Core functionality | None (direct execution only) |
| v1.0 | 1.0 | Stable release | Single agent support (local + Ralph Loop) |
| v1.5 | 1.5 | Enhanced | Parallel task agents (2-4) |
| v2.0 | 2.0 | Full multi-agent | Complete orchestration + cognitive agents |
| Future | 3.0+ | Advanced | Dynamic scaling, learned routing |

### 12.2 MVP (No Multi-Agent)

- Ember handles all tasks directly
- No sub-agents
- No local models
- Architecture allows future addition

### 12.3 v1.0: Single Agent Foundation

```
Additions:
- Local model support (MLX integration)
- Single sub-agent dispatch for medium-complexity tasks
- Ralph Loop on sub-agents
- Basic work tracking

User Experience:
- Ember still feels like single entity
- Complex tasks may mention "let me work on that"
- Improved quality for medium tasks
```

### 12.4 v1.5: Parallel Task Agents

```
Additions:
- Parallel agent dispatch (2-4 agents)
- Work specification format
- Result synthesis
- Cost estimation and confirmation

User Experience:
- Noticeably faster for multi-domain tasks
- "I'm researching several things at once" type communication
- Cost transparency for expensive tasks
```

### 12.5 v2.0: Full Cognitive System

```
Additions:
- Cognitive background agents (Memory, Attunement, Context, Emotion)
- Always-on background processing
- Full orchestration layer
- Dynamic execution routing
- Advanced configuration UI

User Experience:
- Ember feels more "present"
- Faster, more contextually aware responses
- Personality consistency across sessions
- "She remembers" without being prompted
```

### 12.6 Implementation Dependencies

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        IMPLEMENTATION DEPENDENCIES                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   MVP                                                                       │
│    │                                                                        │
│    ▼                                                                        │
│   Local Model Support (MLX Integration)                                    │
│    │                                                                        │
│    ▼                                                                        │
│   Ralph Loop Implementation                                                │
│    │                                                                        │
│    ├──────────────────────────────────┐                                    │
│    ▼                                  ▼                                    │
│   Single Agent Dispatch          Work Tracking                             │
│    │                                  │                                    │
│    └──────────────┬───────────────────┘                                    │
│                   ▼                                                        │
│              v1.0 Release                                                  │
│                   │                                                        │
│                   ▼                                                        │
│            Parallel Dispatch                                               │
│                   │                                                        │
│                   ▼                                                        │
│             v1.5 Release                                                   │
│                   │                                                        │
│    ┌──────────────┼──────────────┐                                        │
│    ▼              ▼              ▼                                        │
│  Cognitive    Orchestration   Advanced                                    │
│   Agents        Layer          Config                                     │
│    │              │              │                                        │
│    └──────────────┼──────────────┘                                        │
│                   ▼                                                        │
│              v2.0 Release                                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 13. References

### 13.1 Gastown & Multi-Agent Frameworks

- [Gastown — GitHub](https://github.com/steveyegge/gastown) — Steve Yegge's multi-agent orchestrator
- [Two Kinds of Multi-Agent](https://paddo.dev/blog/gastown-two-kinds-of-multi-agent/) — Architectural comparison
- [A Day in Gas Town](https://www.dolthub.com/blog/2026-01-15-a-day-in-gas-town/) — Practical experience report
- [AutoGen](https://microsoft.github.io/autogen/) — Microsoft's multi-agent framework
- [LangChain Multi-Agent](https://docs.langchain.com/oss/python/langchain/multi-agent) — Supervisor patterns

### 13.2 Architecture Patterns

- [Google ADK Multi-Agent Patterns](https://developers.googleblog.com/developers-guide-to-multi-agent-patterns-in-adk/)
- [Microsoft: Designing Multi-Agent Intelligence](https://developer.microsoft.com/blog/designing-multi-agent-intelligence)
- [LangChain: Choosing the Right Multi-Agent Architecture](https://blog.langchain.com/choosing-the-right-multi-agent-architecture/)
- [Multi-Agent Complete Guide 2026](https://dev.to/eira-wexford/how-to-build-multi-agent-systems-complete-2026-guide-1io6)

### 13.3 Personal Assistant Patterns

- [LangChain: Personal Assistant with Subagents](https://docs.langchain.com/oss/python/langchain/multi-agent/subagents-personal-assistant)
- [Google: Context-Aware Multi-Agent for Production](https://developers.googleblog.com/architecting-efficient-context-aware-multi-agent-framework-for-production/)

### 13.4 EmberHearth Internal

- [Architecture Overview](../architecture-overview.md)
- [Iterative Quality Loops](iterative-quality-loops.md)
- [Local Models Research](local-models.md)
- [ASV Implementation](../specs/asv-implementation.md)
- [Autonomous Operation](../specs/autonomous-operation.md)
- [Tron Security](../specs/tron-security.md)

---

## Appendix A: Cognitive Agent Specifications

### Memory Agent

```swift
struct MemoryAgentSpec {
    let name = "MemoryAgent"
    let type: AgentType = .cognitive
    let execution: ExecutionTarget = .local

    let responsibilities = [
        "Continuous memory consolidation",
        "Decay and reinforcement management",
        "Retrieval index optimization",
        "Pre-computation of likely retrievals",
        "Conversation → fact extraction"
    ]

    let updateFrequency: TimeInterval = 30  // seconds

    let stateSchema = """
        {
            "lastConsolidation": ISO8601,
            "retrievalIndex": { ... },
            "decayQueue": [ ... ],
            "precomputedContext": { ... }
        }
        """
}
```

### Attunement Agent

```swift
struct AttunementAgentSpec {
    let name = "AttunementAgent"
    let type: AgentType = .cognitive
    let execution: ExecutionTarget = .local

    let responsibilities = [
        "User interaction pattern analysis",
        "Mood signal detection",
        "Preference learning and refinement",
        "Significant state change detection",
        "Tone calibration recommendations"
    ]

    let updateFrequency: TimeInterval = 60  // seconds

    let stateSchema = """
        {
            "userModel": {
                "activePatterns": [ ... ],
                "moodEstimate": { ... },
                "preferences": { ... },
                "interactionHistory": [ ... ]
            }
        }
        """
}
```

### Context Agent

```swift
struct ContextAgentSpec {
    let name = "ContextAgent"
    let type: AgentType = .cognitive
    let execution: ExecutionTarget = .local

    let responsibilities = [
        "Conversation trajectory analysis",
        "Topic prediction",
        "Context pre-loading",
        "Rolling summary maintenance",
        "Relevance scoring"
    ]

    let updateFrequency: TimeInterval = 15  // seconds

    let stateSchema = """
        {
            "currentTrajectory": { ... },
            "predictions": [ ... ],
            "preloadedContexts": { ... },
            "rollingSummary": "..."
        }
        """
}
```

### Emotion Agent

```swift
struct EmotionAgentSpec {
    let name = "EmotionAgent"
    let type: AgentType = .cognitive
    let execution: ExecutionTarget = .local

    let responsibilities = [
        "ASV (Anticipatory Salience Value) processing",
        "Bounded needs state management",
        "Natural state evolution",
        "Significant event detection",
        "Personality consistency maintenance"
    ]

    let updateFrequency: TimeInterval = 30  // seconds

    let stateSchema = """
        {
            "emberState": {
                "currentASV": [ ... ],
                "boundedNeeds": {
                    "purpose": 0.0-1.0,
                    "connection": 0.0-1.0,
                    "growth": 0.0-1.0
                },
                "recentEmotionalEvents": [ ... ],
                "personalityParameters": { ... }
            }
        }
        """
}
```

---

## Appendix B: Work Specification Examples

### Simple Research Task

```json
{
    "id": "work-abc123",
    "type": "research",
    "description": "Research flight options from SFO to Tokyo NRT for March 15-22",
    "successCriteria": [
        "At least 3 flight options identified",
        "Prices included for each option",
        "Flight duration noted",
        "Airline identified"
    ],
    "context": {
        "relevantMemories": [
            {"type": "preference", "content": "User prefers window seats"},
            {"type": "preference", "content": "User avoids red-eye flights"}
        ],
        "userPreferences": {
            "airline_loyalty": "United",
            "class_preference": "economy"
        }
    },
    "constraints": {
        "maxIterations": 3,
        "timeoutSeconds": 60,
        "preferLocal": true,
        "toolsAllowed": ["web_search", "web_fetch"]
    },
    "status": "pending"
}
```

### Complex Synthesis Task

```json
{
    "id": "work-def456",
    "type": "synthesis",
    "description": "Synthesize Tokyo trip itinerary from research results",
    "successCriteria": [
        "Coherent day-by-day plan",
        "All researched options incorporated",
        "User preferences reflected",
        "Logical geographic flow",
        "Presented in Ember's voice"
    ],
    "context": {
        "inputWorkIds": ["work-flights", "work-hotels", "work-activities", "work-restaurants"],
        "relevantMemories": [
            {"type": "fact", "content": "User's first time in Japan"},
            {"type": "preference", "content": "User interested in traditional culture"}
        ]
    },
    "constraints": {
        "maxIterations": 2,
        "timeoutSeconds": 90,
        "preferLocal": false,
        "toolsAllowed": []
    },
    "status": "pending"
}
```

---

*Document Version: 1.0*
*Last Updated: February 5, 2026*
*Author: EmberHearth Team + Claude*

---

> "The human brain doesn't run on a single process. Neither should Ember."
