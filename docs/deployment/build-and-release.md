# Build and Release Guide

This document describes the build, signing, notarization, and release process for EmberHearth.

## Overview

```
Source Code
    │
    ▼
┌─────────────┐
│   Build     │  Xcode / xcodebuild
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    Sign     │  Developer ID Application
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Notarize   │  Apple's automated scan
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Staple    │  Attach ticket to app
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Package   │  DMG or ZIP
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Release   │  GitHub / Website
└─────────────┘
```

---

## Prerequisites

### Apple Developer Account

Required:
- Apple Developer Program membership ($99/year)
- Developer ID Application certificate
- Developer ID Installer certificate (for PKG, optional)
- App-specific password for notarization

### Development Environment

- Xcode 15.0+ (latest stable recommended)
- macOS 14.0+ (Sonoma) for development
- Command Line Tools installed

### Certificates Setup

1. **Generate Certificate Signing Request:**
   ```bash
   # In Keychain Access: Certificate Assistant → Request from CA
   ```

2. **Create Developer ID Certificate:**
   - Apple Developer Portal → Certificates
   - Create "Developer ID Application" certificate
   - Download and install in Keychain

3. **Verify Installation:**
   ```bash
   security find-identity -v -p codesigning
   # Should show: "Developer ID Application: Your Name (TEAM_ID)"
   ```

---

## Build Configuration

### Xcode Project Settings

**Signing & Capabilities:**
```
Team: Your Team ID
Signing Certificate: Developer ID Application
Provisioning Profile: None (manual signing)
```

**Build Settings:**
```
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = Developer ID Application
DEVELOPMENT_TEAM = YOUR_TEAM_ID
ENABLE_HARDENED_RUNTIME = YES
```

### Entitlements

**EmberHearth.entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <!-- App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- Network (for LLM API) -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- Automation (Messages.app) -->
    <key>com.apple.security.automation.apple-events</key>
    <true/>

    <!-- Keychain Access -->
    <key>com.apple.security.keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.emberhearth.app</string>
    </array>
</dict>
</plist>
```

**Note:** Full Disk Access is a system permission, not an entitlement.

---

## Build Process

### Manual Build

```bash
# Clean build folder
xcodebuild clean -project EmberHearth.xcodeproj -scheme EmberHearth

# Build for release
xcodebuild -project EmberHearth.xcodeproj \
    -scheme EmberHearth \
    -configuration Release \
    -archivePath build/EmberHearth.xcarchive \
    archive

# Export app from archive
xcodebuild -exportArchive \
    -archivePath build/EmberHearth.xcarchive \
    -exportPath build/Export \
    -exportOptionsPlist ExportOptions.plist
```

**ExportOptions.plist:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
```

---

## Code Signing

### Sign the App Bundle

```bash
# Sign with hardened runtime and timestamp
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --options runtime \
    --timestamp \
    --force \
    --deep \
    "build/Export/EmberHearth.app"
```

### Verify Signature

```bash
# Check signature
codesign --verify --deep --strict "build/Export/EmberHearth.app"

# Display signature details
codesign -dv --verbose=4 "build/Export/EmberHearth.app"

# Check entitlements
codesign -d --entitlements :- "build/Export/EmberHearth.app"
```

---

## Notarization

### Submit for Notarization

```bash
# Create ZIP for submission
ditto -c -k --keepParent "build/Export/EmberHearth.app" "build/EmberHearth.zip"

# Submit to Apple (requires app-specific password)
xcrun notarytool submit "build/EmberHearth.zip" \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "@keychain:AC_PASSWORD" \
    --wait
```

**Note:** Store app-specific password in Keychain:
```bash
xcrun notarytool store-credentials "AC_PASSWORD" \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "xxxx-xxxx-xxxx-xxxx"
```

### Check Status

```bash
# Check submission status
xcrun notarytool info <submission-id> \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "@keychain:AC_PASSWORD"

# View detailed log (if issues)
xcrun notarytool log <submission-id> \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "@keychain:AC_PASSWORD"
```

### Staple Ticket

```bash
# Staple notarization ticket to app
xcrun stapler staple "build/Export/EmberHearth.app"

# Verify stapling
xcrun stapler validate "build/Export/EmberHearth.app"
```

---

## Packaging

### Create DMG

```bash
# Create DMG with app and Applications symlink
hdiutil create -volname "EmberHearth" \
    -srcfolder "build/Export/EmberHearth.app" \
    -ov -format UDZO \
    "build/EmberHearth-1.0.0.dmg"

# Sign the DMG
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --timestamp \
    "build/EmberHearth-1.0.0.dmg"

# Notarize the DMG (recommended)
xcrun notarytool submit "build/EmberHearth-1.0.0.dmg" \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "@keychain:AC_PASSWORD" \
    --wait

# Staple the DMG
xcrun stapler staple "build/EmberHearth-1.0.0.dmg"
```

### Alternative: ZIP

```bash
# Create signed ZIP
ditto -c -k --keepParent "build/Export/EmberHearth.app" \
    "build/EmberHearth-1.0.0.zip"

# Note: ZIPs cannot be stapled; notarization verified online
```

---

## CI/CD Pipeline

### GitHub Actions Example

