# Model Whisper: Steering Vectors Unlock Large Language Models' Potential in Test-time

- **Paper ID:** 2512.04748
- **Authors:** Xinyue Kang, Diwei Shi, Li Chen
- **Published:** December 4, 2025
- **Source:** arXiv
- **URL:** https://arxiv.org/abs/2512.04748
- **Relevance:** Few-shot adaptation
- **Referenced in:** [POPE RL Curriculum Learning (CMU)](../youtube/discoverai/2026-01-30-pope-rl-curriculum-learning-cmu.md)

## Why This Matters for EmberHearth

Relevant to EmberHearth's test-time adaptation strategy. Test-Time Steering Vectors (TTSV) achieve up to 45.88% relative performance gains by minimizing output entropy — steering the model toward higher-confidence internal states without parameter changes. Accepted to AAAI 2026.

## Key Findings

- Introduces Test-Time Steering Vectors (TTSV) — lightweight, optimizable vectors prepended to input
- Keeps LLM parameters entirely frozen while steering toward task-relevant internal states
- 45.88% relative performance gain on Qwen2.5-Math-7B (MATH500 benchmark)
- Steering vectors demonstrate transferability across different tasks
- Optimizes by minimizing model output entropy on test data

## Full Text

> Full text extraction requires the paper-search MCP server (paper-search-mcp).
> Use `read_arxiv_paper` with paper_id `2512.04748` when available.
