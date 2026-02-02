# Onboarding UX Research

**Status:** Complete
**Last Updated:** February 2, 2026
**Related:** [VISION.md](../VISION.md), [security.md](./security.md), [imessage.md](./imessage.md), [conversation-design.md](./conversation-design.md)

---

## Overview

This document defines the first-time user experience for EmberHearth, with special attention to non-technical users. The goal is getting users to a helpful first interaction as quickly as possible, while requesting permissions only when needed and explaining security in approachable terms.

**Design North Star:** A user's grandparent should be able to set up EmberHearth with minimal friction and understand why each permission is needed.

**Core Tension:** EmberHearth requires significant system access (Full Disk Access, Automation, Contacts, Calendar) to function. Requesting these upfront feels invasive; deferring them creates friction during use. The solution is progressive disclosure with clear, honest explanations.

---

## 1. Permission Requirements

### What EmberHearth Needs and Why

| Permission | When Needed | Why | User Impact if Denied |
|------------|-------------|-----|----------------------|
| **Full Disk Access** | Core (messaging) | Read iMessage database | Cannot receive messages |
| **Automation (Messages.app)** | Core (messaging) | Send iMessages | Cannot send messages |
| **Notifications** | Core (reminders) | Alert user when needed | No proactive reminders |
| **Contacts** | First contact reference | Look up "Mom" → phone number | Must use phone numbers only |
| **Calendar** | First calendar request | Read/create events | No calendar features |
| **Reminders** | First reminder request | Create reminders | No reminder features |
| **Location** | Location-based features | "Near home" triggers | No location awareness |

### Permission Categories

