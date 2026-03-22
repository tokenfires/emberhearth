# Task 0906: Final Documentation Pass

**Milestone:** M10 - Final Integration
**Unit:** 10.7 - User-Facing Documentation and Developer Guide
**Phase:** Final
**Depends On:** 0903 (Final Code Review and Cleanup)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions, security boundaries, core principles (accessibility, privacy, Apple quality), project structure
2. `README.md` — Read entirely; this will be rewritten from developer-focused to user-facing
3. `docs/VISION.md` — Read the first section ("Executive Summary" through "The Dream Setup") for product philosophy and description
4. `docs/releases/mvp-scope.md` — Read the "MVP Success Criteria" section (lines ~16-27) and "Feature Matrix" tables for what's included in v1.0; read the "MVP Architecture" diagram (lines ~163-199) for system overview
5. `docs/research/onboarding-ux.md` — Read Section 2 ("The Onboarding Flow") for the setup flow to document in the user guide, and Section 5 ("Core Permissions") for permission explanations
6. `docs/deployment/build-and-release.md` — Read "Prerequisites" (lines ~43-58) and "Development Environment" for the contributing guide

> **Context Budget Note:** `docs/VISION.md` is ~700+ lines. Only read through "The Dream Setup" section (first ~35 lines). `docs/releases/mvp-scope.md` is ~200 lines, readable in full but focus on the feature matrix and system requirements. `docs/research/onboarding-ux.md` is ~920 lines — focus only on Sections 2 and 5 as noted. `docs/deployment/build-and-release.md` is ~525 lines — focus only on lines 43-58 ("Prerequisites" and "Development Environment").

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are performing the final documentation pass for EmberHearth, a native macOS personal AI assistant that uses iMessage as its primary interface. This is the very last task in the MVP build sequence (task 1.33 from MVP.md). Your job is to transform documentation from developer-focused to user-facing and create missing documentation files.

## Important Rules (from CLAUDE.md)

- Product display name: "EmberHearth" (camelCase "emberhearth" for code/paths only)
- Doc files use lowercase-with-hyphens naming (e.g., `USER-GUIDE.md`)
- Swift files use PascalCase (e.g., `MessageCoordinator.swift`)
- Accessibility is a CORE PRINCIPLE — mention it in all user-facing documentation
- Privacy is a CORE PRINCIPLE — all data stays local, no cloud sync, emphasize everywhere
- Security first: No shell execution in the app, Keychain for secrets, sandboxed web access
- macOS 13.0+ (Ventura) minimum system requirement
- The app is distributed outside the Mac App Store (direct download, Developer ID signed, notarized)

## What You Are Doing

Creating or rewriting four documentation files:
1. **Rewrite `README.md`** — Transform from developer documentation index to user-facing project page
2. **Create `docs/USER-GUIDE.md`** — Comprehensive user guide for non-technical users
3. **Create `CONTRIBUTING.md`** — Developer contributing guide
4. **Create `docs/CHANGELOG.md`** — Initial changelog for v1.0.0 release

## CRITICAL: README.md Creator Message

The current README.md has a "Creator message" section at the very top (before the `---` separator) with a note saying to leave it alone. **You MUST preserve this entire section exactly as-is at the top of the file.** Do NOT edit, remove, or reformat anything in the Creator message section. Place all your changes BELOW it, after the `---` separator.

## File 1: Rewrite README.md

**Path:** `README.md` (root of repo)

Keep the entire existing "Creator message" section at the top unchanged. Replace everything from the `---` separator onward with a user-facing project page.

The new README.md content (below the preserved Creator message section) should be:

```markdown
---

<p align="center">
  <img src="images/profile.png" alt="EmberHearth" width="200">
</p>

<h1 align="center">EmberHearth</h1>

<p align="center">
  <strong>Your personal AI assistant that lives in iMessage.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013.0%2B-blue" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
  <img src="https://img.shields.io/badge/interface-iMessage-brightgreen" alt="iMessage">
</p>

---

## What is EmberHearth?

EmberHearth is a secure, accessible, always-on personal AI assistant for macOS. It lives in iMessage — just text it like you would a friend, and it responds with the help of Claude AI. It remembers your preferences, learns about you over time, and keeps all your data private on your own Mac.

No cloud sync. No data collection. No complicated setup. Just a helpful assistant that's always there.

### Key Features

- **Conversational AI** — Natural conversations powered by Claude, right in iMessage
- **Memory & Learning** — Ember remembers what you tell it and uses that knowledge in future conversations
- **Privacy-First** — All your data stays on your Mac. No cloud sync, no telemetry, no data collection
- **Always-On** — Runs quietly in your menu bar, ready whenever you need it
- **Accessible** — Full VoiceOver support, Dynamic Type, and keyboard navigation throughout
- **Secure** — Encrypted local storage, Keychain for credentials, sandboxed web access, no shell execution

---

## System Requirements

| Requirement | Details |
|-------------|---------|
| **Operating System** | macOS 13.0 (Ventura) or later |
| **Processor** | Apple Silicon or Intel |
| **iMessage** | Configured and signed in with an Apple ID |
| **API Key** | Claude API key from [Anthropic](https://console.anthropic.com/) |
| **Permissions** | Full Disk Access, Automation, Notifications |

---

## Quick Start

1. **Download** — Get the latest release from the [Releases](https://github.com/robault/emberhearth/releases) page
2. **Grant Permissions** — Follow the onboarding wizard to grant Full Disk Access and Automation permissions
3. **Enter API Key** — Add your Claude API key (Ember walks you through this)
4. **Configure Phone Number** — Set the phone number Ember should respond to

That's it. Send yourself a text in iMessage and Ember will respond.

---

## Privacy & Security

EmberHearth is built with privacy and security as foundational principles, not afterthoughts.

| Principle | How |
|-----------|-----|
| **Local-only data** | All memories, conversations, and preferences stay on your Mac |
| **No cloud sync** | Nothing leaves your machine except API calls to your chosen LLM provider |
| **Encrypted storage** | Memory database uses SQLite with encryption |
| **Keychain credentials** | API keys stored exclusively in the macOS Keychain |
| **No shell execution** | The app never executes shell commands — ever |
| **Sandboxed web access** | Web content fetching is isolated and restricted |
| **Input screening** | All messages screened for prompt injection before processing |
| **Output screening** | All AI responses screened for credential leaks before sending |
| **Hardened Runtime** | App signed with Hardened Runtime and notarized by Apple |

Your data is yours. Period.

---

## Accessibility

EmberHearth is designed to be usable by everyone:

- **iMessage as primary interface** — Inherits Apple's full accessibility stack (VoiceOver, Switch Control, Voice Control)
- **VoiceOver support** — Every UI element in the settings app is labeled for screen readers
- **Dynamic Type** — All text respects system font size settings
- **Keyboard navigation** — Full keyboard access throughout the settings app
- **The Grandmother Test** — If it requires explanation to non-technical users, it's not ready

---

## Building from Source

If you'd like to build EmberHearth yourself, see the [Contributing Guide](CONTRIBUTING.md) for detailed instructions.

Quick version:

```bash
git clone https://github.com/robault/emberhearth.git
cd emberhearth
./build.sh build
./build.sh test
```

---

## Documentation

### For Users
| Document | Description |
|----------|-------------|
| [User Guide](docs/USER-GUIDE.md) | Complete guide to setting up and using EmberHearth |
| [Changelog](docs/CHANGELOG.md) | Release history and changes |

### For Developers
| Document | Description |
|----------|-------------|
| [Contributing](CONTRIBUTING.md) | How to contribute to EmberHearth |
| [Vision](docs/VISION.md) | Product vision, architecture, and design philosophy |
| [Architecture Overview](docs/architecture-overview.md) | System design and component relationships |
| [ADR Index](docs/architecture/decisions/README.md) | Architectural Decision Records |
| [Build & Release](docs/deployment/build-and-release.md) | Build, signing, and release process |
| [Testing Strategy](docs/testing/strategy.md) | Testing approach and coverage targets |
| [MVP Scope](docs/releases/mvp-scope.md) | Feature requirements by release version |

### Research
| Document | Description |
|----------|-------------|
| [Research Index](docs/research/README.md) | Index of all research documents |

---

## Building in Public

Development of EmberHearth is streamed live on Twitch. Follow along as we explore, prototype, make mistakes, and (hopefully) build something useful.

[![Watch on Twitch](images/watch_on_twitch.png)](https://www.twitch.tv/tokenfires "Watch live on Twitch")

Streams are archived on [YouTube](https://www.youtube.com/@tokenfires).

---

## License

MIT License — See [LICENSE](LICENSE)
```

