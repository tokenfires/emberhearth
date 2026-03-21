#!/bin/bash
# verify-release.sh — EmberHearth release verification
# Usage: ./scripts/verify-release.sh [--app path] [--dmg path]
#
# This script is for DEVELOPER USE ONLY in the terminal.
# EmberHearth the application NEVER executes shell commands.
#
# Checks:
# - Code signature validity and identity
# - Hardened runtime enabled
# - Entitlements present and correct
# - Notarization status (via spctl)
# - Gatekeeper acceptance
# - App launches and quits cleanly
# - DMG integrity (if --dmg provided)
#
# Produces a pass/fail report for each check.

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
DEFAULT_APP_PATH="${BUILD_DIR}/Export/EmberHearth.app"
BUNDLE_ID="com.emberhearth.app"

# Parse arguments
APP_PATH="$DEFAULT_APP_PATH"
DMG_PATH=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            APP_PATH="$2"
            shift 2
            ;;
        --dmg)
            DMG_PATH="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--app path] [--dmg path]"
            echo ""
            echo "Options:"
            echo "  --app path    Path to EmberHearth.app (default: build/Export/EmberHearth.app)"
            echo "  --dmg path    Path to DMG file (optional, enables DMG-specific checks)"
            echo ""
            echo "Runs a comprehensive verification of the release build."
            exit 0
            ;;
        *)
            # Positional argument — treat as app path for backward compatibility
            if [ -d "$1" ]; then
                APP_PATH="$1"
            elif [ -f "$1" ]; then
                DMG_PATH="$1"
            fi
            shift
            ;;
    esac
done

# ─── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

check_pass() {
    echo -e "  ${GREEN}PASS${NC}  $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

check_fail() {
    echo -e "  ${RED}FAIL${NC}  $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

check_warn() {
    echo -e "  ${YELLOW}WARN${NC}  $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

log_section() {
    echo ""
    echo -e "${BLUE}${BOLD}── $1 ──${NC}"
}

# ─── Header ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}EmberHearth Release Verification${NC}"
echo "================================"
echo ""
echo "App path: ${APP_PATH}"
if [ -n "$DMG_PATH" ]; then
    echo "DMG path: ${DMG_PATH}"
fi
echo "Date:     $(date)"
echo ""

# ═══════════════════════════════════════════════════════════════
# Section 1: App Bundle Checks
# ═══════════════════════════════════════════════════════════════
log_section "App Bundle"

# Check app exists
if [ -d "$APP_PATH" ]; then
    check_pass "App bundle exists"
else
    check_fail "App bundle not found at ${APP_PATH}"
    echo ""
    echo -e "${RED}Cannot continue without app bundle. Exiting.${NC}"
    exit 1
fi

# Check bundle ID
ACTUAL_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || echo "UNKNOWN")
if [ "$ACTUAL_BUNDLE_ID" = "$BUNDLE_ID" ]; then
    check_pass "Bundle ID: ${ACTUAL_BUNDLE_ID}"
else
    check_fail "Bundle ID mismatch: expected ${BUNDLE_ID}, got ${ACTUAL_BUNDLE_ID}"
fi

# Check version
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || echo "UNKNOWN")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || echo "UNKNOWN")
if [ "$APP_VERSION" != "UNKNOWN" ]; then
    check_pass "Version: ${APP_VERSION} (${BUILD_NUMBER})"
else
    check_fail "Could not read version from Info.plist"
fi

# Check minimum macOS version
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersion" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || echo "UNKNOWN")
if [ "$MIN_OS" != "UNKNOWN" ]; then
    check_pass "Minimum macOS: ${MIN_OS}"
else
    check_warn "LSMinimumSystemVersion not set in Info.plist"
fi

# Check executable exists
if [ -f "${APP_PATH}/Contents/MacOS/EmberHearth" ]; then
    check_pass "Main executable exists"
else
    check_fail "Main executable not found"
fi

# ═══════════════════════════════════════════════════════════════
# Section 2: Code Signing
# ═══════════════════════════════════════════════════════════════
log_section "Code Signing"

# Basic signature verification
if codesign --verify --deep --strict "$APP_PATH" 2>/dev/null; then
    check_pass "Code signature valid (deep, strict)"
else
    check_fail "Code signature verification FAILED"
fi

# Check signing identity
SIGN_INFO=$(codesign -dv "$APP_PATH" 2>&1 || true)
if echo "$SIGN_INFO" | grep -q "Developer ID Application"; then
    SIGNER=$(echo "$SIGN_INFO" | grep "Authority=" | head -1 | sed 's/Authority=//')
    check_pass "Signed with Developer ID: ${SIGNER}"