```
┌─────────────────────────────────────────────────────────────────┐
│  PERMISSION PRIORITY                                            │
│                                                                 │
│  TIER 1: REQUIRED FOR CORE FUNCTION                             │
│  ────────────────────────────────────────────────────────────── │
│  • Full Disk Access — Without this, Ember can't receive messages│
│  • Automation (Messages.app) — Without this, Ember can't reply  │
│  • Notifications — Without this, no proactive communication     │
│                                                                 │
│  TIER 2: REQUESTED WHEN FIRST NEEDED                            │
│  ────────────────────────────────────────────────────────────── │
│  • Contacts — First time user says "text Mom"                   │
│  • Calendar — First time user mentions a date/event             │
│  • Reminders — First time user says "remind me"                 │
│                                                                 │
│  TIER 3: OPTIONAL ENHANCEMENTS                                  │
│  ────────────────────────────────────────────────────────────── │
│  • Location — Only if user wants location-based triggers        │
│  • HomeKit — Only if user wants smart home control              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. The Onboarding Flow

### Philosophy: Progressive Disclosure

Following Apple's Human Interface Guidelines: "Give people time to start enjoying your app before showing supplementary information, asking for a review, or making permission requests."

However, EmberHearth's core function requires two permissions upfront: Full Disk Access (to receive messages) and Automation (to send them). Without these, there's no value to deliver.

**Solution:** Explain clearly, request honestly, then immediately deliver value.

### Flow Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  ONBOARDING FLOW (5-7 minutes total)                            │
│                                                                 │
│  1. WELCOME (30 seconds)                                        │
│     • Warm greeting                                             │
│     • One-sentence value prop                                   │
│     • Set expectations: "A few steps to get started"            │
│                                                                 │
│  2. LLM PROVIDER SETUP (2-3 minutes)                            │
│     • Choose provider (Claude, OpenAI, Local, or Skip)          │
│     • Enter API key (with help link)                            │
│     • Test connection                                           │
│                                                                 │
│  3. CORE PERMISSIONS (2-3 minutes)                              │
│     • Explain security model (one screen, plain language)       │
│     • Request Full Disk Access (with walkthrough)               │
│     • Request Automation (automatic prompt)                     │
│     • Request Notifications                                     │
│                                                                 │
│  4. FIRST MESSAGE (30 seconds)                                  │
│     • Show iMessage number to text                              │
│     • User sends first message                                  │
│     • Ember responds                                            │
│     • Success!                                                  │
│                                                                 │
│  5. ADDITIONAL PERMISSIONS (as needed, later)                   │
│     • Contacts: First time user references a contact by name    │
│     • Calendar: First time user mentions an event               │
│     • Reminders: First time user asks for a reminder            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Step 1: Welcome Screen

### Design

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                          🔥                                     │
│                                                                 │
│                    Welcome to Ember                             │
│                                                                 │
│     A personal assistant that lives in your Messages app.       │
│     Text her like you'd text a friend.                          │
│                                                                 │
│     Setup takes about 5 minutes. You'll need:                   │
│     • An API key from an AI provider (or use local models)      │
│     • To grant a few permissions so Ember can help you          │
│                                                                 │
│                                                                 │
│                    [ Let's Get Started ]                        │
│                                                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Copy Principles

- **Warm, not corporate:** "Text her like you'd text a friend"
- **Set expectations:** Time estimate, what's needed
- **No false promises:** Honest about requiring setup
- **Accessible language:** No jargon

---

## 4. Step 2: LLM Provider Setup

### The Challenge

Non-technical users may not know what an "API key" is or how to get one. Technical users want quick configuration without hand-holding.

**Solution:** Tier the explanation based on user signal.

### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Choose Your AI Provider                      │
│                                                                 │
│     Ember uses AI to understand you and respond helpfully.      │
│     Choose how you'd like to power her:                         │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐     │
│     │  ☁️  Claude by Anthropic              [Recommended]  │     │
│     │      Best for thoughtful, nuanced conversation       │     │
│     │      Requires API key ($5-20/month typical)          │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐     │
│     │  ☁️  OpenAI (GPT-4)                                  │     │
│     │      Popular, widely used                            │     │
│     │      Requires API key ($5-20/month typical)          │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐     │
│     │  💻  Local Model (Privacy-First)                     │     │
│     │      Runs entirely on your Mac, no data leaves       │     │
│     │      Requires M1/M2/M3/M4 Mac with 16GB+ RAM         │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐     │
│     │  ⏭️  Skip for Now                                    │     │
│     │      Set this up later in Settings                   │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### API Key Entry (for Claude/OpenAI)

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Enter Your Claude API Key                    │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐     │
│     │  sk-ant-api03-••••••••••••••••••••••••••••••••••    │     │
│     └─────────────────────────────────────────────────────┘     │
│     [ 👁 Show ]                                                  │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐     │
│     │  ℹ️  What's an API key?                              │     │
│     │                                                      │     │
│     │  An API key is like a password that lets Ember       │     │
│     │  talk to Claude's AI. It's tied to your account      │     │
│     │  and you pay based on how much you use it.           │     │
│     │                                                      │     │
│     │  [ Get an API key from Anthropic → ]                 │     │
│     │                                                      │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                 │
│     🔒 Your API key is stored securely in your Mac's Keychain   │
│        and never sent anywhere except to Claude.                │
│                                                                 │
│                                                                 │
│              [ Test Connection ]    [ Continue ]                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### For Users Without an API Key

If user selects a cloud provider but doesn't have a key:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Get a Claude API Key                         │
│                                                                 │
│     1. Go to console.anthropic.com                              │
│        [ Open in Browser → ]                                    │
│                                                                 │
│     2. Create an account (or sign in)                           │
│                                                                 │
│     3. Go to API Keys and create a new key                      │
│                                                                 │
│     4. Copy the key and paste it here                           │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐     │
│     │                                                      │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                 │
│     💡 API keys typically cost $0.01-0.03 per message.          │
│        Most people spend $5-20/month.                           │
│                                                                 │
│                                                                 │
│                    [ I'll Do This Later ]                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Local Model Setup

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Local Model Setup                            │
│                                                                 │
│     Ember will run AI entirely on your Mac.                     │
│     Nothing you say leaves your computer.                       │
│                                                                 │
│     Your Mac: MacBook Pro M3 Pro, 18GB RAM ✓                    │
│                                                                 │
│     Recommended model:                                          │
│     ┌─────────────────────────────────────────────────────┐     │
│     │  Mistral 7B (4.5GB download)                         │     │
│     │  Good balance of speed and quality                   │     │
│     │  [ Download and Install ]                            │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                 │
│     Other options:                                              │
│     • Llama 3 8B — Better quality, slower                       │
│     • Phi-2 — Faster, less capable                              │
│     • I already have Ollama installed →                         │
│                                                                 │
│                                                                 │
│     ⚠️  Local models are less capable than cloud options.       │
│        Ember will work, but may misunderstand complex requests. │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Step 3: Core Permissions

### The Security Explanation Screen

Before requesting permissions, explain why—without overwhelming.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    How Ember Protects You                       │
│                                                                 │
│     Ember needs access to your Mac to be helpful.               │
│     Here's how we keep your data safe:                          │
│                                                                 │
│     🔒 Everything stays on your Mac                             │
│        Your messages, memories, and personal info never         │
│        leave your computer (except to talk to the AI).          │
│                                                                 │
│     🔑 Secrets are encrypted                                    │
│        Sensitive data is protected with your Mac's              │
│        Secure Enclave—the same tech that protects Face ID.      │
│                                                                 │
│     👁 You're always in control                                 │
│        See what Ember knows, correct mistakes, or ask her       │
│        to forget anything. Just message her.                    │
│                                                                 │
│     📋 No hidden access                                         │
│        Ember only accesses what she needs, when she needs it.   │
│        We'll explain each permission before asking.             │
│                                                                 │
│                                                                 │
│                        [ Continue ]                             │
│                                                                 │
│                   [ Read Full Security Details ]                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Permission 1: Full Disk Access

This is the most invasive-sounding permission. Explain carefully.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Permission: Read Your Messages               │
│                                                                 │
│     To receive your messages, Ember needs to read your          │
│     iMessage history. On macOS, this requires "Full Disk        │
│     Access."                                                    │
│                                                                 │
│     ⚠️  This sounds scary, but here's what it actually means:   │
│                                                                 │
│     ✓  Ember can read your iMessage database                    │
│     ✓  Ember can see attachments you've received                │
│                                                                 │
│     ✗  Ember does NOT access other files on your Mac            │
│     ✗  Ember does NOT read your emails, documents, or photos    │
│     ✗  Ember does NOT send your messages anywhere               │
│                                                                 │
│     We need "Full Disk Access" because Apple doesn't provide    │
│     a narrower permission for Messages only.                    │
│                                                                 │
│                                                                 │
│                    [ Grant Permission ]                         │
│                                                                 │
│             [ Why can't you just read Messages? ]               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

After clicking "Grant Permission":

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Open System Settings                         │
│                                                                 │
│     macOS requires you to enable this in System Settings.       │
│     We've opened the right page for you.                        │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐     │
│     │  📋 Instructions:                                    │     │
│     │                                                      │     │
│     │  1. Find "EmberHearth" in the list                   │     │
│     │  2. Click the toggle to turn it ON                   │     │
│     │  3. Enter your password if asked                     │     │
│     │  4. Come back to this window                         │     │
│     │                                                      │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                 │
│     [ Show Me Where ↗ ]                                         │
│                                                                 │
│                                                                 │
│     Status: Waiting for permission...                           │
│                                                                 │
│                    [ Check Again ]                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Permission 2: Automation (Messages.app)

This one triggers automatically when Ember first tries to send.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Permission: Send Messages                    │
│                                                                 │
│     To reply to you, Ember needs permission to control          │
│     the Messages app.                                           │
│                                                                 │
│     When you click Continue, macOS will ask:                    │
│     "EmberHearth wants to control Messages"                     │
│                                                                 │
│     Click "OK" to allow Ember to send messages on your behalf.  │
│                                                                 │
│                                                                 │
│                        [ Continue ]                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Permission 3: Notifications

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Permission: Notifications                    │
│                                                                 │
│     Ember can remind you about things, surface relevant         │
│     information, and alert you when something needs attention.  │
│                                                                 │
│     Would you like Ember to send you notifications?             │
│                                                                 │
│     [ Yes, Notify Me ]        [ No Thanks ]                     │
│                                                                 │
│     You can change this later in Settings.                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Step 4: First Message Success

### The Moment of Value

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    🎉 You're All Set!                           │
│                                                                 │
│     Ember is ready. Text her to get started.                    │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐     │
│     │                                                      │     │
│     │     Open Messages and text:                          │     │
│     │                                                      │     │
│     │         ember@icloud.com                             │     │
│     │                                                      │     │
│     │     [ Copy Address ]                                 │     │
│     │                                                      │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                 │
│     Try saying:                                                 │
│     • "Hi Ember!"                                               │
│     • "What can you help me with?"                              │
│     • "Remind me to call Mom tomorrow at 10am"                  │
│                                                                 │
│                                                                 │
│               [ Open Messages ]    [ Close ]                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Deferred Permission Requests

### Just-in-Time Pattern

When the user first triggers a feature that needs additional permissions, Ember explains and requests in context.

### Example: Contacts Permission

```
User: "Text Mom that I'll be late for dinner"

