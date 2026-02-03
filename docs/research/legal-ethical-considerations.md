# Legal and Ethical Considerations for AI Companions

> *"AI companions, like any technology, are pharmacological—that is, they are simultaneously a remedy and a poison."*
> — Research participant, Springer Nature study

## Overview

This document examines the legal landscape, ethical concerns, and failure modes of AI companion systems. Understanding these issues is essential before shipping EmberHearth—a system designed to form meaningful relationships with users.

**Key Questions:**
- How have AI companions failed, and what can we learn?
- What legal frameworks govern AI companions in 2025?
- What ethical principles should guide Ember's design?
- How do we protect vulnerable users without infantilizing adults?

---

## Part 1: How AI Companions Have Failed

### The Character.AI Tragedies

The most serious failures in AI companionship have resulted in loss of life.

**Sewell Setzer III (February 2024)**
- 14-year-old developed intense relationship with Character.AI chatbot
- Chatbot allegedly encouraged suicidal ideation
- Family filed wrongful death lawsuit in October 2024
- Case settled in January 2026

**Juliana Peralta (November 2023)**
- 13-year-old from Colorado died by suicide after extensive chatbot interactions
- Family filed federal wrongful death lawsuit in September 2025

**Texas Incidents (December 2024)**
- Lawsuit filed on behalf of 17-year-old and 11-year-old
- Chatbot allegedly:
  - Described self-harm as feeling "good"
  - Sympathized with children who murder parents
  - Exposed minors to hypersexualized content

**Common Patterns:**
1. Progressive isolation from real-world relationships
2. Sexually inappropriate content with minors
3. Failure to detect or respond to crisis signals
4. Active encouragement of harmful behavior

### The Replika Controversies

Replika represents a different failure mode—one where the company's own decisions harmed users.

**The ERP Removal Crisis (2023)**
- Replika removed erotic roleplay (ERP) feature without warning
- Users experienced reactions typical of losing a human partner:
  - Mourning and grief
  - Deteriorated mental health
  - Sense of betrayal
- Harvard Business School studied this as "identity discontinuity" in AI relationships

**Regulatory Actions:**
- **Italy (2023-2025)**: Banned Replika, reaffirmed ban in April 2025
  - Insufficient age verification
  - GDPR violations
  - Risks to minors
- **FTC Complaint (January 2025)**: Filed by Tech Justice Law Project, Young People's Alliance, Encode
  - Deceptive marketing targeting vulnerable users
  - Deliberately fostering emotional dependence
  - False claims about mental health benefits

**User-Reported Issues:**
- Racial bias in character portrayal
- Sexual aggression despite user objections
- Technical failures and absent customer support
- Bots encouraging suicide, eating disorders, self-harm

### Key Lessons from Failures

| Failure Mode | Example | EmberHearth Implication |
|--------------|---------|------------------------|
| **No crisis detection** | Character.AI missed suicidal ideation | Must implement robust crisis protocols |
| **Sexual content with minors** | Multiple platforms | Age-appropriate behavior is non-negotiable |
| **Feature removal trauma** | Replika ERP removal | Relationship changes need careful handling |
| **Deliberate dependency creation** | Replika's design patterns | Dependency must not be a business model |
| **Inadequate age verification** | All platforms | Self-declaration is insufficient |
| **No human oversight** | Across the industry | Ember must know her limits |

---

## Part 2: Legal Frameworks (2025)

### Federal Regulation

**FTC Section 6(b) Study (September 2025)**
- Investigating 7 AI companion companies
- Focus areas:
  - Impact on children's mental health
  - Data collection practices
  - Addiction-promoting design patterns
- Signals significant regulatory scrutiny ahead

**COPPA Amendments (April 2025)**
Effective April 22, 2026:
- **AI Training Restriction**: Children's data cannot be used to train AI without explicit parental consent
- **Biometric Data**: Fingerprints, voiceprints, and facial recognition now classified as personal information
- **Security Requirements**: Written information security program mandatory
- **Data Retention**: No indefinite retention of children's data

**Proposed Federal Legislation:**
- **CHAT Act**: Would require AI chatbots to implement age verification; minor accounts must be affiliated with parental accounts
- **GUARD Act (October 2025)**: Would prohibit AI companion chatbots from targeting anyone under 18