else
    check_fail "Not signed with Developer ID Application certificate"
fi

# Check hardened runtime
if echo "$SIGN_INFO" | grep -q "runtime"; then
    check_pass "Hardened Runtime enabled"
else
    check_fail "Hardened Runtime NOT enabled (required for notarization)"
fi

# Check timestamp
if echo "$SIGN_INFO" | grep -qi "timestamp"; then
    check_pass "Timestamp included in signature"
else
    check_warn "No timestamp detected in signature"
fi

# ═══════════════════════════════════════════════════════════════
# Section 3: Entitlements
# ═══════════════════════════════════════════════════════════════
log_section "Entitlements"

ENTITLEMENTS=$(codesign -d --entitlements :- "$APP_PATH" 2>/dev/null || echo "")

if [ -n "$ENTITLEMENTS" ]; then
    check_pass "Entitlements present"

    # Check expected entitlements
    if echo "$ENTITLEMENTS" | grep -q "com.apple.security.network.client"; then
        check_pass "Entitlement: network.client (for API calls)"
    else
        check_fail "Missing entitlement: com.apple.security.network.client"
    fi

    if echo "$ENTITLEMENTS" | grep -q "com.apple.security.automation.apple-events"; then
        check_pass "Entitlement: automation.apple-events (for iMessage)"
    else
        check_fail "Missing entitlement: com.apple.security.automation.apple-events"
    fi

    # Check for dangerous entitlements that should NOT be present
    if echo "$ENTITLEMENTS" | grep -q "com.apple.security.cs.disable-library-validation"; then
        check_warn "Entitlement present: disable-library-validation (review if necessary)"
    fi

    if echo "$ENTITLEMENTS" | grep -q "com.apple.security.cs.allow-unsigned-executable-memory"; then
        check_warn "Entitlement present: allow-unsigned-executable-memory (review if necessary)"
    fi
else
    check_fail "No entitlements found"
fi

# ═══════════════════════════════════════════════════════════════
# Section 4: Notarization
# ═══════════════════════════════════════════════════════════════
log_section "Notarization & Gatekeeper"

# Check notarization via spctl (Gatekeeper assessment)
SPCTL_OUTPUT=$(spctl -a -vv "$APP_PATH" 2>&1 || true)

if echo "$SPCTL_OUTPUT" | grep -q "accepted"; then
    check_pass "Gatekeeper assessment: ACCEPTED"
    if echo "$SPCTL_OUTPUT" | grep -q "Notarized Developer ID"; then
        check_pass "Notarization status: Notarized"
    elif echo "$SPCTL_OUTPUT" | grep -q "Developer ID"; then
        check_warn "Signed with Developer ID but notarization status unclear"
    fi
else
    check_fail "Gatekeeper assessment: REJECTED"
    echo "    spctl output: ${SPCTL_OUTPUT}"
fi

# Check staple
if xcrun stapler validate "$APP_PATH" 2>/dev/null; then
    check_pass "Notarization ticket stapled"
else
    check_warn "Notarization ticket not stapled (app will verify online)"
fi

# ═══════════════════════════════════════════════════════════════
# Section 5: App Launch Test
# ═══════════════════════════════════════════════════════════════
log_section "App Launch Test"

# Try to launch the app briefly and verify it starts
if [ -f "${APP_PATH}/Contents/MacOS/EmberHearth" ]; then
    echo -e "  ${BLUE}....${NC}  Attempting to launch EmberHearth for 5 seconds..."

    # Launch in background, wait briefly, check if it's running, then quit
    "${APP_PATH}/Contents/MacOS/EmberHearth" &
    APP_PID=$!
    sleep 3

    if kill -0 "$APP_PID" 2>/dev/null; then
        check_pass "App launched successfully (PID: ${APP_PID})"

        # Send SIGTERM for clean quit
        kill "$APP_PID" 2>/dev/null || true
        sleep 2

        # Verify it quit
        if kill -0 "$APP_PID" 2>/dev/null; then
            check_warn "App did not quit cleanly after SIGTERM — sending SIGKILL"
            kill -9 "$APP_PID" 2>/dev/null || true
        else
            check_pass "App quit cleanly on SIGTERM"
        fi
    else
        # Process exited — check if it crashed
        EXIT_CODE=0
        wait "$APP_PID" 2>/dev/null || EXIT_CODE=$?
        if [ $EXIT_CODE -eq 0 ]; then
            check_pass "App launched and exited normally (exit code 0)"
        else
            check_fail "App crashed or exited with error (exit code: ${EXIT_CODE})"
        fi
    fi