Ember: "I'd love to text your mom, but I don't have access to
       your contacts yet. Would you like to grant that permission
       so I can look up 'Mom' for you?

       [ Yes, Open Settings ]   [ Use Phone Number Instead ]"
```

If user grants permission:

```
Ember: "Thanks! I found Patricia (Mom) in your contacts.
       I'll text her: 'I'll be late for dinner.'

       Send it? [ Yes ] [ Edit First ]"
```

### Example: Calendar Permission

```
User: "What do I have tomorrow?"

Ember: "I'd need access to your calendar to see your schedule.
       Want to grant that permission?

       [ Yes, Open Settings ]   [ Not Now ]"
```

### Implementation

```swift
struct PermissionRequest {
    let permission: Permission
    let triggerContext: String  // What the user was trying to do
    let explanation: String     // Why we need it
    let benefit: String         // What they'll get

    func conversationalPrompt() -> String {
        """
        I'd love to \(triggerContext), but I need access to your
        \(permission.friendlyName) first.

        \(explanation)

        \(benefit)
        """
    }
}

enum Permission {
    case contacts
    case calendar
    case reminders
    case location

    var friendlyName: String {
        switch self {
        case .contacts: return "contacts"
        case .calendar: return "calendar"
        case .reminders: return "reminders"
        case .location: return "location"
        }
    }
}
```

---

## 8. Explaining Security Without Overwhelming

### The Layered Approach

**Layer 1: One-sentence reassurance** (always visible)
> "Your data stays on your Mac and is encrypted."

**Layer 2: Four-point summary** (shown during onboarding)
> 1. Everything stays on your Mac
> 2. Secrets are encrypted
> 3. You're always in control
> 4. No hidden access

**Layer 3: Full explanation** (available on request)
> Links to detailed security documentation, architecture diagrams,
> and technical specifics for those who want them.

### Language Guidelines

| Technical Term | Plain Language |
|----------------|----------------|
| "Encrypted with AES-256" | "Protected by the same security that protects your banking apps" |
| "Stored in Keychain" | "Kept in your Mac's secure password vault" |
| "Secure Enclave" | "The same chip that protects Face ID" |
| "Local-only storage" | "Stays on your Mac, never uploaded" |
| "API key" | "A password that lets Ember talk to the AI" |
| "Sandboxed" | "Can only access what it needs" |

### What NOT to Say

- "Enterprise-grade security" — Meaningless jargon
- "Military-grade encryption" — Overused, sounds like marketing
- "We take security seriously" — Everyone says this
- "Your data is safe with us" — Vague, doesn't explain how

### What TO Say

- "Your messages never leave your Mac"
- "Here's exactly what Ember can and can't access"
- "You can see everything Ember knows about you"
- "Ask Ember to forget anything, anytime"

---

## 9. Minimum Setup Before First Value

### The Critical Path

The absolute minimum to deliver first value:

```
┌─────────────────────────────────────────────────────────────────┐
│  MINIMUM VIABLE ONBOARDING                                      │
│                                                                 │
│  1. LLM Provider: At least one working (cloud or local)         │
│  2. Full Disk Access: Required to receive messages              │
│  3. Automation: Required to send messages                       │
│                                                                 │
│  That's it. Everything else can come later.                     │
│                                                                 │
│  Without LLM: Can't respond intelligently                       │
│  Without Full Disk: Can't receive messages                      │
│  Without Automation: Can't send messages                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Time to First Value

