# ASV Neurochemical Validation

**Purpose:** Validate the Affective State Vector (ASV) design against neuroscience research
**Date:** February 4, 2026
**Status:** Research Complete

---

## Executive Summary

The ASV's 7-axis emotional model is **well-grounded in neuroscience**. Six of seven axes have direct or strong indirect support from neurochemical research. The temporal axis (past↔future orientation) is cognitive rather than neurochemical, but remains useful for an AI assistant context.

**Recommendation:** Proceed with current ASV design. No modifications required.

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
| **temporal** | Cognitive (not neurochemical) | ⚠️ Indirect | No direct neurochemical mapping, but useful for AI context |
| **valence** | Russell's validated dimension | ✅ Strong | Core dimension in affect research for 40+ years |
| **intensity** | Norepinephrine (arousal) | ✅ Strong | NE is primary arousal/attention modulator |

---

## The Temporal Axis

The temporal axis (past↔future orientation) is the only dimension without direct neurochemical support. However:

1. **It's cognitively valid:** Rumination (past-focused) and worry (future-focused) are recognized psychological phenomena
2. **Dopamine provides indirect support:** Dopamine is about *anticipation* of future reward, suggesting future orientation has neurochemical components
3. **It's practically useful:** For an AI assistant, knowing whether the user is dwelling on past events or planning future actions is valuable context

**Recommendation:** Keep the temporal axis. It serves a different but complementary purpose to the neurochemical axes.

---

## Conclusions

### The ASV Design Is Well-Grounded

The ASV maps remarkably well to established neuroscience:

1. **Two axes map directly to Russell's Circumplex** (valence, arousal/intensity) - the most validated model in affect research
2. **Four axes map to specific neurochemical systems** (serotonin→anger, oxytocin→trust, dopamine→interest/hope, NE→intensity)
3. **One axis (temporal) is cognitive** but practically useful

### No Design Changes Needed

The original ASV design anticipated the neurochemical basis well. The axes are:
- Orthogonal enough to capture distinct emotional dimensions
- Grounded in real neuroscience
- Practical for AI assistant use cases

### Implementation Note

The user's proposed implementation (using the LLM to translate percentages to emotionally resonant words) is elegant because:
1. It avoids hardcoding emotion↔word mappings
2. It leverages the LLM's training on human emotional language
3. It allows the system to express subtle gradations (e.g., "62% between joy and despair")

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
