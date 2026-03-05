# Micro-Transformer Architecture
### Preliminary Design Notes — March 2026

> Status: **Brainstorming / Conceptual**
> These are early-stage architectural ideas, not a specification. Think cocktail napkin, not blueprint.

---

## Vision

Redesign transformer-based LLM architecture from the ground up using small, specialized, modular transformers ("micro-transformers") connected by dynamic eigenvector bridges. The system should be:

- **Modular** — individual micro-transformers can be added, removed, or swapped at runtime
- **Expandable** — new capabilities added without retraining the entire system
- **Trainable on consumer hardware** — small enough to train on Apple Neural Engine / M-series silicon
- **Self-organizing** — the system learns which micro-transformers to engage based on context

This is not a fine-tuning strategy or an adapter layer on top of existing models. This is a ground-up rethinking of how transformer architectures are composed.

---

## Core Components

### 1. Micro-Transformers

Small, focused transformer modules — each with its own attention mechanism, weights, and specialization. Unlike monolithic LLMs where all parameters participate in every inference, micro-transformers activate selectively.

**Key properties:**
- Self-contained: each has its own attention heads, feed-forward layers, positional encoding
- Independently trainable: can be trained in isolation, then integrated into a running system
- Swappable at runtime: the system can load/unload micro-transformers without stopping
- Variable size: not all micro-transformers need the same dimensions — some tasks need more capacity than others

**Open questions:**
- What determines the boundary of a micro-transformer's specialization? Task domain? Data type? Abstraction level?
- How small can they be while remaining useful? What's the minimum viable micro-transformer?
- How do you train one in isolation when its eventual context depends on what it's bridged to?

### 2. Eigenvector Bridges

The connective tissue between micro-transformers. Bridges translate the output representation of one micro-transformer into a compatible input representation for another.

**Key properties:**
- Learned projections between micro-transformer state spaces
- Dynamic: bridges can be created, adjusted, or replaced when micro-transformers are swapped
- Lightweight: the bridge itself should be computationally cheap relative to the micro-transformers it connects
- Bidirectional potential: information may need to flow both ways

**Why "eigenvector"?**
The bridge captures the principal dimensions of variation in each micro-transformer's representation space. Rather than mapping the full high-dimensional state, the bridge identifies and aligns the most significant directions (eigenvectors) of each space, enabling efficient low-dimensional coupling.

**Open questions:**
- Are these true eigendecompositions, or learned projections that approximate eigenvector alignment?
- How do bridges adapt when a new micro-transformer is hot-loaded into a running system?
- What happens when two micro-transformers have incompatible representation geometries?

### 3. Orchestration Engine

A controller layer that decides which micro-transformers to engage for a given input, in what order, and how to route information between them.

**Key properties:**
- Context-aware routing: examines input and decides which micro-transformers are relevant
- Dynamic loading/unloading: manages the active set of micro-transformers in memory
- Attention-weighted selection: uses attention mechanisms to determine routing weights
- Reinforcement learning: optimizes routing decisions based on task outcomes

**Design sketch:**
```
Input → Orchestrator → [selects active micro-transformers]
                     → [creates/activates bridges between them]
                     → [routes input through selected path]
                     → [collects output]
                     → Output
```

**Open questions:**
- Is the orchestrator itself a (micro-)transformer, or something simpler?
- How does it avoid becoming a bottleneck? If the orchestrator must examine every input deeply enough to route it, that's expensive.
- Does routing happen once per input, or can it re-route mid-inference as context develops?

### 4. Reinforcement Learning Integration

RL is not bolted on — it's a first-class citizen in how the system learns and adapts.

**Where RL applies:**
- **Routing policy**: which micro-transformers to activate for a given context
- **Bridge tuning**: adjusting bridge weights based on downstream task performance
- **Micro-transformer lifecycle**: deciding when a micro-transformer is underperforming and should be retrained, replaced, or retired
- **Expansion decisions**: when the system encounters inputs it handles poorly, RL signals the need for a new micro-transformer

**Key insight:** Traditional LLMs learn everything through gradient descent on next-token prediction. This architecture separates *what to know* (micro-transformer training) from *how to use what you know* (RL-driven orchestration). That separation is fundamental.

**Open questions:**
- What's the reward signal? Task completion? Perplexity reduction? User feedback?
- How do you handle credit assignment — when a chain of 5 micro-transformers produces a bad output, which one was at fault?
- Can RL operate online (learning while serving) or only offline (batch learning from logs)?

