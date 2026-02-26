# POPE: Learning to Reason on Hard Problems via Privileged On-Policy Exploration

- **Paper ID:** 2601.18779
- **Authors:** Yuxiao Qu, Amrith Setlur, Virginia Smith, Ruslan Salakhutdinov, Aviral Kumar
- **Published:** January 26, 2026
- **Source:** arXiv
- **URL:** https://arxiv.org/abs/2601.18779
- **Relevance:** Reasoning evaluation, Few-shot adaptation
- **Referenced in:** [POPE RL Curriculum Learning (CMU)](../youtube/discoverai/2026-01-30-pope-rl-curriculum-learning-cmu.md)

## Why This Matters for EmberHearth

Relevant to understanding how future Claude versions may improve reasoning. POPE uses oracle solution prefixes ("helicopter drops") to help RL explore hard problems, bypassing zero-gradient plateaus. Learned behaviors transfer back to unguided problems via instruction-following.

## Key Findings

- Standard on-policy RL fails on hard problems due to zero reward/zero gradient plateaus
- Identifies "ray interference" as barrier when mixing easy and hard problems in curriculum learning
- POPE uses oracle solution prefixes to transport agents to promising regions of state space
- Learned behaviors transfer to unguided problems through instruction-following capabilities
- Expands the set of solvable problems and improves performance on challenging reasoning benchmarks

## Full Text

> Full text extraction requires the paper-search MCP server (paper-search-mcp).
> Use `read_arxiv_paper` with paper_id `2601.18779` when available.