## File 2: Create docs/USER-GUIDE.md

**Path:** `docs/USER-GUIDE.md`

This guide is written for non-technical users. Use plain language. Avoid jargon. When technical terms are unavoidable, explain them in parentheses. Think of this as the guide you'd hand to a family member.

```markdown
# EmberHearth User Guide

> Everything you need to know about setting up and using EmberHearth.

---

## Table of Contents

1. [What is EmberHearth?](#what-is-emberhearth)
2. [Getting Started](#getting-started)
3. [Setup Walkthrough](#setup-walkthrough)
4. [API Key Setup](#api-key-setup)
5. [Phone Number Configuration](#phone-number-configuration)
6. [Using EmberHearth](#using-emberhearth)
7. [Memory & Learning](#memory--learning)
8. [Privacy & Your Data](#privacy--your-data)
9. [Troubleshooting](#troubleshooting)
10. [Frequently Asked Questions](#frequently-asked-questions)

---

## What is EmberHearth?

EmberHearth is a personal AI assistant that lives in iMessage on your Mac. You text it just like you would a friend, and it responds using AI (specifically, Anthropic's Claude). Over time, it learns your preferences and remembers things you tell it.

**What makes it different:**
- It runs entirely on your Mac — your data never leaves your computer
- You interact with it through iMessage, which you already know how to use
- It remembers things about you across conversations
- It's designed to be safe and accessible for everyone, not just tech-savvy users

**What Ember can do:**
- Answer questions and have conversations
- Remember things you tell it ("Remember that I prefer window seats")
- Recall those memories in future conversations
- Fetch and summarize web pages when you share a link
- Adapt its communication style to match your preferences

**What Ember does NOT do:**
- Access your email, calendar, or contacts (those features are planned for future versions)
- Send messages to anyone other than you
- Share your data with anyone
- Execute commands on your computer

---

## Getting Started

### What You Need

Before installing EmberHearth, make sure you have:

1. **A Mac running macOS 13.0 (Ventura) or later**
   - To check your version: Click the Apple menu () in the top-left corner, then "About This Mac"
   - Both Apple Silicon (M1, M2, M3, M4) and Intel Macs are supported

2. **iMessage set up and working**
   - Open the Messages app on your Mac
   - Make sure you can send and receive iMessages (blue bubbles, not green)
   - You need to be signed in with your Apple ID

3. **A Claude API key from Anthropic**
   - This is how Ember talks to the AI. See [API Key Setup](#api-key-setup) below for how to get one
   - The API key costs money based on usage (typically a few dollars per month for personal use)

### Downloading EmberHearth

1. Visit the [Releases page](https://github.com/robault/emberhearth/releases) on GitHub
2. Download the latest `.dmg` file
3. Open the downloaded file
4. Drag EmberHearth to your Applications folder
5. Open EmberHearth from your Applications folder
   - If macOS says the app is from an unidentified developer, right-click the app and choose "Open" instead of double-clicking

### First Launch

When you open EmberHearth for the first time, you'll see the onboarding wizard. This walks you through everything you need to set up. It should take about 5 minutes.

---

## Setup Walkthrough

The onboarding wizard guides you through three types of setup:

### 1. Granting Permissions

EmberHearth needs a few macOS permissions to work. Here's what each one does and why it's needed:

#### Full Disk Access (Required)

**What it does:** Allows EmberHearth to read your iMessage history.

**Why it's needed:** Your iMessages are stored in a database file on your Mac. EmberHearth needs to read this file to see when you've sent it a message. Without this permission, Ember can't see your messages at all.

**How to grant it:**
1. EmberHearth will show you a button that opens System Settings
2. Go to **Privacy & Security > Full Disk Access**
3. Find EmberHearth in the list and toggle it ON
4. You may need to enter your Mac password
5. Return to EmberHearth and click "Check Again"

**What it does NOT do:** EmberHearth only reads messages sent to it. It does not read, store, or transmit your conversations with other people.

#### Automation (Required)

**What it does:** Allows EmberHearth to send iMessages through the Messages app.

**Why it's needed:** When Ember wants to respond to you, it needs to tell the Messages app to send a message. This permission allows that communication between apps.

**How to grant it:**
1. EmberHearth will show you a button that opens System Settings
2. Go to **Privacy & Security > Automation**
3. Find EmberHearth in the list
4. Toggle ON the permission for "Messages"
5. Return to EmberHearth and click "Check Again"

#### Notifications (Optional but Recommended)

**What it does:** Allows EmberHearth to show you status notifications.

**Why it's needed:** EmberHearth uses notifications to tell you about important events, like when it starts up, when there's an API error, or when it's having trouble connecting. Without this, you won't see these alerts.

**How to grant it:**
1. When macOS asks if EmberHearth can send notifications, click "Allow"
2. Or go to **System Settings > Notifications > EmberHearth** and toggle it ON

### 2. API Key Setup

See the [API Key Setup](#api-key-setup) section below for detailed instructions.

### 3. Phone Number Configuration

See the [Phone Number Configuration](#phone-number-configuration) section below for details.

---

## API Key Setup

EmberHearth uses Claude (made by Anthropic) as its AI brain. To use Claude, you need an API key — think of it as a password that lets EmberHearth talk to Claude on your behalf.

### Getting a Claude API Key

1. Go to [console.anthropic.com](https://console.anthropic.com/)
2. Create an account (or sign in if you already have one)
3. Navigate to **API Keys** in the dashboard
4. Click **Create Key**
5. Give it a name (like "EmberHearth") and click **Create**
6. **Copy the key immediately** — you won't be able to see it again
   - It starts with `sk-ant-` followed by a long string of characters

### How Much Does It Cost?

Anthropic charges based on how much you use Claude:
- **Typical personal use:** $2-10 per month
- **Light use (a few messages a day):** Under $2 per month
- **Heavy use (many long conversations):** Could be $10-20 per month
- You can set spending limits in the Anthropic dashboard to avoid surprises

### Entering Your API Key in EmberHearth

1. During onboarding, you'll see a field to paste your API key
2. Paste the key you copied from the Anthropic dashboard
3. EmberHearth will verify the key works by making a small test request
4. If the key is valid, you'll see a green checkmark

**Security note:** Your API key is stored in the macOS Keychain — the same secure storage that holds your passwords. It is never stored in a text file, never logged, and never sent anywhere except to Anthropic's API.

### Changing Your API Key Later

1. Click the EmberHearth icon in your menu bar
2. Click "Settings" (or press Cmd+,)
3. Go to the "API Key" section
4. Enter your new key and click "Save"

---

## Phone Number Configuration

EmberHearth only responds to messages from phone numbers you've authorized. This is a security feature — it prevents anyone else from talking to your assistant.

### Setting Your Phone Number

1. During onboarding, you'll see a field to enter your phone number
2. Enter the phone number you'll be texting from
3. Use the format your Mac recognizes (e.g., +1 555 123 4567)
4. Click "Verify" to confirm

### Important Notes

- EmberHearth only responds to the phone number(s) you configure
- Messages from other numbers are completely ignored
- Group messages are detected and handled separately (Ember won't respond in group chats by default)
- You can change the authorized number later in Settings

---

## Using EmberHearth

### How to Talk to Ember

1. Open the Messages app on any Apple device (Mac, iPhone, iPad)
2. Start a conversation with yourself (your own phone number or Apple ID)
3. Type a message and send it
4. Ember will respond within a few seconds

That's it. There's no special syntax, no commands to memorize, no apps to switch between. Just text naturally.

### What You Can Ask

Ember is a general-purpose assistant. Here are some examples:

**Everyday questions:**
- "What's a good recipe for chicken tikka masala?"
- "How do I convert Celsius to Fahrenheit?"
- "What's the capital of New Zealand?"

**Remembering things:**
- "Remember that my dentist appointment is March 15th"
- "Remember that I prefer aisle seats on flights"
- "What did I ask you to remember about my dentist?"

**Web content:**
- Send a URL and ask "Can you summarize this article?"
- "What does this page say about return policies?" (with a link)

**Conversations:**
- "I'm trying to decide between two job offers. Can you help me think through the pros and cons?"
- "Explain quantum computing like I'm 12"
- "Help me draft a polite email declining an invitation"

### Tips for Better Conversations

- **Be specific** — "Help me plan meals for the week" works better than "Help me with food"
- **Give context** — "I'm vegetarian and don't like spicy food" helps Ember give better answers
- **Tell Ember to remember** — Explicitly say "Remember that..." for things you want it to recall later
- **Share links** — Ember can read and summarize web pages you send
- **Be patient with long responses** — Complex questions may take a few seconds longer

### The Menu Bar Icon

EmberHearth lives in your Mac's menu bar (the row of icons at the top-right of your screen). The icon shows Ember's current status:

- **Normal icon** — Everything is working, Ember is listening for messages
- **Warning indicator** — Something needs attention (click to see details)
- **Error indicator** — There's a problem (click to see what's wrong and how to fix it)

Click the menu bar icon to access:
- Settings
- Status information
- Quit EmberHearth

---

## Memory & Learning

### How Ember Remembers Things

When you tell Ember something about yourself, it extracts key facts and stores them locally on your Mac. For example:

- "Remember that I'm allergic to shellfish" → Ember stores: "User is allergic to shellfish"
- "My favorite color is blue" → Ember stores: "User's favorite color is blue"
- "I have a meeting with Dr. Park on Tuesday" → Ember stores: "User has a meeting with Dr. Park on Tuesday"

### How Memories Are Used

When you start a new conversation, Ember pulls relevant memories into context. If you mention dinner plans, it might recall that you're allergic to shellfish. If you ask about gift ideas, it might recall your friend's interests that you mentioned before.

### What Ember Learns

Over time, Ember also adapts to your communication style:
- If you prefer short, direct answers, Ember will be more concise
- If you like detailed explanations, Ember will elaborate more
- Ember adjusts its tone and verbosity based on how you interact with it

### Clearing Memories

If you want Ember to forget something:
- Tell it: "Forget that I mentioned [topic]"
- Or go to Settings and use the memory management options

All memories are stored locally in an encrypted database on your Mac. They are never uploaded anywhere.

---

## Privacy & Your Data

### What Data is Stored

| Data | Where | Encrypted |
|------|-------|-----------|
| Your memories/facts | Local SQLite database on your Mac | Yes |
| API key | macOS Keychain | Yes (system-level) |
| Phone number configuration | Local preferences | No (not sensitive) |
| App preferences | Local preferences | No (not sensitive) |
| Conversation history | iMessage (managed by Apple) | Yes (by Apple) |

### Where Data is Stored

All EmberHearth data is stored in your Mac's Application Support directory. Nothing is synced to iCloud, no analytics are collected, and no data is sent to third parties.

### What Leaves Your Mac

The ONLY data that leaves your Mac:
1. **Your messages to Ember** — Sent to the Claude API (Anthropic) for AI processing
2. **Relevant memories** — Included in the API request context so Ember can reference them
3. **Web page requests** — When you ask Ember to fetch a URL

That's it. No telemetry, no analytics, no tracking, no cloud backup.

### How to Delete Your Data

To completely remove all EmberHearth data:
1. Quit EmberHearth
2. Delete the app from your Applications folder
3. Delete the EmberHearth data folder:
   - Open Finder
   - Press Cmd+Shift+G
   - Type `~/Library/Application Support/EmberHearth/`
   - Delete the folder
4. Remove the API key from Keychain:
   - Open Keychain Access (in Applications > Utilities)
   - Search for "EmberHearth"
   - Delete any matching entries

---

## Troubleshooting

### Ember Isn't Responding to Messages

**Check that EmberHearth is running:**
- Look for the EmberHearth icon in your menu bar
- If it's not there, open EmberHearth from your Applications folder

**Check your permissions:**
- Go to **System Settings > Privacy & Security > Full Disk Access**
- Make sure EmberHearth is toggled ON
- Go to **System Settings > Privacy & Security > Automation**
- Make sure EmberHearth has permission for Messages

**Check your phone number:**
- Click the EmberHearth menu bar icon > Settings
- Verify the phone number matches the one you're texting from

**Check your API key:**
- Click the EmberHearth menu bar icon > Settings
- Try re-entering your API key
- Make sure your Anthropic account has available credits

### Messages Are Sending Slowly

- **API response time:** Claude typically responds in 2-5 seconds. Longer responses take more time.
- **Network issues:** Check your internet connection. EmberHearth needs internet access to reach the Claude API.
- **API rate limits:** If you're sending many messages quickly, Anthropic may rate-limit your requests. Wait a moment and try again.

### "API Key Invalid" Error

- Verify your API key at [console.anthropic.com](https://console.anthropic.com/)
- Make sure the key starts with `sk-ant-`
- Check that your Anthropic account is active and has credits
- Try generating a new API key and entering it in Settings

### "Permission Denied" Error

- Restart EmberHearth after granting permissions
- Some permission changes require a system restart to take effect
- If Full Disk Access was revoked, re-enable it in System Settings

### Ember Forgot Everything

- Memories are stored locally. If you reinstalled EmberHearth or deleted its data folder, memories are lost.
- Memories are NOT backed up automatically. Consider this when cleaning up your Mac.

### App Crashes on Launch

1. Check the Console app (Applications > Utilities > Console) for crash logs related to EmberHearth
2. Try deleting the preferences:
   - Open Terminal
   - Run: `defaults delete com.emberhearth.app`
3. Try reinstalling from a fresh download
4. File a bug report on [GitHub Issues](https://github.com/robault/emberhearth/issues)

### Messages Not Sending (Automation Permission)

If Ember can read your messages but can't respond:
1. Go to **System Settings > Privacy & Security > Automation**
2. Make sure "Messages" is toggled ON under EmberHearth
3. If it's not listed, try removing EmberHearth from Automation and re-launching the app
4. Restart your Mac if the issue persists

---

## Frequently Asked Questions

**Q: Is EmberHearth free?**
A: EmberHearth itself is free and open source. However, you need a Claude API key from Anthropic, which has usage-based costs (typically a few dollars per month).

**Q: Can I use it on my iPhone?**
A: EmberHearth runs on your Mac, but since it communicates through iMessage, you can text it from your iPhone, iPad, or any device signed into your Apple ID. The Mac needs to be running for Ember to respond.

**Q: What happens if my Mac is asleep or turned off?**
A: Ember can only respond when your Mac is awake and EmberHearth is running. Messages sent while your Mac is off will be processed when it wakes up. For always-on availability, consider a Mac Mini that stays on.

**Q: Can other people in my household text Ember?**
A: Only the phone number(s) you configure in Settings will get responses. Messages from other numbers are ignored completely.

**Q: Can Ember read my other conversations?**
A: EmberHearth has access to your iMessage database (required for Full Disk Access), but it ONLY reads and processes messages from the phone number(s) you've configured. It does not read, store, or process messages from other conversations.

**Q: Is my data sent to Anthropic?**
A: When you send Ember a message, that message (along with recent conversation context and relevant memories) is sent to Anthropic's Claude API for processing. Anthropic's data policies apply to that data. EmberHearth does not send any other data to Anthropic or any other third party.

**Q: Can I switch to a different AI model?**
A: The MVP version supports Claude only. Support for OpenAI and local models is planned for future releases.

**Q: How do I update EmberHearth?**
A: Download the latest release from the [Releases page](https://github.com/robault/emberhearth/releases) and replace the app in your Applications folder. Your data and settings are preserved because they're stored separately from the app.

**Q: How do I report a bug?**
A: File an issue on [GitHub Issues](https://github.com/robault/emberhearth/issues). Include what you were doing, what happened, and what you expected to happen. Do NOT include your API key or message content in bug reports.

**Q: Will EmberHearth work with macOS versions older than 13.0?**
A: No. EmberHearth requires macOS 13.0 (Ventura) or later. This is because it relies on system APIs that aren't available in older versions.
```

