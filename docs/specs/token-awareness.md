# Token Awareness Specification

**Version:** 1.0
**Date:** February 3, 2026
**Status:** Research Complete

---

## The Problem

### Horror Stories

**Moltbot users:** Some hit hundreds or thousands of dollars in unexpected charges because token spend wasn't visible until the bill arrived.

**Cursor users:** The thin circle shows usage, but not *rate*. Users see 50% used by week 1, panic, self-throttle—then lose 40% of their tokens at month-end reset. They paid for tokens they never used because the UI made them scared.

**OpenAI API users:** The dashboard shows historical usage but not projections. You find out you overspent *after* the billing cycle.

### The Grandmother Test

Grandmother shouldn't:
- See a $500 bill because Ember got chatty
- Have to understand what a "token" is
- Need to calculate burn rates manually
- Worry about this at all

Power users should:
- See exactly where tokens are going
- Get projections based on current pace
- Understand cost per conversation
- Have granular control

---

## Design Philosophy

### Ember is Token-Aware

Ember doesn't just *track* token usage—she *understands* it. She knows:
- How much budget remains
- Whether she's on pace or running hot
- When to be more concise vs. more thorough
- How to communicate about her own resource constraints

### Two-Tier Transparency

| User Type | Needs | Solution |
|-----------|-------|----------|
| **Grandmother** | "Am I okay?" | Simple visual + natural language from Ember |
| **Power User** | "Show me everything" | Detailed dashboard with projections |

### No Surprises, Ever

The system should make it **impossible** to accidentally overspend:
- Hard spending cap (not just alerts)
- Automatic quality adjustment before hitting limit
- Ember proactively communicates constraints

---

## Part 1: Usage Visualization

### 1.1 Menu Bar Indicator (Always Visible)

A subtle, always-visible indicator in the macOS menu bar:

```
Normal:     ◐ Ember          (half-filled = ~50% used)
Good pace:  ◑ Ember          (quarter = under pace)
Hot:        ◕ Ember          (three-quarter = over pace)
Critical:   ● Ember (!)      (full + warning)
```

**Click to expand:** Shows quick summary popup

```
┌────────────────────────────────────────┐
│  February Usage                        │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│  ████████████████░░░░░░░░░░  63%       │
│                                        │
│  $12.60 of $20.00 budget               │
│  18 days remaining                     │
│                                        │
│  📊 You're slightly ahead of pace.     │
│     At this rate: ~$19.40 by month end │
│                                        │
│  [View Details]              [Settings]│
└────────────────────────────────────────┘
```

**Color coding:**
- 🟢 Green: Under pace (will have tokens left over)
- 🟡 Yellow: On pace (tracking to budget)
- 🟠 Orange: Over pace (will exceed at current rate)
- 🔴 Red: Critical (approaching hard limit)

### 1.2 Simple View (Default in Mac App)