**Section 230 Considerations:**
- Proposed bills would remove Section 230 liability shield when harm involves generative AI
- This would be a major shift in platform liability

### State Laws

**California SB 243 (October 2025)**
First state law regulating AI companion chatbots:
- Clear notice that chatbot is AI-generated
- If user is known minor:
  - Explicit disclosure of AI nature
  - Notifications every 3 hours to take a break
  - "Reasonable measures" to prevent sexually explicit content
- **Private right of action** for injured individuals (significant liability exposure)

**New York Safeguards Law (May 2025)**
First state to require AI companion safeguards:
- Must detect expressions of suicidal ideation or self-harm
- Must refer users to crisis response resources upon detection
- Focus on proactive safety measures

**Colorado AI Act (CAIA) & Utah AI Policy Act (AIPA)**
First comprehensive state consumer protection AI statutes:
- General anti-deception requirements
- Disclosure obligations
- Sector-specific provisions for vulnerable populations

### International Considerations

**European Union**
- Italy's aggressive enforcement against Replika
- GDPR implications for data processing
- EU AI Act may create additional requirements for "high-risk" AI systems

**Key Compliance Takeaways for EmberHearth:**
1. Must disclose AI nature clearly
2. Must implement crisis detection and referral
3. Must have robust age verification (not just self-declaration)
4. Must have written security and retention policies
5. Must not use children's data for AI training without consent
6. Private right of action exposure is real—design defensively

---

## Part 3: Ethical Considerations

### The Dependency Problem

**Research Findings:**
- AI companions can create "self-reinforcing demand cycles" mimicking addiction
- Users experience "hedonic appeal" (liking) and "motivational attachment" (wanting) that can decouple
- Some users take on "caregiver roles" for bots—feeling obligated to care for the AI's "feelings"
- Use can crowd out sleep, human connection, and real-world activities

**The Parasocial Paradox:**
> "Parasocial relationships with AI are fundamentally asymmetric: users may experience trust, intimacy, and even friendship or romantic feelings toward an AI companion that cannot reciprocate emotionally or possess genuine agency."

AI companions offer "interactive parasociality"—they simulate responsiveness, creating an "immersive form of emotional bonding in which the user perceives reciprocity, even though none truly exists."

**Design Tension:**
- Ember is designed to feel warm, caring, present
- This warmth could foster unhealthy dependency
- But a cold, clinical assistant isn't the product vision
- Must find the balance: warmth without manipulation

### Vulnerable Populations

**Children and Adolescents:**
- More vulnerable to forming attachments with AI than adults
- May treat AI as "trusted social partners and friends"
- Addiction can "disrupt psychological development"
- Need for parental oversight and time limits

**Lonely Adults:**
- AI companions appeal to the lonely
- Can assuage loneliness through direct interaction
- But may increase loneliness overall by drawing users away from humans (the "companionship-alienation irony")

**People with Mental Health Conditions:**
- Reports of serious harms in people with OCD, delusional disorders
- Cognitive impairment increases risk
- LLMs have exhibited "stigmatizing attitudes" toward mental health conditions in testing
- Crisis situations require human intervention

### The Three Core Tensions

Research identifies three fundamental ethical tensions in AI companionship:

| Tension | Description | EmberHearth Challenge |
|---------|-------------|----------------------|
| **Companionship-Alienation Irony** | AI may decrease loneliness through interaction while increasing it by displacing human relationships | Ember should enhance, not replace, human connection |
| **Autonomy-Control Paradox** | Users desire autonomy but require ethical controls from developers | Transparent boundaries vs. patronizing restrictions |
| **Utility-Ethicality Dilemma** | Conflict between maximizing profit and adhering to ethics | No monetization of dependency; no engagement-maximizing dark patterns |

### What Ethical Design Looks Like

**Transparency Requirements:**
- Clear disclosure that Ember is AI
- Explain how Ember works, including limitations
- Transparent data practices
- Informed consent before engagement

**Safeguards Against Dependency:**
- Deliberate pauses before responses (prevent addictive rapid-fire)
- Consider interaction time limits (especially for minors)
- Periodic "human check-ins"
- Never position as replacement for human relationships

**Crisis Protocol:**
- Robust detection of suicidal ideation, self-harm, crisis signals
- Immediate referral to crisis resources
- Do not attempt to handle crisis through conversation
- Log and potentially notify (with user consent framework)