## File 3: Create CONTRIBUTING.md

**Path:** `CONTRIBUTING.md` (root of repo)

```markdown
# Contributing to EmberHearth

Thank you for your interest in contributing to EmberHearth! This guide will help you get set up and understand our development practices.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Getting Started](#getting-started)
3. [Project Structure](#project-structure)
4. [Code Style](#code-style)
5. [Security Rules](#security-rules)
6. [Testing](#testing)
7. [Pull Request Process](#pull-request-process)
8. [Architecture](#architecture)

---

## Prerequisites

Before you begin, make sure you have:

| Requirement | Version |
|-------------|---------|
| **macOS** | 14.0+ (Sonoma) for development |
| **Xcode** | 15.0+ (latest stable recommended) |
| **Swift** | 5.9+ |
| **Command Line Tools** | Installed (`xcode-select --install`) |

**Note:** The development requirement (macOS 14.0+) is higher than the deployment target (macOS 13.0+). You develop on Sonoma or later, but the app runs on Ventura or later.

---

## Getting Started

### Clone and Build

```bash
# Clone the repository
git clone https://github.com/robault/emberhearth.git
cd emberhearth

# Build the project
./build.sh build

# Run all tests
./build.sh test

# Run everything (security check + build + tests)
./build.sh all
```

### Open in Xcode

```bash
# If using Swift Package Manager
open Package.swift

