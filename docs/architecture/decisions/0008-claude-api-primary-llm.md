# ADR-0008: Claude API as Primary LLM Provider

## Status
**Accepted**

## Date
February 2026

## Context

EmberHearth requires an LLM for:
- Conversation with users
- Fact extraction from messages
- Context summarization
- Proactive observation analysis

Options:
1. **Cloud APIs:** Claude (Anthropic), GPT-4 (OpenAI), Gemini (Google)
2. **Local models:** MLX, Ollama, LM Studio
3. **Hybrid:** Cloud primary, local fallback

Considerations:
- Quality of conversation
- Cost at scale
- Privacy implications
- Reliability and uptime
- Terms of service for always-on assistants

## Decision

**Use Claude API (Anthropic) as the primary LLM provider for MVP.**

Rationale:
- High conversation quality with strong instruction-following
- Clear terms of service that don't prohibit assistant use cases
- Good balance of capability and cost
- Strong safety training aligns with EmberHearth values

**Local model support planned for v2.0** as privacy-focused alternative.

## Consequences

### Positive
- **Quality:** Claude excels at nuanced conversation
- **Safety:** Built-in refusals align with our security stance
- **Reliability:** Anthropic API has good uptime
- **Cost:** Reasonable pricing for moderate usage
- **Developer experience:** Good documentation and SDKs

### Negative
- **Cloud dependency:** Requires internet connection
- **Cost at scale:** Heavy users may find it expensive
- **Privacy:** Conversation data sent to Anthropic servers
- **Vendor lock-in:** Prompts optimized for Claude may not transfer
- **ToS risk:** Terms could change (though current terms are permissive)

### Neutral
- **API key management:** User provides their own key
- **Context window:** 200K tokens sufficient for our needs

## Provider Abstraction

To enable future provider switching:

```swift
protocol LLMProvider {
    func complete(messages: [Message],
                  systemPrompt: String,
                  tools: [Tool]?) async throws -> Response
    func stream(messages: [Message],
                systemPrompt: String,
                tools: [Tool]?) -> AsyncStream<StreamChunk>
}

class ClaudeProvider: LLMProvider { ... }
class OpenAIProvider: LLMProvider { ... }  // Future
class LocalProvider: LLMProvider { ... }   // Future (MLX)
```

## API Key Management

- User provides their own Anthropic API key
- Stored in macOS Keychain (per-context access groups)
- Never logged or transmitted elsewhere
- Option to use EmberHearth-provided key (future, subscription model)

## Cost Estimation

For typical usage (50 messages/day, ~2K tokens each):
- Input: ~50K tokens/day × $3/1M = $0.15/day
- Output: ~25K tokens/day × $15/1M = $0.375/day
- Monthly: ~$15-20

Heavy users could see $50-100/month.

## Local Model Support (Future)

Planned for v2.0:
- MLX-based local inference
- Models: Llama 3, Mistral, Qwen
- Mac Mini (M-series) as minimum hardware
- Privacy-first: conversations never leave device

User choice:
- **Cloud mode:** Higher quality, requires internet, data sent externally
- **Local mode:** Lower quality, works offline, fully private

## Alternatives Considered

### OpenAI GPT-4
- Excellent quality
- Rejected as primary: ToS historically less clear on agents; Claude better fit

### Google Gemini
- Competitive quality
- Rejected for MVP: Less mature API; unclear ToS for always-on

### Local-Only
- Maximum privacy
- Rejected for MVP: Quality gap too large; adds hardware requirements

### Multiple Providers (Day 1)
- Flexibility from start
- Rejected for MVP: Scope creep; one provider done well beats three done poorly

## References

- `docs/research/local-models.md` — Local model feasibility
- `docs/VISION.md` — LLM provider considerations
- `docs/architecture-overview.md` — LLMService architecture
