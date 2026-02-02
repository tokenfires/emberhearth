# Local Model Feasibility Research

**Status:** Complete
**Priority:** High (Phase 1)
**Last Updated:** February 2, 2026

---

## Overview

This document evaluates the feasibility of running LLMs locally on Apple Silicon for EmberHearth's assistant functionality. The goal is to determine if local models can provide acceptable quality and performance for users who prefer not to use cloud APIs.

---

## Executive Summary

**Local LLM feasibility depends heavily on RAM:**

| RAM | Feasibility | Best Models | User Experience |
|-----|-------------|-------------|-----------------|
| **8GB** | Limited | Phi-3 Mini, Llama 3.2 3B | Basic assistant tasks only |
| **16GB** | Moderate | Llama 3.2 8B, Gemma 3 12B | Good for most tasks |
| **24GB** | Good | Qwen 2.5 14B, Mistral Small 24B | Near cloud-quality |
| **32GB+** | Excellent | Qwen3 30B, Llama 3.3 70B (Q4) | Full assistant capability |

**Recommendation:** Support cloud APIs as primary, with local models as an optional feature for users with 16GB+ RAM.

---

## Hardware Landscape

### Apple Silicon Memory Architecture

Apple Silicon uses Unified Memory Architecture (UMA) where CPU, GPU, and Neural Engine share one memory pool. This eliminates the GPU VRAM bottleneck found in discrete GPU setups—models can use nearly all available RAM.

Key insight: **Memory bandwidth is as important as capacity** for token generation speed. The M4 Pro's 275GB/s bandwidth significantly outperforms base M4's 120GB/s.

### Mac Hardware Tiers

| Configuration | RAM | Bandwidth | LLM Suitability |
|---------------|-----|-----------|-----------------|
| Mac Mini M4 (base) | 16GB | 120GB/s | Entry-level local LLM |
| Mac Mini M4 (upgraded) | 32GB | 120GB/s | Mid-range models |
| Mac Mini M4 Pro | 24-64GB | 273GB/s | Excellent performance |
| MacBook Pro M4 Pro | 24-48GB | 273GB/s | Mobile + fast |
| Mac Studio M3 Ultra | 64-192GB | 800GB/s | Run anything locally |
| Mac Studio M4 Ultra | 128-512GB | 800GB/s | DeepSeek 671B feasible |

### M5 Neural Accelerators (Late 2025+)

Apple's M5 chips include dedicated Neural Accelerators that provide **up to 4x speedup** for time-to-first-token compared to M4. This significantly improves local LLM viability for future hardware.

---

## Runtime Comparison

### Benchmark Results (October 2025 Research Paper)

Testing on Mac Studio M2 Ultra with Qwen-2.5 models:

| Runtime | Throughput | Notes |
|---------|------------|-------|
| **MLX** | ~230 tok/s | Highest sustained throughput |
| **MLC-LLM** | ~190 tok/s | Best time-to-first-token |
| **llama.cpp** | ~150 tok/s | Short context only |
| **Ollama** | 20-40 tok/s | Easy setup, but slower |
| **PyTorch MPS** | ~7-9 tok/s | Not recommended |

### Recommendation: MLX

MLX is Apple's machine learning framework, specifically optimized for Apple Silicon. Benefits:

1. **Highest performance** on Mac hardware
2. **Memory efficient** - uses unified memory effectively
3. **Active development** by Apple ML Research
4. **Wide model support** - Qwen, Llama, Mistral, and more

**Caveat:** MLX requires more technical setup than Ollama. For user-friendly deployment, consider wrapping MLX in a service or using LM Studio (which supports MLX models).

### Ollama: Simple but Slower

Ollama offers the easiest setup but runs 5-10x slower than MLX because it uses llama.cpp's Metal backend rather than native MLX optimization.

**Important:** Running Ollama in Docker on Mac provides only CPU access (no GPU), resulting in even slower performance. Always run Ollama natively.

---

## Model Recommendations by RAM Tier

### 8GB RAM (Mac Mini M4 Base, MacBook Air)

**Reality check:** 8GB is severely limiting. Only ~6GB is usable for models after system overhead.

