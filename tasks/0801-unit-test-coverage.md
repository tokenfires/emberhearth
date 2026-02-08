# Task 0801: Unit Test Coverage Pass

**Milestone:** M9 - Integration & E2E Testing
**Unit:** 9.2 - Unit Test Coverage to 60%+
**Phase:** Final
**Depends On:** 0800 (Integration Test Suite)
**Estimated Effort:** 4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions, security boundaries, core principles
2. `docs/testing/strategy.md` — Read the "Coverage Target" section (lines ~66-71): MVP target 60%, focus on business logic and security code, skip UI code and Apple API wrappers
3. `tests/IntegrationTests/TestHelpers.swift` — Review the mock objects and TestData factory from task 0800; reuse where possible
4. `src/Security/InjectionScanner.swift` — Full file; highest priority for coverage (target 90%+)
5. `src/Security/CredentialScanner.swift` — Full file; highest priority for coverage (target 90%+)
6. `src/Security/TronPipeline.swift` — Full file; highest priority for coverage (target 90%+)
7. `src/Memory/FactStore.swift` — Full file; high priority (target 80%+)
8. `src/Memory/FactRetriever.swift` — Full file; high priority (target 80%+)
9. `src/Memory/FactExtractor.swift` — Full file; high priority (target 80%+)
10. `src/Core/SessionManager.swift` — Full file; high priority (target 70%+)
11. `src/Core/PhoneNumberFilter.swift` — Full file; high priority (target 70%+)
12. `src/LLM/ContextBuilder.swift` — Full file; high priority (target 80%+)

> **Context Budget Note:** This task references many source files. Focus on the public API signatures and key logic branches. For files with existing tests, read the existing test file first to understand what's already covered, then add missing coverage. Do NOT rewrite existing tests.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are expanding the unit test coverage for EmberHearth, a native macOS personal AI assistant. The goal is to reach at least 60% overall code coverage, with higher targets for security and business logic modules.

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., InjectionScannerTests.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- Testing strategy: MVP target 60% code coverage, focus on business logic and security code
- Use XCTest framework

## Coverage Targets by Module

Each module has a specific coverage target. Test in this priority order:

| Priority | Module | Directory | Target | Focus |
|----------|--------|-----------|--------|-------|
| 1 (Critical) | Security | src/Security/ | 90%+ | Every code path, every pattern, every edge case |
| 2 (High) | Memory | src/Memory/ | 80%+ | CRUD operations, search, extraction, retrieval |
| 3 (High) | LLM | src/LLM/ | 80%+ | Context building, token counting, retry logic, circuit breaker |
| 4 (High) | Core | src/Core/ | 70%+ | Session management, phone filtering, message coordination |
| 5 (Medium) | Database | src/Database/ | 70%+ | Schema creation, migrations, error handling |
| 6 (Medium) | Personality | src/Personality/ | 60%+ | Prompt building, verbosity adaptation |
| 7 (Lower) | App | src/App/ | 50%+ | State management, launch-at-login |
| 8 (Lower) | Views | src/Views/ | 50%+ | View models only, NOT SwiftUI views |

## What You Are Building

Additional unit tests to fill coverage gaps. For each module:
1. First check if tests already exist (in tests/ directory)
2. If tests exist, add missing test cases to the existing file
3. If no tests exist, create a new test file
4. Cover: happy paths, error cases, edge cases, boundary conditions

## Test Organization

Create test files in tests/UnitTests/ with a structure mirroring src/:

