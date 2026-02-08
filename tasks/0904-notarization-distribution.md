# Task 0904: Notarization and Distribution Packaging

**Milestone:** M10 - Final Integration
**Unit:** 10.5 - Notarization, DMG Packaging, and Fresh Install Verification
**Phase:** Final
**Depends On:** 0901 (Build Configuration)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; project conventions, security boundaries, naming rules. Pay special attention to the "Security Boundaries" section: scripts created here are developer build tooling (shell scripts are allowed), NOT app runtime code.
2. `docs/deployment/build-and-release.md` — This is the primary reference. Read these sections carefully:
   - Notarization section (lines ~202-250): `xcrun notarytool submit`, `--wait`, keychain credential storage, `xcrun stapler staple`
   - Packaging section (lines ~254-290): DMG creation with `hdiutil`, DMG signing, DMG notarization, ZIP alternative
   - Release Checklist section (lines ~446-486): Pre-release, build, signing, notarization, distribution, and post-release steps
3. `docs/architecture/decisions/0002-distribute-outside-app-store.md` — Read in full (~87 lines). Defines the signing approach: Developer ID Application certificate, notarization required, Sparkle for updates, direct download distribution.

> **Context Budget Note:** `build-and-release.md` is ~525 lines. Focus on lines 202-290 (Notarization + Packaging) and lines 446-486 (Release Checklist). Skip the CI/CD Pipeline and Auto-Updates sections — CI/CD is reference material but not the focus of this task. The ADR-0002 is short (~87 lines); read it entirely for context on why we sign with Developer ID.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are creating the notarization, DMG packaging, and release verification scripts for EmberHearth, a native macOS personal AI assistant distributed outside the Mac App Store (see ADR-0002). These are developer build tooling scripts — shell scripts that the developer runs in their terminal. They are NOT executed by the app at runtime.

## IMPORTANT RULES (from CLAUDE.md)

- Swift files use PascalCase (e.g., AppDelegate.swift)
- NEVER use shell execution IN THE APP (no Process(), no /bin/bash, no NSTask in source code under src/)
- **HOWEVER:** Shell scripts for developer build tooling (scripts/, build.sh, Makefile) ARE allowed — that is exactly what this task creates
- All source files go under src/
- All test files go under tests/
- macOS 13.0+ deployment target
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app") — in Swift code only
- Store credentials ONLY in Keychain — never hardcoded in scripts or source
- PascalCase for Swift files, lowercase-with-hyphens for docs

## PROJECT CONTEXT

EmberHearth is distributed via direct download with Developer ID signing (ADR-0002). The release flow is:

1. Build archive (xcodebuild archive)
2. Export signed app (xcodebuild -exportArchive)
3. Codesign with Developer ID + hardened runtime + timestamp
4. Notarize via xcrun notarytool (Apple's automated malware scan)
5. Staple the notarization ticket to the app
6. Package into a DMG with Applications symlink
7. Sign, notarize, and staple the DMG
8. Verify everything on a clean system
9. Upload to GitHub Releases

All credentials (Apple ID, Team ID, app-specific password) are referenced via environment variables or Keychain — NEVER hardcoded in scripts.

## WHAT YOU ARE BUILDING

Four files:

1. `scripts/notarize.sh` — Automates the full notarization flow
2. `scripts/create-dmg.sh` — Creates a professional DMG package
3. `scripts/verify-release.sh` — Verifies the release build is properly signed, notarized, and functional
4. `docs/deployment/RELEASE-CHECKLIST.md` — Step-by-step human-readable release process

## FILES TO CREATE

### 1. `scripts/notarize.sh`

This script automates the complete notarization pipeline: archive, export, codesign, notarize, staple.

```bash
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
codesign --verify --deep --strict "$APP_PATH"
if [ $? -eq 0 ]; then
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

xcrun stapler staple "$APP_PATH"
if [ $? -eq 0 ]; then
    log_info "Ticket stapled successfully"
else
    log_fatal "Stapling FAILED"
fi

# Verify staple
xcrun stapler validate "$APP_PATH"
if [ $? -eq 0 ]; then
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
echo "  2. Verify:       ./scripts/verify-release.sh ${APP_PATH}"
echo ""
```

### 2. `scripts/create-dmg.sh`

This script creates a professional DMG with the app and an Applications folder symlink.

```bash
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

# Add a background/README if desired (optional, for a professional DMG)
cat > "${DMG_STAGING_DIR}/.background_notice" << 'EOF'
Drag EmberHearth to Applications to install.
EOF

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
codesign --verify "$DMG_PATH"
if [ $? -eq 0 ]; then
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
        xcrun stapler staple "$DMG_PATH"
        if [ $? -eq 0 ]; then
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
```

### 3. `scripts/verify-release.sh`

This script performs a comprehensive verification of the release build.

```bash
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
    log_info_msg="Attempting to launch EmberHearth for 5 seconds..."
    echo -e "  ${BLUE}....${NC}  ${log_info_msg}"

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
        wait "$APP_PID" 2>/dev/null
        EXIT_CODE=$?
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
    if strings "$BINARY_PATH" | grep -q "sk-ant-\|sk-proj-\|AKIA[0-9A-Z]"; then
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
```

### 4. `docs/deployment/RELEASE-CHECKLIST.md`

This is a human-readable step-by-step checklist for performing a release.

```markdown
# EmberHearth Release Checklist

Step-by-step checklist for releasing a new version of EmberHearth.
Follow every step in order. Do not skip steps.

---

## 1. Pre-Release Preparation

### Version Bump
- [ ] Update version in `src/App/AppVersion.swift` (if it exists)
- [ ] Update `CFBundleShortVersionString` in Info.plist (e.g., `1.0.0` -> `1.1.0`)
- [ ] Update `CFBundleVersion` (build number) in Info.plist
- [ ] Verify version matches across all locations: `grep -rn "1.0.0" src/ --include="*.swift"`

### Changelog
- [ ] Update `CHANGELOG.md` with all changes since last release
- [ ] Follow Keep a Changelog format (Added, Changed, Fixed, Removed)
- [ ] Include date in the version header

### Code Quality
- [ ] All tests pass: `./build.sh test`
- [ ] Security check passes: `./build.sh security-check`
- [ ] Full pre-flight passes: `./build.sh all`
- [ ] No hardcoded debug values or test API keys in `src/`
- [ ] No `print()` statements in production code
- [ ] No TODO/FIXME without task references

---

## 2. Build

### Clean Release Build
- [ ] Run clean build: `./build.sh clean && ./build.sh release`
- [ ] Verify zero warnings in release build output
- [ ] App runs correctly from build output (manual smoke test)

### Entitlements Verification
- [ ] Verify entitlements: `codesign -d --entitlements :- build/Export/EmberHearth.app`
- [ ] Confirm `com.apple.security.network.client` present
- [ ] Confirm `com.apple.security.automation.apple-events` present
- [ ] Confirm no unexpected or overly broad entitlements

---

## 3. Notarize

### Prerequisites
- [ ] Developer ID Application certificate installed in Keychain
- [ ] App-specific password stored in Keychain:
  ```bash
  xcrun notarytool store-credentials "AC_PASSWORD" \
      --apple-id "your@email.com" \
      --team-id "YOUR_TEAM_ID" \
      --password "xxxx-xxxx-xxxx-xxxx"
  ```

### Run Notarization
- [ ] Set credentials: `export KEYCHAIN_PROFILE=AC_PASSWORD`
- [ ] Run notarization script: `./scripts/notarize.sh`
- [ ] Verify output shows "Notarization ACCEPTED"
- [ ] Verify output shows "Ticket stapled successfully"

### If Notarization Fails
- [ ] Check the notarization log for specific errors
- [ ] Common fixes:
  - Enable Hardened Runtime in Xcode build settings
  - Add `--options runtime` to codesign command
  - Ensure timestamp is included (`--timestamp` flag)
  - Verify certificate is "Developer ID Application" (not "Mac Developer")

---

## 4. Package

### Create DMG
- [ ] Run DMG script: `./scripts/create-dmg.sh --version X.Y.Z`
- [ ] Verify DMG contains EmberHearth.app
- [ ] Verify DMG contains Applications symlink
- [ ] Verify DMG is signed
- [ ] Verify DMG is notarized and stapled
- [ ] Note the DMG file size for release notes

---

## 5. Verify

### Automated Verification
- [ ] Run verification: `./scripts/verify-release.sh --app build/Export/EmberHearth.app --dmg build/EmberHearth-X.Y.Z.dmg`
- [ ] All checks PASS (zero failures)

### Manual Verification on Clean System
- [ ] Copy DMG to a separate Mac (or a clean user account)
- [ ] Double-click DMG to mount
- [ ] Drag EmberHearth to Applications
- [ ] Launch from Applications folder
- [ ] Verify NO Gatekeeper warning ("app is damaged" or "unidentified developer")
- [ ] Verify the onboarding flow starts correctly
- [ ] Verify the menu bar icon appears
- [ ] Quit the app cleanly

### Smoke Test (on clean install)
- [ ] Enter API key in onboarding
- [ ] Grant Full Disk Access when prompted
- [ ] Grant Automation permission when prompted
- [ ] Send a test iMessage to the registered number
- [ ] Verify Ember responds via iMessage
- [ ] Check Settings UI opens and functions
- [ ] Verify menu bar status shows correct state

---

## 6. Release

### Create Git Tag
- [ ] Commit all version bump changes
- [ ] Create annotated tag: `git tag -a v1.0.0 -m "Release v1.0.0"`
- [ ] Push tag: `git push origin v1.0.0`

### GitHub Release
- [ ] Create GitHub Release:
  ```bash
  gh release create v1.0.0 \
      build/EmberHearth-1.0.0.dmg \
      --title "EmberHearth v1.0.0" \
      --notes-file CHANGELOG.md
  ```
- [ ] Verify the release page shows correctly
- [ ] Download the DMG from the release page and verify it opens

### Release Notes
- [ ] Include: What's new / Changed / Fixed / Known issues
- [ ] Include: System requirements (macOS 13.0+)
- [ ] Include: Installation instructions
- [ ] Include: Required permissions (Full Disk Access, Automation)

---

## 7. Post-Release

### Verification
- [ ] Download DMG from GitHub Releases
- [ ] Install on a clean system
- [ ] Verify full functionality (see Smoke Test above)
- [ ] Monitor for crash reports (first 24-48 hours)

### Documentation
- [ ] Update project README if needed
- [ ] Update documentation site if applicable
- [ ] Close relevant GitHub issues/milestones
- [ ] Update project board status

### If Issues Found Post-Release
- [ ] Document the issue in GitHub Issues
- [ ] Determine severity (critical = hotfix, minor = next release)
- [ ] For critical issues: prepare a patch release (e.g., v1.0.1)
- [ ] Notify users if applicable

---

## Quick Reference: Release Commands

```bash
# Full release flow (after version bump and passing tests)
export KEYCHAIN_PROFILE=AC_PASSWORD

# Step 1: Notarize
./scripts/notarize.sh

# Step 2: Create DMG
./scripts/create-dmg.sh --version 1.0.0

# Step 3: Verify
./scripts/verify-release.sh --app build/Export/EmberHearth.app --dmg build/EmberHearth-1.0.0.dmg

# Step 4: Tag and release
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
gh release create v1.0.0 build/EmberHearth-1.0.0.dmg --title "EmberHearth v1.0.0" --notes-file CHANGELOG.md
```
```

## Ensure Scripts Are Executable

After creating all files, make the scripts executable:

```bash
chmod +x scripts/notarize.sh
chmod +x scripts/create-dmg.sh
chmod +x scripts/verify-release.sh
```

## Implementation Rules

1. These scripts are for DEVELOPER terminal use. They are NOT executed by the app at runtime.
2. All scripts must use `set -euo pipefail` for robust error handling.
3. NEVER hardcode Apple ID, Team ID, or passwords in scripts — use environment variables or Keychain profiles.
4. All scripts must have colored output for clear pass/fail reporting.
5. All scripts must have `--help` options with usage documentation.
6. The `notarize.sh` script must validate all prerequisites before starting the build.
7. The `create-dmg.sh` script must verify the app is signed before creating the DMG.
8. The `verify-release.sh` script must produce a clear pass/fail summary.
9. The release checklist must cover every step from `build-and-release.md` Release Checklist section.
10. DMG must include an Applications folder symlink for drag-to-install.

## Final Checks

Before finishing, verify:
1. All three scripts exist under `scripts/`
2. All scripts are executable (`chmod +x`)
3. All scripts use `set -euo pipefail`
4. No hardcoded credentials anywhere (grep for passwords, API keys)
5. All scripts have `--help` flags
6. `notarize.sh` validates prerequisites before proceeding
7. `create-dmg.sh` creates DMG with Applications symlink
8. `verify-release.sh` produces a clear pass/fail summary
9. `docs/deployment/RELEASE-CHECKLIST.md` covers all release steps
10. All scripts have colored output (PASS=green, FAIL=red, WARN=yellow)
11. Scripts reference the correct paths (`build/Export/EmberHearth.app`, etc.)
12. `notarize.sh` uses `xcrun notarytool submit ... --wait` (not the deprecated `altool`)
```

---

## Acceptance Criteria

### Scripts Exist and Are Executable
- [ ] `scripts/notarize.sh` exists and is executable
- [ ] `scripts/create-dmg.sh` exists and is executable
- [ ] `scripts/verify-release.sh` exists and is executable
- [ ] `docs/deployment/RELEASE-CHECKLIST.md` exists

### Error Handling
- [ ] All scripts use `set -euo pipefail`
- [ ] All scripts validate prerequisites before running (tools exist, files exist, credentials set)
- [ ] All scripts have `--help` flags with usage documentation
- [ ] All scripts exit with non-zero status on failure

### No Credential Leakage
- [ ] **CRITICAL:** No hardcoded Apple ID in any script
- [ ] **CRITICAL:** No hardcoded passwords or app-specific passwords in any script
- [ ] **CRITICAL:** No hardcoded Team ID in any script (except as placeholder comments)
- [ ] Credentials are loaded from environment variables or `--keychain-profile`

### notarize.sh
- [ ] Detects and validates signing identity (Developer ID Application)
- [ ] Validates notarization credentials before starting
- [ ] Builds archive with `xcodebuild archive`
- [ ] Exports app with `xcodebuild -exportArchive`
- [ ] Signs with `codesign --options runtime --timestamp --force --deep`
- [ ] Creates ZIP with `ditto` for notarization submission
- [ ] Submits via `xcrun notarytool submit ... --wait` (NOT deprecated `xcrun altool`)
- [ ] Retrieves log on failure via `xcrun notarytool log`
- [ ] Staples ticket with `xcrun stapler staple`
- [ ] Validates staple with `xcrun stapler validate`
- [ ] Supports `--skip-build` flag for re-notarizing existing builds
- [ ] Colored output for each step (pass/fail)

### create-dmg.sh
- [ ] Verifies app is signed before proceeding
- [ ] Creates staging directory with app and Applications symlink
- [ ] Creates compressed DMG with `hdiutil create ... -format UDZO`
- [ ] Signs the DMG with Developer ID
- [ ] Notarizes the DMG (if credentials available)
- [ ] Staples the DMG
- [ ] Cleans up staging directory after completion
- [ ] Supports `--version` flag for DMG filename
- [ ] Reads version from Info.plist if `--version` not specified
- [ ] Colored output for each step

### verify-release.sh
- [ ] Checks code signature validity (`codesign --verify --deep --strict`)
- [ ] Checks signing identity is Developer ID Application
- [ ] Checks hardened runtime is enabled
- [ ] Checks timestamp is included
- [ ] Checks entitlements are present and correct
- [ ] Checks Gatekeeper acceptance (`spctl -a -vv`)
- [ ] Checks notarization ticket is stapled
- [ ] Performs app launch test (launch, verify running, quit cleanly)
- [ ] Checks DMG contents when `--dmg` provided (app present, Applications symlink)
- [ ] Checks DMG signature and notarization
- [ ] Checks for hardcoded credentials in binary (`strings` check)
- [ ] Produces pass/fail/warn summary with counts
- [ ] Exits with non-zero on any failure

### RELEASE-CHECKLIST.md
- [ ] Covers version bump steps
- [ ] Covers changelog update
- [ ] Covers pre-release code quality checks
- [ ] Covers build steps
- [ ] Covers entitlements verification
- [ ] Covers notarization (including credential setup)
- [ ] Covers DMG packaging
- [ ] Covers automated verification
- [ ] Covers manual verification on clean system
- [ ] Covers smoke test checklist
- [ ] Covers git tag and GitHub Release creation
- [ ] Covers post-release monitoring
- [ ] Includes quick reference command summary

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# ── File Existence ──
echo "=== FILE EXISTENCE ==="
test -f scripts/notarize.sh && echo "PASS: notarize.sh exists" || echo "FAIL: notarize.sh MISSING"
test -f scripts/create-dmg.sh && echo "PASS: create-dmg.sh exists" || echo "FAIL: create-dmg.sh MISSING"
test -f scripts/verify-release.sh && echo "PASS: verify-release.sh exists" || echo "FAIL: verify-release.sh MISSING"
test -f docs/deployment/RELEASE-CHECKLIST.md && echo "PASS: RELEASE-CHECKLIST.md exists" || echo "FAIL: RELEASE-CHECKLIST.md MISSING"

# ── Executable Permissions ──
echo ""
echo "=== EXECUTABLE PERMISSIONS ==="
test -x scripts/notarize.sh && echo "PASS: notarize.sh is executable" || echo "FAIL: notarize.sh not executable"
test -x scripts/create-dmg.sh && echo "PASS: create-dmg.sh is executable" || echo "FAIL: create-dmg.sh not executable"
test -x scripts/verify-release.sh && echo "PASS: verify-release.sh is executable" || echo "FAIL: verify-release.sh not executable"

# ── Error Handling ──
echo ""
echo "=== ERROR HANDLING ==="
grep -l "set -euo pipefail" scripts/notarize.sh scripts/create-dmg.sh scripts/verify-release.sh | wc -l | xargs -I {} echo "Scripts with set -euo pipefail: {}/3"

# ── Help Flags ──
echo ""
echo "=== HELP FLAGS ==="
grep -l "\-\-help" scripts/notarize.sh scripts/create-dmg.sh scripts/verify-release.sh | wc -l | xargs -I {} echo "Scripts with --help: {}/3"

# ── CRITICAL: No Hardcoded Credentials ──
echo ""
echo "=== CREDENTIAL CHECK (CRITICAL) ==="
# Check for hardcoded passwords
grep -rn "xxxx-xxxx-xxxx-xxxx" scripts/ --include="*.sh" | grep -v "^#\|#.*xxxx\|echo\|store-credentials" && echo "FAIL: Hardcoded password found" || echo "PASS: No hardcoded passwords"
# Check for real email addresses (not placeholder comments)
grep -rn "@.*\.com" scripts/ --include="*.sh" | grep -v "^#\|#.*@\|echo.*@\|--apple-id.*\\\$\|noreply" && echo "WARNING: Possible hardcoded email" || echo "PASS: No hardcoded emails"

# ── Correct Tool Usage ──
echo ""
echo "=== TOOL USAGE ==="
# Must use notarytool (not deprecated altool)
grep -l "notarytool" scripts/notarize.sh && echo "PASS: Uses notarytool" || echo "FAIL: Does not use notarytool"
grep -l "altool" scripts/notarize.sh && echo "FAIL: Uses deprecated altool" || echo "PASS: Does not use deprecated altool"

# Must use stapler
grep -l "stapler staple" scripts/notarize.sh && echo "PASS: Uses stapler staple" || echo "FAIL: Does not use stapler staple"

# Must use hdiutil
grep -l "hdiutil create" scripts/create-dmg.sh && echo "PASS: Uses hdiutil create" || echo "FAIL: Does not use hdiutil create"

# Must use spctl
grep -l "spctl" scripts/verify-release.sh && echo "PASS: Uses spctl for Gatekeeper check" || echo "FAIL: Does not use spctl"

# ── DMG Script Checks ──
echo ""
echo "=== DMG SCRIPT ==="
grep -l "Applications" scripts/create-dmg.sh && echo "PASS: References Applications symlink" || echo "FAIL: No Applications symlink"
grep -l "UDZO" scripts/create-dmg.sh && echo "PASS: Uses UDZO compression" || echo "FAIL: Missing UDZO compression"

# ── Verify Script Checks ──
echo ""
echo "=== VERIFY SCRIPT ==="
grep -l "codesign --verify" scripts/verify-release.sh && echo "PASS: Checks codesign" || echo "FAIL: Missing codesign check"
grep -l "entitlements" scripts/verify-release.sh && echo "PASS: Checks entitlements" || echo "FAIL: Missing entitlements check"
grep -l "PASS_COUNT\|FAIL_COUNT" scripts/verify-release.sh && echo "PASS: Has pass/fail counters" || echo "FAIL: Missing pass/fail summary"

# ── Release Checklist ──
echo ""
echo "=== RELEASE CHECKLIST ==="
grep -c "\- \[ \]" docs/deployment/RELEASE-CHECKLIST.md | xargs -I {} echo "Checklist items: {}"
grep -l "Version Bump\|Notariz\|DMG\|Smoke Test\|GitHub Release" docs/deployment/RELEASE-CHECKLIST.md | wc -l | xargs -I {} echo "Key sections covered: {}/1"

# ── Script Help Output ──
echo ""
echo "=== SCRIPT HELP OUTPUT ==="
echo "--- notarize.sh ---"
./scripts/notarize.sh --help 2>&1 | head -5
echo ""
echo "--- create-dmg.sh ---"
./scripts/create-dmg.sh --help 2>&1 | head -5
echo ""
echo "--- verify-release.sh ---"
./scripts/verify-release.sh --help 2>&1 | head -5
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the EmberHearth notarization and distribution packaging scripts for security, correctness, and robustness. Open these files:

@scripts/notarize.sh
@scripts/create-dmg.sh
@scripts/verify-release.sh
@docs/deployment/RELEASE-CHECKLIST.md

Also reference:
@docs/deployment/build-and-release.md
@docs/architecture/decisions/0002-distribute-outside-app-store.md
@CLAUDE.md

## SECURITY AUDIT (Top Priority)

1. **Credential Leakage (CRITICAL):**
   - Search ALL script files for hardcoded passwords, Apple IDs, or Team IDs.
   - Verify credentials are loaded ONLY from environment variables or Keychain profiles.
   - Check that `--password` flags never have literal values (must be variables or `@keychain:` references).
   - Check that log output never prints credential values (passwords, app-specific passwords).
   - Verify that no `.env` file or credentials file is sourced without being in `.gitignore`.

2. **Script Injection (IMPORTANT):**
   - Check that all variable expansions are properly quoted (`"$VAR"` not `$VAR`).
   - Check for command injection vulnerabilities in argument parsing.
   - Verify `eval` is not used anywhere.
   - Check that paths with spaces are handled correctly.

3. **Binary Security Check (IMPORTANT):**
   - Does `verify-release.sh` check the binary for hardcoded credentials using `strings`?
   - Does it check for shell execution patterns in the app bundle?
   - Are the credential patterns comprehensive (sk-ant-, sk-proj-, AKIA, ghp_, gho_)?

## CORRECTNESS

4. **notarize.sh:**
   - Does it use `xcrun notarytool` (NOT the deprecated `xcrun altool`)?
   - Does it use `--wait` flag for synchronous submission?
   - Does it handle both `--keychain-profile` and environment variable authentication?
   - Does it retrieve the notarization log on failure (`xcrun notarytool log`)?
   - Does it properly detect the signing identity from Keychain?
   - Does it create `ExportOptions.plist` if missing?
   - Does it verify the archive and export succeeded before continuing?
   - Is the codesign command correct: `--sign`, `--options runtime`, `--timestamp`, `--force`, `--deep`?
   - Is the staple command correct: `xcrun stapler staple` and `xcrun stapler validate`?

5. **create-dmg.sh:**
   - Does it verify the app is signed before creating the DMG?
   - Does it create an Applications symlink (`ln -s /Applications`)?
   - Does it use `hdiutil create ... -format UDZO` for compressed DMG?
   - Does it sign the DMG with `codesign --sign ... --timestamp`?
   - Does it notarize and staple the DMG?
   - Does it read the version from Info.plist when `--version` is not provided?
   - Does it clean up the staging directory?

6. **verify-release.sh:**
   - Does it check codesign validity (`codesign --verify --deep --strict`)?
   - Does it verify the signing identity is Developer ID Application?
   - Does it check hardened runtime is enabled?
   - Does it check entitlements (network.client, automation.apple-events)?
   - Does it check for dangerous/unexpected entitlements?
   - Does it check Gatekeeper acceptance (`spctl -a -vv`)?
   - Does it check the staple (`xcrun stapler validate`)?
   - Does it perform an app launch test?
   - Does the app launch test handle clean quit (SIGTERM) and fallback to SIGKILL?
   - Does it check DMG contents (app presence, Applications symlink)?
   - Does it mount/unmount the DMG cleanly?
   - Does it produce a clear pass/fail/warn summary?
   - Does it exit with non-zero on failure?

7. **RELEASE-CHECKLIST.md:**
   - Does it cover ALL items from the Release Checklist in `build-and-release.md` (lines 446-486)?
   - Specifically, does it include:
     - Pre-release: tests passing, version bump, changelog, no debug values
     - Build: clean build, app runs, entitlements correct
     - Signing: codesign verification, hardened runtime, timestamp
     - Notarization: submission, ticket stapled, no Gatekeeper warning
     - Distribution: DMG created, uploaded, appcast updated, release notes
     - Post-release: download verification, clean system test, crash monitoring
   - Does it include a quick reference section with all commands?

## ROBUSTNESS

8. **Error Handling:**
   - Do all scripts use `set -euo pipefail`?
   - Do scripts check for required tools (`xcodebuild`, `notarytool`, etc.) before running?
   - Do scripts provide clear error messages with suggested fixes?
   - Do scripts clean up temporary files on exit (ZIP for notarization, staging dir)?

9. **Usability:**
   - Do all scripts have `--help` flags with usage documentation?
   - Is colored output used consistently (green=pass, red=fail, yellow=warn)?
   - Do scripts show progress (step numbers, informational messages)?
   - Are the "Next steps" messages at the end of each script correct?

10. **Compatibility:**
    - Do scripts work with both `.xcworkspace` and `.xcodeproj` projects?
    - Do scripts work when the project root path contains spaces?
    - Is the `--keychain-profile` option spelled correctly (matches `xcrun notarytool` docs)?

Report any issues with specific file paths and line numbers. Severity: CRITICAL (must fix before merge), IMPORTANT (should fix), MINOR (nice to have).
```

---

## Commit Message

```
feat(m10): add notarization, DMG packaging, and release verification scripts
```

---

## Notes for Next Task

- The three scripts (`notarize.sh`, `create-dmg.sh`, `verify-release.sh`) form the complete release pipeline. They are designed to be run in sequence: notarize -> create-dmg -> verify-release.
- Credentials are never hardcoded. The recommended approach is `xcrun notarytool store-credentials` to save credentials in Keychain, then set `KEYCHAIN_PROFILE` environment variable.
- The `verify-release.sh` script includes an app launch test that starts the app, waits 3 seconds, and then sends SIGTERM. If the app requires specific permissions (Full Disk Access, Automation) to launch without crashing, this test may fail on systems without those permissions granted. This is expected behavior.
- The `RELEASE-CHECKLIST.md` includes a manual "clean system test" step that cannot be automated — it requires a separate Mac or user account.
- The `ExportOptions.plist` is auto-created by `notarize.sh` if it doesn't exist. For customized export options (specific provisioning profiles, etc.), create it manually before running the script.
- The DMG created by `create-dmg.sh` is a basic UDZO-compressed DMG. For a more polished DMG with custom backgrounds and icon positioning, consider using a tool like `create-dmg` (npm package) or `dmgbuild` (Python) in a future enhancement.
- These scripts do NOT set up CI/CD. The GitHub Actions workflow in `build-and-release.md` handles CI/CD separately. These scripts are for local developer use.
- Task 0903 (Final Review) should verify that these scripts don't contain any hardcoded credentials before the final release.