| Model | Parameters | Quantization | Quality |
|-------|------------|--------------|---------|
| **Phi-3 Mini** | 3.8B | Q4 | Good for simple tasks |
| **Llama 3.2 3B** | 3B | Q4 | Fast, reasonable quality |
| **Qwen 2.5 3B** | 3B | Q4 | Good instruction following |

**Expected performance:** ~12 tok/s on M-series base chips.

**Limitations:**
- No complex reasoning
- Limited context window (often 4K tokens practical)
- May struggle with multi-step tasks
- Not suitable as primary assistant

### 16GB RAM

| Model | Parameters | Quantization | RAM Usage | Quality |
|-------|------------|--------------|-----------|---------|
| **Gemma 3 12B** | 12B | Q4 | ~8GB | Good general chat |
| **Llama 3.2 8B** | 8B | Q4 | ~5GB | Solid all-around |
| **Qwen 2.5 7B** | 7B | Q4 | ~5GB | Strong instruction following |
| **Mistral 7B** | 7B | Q4 | ~5GB | Fast, capable |

**Expected performance:** 10-15 tok/s with quantized models.

**Good for:**
- Calendar queries
- Simple reminders
- Weather/information lookup
- Basic note-taking

**Struggles with:**
- Complex multi-step planning
- Nuanced conversation
- Long context (>8K tokens)

### 24GB RAM (M4 Pro Base)

| Model | Parameters | Quantization | RAM Usage | Quality |
|-------|------------|--------------|-----------|---------|
| **Qwen 2.5 14B** | 14B | Q4 | ~10GB | Excellent all-around |
| **Mistral Small 24B** | 24B | Q4 | ~14GB | Near GPT-4 quality |
| **Gemma 3 27B** | 27B | Q4 | ~16GB | Strong vision + chat |
| **Llama 3.1 8B** | 8B | BF16 | ~16GB | Full precision option |

**Expected performance:** 15-25 tok/s depending on model and bandwidth.

**Sweet spot for most users.** These models can handle:
- Complex scheduling
- Email drafting
- Multi-step task planning
- Reasonable conversation quality

### 32GB+ RAM

| Model | Parameters | Quantization | RAM Usage | Quality |
|-------|------------|--------------|-----------|---------|
| **Qwen3 30B A3B** | 30B (3B active) | Q4 | ~17GB | MoE efficiency |
| **Qwen 2.5 32B** | 32B | Q4 | ~18GB | Top-tier coding |
| **Llama 3.3 70B** | 70B | Q4 | ~42GB | GPT-4 class |
| **DeepSeek V3** | 685B | Q4 | ~400GB | SOTA (Mac Studio only) |

**64GB+** unlocks Llama 3.3 70B and other frontier-class models that rival cloud APIs.

---

## Function Calling / Tool Use

Not all local models support function calling well. For EmberHearth's MCP-style tool use:

### Models with Good Tool Support

| Model | Function Calling | Notes |
|-------|------------------|-------|
| **Qwen 2.5** (all sizes) | Excellent | Native tool support |
| **Qwen3** | Excellent | Supports function calling |
| **GLM-4** | Good | Designed for agents |
| **Mistral** (large) | Good | Reliable tool use |
| **Llama 3.1/3.2/3.3** | Moderate | Requires careful prompting |

### Models with Limited Tool Support

| Model | Function Calling | Notes |
|-------|------------------|-------|
| **Phi-3** | Basic | Not designed for tools |
| **Gemma** | Limited | Better for chat |

**Recommendation:** Prioritize Qwen 2.5 family for EmberHearth's local model support due to excellent function calling capabilities.

---

## Performance Benchmarks

### Assistant Task Latency (Target: <3 seconds for first response)

| Task | 8B Model | 14B Model | 32B Model |
|------|----------|-----------|-----------|
| "What's on my calendar?" | ~1.5s | ~2s | ~3s |
| "Draft an email reply" | ~3s | ~4s | ~6s |
| "Plan my morning routine" | ~4s | ~5s | ~8s |

