#!/bin/bash
# notarize.sh — EmberHearth notarization automation
# Usage: ./scripts/notarize.sh [--skip-build] [--archive-path path]
#
# This script is for DEVELOPER USE ONLY in the terminal.
# EmberHearth the application NEVER executes shell commands.
#
# Required environment variables (or Keychain credentials):
#   APPLE_ID         — Your Apple ID email
#   TEAM_ID          — Your Apple Developer Team ID
#   APP_PASSWORD     — App-specific password (or use --keychain-profile)
#
# Alternatively, store credentials in Keychain:
#   xcrun notarytool store-credentials "AC_PASSWORD" \
#       --apple-id "your@email.com" \
#       --team-id "YOUR_TEAM_ID" \
#       --password "xxxx-xxxx-xxxx-xxxx"
#   Then set: KEYCHAIN_PROFILE=AC_PASSWORD

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/EmberHearth.xcarchive"
EXPORT_PATH="${BUILD_DIR}/Export"
APP_PATH="${EXPORT_PATH}/EmberHearth.app"
SCHEME="EmberHearth"
BUNDLE_ID="com.emberhearth.app"
EXPORT_OPTIONS_PLIST="${PROJECT_DIR}/ExportOptions.plist"

# Parse arguments
SKIP_BUILD=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --archive-path)
            ARCHIVE_PATH="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--skip-build] [--archive-path path]"
            echo ""
            echo "Options:"
            echo "  --skip-build       Skip the archive/export step (use existing build)"
            echo "  --archive-path     Path to existing .xcarchive"
            echo ""
            echo "Environment variables:"
            echo "  APPLE_ID           Apple ID email (required unless KEYCHAIN_PROFILE set)"
            echo "  TEAM_ID            Apple Developer Team ID (required unless KEYCHAIN_PROFILE set)"
            echo "  APP_PASSWORD       App-specific password (required unless KEYCHAIN_PROFILE set)"
            echo "  KEYCHAIN_PROFILE   Keychain profile name (alternative to above three)"
            echo "  SIGNING_IDENTITY   Code signing identity (default: auto-detect Developer ID)"
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
NC='\033[0m' # No Color

log_step()  { echo -e "\n${BLUE}${BOLD}==> $1${NC}"; }
log_info()  { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }
log_fatal() { echo -e "${RED}[FATAL]${NC} $1"; exit 1; }

# ─── Prerequisite Checks ─────────────────────────────────────
log_step "Checking prerequisites"

# Verify Xcode command line tools
if ! command -v xcodebuild &>/dev/null; then
    log_fatal "xcodebuild not found. Install Xcode Command Line Tools: xcode-select --install"
fi
log_info "xcodebuild found: $(xcodebuild -version | head -1)"

# Verify notarytool
if ! xcrun notarytool --version &>/dev/null; then
    log_fatal "notarytool not found. Requires Xcode 13+ with command line tools."
fi
log_info "notarytool available"

# Verify signing identity
if [ -n "${SIGNING_IDENTITY:-}" ]; then
    SIGN_ID="$SIGNING_IDENTITY"
else
    SIGN_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    if [ -z "$SIGN_ID" ]; then
        log_fatal "No 'Developer ID Application' certificate found in Keychain. Install your certificate first."
    fi
fi
log_info "Signing identity: ${SIGN_ID}"

# Verify notarization credentials
if [ -n "${KEYCHAIN_PROFILE:-}" ]; then
    NOTARY_AUTH="--keychain-profile ${KEYCHAIN_PROFILE}"
    log_info "Using Keychain profile: ${KEYCHAIN_PROFILE}"
elif [ -n "${APPLE_ID:-}" ] && [ -n "${TEAM_ID:-}" ] && [ -n "${APP_PASSWORD:-}" ]; then
    NOTARY_AUTH="--apple-id ${APPLE_ID} --team-id ${TEAM_ID} --password ${APP_PASSWORD}"
    log_info "Using environment variable credentials (APPLE_ID: ${APPLE_ID})"
else
    log_fatal "Notarization credentials not configured. Set KEYCHAIN_PROFILE or (APPLE_ID + TEAM_ID + APP_PASSWORD)."
fi

# Verify ExportOptions.plist exists (needed for archive export)
if [ "$SKIP_BUILD" = false ] && [ ! -f "$EXPORT_OPTIONS_PLIST" ]; then
    log_warn "ExportOptions.plist not found at ${EXPORT_OPTIONS_PLIST}. Creating default..."
    cat > "$EXPORT_OPTIONS_PLIST" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
PLIST_EOF
    log_info "Created ExportOptions.plist"
fi