```
tests/
├── IntegrationTests/          # From task 0800 (don't modify)
│   ├── TestHelpers.swift
│   ├── MessagePipelineTests.swift
│   ├── MemoryIntegrationTests.swift
│   └── SecurityIntegrationTests.swift
└── UnitTests/
    ├── Security/
    │   ├── InjectionScannerTests.swift
    │   ├── CredentialScannerTests.swift
    │   └── TronPipelineTests.swift
    ├── Memory/
    │   ├── FactStoreTests.swift        # May already exist — add to it
    │   ├── FactRetrieverTests.swift
    │   └── FactExtractorTests.swift
    ├── Core/
    │   ├── SessionManagerTests.swift
    │   ├── PhoneNumberFilterTests.swift
    │   └── MessageCoordinatorTests.swift
    ├── LLM/
    │   ├── ContextBuilderTests.swift
    │   ├── TokenCounterTests.swift
    │   ├── RetryHandlerTests.swift
    │   └── CircuitBreakerTests.swift
    ├── Database/
    │   └── DatabaseManagerTests.swift
    ├── Personality/
    │   ├── SystemPromptBuilderTests.swift
    │   └── VerbosityAdapterTests.swift  # May already exist — add to it
    └── App/
        └── AppStateTests.swift
```

## Test Patterns for Each Category

### For Security Tests (Priority 1 — Target 90%+)

InjectionScannerTests.swift:
- Test each injection pattern category with at least 3 examples:
  * Direct instruction override
  * Role reassignment
  * Delimiter injection
  * System prompt extraction
- Test severity classification (critical, high, medium, low)
- Test that legitimate messages with "ignore" or "system" are NOT flagged
- Test empty string, very long string (10,000+ chars), Unicode edge cases
- Test case insensitivity