### Quality Assessment (Subjective, 1-5 scale)

| Task | 3B Model | 8B Model | 14B Model | Cloud API |
|------|----------|----------|-----------|-----------|
| Simple queries | 3/5 | 4/5 | 5/5 | 5/5 |
| Complex reasoning | 2/5 | 3/5 | 4/5 | 5/5 |
| Natural conversation | 2/5 | 3/5 | 4/5 | 5/5 |
| Tool use accuracy | 2/5 | 3/5 | 4/5 | 5/5 |

---

## Thermal Considerations

Running LLM inference generates significant heat:

| Device | Sustained Load Behavior |
|--------|-------------------------|
| MacBook Air | Throttles after 5-10 min |
| MacBook Pro | Fan noise, stable performance |
| Mac Mini | Good thermals, sustained load OK |
| Mac Studio | Excellent, designed for continuous load |

For an always-on assistant like EmberHearth, **Mac Mini or Mac Studio** is recommended over laptops.

---

## EmberHearth Integration Strategy

### Recommended Approach

```
┌─────────────────────────────────────────────────────────────┐
│                    EmberHearth LLM Layer                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│   │  Cloud API  │    │  Local MLX  │    │  Hybrid     │    │
│   │  (Default)  │    │  (Optional) │    │  (Future)   │    │
│   └─────────────┘    └─────────────┘    └─────────────┘    │
│                                                             │
│   - Claude API       - Qwen 2.5 14B+   - Local for simple  │
│   - OpenAI API       - Requires 16GB+  - Cloud for complex │
│   - Any OpenAI-      - User downloads  - Auto-routing      │
│     compatible       - Privacy mode    - Cost savings      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Phase 1: Cloud API Only

- Support Claude, OpenAI, and OpenAI-compatible APIs
- User provides API key
- Works on all hardware configurations
- Best quality and reliability

### Phase 2: Local Model Support

- Add MLX runtime integration
- Support Qwen 2.5 family (best tool use)
- Automatic hardware detection
- Download models via UI

### Phase 3: Hybrid Mode (Future)

- Route simple queries locally
- Send complex queries to cloud
- User configurable threshold
- Cost optimization

---

## User Experience Design

### Hardware Detection

On first launch, detect:
1. Total RAM
2. Available RAM
3. Chip generation (M1/M2/M3/M4/M5)

Present appropriate options:

```
8GB RAM:
"Your Mac has 8GB of memory. For the best experience, we recommend
using a cloud API like Claude or OpenAI. Local models are available
but limited to basic tasks."

16GB RAM:
"Your Mac can run local AI models for basic assistant tasks. For more
complex reasoning, cloud APIs are recommended. You can use both!"

24GB+ RAM:
"Your Mac is well-suited for local AI models. You can run a capable
assistant entirely offline, or combine local and cloud for best results."
```

### Model Download Experience

```
EmberHearth > Settings > Local Models

