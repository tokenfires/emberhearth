# Task 0002: SwiftUI App Shell with Basic Structure

**Milestone:** M1 - Foundation
**Unit:** 1.2 - Basic SwiftUI App Structure
**Phase:** 1
**Depends On:** Task 0001 (Xcode Project Setup)
**Estimated Effort:** 1-2 hours
**Complexity:** Small

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; core principles (accessibility, Apple quality), naming conventions (PascalCase for Swift)
2. `docs/architecture-overview.md` — Focus on lines 90-121: "Component Detail > 1. EmberHearth.app" for planned file structure (Views/, Services/, Models/)
3. `docs/releases/mvp-scope.md` — Focus on lines 161-207: "MVP Architecture" diagram and "MVP Simplifications" list (single process, no XPC)

> **Context Budget Note:** For architecture-overview.md, only read the "1. EmberHearth.app" section (lines 90-121). Skip everything else. For mvp-scope.md, skip everything after "MVP Simplifications" (line 207).

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are building the SwiftUI app shell for EmberHearth, a native macOS personal AI assistant. Task 0001 has already created the project structure with Package.swift, module directories, and a minimal @main entry point.

Your job is to replace the minimal entry point with a proper SwiftUI app structure that includes an AppDelegate for system integration.

IMPORTANT RULES (from CLAUDE.md):
- Product display name: "EmberHearth"
- Bundle identifier: "com.emberhearth.app"
- Swift files use PascalCase
- All UI MUST include VoiceOver accessibility labels
- Follow Apple Human Interface Guidelines
- Support light and dark mode via @Environment(\.colorScheme)
- Security first: never implement shell execution

WHAT EXISTS (from Task 0001):
- Package.swift at project root
- src/App/EmberHearthApp.swift (minimal @main — you will REPLACE this)
- src/App/AppModule.swift (placeholder — leave it alone)
- Module directories: src/Core/, src/Database/, src/LLM/, src/Memory/, src/Personality/, src/Security/, src/Views/, src/Logging/
- src/EmberHearth.entitlements and src/Info.plist (excluded from build)

STEP 1: Replace src/App/EmberHearthApp.swift

Replace the entire contents of this file. The new version should:
- Use @main attribute with SwiftUI App lifecycle
- Use NSApplicationDelegateAdaptor to bridge to an AppDelegate
- Define a single WindowGroup scene
- Show ContentView as the root view

File: src/App/EmberHearthApp.swift
```swift
// EmberHearthApp.swift
// EmberHearth
//
// Main entry point for the EmberHearth macOS application.
// Uses SwiftUI App lifecycle with NSApplicationDelegateAdaptor
// for system-level integration (menu bar, launch agent, etc.).

import SwiftUI

@main
struct EmberHearthApp: App {

    /// Bridge to AppDelegate for system integration (menu bar, notifications, etc.)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, minHeight: 300)
                .frame(idealWidth: 500, idealHeight: 400)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 500, height: 400)
    }
}
```

STEP 2: Create src/App/AppDelegate.swift

This AppDelegate provides hooks for system-level integration. For now it is minimal, but it will be expanded in Task 0003 (menu bar) and beyond.

File: src/App/AppDelegate.swift
```swift
// AppDelegate.swift
// EmberHearth
//
// NSApplicationDelegate for system-level integration.
// Manages app lifecycle events, menu bar presence (future),
// and other system hooks that SwiftUI doesn't directly support.

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure the app as an accessory application.
        // LSUIElement is set in Info.plist, but we also set the activation policy
        // programmatically to ensure the app runs without a Dock icon.
        NSApp.setActivationPolicy(.accessory)

        // Bring the main window to front on first launch
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean shutdown: flush pending writes, close database connections.
        // Placeholder for future cleanup logic.
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        // Do NOT quit when the window is closed. EmberHearth runs in the background
        // as a menu bar app. The user quits via the menu bar dropdown.
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When the user clicks the app in Finder or Spotlight, show the main window.
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
}
```

STEP 3: Create src/Views/ContentView.swift

This is the main window content. For now it shows a simple welcome screen. It will be replaced with the real settings/onboarding UI in later tasks.

File: src/Views/ContentView.swift
```swift
// ContentView.swift
// EmberHearth
//
// Root content view for the EmberHearth main window.
// Displays a welcome/status screen. Will be replaced with
// settings and onboarding views in later milestones.

import SwiftUI

struct ContentView: View {

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            // App icon area
            Image(systemName: "flame.fill")
                .font(.system(size: 64))
                .foregroundStyle(flameGradient)
                .accessibilityLabel("EmberHearth flame icon")

            // App name
            Text("EmberHearth")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            // Status text (placeholder — will be dynamic in future tasks)
            Text("Your personal AI assistant")
                .font(.title3)
                .foregroundStyle(.secondary)

            Divider()
                .frame(maxWidth: 200)

            // Status indicator (placeholder)
            HStack(spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Status indicator: running")

                Text("Running")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("EmberHearth status: running")
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
    }

    // MARK: - Styling

    /// Gradient for the flame icon, adapts to color scheme
    private var flameGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [.orange, .red]
                : [.orange, .red.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Background color that adapts to the system color scheme
    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(nsColor: .windowBackgroundColor)
            : Color(nsColor: .windowBackgroundColor)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light Mode") {
    ContentView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    ContentView()
        .preferredColorScheme(.dark)
}
#endif
```

STEP 4: Verify the build

After creating all files, run these commands from the project root (/Users/robault/Documents/GitHub/emberhearth):

```bash
swift build
```

