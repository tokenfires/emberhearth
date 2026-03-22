# Task 0901: Build Configuration and Scripts

**Milestone:** M10 - Crisis Safety & Compliance
**Unit:** 10.2 - Build Configuration, Code Signing, and Scheme Setup
**Phase:** Final
**Depends On:** 0900 (Crisis Safety)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions, security boundaries (especially the "Never do" list regarding credentials)
2. `docs/deployment/build-and-release.md` — Read the "Build Configuration" section (lines ~79-128) for Xcode project settings, entitlements, and signing configuration
3. `docs/architecture/decisions/` — Check for ADR-0002 (Distribute Outside App Store) if it exists; it defines the signing approach
4. `.gitignore` — Read entirely; verify build artifacts are excluded
5. `Package.swift` — If it exists, read entirely; understand the Swift package structure

> **Context Budget Note:** `build-and-release.md` is ~525 lines. Focus on lines 79-169 (Build Configuration and Build Process). Skip the Notarization, Packaging, CI/CD, and Auto-Updates sections — those are for later.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are finalizing the build configuration and creating build scripts for EmberHearth, a native macOS personal AI assistant. This task ensures the project builds cleanly, has proper signing configuration, and provides convenient build/test commands for development.

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., AppDelegate.swift)
- NEVER use shell execution IN THE APP (no Process(), no /bin/bash, no NSTask in source code)
- Note: Build scripts (build.sh, Makefile) are for the DEVELOPER's terminal use, not for app runtime
- All source files go under src/
- All test files go under tests/
- Store credentials ONLY in Keychain — never in source code, config files, or plists
- PascalCase for Swift files, lowercase-with-hyphens for docs

## What You Are Building

1. Verify/update the Xcode project build settings
2. Verify/update the entitlements file
3. Create a developer build script (build.sh)
4. Create a Makefile with common targets
5. Update .gitignore for build artifacts
6. Verify no hardcoded secrets in the codebase
7. Create a pre-commit check script
8. Set version numbers

## Important: Xcode Project vs Swift Package

First, determine the project structure:
- If there's a `Package.swift`, the project uses Swift Package Manager
- If there's an `.xcodeproj` or `.xcworkspace`, the project uses Xcode
- If both exist, determine which is the primary build system

Adapt all commands and configurations to match the actual build system.

## Files to Create/Update

### 1. Verify Build Settings

If an Xcode project exists, verify these settings:
```
PRODUCT_BUNDLE_IDENTIFIER = com.emberhearth.app
MACOSX_DEPLOYMENT_TARGET = 13.0
SWIFT_VERSION = 5.9
ENABLE_HARDENED_RUNTIME = YES
CODE_SIGN_STYLE = Manual (for distribution) or Automatic (for development)
CODE_SIGN_IDENTITY = "Developer ID Application" (for distribution)
INFOPLIST_KEY_LSUIElement = YES (menu bar app, no Dock icon)
```

If using Package.swift, verify:
```swift
platforms: [.macOS(.v13)]
```

### 2. Verify Entitlements

Check for or create `EmberHearth.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Automation: Required for sending iMessages via AppleScript -->
    <key>com.apple.security.automation.apple-events</key>
    <true/>

    <!-- File access: Required for reading chat.db -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- Network: Required for Claude API calls -->
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

### 3. Create build.sh

Create `build.sh` at the project root. This is a convenience script for developers — it is NOT executed by the app at runtime.

```bash
#!/bin/bash
# build.sh — EmberHearth developer build script
# Usage: ./build.sh [build|test|clean|release]
#
# This script is for DEVELOPER USE ONLY in the terminal.
# EmberHearth the application NEVER executes shell commands.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
SCHEME="EmberHearth"

# Detect build system
if [ -f "${PROJECT_DIR}/Package.swift" ]; then
    BUILD_SYSTEM="spm"
