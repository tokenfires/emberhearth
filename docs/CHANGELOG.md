# Changelog

All notable changes to EmberHearth will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-XX-XX

Initial release of EmberHearth.

### Added

#### iMessage Integration
- Read incoming iMessages from authorized phone numbers via chat.db monitoring
- Send responses through Messages.app via AppleScript automation
- FSEvents-based real-time message detection (no polling)
- Phone number filtering to restrict access to authorized users only
- Group chat detection to prevent unintended responses in group conversations

#### AI Conversations
- Claude API integration for AI-powered responses
- Streaming response handling via SSE for real-time message delivery
- Context window management with rolling conversation summaries
- Conversation continuity across sessions
- Web content fetching and summarization (URL sharing)
- Circuit breaker and retry logic for resilient API communication

#### Memory System
- SQLite-based local fact storage with encryption
- Automatic fact extraction from conversations
- Relevant fact retrieval for conversation context
- Session management with conversation continuity
- Context budget enforcement to stay within token limits

#### Personality
- Ember personality with warm, helpful communication style
- Verbosity adaptation based on user communication patterns
- Bounded needs model for authentic personality expression
- System prompt engineering for consistent behavior

#### Security
- Tron security pipeline for input and output screening
- Prompt injection scanning on all inbound messages
- Credential detection scanning on all outbound responses
- Crisis detection with tiered response system (Tier 1/2/3)
- 988 Suicide & Crisis Lifeline referral in all crisis responses
- Security event logging (without user message content)
- Keychain-only credential storage
- No shell execution — ever
- Hardened Runtime enabled

#### User Interface
- Onboarding wizard with guided permission setup
- API key entry with live validation
- Phone number configuration with format verification
- Settings panel for configuration management
- Menu bar integration with status indicators
- Launch at login support
- Error state UI with actionable recovery guidance
- Crash recovery and graceful degradation
- Offline handling with graceful degradation and recovery

#### Accessibility
- Full VoiceOver support on all UI elements
- Dynamic Type support for all text
- Keyboard navigation throughout the settings app
- Semantic font styles (no fixed font sizes)
- iMessage as primary interface inherits Apple's full accessibility stack

#### Developer Experience
- Build script with security-check, build, test, and release targets
- Makefile with convenience targets
- Pre-commit hook for security auditing
- Comprehensive test suite (unit, integration, security penetration)
