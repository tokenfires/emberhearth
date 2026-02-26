# Defense Against Indirect Prompt Injection via Tool Result Parsing

- **Paper ID:** 2601.04795
- **Authors:** Qiang Yu, Xinran Cheng, Chuanyi Liu
- **Published:** January 8, 2026
- **Source:** arXiv
- **URL:** https://arxiv.org/abs/2601.04795
- **Relevance:** Prompt injection defense

## Why This Matters for EmberHearth

Directly relevant to EmberHearth's Tron security layer. Proposes tool result parsing to filter malicious instructions embedded in tool call results — achieving the lowest attack success rate (ASR) while maintaining system utility. Critical as EmberHearth agents will use external tools.

## Key Findings

- Addresses attacks that embed adversarial instructions in tool call results
- Proposes tool result parsing to provide precise data while filtering injected code
- Achieves competitive utility with lowest Attack Success Rate (ASR) to date
- Targets the growing risk as agents gain direct control over physical environments
- More lightweight than training dedicated detection models, avoiding frequent update requirements

## Full Text

> Full text extraction requires the paper-search MCP server (paper-search-mcp).
> Use `read_arxiv_paper` with paper_id `2601.04795` when available.