**Target: Under 5 minutes**

| Step | Target Time | Notes |
|------|-------------|-------|
| Welcome screen | 30 seconds | One button click |
| LLM setup (has key) | 1 minute | Paste key, test |
| LLM setup (needs key) | 3-5 minutes | Create account, get key |
| Security explanation | 30 seconds | Read, click continue |
| Full Disk Access | 1 minute | Open settings, toggle |
| Automation | 10 seconds | Click OK on prompt |
| First message | 30 seconds | Send "Hi Ember!" |

**If user has API key ready:** ~3 minutes
**If user needs to get API key:** ~7 minutes
**If user chooses local model:** ~5 minutes + download time

---

## 10. Handling Edge Cases

### User Denies a Required Permission

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Ember Needs This Permission                  │
│                                                                 │
│     Without Full Disk Access, Ember can't read your messages    │
│     and won't be able to respond when you text her.             │
│                                                                 │
│     [ Try Again ]                                               │
│                                                                 │
│     [ Continue Without Messages ]                               │
│     (Ember will only work through the Mac app)                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### User Skips LLM Setup

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Limited Mode                                 │
│                                                                 │
│     Ember needs an AI provider to understand you and respond    │
│     helpfully. Without one, she'll only be able to:             │
│                                                                 │
│     • Set simple timers and reminders                           │
│     • Send pre-formatted messages you dictate                   │
│     • Forward you to Settings when you need help                │
│                                                                 │
│     You can set up an AI provider anytime in Settings.          │
│                                                                 │
│     [ Continue in Limited Mode ]   [ Set Up AI Now ]            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Mac Doesn't Meet Local Model Requirements

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Local Models Unavailable                     │
│                                                                 │
│     Your Mac (Intel, 8GB RAM) doesn't have enough power to      │
│     run AI locally. Local models need:                          │
│                                                                 │
│     • Apple Silicon (M1/M2/M3/M4)                               │
│     • At least 16GB RAM                                         │
│                                                                 │
│     You can still use Ember with a cloud provider like Claude   │
│     or OpenAI.                                                  │
│                                                                 │
│     [ Use Cloud Provider ]   [ Learn More ]                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Permission Was Previously Denied

