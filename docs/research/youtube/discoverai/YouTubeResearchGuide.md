# Discover AI - YouTube Research Guide (EmberHearth)

This guide enables any Claude Code session to search the **Discover AI** YouTube channel for videos relevant to EmberHearth, pull transcripts, and save them as searchable markdown files in this directory.

---

## Channel Info

- **Channel:** Discover AI
- **Channel ID:** `UCfOvNb3xj28SNqPQ_JIbumg`
- **Focus:** Scientific AI research frontiers — papers from DeepMind, Google, Stanford, CMU, etc.
- **Cadence:** Daily uploads

---

## What EmberHearth Cares About

EmberHearth is a secure, accessible, always-on personal AI assistant for macOS. Primary interface is iMessage. It uses Claude as its LLM provider with local/offline fallback planned.

> **📋 Check calibrated topics first.** Before using the static tables below, check [`../../CALIBRATED-TOPICS.md`](../../CALIBRATED-TOPICS.md) for the current calibrated topic list. If calibration has run, that file supersedes these tables — it has phase-aware priorities, updated search terms, and emerging topics derived from the actual project state. The tables below serve as the **baseline seed** for calibration and as a fallback if calibration hasn't run yet.

### High-Priority Research Topics (Baseline)

These topics directly impact EmberHearth's architecture and development decisions:

| Topic | Why It Matters |
|-------|---------------|
| **Prompt injection & LLM security** | Core of the Tron security layer; adversarial input detection |
| **Context window management** | Token efficiency for long conversations over iMessage |
| **Memory & retrieval (RAG)** | Local SQLite memory system for facts and conversation history |
| **Multi-agent orchestration** | Task agents (ephemeral) + Cognitive agents (persistent) |
| **Alignment & personality constraints** | Ember personality system; bounded, attachment-informed behavior |
| **Local/on-device LLMs** | Offline fallback; model compression; on-device inference |
| **Constitutional AI & safety** | Behavioral constraints, safety layers, goal alignment |
| **Long-horizon planning** | Autonomous operation, proactive behavior, anticipatory systems |
| **Few-shot learning & adaptation** | Learning from user interactions without retraining |
| **Reasoning quality & evaluation** | Ralph Loop for continuous prompt refinement and quality assessment |

### Medium-Priority Topics (Baseline)

| Topic | Why It Matters |
|-------|---------------|
| **Quantization & model compression** | Relevant to local model fallback strategy |
| **Mixture of Experts (MoE)** | Could inform provider selection and model routing |
| **Reinforcement learning for LLMs** | Informs understanding of model capabilities and limitations |
| **Agent failure modes** | Circuit breakers, error recovery, graceful degradation |

### Low-Priority (Track but don't prioritize)

- Benchmark comparisons between models (unless Claude is featured)
- Hardware-specific AI content (GPUs, TPUs)
- Pure math/theory with no applied relevance

---

## Search Keywords

> If `CALIBRATED-TOPICS.md` has been populated, use the search terms from there instead of this baseline list.

When searching the Discover AI channel, use these baseline terms (combine as needed):

```
prompt injection, safety, security, alignment
context window, token, long context
memory, retrieval, RAG, knowledge
multi-agent, agent orchestration, task agent
personality, constitutional AI, behavioral
local model, on-device, offline, edge AI
reasoning, chain of thought, thinking
evaluation, benchmark, quality
quantization, compression, small model
MoE, mixture of experts
reinforcement learning, RLHF, RL
few-shot, in-context learning, ICL
planning, autonomous, proactive
```

---

## Workflow: Finding and Saving Videos

### Step 1: Search for Recent Videos

Use the YouTube MCP tools to search the channel:

```
Tool: mcp__youtube__searchVideos
  query: <keyword from list above>
  channelId: UCfOvNb3xj28SNqPQ_JIbumg
  maxResults: 10-30
  order: date
```

Or get the latest videos regardless of topic:

```
Tool: mcp__youtube__searchVideos
  query: *
  channelId: UCfOvNb3xj28SNqPQ_JIbumg
  maxResults: 30
  order: date
```

### Step 2: Filter for Relevance

Review titles and descriptions against the topic tables above. Prioritize:
1. Videos that match High-Priority topics
2. Videos mentioning Claude, Anthropic, or direct competitors
3. Videos about techniques EmberHearth could adopt

### Step 3: Pull Transcript

```
Tool: mcp__youtube__getTranscripts
  videoIds: ["<videoId>"]
  format: full_text
  lang: en
```

### Step 4: Save as Markdown

Save each transcript to this directory with the naming convention:

```
docs/research/youtube/discoverai/<YYYY-MM-DD>-<slugified-title>.md
```

**File format:**

```markdown
# <Video Title>

- **Video ID:** <id>
- **Published:** <date>
- **Channel:** Discover AI
- **URL:** https://www.youtube.com/watch?v=<videoId>
- **Relevance:** <which EmberHearth topic(s) this relates to>

## Why This Matters for EmberHearth

<1-3 sentence summary of why this video was selected>

## Transcript

<full transcript text>
```

### Step 5: Extract Source Papers (Optional but Recommended)

Many Discover AI videos are deep dives into specific research papers. After saving a transcript, extract the source paper using the paper-search MCP tools:

1. Scan the transcript for paper titles, author names, and institutions
2. Search for the paper:
   ```
   Tool: search_arxiv
     query: "<paper title or key phrase>"
     max_results: 5
   ```
3. If found, follow the workflow in `docs/research/papers/PaperResearchGuide.md` to save it
4. Cross-reference the video and paper files with each other

This creates a linked research library: video explanation + source paper side by side.

### Step 6: Update the Index (Optional)

If an `index.md` file exists in this directory, append the new entry. If it doesn't exist and there are 5+ transcripts saved, create one:

```markdown
# Discover AI - Saved Transcripts

| Date | Title | Topics | File |
|------|-------|--------|------|
| ... | ... | ... | ... |
```

---

## Tips for Future Sessions

- The channel posts daily. A weekly scan of the last 7 videos is a good cadence.
- Use `getVideoDetails` if you need view counts or tags to gauge impact.
- Cross-reference findings with EmberHearth's architecture docs at `docs/architecture-overview.md`.
- If a video covers a topic that warrants an architecture decision, note it and suggest creating an ADR in `docs/architecture/decisions/`.
- Transcripts are free (no YouTube API quota cost), so grab them liberally.