For grandmother—answers "Am I okay?" at a glance:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   This Month's Usage                                    │
│                                                         │
│        ┌─────────────────────────────────┐              │
│        │  ████████████████░░░░░░░░░░░░░  │  63%         │
│        └─────────────────────────────────┘              │
│                                                         │
│   ✓ You're on track                                     │
│                                                         │
│   Ember is adjusting her responses to stay              │
│   within your $20/month budget.                         │
│                                                         │
│   [That's all I need to know]     [Show me more →]      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Status messages (plain English):**
- ✓ "You're on track" — Under or at pace
- ✓ "You're under budget—Ember can be more thorough" — Significantly under
- ⚠ "You're using more than usual" — Over pace but not critical
- ⚠ "Ember is being concise to stay in budget" — Quality adjusted
- 🛑 "Budget reached—Ember will resume on [date]" — Hard limit hit

### 1.3 Detailed View (Power Users)

Behind "Show me more →":

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   February 2026 Usage Details                                   │
│                                                                 │
│   ┌───────────────────────────────────────────────────────────┐ │
│   │                         Burn Rate Chart                    │ │
│   │   $                                                        │ │
│   │   20 ┤                                        ••••• Budget │ │
│   │      │                              ∙∙∙∙∙∙∙∙∙              │ │
│   │   15 ┤                    ∙∙∙∙∙∙∙∙∙                        │ │
│   │      │          ████████                                   │ │
│   │   10 ┤    ██████        Actual ━━                          │ │
│   │      │ ███              Projected ∙∙                       │ │
│   │    5 ┤                                                     │ │
│   │      │                                                     │ │
│   │    0 ┼────┬────┬────┬────┬────┬────┬────┬────┬────┬────┤  │ │
│   │      1    4    7   10   13   16   19   22   25   28       │ │
│   │                        Day of Month                        │ │
│   └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│   ┌─────────────────────┐  ┌─────────────────────┐              │
│   │ Current             │  │ Projections         │              │
│   │                     │  │                     │              │
│   │ Spent:    $12.60    │  │ At current pace:    │              │
│   │ Budget:   $20.00    │  │   $19.40 (97%)      │              │
│   │ Remaining: $7.40    │  │                     │              │
│   │                     │  │ If you maintain     │              │
│   │ Days elapsed: 12    │  │ today's average:    │              │
│   │ Days remaining: 18  │  │   $21.20 (106%)     │              │
│   │                     │  │                     │              │
│   │ Daily average:      │  │ Budget resets:      │              │
│   │   $1.05/day         │  │   March 1, 2026     │              │
│   │ Budget pace:        │  │                     │              │
│   │   $0.67/day         │  │                     │              │
│   └─────────────────────┘  └─────────────────────┘              │
│                                                                 │
│   Usage Breakdown                                               │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ Conversations      ███████████████████░░░  78%  $9.83   │   │
│   │ Calendar queries   ████░░░░░░░░░░░░░░░░░░  12%  $1.51   │   │
│   │ Memory operations  ██░░░░░░░░░░░░░░░░░░░░   7%  $0.88   │   │
│   │ Other              █░░░░░░░░░░░░░░░░░░░░░   3%  $0.38   │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   [Export Report]  [Adjust Budget]  [Quality Settings]          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.4 Historical View

```
┌─────────────────────────────────────────────────────────────┐
│   Usage History                                             │
│                                                             │
│   Month         Budget    Spent     Unused   Quality Mode   │
│   ─────────────────────────────────────────────────────────│
│   Feb 2026      $20.00    $12.60*   —        Standard       │
│   Jan 2026      $20.00    $18.45    $1.55    Standard       │
│   Dec 2025      $20.00    $23.80†   —        Standard       │
│   Nov 2025      $15.00    $14.22    $0.78    Standard       │
│                                                             │
│   * Current month (in progress)                             │
│   † Budget was increased mid-month                          │
│                                                             │
│   Lifetime: $68.07 across 4 months                          │
│   Average: $17.02/month                                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Part 2: Adaptive Quality System

### 2.1 The Core Insight

> If you're under-utilizing tokens, Ember should give you MORE value.
> If you're over-utilizing, Ember should gracefully reduce quality before hitting a wall.

This is the opposite of "set it and forget it" pricing—it's dynamic value optimization.

### 2.2 Quality Tiers

| Tier | Model | Context | Response Style | When Used |
|------|-------|---------|----------------|-----------|
| **Premium** | Claude Opus / GPT-4 | Full | Thorough, detailed | Under 50% pace |
| **Standard** | Claude Sonnet / GPT-4o | Full | Balanced | 50-80% pace |
| **Efficient** | Claude Haiku / GPT-4o-mini | Reduced | Concise | 80-95% pace |
| **Minimal** | Cheapest available | Minimal | Brief | 95-100% pace |
| **Paused** | None | — | Queued | Over budget |

### 2.3 Quality Adjustment Logic

```
Budget Utilization vs. Time Elapsed
─────────────────────────────────────────────────────────────

    100% ┤                                          ┌─────────
        │                                     ┌────┘ PAUSED
     95% ┤                               ┌───┘
        │                          ┌────┘      Minimal
     80% ┤                    ┌───┘
        │               ┌────┘            Efficient
     50% ┤         ┌───┘
        │    ┌────┘                    Standard
        │ ──┘
      0% ┼─────────────────────────────────────────────────────
        0%                     Time →                      100%
                                                      Premium ↓

If utilization < expected_for_time: Quality UP
If utilization > expected_for_time: Quality DOWN
```

**Example scenarios:**

| Day | Budget Used | Expected | Quality Decision |
|-----|-------------|----------|------------------|
| Day 7 (25% of month) | 15% | 25% | Upgrade to Premium (under pace) |
| Day 15 (50% of month) | 50% | 50% | Stay Standard (on pace) |
| Day 15 (50% of month) | 70% | 50% | Downgrade to Efficient (over pace) |
| Day 28 (93% of month) | 40% | 93% | Upgrade to Premium (way under!) |

### 2.4 User Control Over Automatic Adjustment

Settings → Usage → Quality Adjustment:

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   Automatic Quality Adjustment                              │
│                                                             │
│   ( ) Off — Always use Standard quality                     │
│   (•) Smart — Adjust based on budget pace (Recommended)     │
│   ( ) Maximize — Always use best quality until budget hit   │
│   ( ) Minimize — Always use cheapest, save money            │
│                                                             │
│   ─────────────────────────────────────────────────────────│
│                                                             │
│   When approaching budget limit:                            │
│                                                             │
│   (•) Reduce quality to stay within budget                  │
│   ( ) Stop responding (resume next billing cycle)           │
│   ( ) Allow 10% overage (I'll pay the extra)                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Part 3: Proactive Communication

### 3.1 Ember Talks About Her Budget

Ember should naturally mention her resource constraints when relevant:

**When quality is upgraded:**
> "I've got some extra capacity this month, so I can be more thorough if you'd like!"

**When quality is reduced:**
> "I'm being a bit more concise lately to stay within our budget for the month. Let me know if you need more detail on anything specific."

**When approaching limit:**
> "Heads up—we're getting close to our monthly budget. I'll keep helping, but I might be briefer than usual for the next few days."

**When limit is reached:**
> "I've hit our budget for February. I'll be back to full speed on March 1st! In the meantime, I can still help with quick questions."

### 3.2 User Can Ask

**User:** "Ember, how's our budget looking?"

**Ember:** "We're doing well! We've used about 63% of our February budget with 18 days left. At this pace, we'll end the month right around $19—just under the $20 budget. I'm using my standard quality right now. Want me to show you the details in the app?"

### 3.3 Notification Thresholds

| Threshold | Notification Type | Message |
|-----------|-------------------|---------|
| 50% | None (on track) | — |
| 50% early (< 40% of month) | Gentle via iMessage | "We're moving through our budget a bit faster than usual..." |
| 75% | Badge on app icon | — |
| 90% | macOS notification | "Ember is switching to concise mode to stay in budget" |
| 100% | macOS notification + iMessage | "Budget reached—Ember will respond to urgent messages only until [date]" |

---

## Part 4: Hard Spending Cap

### 4.1 The Guarantee

**No matter what, spending will not exceed the user's configured budget.**

This is not an alert. This is not a warning. This is a hard stop.

### 4.2 Implementation

```swift
class BudgetEnforcer {
    func canProcessRequest(_ request: LLMRequest) -> BudgetDecision {
        let currentSpend = UsageTracker.currentMonthSpend()
        let budget = UserSettings.monthlyBudget
        let estimatedCost = estimateCost(request)

        // Hard limit check
        if currentSpend + estimatedCost > budget {
            return .denied(reason: .budgetExceeded)
        }

        // Soft limit check (95%)
        if currentSpend + estimatedCost > budget * 0.95 {
            return .allowWithConstraints(
                maxTokens: calculateSafeTokenLimit(remaining: budget - currentSpend),
                model: .cheapest
            )
        }

        return .allowed
    }
}
```

### 4.3 Grace Handling

When budget is exhausted:

1. **Acknowledge receipt:** "I got your message..."
2. **Provide context:** "I've reached our February budget"
3. **Set expectations:** "I'll be back to normal on March 1st"
4. **Offer alternatives:** "For urgent matters, you can [increase budget / wait]"

---

## Part 5: Budget Configuration

### 5.1 Onboarding

During setup, after API key entry:

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   Set Your Monthly Budget                                   │
│                                                             │
│   How much would you like to spend on Ember each month?     │
│                                                             │
│         ┌─────────────────────────────────────┐             │
│         │  $ [ 20.00 ]  per month             │             │
│         └─────────────────────────────────────┘             │
│                                                             │
│   Based on typical usage, this gives you:                   │
│   • ~500-800 conversational exchanges                       │
│   • ~50-100 calendar/reminder operations                    │
│   • Room for Ember to be thorough when helpful              │
│                                                             │
│   💡 Tip: Most users spend $10-30/month. You can always     │
│      change this later in Settings.                         │
│                                                             │
│   ┌───────────────────────────────────────────────────────┐ │
│   │ ☑ Never exceed this budget (recommended)              │ │
│   │   Ember will adjust quality to stay within budget     │ │
│   └───────────────────────────────────────────────────────┘ │
│                                                             │
│                                              [Continue →]   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Settings Panel

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   Budget Settings                                           │
│                                                             │
│   Monthly budget:  $ [ 20.00 ]                              │
│                                                             │
│   ☑ Hard limit (never exceed budget)                        │
│   ☐ Soft limit (warn at 90%, allow overage up to 10%)       │
│                                                             │
│   ─────────────────────────────────────────────────────────│
│                                                             │
│   Budget alerts:                                            │
│   ☑ Notify me at 75% usage                                  │
│   ☑ Notify me at 90% usage                                  │
│   ☐ Weekly usage summary                                    │
│                                                             │
│   ─────────────────────────────────────────────────────────│
│                                                             │
│   Billing cycle resets: 1st of each month                   │
│   (Based on your LLM provider billing cycle)                │
│                                                             │
│   [Save Changes]                                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Part 6: Data Model

### 6.1 Usage Record Schema

```sql
CREATE TABLE usage_records (
    id INTEGER PRIMARY KEY,
    timestamp TEXT NOT NULL,              -- ISO 8601
    request_type TEXT NOT NULL,           -- 'conversation', 'calendar', 'memory', etc.
    model TEXT NOT NULL,                  -- 'claude-sonnet', 'gpt-4o', etc.
    input_tokens INTEGER NOT NULL,
    output_tokens INTEGER NOT NULL,
    cost_cents INTEGER NOT NULL,          -- Store as cents to avoid float issues
    quality_tier TEXT NOT NULL,           -- 'premium', 'standard', 'efficient', 'minimal'
    conversation_id TEXT,                 -- For grouping
    billing_period TEXT NOT NULL          -- '2026-02' for February 2026
);

CREATE INDEX idx_usage_billing_period ON usage_records(billing_period);
CREATE INDEX idx_usage_timestamp ON usage_records(timestamp);
```

### 6.2 Budget Settings Schema

```sql
CREATE TABLE budget_settings (
    id INTEGER PRIMARY KEY,
    monthly_budget_cents INTEGER NOT NULL,
    hard_limit BOOLEAN NOT NULL DEFAULT 1,
    overage_percent INTEGER DEFAULT 0,    -- 0-20% allowed overage if soft limit
    quality_adjustment TEXT NOT NULL,     -- 'smart', 'off', 'maximize', 'minimize'
    notify_at_75 BOOLEAN NOT NULL DEFAULT 1,
    notify_at_90 BOOLEAN NOT NULL DEFAULT 1,
    weekly_summary BOOLEAN NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL
);
```

### 6.3 Projection Calculation

```swift
struct UsageProjection {
    let currentSpendCents: Int
    let budgetCents: Int
    let daysElapsed: Int
    let daysInPeriod: Int

    var dailyAverage: Double {
        guard daysElapsed > 0 else { return 0 }
        return Double(currentSpendCents) / Double(daysElapsed)
    }

    var expectedPace: Double {
        return Double(budgetCents) / Double(daysInPeriod)
    }

    var projectedEndSpend: Int {
        return Int(dailyAverage * Double(daysInPeriod))
    }

    var paceRatio: Double {
        // < 1.0 = under pace (good), > 1.0 = over pace (concerning)
        guard expectedPace > 0 else { return 0 }
        return dailyAverage / expectedPace
    }

    var recommendedQualityTier: QualityTier {
        switch paceRatio {
        case ..<0.5: return .premium      // Way under pace
        case 0.5..<0.8: return .standard  // Under or on pace
        case 0.8..<0.95: return .efficient // Over pace
        case 0.95..<1.0: return .minimal  // Near limit
        default: return .paused           // Over budget
        }
    }
}
```

---

## Implementation Checklist

### MVP

- [ ] Usage tracking (per-request cost logging)
- [ ] Menu bar indicator (simple circle fill)
- [ ] Basic popup (current spend / budget)
- [ ] Hard spending cap enforcement
- [ ] Budget configuration in settings
- [ ] Single quality tier (Standard only)

### v1.1

- [ ] Detailed usage view with chart
- [ ] Projection calculations
- [ ] Automatic quality adjustment (smart mode)
- [ ] Ember budget awareness (can discuss her budget)
- [ ] Notification thresholds (75%, 90%, 100%)
- [ ] Usage breakdown by category

### v1.2+

- [ ] Historical usage view
- [ ] Usage export (CSV/JSON)
- [ ] Multiple budget profiles (personal vs work)
- [ ] Cost optimization suggestions
- [ ] Anomaly detection ("unusual spike detected")

---

## Testing Requirements

```swift
// Test: Hard limit enforcement
func testHardLimitEnforcement() {
    UserSettings.monthlyBudget = 2000 // $20.00
    UsageTracker.recordSpend(1950)     // $19.50

    let request = LLMRequest(estimatedCost: 100) // $1.00

    // Should be denied (would exceed budget)
    XCTAssertEqual(
        BudgetEnforcer.canProcessRequest(request),
        .denied(reason: .budgetExceeded)
    )
}

// Test: Quality tier adjustment
func testQualityTierSelection() {
    // 50% of month elapsed, 30% of budget used = under pace
    let projection = UsageProjection(
        currentSpendCents: 600,  // $6
        budgetCents: 2000,       // $20
        daysElapsed: 15,
        daysInPeriod: 30
    )

    XCTAssertEqual(projection.recommendedQualityTier, .premium)
}

// Test: Projection accuracy
func testProjectionCalculation() {
    let projection = UsageProjection(
        currentSpendCents: 1000,  // $10
        budgetCents: 2000,        // $20
        daysElapsed: 10,
        daysInPeriod: 30
    )

    // $10 in 10 days = $1/day
    // Projected: $1 × 30 = $30
    XCTAssertEqual(projection.projectedEndSpend, 3000)
    XCTAssertGreaterThan(projection.paceRatio, 1.0) // Over pace
}
```

---

## References

- [OpenAI Usage Dashboard](https://platform.openai.com/account/usage)
- [Claude Code Cost Management](https://code.claude.com/docs/en/costs)
- [Budget Burndown Charts](https://www.gpstrategies.com/blog/the-value-of-burndown-charts-to-manage-project-costs/)
- [PocketGuard Budget Alerts](https://pocketguard.com/)
- [AI Model Fallback Patterns](https://medium.com/@tombastaner/building-resilient-ai-systems-understanding-model-level-fallback-mechanisms-436cf636045f)
- [GenAI Cost Optimization Guide](https://www.nops.io/blog/genai-cost-optimization-the-essential-guide/)
- [Budget Pacing Concepts](https://supermetrics.com/blog/google-ads-budget-pacing)

---

## Glossary

| Term | Definition |
|------|------------|
| **Burn rate** | Rate of spending over time (e.g., $1.05/day) |
| **Pace** | Whether current burn rate will hit, exceed, or fall short of budget |
| **Quality tier** | Model/response quality level based on cost |
| **Hard limit** | Absolute spending cap that cannot be exceeded |
| **Soft limit** | Warning threshold with optional overage allowance |
| **Billing period** | Monthly cycle (typically calendar month or subscription anniversary) |