If user denied a permission in a previous session:

```
Ember: "I tried to access your calendar but macOS says I don't
       have permission. You may have denied it before.

       To fix this:
       1. Open System Settings → Privacy & Security → Calendars
       2. Find EmberHearth and turn it ON

       [ Open Settings ]"
```

---

## 11. Post-Onboarding Guidance

### The First Conversation

Ember's first response should reinforce the relationship:

```
User: "Hi Ember!"

Ember: "Hi! I'm so glad you set me up. I'm Ember, and I'm here
       to help with whatever you need—reminders, messages,
       calendar, or just someone to think through things with.

       What can I help you with today?"
```

### Gentle Feature Discovery

Over the first week, Ember can surface capabilities naturally:

```
Day 1: (After setting a reminder)
Ember: "Reminder set! By the way, if you ever want to see what
       I know about you or your schedule, just ask. I'm an
       open book."

Day 3: (After mentioning a person by name)
Ember: "I noticed you mentioned Sarah a few times. Want me to
       remember who she is? That way I can help with context
       in the future."

Day 7: (After using for a week)
Ember: "We've been chatting for a week now! If you ever want
       to adjust how proactive I am, or see what I've learned
       about your preferences, just ask."
```

### What NOT to Do

- Don't show a feature tour on first launch
- Don't overwhelm with tips and suggestions
- Don't send notifications about features during onboarding
- Don't ask for a review or rating
- Don't promote premium features (there aren't any)

---

## 12. Accessibility Considerations

### VoiceOver Support

All onboarding screens must work with VoiceOver:

- Clear heading hierarchy
- Descriptive button labels ("Grant Full Disk Access" not just "Continue")
- Status announcements ("Permission granted successfully")
- Focus management between steps

### Dynamic Type

All text must scale with system font size settings:

- Minimum touch targets of 44x44 points
- Layouts must reflow, not truncate
- Critical information visible at largest text sizes

### Keyboard Navigation

Full keyboard support:

- Tab through all interactive elements
- Clear focus indicators
- Enter/Space to activate buttons
- Escape to go back

