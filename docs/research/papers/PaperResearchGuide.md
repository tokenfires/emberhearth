# Academic Paper Research Guide (EmberHearth)

This guide enables any Claude Code session to search for academic papers relevant to EmberHearth, extract their content, and save them as searchable markdown files in this directory.

---

## MCP Server Info

- **Server:** paper-search-mcp
- **Platforms:** arXiv, Semantic Scholar, Google Scholar, CrossRef, PubMed, bioRxiv, medRxiv, IACR
- **Primary platforms for this project:** arXiv (pre-prints), Semantic Scholar (citations/related work)

---

## What EmberHearth Cares About

EmberHearth is a secure, accessible, always-on personal AI assistant for macOS. Primary interface is iMessage, using Claude as the LLM provider with local/offline fallback planned.

### High-Priority Research Topics

| Topic | Search Terms | Why It Matters |
|-------|-------------|----------------|
| **Prompt injection defense** | `prompt injection defense LLM`, `adversarial attacks language models` | Core of the Tron security layer |
| **Context window efficiency** | `context window management`, `long context LLM`, `token efficiency` | Long conversations over iMessage |
| **Retrieval-augmented generation** | `RAG retrieval augmented generation`, `memory augmented LLM` | Local SQLite memory system |
| **Multi-agent architectures** | `multi-agent LLM orchestration`, `agent coordination` | Task agents + Cognitive agents |
| **Alignment & behavioral constraints** | `constitutional AI`, `alignment fine-tuning`, `behavioral constraints LLM` | Ember personality system |
| **On-device / local LLMs** | `on-device inference`, `edge LLM`, `model compression mobile` | Offline fallback strategy |
| **AI safety & guardrails** | `LLM safety guardrails`, `alignment stability`, `jailbreak prevention` | Security-first design principle |
| **Long-horizon planning** | `LLM planning`, `autonomous agent planning`, `proactive AI assistant` | Autonomous operation mode |
| **Few-shot adaptation** | `few-shot learning LLM`, `in-context learning`, `user adaptation` | Learning from user interactions |
| **Reasoning evaluation** | `LLM reasoning evaluation`, `process reward model`, `chain of thought` | Ralph Loop quality assessment |

### Medium-Priority Topics

| Topic | Search Terms |
|-------|-------------|
| **Quantization & compression** | `model quantization`, `4-bit LLM`, `knowledge distillation` |
| **Mixture of Experts** | `mixture of experts LLM`, `MoE routing`, `sparse models` |
| **Agent failure modes** | `LLM agent failure`, `hallucination detection`, `cascading errors` |
| **Conversation modeling** | `dialogue systems`, `conversational AI`, `multi-turn reasoning` |

---

## Workflow: Finding and Saving Papers

### Method 1: Direct Search (when you know what you're looking for)

#### Step 1: Search arXiv or Semantic Scholar

```
Tool: search_arxiv
  query: "<search terms from table above>"
  max_results: 10

Tool: search_semantic
  query: "<search terms>"
  year: "2025"  (or 2026, to filter recent work)
  max_results: 10
```

#### Step 2: Review Results

Evaluate titles and abstracts against the topic tables. Prioritize:
1. Papers from top labs (Google DeepMind, Anthropic, OpenAI, Stanford, CMU, Princeton, MIT)
2. Papers published in the last 6 months
3. Papers with high citation counts (use Semantic Scholar for this)

#### Step 3: Extract Paper Content

```
Tool: read_arxiv_paper
  paper_id: "<arxiv_id>"  (e.g., "2503.23278")
  save_path: "./docs/research/papers/downloads"
```

This downloads the PDF and extracts text content.

#### Step 4: Save as Markdown

Save each paper to this directory with the naming convention:

```
docs/research/papers/<YYYY-MM-DD>-<slugified-title>.md
```

**File format:**