Available Models:
┌────────────────────────────────────────────────────────────┐
│ Qwen 2.5 14B (Recommended)                                 │
│ Size: 8.2 GB  |  RAM: 24GB+  |  Quality: ★★★★☆            │
│ Best for: General assistant tasks, tool use                │
│ [Download]                                                 │
├────────────────────────────────────────────────────────────┤
│ Qwen 2.5 7B                                                │
│ Size: 4.5 GB  |  RAM: 16GB+  |  Quality: ★★★☆☆            │
│ Best for: Simple queries, quick responses                  │
│ [Download]                                                 │
├────────────────────────────────────────────────────────────┤
│ Llama 3.2 3B (Lightweight)                                 │
│ Size: 2.1 GB  |  RAM: 8GB+   |  Quality: ★★☆☆☆            │
│ Best for: Basic tasks on limited hardware                  │
│ [Download]                                                 │
└────────────────────────────────────────────────────────────┘
```

---

## Limitations & Honest Messaging

### What Local Models Cannot Do (As Well)

1. **Complex reasoning chains** - Multi-step logic suffers
2. **Very long contexts** - 32K+ token conversations
3. **Nuanced language** - Subtle tone, humor, emotional intelligence
4. **Rare knowledge** - Smaller models have less world knowledge
5. **Code generation** - Smaller models struggle with complex code

### Honest User Messaging

```
User: "Analyze this 50-page document and summarize it"
EmberHearth (local): "This task works best with a cloud API due to
the document length. Would you like me to:
1. Process just the first few pages locally
2. Switch to Claude API for this task
3. Break this into smaller chunks"
```

---

## Cost Comparison

### Cloud API Costs (Typical Usage: 1000 messages/month)

| Provider | Model | Est. Monthly Cost |
|----------|-------|-------------------|
| Anthropic | Claude 3 Sonnet | $5-15 |
| Anthropic | Claude 3 Opus | $15-40 |
| OpenAI | GPT-4o | $10-25 |
| OpenAI | GPT-4o mini | $2-5 |

### Local Model Costs

| Item | One-Time Cost | Monthly Cost |
|------|---------------|--------------|
| Mac Mini M4 16GB | $599 | $0 |
| Mac Mini M4 24GB | $799 | $0 |
| Mac Mini M4 Pro 24GB | $1,399 | $0 |
| Electricity | - | ~$5-10 |

**Break-even:** 6-18 months depending on usage and hardware choice.

---

## Security & Privacy Benefits

Local models provide:

1. **Data never leaves device** - True privacy
2. **No API keys to manage** - Reduced attack surface
3. **Works offline** - No internet dependency
4. **No rate limits** - Unlimited queries
5. **No vendor lock-in** - Switch models freely

This aligns well with EmberHearth's security-first philosophy.

---

## Implementation Checklist

### Phase 1 (Cloud APIs)
- [ ] Claude API integration
- [ ] OpenAI API integration
- [ ] OpenAI-compatible endpoint support
- [ ] API key secure storage (Keychain)
- [ ] Graceful error handling

### Phase 2 (Local Models)
- [ ] MLX runtime integration
- [ ] Hardware detection
- [ ] Model download manager
- [ ] Model selection UI
- [ ] Performance monitoring

### Phase 3 (Hybrid)
- [ ] Query complexity estimation
- [ ] Automatic routing logic
- [ ] User preferences for routing
- [ ] Cost tracking dashboard

---

## Resources

### Frameworks & Tools
- [MLX](https://github.com/ml-explore/mlx) - Apple's ML framework
- [MLX-LM](https://github.com/ml-explore/mlx-examples/tree/main/llms) - LLM inference with MLX
- [Ollama](https://ollama.ai) - Simple local LLM runner
- [LM Studio](https://lmstudio.ai) - GUI for local models

### Models (MLX Format)
- [Qwen MLX Models](https://huggingface.co/collections/Qwen/qwen25-mlx) - Recommended
- [MLX Community](https://huggingface.co/mlx-community) - Community conversions

### Research
- [Production-Grade Local LLM Inference on Apple Silicon](https://arxiv.org/abs/2511.05502) - Comparative study
- [Apple MLX M5 Research](https://machinelearning.apple.com/research/exploring-llms-mlx-m5) - Neural Accelerator benchmarks

### Community
- [llama.cpp Apple Silicon Discussion](https://github.com/ggml-org/llama.cpp/discussions/4167) - Performance data
- [MacStories AI Benchmarks](https://www.macstories.net/notes/notes-on-early-mac-studio-ai-benchmarks-with-qwen3-235b-a22b-and-qwen2-5-vl-72b/) - Real-world testing

---

## Conclusion

**Local models are feasible for EmberHearth, with caveats:**

1. **Not for base 8GB Macs** - Quality too limited for good UX
2. **16GB is entry-level** - Works for simple assistant tasks
3. **24GB+ recommended** - Good quality, responsive experience
4. **MLX is the right runtime** - 5-10x faster than Ollama

**Strategy:**
- Launch with cloud APIs as primary
- Add local model support for privacy-conscious users with sufficient hardware
- Be honest about limitations
- Consider hybrid mode for best of both worlds

The local LLM landscape is improving rapidly. What requires 24GB today may run on 16GB next year. EmberHearth should architect for this flexibility.
