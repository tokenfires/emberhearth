# ASV Neurochemical Validation

**Purpose:** Validate the Affective State Vector (ASV) design against neuroscience research
**Date:** February 4, 2026
**Status:** Research Complete (with Open Questions)

---

## Executive Summary

The ASV's 7-axis emotional model is **well-grounded in neuroscience**. All seven axes have neurochemical support, though the temporal axis connection was discovered late in research via dopamine's role in temporal processing.

**Key Finding:** Dopamine modulates not just reward/interest but also **time perception itself**. ADHD research demonstrates this clearly—dopamine dysregulation causes "time blindness," and medication that restores dopamine balance also normalizes time perception.

**Recommendation:** Proceed with current ASV design. Flag temporal axis for potential future refinement as research evolves.

**Open Questions:** See "Open Research Questions" section below.

---

## The ASV Axes (Reminder)

```
ASV = [
    anger_acceptance,      // -1.0 (anger) to +1.0 (acceptance)
    fear_trust,            // -1.0 (fear) to +1.0 (trust)
    despair_hope,          // -1.0 (despair) to +1.0 (hope/joy)
    boredom_interest,      // -1.0 (boredom) to +1.0 (interest)
    temporal,              // -1.0 (past) to +1.0 (future)
    valence,               // -1.0 (negative) to +1.0 (positive)
    intensity              // 0.0 (absent) to 1.0 (fully attentive)
]
```

---

## Relevant Neurochemical Systems

### 1. Serotonin (5-HT)

**Key Functions:**
- Mood regulation
- Impulse control
- Aggression modulation
- Prefrontal-amygdala communication

**Research Findings:**
- Low serotonin strongly correlates with **aggression and anger**
- Serotonin regulates communication between prefrontal cortex (rational control) and amygdala (emotional response)
- Selective serotonin reuptake inhibitors (SSRIs) reduce aggression and irritability
- In the Lövheim Cube model, low serotonin contributes to anger/rage, fear/terror, distress/anguish, and shame

**ASV Mapping:** Directly supports the **anger↔acceptance** axis

---

### 2. Dopamine (DA)

**Key Functions:**
- Reward anticipation (NOT reward itself)
- Motivation and drive
- Interest and curiosity
- Goal-directed behavior

**Research Findings:**
- Dopamine neurons fire on **anticipation** of reward, not on receiving it
- The "wanting" system rather than "liking" system
- Low dopamine → anhedonia (inability to feel pleasure), apathy
- High dopamine → motivation, interest, engagement
- In Lövheim Cube: high dopamine + high norepinephrine = **Interest/Excitement**

**ASV Mapping:** Supports both **boredom↔interest** and **despair↔hope** axes
- Boredom correlates with low dopamine/motivation
- Hope involves anticipation of positive future outcomes

---

### 3. Norepinephrine / Noradrenaline (NE)

**Key Functions:**
- Arousal and alertness
- Attention and vigilance
- Stress response (fight-or-flight)
- Memory formation under emotional conditions

**Research Findings:**
- NE release is lowest during sleep, rises during wakefulness, peaks during stress/danger
- The locus coeruleus-NE system has "robust wake-promoting actions"
- NE "ignites local hotspots of neuronal excitation" enhancing selective attention
- Creates a few hotspots of excitation in context of widespread suppression
- Tracks "emotional modulation of attention" in the amygdala

**ASV Mapping:** Directly supports the **intensity** axis (arousal/attention level)

---

### 4. Oxytocin (OT)

**Key Functions:**
- Social bonding
- Trust formation
- Empathy and attachment
- Reduction of social fear

**Research Findings:**
- Known as the "trust hormone" or "love hormone"
- Intranasal oxytocin **increases trust** in humans, especially those with low baseline trust
- Modulates amygdala activity (reduces fear response to social stimuli)
- Facilitates social bonding, attachment behaviors
- Promotes cooperation in social networks by:
  1. Increasing individual cooperation
  2. Fostering interpersonal bonding
  3. Facilitating heterogeneous network formation
- Decreases willingness to harm others by promoting guilt and shame

**ASV Mapping:** Directly supports the **fear↔trust** axis

---

### 5. Cortisol

**Key Functions:**
- Stress response hormone
- Fear and threat processing
- Energy metabolism coordination
- Emotional regulation (paradoxically)