```markdown
# <Paper Title>

- **Paper ID:** <arXiv ID or DOI>
- **Authors:** <author list>
- **Published:** <date>
- **Source:** arXiv / Semantic Scholar / etc.
- **URL:** <link to paper>
- **Relevance:** <which EmberHearth topic(s) this relates to>

## Why This Matters for EmberHearth

<1-3 sentence summary of why this paper was selected>

## Key Findings

<3-5 bullet points summarizing the main contributions>

## Full Text

<extracted paper content>
```

### Method 2: From Video Transcripts (the pipeline approach)

When processing Discover AI video transcripts from `docs/research/youtube/discoverai/`:

#### Step 1: Identify Paper References

Scan the transcript for:
- Paper titles (often mentioned explicitly)
- Author names + institutions (e.g., "Princeton University tells us...")
- arXiv IDs (sometimes mentioned directly)
- Key phrases that uniquely identify the research

#### Step 2: Search for the Paper

```
Tool: search_arxiv
  query: "<paper title or key phrase from transcript>"
  max_results: 5
```

If arXiv doesn't find it, try Semantic Scholar or Google Scholar:

```
Tool: search_semantic
  query: "<paper title>"
  max_results: 5

Tool: search_google_scholar
  query: "<paper title authors>"
  max_results: 5
```

#### Step 3: Cross-Reference

When saving, note which video transcript referenced this paper:

```markdown
- **Referenced in:** [Video Title](../youtube/discoverai/<filename>.md)
```

#### Step 4: Save Using the Standard Format Above

---

## Known Issues & Workarounds

These are real problems encountered during paper research sweeps. Read this section before starting to avoid rediscovering them.

### 1. `search_arxiv` Returns Irrelevant Results (Search Is Broken)

As of February 2026, `search_arxiv` **does not filter by query**. It connects to arXiv successfully but returns the most recent global submissions regardless of search terms. For example, searching "prompt injection" returns papers on plasma physics and quantum computing. This has been confirmed across two separate research sweeps.

The tool sometimes returns `[]` (empty) instead — likely due to transient arXiv API issues or rate limiting. Either way, **do not rely on `search_arxiv` for finding papers.**