# ─── Step 1: Build Archive ───────────────────────────────────
if [ "$SKIP_BUILD" = false ]; then
    log_step "Step 1/5: Building release archive"

    mkdir -p "$BUILD_DIR"

    # Detect project type
    if ls "${PROJECT_DIR}"/*.xcworkspace 1>/dev/null 2>&1; then
        WORKSPACE=$(ls "${PROJECT_DIR}"/*.xcworkspace | head -1)
        BUILD_CMD="xcodebuild -workspace ${WORKSPACE}"
    elif ls "${PROJECT_DIR}"/*.xcodeproj 1>/dev/null 2>&1; then
        PROJECT=$(ls "${PROJECT_DIR}"/*.xcodeproj | head -1)
        BUILD_CMD="xcodebuild -project ${PROJECT}"
    else
        log_fatal "No .xcworkspace or .xcodeproj found in ${PROJECT_DIR}"
    fi

    # Clean
    log_info "Cleaning previous build..."
    $BUILD_CMD -scheme "$SCHEME" clean 2>&1 | tail -3

    # Archive
    log_info "Archiving (this may take a few minutes)..."
    $BUILD_CMD \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        archive 2>&1 | tail -5

    if [ ! -d "$ARCHIVE_PATH" ]; then
        log_fatal "Archive failed — ${ARCHIVE_PATH} not created"
    fi
    log_info "Archive created: ${ARCHIVE_PATH}"

    # Export
    log_step "Step 2/5: Exporting signed app from archive"
    mkdir -p "$EXPORT_PATH"

    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" 2>&1 | tail -5

    if [ ! -d "$APP_PATH" ]; then
        log_fatal "Export failed — ${APP_PATH} not created"
    fi
    log_info "Exported app: ${APP_PATH}"
else
    log_step "Skipping build (--skip-build)"
    if [ ! -d "$APP_PATH" ]; then
        log_fatal "App not found at ${APP_PATH}. Run without --skip-build first."
    fi
    log_info "Using existing app: ${APP_PATH}"
fi

# ─── Step 3: Codesign ────────────────────────────────────────
log_step "Step 3/5: Code signing with hardened runtime"

codesign --sign "$SIGN_ID" \
    --options runtime \
    --timestamp \
    --force \
    --deep \
    "$APP_PATH"

# Verify signature
if codesign --verify --deep --strict "$APP_PATH"; then
    log_info "Code signature verified"
else
    log_fatal "Code signature verification FAILED"
fi

# Display entitlements for manual review
log_info "Entitlements:"
codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | head -20

# ─── Step 4: Notarize ────────────────────────────────────────
log_step "Step 4/5: Submitting for notarization"

# Create ZIP for submission
NOTARIZE_ZIP="${BUILD_DIR}/EmberHearth-notarize.zip"
ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"
log_info "Created submission ZIP: ${NOTARIZE_ZIP}"

# Submit and wait
log_info "Submitting to Apple notary service (this typically takes 2-10 minutes)..."
SUBMIT_OUTPUT=$(xcrun notarytool submit "$NOTARIZE_ZIP" \
    $NOTARY_AUTH \
    --wait 2>&1)

echo "$SUBMIT_OUTPUT"

# Check result
if echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
    log_info "Notarization ACCEPTED"
elif echo "$SUBMIT_OUTPUT" | grep -q "status: Invalid"; then
    log_error "Notarization REJECTED"
    # Extract submission ID for log retrieval
    SUBMISSION_ID=$(echo "$SUBMIT_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')
    if [ -n "$SUBMISSION_ID" ]; then
        log_info "Fetching rejection log..."
        xcrun notarytool log "$SUBMISSION_ID" $NOTARY_AUTH 2>&1
    fi
    log_fatal "Notarization failed. Review the log output above."
else
    log_warn "Unexpected notarization status. Review output above."
    # Attempt to continue — staple may still work if it was accepted
fi

# Clean up submission ZIP
rm -f "$NOTARIZE_ZIP"

# ─── Step 5: Staple ──────────────────────────────────────────
log_step "Step 5/5: Stapling notarization ticket"

if xcrun stapler staple "$APP_PATH"; then
    log_info "Ticket stapled successfully"
else
    log_fatal "Stapling FAILED"
fi

# Verify staple
if xcrun stapler validate "$APP_PATH"; then
    log_info "Staple validation passed"
else
    log_fatal "Staple validation FAILED"
fi

# ─── Summary ─────────────────────────────────────────────────
log_step "Notarization Complete"
echo ""
echo -e "${GREEN}${BOLD}EmberHearth has been signed, notarized, and stapled.${NC}"
echo ""
echo "  App location:  ${APP_PATH}"
echo ""
echo "Next steps:"
echo "  1. Create DMG:   ./scripts/create-dmg.sh"
echo "  2. Verify:       ./scripts/verify-release.sh --app ${APP_PATH}"
echo ""
