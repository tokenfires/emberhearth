# Local Model Feasibility Research

**Status:** Not Started  
**Priority:** High (Phase 1)

---

## Research Goal

Determine if local models can handle assistant tasks acceptably on consumer Mac hardware.

---

## Research Questions

- [ ] What models run well on Apple Silicon (M1/M2/M4)?
- [ ] MLX vs llama.cpp vs Ollama — which performs best?
- [ ] What's the latency for a typical assistant query?
- [ ] Can a Mac Mini M2 (base, 8GB) run useful models?
- [ ] What about Mac Mini M2 Pro (16GB/32GB)?
- [ ] What quantization levels (4-bit, 8-bit) are practical?
- [ ] Which model families work best for assistant tasks?

---

## Models to Evaluate

| Model | Size | Quantization | RAM Required | Notes |
|-------|------|--------------|--------------|-------|
| Llama 3.2 3B | 3B | Q4 | ? | |
| Llama 3.1 8B | 8B | Q4 | ? | |
| Mistral 7B | 7B | Q4 | ? | |
| Phi-3 | 3.8B | Q4 | ? | |
| Gemma 2 | 9B | Q4 | ? | |

---

## Benchmarks

*To be documented as testing progresses.*

### Test Queries
1. Simple question: "What's on my calendar tomorrow?"
2. Research: "Find articles about sourdough bread making"
3. Reasoning: "Should I schedule this meeting before or after lunch given..."
4. Memory recall: "What did I say about the project last week?"

### Metrics to Capture
- Time to first token
- Total response time
- Quality of response (subjective)
- Memory usage during inference
- Thermal/fan behavior

---

## Findings

*To be documented as research progresses.*

---

## Recommendation

*To be added after research is complete.*