**.github/workflows/release.yml:**
```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4

      - name: Install Certificates
        env:
          CERTIFICATE_BASE64: ${{ secrets.DEVELOPER_ID_CERT }}
          CERTIFICATE_PASSWORD: ${{ secrets.DEVELOPER_ID_PASSWORD }}
        run: |
          # Create temporary keychain
          security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          security default-keychain -s build.keychain
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain

          # Import certificate
          echo "$CERTIFICATE_BASE64" | base64 --decode > certificate.p12
          security import certificate.p12 -k build.keychain \
              -P "$CERTIFICATE_PASSWORD" -T /usr/bin/codesign

          # Allow codesign access
          security set-key-partition-list -S apple-tool:,apple: \
              -s -k "$KEYCHAIN_PASSWORD" build.keychain

      - name: Build
        run: |
          xcodebuild -project EmberHearth.xcodeproj \
              -scheme EmberHearth \
              -configuration Release \
              -archivePath build/EmberHearth.xcarchive \
              archive

      - name: Export
        run: |
          xcodebuild -exportArchive \
              -archivePath build/EmberHearth.xcarchive \
              -exportPath build/Export \
              -exportOptionsPlist ExportOptions.plist

      - name: Notarize
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          TEAM_ID: ${{ secrets.TEAM_ID }}
          APP_PASSWORD: ${{ secrets.APP_SPECIFIC_PASSWORD }}
        run: |
          ditto -c -k --keepParent "build/Export/EmberHearth.app" build/EmberHearth.zip

          xcrun notarytool submit build/EmberHearth.zip \
              --apple-id "$APPLE_ID" \
              --team-id "$TEAM_ID" \
              --password "$APP_PASSWORD" \
              --wait

          xcrun stapler staple "build/Export/EmberHearth.app"

      - name: Create DMG
        run: |
          hdiutil create -volname "EmberHearth" \
              -srcfolder "build/Export/EmberHearth.app" \
              -ov -format UDZO \
              "build/EmberHearth-${{ github.ref_name }}.dmg"

          codesign --sign "Developer ID Application" \
              --timestamp \
              "build/EmberHearth-${{ github.ref_name }}.dmg"

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: build/EmberHearth-${{ github.ref_name }}.dmg
```

### Required Secrets

| Secret | Description |
|--------|-------------|
| `DEVELOPER_ID_CERT` | Base64-encoded .p12 certificate |
| `DEVELOPER_ID_PASSWORD` | Password for .p12 |
| `APPLE_ID` | Apple ID email |
| `TEAM_ID` | Apple Developer Team ID |
| `APP_SPECIFIC_PASSWORD` | App-specific password for notarytool |

---

## Auto-Updates (Sparkle)

### Integration

1. Add Sparkle framework to project
2. Configure appcast URL
3. Set up SUFeedURL in Info.plist

**Info.plist:**
```xml
<key>SUFeedURL</key>
<string>https://emberhearth.app/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_ED25519_PUBLIC_KEY</string>
```

### Generate Update

```bash
# Generate appcast entry
./bin/generate_appcast /path/to/releases/

# Sign update with EdDSA key
./bin/sign_update EmberHearth-1.1.0.dmg
```

### Appcast Format

**appcast.xml:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>EmberHearth Updates</title>
    <item>
      <title>Version 1.1.0</title>
      <pubDate>Wed, 15 Mar 2026 12:00:00 +0000</pubDate>
      <sparkle:version>1.1.0</sparkle:version>
      <sparkle:shortVersionString>1.1.0</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <enclosure url="https://emberhearth.app/releases/EmberHearth-1.1.0.dmg"
                 length="15000000"
                 type="application/octet-stream"
                 sparkle:edSignature="..." />
      <sparkle:releaseNotesLink>
        https://emberhearth.app/releases/1.1.0.html
      </sparkle:releaseNotesLink>
    </item>
  </channel>
</rss>
```

---

## Release Checklist

### Pre-Release

- [ ] All tests passing
- [ ] Version number bumped
- [ ] Changelog updated
- [ ] No hardcoded debug values
- [ ] No test API keys in code

### Build

- [ ] Clean build succeeds
- [ ] App runs correctly from build output
- [ ] All entitlements correct

### Signing

- [ ] Codesign verification passes
- [ ] Hardened Runtime enabled
- [ ] Timestamp included

### Notarization

- [ ] Notarization succeeds
- [ ] Ticket stapled
- [ ] App opens without Gatekeeper warning

### Distribution

- [ ] DMG/ZIP created
- [ ] Upload to GitHub Releases / website
- [ ] Appcast updated (for updates)
- [ ] Release notes published

### Post-Release

- [ ] Verify download works
- [ ] Test fresh install on clean system
- [ ] Monitor for crash reports
- [ ] Update documentation if needed

---

## Troubleshooting

### Notarization Failures

**"The signature of the binary is invalid"**
- Ensure Hardened Runtime is enabled
- Check timestamp is included
- Verify certificate is Developer ID (not Mac Developer)

**"The executable does not have the hardened runtime enabled"**
- Add `--options runtime` to codesign command
- Enable in Xcode: Signing & Capabilities → Hardened Runtime

**"The binary uses an SDK older than the 10.9 SDK"**
- Update deployment target
- Rebuild with current SDK

### Gatekeeper Issues

**"App is damaged and can't be opened"**
- Usually means notarization failed or wasn't stapled
- Check: `spctl -a -vv EmberHearth.app`

**"App downloaded from the Internet"**
- Normal for first launch of notarized but unstapled apps
- Stapling avoids this by embedding ticket

---

## References

- [Notarizing macOS Software Before Distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Sparkle Framework](https://sparkle-project.org/)
- ADR-0002 — Distribute Outside App Store
- `docs/research/security.md` — Security architecture details
