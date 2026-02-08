# Task 0903: Final Code Review and Cleanup

**Milestone:** M10 - Final Integration
**Unit:** 10.4 - Comprehensive Code Review, Cleanup, and Documentation
**Phase:** Final
**Depends On:** 0902 (App Startup Wiring)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; this defines all conventions and security boundaries to verify against
2. `docs/VISION.md` — Read the first section for product philosophy
3. `docs/testing/strategy.md` — Read the "Coverage Target" section (lines ~66-71): MVP target 60%
4. `docs/deployment/build-and-release.md` — Read the "Release Checklist" section (lines ~446-486)
5. `README.md` — Read entirely; will be updated in this task
6. `.gitignore` — Read entirely; verify completeness

> **Context Budget Note:** This task is a comprehensive review across ALL source files. You do not need to open every file at once. Instead, systematically work through each audit category, opening files as needed. Start with the security audit (most critical), then code quality, then accessibility, then architecture.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are performing the final comprehensive code review and cleanup for EmberHearth, a native macOS personal AI assistant. This is the LAST task before the MVP release. Your job is to find and fix any remaining issues across the entire codebase.

## Important Rules (from CLAUDE.md)

- NEVER use shell execution (no Process(), no /bin/bash, no NSTask) in source code
- Security first: Keychain for secrets, validate all inputs, no sensitive data in logs
- All UI must support VoiceOver, Dynamic Type, keyboard navigation
- PascalCase for Swift files, camelCase for properties/methods
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app") — no print()
- All public types and methods must have documentation comments (///)

## What You Are Doing

A systematic final review organized into these phases:
1. Security audit (MOST CRITICAL)
2. Code quality audit
3. Accessibility audit
4. Architecture audit
5. Documentation updates
6. Final build verification

## Phase 1: Security Audit (Critical)

Search the ENTIRE src/ directory for each of these. Every item must have ZERO results.

### 1a. Shell Execution Check
Search for any shell execution — this is an absolute prohibition in EmberHearth:
```
grep -rn "Process()" src/ --include="*.swift"
grep -rn "/bin/bash" src/ --include="*.swift"
grep -rn "/bin/sh" src/ --include="*.swift"
grep -rn "NSTask" src/ --include="*.swift"
grep -rn "CommandLine" src/ --include="*.swift"
```
**Expected: ZERO results for all searches.** If any are found, remove them immediately. There are NO exceptions.

### 1b. Hardcoded Secrets Check
Search for any hardcoded API keys, tokens, or credentials:
```
grep -rn "sk-ant-" src/ --include="*.swift"
grep -rn "sk-proj-" src/ --include="*.swift"
grep -rn "AKIA" src/ --include="*.swift"
grep -rn "ghp_\|gho_\|ghu_" src/ --include="*.swift"
grep -rn "password\s*=" src/ --include="*.swift"
grep -rn "apiKey\s*=\s*\"" src/ --include="*.swift"
```
**Expected: ZERO results.** Credentials must ONLY be loaded from Keychain. If any test API keys are found in source, remove them.

Note: Test files in tests/ may contain mock API keys for testing credential detection — that is acceptable. But src/ must have ZERO.

### 1c. Input Validation Check
For every place where user input enters the system, verify it is validated:
- `MessageCoordinator.processIncomingMessage()` — does it validate before processing?
- `TronPipeline.screenInbound()` — is it called before the LLM receives any user input?
- `TronPipeline.screenOutbound()` — is it called before any LLM output is sent to the user?
- All SQL queries — do they use parameterized queries (? placeholders)?

Search for string interpolation in SQL (dangerous):
```
grep -rn "\".*\\\\(.*\"" src/Database/ --include="*.swift"
grep -rn "\".*\\\\(.*\"" src/Memory/ --include="*.swift"
```
If any SQL uses string interpolation instead of parameterized queries, fix it immediately.

### 1d. Sensitive Data in Logs Check
Search for potential sensitive data leaks in log output:
```
grep -rn "logger.*message\|logger.*content\|logger.*text\|logger.*password\|logger.*key\|logger.*token" src/ --include="*.swift"
```
Review each result. Log entries should contain:
- Event descriptions (what happened)
- Non-sensitive metadata (timestamps, counts, severity levels)
- NEVER: message content, API keys, user data, phone numbers

### 1e. Keychain Usage Verification
Verify that ALL credential storage goes through KeychainManager:
```
grep -rn "KeychainManager\|Keychain" src/ --include="*.swift"
```
The API key should be loaded from Keychain in AppDelegate and passed to ClaudeAPIClient via dependency injection. It should NOT be stored in UserDefaults, plist files, or any other non-Keychain location.

## Phase 2: Code Quality Audit

### 2a. No Force Unwraps in Production Code
Search for force unwraps in src/ (NOT tests/):
```
grep -rn "![[:space:]]" src/ --include="*.swift" | grep -v "!=" | grep -v "//\|///" | grep -v "IBOutlet\|IBAction"
```
Replace any force unwraps with:
- `guard let ... else { ... }` for early returns
- `if let ...` for optional handling
- `XCTUnwrap` is acceptable in tests only

### 2b. No print() Statements
Search for print() in production code:
```
grep -rn "^[[:space:]]*print(" src/ --include="*.swift"
```
**Expected: ZERO results.** All logging must use `os.Logger`. Replace any print() with the appropriate logger call.

### 2c. No TODO/FIXME Without Task Reference
Search for loose TODOs:
```
grep -rn "TODO\|FIXME\|HACK\|XXX" src/ --include="*.swift"
```
Each TODO/FIXME should either:
- Have a task reference (e.g., "TODO(v1.1): Add multi-language support")
- Be resolved in this task
- Be removed if no longer applicable

### 2d. Consistent Naming Conventions
Verify:
- All Swift file names use PascalCase (e.g., `MessageCoordinator.swift`, not `message_coordinator.swift`)
- All type names use PascalCase (classes, structs, enums, protocols)
- All property and method names use camelCase
- All enum cases use camelCase (e.g., `.preference`, not `.Preference`)

### 2e. No Unused Imports
Check each file for imports that aren't used. Common unused imports to check:
```
grep -rn "import UIKit" src/ --include="*.swift"
```
(UIKit should not be imported — this is a macOS app. Use AppKit/Cocoa/SwiftUI instead.)

### 2f. No Dead Code
Look for:
- Commented-out code blocks (remove or convert to TODO with explanation)
- Unreachable code after return/throw statements
- Unused private methods or properties

## Phase 3: Accessibility Audit

### 3a. VoiceOver Labels
For every SwiftUI view in src/Views/ that contains interactive elements (buttons, toggles, text fields, links), verify:
```swift
.accessibilityLabel("Clear description of what this element does")
```

Search for views without accessibility:
```
grep -rn "Button\|Toggle\|TextField\|Picker\|Slider\|Link" src/Views/ --include="*.swift"
```
Then for each file that has interactive elements, verify it also has:
```
grep -rn "accessibilityLabel\|accessibilityValue\|accessibilityHint" [that file]
```

### 3b. Semantic Font Styles
Search for fixed font sizes:
```
grep -rn "\.font(.system(size:" src/Views/ --include="*.swift"
grep -rn "fontSize" src/Views/ --include="*.swift"
```
Replace any fixed font sizes with semantic styles:
```swift
.font(.title)
.font(.headline)
.font(.body)
.font(.caption)
```

### 3c. No Fixed Frame Sizes on Text
Search for frame modifiers on text-containing views that could prevent Dynamic Type scaling:
```
grep -rn "\.frame(.*height:" src/Views/ --include="*.swift"
```
Review each result — fixed heights on text containers prevent Dynamic Type from working.

## Phase 4: Architecture Audit

### 4a. No Circular Dependencies
Review the import statements in each source file. Check that:
- `src/Security/` files do NOT import from `src/LLM/` or `src/iMessage/`
- `src/Memory/` files do NOT import from `src/LLM/` or `src/iMessage/`
- `src/Database/` files do NOT import from any other src/ module
- Dependencies flow downward: App -> Core -> (Security, Memory, LLM, iMessage) -> Database

### 4b. File Organization
Verify every .swift file is in the correct directory:
- Security-related files → src/Security/
- Memory-related files → src/Memory/
- LLM-related files → src/LLM/
- iMessage-related files → src/iMessage/
- Database files → src/Database/
- Core orchestration → src/Core/
- Personality → src/Personality/
- App lifecycle → src/App/
- Views → src/Views/

### 4c. Protocol Usage
Verify that testable components use protocols for their dependencies:
- ClaudeAPIClient should conform to a protocol (for mocking in tests)
- MessageSender should conform to a protocol
- ChatDatabaseReader should conform to a protocol
- Any component that MessageCoordinator depends on should be injectable via protocol

## Phase 5: Documentation Updates

### 5a. Update README.md
Update the project root README.md to include:

```markdown
# EmberHearth

A secure, accessible, always-on personal AI assistant for macOS, using iMessage as its primary interface.

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0+ (for building from source)
- A Claude API key from [Anthropic](https://www.anthropic.com/)
- Full Disk Access permission (for reading iMessage database)
- Automation permission (for sending iMessages)

## Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/emberhearth.git
cd emberhearth

# Build
./build.sh build

# Run tests
./build.sh test

# Run everything (security check + build + tests)
./build.sh all
```

## First Run

1. Launch EmberHearth
2. Complete the onboarding wizard:
   - Enter your Claude API key
   - Grant required permissions
   - Add your phone number to the authorized list
3. Ember will appear in your menu bar
4. Send a message to yourself in iMessage — Ember will respond!

## Architecture

EmberHearth is built with:
- **Swift + SwiftUI** for native macOS performance
- **iMessage** as the primary conversational interface
- **SQLite** for local memory storage (encrypted)
- **Claude API** for language understanding
- **Keychain** for all credential storage

## Security

- All user data stays local — no cloud sync
- API keys stored exclusively in macOS Keychain
- All LLM inputs screened for prompt injection attacks
- All LLM outputs screened for credential leaks
- No shell execution — ever
- Hardened Runtime enabled

## Documentation

See the `docs/` directory for detailed documentation:
- `docs/VISION.md` — Product vision and philosophy
- `docs/architecture-overview.md` — System architecture
- `docs/specs/` — Implementation specifications
- `docs/research/` — Research findings

## License

MIT License — see LICENSE file for details.
```

### 5b. Verify LICENSE File
Ensure a LICENSE file exists at the project root with the MIT license.

### 5c. Create CHANGELOG.md
Create a CHANGELOG.md at the project root:

```markdown
# Changelog

All notable changes to EmberHearth will be documented in this file.

## [1.0.0] - 2026-02-XX

### Added
- iMessage integration: Read and respond to messages
- Claude API integration: AI-powered conversations
- Memory system: Remember facts about the user across sessions
- Personality: Ember's warm, helpful personality
- Security pipeline (Tron): Injection scanning, credential detection
- Crisis detection: Tiered safety responses with 988 referral
- Onboarding wizard: Guided first-time setup
- Settings app: Configure API key, authorized numbers, preferences
- Menu bar integration: Always-on, minimal footprint
- Error handling: Graceful recovery from network/API failures
- Web content fetching: Summarize web pages on request
- VoiceOver support: Full accessibility for all UI elements
```

### 5d. Remove Placeholder Files
Search for .gitkeep files that are no longer needed (directories now have actual files):
```
find . -name ".gitkeep" -not -path "./.git/*"
```
Remove .gitkeep from any directory that now contains source files.

## Phase 6: Final Build Verification

After all fixes are applied:

1. Run `swift build` — must succeed with ZERO warnings
2. Run `swift test` — ALL tests must pass
3. Run `./build.sh security-check` — must pass
4. Run `./build.sh all` — must pass all stages

If there are any warnings, fix them before completing this task.

## Implementation Rules

1. Do NOT add new features — this is a review and cleanup task only.
2. Fix issues in-place — don't create new files unless absolutely necessary.
3. If you find a bug, fix it and add a test for it.
4. If you find dead code, remove it.
5. If you find a security issue, fix it immediately and document what was fixed.
6. If you find an accessibility issue, fix it.
7. Keep all existing tests passing — do not break anything.

## Final Checks

Before finishing, verify every single one of these:
1. `grep -rn "Process()" src/` → ZERO results
2. `grep -rn "/bin/bash\|/bin/sh" src/` → ZERO results
3. `grep -rn "sk-ant-\|sk-proj-\|AKIA" src/` → ZERO results
4. `grep -rn "^[[:space:]]*print(" src/` → ZERO results
5. `swift build` → SUCCESS with ZERO warnings
6. `swift test` → ALL tests pass
7. `./build.sh security-check` → PASS
8. README.md is up to date
9. CHANGELOG.md exists with v1.0.0 entry
10. LICENSE file exists
```

---

## Acceptance Criteria

### Security (All MUST pass)
- [ ] Zero `Process()` calls in src/
- [ ] Zero `/bin/bash` or `/bin/sh` references in src/
- [ ] Zero hardcoded API keys or credentials in src/
- [ ] All user input validated before processing
- [ ] All LLM output screened before sending to user
- [ ] All SQL uses parameterized queries (no string interpolation)
- [ ] No sensitive data in log output
- [ ] Keychain is the only credential storage mechanism

### Code Quality
- [ ] Zero force unwraps in production code (src/)
- [ ] Zero `print()` statements in production code
- [ ] All TODO/FIXME have task references or are resolved
- [ ] Consistent PascalCase for types, camelCase for properties/methods
- [ ] No unused imports (especially no UIKit)
- [ ] No dead code or large commented-out blocks

### Accessibility
- [ ] All interactive SwiftUI elements have VoiceOver labels
- [ ] Semantic font styles used (no fixed font sizes in views)
- [ ] No fixed frame heights on text containers

### Architecture
- [ ] No circular dependencies between modules
- [ ] All files in correct directories per project structure
- [ ] Testable components use protocols for dependency injection

### Documentation
- [ ] README.md updated with build instructions and architecture overview
- [ ] CHANGELOG.md exists with v1.0.0 entry
- [ ] LICENSE file exists
- [ ] Unnecessary .gitkeep files removed

### Build
- [ ] `swift build` succeeds with zero warnings
- [ ] `swift test` passes all tests (unit, integration, security)
- [ ] `./build.sh security-check` passes
- [ ] `./build.sh all` passes all stages

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# ── Security Checks ──
echo "=== SECURITY AUDIT ==="

echo "Shell execution check:"
grep -rn "Process()" src/ --include="*.swift" && echo "FAIL" || echo "PASS"
grep -rn "/bin/bash\|/bin/sh\|NSTask" src/ --include="*.swift" && echo "FAIL" || echo "PASS"

echo "Hardcoded credentials check:"
grep -rn "sk-ant-\|sk-proj-\|AKIA\|ghp_\|gho_" src/ --include="*.swift" && echo "FAIL" || echo "PASS"

echo "print() statements check:"
grep -rn "^[[:space:]]*print(" src/ --include="*.swift" && echo "FAIL" || echo "PASS"

# ── Documentation Checks ──
echo "=== DOCUMENTATION ==="
test -f README.md && echo "README.md exists" || echo "MISSING"
test -f CHANGELOG.md && echo "CHANGELOG.md exists" || echo "MISSING"
test -f LICENSE && echo "LICENSE exists" || echo "MISSING"

# ── Build Checks ──
echo "=== BUILD ==="
swift build 2>&1
echo "---"
swift test 2>&1
echo "---"
./build.sh security-check 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Perform a final verification review of the EmberHearth codebase after task 0903 cleanup. This is the LAST review before MVP release.

Check EVERY source file in src/ systematically. Start by listing all .swift files:
```
find src/ -name "*.swift" | sort
```

For EACH file, verify:

1. **SECURITY (Block release if any fail):**
   - Zero Process(), /bin/bash, /bin/sh, NSTask, CommandLine calls
   - Zero hardcoded API keys, tokens, or credentials
   - Parameterized SQL queries (no string interpolation in SQL)
   - No sensitive data (messages, keys, phone numbers) in log output
   - All user input goes through TronPipeline.screenInbound() before LLM
   - All LLM output goes through TronPipeline.screenOutbound() before user

2. **CODE QUALITY (Should fix before release):**
   - No force unwraps (!) in production code
   - No print() statements — use os.Logger
   - All public types and methods have /// documentation
   - Consistent naming (PascalCase types, camelCase members)
   - No unused imports
   - No dead code

3. **ACCESSIBILITY (Should fix before release):**
   - Interactive SwiftUI elements have .accessibilityLabel()
   - Semantic font styles used (.title, .body, etc.)
   - No fixed font sizes that prevent Dynamic Type

4. **ARCHITECTURE (Important):**
   - Each file is in the correct directory
   - No circular dependencies
   - Testable components use protocols

5. **DOCUMENTATION:**
   - README.md has build instructions
   - CHANGELOG.md has v1.0.0 entry
   - LICENSE file exists

6. **BUILD:**
   - `swift build` succeeds with zero warnings
   - `swift test` passes all tests
   - `./build.sh all` passes

For each issue found, indicate:
- **BLOCKER**: Must fix before release (security issues)
- **IMPORTANT**: Should fix before release (code quality, accessibility)
- **MINOR**: Can fix in v1.0.1

Provide a final RELEASE/NO-RELEASE recommendation with justification.
```

---

## Commit Message

```
chore: final code review, cleanup, and documentation
```

---

## Notes for Next Task

There is no next task. This is the final task in the EmberHearth MVP build sequence.

After this task is complete:
1. Create a git tag: `git tag v1.0.0`
2. Follow the build-and-release process in `docs/deployment/build-and-release.md`
3. Run the manual smoke test checklist in `docs/testing/strategy.md`
4. Begin beta testing with the protocol in `docs/testing/strategy.md`

Post-MVP priorities (v1.1+):
- Multi-language crisis detection
- Context-aware crisis escalation/de-escalation
- 80%+ test coverage target
- Calendar and Reminders integration
- Local model support
- Sparkle auto-updates
