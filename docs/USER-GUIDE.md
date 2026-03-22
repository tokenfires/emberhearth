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

1. **A Mac running macOS 26.0 or later**
   - To check your version: Click the Apple menu in the top-left corner, then "About This Mac"
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

- "Remember that I'm allergic to shellfish" — Ember stores: "User is allergic to shellfish"
- "My favorite color is blue" — Ember stores: "User's favorite color is blue"
- "I have a meeting with Dr. Park on Tuesday" — Ember stores: "User has a meeting with Dr. Park on Tuesday"

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
   - Open Terminal (Applications > Utilities > Terminal)
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
A: The v1.0 release supports Claude only. Support for additional AI providers is planned for future releases.

**Q: How do I update EmberHearth?**
A: Download the latest release from the [Releases page](https://github.com/robault/emberhearth/releases) and replace the app in your Applications folder. Your data and settings are preserved because they're stored separately from the app.

**Q: How do I report a bug?**
A: File an issue on [GitHub Issues](https://github.com/robault/emberhearth/issues). Include what you were doing, what happened, and what you expected to happen. Do NOT include your API key or message content in bug reports.

**Q: Will EmberHearth work with macOS versions older than 26.0?**
A: No. EmberHearth requires macOS 26.0 or later. This is because it relies on system APIs that aren't available in older versions.
