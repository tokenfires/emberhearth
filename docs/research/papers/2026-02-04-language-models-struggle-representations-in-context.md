# Language Models Struggle to Use Representations Learned In-Context

- **Paper ID:** 2602.04212
- **Authors:** Michael A. Lepori, Tal Linzen, Ann Yuan, Katja Filippova
- **Published:** February 4, 2026
- **Source:** arXiv
- **URL:** https://arxiv.org/abs/2602.04212
- **Relevance:** Context window efficiency, Few-shot adaptation
- **Referenced in:** [Google's Warning: ICL Context is Inert](../youtube/discoverai/2026-02-06-googles-warning-icl-context-is-inert.md)

## Why This Matters for EmberHearth

Critical for EmberHearth's long-conversation iMessage use case. Shows that LLMs encode novel semantics in latent representations but fail to deploy them for prediction — meaning context alone may not teach the model new patterns reliably.

## Key Findings

- Open-weights LLMs struggle to deploy representations of novel semantics defined in-context
- Models encode novel semantics in latent representations but cannot use them for next-token prediction
- Tested via a novel "adaptive world modeling" task using 2D grid topology experiments
- Even state-of-the-art closed-source reasoning models cannot reliably leverage novel in-context patterns
- Highlights fundamental limitations of in-context learning for teaching new concepts

## Full Text

> Full text extraction requires the paper-search MCP server (paper-search-mcp).
> Use `read_arxiv_paper` with paper_id `2602.04212` when available.
