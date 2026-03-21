#!/bin/bash
# build.sh — EmberHearth developer build script
# Usage: ./build.sh [build|test|clean|release|security-check|all]
#
# This script is for DEVELOPER USE ONLY in the terminal.
# EmberHearth the application NEVER executes shell commands.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Build ──────────────────────────────────────────────────
cmd_build() {
    log_info "Building EmberHearth (Swift Package Manager)..."
    swift build 2>&1
    log_info "Build succeeded!"
}

# ─── Test ───────────────────────────────────────────────────
cmd_test() {
    log_info "Running tests..."
    swift test 2>&1
    log_info "All tests passed!"
}

# ─── Clean ──────────────────────────────────────────────────
cmd_clean() {
    log_info "Cleaning build artifacts..."
    swift package clean 2>&1
    rm -rf .build/
    rm -rf "${BUILD_DIR}"
    log_info "Clean complete!"
}

# ─── Release Build ──────────────────────────────────────────
cmd_release() {
    log_info "Building release configuration..."
    swift build -c release 2>&1
    log_info "Release build succeeded!"
}

# ─── Security Check ────────────────────────────────────────
cmd_security_check() {
    log_info "Running security checks..."
    local issues=0

    # Check for hardcoded API keys (exclude comment lines and pattern/validation strings)
    # Looks for complete key-like values: prefix followed by substantial content
    if grep -rn "sk-ant-api[0-9A-Za-z_-]\{10,\}\|sk-proj-[0-9A-Za-z_-]\{10,\}\|AKIA[A-Z0-9]\{16\}" \
        src/ --include="*.swift" 2>/dev/null | grep -v "^\s*//" | grep -v "pattern:\|regex\|#\""; then
        log_error "Found potential hardcoded API keys in source!"
        issues=$((issues + 1))
    else
        log_info "No hardcoded API keys found in src/"
    fi

    # Check for Process() calls (shell execution) — exclude comment lines
    if grep -rn "Process()\|/bin/bash\|/bin/sh\b\|NSTask" src/ --include="*.swift" 2>/dev/null \
        | grep -v ":[[:space:]]*/[/*]"; then
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
    if grep -rn "![[:space:]]*$\|!\.self\|!\." src/ --include="*.swift" 2>/dev/null | grep -v "//\|///\|!=" | head -5; then
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