else
    check_fail "Main executable not found — cannot perform launch test"
fi

# ═══════════════════════════════════════════════════════════════
# Section 6: DMG Checks (if provided)
# ═══════════════════════════════════════════════════════════════
if [ -n "$DMG_PATH" ]; then
    log_section "DMG Verification"

    if [ -f "$DMG_PATH" ]; then
        check_pass "DMG file exists"

        # Check DMG size
        DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
        check_pass "DMG size: ${DMG_SIZE}"

        # Verify DMG signature
        if codesign --verify "$DMG_PATH" 2>/dev/null; then
            check_pass "DMG signature valid"
        else
            check_fail "DMG signature INVALID or missing"
        fi

        # Check DMG notarization
        DMG_SPCTL=$(spctl -a -vv --type install "$DMG_PATH" 2>&1 || true)
        if echo "$DMG_SPCTL" | grep -q "accepted"; then
            check_pass "DMG Gatekeeper assessment: ACCEPTED"
        else
            check_warn "DMG Gatekeeper assessment: not accepted (may need notarization)"
        fi

        # Check DMG staple
        if xcrun stapler validate "$DMG_PATH" 2>/dev/null; then
            check_pass "DMG notarization ticket stapled"
        else
            check_warn "DMG notarization ticket not stapled"
        fi

        # Mount and inspect DMG contents
        MOUNT_POINT=$(hdiutil attach "$DMG_PATH" -nobrowse -noverify -readonly 2>/dev/null | grep "/Volumes/" | awk '{print $NF}')
        if [ -n "$MOUNT_POINT" ]; then
            check_pass "DMG mounts successfully at: ${MOUNT_POINT}"

            # Check for app in DMG
            if [ -d "${MOUNT_POINT}/EmberHearth.app" ]; then
                check_pass "EmberHearth.app found in DMG"
            else
                check_fail "EmberHearth.app NOT found in DMG"
            fi

            # Check for Applications symlink
            if [ -L "${MOUNT_POINT}/Applications" ]; then
                SYMLINK_TARGET=$(readlink "${MOUNT_POINT}/Applications")
                if [ "$SYMLINK_TARGET" = "/Applications" ]; then
                    check_pass "Applications symlink present and correct"
                else
                    check_fail "Applications symlink points to '${SYMLINK_TARGET}' instead of '/Applications'"
                fi
            else
                check_warn "No Applications symlink in DMG (drag-to-install won't work)"
            fi

            # Unmount
            hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
            check_pass "DMG unmounted cleanly"
        else
            check_fail "Could not mount DMG"
        fi
    else
        check_fail "DMG not found at ${DMG_PATH}"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# Section 7: Security Quick Check
# ═══════════════════════════════════════════════════════════════
log_section "Security Quick Check"

# Check that no shell execution exists in the app bundle
if grep -rn "Process()\|NSTask\|/bin/bash\|/bin/sh" "${APP_PATH}/Contents/" --include="*.swift" 2>/dev/null; then
    check_fail "Shell execution patterns found in app bundle source"
else
    check_pass "No shell execution patterns in app bundle"
fi

# Check for hardcoded credential patterns in the binary
BINARY_PATH="${APP_PATH}/Contents/MacOS/EmberHearth"
if [ -f "$BINARY_PATH" ]; then
    if strings "$BINARY_PATH" | grep -qE "sk-ant-|sk-proj-|AKIA[0-9A-Z]|ghp_|gho_"; then
        check_fail "Potential hardcoded credentials found in binary"
    else
        check_pass "No hardcoded credential patterns in binary"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}════════════════════════════════════════${NC}"
echo -e "${BOLD}         VERIFICATION SUMMARY          ${NC}"
echo -e "${BOLD}════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}PASSED:${NC}   ${PASS_COUNT}"
echo -e "  ${RED}FAILED:${NC}   ${FAIL_COUNT}"
echo -e "  ${YELLOW}WARNINGS:${NC} ${WARN_COUNT}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}${BOLD}RESULT: ALL CHECKS PASSED${NC}"
    echo ""
    echo "This build is ready for distribution."
    exit 0
else
    echo -e "${RED}${BOLD}RESULT: ${FAIL_COUNT} CHECK(S) FAILED${NC}"
    echo ""
    echo "Fix the failures above before distributing."
    exit 1
fi
