# The Quantization Trap: Breaking Linear Scaling Laws in Multi-Hop Reasoning

- **Paper ID:** 2602.13595
- **Authors:** Henry Han, Xiyang Liu, Xiaodong Wang, Fei Han, Xiaodong Li
- **Published:** February 14, 2026
- **Source:** arXiv
- **URL:** https://arxiv.org/abs/2602.13595
- **Relevance:** Quantization & compression, On-device / local LLMs
- **Referenced in:** [Quantization Breaks 4-bit AI Models](../youtube/discoverai/2026-02-18-quantization-breaks-4bit-ai-models.md)

## Why This Matters for EmberHearth

Critical for EmberHearth's offline fallback strategy. Reveals that reducing precision from 16-bit to 4/8-bit paradoxically increases energy consumption while degrading multi-hop reasoning accuracy — the "smaller-is-better" heuristic fails for complex reasoning tasks.

## Key Findings

- Identifies a "quantization trap" where lower precision increases net energy consumption
- Multi-hop reasoning accuracy degrades non-linearly with quantization
- Hardware casting overhead and dequantization kernel latency become dominant bottlenecks
- Sequential reasoning chains are especially vulnerable to precision reduction
- Challenges the "smaller-is-better" heuristic for complex reasoning tasks on edge devices

## Full Text

> Full text extraction requires the paper-search MCP server (paper-search-mcp).
> Use `read_arxiv_paper` with paper_id `2602.13595` when available.
