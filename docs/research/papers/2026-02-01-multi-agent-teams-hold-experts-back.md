# Multi-Agent Teams Hold Experts Back

- **Paper ID:** 2602.01011
- **Authors:** Aneesh Pappu, Batu El, Hancheng Cao, Carmelo di Nolfo, Yanchao Sun, Meng Cao, James Zou
- **Published:** February 1, 2026
- **Source:** arXiv
- **URL:** https://arxiv.org/abs/2602.01011
- **Relevance:** Multi-agent architectures, Agent failure modes
- **Referenced in:** [Stanford AI Agents Destroy Their Own Intelligence](../youtube/discoverai/2026-02-09-stanford-ai-agents-destroy-their-own-intelligence.md)

## Why This Matters for EmberHearth

Critical warning for EmberHearth's multi-agent design. LLM teams consistently fail to leverage their best member's expertise (up to 37.6% performance loss). Teams default to consensus-averaging rather than weighting expertise — must be accounted for in agent orchestration.

## Key Findings

- LLM teams consistently fail to match expert agent performance, with losses up to 37.6%
- Failure stems from integrative compromise — averaging expert and non-expert views
- The problem is not identifying experts but leveraging them effectively
- Consensus behavior improves robustness against adversarial agents (trade-off)
- Suggests explicit role specification and workflow design are needed until models can autonomously leverage expertise

## Full Text

> Full text extraction requires the paper-search MCP server (paper-search-mcp).
> Use `read_arxiv_paper` with paper_id `2602.01011` when available.