**Always use the WebSearch fallback for discovery:**
- **Search:** Use `WebSearch` to find papers. Query format: `"<paper title>" site:arxiv.org` or `"<topic>" arxiv 2026` works well.
- **Get metadata:** Use `WebFetch` on `https://arxiv.org/abs/<paper_id>` and prompt for title, authors, date, and abstract.
- **Full text:** Once you have a paper ID, `read_arxiv_paper` works (see issue #1b below). If that also fails, add a placeholder:
  ```
  > Full text extraction requires the paper-search MCP server (paper-search-mcp).
  > Use `read_arxiv_paper` with paper_id `<id>` when available.
  ```

### 1b. `download_arxiv` / `read_arxiv_paper` Need the Downloads Directory to Exist

`download_arxiv` and `read_arxiv_paper` **work correctly** once you have a paper ID — but they fail silently or error if the target directory doesn't exist. The server does not create it automatically.

**Fix:** Before calling either tool, ensure the directory exists:
```bash
mkdir -p docs/research/papers/downloads
```

**Tool dependency chain:**
1. `download_arxiv` downloads the PDF (needs the directory)
2. `read_arxiv_paper` calls `download_arxiv` internally, then extracts text from the PDF

If `read_arxiv_paper` returns `""` (empty string), the most likely cause is the missing directory. Create it and retry.

| Tool | Status | Notes |
|------|--------|-------|
| `search_arxiv` | **Broken** | Query ignored — returns latest papers globally |
| `download_arxiv` | Works | Needs target directory to exist first |
| `read_arxiv_paper` | Works | Needs `download_arxiv` to succeed (needs directory) |

### 2. Batch File Creation — Template Literal Escaping

When saving many papers at once, writing a Node.js script (`.mjs`) and running it via Bash is much faster than calling Write 18+ times. **But the Write tool escapes backticks in template literals**, turning `` `${var}` `` into `` \`\${var}\` ``.

**Fix:** After writing the script, always run `node --check <script.mjs>` before executing. If it fails with "Invalid or unexpected token" on a backtick line, fix the escaped backticks with:
```js
// Run from the directory containing the script
node -e "
const fs = require('fs');
let s = fs.readFileSync('<script.mjs>', 'utf8');
// Fix escaped template literals from Write tool
s = s.replace(/\\\\\`/g, '\`');
fs.writeFileSync('<script.mjs>', s);
"
```
Then re-run `node --check` to verify.

### 3. Subagents Cannot Approve MCP Tools or Write

If you try to parallelize work by launching Task agents (subagents), they **cannot prompt the user for permission**. This means subagents will be denied access to:
- All MCP tools (YouTube, paper-search, etc.)
- The Write tool
- Certain Bash commands

**Workaround:** Pull all data requiring user permission from the **main conversation** first (transcripts, search results, WebFetch calls). Then either:
- Write files directly from the main conversation, or
- Write a Node.js script and run it via Bash (which only needs one permission approval)

Subagents are fine for **read-only work** that doesn't touch MCP tools — e.g., scanning already-saved files with Grep/Read.

### 4. Newline Literals in Metadata Fields

When building markdown content in a Node.js script, if you concatenate metadata fields with `\n` inside a template literal that's already multi-line, the `\n` may end up as a literal two-character `\n` in the output file instead of an actual newline.

**Symptom:** A metadata line like:
```
- **Relevance:** Topic\n- **Referenced in:** [Video](...)
```
instead of two separate lines.

**Fix after the fact:**
```js
node -e "
const fs = require('fs');
const files = fs.readdirSync('.').filter(f => f.startsWith('2026-') && f.endsWith('.md'));
for (const f of files) {
  let c = fs.readFileSync(f, 'utf8');
  if (c.includes('\\\\n- **Referenced in:')) {
    c = c.replace('\\\\n- **Referenced in:', '\\n- **Referenced in:');
    fs.writeFileSync(f, c);
  }
}
"
```

**Prevention:** In your Node.js save script, put `Referenced in` on its own line in the template literal rather than appending it to the Relevance line with `\n`.

### 5. Some Papers Won't Be on arXiv

Not all papers referenced in video transcripts have arXiv pre-prints. Some are conference-only, journal-only, or too new. If `WebSearch` with `site:arxiv.org` returns nothing:
- Try Semantic Scholar: `WebSearch` for `"<title>" site:semanticscholar.org`
- Try the institution's publications page
- If still not found, skip it and note it in a comment — don't waste cycles hunting

---

## Tips for Future Sessions

- **arXiv is your primary source.** Most AI research from the Discover AI channel lands on arXiv first.
- **Semantic Scholar is your secondary source.** Great for finding citation networks and related work.
- **Use `read_arxiv_paper` liberally.** It extracts the full text so you can search/analyze it later.
- **Cross-reference with video transcripts.** The Discover AI videos often provide accessible explanations of dense papers — having both is powerful.
- **Check for related work.** When you find a relevant paper, search for its title on Semantic Scholar to find citing and cited papers.
- **Papers from these labs are highest priority for EmberHearth:** Anthropic, Google DeepMind, Stanford, CMU, Princeton, MIT, UC Berkeley.
- **Don't forget the downloads folder.** PDFs are saved to `docs/research/papers/downloads/` — these can be cleaned up periodically.

---

## Repeatable Prompt

Use this prompt to run a paper research sweep in any session:

```
Read docs/research/papers/PaperResearchGuide.md and follow its workflow.
Search arXiv and Semantic Scholar for recent papers (last 3 months)
matching the high-priority topics in the guide. Skip any papers that
already have files saved in that directory. For each new relevant paper,
extract the content and save it using the guide's file format and naming
convention. Also check recent video transcripts in
docs/research/youtube/discoverai/ for paper references that haven't
been captured yet.
```
