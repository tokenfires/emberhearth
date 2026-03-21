# Changelog

All notable changes to EmberHearth will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-21

### Added
- **iMessage integration** — reads incoming messages via FSEvents + SQLite; sends replies via AppleScript
- **Claude API integration** — streaming responses, retry logic, circuit breaker, token budget management
- **Memory system** — fact extraction, categorized storage, retrieval for context enrichment
- **Personality** — Ember's warm, bounded, helper personality via system prompt builder
- **Security pipeline (Tron)** — prompt injection scanning, credential detection on all LLM I/O
- **Crisis detection** — tiered safety responses (Tier 1–3) with 988 Lifeline referral
- **Onboarding wizard** — guided first-time setup: permissions → API key → phone config → first message test
- **Settings app** — API key management, authorized number list, session timeout, about panel
- **Menu bar integration** — always-on, minimal footprint, status indicator
- **Error handling** — graceful recovery from network failures, API errors, and database issues
- **Crash recovery** — detects abnormal exits and restores safe state on relaunch
- **Web content fetching** — summarizes web pages on user request with URL validation
- **VoiceOver support** — full accessibility labels, hints, and values across all UI
- **Dynamic Type support** — semantic font styles throughout
- **Keychain storage** — API credentials stored exclusively in macOS Keychain
- **Session management** — conversation sessions with configurable timeout
- **Group chat filtering** — configurable: block, read-only, or social mode
- **Health check service** — periodic API and database status verification
- **Structured logging** — `os.Logger` throughout with privacy annotations; security event audit log
- **Build script** — `build.sh` with `build`, `test`, `security-check`, and `all` targets