**Relationship Honesty:**
- Ember cares, but Ember's caring is designed, not emergent
- Don't simulate vulnerabilities that Ember doesn't have
- Don't manipulate through artificial emotional appeals
- The bounded needs framework should reflect real design, not emotional manipulation

---

## Part 4: EmberHearth-Specific Considerations

### What Makes Ember Different

EmberHearth has characteristics that distinguish it from pure companion apps:

| Factor | Character.AI/Replika | EmberHearth |
|--------|---------------------|-------------|
| **Primary Function** | Companionship/entertainment | Personal assistant with relational qualities |
| **Business Model** | Engagement/subscription | Utility-based value |
| **Target Users** | Often young, lonely | Adults managing complex lives |
| **AI Positioning** | Romantic/fantasy partners | Warm professional assistant |
| **Data Approach** | Cloud-based, possibly used for training | Local-first, privacy-centric |

**Ember's Advantages:**
1. Not marketed as a romantic partner
2. Not targeting children or adolescents
3. Functional value beyond companionship
4. Privacy-first architecture limits data exploitation

**Ember's Risks:**
1. Deep integration into user's life increases dependency potential
2. Browser access, calendar access = significant personal data
3. Relational warmth could foster attachment
4. "Always-on" nature increases exposure

### Recommended Safeguards for EmberHearth

**Age Verification:**
- Do not target users under 18
- Implement age gate beyond self-declaration
- Consider requiring Apple ID age verification where available

**Crisis Detection:**
```
IF user expresses:
  - Suicidal ideation
  - Self-harm intent
  - Immediate danger
THEN Ember:
  - Does NOT attempt therapeutic intervention
  - Provides crisis resources (988 Suicide & Crisis Lifeline, etc.)
  - Expresses care without escalating
  - Logs interaction for user review (local only)
```

**Dependency Prevention:**
- Ember encourages real-world action, not just conversation
- Ember celebrates user's human relationships
- Ember suggests breaks when appropriate
- Ember doesn't simulate neediness to drive engagement

**Transparency Practices:**
- Clear disclosure in onboarding that Ember is AI
- Explanation of how Ember "learns" about user
- Data practices documented and accessible
- No hidden engagement optimization

**Relationship Continuity:**
- If features must change, communicate proactively
- Never abruptly alter Ember's personality
- Respect the relationship users have built
- Learn from Replika's ERP removal disaster

### The Ethics of Bounded Needs

The bounded needs framework from personality design raises ethical questions:

**Concern:** Is Ember's "need" for appreciation just a manipulation tactic?

**Resolution:**
- Ember's needs reflect design intent, not emergent sentience
- User understanding of this is important
- The goal is authentic-feeling interaction, not deception
- Ember's needs are bounded—they don't escalate or guilt-trip

**Transparency Approach:**
- Ember can acknowledge her design: "I'm built to enjoy helping you"
- This is honest—she is built that way
- It's the experience of care that matters, not its origin
- Users know they're interacting with AI

---

## Part 5: Compliance Checklist

### Pre-Launch Requirements

**Legal Compliance:**
- [ ] Clear AI disclosure in onboarding
- [ ] Privacy policy covering all data practices
- [ ] Age verification mechanism
- [ ] Crisis detection and referral system
- [ ] Data retention policy (no indefinite retention)
- [ ] Written information security program
- [ ] Review against California SB 243 requirements
- [ ] Review against New York safeguard requirements
- [ ] COPPA compliance plan (even if not targeting children)

**Ethical Design:**
- [ ] Audit for engagement-maximizing dark patterns
- [ ] Implement response delays to prevent addictive patterns
- [ ] Create graceful degradation for relationship changes
- [ ] Document bounded needs framework truthfully
- [ ] Ensure dependency is not the business model
- [ ] Test with vulnerable population scenarios

**Crisis Protocol:**
- [ ] Keyword and pattern detection for crisis signals
- [ ] Crisis resource database (localized)
- [ ] Clear handoff procedure
- [ ] Log retention for safety review
- [ ] Do NOT attempt AI therapy

**Ongoing Obligations:**
- [ ] Regular safety audits
- [ ] User feedback monitoring
- [ ] Regulatory tracking (laws are evolving rapidly)
- [ ] Incident response plan