# If using Xcode project
open EmberHearth.xcodeproj
```

### Available Build Commands

```bash
./build.sh build           # Build (debug configuration)
./build.sh test            # Run all tests
./build.sh clean           # Clean build artifacts
./build.sh release         # Build (release configuration)
./build.sh security-check  # Run security audit
./build.sh all             # Security check + build + test
```

Or use Make:

```bash
make build
make test
make clean
make all
```

---

## Project Structure

```
emberhearth/
├── CLAUDE.md               # AI assistant instructions (project conventions)
├── CONTRIBUTING.md          # This file
├── README.md               # User-facing project page
├── Package.swift           # Swift Package Manager configuration
├── build.sh                # Developer build script
├── Makefile                # Convenience targets
├── src/                    # All source code
│   ├── App/                # App lifecycle (AppDelegate, PermissionManager, AppVersion)
│   ├── Core/               # Core orchestration (MessageCoordinator)
│   ├── Database/           # Database layer (DatabaseManager)
│   ├── iMessage/           # iMessage integration (ChatDatabaseReader, MessageSender, MessageWatcher)
│   ├── LLM/                # LLM client (ClaudeAPIClient, StreamingHandler, ContextBuilder)
│   ├── Logging/            # Logging utilities (SecurityLogger)
│   ├── Memory/             # Memory system (FactStore, FactRetrieval, FactExtraction, SessionManager)
│   ├── Personality/        # Personality & context (SystemPrompt, VerbosityAdaptation)
│   ├── Security/           # Security layer (TronPipeline, InjectionScanner, CrisisDetector, KeychainManager)
│   └── Views/              # SwiftUI views (Onboarding/, Settings/, MenuBar/)
├── tests/                  # All test files
│   ├── CoreTests/          # Core orchestration tests
│   ├── DatabaseTests/      # Database layer tests
│   ├── iMessageTests/      # iMessage integration tests
│   ├── LLMTests/           # LLM client tests
│   ├── MemoryTests/        # Memory system tests
│   ├── SecurityTests/      # Security and crisis detection tests
│   └── IntegrationTests/   # End-to-end integration tests
├── docs/                   # Documentation
│   ├── VISION.md           # Vision and design philosophy
│   ├── NEXT-STEPS.md       # Roadmap and task tracking
│   ├── architecture-overview.md
│   ├── architecture/       # ADRs and architecture decisions
│   ├── releases/           # Release planning (MVP scope, feature matrix)
│   ├── specs/              # Implementation specifications
│   ├── research/           # Research findings
│   ├── deployment/         # Build and release docs
│   └── testing/            # Testing strategy
├── tasks/                  # AI-assisted build task documents
└── scripts/                # Developer scripts (pre-commit hooks)
```

### Key Source Files

| File | Purpose |
|------|---------|
| `src/Core/MessageCoordinator.swift` | Central orchestrator — connects iMessage, LLM, memory, and security |
| `src/Security/TronPipeline.swift` | Security screening pipeline (injection scanning, credential detection, crisis detection) |
| `src/Security/CrisisDetector.swift` | Crisis signal detection with tiered response system |
| `src/LLM/ClaudeAPIClient.swift` | Claude API integration with streaming support |
| `src/Memory/FactStore.swift` | Local fact storage and retrieval (SQLite) |
| `src/iMessage/ChatDatabaseReader.swift` | Reads the iMessage database (chat.db) |
| `src/iMessage/MessageSender.swift` | Sends iMessages via AppleScript automation |
| `src/App/PermissionManager.swift` | Checks and manages macOS permissions |

---

## Code Style

### Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Swift files | PascalCase | `MessageCoordinator.swift` |
| Doc files | lowercase-with-hyphens | `architecture-overview.md` |
| Types (class, struct, enum, protocol) | PascalCase | `CrisisDetector`, `FactStore` |
| Properties and methods | camelCase | `detectCrisis(in:)`, `matchedPatterns` |
| Enum cases | camelCase | `.tier1`, `.preference` |
| Constants | camelCase | `primaryCrisisNumber` |

### Documentation Comments

All public types and methods MUST have documentation comments:

```swift
/// Detects crisis signals in user messages using pattern matching.
///
/// The detector uses three layers of analysis:
/// 1. False positive filtering
/// 2. Tier-based pattern matching
/// 3. Context awareness
///
/// - Parameter message: The user's message text.
/// - Returns: A `CrisisAssessment` if crisis signals are detected, nil otherwise.
func detectCrisis(in message: String) -> CrisisAssessment? {
    // ...
}
```

### Logging

Use `os.Logger` for all logging. Never use `print()` in production code.

```swift
import os