The build must succeed. If it fails, debug the issue. Common problems:
- Multiple @main entry points: Make sure only EmberHearthApp.swift has @main
- Missing import: Ensure AppKit is imported in AppDelegate.swift and SwiftUI in the other files
- File not found: Ensure all files are in the correct paths under src/

IMPORTANT NOTES:
- Do NOT modify Package.swift. It was set up correctly in Task 0001.
- Do NOT modify any module placeholder files (CoreModule.swift, etc.).
- Do NOT create any new directories.
- Do NOT add any third-party dependencies.
- The AppDelegate uses NSApp.setActivationPolicy(.accessory) which matches LSUIElement=true in Info.plist. This makes the app run in the menu bar without a Dock icon.
- applicationShouldTerminateAfterLastWindowClosed returns false because EmberHearth is a background/menu bar app that should keep running when the window is closed.
- All Text and Image elements must have accessibility labels or traits.
- ContentView uses @Environment(\.colorScheme) to adapt styling for light/dark mode.
```

---

## Acceptance Criteria

- [ ] `src/App/EmberHearthApp.swift` uses `@main` with `NSApplicationDelegateAdaptor`
- [ ] `src/App/AppDelegate.swift` exists and implements `NSApplicationDelegate`
- [ ] `src/Views/ContentView.swift` exists with flame icon and app name
- [ ] AppDelegate sets activation policy to `.accessory` (no Dock icon)
- [ ] `applicationShouldTerminateAfterLastWindowClosed` returns `false`
- [ ] ContentView uses `@Environment(\.colorScheme)` for light/dark mode support
- [ ] All visual elements have VoiceOver accessibility labels
- [ ] ContentView has at least one `#Preview` for light and dark mode
- [ ] `swift build` succeeds with no errors
- [ ] No modifications to Package.swift or module placeholder files
- [ ] Only ONE `@main` entry point exists across all Swift files

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify files exist
test -f src/App/EmberHearthApp.swift && echo "EmberHearthApp.swift exists" || echo "MISSING"
test -f src/App/AppDelegate.swift && echo "AppDelegate.swift exists" || echo "MISSING"
test -f src/Views/ContentView.swift && echo "ContentView.swift exists" || echo "MISSING"

# Verify only one @main entry point
grep -r "@main" src/ --include="*.swift" -l

# Verify accessibility labels exist
grep -r "accessibilityLabel\|accessibilityAddTraits\|accessibilityElement" src/Views/ContentView.swift

# Verify colorScheme usage
grep -r "colorScheme" src/Views/ContentView.swift

# Verify activation policy
grep -r "setActivationPolicy.*accessory" src/App/AppDelegate.swift

# Build the project
swift build 2>&1

# Run tests (existing tests from 0001 should still pass)
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the SwiftUI app shell created in task 0002 for EmberHearth. Check for these common Sonnet failure modes:

1. SINGLE @main ENTRY POINT:
   - Run: grep -r "@main" src/ --include="*.swift"
   - There must be EXACTLY one result: src/App/EmberHearthApp.swift
   - If any other file has @main, that's a build-breaking error

2. NSApplicationDelegateAdaptor USAGE:
   - Verify EmberHearthApp.swift uses @NSApplicationDelegateAdaptor(AppDelegate.self)
   - Verify AppDelegate.swift is a class (not struct) that inherits from NSObject and conforms to NSApplicationDelegate
   - Verify AppDelegate is NOT marked with @main (only EmberHearthApp should have it)

3. ACTIVATION POLICY:
   - AppDelegate.applicationDidFinishLaunching must call NSApp.setActivationPolicy(.accessory)
   - This is critical for menu bar behavior — without it, the app shows in the Dock

4. WINDOW CLOSE BEHAVIOR:
   - applicationShouldTerminateAfterLastWindowClosed must return false
   - Without this, closing the settings window kills the entire app

5. ACCESSIBILITY COMPLIANCE:
   - Every Image(systemName:) must have .accessibilityLabel()
   - Every status indicator must be accessible
   - ContentView should use .accessibilityAddTraits(.isHeader) on the title
   - Check for .accessibilityElement(children: .combine) on grouped elements

6. DARK MODE SUPPORT:
   - ContentView must use @Environment(\.colorScheme)
   - The flame gradient should adapt to color scheme
   - No hardcoded colors that would look bad in dark mode

7. IMPORT CORRECTNESS:
   - EmberHearthApp.swift: imports SwiftUI (not AppKit)
   - AppDelegate.swift: imports AppKit and SwiftUI
   - ContentView.swift: imports SwiftUI (not AppKit)

8. BUILD VERIFICATION:
   - Run `swift build` and confirm success
   - Run `swift test` and confirm existing tests still pass
   - Check that no new warnings were introduced

Report any issues found, with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m1): add SwiftUI app shell with AppDelegate and ContentView
```

---

## Notes for Next Task

- The AppDelegate in `src/App/AppDelegate.swift` is where Task 0003 will wire up the StatusBarController. The `applicationDidFinishLaunching` method is the hook point.
- The app already runs as an accessory app (no Dock icon) via both Info.plist LSUIElement and programmatic setActivationPolicy(.accessory). Task 0003 should NOT change this.
- `applicationShouldTerminateAfterLastWindowClosed` returns false. The user will quit via the menu bar dropdown created in Task 0003.
- ContentView is intentionally simple. It will be replaced with a real settings/onboarding UI in later milestones (M7-M8). Task 0003 does not need to modify ContentView.
- The WindowGroup scene is the settings/admin window. The primary UI is iMessage (handled in M2). The menu bar (Task 0003) is the always-visible system presence.