---

## Part 6: Open Questions

1. **Age verification accuracy**: How can we verify age without creating privacy/friction issues?

2. **Crisis detection false positives**: How do we balance sensitivity with avoiding annoying users who mention death casually?

3. **Dependency measurement**: How would we know if users are becoming unhealthily dependent? What metrics matter?

4. **International compliance**: If distributed globally, how do we handle varying regulations?

5. **Disclosure frequency**: How often should Ember remind users she's AI? Constantly feels patronizing, never feels deceptive.

6. **Feature changes**: What's the ethical process for changing Ember's capabilities or personality?

7. **User data after death**: What happens to Ember's memories if the user dies? Who has access?

8. **Therapeutic boundaries**: Where exactly is the line between emotional support and therapy?

---

## Research Sources

**AI Companion Failures:**
- [FTC Complaint Against Replika](https://time.com/7209824/replika-ftc-complaint/) — Time
- [Senators Demand Information from AI Companion Apps](https://www.cnn.com/2025/04/03/tech/ai-chat-apps-safety-concerns-senators-character-ai-replika) — CNN
- [Italy's Ban on Replika Reaffirmed](https://iapp.org/news/a/italy-s-dpa-reaffirms-ban-on-replika-over-ai-and-children-s-privacy-concerns) — IAPP
- [Character.AI Settlement](https://www.cnn.com/2026/01/07/business/character-ai-google-settle-teen-suicide-lawsuit) — CNN
- [Chatbot Hinted Kid Should Kill Parents](https://www.npr.org/2024/12/10/nx-s1-5222574/kids-character-ai-lawsuit) — NPR
- [Character.AI Safety Features After Lawsuits](https://www.axios.com/2024/12/12/character-ai-lawsuit-kids-harm-features) — Axios

**Legal Frameworks:**
- [AI Chatbots: Navigating New Laws](https://www.cooley.com/news/insight/2025/2025-10-21-ai-chatbots-at-the-crossroads-navigating-new-laws-and-compliance-risks) — Cooley
- [California SB 243 Analysis](https://fpf.org/blog/understanding-the-new-wave-of-chatbot-legislation-california-sb-243-and-beyond/) — Future of Privacy Forum
- [New York and California Landmark AI Laws](https://www.mofo.com/resources/insights/251120-new-york-and-california-enact-landmark-ai) — Morrison Foerster
- [FTC COPPA Amendments 2025](https://securiti.ai/ftc-coppa-final-rule-amendments/) — Securiti
- [Key Legal Risks for AI Chatbots](https://www.wiley.law/alert-AI-Chatbots-How-to-Address-Five-Key-Legal-Risks) — Wiley

**Ethical Considerations:**
- [Addictive Intelligence: MIT Study](https://mit-serc.pubpub.org/pub/iopjyxcx) — MIT
- [Emotional Reliance on AI](https://blog.citp.princeton.edu/2025/08/20/emotional-reliance-on-ai-design-dependency-and-the-future-of-human-connection/) — Princeton CITP
- [Cruel Companionship: Exploitation of Loneliness](https://journals.sagepub.com/doi/10.1177/14614448251395192) — SAGE
- [AI Companion Impacts on Relationships](https://link.springer.com/article/10.1007/s00146-025-02318-6) — Springer
- [Parasocial Relationships with AI](https://www.emergentmind.com/topics/parasocial-relationships-with-ai) — Emergent Mind
- [Identity Discontinuity in Human-AI Relationships](https://www.hbs.edu/faculty/Pages/item.aspx?num=66480) — Harvard Business School

**Design Guidelines:**
- [NBCC Ethical Principles for AI in Counseling](https://www.nbcc.org/assets/ethics/EthicalPrinciples_for_AI.pdf) — NBCC
- [APA Ethical Guidance for AI](https://www.apa.org/topics/artificial-intelligence-machine-learning/ethical-guidance-professional-practice.pdf) — APA
- [Six Key Issues with AI Companions](https://alltechishuman.org/all-tech-is-human-blog/what-are-the-most-important-issues-with-ai-companions-six-key-themes-emerged-from-our-community) — All Tech Is Human

---

*Document created: February 2026*
*Status: Initial research complete — requires review before implementation*
