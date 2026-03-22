# Migrating EmberHearth from SPM Package to Xcode Project

The root cause of all signing and launch issues: SPM packages opened in Xcode are always
ad-hoc signed with no entitlements, and Xcode provides no reliable hook to override this.
A proper `.xcodeproj` gives full control over signing, entitlements, and build phases.

---

## Before You Start

- Close Xcode
- Make sure the current code is committed to git (clean working tree)
- Have your Apple Developer account ready in Xcode → Settings → Accounts

---

## Step 1: Create a New Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose **macOS → App**
3. Configure:
   - **Product Name:** `EmberHearth`
   - **Bundle Identifier:** `com.emberhearth.app`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Uncheck** "Include Tests" (we'll add tests back manually)
4. Save location: **outside** the existing `emberhearth/` repo folder (e.g. your Desktop)
   — we'll copy files in next

---

## Step 2: Copy the Generated Project Files

From the new Xcode project folder, copy these into `emberhearth/`:

- `EmberHearth.xcodeproj/` → `emberhearth/EmberHearth.xcodeproj/`
- Delete the auto-generated `EmberHearth/` source folder Xcode created (we'll use existing `src/`)

---

## Step 3: Configure Signing & Capabilities in Xcode

Open `emberhearth/EmberHearth.xcodeproj` in Xcode.

1. Click the **EmberHearth** target → **Signing & Capabilities**
2. Set **Team** to your Apple Developer account
3. Set **Bundle Identifier** to `com.emberhearth.app`
4. Set **Signing Certificate** to `Developer ID Application` (for distribution)
   or `Apple Development` (for local debug — preferred for development)
5. Click **+ Capability** and add:
   - **Hardened Runtime**
   - **App Sandbox** — then uncheck "App Sandbox" immediately after (EmberHearth is not sandboxed — it needs Full Disk Access and Automation which sandbox blocks)

---

## Step 4: Replace the Entitlements File

Xcode generates a default entitlements file. Replace its contents with the existing one:

1. In the Xcode project navigator, find `EmberHearth.entitlements`
2. Replace all content with the contents of `src/EmberHearth.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.temporary-exception.files.absolute-path.read-only</key>
    <array>
        <string>/Users/</string>
    </array>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.emberhearth.app</string>
    </array>
</dict>
</plist>
```

Note: Do **not** add `com.apple.security.get-task-allow` — Xcode injects this automatically
for debug builds when using Apple Development signing.

---

## Step 5: Add Source Files to the Project

1. In Xcode, delete the auto-generated `ContentView.swift` and `EmberHearthApp.swift`
2. **File → Add Files to "EmberHearth"...**
3. Navigate to `emberhearth/src/` and select all folders:
   - `App/`, `Core/`, `Database/`, `LLM/`, `Logging/`, `Memory/`, `Personality/`, `Security/`, `Views/`
4. Options: ✓ **Create groups**, ✓ **Add to target: EmberHearth**
5. Also add `Info.plist` — but do **not** add `EmberHearth.entitlements` this way (it's already set via Signing & Capabilities)

---

## Step 6: Configure Info.plist

1. Click the **EmberHearth** target → **Build Settings**
2. Search for `Info.plist`
3. Set **Info.plist File** to `src/Info.plist`

Then verify `src/Info.plist` has these keys (add if missing):

```xml
<key>NSAppleEventsUsageDescription</key>
<string>EmberHearth needs to send messages via Messages.app.</string>
<key>NSAppleScriptEnabled</key>
<true/>
<key>CFBundleIdentifier</key>
<string>com.emberhearth.app</string>
<key>LSUIElement</key>
<true/>
```

`LSUIElement = true` makes it a menu bar app (no Dock icon).

---

## Step 7: Remove the SPM Entry Point Conflict

The existing `EmberHearthApp.swift` uses `@main`. Xcode projects also set an entry point
via the scheme. They conflict if both are present.

In **Build Settings**, search for `SWIFT_ACTIVE_COMPILATION_CONDITIONS` and verify
`DEBUG` is set for Debug. No changes needed — just confirming the `@main` in
`EmberHearthApp.swift` will be used as-is.

---

## Step 8: Build Settings Cleanup

In **Build Settings**, confirm or set:

| Setting | Value |
|---|---|
| `MACOSX_DEPLOYMENT_TARGET` | `26.0` |
| `SWIFT_VERSION` | `5.9` |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.emberhearth.app` |
| `CODE_SIGN_STYLE` | `Automatic` |
| `DEVELOPMENT_TEAM` | Your team ID (`GPKUTW7B5R`) |

---

## Step 9: Add the Test Target (Optional)

1. **File → New → Target → macOS → Unit Testing Bundle**
2. Name it `EmberHearthTests`
3. **File → Add Files** → select `tests/` folder, add to `EmberHearthTests` target only

---

## Step 10: Delete the SPM Workspace

Once everything builds from the `.xcodeproj`:

1. Delete `.swiftpm/` directory from the repo
2. Delete `Package.swift` (or keep it if you want to retain SPM compatibility — the two can coexist)
3. Update `.gitignore` to exclude `*.xcodeproj/xcuserdata/`

---

## Verifying It Works

After building (CMD+B):

```bash
codesign -dvv /path/to/DerivedData/.../Build/Products/Debug/EmberHearth.app
```

You should see:
- `Authority=Apple Development: ...` (not `adhoc`)
- `com.apple.security.automation.apple-events = true` in entitlements

Then CMD+R should launch the app with the onboarding window appearing.

---

## Why This Fixes Everything

| Problem | SPM cause | Xcode project fix |
|---|---|---|
| No entitlements in binary | SPM excludes `.entitlements` from build | Xcode embeds entitlements via Signing & Capabilities |
| Ad-hoc signing only | SPM has no `CODE_SIGN_IDENTITY` build setting | Xcode uses your Developer certificate automatically |
| Debugger can't attach | `get-task-allow` missing | Xcode injects it for Debug builds automatically |
| App won't launch from CMD+R | LLDB can't attach to ad-hoc binary | Real certificate allows debugger attachment |
| TCC won't prompt for Automation | `apple-events` entitlement not embedded | Entitlement embedded → TCC sees it and prompts |
</content>
</invoke>