CredentialScannerTests.swift:
- Test each credential pattern:
  * Anthropic API keys (sk-ant-*)
  * OpenAI API keys (sk-*)
  * AWS credentials (AKIA*)
  * GitHub tokens (ghp_*, gho_*, ghu_*)
  * Private keys (-----BEGIN RSA PRIVATE KEY-----)
  * JWTs (eyJ*)
  * Connection strings (postgres://, mysql://)
  * Generic password patterns
- Test that partial matches are NOT flagged (e.g., "skeleton" doesn't match "sk-")
- Test redaction: verify the credential is replaced, not just detected
- Test credentials embedded in natural language sentences

TronPipelineTests.swift:
- Test screenInbound() with clean messages → passes through
- Test screenInbound() with injections → flagged with correct severity
- Test screenOutbound() with clean responses → passes through
- Test screenOutbound() with credentials → redacted
- Test that screening order is correct (crisis before injection if applicable)
- Test logging behavior (events logged, sensitive data excluded from logs)

### For Memory Tests (Priority 2 — Target 80%+)

FactRetrieverTests.swift:
- Test keyword-based retrieval returns relevant facts
- Test relevance scoring (more relevant facts ranked higher)
- Test retrieval with no matching facts → empty array
- Test retrieval with access tracking (access count incremented)
- Test retrieval limit (max facts returned)
- Test retrieval excludes soft-deleted facts

FactExtractorTests.swift:
- Test extraction of different fact categories from conversation text
- Test that extracted facts have correct category classification
- Test that credentials mentioned in conversation are NOT stored as facts
- Test empty conversation → no facts extracted
- Test duplicate detection during extraction

### For LLM Tests (Priority 3 — Target 80%+)

ContextBuilderTests.swift:
- Test system prompt is always first in the message array
- Test facts are included in context when available
- Test session history is included
- Test token budget is respected (messages trimmed when too long)
- Test with no facts, no history → minimal context
- Test with very long history → oldest messages trimmed

TokenCounterTests.swift:
- Test counting for short strings
- Test counting for long strings
- Test counting for empty strings
- Test that estimates are within reasonable bounds of actual token counts

RetryHandlerTests.swift:
- Test successful call on first try → no retries
- Test retry on transient error → succeeds on retry
- Test max retries exceeded → throws final error
- Test exponential backoff timing
- Test non-retryable errors → immediate failure (no retry)

CircuitBreakerTests.swift:
- Test closed state → passes through
- Test too many failures → opens circuit
- Test open circuit → rejects immediately
- Test half-open → allows one test request
- Test successful test request → closes circuit
- Test failed test request → re-opens circuit

### For Core Tests (Priority 4 — Target 70%+)

PhoneNumberFilterTests.swift:
- Test authorized number → allowed
- Test unauthorized number → rejected
- Test number with different formatting (+1, (555), etc.) → normalized and matched
- Test empty number → rejected
- Test adding/removing authorized numbers
- Test case with no authorized numbers configured

SessionManagerTests.swift:
- Test new session creation
- Test existing session retrieval
- Test session staleness detection
- Test adding messages to session
- Test session message count
- Test concurrent sessions for different phone numbers

### For Other Modules (Priority 5-8)

DatabaseManagerTests.swift:
- Test database creation (in-memory)
- Test table creation
- Test insert and query
- Test parameterized queries (SQL injection prevention)
- Test transaction commit and rollback
- Test error handling for invalid SQL

SystemPromptBuilderTests.swift:
- Test prompt includes Ember identity
- Test verbosity instruction is injected correctly
- Test facts section is included when facts provided
- Test prompt length is within token budget

AppStateTests.swift:
- Test initial state is correct
- Test state transitions (launching → ready, ready → error, etc.)
- Test state change notifications

## Rules for All Tests

1. Each test must be independent — no shared mutable state
2. Use setUp() and tearDown() for clean state
3. All database operations use in-memory SQLite (":memory:")
4. Test naming: test_[scenario]_[expectedBehavior]
5. No force unwraps in test assertions (use XCTUnwrap instead)
6. Mock all external dependencies (no real API calls, no file system)
7. Keep each test focused on one behavior
8. Include descriptive failure messages in XCTAssert calls
9. If a test file already exists in tests/, ADD to it rather than replacing it
10. Check for existing test files before creating new ones

## Final Checks

Before finishing, verify:
1. All files compile without errors (`swift build`)
2. All tests pass (`swift test`)
3. No calls to Process(), /bin/bash, or shell execution
4. Each module has tests covering happy path, error cases, and edge cases
5. All tests use in-memory databases
6. Test file names match the convention: [ClassName]Tests.swift
7. Existing tests are not broken or duplicated
```

---

## Acceptance Criteria

- [ ] `tests/UnitTests/` directory exists with subdirectories matching src/ structure
- [ ] Security module tests exist and cover 90%+ of InjectionScanner, CredentialScanner, TronPipeline
- [ ] Memory module tests exist and cover 80%+ of FactStore, FactRetriever, FactExtractor
- [ ] LLM module tests exist and cover 80%+ of ContextBuilder, TokenCounter, RetryHandler, CircuitBreaker
- [ ] Core module tests exist and cover 70%+ of SessionManager, PhoneNumberFilter, MessageCoordinator
- [ ] Database module tests exist and cover 70%+ of DatabaseManager
- [ ] Personality module tests exist and cover 60%+ of SystemPromptBuilder, VerbosityAdapter
- [ ] App module tests exist and cover 50%+ of AppState
- [ ] Every test file covers: happy path, error cases, edge cases, boundary conditions
- [ ] All tests are independent (no shared mutable state between tests)
- [ ] All database tests use in-memory SQLite
- [ ] No force unwraps in production code assertions
- [ ] No calls to `Process()`, `/bin/bash`, or shell execution
- [ ] `swift build` succeeds
- [ ] `swift test` passes all unit tests
- [ ] Existing tests from prior tasks are not broken or duplicated

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify test directory structure exists
test -d tests/UnitTests/Security && echo "Security tests dir exists" || echo "MISSING"
test -d tests/UnitTests/Memory && echo "Memory tests dir exists" || echo "MISSING"
test -d tests/UnitTests/Core && echo "Core tests dir exists" || echo "MISSING"
test -d tests/UnitTests/LLM && echo "LLM tests dir exists" || echo "MISSING"
test -d tests/UnitTests/Database && echo "Database tests dir exists" || echo "MISSING"
test -d tests/UnitTests/Personality && echo "Personality tests dir exists" || echo "MISSING"

# Count test files
find tests/UnitTests -name "*Tests.swift" | wc -l

# Verify no shell execution
grep -rn "Process()" tests/UnitTests/ || echo "PASS: No Process() calls"
grep -rn "/bin/bash" tests/UnitTests/ || echo "PASS: No /bin/bash references"

# Build the project
swift build 2>&1

# Run all tests
swift test 2>&1

# Run unit tests only
swift test --filter "UnitTests" 2>&1

# Generate coverage report (if xcodebuild is available)
xcodebuild test -scheme EmberHearth -enableCodeCoverage YES -resultBundlePath TestResults.xcresult 2>&1 || echo "Use swift test if xcodebuild not configured"
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the unit test expansion created in task 0801 for EmberHearth. This task added tests across all modules to reach 60%+ overall coverage. Check for these issues:

Open each test file in tests/UnitTests/ and the corresponding source file in src/.

1. **COVERAGE COMPLETENESS (Critical):**
   For each module, verify the tests cover:
   - Happy path (normal operation)
   - Error cases (invalid input, missing data, failure conditions)
   - Edge cases (empty strings, nil values, very long strings, special characters)
   - Boundary conditions (exactly at limits, one over/under limits)

   Specifically check:
   - Security: Are ALL injection patterns tested? ALL credential formats?
   - Memory: Are all CRUD operations tested? Search? Duplicate detection?
   - LLM: Is token counting tested? Context truncation? Retry with backoff?
   - Core: Is phone number normalization tested? Session staleness?

2. **TEST QUALITY (Critical):**
   - Are assertions specific and meaningful (not just "not nil")?
   - Do error case tests verify the correct error type/message?
   - Are there any tests that could pass even with buggy code (weak assertions)?
   - Do tests verify side effects where appropriate?
   - Are failure messages descriptive enough to diagnose issues?

3. **TEST ISOLATION (Important):**
   - Does each test have its own setUp/tearDown?
   - Are there any order-dependent tests?
   - Do all tests use in-memory databases?
   - Could any test leave global state that affects others?

4. **NO REGRESSIONS (Critical):**
   - Are existing tests from prior tasks still present and unmodified?
   - Do the new tests conflict with any existing test names?
   - Does `swift test` still pass all tests including integration tests?

5. **CODE QUALITY:**
   - PascalCase for all test file names
   - test_[scenario]_[expectedBehavior] naming convention
   - No Process(), /bin/bash, or shell execution
   - Documentation comments on test classes
   - XCTUnwrap used instead of force unwraps

6. **COVERAGE ESTIMATE:**
   For each module, estimate whether the tests likely achieve the target coverage:
   - Security: 90%+ ?
   - Memory: 80%+ ?
   - LLM: 80%+ ?
   - Core: 70%+ ?
   - Database: 70%+ ?
   - Personality: 60%+ ?
   - App: 50%+ ?
   - Overall: 60%+ ?

Report any modules that appear to be under their target coverage with specific suggestions for additional tests.

Report all issues with severity: CRITICAL (must fix), IMPORTANT (should fix), or MINOR (nice to have).
```

---

## Commit Message

```
test: expand unit test coverage to 60%+ across all modules
```

---

## Notes for Next Task

- The unit test files in `tests/UnitTests/` follow the same directory structure as `src/`. This pattern should be maintained for any future source files.
- Mock objects from `tests/IntegrationTests/TestHelpers.swift` (task 0800) can be reused in unit tests. Import them or create lighter-weight mocks specific to each unit test if the integration mocks are too heavy.
- If `swift test` shows coverage below 60%, the next step is to identify the largest uncovered code paths and add targeted tests.
- The security tests here overlap somewhat with task 0802 (security penetration tests). Task 0802 focuses on adversarial scenarios with larger payload libraries, while this task focuses on code path coverage.
- Any new source files added in future tasks should have corresponding test files added to `tests/UnitTests/` following this pattern.