private let logger = Logger(
    subsystem: "com.emberhearth.app",
    category: "YourCategory"
)

// Usage
logger.info("Something happened")
logger.error("Something went wrong: \(errorDescription, privacy: .public)")
```

**CRITICAL:** Never include user message content, API keys, phone numbers, or personal data in log output.

### SwiftUI Accessibility

Every interactive SwiftUI element must include accessibility modifiers:

```swift
Button("Save Settings") {
    saveSettings()
}
.accessibilityLabel("Save settings")
.accessibilityHint("Saves your current configuration")
```

Use semantic font styles, not fixed sizes:

```swift
// Good
.font(.headline)
.font(.body)

// Bad
.font(.system(size: 14))
```

---

## Security Rules

These are absolute rules. No exceptions.

### Never Do

- **No shell execution:** Never use `Process()`, `/bin/bash`, `/bin/sh`, `NSTask`, or `CommandLine` in source code. EmberHearth the application NEVER executes shell commands. (Build scripts for developer use are fine.)
- **No hardcoded credentials:** Never put API keys, tokens, or passwords in source code. Use Keychain.
- **No credentials in logs:** Never log API keys, user messages, phone numbers, or personal data.
- **No plaintext secrets:** Never store credentials in UserDefaults, plist files, or text files.
- **No force unwraps in production:** Use `guard let`, `if let`, or `Optional` chaining. (`XCTUnwrap` in tests is fine.)

### Always Do

- **Use Keychain for secrets:** All credentials go through `KeychainManager`.
- **Validate all inputs:** Every user input must be validated before processing.
- **Screen LLM inputs/outputs:** All messages pass through `TronPipeline` before and after the LLM.
- **Use parameterized SQL:** Never use string interpolation in SQL queries. Use `?` placeholders.
- **Log security events:** Use `SecurityLogger` for security-relevant events.
- **Sandbox file access:** Only access files in approved locations.

### Pre-Commit Hook

Install the pre-commit hook to catch security issues before committing:

```bash
cp scripts/pre-commit-check.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

This checks staged files for hardcoded API keys and shell execution in `src/`.

---

## Testing

### Running Tests

```bash
# All tests
./build.sh test

# Specific test class
swift test --filter CrisisDetectorTests

# With verbose output
swift test -v
```

### Coverage Target

The MVP target is **60% code coverage**. Aim higher for security-critical code.

### Test Organization

- Unit tests go in `tests/` mirroring the `src/` structure
- Integration tests go in `tests/IntegrationTests/`
- Security penetration tests go in `tests/SecurityTests/`

### What to Test

- All public methods
- Error paths and edge cases
- Security boundaries (injection attempts, credential exposure)
- Accessibility (VoiceOver labels exist on interactive elements)
- False positives and true positives for detection systems (crisis, injection)

---

## Pull Request Process

### Branch Naming

```
feature/short-description    # New features
fix/short-description        # Bug fixes
chore/short-description      # Maintenance, refactoring, docs
```

### Commit Messages

Follow the conventional commit format:

