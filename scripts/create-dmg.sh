#!/bin/bash
# create-dmg.sh — EmberHearth DMG packaging
# Usage: ./scripts/create-dmg.sh [--version X.Y.Z] [--app-path path]
#
# This script is for DEVELOPER USE ONLY in the terminal.
# EmberHearth the application NEVER executes shell commands.
#
# Creates a DMG containing:
# - EmberHearth.app
# - Applications folder symlink (for drag-to-install)
#
# The DMG is then signed, notarized, and stapled.
#
# Required environment variables (same as notarize.sh):
#   KEYCHAIN_PROFILE  — Keychain profile name for notarytool
#   OR
#   APPLE_ID + TEAM_ID + APP_PASSWORD

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
DEFAULT_APP_PATH="${BUILD_DIR}/Export/EmberHearth.app"
DMG_STAGING_DIR="${BUILD_DIR}/dmg-staging"
VOLUME_NAME="EmberHearth"

# Parse arguments
APP_PATH="$DEFAULT_APP_PATH"
VERSION=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --app-path)
            APP_PATH="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--version X.Y.Z] [--app-path path]"
            echo ""
            echo "Options:"
            echo "  --version X.Y.Z    Version number for DMG filename (default: from Info.plist)"
            echo "  --app-path path    Path to EmberHearth.app (default: build/Export/EmberHearth.app)"
            echo ""
            echo "Environment variables (for DMG notarization):"
            echo "  KEYCHAIN_PROFILE   Keychain profile name for notarytool"
            echo "  OR"
            echo "  APPLE_ID           Apple ID email"
            echo "  TEAM_ID            Apple Developer Team ID"
            echo "  APP_PASSWORD       App-specific password"
            echo "  SIGNING_IDENTITY   Code signing identity (default: auto-detect)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
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

log_step()  { echo -e "\n${BLUE}${BOLD}==> $1${NC}"; }
log_info()  { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }
log_fatal() { echo -e "${RED}[FATAL]${NC} $1"; exit 1; }

# ─── Prerequisite Checks ─────────────────────────────────────
log_step "Checking prerequisites"

# Verify app exists
if [ ! -d "$APP_PATH" ]; then
    log_fatal "App not found at ${APP_PATH}. Run notarize.sh first."
fi
log_info "App found: ${APP_PATH}"

# Verify app is signed
if ! codesign --verify --deep --strict "$APP_PATH" 2>/dev/null; then
    log_fatal "App is not properly signed. Run notarize.sh first."
fi
log_info "App is properly signed"

# Verify app is notarized (stapled)
if ! xcrun stapler validate "$APP_PATH" 2>/dev/null; then
    log_warn "App does not have a stapled notarization ticket. DMG will still be created but may trigger Gatekeeper warnings."
fi

# Get version from Info.plist if not specified
if [ -z "$VERSION" ]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || echo "1.0.0")
fi
log_info "Version: ${VERSION}"

DMG_FILENAME="EmberHearth-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_FILENAME}"

# Detect signing identity
if [ -n "${SIGNING_IDENTITY:-}" ]; then
    SIGN_ID="$SIGNING_IDENTITY"
else
    SIGN_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    if [ -z "$SIGN_ID" ]; then
        log_fatal "No 'Developer ID Application' certificate found in Keychain."
    fi
fi
log_info "Signing identity: ${SIGN_ID}"

# Determine notarization auth
NOTARY_AUTH=""
if [ -n "${KEYCHAIN_PROFILE:-}" ]; then
    NOTARY_AUTH="--keychain-profile ${KEYCHAIN_PROFILE}"
elif [ -n "${APPLE_ID:-}" ] && [ -n "${TEAM_ID:-}" ] && [ -n "${APP_PASSWORD:-}" ]; then
    NOTARY_AUTH="--apple-id ${APPLE_ID} --team-id ${TEAM_ID} --password ${APP_PASSWORD}"
else
    log_warn "No notarization credentials configured. DMG will be created and signed but NOT notarized."
fi

# ─── Step 1: Prepare Staging Directory ────────────────────────
log_step "Step 1/4: Preparing DMG contents"

# Clean previous staging
rm -rf "$DMG_STAGING_DIR"
mkdir -p "$DMG_STAGING_DIR"

# Copy app to staging
cp -R "$APP_PATH" "${DMG_STAGING_DIR}/"
log_info "Copied EmberHearth.app to staging"

# Create Applications symlink
ln -s /Applications "${DMG_STAGING_DIR}/Applications"
log_info "Created Applications symlink"

# ─── Step 2: Create DMG ──────────────────────────────────────
log_step "Step 2/4: Creating DMG"

# Remove existing DMG
rm -f "$DMG_PATH"

# Create compressed DMG
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

if [ ! -f "$DMG_PATH" ]; then
    log_fatal "DMG creation failed — ${DMG_PATH} not created"
fi

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
log_info "DMG created: ${DMG_PATH} (${DMG_SIZE})"

# Clean up staging
rm -rf "$DMG_STAGING_DIR"
log_info "Cleaned up staging directory"

# ─── Step 3: Sign DMG ────────────────────────────────────────
log_step "Step 3/4: Signing DMG"

codesign --sign "$SIGN_ID" \
    --timestamp \
    "$DMG_PATH"

# Verify DMG signature
if codesign --verify "$DMG_PATH"; then
    log_info "DMG signature verified"
else
    log_fatal "DMG signature verification FAILED"
fi

# ─── Step 4: Notarize and Staple DMG ─────────────────────────
if [ -n "$NOTARY_AUTH" ]; then
    log_step "Step 4/4: Notarizing DMG"

    log_info "Submitting DMG for notarization (this typically takes 2-10 minutes)..."
    SUBMIT_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
        $NOTARY_AUTH \
        --wait 2>&1)

    echo "$SUBMIT_OUTPUT"

    if echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
        log_info "DMG notarization ACCEPTED"

        # Staple the DMG
        if xcrun stapler staple "$DMG_PATH"; then
            log_info "DMG ticket stapled"
        else
            log_warn "DMG stapling failed — users will need an internet connection to verify"
        fi
    else
        log_error "DMG notarization failed. Users may see Gatekeeper warnings."
        log_warn "The DMG is still usable but not notarized."
    fi
else
    log_step "Step 4/4: Skipping DMG notarization (no credentials configured)"
    log_warn "Set KEYCHAIN_PROFILE or APPLE_ID+TEAM_ID+APP_PASSWORD to enable DMG notarization."
fi

# ─── Summary ─────────────────────────────────────────────────
log_step "DMG Packaging Complete"
echo ""
echo -e "${GREEN}${BOLD}EmberHearth DMG is ready for distribution.${NC}"
echo ""
echo "  DMG:      ${DMG_PATH}"
echo "  Size:     ${DMG_SIZE}"
echo "  Version:  ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Verify:    ./scripts/verify-release.sh --dmg ${DMG_PATH}"
echo "  2. Upload:    gh release create v${VERSION} ${DMG_PATH} --title 'EmberHearth v${VERSION}'"
echo ""
