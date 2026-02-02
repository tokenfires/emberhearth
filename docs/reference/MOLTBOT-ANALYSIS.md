# Moltbot Architecture Analysis

**Purpose:** Reference document for understanding Moltbot's construction, operation, and features to inform EmberHearth design decisions.

**Date:** January 30, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [High-Level Architecture](#high-level-architecture)
3. [The Gateway (Always-On System)](#the-gateway-always-on-system)
4. [The Agent System (LLM Integration)](#the-agent-system-llm-integration)
5. [Memory System](#memory-system)
6. [Cron and Scheduled Tasks (Overnight Processing)](#cron-and-scheduled-tasks-overnight-processing)
7. [Messaging Channels](#messaging-channels)
8. [Hooks System (Extensibility)](#hooks-system-extensibility)
9. [CLI Commands](#cli-commands)
10. [Configuration System](#configuration-system)
11. [Security Considerations](#security-considerations)
12. [Key Takeaways for EmberHearth](#key-takeaways-for-emberhearth)

---

## Overview

### What is Moltbot?

Moltbot is a multi-channel AI assistant gateway that bridges messaging platforms (WhatsApp, Telegram, Discord, Slack, Signal, iMessage) to AI coding agents. Key characteristics:

- **TypeScript/Node.js** codebase (~2,400+ source files)
- **Gateway architecture** — single long-running process managing all connections
- **Pi agent integration** — uses the Pi coding agent framework
- **Multi-channel** — supports 6+ messaging platforms with plugin extensibility
- **Always-on** — designed to run continuously as a service

### The "Space Lobster" Theme

Moltbot powers "Clawd" (CLAW + TARDIS), a space lobster assistant. The theming is playful, but the underlying system is sophisticated.

---

## High-Level Architecture

```
WhatsApp / Telegram / Discord / iMessage / Slack / Signal (+ plugins)
        │
        ▼
  ┌───────────────────────────┐
  │          GATEWAY          │  ws://127.0.0.1:18789 (default)
  │     (single process)      │
  │                           │  
  │  ┌─────────────────────┐  │
  │  │ Channel Manager     │  │  ← Manages all messaging connections
  │  │ Agent Runner        │  │  ← Executes LLM agent turns
  │  │ Cron Service        │  │  ← Scheduled tasks
  │  │ Heartbeat Runner    │  │  ← Periodic checks
  │  │ Session Manager     │  │  ← Conversation state
  │  │ Plugin Registry     │  │  ← Extension system
  │  │ WebSocket Server    │  │  ← Control plane
  │  │ HTTP Server         │  │  ← APIs + webhooks
  │  └─────────────────────┘  │
  └───────────┬───────────────┘
              │
              ├─ Pi agent (embedded)
              ├─ CLI (moltbot …)
              ├─ macOS menubar app
              ├─ iOS/Android nodes
              └─ Browser Control UI
```

### Key Insight: Single Gateway Process

Everything flows through **one long-running process**. The Gateway:
- Owns all channel connections (WhatsApp session, Telegram bot, etc.)
- Manages the agent execution
- Handles scheduled tasks
- Exposes WebSocket + HTTP APIs

This is how the "always on" aspect works — it's a persistent Node.js process.

---

## The Gateway (Always-On System)

### Entry Point

```
CLI: moltbot gateway run
File: src/cli/gateway-cli/run.ts → src/gateway/server.impl.ts
```

### Startup Sequence

1. **Config Loading** — Reads `~/.clawdbot/moltbot.json`
2. **Runtime State Creation** — HTTP server, WebSocket server, client registry
3. **Component Initialization**:
   - Node Registry (connected devices)
   - Channel Manager (messaging platforms)
   - Discovery Service (mDNS/Bonjour)
   - Cron Service (scheduled tasks)
   - Heartbeat Runner (periodic checks)
   - Plugin Registry (extensions)
4. **Sidecar Services** — Browser control, Gmail watcher, hooks, channels
5. **WebSocket Handler** — Control plane for clients
6. **Config Watcher** — Hot-reload support

### How It Stays Running

The Gateway stays alive via Node.js's event loop:
- **HTTP Server** listening on port (default 18789)
- **WebSocket Server** for real-time communication
- **Timers** for maintenance, health checks, cron jobs
- **Channel Connections** (Telegram polling, Discord WebSocket, etc.)

No explicit polling loop — Node.js handles I/O events.

### Process Management

Can run as:
- **Direct CLI** — `moltbot gateway run`
- **macOS LaunchAgent** — Menubar app manages lifecycle
- **Linux systemd service** — User service
- **Windows scheduled task** — Via Task Scheduler

### Key Files

- `src/gateway/server.impl.ts` — Main startup
- `src/gateway/server-runtime-state.ts` — Runtime state
- `src/gateway/server-http.ts` — HTTP endpoints
- `src/gateway/server-close.ts` — Shutdown handling

---

## The Agent System (LLM Integration)

### Core Architecture

Moltbot uses the **Pi coding agent** framework (`@mariozechner/pi-coding-agent`). The agent:
- Receives prompts from messaging channels
- Maintains conversation context
- Has access to tools (file operations, web search, browser, etc.)
- Streams responses back to channels

### Agent Execution Flow

```
Message arrives → Auto-reply system → runEmbeddedPiAgent() → LLM API call → Tool execution → Response
```

### Session Management

**Sessions are persisted as JSONL files:**
```
~/.clawdbot/agents/<agentId>/sessions/<sessionKey>.jsonl
```

Each line is a JSON object representing a conversation turn. Sessions persist across restarts.

### Context Handling

1. **Session Loading** — Reads prior messages from JSONL
2. **Sanitization** — Adapts history for provider compatibility (Anthropic vs OpenAI vs Google)
3. **Limiting** — Prunes old messages to fit context window
4. **System Prompt** — Constructed with tools, skills, workspace context

### Tools Available to Agent

**Core Coding Tools:**
- `read`, `write`, `edit`, `apply_patch` — File operations
- `grep`, `find`, `ls` — Search and navigation
- `exec`, `process` — Shell execution (!)

**Moltbot-Specific Tools:**
- `web_search`, `web_fetch` — Web research
- `browser` — Browser automation (Playwright)
- `canvas` — Visual canvas for A2UI
- `cron` — Schedule tasks
- `message` — Send messages to channels
- `gateway` — Gateway control
- `sessions_spawn` — Create subagents
- `image` — Image generation/analysis

### LLM Provider Support

- Anthropic (Claude)
- OpenAI (GPT-4, etc.)
- Google (Gemini)
- Groq, Mistral, and others
- Local models via `node-llama-cpp`

### Key Files

- `src/agents/pi-embedded-runner/run.ts` — Main agent runner
- `src/agents/pi-tools.ts` — Tool definitions
- `src/agents/moltbot-tools.ts` — Moltbot-specific tools
- `src/agents/system-prompt.ts` — System prompt construction

---

## Memory System

### Storage: SQLite + Vector Search

**Database:** `~/.clawdbot/agents/<agentId>/memory-index.db`

**Tables:**
- `meta` — Index metadata (model, provider, dimensions)
- `files` — Indexed files (path, hash, mtime)
- `chunks` — Text chunks with embeddings
- `chunks_vec` — Vector similarity search (sqlite-vec)
- `chunks_fts` — Full-text keyword search (FTS5)
- `embedding_cache` — Cached embeddings

### What Gets Indexed

1. **Memory Files** — `MEMORY.md`, `memory.md`, or `memory/*.md` in workspace
2. **Session Transcripts** — Past conversations from JSONL files

### How Memory Works

**Indexing:**
1. Discover files (markdown + session files)
2. Split into chunks (configurable token size/overlap)
3. Generate vector embeddings (OpenAI, Gemini, or local)
4. Store in SQLite with FTS and vector indexes

**Retrieval (Hybrid Search):**
1. Embed the query
2. Vector similarity search (cosine distance)
3. Optional keyword search (BM25)
4. Merge and rank results
5. Return snippets with metadata

### Learning Model

**Important:** Moltbot does **not** automatically extract facts from conversations.

- It indexes what's explicitly in memory files
- It indexes past session transcripts
- Users must manually curate `MEMORY.md`
- There's no automatic "learns about you" intelligence

### Key Files

- `src/memory/index.ts` — Memory index management
- `src/memory/store.ts` — SQLite storage
- `src/memory/embeddings.ts` — Embedding generation
- `src/memory/search.ts` — Hybrid search

---

## Cron and Scheduled Tasks (Overnight Processing)

### How "Overnight" Works

The cron system is how Moltbot does autonomous work without user prompts.

**Storage:** `~/.clawdbot/cron/jobs.json`

### Job Types

1. **One-Shot (`at`)** — Run once at a specific time
2. **Repeating (`every`)** — Run every N milliseconds
3. **Cron Expression (`cron`)** — Standard cron syntax with timezone

### Execution Modes

**Main Session Jobs (`sessionTarget: "main"`):**
- Enqueue a system event into the main agent session
- Agent processes it during next heartbeat
- Example: "Check my calendar and summarize"

**Isolated Jobs (`sessionTarget: "isolated"`):**
- Run in a dedicated `cron:<jobId>` session
- Independent of main conversation
- Can deliver results back to user
- Example: "Research topic X and send me a summary"

### Heartbeat Integration

The **heartbeat** is a periodic check that:
1. Wakes on schedule or when triggered
2. Checks for pending system events (from cron jobs)
3. Runs the agent to process them
4. Sends any responses back to configured channels

**Wake Modes:**
- `now` — Immediately run heartbeat
- `next-heartbeat` — Queue for next scheduled run

### Execution Flow

```
Timer fires → Check due jobs → Execute job → Inject system event → Trigger heartbeat → Agent runs → Deliver response
```

### Key Files

- `src/cron/service.ts` — Main cron service
- `src/cron/service/timer.ts` — Timer and execution
- `src/cron/service/jobs.ts` — Job management
- `src/cron/isolated-agent/run.ts` — Isolated job execution

---

## Messaging Channels

### Supported Channels

**Core (Built-in):**
| Channel | Protocol | Notes |
|---------|----------|-------|
| WhatsApp | Baileys (Web) | QR code pairing, web session |
| Telegram | Bot API (grammY) | DMs and groups |
| Discord | Bot API (discord.js) | DMs and guild channels |
| Slack | Socket Mode | Workspace integration |
| Signal | signal-cli REST | Requires signal-cli setup |
| iMessage | imsg CLI | macOS only |

**Extensions (Plugins):**
- Matrix, MS Teams, Mattermost
- LINE, Zalo
- Nostr, Twitch
- And more

### Channel Abstraction

All channels implement a common interface (`ChannelPlugin`) with optional adapters:
- `ChannelOutboundAdapter` — Sending messages
- `ChannelConfigAdapter` — Configuration
- `ChannelStatusAdapter` — Health/status
- `ChannelPairingAdapter` — Device pairing
- `ChannelGroupAdapter` — Group behavior
- `ChannelMentionAdapter` — Mention handling

### Message Flow

**Inbound:**
```
Platform → Monitor → Normalize → Access Control → Auto-Reply → Agent
```

**Outbound:**
```
Agent Response → Chunking → Channel Adapter → Platform API
```

### Access Control Features

1. **Allowlists** — Who can send messages
2. **Pairing** — Device/user verification for DMs
3. **Command Gating** — Who can run commands
4. **Mention Gating** — Group message filtering (require @mention)

### Key Files

- `src/channels/plugins/` — Plugin system
- `src/telegram/` — Telegram implementation
- `src/discord/` — Discord implementation
- `src/slack/` — Slack implementation
- `src/signal/` — Signal implementation
- `src/imessage/` — iMessage implementation
- `src/web/` — WhatsApp (Baileys) implementation

---

## Hooks System (Extensibility)

### What Are Hooks?

Event-driven extensions that react to system events:
- `command` — Slash command events (`/new`, `/reset`)
- `agent:bootstrap` — Before agent starts
- `gateway:startup` — After gateway starts
- `session` — Session lifecycle (planned)

### Built-in Hooks

1. **session-memory** — Saves session context to memory on `/new`
2. **command-logger** — Logs all commands to audit file
3. **soul-evil** — Swaps AI personality during "purge windows" (fun feature)
4. **boot-md** — Executes `BOOT.md` on gateway startup

### Gmail Hook

Watches Gmail for new emails and injects them as system events. Uses Google Pub/Sub for push notifications.

### Hook Structure

```
hooks/
  my-hook/
    HOOK.md       # Metadata (YAML frontmatter)
    handler.ts    # Handler function
```

### Key Files

- `src/hooks/internal-hooks.ts` — Event system
- `src/hooks/loader.ts` — Hook discovery
- `src/hooks/bundled/` — Built-in hooks

---

## CLI Commands

### Core Commands

| Command | Description |
|---------|-------------|
| `moltbot setup` | Initialize config and workspace |
| `moltbot onboard` | Interactive setup wizard |
| `moltbot gateway` | Gateway management (run, start, stop, status) |
| `moltbot agent` | Run agent turn |
| `moltbot message send` | Send messages to channels |
| `moltbot status` | Show channel health |
| `moltbot doctor` | Health checks and fixes |

### Channel Management

| Command | Description |
|---------|-------------|
| `moltbot channels list` | List configured channels |
| `moltbot channels login` | Link a channel (QR for WhatsApp) |
| `moltbot channels status` | Show channel status |
| `moltbot channels add` | Add channel account |

### Agent/Session Commands

| Command | Description |
|---------|-------------|
| `moltbot agents list` | List configured agents |
| `moltbot agents add` | Add isolated agent |
| `moltbot sessions` | List conversation sessions |

### Model Configuration

| Command | Description |
|---------|-------------|
| `moltbot models list` | List available models |
| `moltbot models set` | Set default model |
| `moltbot models auth add` | Add auth profile (API key, OAuth) |

### Automation

| Command | Description |
|---------|-------------|
| `moltbot cron list` | List scheduled jobs |
| `moltbot cron add` | Add scheduled job |
| `moltbot hooks` | Manage hooks |
| `moltbot plugins` | Manage plugins |

---

## Configuration System

### Config File

**Location:** `~/.clawdbot/moltbot.json`

### Key Sections

```json5
{
  // Agent settings
  agent: {
    model: "claude-sonnet-4-20250514",
    workspace: "~/moltbot-workspace",
    // ...
  },
  
  // Channel configuration
  channels: {
    whatsapp: {
      allowFrom: ["+15555550123"],
      groups: { "*": { requireMention: true } }
    },
    telegram: { /* ... */ },
    discord: { /* ... */ }
  },
  
  // Message handling
  messages: {
    groupChat: {
      mentionPatterns: ["@clawd", "@moltbot"]
    }
  },
  
  // Gateway settings
  gateway: {
    port: 18789,
    bind: "loopback",
    token: "xxx"
  },
  
  // Cron jobs
  cron: {
    jobs: [/* ... */]
  },
  
  // Hooks
  hooks: {
    gmail: { /* ... */ }
  }
}
```

### Environment Variables

- `CLAWDBOT_CONFIG_PATH` — Custom config file path
- `CLAWDBOT_STATE_DIR` — Custom state directory
- `ANTHROPIC_API_KEY` — Claude API key
- `OPENAI_API_KEY` — OpenAI API key

---

## Security Considerations

### Critical Security Issues (from SECURITY-AUDIT.md)

**1. Shell Execution**
The agent has `exec` and `process` tools that run arbitrary shell commands. This means:
```
Untrusted Input → LLM → Shell Execution → Complete System Access
```

A prompt injection attack could execute any command on the host system.

**2. Credential Exposure**
- API keys stored in config files or environment variables
- Can be read by the agent via file tools
- Once compromised, attacker has all keys

**3. No Sandboxing**
- Agent runs with full user privileges
- No process isolation
- No capability restrictions

**4. Trust Model**
- All messages from allowed senders are trusted
- LLM decides what actions to take
- No human approval for dangerous operations (by default)

### What Moltbot Does Right

- **Allowlists** — Can restrict who sends messages
- **Pairing** — Device verification for DMs
- **Command gating** — Restrict command execution
- **Exec approvals** — Optional approval for shell commands
- **Token-based gateway auth** — Protects control plane

### What EmberHearth Should Avoid

1. **No shell execution** — Use structured operations only
2. **Credential isolation** — Use keychain, never expose to LLM
3. **Sandboxed workbench** — If shell needed, full container isolation
4. **Input sanitization** — Filter content before LLM sees it
5. **Output validation** — Check responses for credential leaks

---

## Key Takeaways for EmberHearth

### Architecture Patterns to Consider

1. **Single Gateway Process** — Works well for "always on"
2. **WebSocket Control Plane** — Good for multi-client control
3. **Channel Abstraction** — Clean plugin interface
4. **Session Persistence** — JSONL is simple and effective
5. **Cron/Heartbeat** — Enables autonomous operation

### What to Improve

1. **Security Model** — Remove shell execution entirely
2. **Memory System** — Add automatic fact extraction, not just indexing
3. **Credential Handling** — Keychain integration, never expose
4. **Setup Complexity** — Moltbot requires technical expertise
5. **Configuration** — Too many options, JSON editing required

### Feature Inspiration

- **Multi-channel support** — Valuable, but iMessage-only is fine for MVP
- **Cron jobs** — Useful for proactive behavior
- **Session management** — Important for continuity
- **Heartbeat** — Enables anticipatory features
- **Hooks** — Good extensibility model

### Complexity to Avoid

- **Plugin system** — Adds attack surface and complexity
- **Multi-agent routing** — Unnecessary for single-user
- **Browser automation** — Security risk
- **Remote access** — Keep it local-first

---

## Summary

Moltbot is a sophisticated, feature-rich system that demonstrates what's possible with always-on AI assistants. However, its complexity and security model make it unsuitable for non-technical users.

**EmberHearth's opportunity:** Take the core concepts (gateway, sessions, scheduling, channel abstraction) and rebuild with:
- Security as the foundation
- Simplicity for non-technical users
- macOS-native integration
- iMessage as the primary (and initially only) interface

The architecture patterns are sound. The implementation choices around security need fundamental rethinking.

---

*This analysis is based on exploration of the Moltbot codebase as of January 2026.*
