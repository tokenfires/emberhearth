# Iterative Quality Loops Research

**Status:** Research Complete
**Priority:** High (Informs MVP Design)
**Last Updated:** February 5, 2026
**Related:** [Autonomous Operation](../specs/autonomous-operation.md), [Error Handling](../specs/error-handling.md)

---

## Executive Summary

The "Ralph Loop" technique has emerged as an effective pattern for improving LLM output quality through iterative execution with fresh context. This research explores how EmberHearth can adapt this pattern to ensure Ember produces reliable, high-quality results — particularly for tool calls and complex tasks.

**Key Insight:** The pattern works because it trades compute for quality through iteration, while avoiding context pollution from failed attempts.

**EmberHearth Adaptation:** Rather than blind loops, Ember uses context-aware quality cycles with dynamic iteration based on task complexity. She communicates expected duration to users, removing surprises while ensuring quality outcomes.

---

## Table of Contents

1. [What is the Ralph Loop?](#1-what-is-the-ralph-loop)
2. [Why It Works](#2-why-it-works)
3. [Limitations and Risks](#3-limitations-and-risks)
4. [EmberHearth Adaptation](#4-emberhearth-adaptation)
5. [Implementation Design](#5-implementation-design)
6. [User Experience](#6-user-experience)
7. [Performance Considerations](#7-performance-considerations)
8. [MVP Scope](#8-mvp-scope)
9. [References](#9-references)

---

## 1. What is the Ralph Loop?

### 1.1 Origin

The "Ralph Loop" (or "Ralph Wiggum technique") was popularized by [Geoffrey Huntley](https://ghuntley.com/loop/) in late 2025. The name references the Simpsons character known for persistent, if naive, effort.

### 1.2 Core Pattern

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         RALPH LOOP PATTERN                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐         ┌─────────────┐         ┌─────────────┐         │
│   │    SPEC     │   ───►  │    WORK     │   ───►  │   REVIEW    │         │
│   │  (Define)   │         │  (Execute)  │         │  (Validate) │         │
│   └─────────────┘         └─────────────┘         └──────┬──────┘         │
│                                                          │                 │
│                                                          ▼                 │
│                                                   ┌─────────────┐         │
│                                                   │   PASSED?   │         │
│                                                   └──────┬──────┘         │
│                                                          │                 │
│                              ┌────────────┬──────────────┘                 │
│                              │            │                                 │
│                              ▼            ▼                                 │
│                           [YES]        [NO]                                │
│                              │            │                                 │
│                              ▼            ▼                                 │
│                         ┌────────┐   ┌────────────┐                        │
│                         │  SHIP  │   │ CLEAR CTX  │──┐                     │
│                         └────────┘   │ + ITERATE  │  │                     │
│                                      └────────────┘  │                     │
│                                           ▲          │                     │
│                                           └──────────┘                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Key characteristics:**

1. **Specification-first:** Define requirements and success criteria before execution
2. **Fresh context per iteration:** Each attempt starts clean, avoiding context pollution
3. **Explicit review:** Separate validation step determines pass/fail
4. **State via files:** Progress persists through files, not conversation history
5. **Automated backpressure:** Tests/validation gates force self-correction

### 1.3 Implementations

Several implementations have emerged:

| Implementation | Source | Key Feature |
|---------------|--------|-------------|
| [snarktank/ralph](https://github.com/snarktank/ralph) | GitHub | PRD-driven, supports Claude Code + Amp |
| [Goose Ralph Loop](https://block.github.io/goose/docs/tutorials/ralph-loop/) | Block | Worker + Reviewer model separation |
| [Ralph Playbook](https://claytonfarr.github.io/ralph-playbook/) | Clayton Farr | Detailed prompt engineering patterns |
| [Vercel Ralph Loop Agent](https://github.com/vercel-labs/ralph-loop-agent) | Vercel | AI SDK integration |

### 1.4 The Spec-to-Code Workflow

[Addy Osmani's workflow](https://addyosmani.com/blog/ai-coding-workflow/) describes the broader pattern:

```
1. Brainstorm spec WITH the AI (iterative questioning)
2. Compile spec.md (requirements, architecture, testing strategy)
3. Generate step-by-step plan (discrete, testable chunks)
4. Execute incrementally (one chunk at a time)
5. Test after each step (tight feedback loop)
6. Review output (human or AI-assisted)
7. Commit on success, iterate on failure
```

---

## 2. Why It Works

### 2.1 Context Window Optimization

**The Problem:** Standard agent loops accumulate context from failed attempts:

```
Attempt 1: [Prompt] + [Response] + [Error]
Attempt 2: [Prompt] + [Response] + [Error] + [Retry Prompt] + [Response] + [Error]
Attempt 3: [All of the above] + [More noise]...
```

By attempt 5+, the model processes thousands of tokens of failure history, reducing effective capacity for the actual task.

**Ralph's Solution:** Each iteration starts fresh:

```
Iteration 1: [Prompt] + [State Files] → [Work] → [Review] → Fail
Iteration 2: [Prompt] + [Updated State Files] → [Work] → [Review] → Fail
Iteration 3: [Prompt] + [Updated State Files] → [Work] → [Review] → Pass!
```

State persists through files, but conversation context resets. The model operates in its ["smart zone"](https://claytonfarr.github.io/ralph-playbook/) (40-60% context utilization).

### 2.2 Backpressure Forces Self-Correction

Without validation gates, LLMs can claim completion prematurely. Ralph enforces:

- **Tests must pass** — No cheating by claiming "done"
- **Type checks must pass** — Structural correctness enforced
- **Review must approve** — Second opinion catches issues

This creates what the [Ralph Playbook](https://claytonfarr.github.io/ralph-playbook/) calls "backpressure" — the system resists completion until genuinely complete.

### 2.3 Separation of Concerns

| Phase | Focus | Model Mindset |
|-------|-------|---------------|
| **Spec** | What needs to happen | Requirements analysis |
| **Work** | How to do it | Implementation |
| **Review** | Did it work? | Critical evaluation |

Separating these prevents conflation. The worker doesn't evaluate itself; a distinct review phase does.

### 2.4 Research Validation

Academic research supports the pattern. [LLMLOOP](https://www.researchgate.net/publication/394085087_LLMLOOP_Improving_LLM-Generated_Code_and_Tests_through_Automated_Iterative_Feedback_Loops) demonstrated:

> "Pass@10 of 90.24% versus pass@10 of 76.22% for the baseline when using automated iterative feedback loops."

The [PromptGuard framework](https://www.nature.com/articles/s41598-025-31086-y) achieved:

> "67% reduction in injection success rate and an F1-score of 0.91 in detection, with a latency increase below 8%."

---

## 3. Limitations and Risks

### 3.1 Task Scoping Problems

From [community feedback](https://dev.to/alexandergekov/2026-the-year-of-the-ralph-loop-agent-1gkj):

> "The agent picks tasks which are too large and doesn't scope the amount of work correctly, trying things which are too ambitious."

**EmberHearth Mitigation:** Ember handles well-defined tool calls, not open-ended coding. Tasks like "add calendar event" are naturally scoped.

### 3.2 Safety Degradation Risk

A [2025 study](https://blog.codacy.com/what-everyone-gets-wrong-about-the-ralph-loop) found:

> "In pure LLM feedback loops, code safety can systematically degrade with increasing iterations, with initially secure code potentially introducing vulnerabilities."

**EmberHearth Mitigation:** Tron validates all outputs regardless of iteration count. Security scanning is non-negotiable, not part of the iteration decision.

### 3.3 Completion Recognition

The model may not know when to stop — either iterating infinitely or stopping prematurely.

**EmberHearth Mitigation:** Explicit success criteria defined per task type. Iteration caps prevent runaway loops.

### 3.4 Cost Implications

Multiple iterations multiply token consumption. From [Addy Osmani](https://addyosmani.com/blog/ai-coding-workflow/):

> "Trading compute cost for developer time."

**EmberHearth Mitigation:** Iteration only for tool calls that fail or complex tasks. Simple queries don't iterate.

### 3.5 Latency Impact

Each iteration adds latency. Users experience delays.

**EmberHearth Mitigation:** Ember communicates expected duration upfront. Background processing where appropriate.

---

## 4. EmberHearth Adaptation

### 4.1 Core Philosophy

EmberHearth adapts Ralph Loop principles while maintaining Ember's personality and the user-first experience:

| Ralph Loop | EmberHearth Adaptation |
|------------|------------------------|
| Blind iteration until pass | Context-aware iteration based on task complexity |
| Different model as reviewer | Structured self-check prompts (maintains Claude consistency) |
| File-based state | Memory system + session state |
| Generic bash loop | Integrated into XPC service architecture |
| Developer-focused | Consumer-friendly with communication |

### 4.2 Scope: Tool Calls

Ember uses iterative quality patterns specifically for **tool calls** — discrete actions with verifiable outcomes:

| Tool Call Type | Iteration Appropriate? | Why |
|----------------|----------------------|-----|
| Create calendar event | ✅ Yes | Verifiable: event exists with correct details |
| Send iMessage | ✅ Yes | Verifiable: message sent successfully |
| Query memory | ✅ Yes | Verifiable: relevant results returned |
| Create reminder | ✅ Yes | Verifiable: reminder created correctly |
| Simple question response | ❌ No | No external action to verify |
| Casual conversation | ❌ No | Subjective, no "correct" answer |

### 4.3 Dynamic Quality Cycles

Unlike rigid Ralph Loops, Ember dynamically determines iteration needs based on:

**Task Complexity:**
```
Simple task (add reminder):       1-2 iterations max
Medium task (plan dinner):        2-3 iterations
Complex task (travel itinerary):  3-5 iterations
```

**Confidence Signal:**
```
High confidence result:           Skip review, ship
Medium confidence result:         Self-check, then ship
Low confidence result:            Full review cycle
```

**User Signals:**
```
User explicitly asked for quick:  Minimize iterations
User asked for "thorough":        Maximize quality cycles
Previous failures on similar:     Increase iterations
```

### 4.4 Communication as Core Feature

Ember doesn't iterate silently. She communicates:

```
User: "Plan my trip to Tokyo next month"

Ember: "A Tokyo trip! That's exciting. Let me put together an itinerary for you.
        This will take me a minute or two — I want to make sure I get the
        details right. I'll message you when it's ready."

[Ember works in background, iterating until satisfied]

Ember: "Okay, I've put together a 7-day Tokyo itinerary! Here's what I'm
        thinking: [details]. Does this look good, or should I adjust anything?"
```

This removes surprises and sets expectations — a key principle from the [autonomous operation spec](../specs/autonomous-operation.md).

---

## 5. Implementation Design

### 5.1 Quality Cycle Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     EMBER QUALITY CYCLE ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   User Request                                                              │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                    TASK CLASSIFIER                                   │  │
│   │  • Determines task type (simple/medium/complex)                     │  │
│   │  • Estimates iteration needs                                        │  │
│   │  • Decides sync vs background processing                            │  │
│   │  • Generates user communication (if async)                          │  │
│   └───────────────────────────────┬─────────────────────────────────────┘  │
│                                   │                                         │
│                   ┌───────────────┴───────────────┐                        │
│                   │                               │                         │
│                   ▼                               ▼                         │
│            [SIMPLE TASK]                  [COMPLEX TASK]                   │
│                   │                               │                         │
│                   ▼                               ▼                         │
│   ┌─────────────────────────┐     ┌─────────────────────────────────────┐  │
│   │    DIRECT EXECUTION     │     │         QUALITY LOOP                 │  │
│   │  • Single attempt       │     │                                      │  │
│   │  • Verify result        │     │  ┌────────────┐                      │  │
│   │  • Return immediately   │     │  │   PLAN     │ ← Define success     │  │
│   └─────────────────────────┘     │  │  (Spec)    │   criteria           │  │
│                                   │  └─────┬──────┘                      │  │
│                                   │        │                              │  │
│                                   │        ▼                              │  │
│                                   │  ┌────────────┐                      │  │
│                                   │  │  EXECUTE   │ ← Perform action     │  │
│                                   │  │  (Work)    │                      │  │
│                                   │  └─────┬──────┘                      │  │
│                                   │        │                              │  │
│                                   │        ▼                              │  │
│                                   │  ┌────────────┐                      │  │
│                                   │  │  VERIFY    │ ← Check result       │  │
│                                   │  │  (Review)  │   against criteria   │  │
│                                   │  └─────┬──────┘                      │  │
│                                   │        │                              │  │
│                                   │   [PASS?]───────► SHIP              │  │
│                                   │        │                              │  │
│                                   │       [NO]                           │  │
│                                   │        │                              │  │
│                                   │        ▼                              │  │
│                                   │  ┌────────────┐                      │  │
│                                   │  │   LEARN    │ ← Record failure     │  │
│                                   │  │  (Refine)  │   mode, adjust       │  │
│                                   │  └─────┬──────┘                      │  │
│                                   │        │                              │  │
│                                   │        └──────► [ITERATE or FAIL]   │  │
│                                   │                                      │  │
│                                   └─────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Task Classification

```swift
enum TaskComplexity {
    case simple      // Single tool call, clear outcome
    case medium      // Multiple related tool calls
    case complex     // Multi-step planning required
}

struct TaskClassification {
    let complexity: TaskComplexity
    let estimatedIterations: Int
    let estimatedDuration: TimeInterval
    let processingMode: ProcessingMode

    enum ProcessingMode {
        case synchronous       // User waits for response
        case backgroundQuick   // Quick background, notify when done
        case backgroundLong    // Extended background, progress updates
    }
}

func classifyTask(_ request: UserRequest) -> TaskClassification {
    // Analyze request characteristics
    let toolCallCount = estimateToolCalls(request)
    let hasExternalDependencies = checkExternalDependencies(request)
    let historicalComplexity = lookupSimilarTasks(request)

    // Classify
    let complexity: TaskComplexity
    switch toolCallCount {
    case 1:
        complexity = .simple
    case 2...4:
        complexity = hasExternalDependencies ? .complex : .medium
    default:
        complexity = .complex
    }

    // Estimate iterations
    let estimatedIterations = switch complexity {
    case .simple: 1
    case .medium: min(2, 1 + (historicalComplexity.failureRate > 0.3 ? 1 : 0))
    case .complex: 3
    }

    // Estimate duration
    let baseDuration = switch complexity {
    case .simple: 2.0
    case .medium: 8.0
    case .complex: 30.0
    }
    let estimatedDuration = baseDuration * Double(estimatedIterations)

    // Determine processing mode
    let processingMode: ProcessingMode
    if estimatedDuration < 5.0 {
        processingMode = .synchronous
    } else if estimatedDuration < 30.0 {
        processingMode = .backgroundQuick
    } else {
        processingMode = .backgroundLong
    }

    return TaskClassification(
        complexity: complexity,
        estimatedIterations: estimatedIterations,
        estimatedDuration: estimatedDuration,
        processingMode: processingMode
    )
}
```

### 5.3 Structured Self-Check Prompts

Rather than a separate reviewer model, Ember uses structured self-check prompts:

```swift
struct SelfCheckPrompt {

    static func forToolCall(_ toolCall: ToolCall, result: ToolResult) -> String {
        """
        SELF-CHECK: Verify this tool call result.

        ORIGINAL REQUEST: \(toolCall.originalUserRequest)

        TOOL CALLED: \(toolCall.name)
        PARAMETERS: \(toolCall.parameters)

        RESULT: \(result.summary)

        VERIFICATION QUESTIONS:
        1. Does the result match what the user asked for?
        2. Are all required fields populated correctly?
        3. Are there any obvious errors or inconsistencies?
        4. Would this result make the user happy?

        If ALL answers are YES, respond: VERIFIED
        If ANY answer is NO, respond: ISSUE: [brief description]
        """
    }

    static func forComplexTask(_ task: ComplexTask, result: TaskResult) -> String {
        """
        SELF-CHECK: Verify this complex task completion.

        ORIGINAL REQUEST: \(task.originalUserRequest)

        SUCCESS CRITERIA:
        \(task.successCriteria.enumerated().map { "  \($0 + 1). \($1)" }.joined(separator: "\n"))

        ACTIONS TAKEN:
        \(task.actionsTaken.enumerated().map { "  \($0 + 1). \($1)" }.joined(separator: "\n"))

        FINAL RESULT:
        \(result.summary)

        For each success criterion, answer: MET / NOT MET / PARTIAL

        Overall assessment:
        - If ALL criteria MET: VERIFIED
        - If any NOT MET or PARTIAL: ISSUE: [which criteria and why]
        """
    }
}
```

### 5.4 Learning from Failures

When iterations fail, Ember records the failure mode to improve future attempts:

```swift
struct IterationLearning {
    let taskType: String
    let failureMode: FailureMode
    let resolution: String?
    let timestamp: Date

    enum FailureMode {
        case missingParameter(String)
        case invalidFormat(String)
        case externalServiceError(String)
        case logicError(String)
        case userClarificationNeeded(String)
    }
}

class QualityLearningStore {
    func recordFailure(_ learning: IterationLearning) {
        // Append to learning log
        // Use in future classification and prompting
    }

    func getRelevantLearnings(for taskType: String) -> [IterationLearning] {
        // Retrieve past learnings for similar tasks
        // Inform iteration estimates and prompting
    }
}
```

### 5.5 Iteration Caps and Escalation

```swift
struct QualityLoopConfig {
    // Maximum iterations per complexity level
    static let maxIterations: [TaskComplexity: Int] = [
        .simple: 2,
        .medium: 3,
        .complex: 5
    ]

    // When max iterations reached without success
    enum EscalationStrategy {
        case returnBestAttempt      // Return most promising result with caveat
        case askUserForClarification // Ask user to refine request
        case reportFailure          // Honestly report inability to complete
    }

    static func escalationStrategy(for task: TaskClassification) -> EscalationStrategy {
        switch task.complexity {
        case .simple:
            return .reportFailure  // Simple tasks should succeed or fail clearly
        case .medium:
            return .returnBestAttempt
        case .complex:
            return .askUserForClarification
        }
    }
}
```

---

## 6. User Experience

### 6.1 Communication Patterns

**Simple Task (Synchronous):**
```
User: "Add a reminder to call Mom tomorrow at 3pm"
Ember: "Done! I've set a reminder for tomorrow at 3pm to call Mom. 📞"
```

**Medium Task (Background Quick):**
```
User: "Schedule dinner reservations for Saturday"
Ember: "I'll find some options for Saturday dinner. Give me just a moment..."
[5 seconds later]
Ember: "I found three restaurants with availability Saturday evening:
        1. Noma — 7:30pm
        2. Eleven Madison Park — 8:00pm
        3. Alinea — 7:00pm
        Which sounds good?"
```

**Complex Task (Background Long):**
```
User: "Plan my trip to Tokyo next month"
Ember: "A Tokyo trip! That's exciting. Let me put together a proper itinerary.
        This will take me a minute or two — I want to make sure I get the
        details right. I'll message you when it's ready."

[Ember works in background, user can continue other conversations]

[2 minutes later]
Ember: "Okay! I've put together a 7-day Tokyo itinerary for you. Here's the overview:

        Day 1: Arrive Narita, check into Shinjuku hotel
        Day 2: Senso-ji Temple, Asakusa, Ueno Park
        ...

        I've also noted the best times to visit each spot and some restaurant
        recommendations. Want me to add these as calendar events?"
```

### 6.2 Failure Communication

When quality cycles exhaust without success:

```
User: "Book me the cheapest flight to Paris next Friday"

[Ember iterates but can't find availability]

Ember: "I looked into flights to Paris for next Friday, but I ran into some issues.
        Most flights are either sold out or significantly more expensive than usual
        ($1,200+).

        A few options:
        • I can keep checking over the next few hours in case something opens up
        • Friday the 14th has much better availability — want me to check that instead?
        • I can show you what's currently available so you can decide

        What would you prefer?"
```

### 6.3 Transparency Without Overwhelm

Ember doesn't expose iteration internals to users, but she's honest about her process:

❌ **Too technical:**
> "Iteration 3 of 5: Self-check failed on criterion 2. Retrying with adjusted parameters."

❌ **Too vague:**
> "Working on it..."

✅ **Just right:**
> "Let me double-check those details to make sure everything's correct."

---

## 7. Performance Considerations

### 7.1 Token Economics

| Scenario | Without Quality Loop | With Quality Loop | Overhead |
|----------|---------------------|-------------------|----------|
| Simple tool call (success) | ~500 tokens | ~600 tokens | +20% |
| Simple tool call (1 retry) | ~1000 tokens | ~800 tokens | -20% (cleaner context) |
| Complex task (3 iterations) | ~5000 tokens (accumulated) | ~3000 tokens | -40% (fresh context wins) |

**Key insight:** Fresh context per iteration often *reduces* total tokens compared to accumulated failure context.

### 7.2 Latency Budget

| Task Type | Target Latency | Max Iterations | Timeout |
|-----------|---------------|----------------|---------|
| Simple | <3s | 2 | 10s |
| Medium | <15s | 3 | 30s |
| Complex | <60s | 5 | 120s |

### 7.3 Background Processing Benefits

Complex tasks run in background, meaning:
- User isn't blocked waiting
- Ember can use more iterations without UX penalty
- Failed attempts don't visibly frustrate user
- Success message feels like a pleasant notification

---

## 8. MVP Scope

### 8.1 MVP Implementation

For MVP, implement a simplified quality cycle:

| Feature | MVP | v1.0 | Full |
|---------|-----|------|------|
| Task classification | ✅ Simple heuristics | ✅ ML-based | ✅ Learned from history |
| Self-check prompts | ✅ Basic verification | ✅ Structured prompts | ✅ Adaptive prompts |
| Iteration (simple tasks) | ✅ 1-2 max | ✅ 1-2 max | ✅ Dynamic |
| Iteration (complex tasks) | ❌ Deferred | ✅ 3 max | ✅ Dynamic |
| Background processing | ❌ Deferred | ✅ Basic | ✅ Full queue |
| Learning from failures | ❌ Deferred | ❌ Deferred | ✅ Full |
| User communication | ✅ Basic | ✅ Contextual | ✅ Personality-rich |

### 8.2 MVP Code Structure

```
src/
├── Quality/
│   ├── TaskClassifier.swift       # Determine task complexity
│   ├── QualityLoop.swift          # Iteration coordinator
│   ├── SelfCheck.swift            # Verification prompts
│   └── QualityConfig.swift        # Iteration limits, timeouts
```

### 8.3 MVP Integration Point

```swift
// In tool execution flow
func executeToolCall(_ toolCall: ToolCall) async -> ToolResult {
    let classification = TaskClassifier.classify(toolCall)

    var attempts = 0
    var lastResult: ToolResult?

    while attempts < classification.maxIterations {
        attempts += 1

        // Execute
        let result = await performToolCall(toolCall)

        // Self-check
        let verification = await SelfCheck.verify(toolCall, result: result)

        if verification.passed {
            return result
        }

        lastResult = result

        // If more iterations allowed, adjust and retry
        if attempts < classification.maxIterations {
            // Record learning
            QualityLearning.record(verification.issue)
            // Adjust parameters if possible
            toolCall = adjustForRetry(toolCall, feedback: verification.feedback)
        }
    }

    // Max iterations reached
    return handleMaxIterations(toolCall, bestAttempt: lastResult, classification: classification)
}
```

---

## 9. References

### 9.1 Primary Sources

- [Geoffrey Huntley — Everything is a Ralph Loop](https://ghuntley.com/loop/)
- [snarktank/ralph — GitHub](https://github.com/snarktank/ralph)
- [Ralph Playbook — Clayton Farr](https://claytonfarr.github.io/ralph-playbook/)
- [Goose Ralph Loop Tutorial](https://block.github.io/goose/docs/tutorials/ralph-loop/)

### 9.2 Workflow References

- [Addy Osmani — My LLM Coding Workflow Going Into 2026](https://addyosmani.com/blog/ai-coding-workflow/)
- [Harper Reed — My LLM Codegen Workflow](https://harper.blog/2025/02/16/my-llm-codegen-workflow-atm/)

### 9.3 Research

- [LLMLOOP: Improving LLM-Generated Code Through Iterative Feedback](https://www.researchgate.net/publication/394085087_LLMLOOP_Improving_LLM-Generated_Code_and_Tests_through_Automated_Iterative_Feedback_Loops)
- [PromptGuard: Four-Layer Defense Framework](https://www.nature.com/articles/s41598-025-31086-y)

### 9.4 Critical Analysis

- [What Everyone Gets Wrong About Ralph Loop — Codacy](https://blog.codacy.com/what-everyone-gets-wrong-about-the-ralph-loop)
- [Your Agent Orchestrator Is Too Clever — Chris Sherwood](https://www.chrismdp.com/your-agent-orchestrator-is-too-clever/)
- [2026: The Year of the Ralph Loop Agent — DEV Community](https://dev.to/alexandergekov/2026-the-year-of-the-ralph-loop-agent-1gkj)

### 9.5 EmberHearth Internal

- [Autonomous Operation Spec](../specs/autonomous-operation.md)
- [Error Handling Spec](../specs/error-handling.md)
- [Personality Design](personality-design.md)

---

## Appendix A: Ralph Loop Prompt Templates

Example prompts from the Ralph Playbook that inform EmberHearth's approach:

**Planning Phase:**
```
Study the specs in specs/*.md and the current codebase.
Identify gaps between what's specified and what's implemented.
Update IMPLEMENTATION_PLAN.md with prioritized tasks.
Do not implement anything — planning only.
```

**Building Phase:**
```
Read IMPLEMENTATION_PLAN.md.
Select the highest priority incomplete task.
Implement it following the patterns in AGENTS.md.
Run tests to verify.
On success: commit, mark complete, update plan.
On failure: record learning, try different approach.
```

**Review Phase:**
```
Evaluate the work against the original task description.
Check: Does it meet all acceptance criteria?
Check: Are there any obvious issues?
If ready to ship: respond "SHIP"
If needs revision: respond "REVISE: [specific feedback]"
```

---

*Document Version: 1.0*
*Last Updated: February 5, 2026*
*Author: EmberHearth Team + Claude*