```
type(scope): description

Examples:
feat(memory): add fact extraction from conversations
fix(security): prevent credential leak in error messages
chore(docs): update contributing guide
test(crisis): add false positive tests for idioms
```

Types: `feat`, `fix`, `chore`, `test`, `docs`, `refactor`, `style`, `perf`

### Before Submitting

1. Run `./build.sh all` — must pass (security check + build + tests)
2. Ensure no new warnings are introduced
3. Add tests for new functionality
4. Update documentation if behavior changes
5. Verify accessibility on new UI elements (VoiceOver labels, Dynamic Type, keyboard nav)

### Review Requirements

- All PRs require at least one review
- Security-related changes require extra scrutiny
- No force-merging to main
- CI checks must pass before merge

---

## Architecture

For a detailed understanding of EmberHearth's architecture, see:

- [Architecture Overview](docs/architecture-overview.md) — System design and component relationships
- [ADR Index](docs/architecture/decisions/README.md) — Architectural Decision Records explaining key design choices
- [Vision](docs/VISION.md) — Product vision and design philosophy
- [Tron Security Spec](docs/specs/tron-security.md) — Security layer specification

### Key Design Principles

1. **Security by Removal** — No shell execution. Structured operations that can't be misused.
2. **Secure by Default** — Safe with zero configuration. Capabilities require explicit consent.
3. **The Grandmother Test** — If grandma can't use it unsupervised, it's not ready.
4. **Accessibility First** — iMessage as primary interface inherits Apple's full accessibility stack.
5. **Privacy First** — All personal data stays local. No cloud sync. No telemetry.

### Dependency Flow

Dependencies flow downward. Upper layers depend on lower layers, never the reverse:

```
App Layer (AppDelegate, Views)
    │
    ▼
Core Layer (MessageCoordinator)
    │
    ▼
Service Layer (Security, Memory, LLM, iMessage)
    │
    ▼
Data Layer (Database)
```

Cross-module imports within the same layer should be avoided. If module A and module B at the same layer need to communicate, they should do so through the Core layer above them.
```

## File 4: Create docs/CHANGELOG.md

**Path:** `docs/CHANGELOG.md`

```markdown
# Changelog

All notable changes to EmberHearth will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-XX-XX

Initial release of EmberHearth.

### Added

#### iMessage Integration
- Read incoming iMessages from authorized phone numbers via chat.db monitoring
- Send responses through Messages.app via AppleScript automation
- FSEvents-based real-time message detection
- Phone number filtering to restrict access to authorized users only
- Group chat detection to prevent unintended responses in group conversations

#### AI Conversations
- Claude API integration for AI-powered responses
- Streaming response handling for real-time message delivery
- Context window management with rolling summaries
- Conversation continuity across sessions
- Web content fetching and summarization

#### Memory System
- SQLite-based local fact storage with encryption
- Automatic fact extraction from conversations
- Relevant fact retrieval for conversation context
- Session management with conversation continuity
- Context budget enforcement to stay within token limits

#### Personality
- Ember personality with warm, helpful communication style
- Verbosity adaptation based on user communication patterns
- Bounded needs model for authentic personality expression
- System prompt engineering for consistent behavior

#### Security
- Tron security pipeline for input and output screening
- Prompt injection scanning on all inbound messages
- Credential detection scanning on all outbound responses
- Crisis detection with tiered response system (Tier 1/2/3)
- 988 Suicide & Crisis Lifeline referral in all crisis responses
- Security event logging (without user message content)
- Keychain-only credential storage
- No shell execution — ever
- Hardened Runtime enabled

#### User Interface
- Onboarding wizard with guided permission setup
- API key entry with validation
- Phone number configuration
- Settings panel for configuration management
- Menu bar integration with status indicators
- Error state UI with recovery guidance
- Crash recovery and graceful degradation

#### Accessibility
- Full VoiceOver support on all UI elements
- Dynamic Type support for all text
- Keyboard navigation throughout the settings app
- Semantic font styles (no fixed font sizes)
- iMessage as primary interface inherits Apple's accessibility stack

#### Developer Experience
- Build script with security-check, build, test, and release targets
- Makefile with convenience targets
- Pre-commit hook for security auditing
- Comprehensive test suite (unit, integration, security penetration)
```

## Implementation Rules

1. **Preserve the Creator message section** in README.md exactly as-is. Only modify content below it.
2. Doc files use lowercase-with-hyphens naming (e.g., `USER-GUIDE.md`, `CHANGELOG.md`).
3. Do NOT add new features or change source code. This is a documentation-only task.
4. Write the User Guide for non-technical users. Use plain language. Explain technical terms in parentheses when unavoidable.
5. All links should use relative paths within the repository.
6. Verify every internal link points to a file that exists.
7. Include accessibility and privacy messaging in ALL user-facing documentation.
8. System requirement is macOS 13.0+ (Ventura). Development requirement is macOS 14.0+ (Sonoma).
9. The product display name is "EmberHearth" (not "Ember Hearth" or "emberhearth" in user-facing text).
10. No emojis in documentation.

## Final Checks

Before finishing, verify:
1. README.md Creator message section is unchanged at the top
2. README.md below the Creator message is user-facing (not a developer documentation index)
3. README.md includes: features, system requirements, quick start, privacy, accessibility, building from source, documentation links
4. docs/USER-GUIDE.md exists with all sections: getting started, setup, API key, phone config, usage, memory, privacy, troubleshooting, FAQ
5. CONTRIBUTING.md exists with: prerequisites, getting started, project structure, code style, security rules, testing, PR process, architecture
6. docs/CHANGELOG.md exists with v1.0.0 entry following Keep a Changelog format
7. All internal links in all four files point to files that exist
8. No developer jargon in user-facing docs (README.md and USER-GUIDE.md)
9. Privacy and accessibility are mentioned in every user-facing document
10. No emojis in any documentation file
```

---

## Acceptance Criteria

### README.md
- [ ] Creator message section at the top is preserved unchanged
- [ ] Content below Creator message is user-facing (not a developer documentation index)
- [ ] Includes hero section explaining what EmberHearth is
- [ ] Includes key features list (conversational AI, memory, privacy, accessibility, always-on, security)
- [ ] Includes system requirements table (macOS 13.0+, Apple Silicon or Intel, iMessage, API key)
- [ ] Includes quick start guide (download, permissions, API key, phone number)
- [ ] Includes privacy and security section with details on local-only data, encryption, Keychain, no shell execution
- [ ] Includes accessibility section (VoiceOver, Dynamic Type, keyboard navigation)
- [ ] Includes building from source section pointing to CONTRIBUTING.md
- [ ] Includes documentation links organized into "For Users" and "For Developers"
- [ ] Uses badges (macOS version, Swift version, license, interface)
- [ ] No developer jargon in main content