elif ls "${PROJECT_DIR}"/*.xcodeproj 1>/dev/null 2>&1; then
    BUILD_SYSTEM="xcode"
else
    echo "Error: No Package.swift or .xcodeproj found"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Build ──────────────────────────────────────────────────
cmd_build() {
    log_info "Building EmberHearth (${BUILD_SYSTEM})..."

    if [ "$BUILD_SYSTEM" = "spm" ]; then
        swift build 2>&1
    else
        xcodebuild -scheme "$SCHEME" \
            -configuration Debug \
            -derivedDataPath "${BUILD_DIR}/DerivedData" \
            build 2>&1
    fi

    if [ $? -eq 0 ]; then
        log_info "Build succeeded!"
    else
        log_error "Build failed!"
        exit 1
    fi
}

# ─── Test ───────────────────────────────────────────────────
cmd_test() {
    log_info "Running tests..."

    if [ "$BUILD_SYSTEM" = "spm" ]; then
        swift test 2>&1
    else
        xcodebuild -scheme "$SCHEME" \
            -configuration Debug \
            -derivedDataPath "${BUILD_DIR}/DerivedData" \
            test 2>&1
    fi

    if [ $? -eq 0 ]; then
        log_info "All tests passed!"
    else
        log_error "Tests failed!"
        exit 1
    fi
}

# ─── Clean ──────────────────────────────────────────────────
cmd_clean() {
    log_info "Cleaning build artifacts..."

    if [ "$BUILD_SYSTEM" = "spm" ]; then
        swift package clean 2>&1
        rm -rf .build/
    else
        xcodebuild -scheme "$SCHEME" \
            -derivedDataPath "${BUILD_DIR}/DerivedData" \
            clean 2>&1
    fi

    rm -rf "${BUILD_DIR}"
    log_info "Clean complete!"
}

# ─── Release Build ──────────────────────────────────────────
cmd_release() {
    log_info "Building release configuration..."

    if [ "$BUILD_SYSTEM" = "spm" ]; then
        swift build -c release 2>&1
    else
        xcodebuild -scheme "$SCHEME" \
            -configuration Release \
            -derivedDataPath "${BUILD_DIR}/DerivedData" \
            build 2>&1
    fi

    if [ $? -eq 0 ]; then
        log_info "Release build succeeded!"
    else
        log_error "Release build failed!"
        exit 1
    fi
}

# ─── Security Check ────────────────────────────────────────
cmd_security_check() {
    log_info "Running security checks..."
    local issues=0

    # Check for hardcoded API keys
    if grep -rn "sk-ant-\|sk-proj-\|AKIA\|ghp_\|gho_" src/ --include="*.swift" 2>/dev/null; then
        log_error "Found potential hardcoded API keys in source!"
        issues=$((issues + 1))
    else
        log_info "No hardcoded API keys found in src/"
    fi

    # Check for Process() calls (shell execution)
    if grep -rn "Process()\|/bin/bash\|/bin/sh\|NSTask" src/ --include="*.swift" 2>/dev/null; then
        log_error "Found shell execution in source! This violates security policy."
        issues=$((issues + 1))
    else
        log_info "No shell execution found in src/"
    fi

    # Check for print() statements (should use os.Logger)
    if grep -rn "^[[:space:]]*print(" src/ --include="*.swift" 2>/dev/null; then
        log_warn "Found print() statements in source. Use os.Logger instead."
    fi

    # Check for force unwraps in production code
    if grep -rn "![[:space:]]*$\|!\.self\|!\." src/ --include="*.swift" 2>/dev/null | grep -v "//\|///\|!=\|!=" | head -5; then
        log_warn "Found potential force unwraps in source. Review these carefully."
    fi

    if [ $issues -gt 0 ]; then
        log_error "Security check found $issues issue(s)!"
        exit 1
    else
        log_info "Security check passed!"
    fi
}

# ─── Main ───────────────────────────────────────────────────
case "${1:-build}" in
    build)          cmd_build ;;
    test)           cmd_test ;;
    clean)          cmd_clean ;;
    release)        cmd_release ;;
    security-check) cmd_security_check ;;
    all)
        cmd_security_check
        cmd_build
        cmd_test
        log_info "All checks passed!"
        ;;
    *)
        echo "Usage: $0 {build|test|clean|release|security-check|all}"
        exit 1
        ;;
esac
```

### 4. Create Makefile

Create `Makefile` at the project root:

```makefile
# Makefile — EmberHearth convenience targets
# Usage: make [target]
#
# This Makefile is for DEVELOPER USE ONLY in the terminal.
# EmberHearth the application NEVER executes shell commands.

.PHONY: build test clean release security-check all

# Default target
all: security-check build test

# Build the project (debug configuration)
build:
	@./build.sh build

# Run all tests
test:
	@./build.sh test

# Clean build artifacts
clean:
	@./build.sh clean

# Build release configuration
release:
	@./build.sh release

# Run security checks (no hardcoded keys, no shell execution in src/)
security-check:
	@./build.sh security-check

# Run everything: security check, build, and test
check: all
```

### 5. Update .gitignore

Ensure .gitignore includes these entries. ADD to the existing file, don't replace it:

```
# Build artifacts
build/
.build/
DerivedData/
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/

# IDE files
.idea/
*.swp
*.swo
*~
.vscode/

# macOS system files
.DS_Store
.Spotlight-V100
.Trashes

# Sensitive files
*.env
.env.local
credentials.json
secrets.json

# Test results
TestResults.xcresult
*.xcresult

# Archives
*.xcarchive
```

### 6. Create Pre-Commit Hook Script

Create `scripts/pre-commit-check.sh`:

```bash
#!/bin/bash
# pre-commit-check.sh — Run before committing to verify no secrets in source
#
# Install as a git hook:
#   cp scripts/pre-commit-check.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit

set -e

echo "Running pre-commit security check..."

# Check staged files for API keys
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)

if [ -z "$STAGED_FILES" ]; then
    echo "No Swift files staged, skipping."
    exit 0
fi

ISSUES=0

# Check for hardcoded API keys
for file in $STAGED_FILES; do
    if grep -n "sk-ant-\|sk-proj-\|AKIA[0-9A-Z]\{16\}\|ghp_[A-Za-z0-9]\{36\}\|gho_[A-Za-z0-9]" "$file" 2>/dev/null; then
        echo "ERROR: Potential API key found in $file"
        ISSUES=$((ISSUES + 1))
    fi
done

# Check for Process() or shell execution in src/
for file in $STAGED_FILES; do
    if echo "$file" | grep -q "^src/"; then
        if grep -n "Process()\|NSTask\|/bin/bash\|/bin/sh" "$file" 2>/dev/null; then
            echo "ERROR: Shell execution found in $file"
            ISSUES=$((ISSUES + 1))
        fi
    fi
done

if [ $ISSUES -gt 0 ]; then
    echo "Pre-commit check FAILED: $ISSUES issue(s) found."
    echo "Fix the issues or use --no-verify to skip (not recommended)."
    exit 1
fi

echo "Pre-commit check passed."
exit 0
```

### 7. Version Number Configuration

If Info.plist exists, verify these entries:
```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
<key>CFBundleVersion</key>
<string>1</string>
```

If using Package.swift, add a version constant:
Create or update `src/App/AppVersion.swift`:
```swift
// AppVersion.swift
// EmberHearth
//
// Application version constants.

import Foundation

/// Application version information.
///
/// These constants should be updated for each release.
/// CFBundleShortVersionString and CFBundleVersion in Info.plist
/// must match these values.
enum AppVersion {
    /// The user-facing version number (semantic versioning).
    static let version = "1.0.0"

    /// The internal build number (incremented with each build).
    static let build = "1"

    /// Combined display string: "1.0.0 (1)"
    static var displayString: String {
        "\(version) (\(build))"
    }
}
```

### 8. Verify Build

After all changes, verify:

1. Run `swift build` (or `xcodebuild build`) — should succeed with ZERO warnings
2. Run `swift test` (or `xcodebuild test`) — all tests should pass
3. Run `./build.sh security-check` — should pass
4. Run `./build.sh all` — should pass all stages

If there are build warnings, fix them. Common warnings to resolve:
- Unused imports: Remove them
- Unused variables: Prefix with underscore or remove
- Deprecated API usage: Update to modern equivalent
- Missing return types: Add explicit types

## Implementation Rules

1. The build.sh and Makefile are for DEVELOPER terminal use. They are NOT executed by the app.
2. The pre-commit hook is optional but recommended. Don't force-install it.
3. Do NOT commit any API keys, tokens, or credentials.
4. The version number starts at 1.0.0 for the MVP release.
5. All source code must compile without warnings in both Debug and Release configurations.
6. Ensure build.sh is executable (chmod +x build.sh).
7. The security check script should check both src/ and the root for accidental credential leaks.

## Final Checks

Before finishing, verify:
1. `swift build` or `xcodebuild build` succeeds with zero warnings
2. `swift test` or `xcodebuild test` passes all tests
3. `./build.sh security-check` passes
4. `.gitignore` covers build/, .build/, DerivedData/, .env, credentials.json
5. No hardcoded API keys or credentials anywhere in source
6. No Process() or shell execution in src/ directory
7. Version number is set to 1.0.0
8. build.sh is executable
9. Entitlements file includes automation, file access, and network entitlements
```

---

## Acceptance Criteria

- [ ] Build settings verified (deployment target 13.0, Swift 5.9, hardened runtime)
- [ ] Entitlements file exists with automation, file access, and network entitlements
- [ ] `build.sh` exists and is executable with targets: build, test, clean, release, security-check, all
- [ ] `Makefile` exists with targets: build, test, clean, release, security-check, all
- [ ] `.gitignore` updated to exclude build/, .build/, DerivedData/, .env, credentials.json, test results
- [ ] `scripts/pre-commit-check.sh` exists and checks for API keys and shell execution
- [ ] Version number set to 1.0.0 (build 1)
- [ ] `swift build` succeeds with zero warnings
- [ ] `swift test` passes all tests
- [ ] `./build.sh security-check` passes (no hardcoded keys, no shell execution in src/)
- [ ] No API keys, tokens, or credentials in source code
- [ ] No `Process()`, `/bin/bash`, or shell execution in `src/` directory

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify build script exists and is executable
test -x build.sh && echo "build.sh exists and is executable" || echo "MISSING or not executable"

# Verify Makefile exists
test -f Makefile && echo "Makefile exists" || echo "MISSING"

# Verify pre-commit script exists
test -f scripts/pre-commit-check.sh && echo "Pre-commit script exists" || echo "MISSING"

# Verify .gitignore has build artifacts
grep "build/" .gitignore && echo ".gitignore has build/" || echo "MISSING: build/ in .gitignore"
grep ".env" .gitignore && echo ".gitignore has .env" || echo "MISSING: .env in .gitignore"

# Run security check
./build.sh security-check

# Build
./build.sh build

# Test
./build.sh test

# Full check
./build.sh all

# Verify no hardcoded API keys in source
grep -rn "sk-ant-\|sk-proj-\|AKIA\|ghp_\|gho_" src/ --include="*.swift" && echo "WARNING: Found potential keys!" || echo "PASS: No hardcoded keys"

# Verify no shell execution in source
grep -rn "Process()\|/bin/bash\|/bin/sh\|NSTask" src/ --include="*.swift" && echo "WARNING: Found shell execution!" || echo "PASS: No shell execution"
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the build configuration and scripts created in task 0901 for EmberHearth.

@build.sh
@Makefile
@scripts/pre-commit-check.sh
@.gitignore
@CLAUDE.md (security boundaries)

If they exist, also check:
@EmberHearth.entitlements
@src/App/AppVersion.swift
@Package.swift or the .xcodeproj build settings

1. **BUILD CORRECTNESS (Critical):**
   - Does `swift build` (or xcodebuild) succeed with zero warnings?
   - Does `swift test` (or xcodebuild test) pass all tests?
   - Is the deployment target set to macOS 13.0?
   - Is hardened runtime enabled (required for notarization)?

2. **SECURITY (Critical):**
   - Run `grep -rn "sk-ant-\|sk-proj-\|AKIA\|ghp_" src/` — are there ANY results?
   - Run `grep -rn "Process()\|/bin/bash\|NSTask" src/` — are there ANY results?
   - Does the pre-commit hook check for both API keys and shell execution?
   - Does .gitignore exclude .env, credentials.json, and other sensitive files?
   - Are there any hardcoded test API keys that should be removed?

3. **ENTITLEMENTS (Important):**
   - Does the entitlements file include com.apple.security.automation.apple-events?
   - Does it include network client (for API calls)?
   - Does it include file access (for chat.db)?
   - Are there any unnecessary entitlements that should be removed?

4. **BUILD SCRIPTS (Important):**
   - Is build.sh executable (chmod +x)?
   - Does build.sh correctly detect SPM vs Xcode build system?
   - Does the Makefile correctly delegate to build.sh?
   - Are all script targets documented with usage comments?

5. **VERSION MANAGEMENT (Important):**
   - Is the version set to 1.0.0?
   - Is the build number set to 1?
   - If AppVersion.swift exists, do its constants match Info.plist?

6. **.gitignore COMPLETENESS:**
   - Does it cover build/, .build/, DerivedData/?
   - Does it cover .env, credentials.json, secrets?
   - Does it cover IDE files (.idea/, .vscode/, *.swp)?
   - Does it cover macOS system files (.DS_Store)?
   - Does it cover test results (*.xcresult)?

Report any issues with severity: CRITICAL (must fix), IMPORTANT (should fix), MINOR (nice to have).
```

---

## Commit Message

```
chore: finalize build configuration and scripts
```

---

## Notes for Next Task

- The `build.sh` script auto-detects whether the project uses SPM or Xcode. Task 0902 (app startup wiring) may need to reference specific build targets.
- The `./build.sh all` command runs security check, build, and tests in sequence. This is the recommended pre-commit workflow.
- The pre-commit hook is in `scripts/pre-commit-check.sh`. To install it, copy it to `.git/hooks/pre-commit`. This is optional but recommended.
- The version number is 1.0.0 (build 1). The AppVersion.swift constants should be updated for each release.
- All build artifacts go to `build/` (Xcode) or `.build/` (SPM). Both are in `.gitignore`.
- If any build warnings were found and fixed during this task, note what was changed so task 0903 (final review) can verify the fixes.
