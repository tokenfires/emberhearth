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
- [ ] Include: System requirements (macOS 26.0+)
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