### USER-GUIDE.md
- [ ] File exists at `docs/USER-GUIDE.md`
- [ ] Includes "What is EmberHearth?" section
- [ ] Includes "Getting Started" with system requirements in plain language
- [ ] Includes "Setup Walkthrough" explaining each permission in plain language (Full Disk Access, Automation, Notifications)
- [ ] Includes "API Key Setup" with step-by-step instructions for getting a Claude API key
- [ ] Includes cost guidance for API usage
- [ ] Includes "Phone Number Configuration" section
- [ ] Includes "Using EmberHearth" with conversation examples and tips
- [ ] Includes "Memory & Learning" explaining how Ember remembers things
- [ ] Includes "Privacy & Your Data" with data storage details and deletion instructions
- [ ] Includes "Troubleshooting" section covering: app not responding, slow messages, API key errors, permission issues, lost memories, crash recovery
- [ ] Includes "FAQ" with common questions
- [ ] Written in plain language suitable for non-technical users (the grandmother test)
- [ ] No unexplained developer jargon

### CONTRIBUTING.md
- [ ] File exists at root: `CONTRIBUTING.md`
- [ ] Includes prerequisites (Xcode 15+, macOS 14+, Swift 5.9+)
- [ ] Includes clone/build/test instructions
- [ ] Includes project structure description matching actual `src/` layout
- [ ] Includes code style conventions (PascalCase files, camelCase properties, documentation comments)
- [ ] Includes security rules (no shell execution, Keychain for secrets, no credentials in logs)
- [ ] Includes testing instructions with coverage target (60% MVP)
- [ ] Includes pull request process (branch naming, commit format, review requirements)
- [ ] Includes architecture links and design principles

### CHANGELOG.md
- [ ] File exists at `docs/CHANGELOG.md`
- [ ] Follows Keep a Changelog format (Added, Changed, Fixed, etc.)
- [ ] Has v1.0.0 entry with comprehensive feature list
- [ ] Features organized by category (iMessage, AI, Memory, Personality, Security, UI, Accessibility, Developer Experience)
- [ ] Includes semantic versioning reference

### General
- [ ] All internal links across all four files point to files that exist
- [ ] No developer jargon in user-facing documents (README.md, USER-GUIDE.md)
- [ ] Privacy mentioned in all user-facing documents
- [ ] Accessibility mentioned in all user-facing documents
- [ ] Product name consistently "EmberHearth" in user-facing text
- [ ] System requirement consistently macOS 13.0+ (Ventura)
- [ ] No emojis in any documentation file

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# ── File Existence ──
echo "=== FILE EXISTENCE ==="
test -f README.md && echo "PASS: README.md exists" || echo "FAIL: README.md missing"
test -f CONTRIBUTING.md && echo "PASS: CONTRIBUTING.md exists" || echo "FAIL: CONTRIBUTING.md missing"
test -f docs/USER-GUIDE.md && echo "PASS: docs/USER-GUIDE.md exists" || echo "FAIL: docs/USER-GUIDE.md missing"
test -f docs/CHANGELOG.md && echo "PASS: docs/CHANGELOG.md exists" || echo "FAIL: docs/CHANGELOG.md missing"

# ── README.md Checks ──
echo "=== README.md ==="

# Creator message preserved
grep -q "Creator message:" README.md && echo "PASS: Creator message section preserved" || echo "FAIL: Creator message section missing"
grep -q "hey AI agent" README.md && echo "PASS: Creator note to AI preserved" || echo "FAIL: Creator note to AI missing"

# User-facing content present
grep -q "System Requirements" README.md && echo "PASS: System Requirements section present" || echo "FAIL: System Requirements missing"
grep -q "Quick Start" README.md && echo "PASS: Quick Start section present" || echo "FAIL: Quick Start missing"
grep -q "Privacy" README.md && echo "PASS: Privacy section present" || echo "FAIL: Privacy section missing"
grep -q "Accessibility" README.md && echo "PASS: Accessibility section present" || echo "FAIL: Accessibility section missing"
grep -q "macOS 13.0" README.md && echo "PASS: macOS 13.0 requirement stated" || echo "FAIL: macOS 13.0 requirement missing"

# ── USER-GUIDE.md Checks ──
echo "=== USER-GUIDE.md ==="
grep -q "Getting Started" docs/USER-GUIDE.md && echo "PASS: Getting Started section" || echo "FAIL: Getting Started missing"
grep -q "Setup Walkthrough" docs/USER-GUIDE.md && echo "PASS: Setup Walkthrough section" || echo "FAIL: Setup Walkthrough missing"
grep -q "Full Disk Access" docs/USER-GUIDE.md && echo "PASS: Full Disk Access explained" || echo "FAIL: Full Disk Access missing"
grep -q "Automation" docs/USER-GUIDE.md && echo "PASS: Automation permission explained" || echo "FAIL: Automation permission missing"
grep -q "API Key" docs/USER-GUIDE.md && echo "PASS: API Key section present" || echo "FAIL: API Key section missing"
grep -q "Troubleshooting" docs/USER-GUIDE.md && echo "PASS: Troubleshooting section" || echo "FAIL: Troubleshooting missing"
grep -q "FAQ\|Frequently Asked" docs/USER-GUIDE.md && echo "PASS: FAQ section" || echo "FAIL: FAQ missing"
grep -q "Privacy" docs/USER-GUIDE.md && echo "PASS: Privacy section" || echo "FAIL: Privacy missing"

# ── CONTRIBUTING.md Checks ──
echo "=== CONTRIBUTING.md ==="
grep -q "Prerequisites" CONTRIBUTING.md && echo "PASS: Prerequisites section" || echo "FAIL: Prerequisites missing"
grep -q "Xcode 15" CONTRIBUTING.md && echo "PASS: Xcode requirement stated" || echo "FAIL: Xcode requirement missing"
grep -q "Security Rules" CONTRIBUTING.md && echo "PASS: Security rules section" || echo "FAIL: Security rules missing"
grep -q "No shell execution\|Never.*shell\|No.*Process()" CONTRIBUTING.md && echo "PASS: Shell execution prohibition documented" || echo "FAIL: Shell execution rule missing"
grep -q "Pull Request\|PR" CONTRIBUTING.md && echo "PASS: PR process documented" || echo "FAIL: PR process missing"

# ── CHANGELOG.md Checks ──
echo "=== CHANGELOG.md ==="
grep -q "1.0.0" docs/CHANGELOG.md && echo "PASS: v1.0.0 entry exists" || echo "FAIL: v1.0.0 entry missing"
grep -q "Added" docs/CHANGELOG.md && echo "PASS: 'Added' category present" || echo "FAIL: 'Added' category missing"
grep -q "Keep a Changelog" docs/CHANGELOG.md && echo "PASS: Follows Keep a Changelog" || echo "FAIL: Keep a Changelog reference missing"

