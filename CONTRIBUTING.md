# Contributing to EmberHearth

Thank you for your interest in contributing to EmberHearth! This guide will help you get set up and understand our development practices.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Getting Started](#getting-started)
3. [Project Structure](#project-structure)
4. [Code Style](#code-style)
5. [Security Rules](#security-rules)
6. [Testing](#testing)
7. [Pull Request Process](#pull-request-process)
8. [Architecture](#architecture)

---

## Prerequisites

Before you begin, make sure you have:

| Requirement | Version |
|-------------|---------|
| **macOS** | 14.0+ (Sonoma) for development |
| **Xcode** | 15.0+ (latest stable recommended) |
| **Swift** | 5.9+ |
| **Command Line Tools** | Installed (`xcode-select --install`) |

**Note:** You need Xcode 15 or later on macOS 14.0+ (Sonoma) for development. The development requirement is higher than the deployment target (macOS 13.0+) — you develop on Sonoma or later, but the app runs on Ventura or later.

---

## Getting Started

### Clone and Build

```bash
# Clone the repository
git clone https://github.com/robault/emberhearth.git
cd emberhearth

# Build the project
./build.sh build

# Run all tests
./build.sh test

# Run everything (security check + build + tests)
./build.sh all
```

### Open in Xcode

```bash
open Package.swift
```

### Available Build Commands

```bash
./build.sh build           # Build (debug configuration)
./build.sh test            # Run all tests
./build.sh clean           # Clean build artifacts
./build.sh release         # Build (release configuration)
./build.sh security-check  # Run security audit
./build.sh all             # Security check + build + test
```

Or use Make:

```bash
make build
make test
make clean
make all
```

---

## Project Structure

```
emberhearth/
├── CLAUDE.md               # AI assistant instructions (project conventions)
├── CONTRIBUTING.md         # This file
├── README.md               # User-facing project page
├── Package.swift           # Swift Package Manager configuration
├── build.sh                # Developer build script
├── Makefile                # Convenience targets
├── src/                    # All source code
│   ├── App/                # App lifecycle (EmberHearthApp, AppDelegate, AppState,
│   │                       #   AppVersion, PermissionManager, StatusBarController,
│   │                       #   CrashRecoveryManager, ServiceContainer)
│   ├── Core/               # Core orchestration + iMessage integration
│   │                       #   (MessageCoordinator, ChatDatabaseReader, MessageSender,
│   │                       #   MessageWatcher, SessionManager, GroupChatDetector,
│   │                       #   PhoneNumberFilter, WebFetcher, NetworkMonitor,
│   │                       #   OfflineCoordinator, SummaryGenerator)
│   ├── Database/           # Database layer (DatabaseManager)
│   ├── LLM/                # LLM client (ClaudeAPIClient, ContextBuilder, SSEParser,
│   │                       #   TokenCounter, CircuitBreaker, RetryHandler)
│   ├── Logging/            # Logging utilities (AppLogger, SecurityLogger)
│   ├── Memory/             # Memory system (FactStore, FactExtractor, FactRetriever)
│   ├── Personality/        # Personality & context (EmberSystemPrompt,
│   │                       #   SystemPromptBuilder, VerbosityAdapter)
│   ├── Security/           # Security layer (TronPipeline, InjectionScanner,
│   │                       #   CrisisDetector, CrisisResponseTemplates,
│   │                       #   CredentialScanner, KeychainManager)
│   └── Views/              # SwiftUI views (Onboarding/, Settings/, Components/)
├── tests/                  # All test files
│   ├── UnitTests/          # Unit tests mirroring src/ structure
│   │   ├── App/
│   │   ├── Core/
│   │   ├── Database/
│   │   ├── LLM/
│   │   ├── Memory/
│   │   ├── Personality/
│   │   ├── Security/
│   │   └── Views/
│   ├── SecurityTests/      # Security and penetration tests
│   └── IntegrationTests/   # End-to-end integration tests
├── docs/                   # Documentation
│   ├── USER-GUIDE.md       # Non-technical user guide
│   ├── CHANGELOG.md        # Release history
│   ├── VISION.md           # Vision and design philosophy
│   ├── NEXT-STEPS.md       # Roadmap and task tracking
│   ├── architecture-overview.md
│   ├── architecture/       # ADRs and architecture decisions
│   ├── releases/           # Release planning (MVP scope, feature matrix)
│   ├── specs/              # Implementation specifications
│   ├── research/           # Research findings
│   ├── deployment/         # Build and release docs
│   └── testing/            # Testing strategy
├── tasks/                  # AI-assisted build task documents
└── scripts/                # Developer scripts (pre-commit hooks)
```

### Key Source Files

| File | Purpose |
|------|---------|
| `src/Core/MessageCoordinator.swift` | Central orchestrator — connects iMessage, LLM, memory, and security |
| `src/Security/TronPipeline.swift` | Security screening pipeline (injection scanning, credential detection, crisis detection) |
| `src/Security/CrisisDetector.swift` | Crisis signal detection with tiered response system |
| `src/LLM/ClaudeAPIClient.swift` | Claude API integration with streaming support |
| `src/Memory/FactStore.swift` | Local fact storage and retrieval (SQLite) |
| `src/Core/ChatDatabaseReader.swift` | Reads the iMessage database (chat.db) |
| `src/Core/MessageSender.swift` | Sends iMessages via AppleScript automation |
| `src/App/PermissionManager.swift` | Checks and manages macOS permissions |

---

## Code Style

### Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Swift files | PascalCase | `MessageCoordinator.swift` |
| Doc files | lowercase-with-hyphens | `architecture-overview.md` |
| Types (class, struct, enum, protocol) | PascalCase | `CrisisDetector`, `FactStore` |
| Properties and methods | camelCase | `detectCrisis(in:)`, `matchedPatterns` |
| Enum cases | camelCase | `.tier1`, `.preference` |
| Constants | camelCase | `primaryCrisisNumber` |

### Documentation Comments

All public types and methods MUST have documentation comments:

```swift
/// Detects crisis signals in user messages using pattern matching.
///
/// The detector uses three layers of analysis:
/// 1. False positive filtering
/// 2. Tier-based pattern matching
/// 3. Context awareness
///
/// - Parameter message: The user's message text.
/// - Returns: A `CrisisAssessment` if crisis signals are detected, nil otherwise.
func detectCrisis(in message: String) -> CrisisAssessment? {
    // ...
}
```

### Logging

Use `os.Logger` for all logging. Never use `print()` in production code.

```swift
import os

private let logger = Logger(
    subsystem: "com.emberhearth.app",
    category: "YourCategory"
)

// Usage
logger.info("Something happened")
logger.error("Something went wrong: \(errorDescription, privacy: .public)")
```

**CRITICAL:** Never include user message content, API keys, phone numbers, or personal data in log output.

### SwiftUI Accessibility

Every interactive SwiftUI element must include accessibility modifiers:

```swift
Button("Save Settings") {
    saveSettings()
}
.accessibilityLabel("Save settings")
.accessibilityHint("Saves your current configuration")
```

Use semantic font styles, not fixed sizes:

```swift
// Good
.font(.headline)
.font(.body)

// Bad
.font(.system(size: 14))
```

---

## Security Rules

These are absolute rules. No exceptions.

### Never Do

- **No shell execution:** Never use `Process()`, `/bin/bash`, `/bin/sh`, `NSTask`, or `CommandLine` in source code. EmberHearth the application NEVER executes shell commands. (Build scripts for developer use are fine.)
- **No hardcoded credentials:** Never put API keys, tokens, or passwords in source code. Use Keychain.
- **No credentials in logs:** Never log API keys, user messages, phone numbers, or personal data.
- **No plaintext secrets:** Never store credentials in UserDefaults, plist files, or text files.
- **No force unwraps in production:** Use `guard let`, `if let`, or `Optional` chaining. (`XCTUnwrap` in tests is fine.)

### Always Do

- **Use Keychain for secrets:** All credentials go through `KeychainManager`.
- **Validate all inputs:** Every user input must be validated before processing.
- **Screen LLM inputs/outputs:** All messages pass through `TronPipeline` before and after the LLM.
- **Use parameterized SQL:** Never use string interpolation in SQL queries. Use `?` placeholders.
- **Log security events:** Use `SecurityLogger` for security-relevant events.
- **Sandbox file access:** Only access files in approved locations.

### Pre-Commit Hook

Install the pre-commit hook to catch security issues before committing:

```bash
cp scripts/pre-commit-check.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

This checks staged files for hardcoded API keys and shell execution in `src/`.

---

## Testing

### Running Tests

```bash
# All tests
./build.sh test

# Specific test class
swift test --filter CrisisDetectorTests

# With verbose output
swift test -v
```

### Coverage Target

The MVP target is **60% code coverage**. Aim higher for security-critical code.

### Test Organization

- Unit tests go in `tests/UnitTests/` mirroring the `src/` structure
- Integration tests go in `tests/IntegrationTests/`
- Security penetration tests go in `tests/SecurityTests/`

### What to Test

- All public methods
- Error paths and edge cases
- Security boundaries (injection attempts, credential exposure)
- Accessibility (VoiceOver labels exist on interactive elements)
- False positives and true positives for detection systems (crisis, injection)

---

## Pull Request Process

### Branch Naming

```
feature/short-description    # New features
fix/short-description        # Bug fixes
chore/short-description      # Maintenance, refactoring, docs
```

### Commit Messages

Follow the conventional commit format:

```
type(scope): description

Examples:
feat(memory): add fact extraction from conversations
fix(security): prevent credential leak in error messages
chore(docs): update contributing guide
test(crisis): add false positive tests for idioms
```

Types: `feat`, `fix`, `chore`, `test`, `docs`, `refactor`, `style`, `perf`

### Before Submitting

1. Run `./build.sh all` — must pass (security check + build + tests)
2. Ensure no new warnings are introduced
3. Add tests for new functionality
4. Update documentation if behavior changes
5. Verify accessibility on new UI elements (VoiceOver labels, Dynamic Type, keyboard nav)

### Review Requirements

- All PRs require at least one review
- Security-related changes require extra scrutiny
- No force-merging to main
- CI checks must pass before merge

---

## Architecture

For a detailed understanding of EmberHearth's architecture, see:

- [Architecture Overview](docs/architecture-overview.md) — System design and component relationships
- [ADR Index](docs/architecture/decisions/README.md) — Architectural Decision Records explaining key design choices
- [Vision](docs/VISION.md) — Product vision and design philosophy
- [Tron Security Spec](docs/specs/tron-security.md) — Security layer specification

### Key Design Principles

1. **Security by Removal** — No shell execution. Structured operations that can't be misused.
2. **Secure by Default** — Safe with zero configuration. Capabilities require explicit consent.
3. **The Grandmother Test** — If grandma can't use it unsupervised, it's not ready.
4. **Accessibility First** — iMessage as primary interface inherits Apple's full accessibility stack.
5. **Privacy First** — All personal data stays local. No cloud sync. No telemetry.

### Dependency Flow

Dependencies flow downward. Upper layers depend on lower layers, never the reverse:

```
App Layer (EmberHearthApp, Views)
    |
    v
Core Layer (MessageCoordinator)
    |
    v
Service Layer (Security, Memory, LLM, iMessage integration in Core)
    |
    v
Data Layer (Database)
```

Cross-module imports within the same layer should be avoided. If module A and module B at the same layer need to communicate, they should do so through the Core layer above them.