**Research Findings:**
- Cortisol strengthens amygdala signaling during fear (in men)
- Released via HPA axis when amygdala perceives danger
- High chronic cortisol → hippocampal atrophy, memory deficits
- However: cortisol also **improves downregulation of negative emotions**
- Cortisol "buffers increases of negative affect" and "reduces phobic fear"
- Complex dual role: acute stress response AND emotional regulation

**ASV Mapping:** Supports the **fear↔trust** axis (fear side) and influences **intensity**

---

## Validation Against Established Models

### Lövheim Cube of Emotions

Hugo Lövheim's (2012) model maps three neurochemicals to eight basic emotions:

| Serotonin | Dopamine | Noradrenaline | Resulting Emotion |
|-----------|----------|---------------|-------------------|
| High | High | High | Interest/Excitement |
| High | High | Low | Enjoyment/Joy |
| High | Low | High | Surprise |
| High | Low | Low | Contempt/Disgust |
| Low | High | High | **Anger/Rage** |
| Low | High | Low | **Fear/Terror** |
| Low | Low | High | Distress/Anguish |
| Low | Low | Low | Shame/Humiliation |

**ASV Alignment:**
- anger_acceptance: Maps to Serotonin (low S → anger) ✅
- fear_trust: Maps to Low S + Low N combinations ✅
- boredom_interest: Maps to High D + High N = Interest ✅

---

### Russell's Circumplex Model of Affect

James Russell's (1980) model uses two orthogonal dimensions:

```
                    Arousal (activated)
                           ↑
                    excited │ tense
                            │
Valence (pleasant) ─────────┼───────── Valence (unpleasant)
                            │
                      calm  │ sad
                           ↓
                    Arousal (deactivated)
```

This model has been **empirically validated for 40+ years** across cultures.

**ASV Alignment:**
- valence axis: Directly matches Russell's valence dimension ✅
- intensity axis: Directly matches Russell's arousal dimension ✅

---

## Axis-by-Axis Validation

| ASV Axis | Neurochemical Basis | Validation Strength | Notes |
|----------|---------------------|---------------------|-------|
| **anger↔acceptance** | Serotonin (low = anger) | ✅ Strong | Lövheim Cube: low serotonin → anger/rage |
| **fear↔trust** | Oxytocin (trust), Cortisol/NE (fear) | ✅ Strong | Oxytocin increases trust; cortisol/NE mediate fear response |
| **despair↔hope** | Dopamine (anticipation) | ✅ Moderate | Dopamine drives anticipation of future rewards; low DA → anhedonia |
| **boredom↔interest** | Dopamine + Norepinephrine | ✅ Strong | Lövheim: high DA + high NE = Interest/Excitement |
| **temporal** | Dopamine (time perception) | ✅ Moderate | Dopamine modulates temporal processing; ADHD time blindness demonstrates this |
| **valence** | Russell's validated dimension | ✅ Strong | Core dimension in affect research for 40+ years |
| **intensity** | Norepinephrine (arousal) | ✅ Strong | NE is primary arousal/attention modulator |

---

## The Temporal Axis — Revisited

Initial analysis categorized the temporal axis as "cognitive, not neurochemical." Further research revealed this was incorrect.

### Dopamine and Time Perception

Research shows dopamine **directly modulates temporal processing**:

- **Basal ganglia and striatum:** Time perception (hundreds of ms to seconds) depends on dopaminergic pathways
- **Prefrontal cortex:** Time estimation is associated with dopaminergic signaling
- **Optogenetic studies:** Stimulating/inhibiting dopamine neurons makes mice behave as if time moves faster or slower
- **Human studies:** Fast phasic dopamine signals → underestimation of time intervals; slow tonic dopamine decreases → poorer temporal precision

### ADHD as Evidence

ADHD provides strong evidence for dopamine-temporal connection:

- **Time blindness** affects up to 90% of people with ADHD
- ADHD involves dopamine dysregulation in prefrontal cortex and striatum
- When ADHD medication restores dopamine balance, "time clicks into place"
- Research: "Temporal processing differences [are] a core ADHD feature related to dopaminergic dysfunction"

### Implications for ASV

The temporal axis may **partially overlap** with dopamine-driven axes (despair↔hope, boredom↔interest):

- Future-orientation correlates with dopamine-driven anticipation
- Past-rumination may correlate with low dopamine states

