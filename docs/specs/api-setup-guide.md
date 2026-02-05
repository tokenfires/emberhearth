# API Setup Guide & Terms of Service Clarification

**Version:** 1.0
**Date:** February 5, 2026
**Status:** Pre-Implementation
**Related:** `research/onboarding-ux.md`

---

## Overview

Many users confuse AI subscriptions (like Claude Pro or ChatGPT Plus) with API access. This confusion can lead to:

1. **Failed setup** — User enters subscription credentials that don't work
2. **Unexpected costs** — User doesn't understand pay-per-use pricing
3. **ToS violations** — Anthropic/OpenAI prohibit automated access via consumer subscriptions
4. **Support burden** — Troubleshooting auth issues wastes everyone's time

This specification defines how EmberHearth clearly explains the difference and guides users to correct setup.

---

## Part 1: The Confusion Problem

### 1.1 Why Users Get Confused

| What Users Think | Reality |
|------------------|---------|
| "I pay $20/month for Claude, I'll use that" | Subscription ≠ API access |
| "I'll log in with my email and password" | API uses keys, not login credentials |
| "It's unlimited because I have Pro" | API is pay-per-use, not unlimited |
| "The AI company will bill me through EmberHearth" | User pays the AI provider directly |

### 1.2 Terms of Service Implications

**Anthropic's Consumer Terms (as of 2025):**
> Claude Pro/Team subscriptions are for direct use through claude.ai. Automated access via third-party applications requires API access through a separate developer account.

**OpenAI's Terms (as of 2025):**
> ChatGPT Plus/Team subscriptions cannot be used for programmatic access. API access requires a separate OpenAI Platform account with usage-based billing.

**EmberHearth's Responsibility:**
- We cannot facilitate ToS violations
- We must clearly explain that subscriptions won't work
- We should help users get proper API access

---

## Part 2: Onboarding Clarification

### 2.1 Before Provider Selection