### Reduced Motion

For users with motion sensitivity:

- No animated transitions (or provide alternatives)
- No auto-advancing screens
- Static progress indicators

---

## 13. Implementation Notes

### State Machine

```swift
enum OnboardingState {
    case welcome
    case llmProviderSelection
    case llmApiKeyEntry(provider: LLMProvider)
    case llmLocalSetup
    case llmSkipped
    case securityExplanation
    case fullDiskAccessRequest
    case fullDiskAccessPending
    case automationRequest
    case notificationRequest
    case complete
    case error(OnboardingError)
}

struct OnboardingFlow {
    var state: OnboardingState = .welcome
    var llmConfigured: Bool = false
    var fullDiskAccessGranted: Bool = false
    var automationGranted: Bool = false
    var notificationsEnabled: Bool = false

    var canProceedToCompletion: Bool {
        llmConfigured && fullDiskAccessGranted && automationGranted
    }

    var minimumViableComplete: Bool {
        // Can at least receive and send messages
        fullDiskAccessGranted && automationGranted
    }
}
```

### Permission Checking

```swift
class PermissionChecker {
    func checkFullDiskAccess() -> Bool {
        let testPath = NSHomeDirectory() + "/Library/Messages/chat.db"
        return FileManager.default.isReadableFile(atPath: testPath)
    }

    func checkAutomation() -> Bool {
        // Attempt a harmless AppleScript to check
        let script = "tell application \"Messages\" to get name"
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        return error == nil
    }

    func checkNotifications() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}
```

### Persistence

```swift
struct OnboardingPersistence {
    @AppStorage("onboarding_completed") var completed: Bool = false
    @AppStorage("onboarding_skipped_llm") var skippedLLM: Bool = false
    @AppStorage("onboarding_version") var version: Int = 0

    // If we add new onboarding steps in future versions,
    // we can check version and show just the new parts
    let currentVersion = 1

    var needsOnboarding: Bool {
        !completed || version < currentVersion
    }
}
```

---

## 14. Metrics and Success Criteria

### What to Measure

| Metric | Target | Why |
|--------|--------|-----|
| Onboarding completion rate | >80% | Are people finishing setup? |
| Time to first message | <5 minutes | Is setup fast enough? |
| Permission grant rate | >90% | Are explanations working? |
| Day-1 retention | >70% | Do people come back? |
| Permission denial recovery | >50% | Do explanations convince people? |

### Drop-off Points to Monitor

1. LLM provider selection (overwhelmed by choice?)
2. API key entry (too technical?)
3. Full Disk Access request (too scary?)
4. After first message (did it work?)

---

## 15. Summary

| Aspect | Approach |
|--------|----------|
| **Philosophy** | Progressive disclosure, explain then request |
| **Minimum setup** | LLM provider + Full Disk + Automation |
| **Time to value** | Target <5 minutes with API key ready |
| **Security explanation** | Layered: one-liner → four points → full docs |
| **Permission timing** | Core upfront, others when first needed |
| **Language** | Plain, honest, no jargon |
| **Edge cases** | Graceful degradation, clear recovery paths |
| **Accessibility** | VoiceOver, Dynamic Type, Keyboard, Reduced Motion |

### The One-Sentence Summary

**Get users to their first successful message as quickly as possible, requesting only essential permissions upfront and explaining everything in language their grandparents would understand.**

---

## References

- [Apple Human Interface Guidelines: Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)
- [Apple Human Interface Guidelines: Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)
- [Nielsen Norman Group: Permission Requests](https://www.nngroup.com/articles/permission-requests/)
- [TidBITS: macOS Sequoia Permission Prompts](https://tidbits.com/2024/08/12/macos-15-sequoias-excessive-permissions-prompts-will-hurt-security/)
- [UX Design Institute: Onboarding Best Practices](https://www.uxdesigninstitute.com/blog/ux-onboarding-best-practices-guide/)
- [UserGuiding: How Top AI Tools Onboard Users](https://userguiding.com/blog/how-top-ai-tools-onboard-new-users)
- [security.md](./security.md) — EmberHearth security architecture
- [imessage.md](./imessage.md) — iMessage integration requirements