**Open Question:** Is temporal orientation (past↔future) capturing something distinct from hope/interest, or is it redundant? This warrants future analysis of ASV data to detect correlation patterns.

**Current Recommendation:** Keep the temporal axis. Even if partially correlated with other axes, the explicit past/future framing provides useful semantic context for an AI assistant.

---

## Additional Neurochemical Systems

Beyond the primary monoamines, several other systems influence emotional processing:

### Endocannabinoid System (ECS)

- Acts as a "regulatory buffer system for emotional responses"
- Ensures appropriate reaction to stressful events
- CB1 receptors on glutamatergic terminals → anxiolysis
- CB1 receptors on GABAergic terminals → can facilitate anxiety
- Critical for fear extinction learning

**ASV Relevance:** May influence the *stability* of emotional states rather than specific axes.

### Neuropeptides

| Neuropeptide | Function | Notes |
|--------------|----------|-------|
| **Orexin** | Arousal, wakefulness, reward-seeking | Maximal during positive emotion, anger; minimal during sleep |
| **Substance P** | Stress, pain, mood | Modulates monoamine nuclei (NE, DA, 5-HT) |
| **NPY** | Anxiety regulation | Bidirectional effects on arousal |
| **Neuropeptide S** | Stress and arousal modulation | Interacts with orexin system |

**ASV Relevance:** These likely act as modulators of the primary axes rather than representing distinct dimensions.