# ── Link Validation (spot check key internal links) ──
echo "=== INTERNAL LINK SPOT CHECK ==="
test -f docs/VISION.md && echo "PASS: docs/VISION.md exists (linked from README)" || echo "FAIL: docs/VISION.md missing"
test -f docs/architecture-overview.md && echo "PASS: docs/architecture-overview.md exists (linked from README)" || echo "FAIL: missing"
test -f docs/architecture/decisions/README.md && echo "PASS: ADR index exists (linked from README)" || echo "FAIL: missing"
test -f docs/deployment/build-and-release.md && echo "PASS: build-and-release.md exists (linked from CONTRIBUTING)" || echo "FAIL: missing"
test -f docs/testing/strategy.md && echo "PASS: testing/strategy.md exists (linked from README)" || echo "FAIL: missing"
test -f docs/specs/tron-security.md && echo "PASS: tron-security.md exists (linked from CONTRIBUTING)" || echo "FAIL: missing"

# ── No Emojis Check ──
echo "=== EMOJI CHECK ==="
# Check for common emoji patterns (unicode ranges) — should find zero
python3 -c "
import re, sys
files = ['README.md', 'CONTRIBUTING.md', 'docs/USER-GUIDE.md', 'docs/CHANGELOG.md']
emoji_pattern = re.compile('[\U0001F600-\U0001F64F\U0001F300-\U0001F5FF\U0001F680-\U0001F6FF\U0001F1E0-\U0001F1FF\U00002702-\U000027B0\U0001F900-\U0001F9FF\U0001FA00-\U0001FA6F\U0001FA70-\U0001FAFF]')
for f in files:
    try:
        with open(f) as fh:
            content = fh.read()
            emojis = emoji_pattern.findall(content)
            if emojis:
                print(f'WARN: {f} contains emojis: {emojis}')
            else:
                print(f'PASS: {f} has no emojis')
    except FileNotFoundError:
        print(f'SKIP: {f} not found')
" 2>/dev/null || echo "SKIP: Python emoji check unavailable"
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the final documentation created in task 0906 for EmberHearth, a native macOS personal AI assistant that uses iMessage as its primary interface. This is the LAST task in the entire MVP build sequence.

@README.md
@CONTRIBUTING.md
@docs/USER-GUIDE.md
@docs/CHANGELOG.md

Also reference for accuracy:
@CLAUDE.md (naming conventions, security boundaries, core principles)
@docs/releases/mvp-scope.md (feature matrix — verify CHANGELOG matches actual MVP features)

Review each document thoroughly:

1. **CLARITY FOR NON-TECHNICAL USERS (Critical for README.md and USER-GUIDE.md):**
   - Read README.md as if you are a non-technical person visiting the project for the first time. Is it immediately clear what EmberHearth does and how to get started?
   - Read USER-GUIDE.md as if you are someone's grandparent trying to set up EmberHearth. Is every step clear? Are technical terms explained?
   - Is there any developer jargon that would confuse a non-technical reader?
   - Would a user understand why each permission is needed based on the explanations?
   - Are the troubleshooting steps actionable — can someone follow them without developer knowledge?
   - Is the FAQ comprehensive? Are there obvious questions that are missing?

2. **ACCURACY OF SYSTEM REQUIREMENTS:**
   - Is the deployment target consistently stated as macOS 13.0+ (Ventura)?
   - Is the development requirement stated as macOS 14.0+ (Sonoma) in CONTRIBUTING.md?
   - Are Xcode 15+ and Swift 5.9+ correctly listed as development prerequisites?
   - Is the Claude API key requirement clearly explained?
   - Are the permission requirements correct (Full Disk Access, Automation, Notifications)?

3. **COMPLETENESS OF TROUBLESHOOTING (USER-GUIDE.md):**
   - Does it cover: app not responding, messages not sending, API key errors, permission issues, lost memories, crashes?
   - Are the suggested fixes accurate for macOS?
   - Is the data deletion process complete and correct?
   - Are there any common issues that are NOT covered?

4. **CORRECT PROJECT STRUCTURE (CONTRIBUTING.md):**
   - Does the project structure description match the actual src/ directory layout?
   - Are the key source files correctly described?
   - Is the dependency flow diagram accurate?
   - Are all security rules from CLAUDE.md reflected in the contributing guide?
   - Is the commit message format consistent with what the project actually uses?

5. **CHANGELOG ACCURACY:**
   - Compare the v1.0.0 feature list against docs/releases/mvp-scope.md
   - Are there features listed in the CHANGELOG that are NOT in the MVP scope?
   - Are there MVP features missing from the CHANGELOG?
   - Does it follow Keep a Changelog format correctly?

6. **SENSITIVE INFORMATION:**
   - Do any of the documents expose API keys, credentials, or internal URLs that shouldn't be public?
   - Are example API keys clearly marked as examples (not real)?
   - Does the user guide correctly warn against sharing API keys?
   - Are bug report instructions clear about NOT including sensitive data?

7. **INTERNAL LINK VALIDATION:**
   - Check every internal link in all four documents. Does the linked file exist?
   - Are all links using correct relative paths?
   - Are GitHub links using the correct repository URL?

8. **CONSISTENCY:**
   - Is the product name consistently "EmberHearth" in user-facing text?
   - Is the system requirement consistently macOS 13.0+ across all documents?
   - Is the privacy messaging consistent across all documents?
   - Are the accessibility claims consistent?

9. **README.md CREATOR MESSAGE:**
   - Is the Creator message section at the top of README.md completely unchanged?
   - Is all new content placed below it, after the --- separator?

Report issues with severity:
- **CRITICAL**: Factual errors, missing security warnings, broken links, exposed credentials
- **IMPORTANT**: Jargon in user-facing docs, inconsistencies, missing sections
- **MINOR**: Formatting, style preferences, nice-to-have additions
```

---

## Commit Message

```
docs: add user-facing documentation, user guide, contributing guide, and changelog
```

---

## Notes for Next Task

There is no next task. This is the final task in the EmberHearth MVP build sequence.

After this task is complete:
1. Ensure task 0903 (Final Code Review and Cleanup) is also complete
2. Create a git tag: `git tag v1.0.0`
3. Follow the build-and-release process in `docs/deployment/build-and-release.md`
4. Run the manual smoke test checklist in `docs/testing/strategy.md`
5. Begin beta testing with the protocol in `docs/testing/strategy.md`

Post-MVP documentation priorities (v1.1+):
- API documentation for developers extending EmberHearth
- Multi-language user guide
- Video walkthrough for onboarding
- Troubleshooting guide expansion based on beta tester feedback
- Architecture deep-dive documents for significant contributors