---

## Runtime Behavior

### Hot-Loading a New Micro-Transformer

```
1. System is running with micro-transformers [A, B, C] and bridges [A↔B, B↔C]
2. New micro-transformer D is introduced (pre-trained or empty)
3. Orchestrator generates provisional bridges [B↔D, C↔D] based on D's representation space
4. D enters a probationary period — receives inputs but its outputs are weighted low
5. RL tunes the bridges and routing weights based on D's actual performance
6. D either stabilizes into the active set or gets pulled back for more training
```

### Attention-Driven Routing

Rather than round-robin or static routing, the orchestrator uses attention over the available micro-transformers to decide routing:

```
1. Input arrives
2. Orchestrator computes attention scores over micro-transformer "signatures"
   (compact representations of what each micro-transformer is good at)
3. Top-k micro-transformers are activated
4. Bridges between selected micro-transformers are activated
5. Input flows through the selected subgraph
6. Output is collected and returned
```

This is conceptually similar to Mixture of Experts (MoE) gating, but at a much coarser granularity — entire transformer modules rather than individual feed-forward experts.

---

## What This Is Not

- **Mixture of Transformers (MoT)**: The closest conceptual frame. Where MoE switches between feed-forward experts *within* a single transformer, MoT composes *entire transformers* with independent attention, weights, and training histories. The eigenvector bridges are the coupling mechanism that makes this composition work. This is where the design is headed.
- **Not Mixture of Experts (MoE)**: MoE operates at the feed-forward layer level within a monolithic architecture. MoT operates at the transformer level across independently trained modules.
- **Not LoRA / Adapters**: Those are parameter-efficient fine-tuning on a frozen base model. This has no frozen base model — the entire system is composed of independently trained modules.
- **Not ensemble methods**: Ensembles run multiple models and aggregate outputs. This routes through a dynamic subgraph of interconnected modules.
- **Not a plugin system for an existing LLM**: This is the LLM. There is no monolithic model underneath.

---

## Why This Matters

The current paradigm: train one enormous model on everything, hope it generalizes. Scale by making the model bigger. This requires:
- Massive compute for training
- Massive memory for inference
- Retraining from scratch when the world changes
- No way to add capabilities without touching the entire model

The micro-transformer alternative:
- Train small modules on consumer hardware
- Add capabilities by adding modules, not retraining
- Remove or replace modules without disrupting the system
- Scale by composition, not by parameter count
- Each module can be understood, tested, and validated independently

---

## Relationship to Prior Work

- **EmberHearth eigenvector bridging research** — the earlier approach focused on bridging existing large models. The micro-transformer architecture supersedes this: if you design the modules from scratch, you don't need to reverse-engineer bridges between models that weren't built to interoperate.
- **ANE training research** — Apple Neural Engine as a training target for micro-transformers. Small enough to fit, fast enough to iterate. The M5 Max with 128GB unified memory and 40-core GPU makes this increasingly practical.
- **Taalas hardware philosophy** — interesting parallel: they build model-specific silicon. The micro-transformer approach is the software analog — build task-specific modules, compose them dynamically.

---

## Reference Implementations & Starting Points

- **LLMs from Scratch (Qwen 3.5)** — https://github.com/rasbt/LLMs-from-scratch/tree/main/ch05/16_qwen3.5 — Good code starting point for minimal transformer implementation
- **Karpathy's nanochat** — Small-transformer experimentation patterns for bridging
- **ANE (Apple Neural Engine)** — https://github.com/maderix/ANE — Transformer training on Neural Engine, 1.78 TFLOPS sustained on M4

## Next Steps (When Ready)

- [ ] Define minimum viable micro-transformer: smallest useful architecture, parameter count, training requirements
- [ ] Prototype eigenvector bridge mechanism: actual math, not scaffold code
- [ ] Design orchestrator attention mechanism: how does routing actually work?
- [ ] Explore training pipeline: how do you train a micro-transformer that will be integrated into a larger system?
- [ ] Benchmark on consumer hardware: what can an M4 Pro / M5 Max actually train in reasonable time?
- [ ] Review reference implementations (Qwen, nanochat, ANE) for practical patterns

---

*Source material: TK's brainstorming session with Taalas Chat Jimmy (hardware Llama 3.1 8B), March 2026. Original conversation archived.*
*This document captures the vision. Implementation details TBD.*