### The Neurochemical Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 1: Substrate                                             │
│  Glutamate (excitatory) ←→ GABA (inhibitory)                   │
│  Base signal propagation                                        │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 2: Monoamine Modulators (Lövheim Trio)                   │
│  Serotonin · Dopamine · Norepinephrine                          │
│  Tune emotional/cognitive state                                 │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 3: Social/Stress Hormones                                │
│  Oxytocin (bonding) · Cortisol (threat)                         │
│  Handle social and stress contexts                              │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 4: Buffer Systems                                        │
│  Endocannabinoid system                                         │
│  Emotional response regulation/stability                        │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 5: Neuropeptide Fine-Tuning                              │
│  Orexin · Substance P · NPY · etc.                              │
│  Context-specific modulation                                    │
└─────────────────────────────────────────────────────────────────┘
```

The ASV primarily captures Layers 2-3, which is appropriate for a practical emotional model.

---

## Open Research Questions

These questions are flagged for future investigation as ASV data accumulates:

### 1. Temporal Axis Redundancy

**Question:** Is the temporal axis (past↔future) capturing something distinct, or is it highly correlated with despair↔hope and boredom↔interest?

**Why it matters:** If temporal is redundant, it could be collapsed into existing axes. If distinct, it validates keeping 7 dimensions.

**How to investigate:** Analyze stored ASV data for correlation patterns between temporal and other dopamine-influenced axes.

### 2. Intensity vs Valence Interaction

**Question:** Should intensity modulate the other axes multiplicatively, or remain independent?

**Neurochemical basis:** Norepinephrine (intensity) "ignites local hotspots" and amplifies selective attention. This suggests intensity might *amplify* other emotional states rather than exist independently.

**Current approach:** Treat as independent for simplicity. Revisit if word translations feel off.

### 3. Missing Dimensions?

**Question:** Are there emotional dimensions the ASV fails to capture?

**Candidates:**
- **Social context** (alone ↔ connected) — Oxytocin partially captures this
- **Agency** (helpless ↔ in-control) — May correlate with hope/fear
- **Cognitive load** (overwhelmed ↔ clear) — Practical for AI but may not be "emotional"

**Current stance:** The 7-axis model is sufficient. Resist adding dimensions without strong evidence of gaps.

### 4. Individual Baseline Variance

**Question:** Do different people have different "resting" ASV states, and should Ember track per-person baselines?

**Neurochemical basis:** Genetic variations affect monoamine transporter density, meaning people have different baseline neurochemical states.

**Implication for ASV:** What feels like 0.0 (neutral) for one person might be +0.3 for another. Ember may need to learn individual baselines over time.

---

## Conclusions

### The ASV Design Is Well-Grounded

The ASV maps remarkably well to established neuroscience:

1. **Two axes map directly to Russell's Circumplex** (valence, arousal/intensity) — the most validated model in affect research
2. **Five axes map to specific neurochemical systems**:
   - Serotonin → anger↔acceptance
   - Oxytocin → fear↔trust
   - Dopamine → despair↔hope, boredom↔interest, temporal
   - Norepinephrine → intensity
3. **The temporal axis has stronger neurochemical grounding than initially thought** — dopamine directly modulates time perception

### No Design Changes Needed (Currently)

The original ASV design anticipated the neurochemical basis well. The axes are:
- Grounded in real neuroscience
- Practical for AI assistant use cases
- Flexible enough to accommodate future refinements

**However:** Flag the open research questions above for future analysis once ASV data accumulates.

### Implementation Note

The LLM-based word translation approach is elegant because:
1. It avoids hardcoding emotion↔word mappings
2. It leverages the LLM's training on human emotional language
3. It allows the system to express subtle gradations (e.g., "62% between joy and despair")
4. It's culture/language agnostic — the LLM handles localization

---

## Sources

### Lövheim Cube
- Lövheim, H. (2012). A new three-dimensional model for emotions and monoamine neurotransmitters. Medical Hypotheses, 78(2), 341-348.

### Russell's Circumplex
- Russell, J. A. (1980). A circumplex model of affect. Journal of Personality and Social Psychology, 39(6), 1161-1178.

### Serotonin and Aggression
- [The role of serotonin in aggression and impulsivity](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4508627/)

### Dopamine and Reward
- [Neuroscience of reward, motivation, and drive](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4491543/)

### Oxytocin and Trust
- [Oxytocin increases trust in humans - Nature](https://www.nature.com/articles/nature03701)
- [Oxytocin in Human Social Network Cooperation](https://journals.sagepub.com/doi/10.1177/10738584241293366)
- [Neurobiological impact of oxytocin in mental health disorders](https://pmc.ncbi.nlm.nih.gov/articles/PMC11981257/)

### Norepinephrine and Arousal
- [The Locus Coeruleus-Norepinephrine System in Stress and Arousal](https://www.frontiersin.org/journals/psychiatry/articles/10.3389/fpsyt.2020.601519/full)
- [Norepinephrine ignites local hotspots of neuronal excitation](https://www.cambridge.org/core/journals/behavioral-and-brain-sciences/article/norepinephrine-ignites-local-hotspots-of-neuronal-excitation-how-arousal-amplifies-selectivity-in-perception-and-memory/A1750B4C91812D0CC7F6D42872DC05AD)

### Cortisol and Stress
- [Cortisol increases the return of fear by strengthening amygdala signaling](https://pubmed.ncbi.nlm.nih.gov/29529523/)
- [Understanding the stress response - Harvard Health](https://www.health.harvard.edu/staying-healthy/understanding-the-stress-response)

### Dopamine and Temporal Processing
- [Dopamine and the interdependency of time perception and reward](https://pmc.ncbi.nlm.nih.gov/articles/PMC9062982/)
- [Dopamine, time perception, and future time perspective](https://pmc.ncbi.nlm.nih.gov/articles/PMC6182591/)
- [Dopamine Cells Influence Our Perception of Time - Simons Foundation](https://www.simonsfoundation.org/2017/01/20/dopamine-cells-influence-our-perception-of-time/)
- [Sub-second and multi-second dopamine dynamics underlie variability in human time perception](https://www.medrxiv.org/content/10.1101/2024.02.09.24302276v1)

### ADHD and Time Blindness
- [Clinical Implications of the Perception of Time in ADHD](https://pmc.ncbi.nlm.nih.gov/articles/PMC6556068/)
- [Time Perception is a Focal Symptom of ADHD in Adults](https://pmc.ncbi.nlm.nih.gov/articles/PMC8293837/)

### Endocannabinoid System
- [The endocannabinoid system in anxiety, fear memory and habituation](https://pmc.ncbi.nlm.nih.gov/articles/PMC3267552/)
- [The endocannabinoid system in modulating fear, anxiety, and stress](https://www.tandfonline.com/doi/full/10.31887/DCNS.2020.22.3/rmaldonado)

### Neuropeptides
- [Protective Role of Neuropeptides in Depression and Anxiety](https://pmc.ncbi.nlm.nih.gov/articles/PMC9952193/)
- [The Orexin/Hypocretin System and Adaptation to Stress](https://www.mdpi.com/2227-9059/12/2/448)