Add explicit explanation before the provider choice screen:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    How Ember Connects to AI                     │
│                                                                 │
│     Ember needs an API key to communicate with AI services.     │
│                                                                 │
│     ⚠️  Important: This is different from a subscription.       │
│                                                                 │
│     ┌───────────────────────────────────────────────────────┐   │
│     │                                                        │   │
│     │  Claude Pro / ChatGPT Plus subscriptions WON'T work.   │   │
│     │                                                        │   │
│     │  You need an API key from a developer account, which   │   │
│     │  has separate (pay-as-you-go) billing.                 │   │
│     │                                                        │   │
│     └───────────────────────────────────────────────────────┘   │
│                                                                 │
│     Most users spend $5-30/month on API usage.                  │
│     EmberHearth helps you track and limit spending.             │
│                                                                 │
│                        [ I Understand ]                         │
│                                                                 │
│                    [ What's an API key? ]                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 "What's an API key?" Expandable

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Understanding API Keys                       │
│                                                                 │
│     Think of it like this:                                      │
│                                                                 │
│     📱 Subscription (Claude Pro, ChatGPT Plus)                  │
│        • Like a gym membership                                  │
│        • Fixed monthly price                                    │
│        • Use it yourself through their website                  │
│        • Can't share with other apps                            │
│                                                                 │
│     🔑 API Key (What Ember needs)                               │
│        • Like a utility meter                                   │
│        • Pay for what you use                                   │
│        • Lets apps like Ember connect                           │
│        • You control the spending limit                         │
│                                                                 │
│     ───────────────────────────────────────────────────────     │
│                                                                 │
│     Why can't Ember use my subscription?                        │
│                                                                 │
│     The AI companies' terms of service only allow their         │
│     websites to use subscriptions. Third-party apps like        │
│     Ember must use API access, which has different pricing.     │
│                                                                 │
│                          [ Got It ]                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 Provider Selection with Cost Guidance

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Choose Your AI Provider                      │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐     │
│     │  ☁️  Claude by Anthropic              [Recommended]  │     │
│     │      Thoughtful, nuanced responses                   │     │
│     │                                                      │     │
│     │      💰 Typical cost: $5-20/month                    │     │
│     │      📊 ~$0.01-0.03 per message exchange             │     │
│     │                                                      │     │
│     │      Requires: Anthropic API account (free to create)│     │
│     │      NOT the same as: Claude Pro subscription        │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐     │
│     │  ☁️  OpenAI (GPT-4)                                  │     │
│     │      Popular, widely used                            │     │
│     │                                                      │     │
│     │      💰 Typical cost: $5-25/month                    │     │
│     │      📊 ~$0.01-0.04 per message exchange             │     │
│     │                                                      │     │
│     │      Requires: OpenAI Platform account (free to create)   │
│     │      NOT the same as: ChatGPT Plus subscription      │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐     │
│     │  💻  Local Model (Privacy-First)                     │     │
│     │      Runs entirely on your Mac                       │     │
│     │                                                      │     │
│     │      💰 Cost: Free (after setup)                     │     │
│     │      ⚠️  Less capable than cloud models              │     │
│     │                                                      │     │
│     │      Requires: M1/M2/M3/M4 Mac with 16GB+ RAM        │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.4 API Key Entry with Validation Hints

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Enter Your Anthropic API Key                 │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐     │
│     │  sk-ant-api03-                                      │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                 │
│     ✓ API keys start with "sk-ant-api"                          │
│                                                                 │
│     ───────────────────────────────────────────────────────     │
│                                                                 │
│     Don't have an API key yet?                                  │
│                                                                 │
│     1. Go to console.anthropic.com                              │
│        [ Open Anthropic Console → ]                             │
│                                                                 │
│     2. Create a free account (different from Claude.ai!)        │
│                                                                 │
│     3. Add a payment method (you only pay for what you use)     │
│                                                                 │
│     4. Go to "API Keys" and create a new key                    │
│                                                                 │
│     5. Copy the key and paste it here                           │
│                                                                 │
│     ───────────────────────────────────────────────────────     │
│                                                                 │
│     🔒 Your API key is stored in your Mac's secure Keychain.    │
│        It's never shared with anyone except Anthropic.          │
│                                                                 │
│              [ Test Connection ]    [ Continue → ]              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.5 Common Mistakes Detection

Detect and handle common errors before they frustrate users:

```swift
struct APIKeyValidator {
    enum ValidationResult {
        case valid
        case invalid(reason: InvalidReason)
    }

    enum InvalidReason {
        case wrongFormat(expected: String)
        case looksLikePassword
        case looksLikeEmail
        case tooShort
        case containsSpaces

        var userMessage: String {
            switch self {
            case .wrongFormat(let expected):
                return "This doesn't look like an API key. Keys should start with \"\(expected)\""

            case .looksLikePassword:
                return "This looks like a password, not an API key. API keys are longer and start with a specific prefix."

            case .looksLikeEmail:
                return "This looks like an email address. You need an API key, which you can get from your developer console."

            case .tooShort:
                return "API keys are usually longer than this. Make sure you copied the whole thing."

            case .containsSpaces:
                return "API keys don't contain spaces. Check for extra characters at the beginning or end."
            }
        }
    }

    static func validate(_ input: String, for provider: LLMProvider) -> ValidationResult {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Check for common mistakes
        if trimmed.contains("@") {
            return .invalid(reason: .looksLikeEmail)
        }

        if trimmed.contains(" ") {
            return .invalid(reason: .containsSpaces)
        }

        if trimmed.count < 20 {
            return .invalid(reason: .tooShort)
        }

        // Check provider-specific format
        switch provider {
        case .claude:
            if !trimmed.hasPrefix("sk-ant-") {
                return .invalid(reason: .wrongFormat(expected: "sk-ant-"))
            }

        case .openai:
            if !trimmed.hasPrefix("sk-") {
                return .invalid(reason: .wrongFormat(expected: "sk-"))
            }
        }

        return .valid
    }
}
```

### 2.6 Invalid Key Error Handling

When the key doesn't work:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    ⚠️ Connection Failed                         │
│                                                                 │
│     Anthropic returned: "Invalid API key"                       │
│                                                                 │
│     Common causes:                                              │
│                                                                 │
│     • Key was copied incorrectly (missing characters?)          │
│     • Key has been revoked or expired                           │
│     • Using Claude Pro login instead of API key                 │
│       ↳ API keys are different from your claude.ai login!       │
│     • Account doesn't have billing set up                       │
│                                                                 │
│     ───────────────────────────────────────────────────────     │
│                                                                 │
│     To get a working API key:                                   │
│                                                                 │
│     1. Go to console.anthropic.com (NOT claude.ai)              │
│     2. Sign in or create a new account                          │
│     3. Add a payment method                                     │
│     4. Create a new API key                                     │
│                                                                 │
│     [ Open Anthropic Console → ]                                │
│                                                                 │
│     [ Try Again ]                [ Use Different Provider ]     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Part 3: Cost Transparency

### 3.1 Pre-Setup Cost Expectations

Before asking for an API key, set clear expectations:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    What Will This Cost?                         │
│                                                                 │
│     API pricing is pay-as-you-go, based on usage.               │
│                                                                 │
│     Typical EmberHearth users spend:                            │
│                                                                 │
│     ┌───────────────────────────────────────────────────────┐   │
│     │  Light user (few messages/day)        $3-8/month      │   │
│     │  Average user (regular chatting)      $10-20/month    │   │
│     │  Heavy user (lots of complex tasks)   $20-40/month    │   │
│     └───────────────────────────────────────────────────────┘   │
│                                                                 │
│     EmberHearth helps you control costs:                        │
│     • Set a monthly budget cap                                  │
│     • See real-time usage in the menu bar                       │
│     • Get warnings before hitting your limit                    │
│     • Ember adjusts response length to stay in budget           │
│                                                                 │
│     💡 You can start with a $5 limit and increase if needed.    │
│                                                                 │
│                        [ Continue ]                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Budget Setup (Integrated with Onboarding)

After successful API key validation:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Set Your Monthly Budget                      │
│                                                                 │
│     How much would you like to spend on Ember each month?       │
│                                                                 │
│         ┌─────────────────────────────────────┐                 │
│         │  $ [ 20.00 ]  per month             │                 │
│         └─────────────────────────────────────┘                 │
│                                                                 │
│     Quick picks:                                                │
│     [ $5 ]  [ $10 ]  [ $20 ]  [ $50 ]  [ No limit ]            │
│                                                                 │
│     At $20/month, you get approximately:                        │
│     • 500-800 back-and-forth messages                           │
│     • 50-100 calendar/reminder operations                       │
│     • Room for Ember to be thorough when helpful                │
│                                                                 │
│     ┌───────────────────────────────────────────────────────┐   │
│     │ ☑ Hard limit: Never exceed this budget                 │   │
│     │   (Ember will get more concise near the limit)         │   │
│     └───────────────────────────────────────────────────────┘   │
│                                                                 │
│     You can change this anytime in Settings.                    │
│                                                                 │
│                                              [ Continue → ]     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Part 4: Step-by-Step Guides

### 4.1 Claude API Setup Guide

Linked from "Open Anthropic Console →" button:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Getting a Claude API Key                     │
│                                                                 │
│     Step 1: Go to the Anthropic Console                         │
│     ─────────────────────────────────────                       │
│     Visit: console.anthropic.com                                │
│                                                                 │
│     ⚠️ This is different from claude.ai (where you chat)!       │
│        The Console is for developers who build with Claude.     │
│                                                                 │
│     [ Open console.anthropic.com → ]                            │
│                                                                 │
│     ───────────────────────────────────────────────────────     │
│                                                                 │
│     Step 2: Create an account or sign in                        │
│     ─────────────────────────────────────                       │
│     • You can use your existing email                           │
│     • This creates a separate developer account                 │
│     • Your Claude Pro subscription (if any) is not connected    │
│                                                                 │
│     ───────────────────────────────────────────────────────     │
│                                                                 │
│     Step 3: Add a payment method                                │
│     ─────────────────────────────────────                       │
│     • Go to Settings → Billing                                  │
│     • Add a credit card                                         │
│     • You won't be charged until you use the API                │
│     • Set a spending limit if you want extra safety             │
│                                                                 │
│     ───────────────────────────────────────────────────────     │
│                                                                 │
│     Step 4: Create an API key                                   │
│     ─────────────────────────────────────                       │
│     • Go to Settings → API Keys                                 │
│     • Click "Create Key"                                        │
│     • Give it a name like "EmberHearth"                         │
│     • Copy the key (it starts with sk-ant-api03-)               │
│                                                                 │
│     ⚠️ You can only see the full key once! Copy it now.         │
│                                                                 │
│     ───────────────────────────────────────────────────────     │
│                                                                 │
│     Step 5: Paste the key in EmberHearth                        │
│     ─────────────────────────────────────                       │
│     • Come back to this window                                  │
│     • Paste the key in the field above                          │
│     • Click "Test Connection"                                   │
│                                                                 │
│                          [ Done ]                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 OpenAI API Setup Guide

Similar guide for OpenAI:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Getting an OpenAI API Key                    │
│                                                                 │
│     Step 1: Go to the OpenAI Platform                           │
│     ─────────────────────────────────────                       │
│     Visit: platform.openai.com                                  │
│                                                                 │
│     ⚠️ This is different from chatgpt.com!                      │
│        The Platform is for developers who build with GPT.       │
│                                                                 │
│     [ Open platform.openai.com → ]                              │
│                                                                 │
│     ───────────────────────────────────────────────────────     │
│                                                                 │
│     Step 2: Create an account or sign in                        │
│     ─────────────────────────────────────                       │
│     • You can use the same email as ChatGPT                     │
│     • But you need to set up the Platform separately            │
│     • Your ChatGPT Plus subscription is not connected           │
│                                                                 │
│     ───────────────────────────────────────────────────────     │
│                                                                 │
│     Step 3: Add a payment method                                │
│     ─────────────────────────────────────                       │
│     • Go to Settings → Billing                                  │
│     • Add credits or set up auto-reload                         │
│     • Consider setting a monthly limit                          │
│                                                                 │
│     ───────────────────────────────────────────────────────     │
│                                                                 │
│     Step 4: Create an API key                                   │
│     ─────────────────────────────────────                       │
│     • Go to API Keys in the left menu                           │
│     • Click "Create new secret key"                             │
│     • Give it a name like "EmberHearth"                         │
│     • Copy the key (it starts with sk-)                         │
│                                                                 │
│     ⚠️ You can only see the full key once! Copy it now.         │
│                                                                 │
│                          [ Done ]                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Part 5: Post-Setup Reminders

### 5.1 First Week Cost Check-In

After one week of use, if user hasn't viewed usage:

```
Ember: "Hey! We've been chatting for a week now. Just wanted to
       let you know your API usage is tracking at about $0.85/day,
       which would be around $25/month. Your budget is set to $20.

       Want me to be a bit more concise to stay under budget, or
       would you like to adjust your limit?"
```

### 5.2 Settings Reminder

In Settings → AI Provider:

```
┌─────────────────────────────────────────────────────────────────┐
│  AI Provider Settings                                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Provider: Claude (Anthropic)                                   │
│  Status: Connected ✓                                            │
│                                                                 │
│  API Key: sk-ant-api03-****...**** [ Change ]                   │
│                                                                 │
│  ───────────────────────────────────────────────────────────    │
│                                                                 │
│  ℹ️ API Usage & Billing                                         │
│                                                                 │
│  EmberHearth tracks your usage, but billing happens directly    │
│  with Anthropic. To see your bill or manage payment:            │
│                                                                 │
│  [ Open Anthropic Console → ]                                   │
│                                                                 │
│  Your EmberHearth budget ($20/month) is a local limit only.     │
│  Set a spending limit in Anthropic Console for extra safety.    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Part 6: Error Recovery

### 6.1 "My API key stopped working"

Common scenario: User's API account ran out of credits or card expired.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    ⚠️ API Connection Issue                      │
│                                                                 │
│     Ember can't connect to Claude right now.                    │
│                                                                 │
│     The error says: "Insufficient credits"                      │
│                                                                 │
│     This usually means:                                         │
│     • Your Anthropic account ran out of prepaid credits         │
│     • Your credit card on file was declined                     │
│     • You hit a spending limit you set in Anthropic Console     │
│                                                                 │
│     To fix this:                                                │
│     1. Go to console.anthropic.com                              │
│     2. Check your billing settings                              │
│     3. Add credits or update your payment method                │
│                                                                 │
│     [ Open Anthropic Console → ]                                │
│                                                                 │
│     ───────────────────────────────────────────────────────     │
│                                                                 │
│     Ember will keep trying to connect. Once your account        │
│     is sorted, she'll start responding again automatically.     │
│                                                                 │
│                          [ Okay ]                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 FAQ in Help

Settings → Help → API & Billing FAQ:

```
Q: Why can't I use my Claude Pro / ChatGPT Plus subscription?

A: Subscriptions are for using Claude/ChatGPT directly through their
   websites. Apps like EmberHearth need API access, which is a separate
   service with pay-as-you-go pricing.

   This is required by Anthropic's and OpenAI's terms of service.


Q: Do I need to pay Anthropic AND EmberHearth?

A: EmberHearth is free. You only pay Anthropic (or OpenAI) directly
   for the AI usage. EmberHearth helps you track and limit spending.


Q: How do I know how much I'm spending?

A: Check the menu bar icon for a quick view, or go to Settings → Usage
   for detailed breakdowns. Your actual bill comes from Anthropic/OpenAI.


Q: Can I use both Claude and OpenAI?

A: Currently, EmberHearth uses one provider at a time. You can switch
   providers in Settings → AI Provider, but you can't use both
   simultaneously.


Q: What if I want to stop using API and switch to local?

A: Go to Settings → AI Provider → Change Provider → Local Model.
   Local models are less capable but free and private.
```

---

## Implementation Checklist

### MVP (Onboarding)

- [ ] "API key is different from subscription" explanation screen
- [ ] "What's an API key?" expandable section
- [ ] Provider-specific format validation
- [ ] Step-by-step guides for Claude and OpenAI
- [ ] Cost expectations before API key entry
- [ ] Budget setup integrated into onboarding

### v1.1

- [ ] Smart error detection (subscription vs API key confusion)
- [ ] First-week cost check-in via Ember
- [ ] In-app FAQ for billing questions
- [ ] "Why isn't this working?" diagnostic flow

### v1.2+

- [ ] Guided walkthrough with screenshots
- [ ] Direct link to billing pages with pre-filled context
- [ ] Support for additional providers (Google, etc.)

---

## References

- [Anthropic API Documentation](https://docs.anthropic.com/)
- [OpenAI Platform Documentation](https://platform.openai.com/docs)
- `specs/token-awareness.md` — Usage tracking and budget enforcement
- `research/onboarding-ux.md` — Full onboarding flow

---

*Specification complete. February 5, 2026.*
