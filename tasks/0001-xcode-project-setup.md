# Task 0001: Xcode Project Setup with Signing Configuration

**Milestone:** M1 - Foundation
**Unit:** 1.1 - Xcode Project with Signing
**Phase:** 1
**Depends On:** None (first task)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; contains naming conventions, security boundaries, project structure, and core principles
2. `docs/architecture-overview.md` — Focus on "Component Detail > 1. EmberHearth.app" (lines ~90-121) for planned file structure, and "System Overview" for component names
3. `docs/releases/mvp-scope.md` — Focus on "Technical Requirements" (lines ~226-243) for minimum system requirements and permissions, and "MVP Architecture" (lines ~161-199) for simplified single-process design
4. `docs/deployment/build-and-release.md` — Focus on "Entitlements" (lines ~98-128) for the exact entitlements XML, and "Build Configuration > Xcode Project Settings" (lines ~79-97) for signing settings

> **Context Budget Note:** architecture-overview.md is 770+ lines. Focus only on lines 90-121 (planned file structure) and lines 574-598 (MVP vs Full System table). The deployment doc is ~525 lines; focus on lines 79-128 (build config and entitlements). Skip CI/CD, Sparkle, and packaging sections entirely.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are setting up the initial Xcode project structure for EmberHearth, a native macOS personal AI assistant app. This is a greenfield project — no code exists yet. You will create the project as a Swift Package Manager project that builds a macOS application.

IMPORTANT RULES (from CLAUDE.md):
- Product display name: "EmberHearth"
- Code/path identifier: "emberhearth"
- Bundle identifier: "com.emberhearth.app"
- Swift files use PascalCase (e.g., EmberHearthApp.swift)
- Doc files use lowercase-with-hyphens
- Security first: never implement shell execution
- All UI must support VoiceOver, Dynamic Type, keyboard navigation
- Follow Apple Human Interface Guidelines

PROJECT REQUIREMENTS:
- macOS 13.0+ (Ventura) deployment target
- Support both Apple Silicon (arm64) and Intel (x86_64) via universal binary
- Swift 5.9+
- SwiftUI App lifecycle

STEP 1: Create Package.swift at the project root (/Users/robault/Documents/GitHub/emberhearth/Package.swift)

The Package.swift should:
- Set swift-tools-version to 5.9
- Package name: "EmberHearth"
- Define a single executable product named "EmberHearth"
- Set the macOS platform to .macOS(.v13)
- Set the target's path to "src"
- Exclude any .entitlements and .plist files from the target sources using `exclude`
- Add a dependency on swift-argument-parser or similar ONLY if needed (for now, no external dependencies)

Here is the exact content for Package.swift:

```swift
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "EmberHearth",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "EmberHearth",
            targets: ["EmberHearth"]
        )
    ],
    targets: [
        .executableTarget(
            name: "EmberHearth",
            path: "src",
            exclude: [
                "EmberHearth.entitlements",
                "Info.plist"
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "EmberHearthTests",
            dependencies: ["EmberHearth"],
            path: "tests"
        )
    ]
)
```

STEP 2: Create the directory structure under src/

Create these directories (they will contain Swift source files in later tasks):

- src/App/           — App entry point, AppDelegate, StatusBarController
- src/Core/          — Message handling, coordination, main processing loop
- src/Database/      — SQLite management, schema, migrations
- src/LLM/           — LLM provider integration (Claude API client)
- src/Memory/        — Fact storage, retrieval, extraction
- src/Personality/   — System prompts, ASV (Affective State Vector)
- src/Security/      — Tron security layer, injection defense
- src/Views/         — SwiftUI views (Settings, Onboarding, etc.)
- src/Logging/       — Logging infrastructure, OSLog wrappers

For each directory, create a placeholder Swift file so the directory is tracked by git AND so the Swift compiler has something to process. Use this exact pattern for each:

File: src/App/AppModule.swift
```swift
// AppModule.swift
// EmberHearth
//
// App entry point, delegates, and system integration.

import Foundation

enum AppModule {
    static let name = "App"
}
```

File: src/Core/CoreModule.swift
```swift
// CoreModule.swift
// EmberHearth
//
// Message handling, coordination, and main processing loop.

import Foundation

enum CoreModule {
    static let name = "Core"
}
```

File: src/Database/DatabaseModule.swift
```swift
// DatabaseModule.swift
// EmberHearth
//
// SQLite management, schema versioning, and migrations.

import Foundation

enum DatabaseModule {
    static let name = "Database"
}
```

File: src/LLM/LLMModule.swift
```swift
// LLMModule.swift
// EmberHearth
//
// LLM provider integration (Claude API, future providers).

import Foundation

enum LLMModule {
    static let name = "LLM"
}
```

File: src/Memory/MemoryModule.swift
```swift
// MemoryModule.swift
// EmberHearth
//
// Fact storage, retrieval, and extraction.

import Foundation

enum MemoryModule {
    static let name = "Memory"
}
```

File: src/Personality/PersonalityModule.swift
```swift
// PersonalityModule.swift
// EmberHearth
//
// System prompts, personality traits, and Affective State Vector.

import Foundation

enum PersonalityModule {
    static let name = "Personality"
}
```

File: src/Security/SecurityModule.swift
```swift
// SecurityModule.swift
// EmberHearth
//
// Tron security layer, injection defense, credential detection.

import Foundation

enum SecurityModule {
    static let name = "Security"
}
```

File: src/Views/ViewsModule.swift
```swift
// ViewsModule.swift
// EmberHearth
//
// SwiftUI views for settings, onboarding, and status.

import Foundation

enum ViewsModule {
    static let name = "Views"
}
```

File: src/Logging/LoggingModule.swift
```swift
// LoggingModule.swift
// EmberHearth
//
// Logging infrastructure using OSLog.

import Foundation

enum LoggingModule {
    static let name = "Logging"
}
```

STEP 3: Create the minimal app entry point

Since this is a Swift Package Manager executable, we need a @main entry point. Create a minimal one that just launches the app. This will be expanded in task 0002.

File: src/App/EmberHearthApp.swift
```swift
// EmberHearthApp.swift
// EmberHearth
//
// Main entry point for the EmberHearth macOS application.

import SwiftUI

@main
struct EmberHearthApp: App {
    var body: some Scene {
        WindowGroup {
            Text("EmberHearth")
                .frame(width: 300, height: 200)
                .accessibilityLabel("EmberHearth application window")
        }
    }
}
```

STEP 4: Create the entitlements file

File: src/EmberHearth.entitlements
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Automation permission for controlling Messages.app via AppleScript -->
    <key>com.apple.security.automation.apple-events</key>
    <true/>

    <!-- File access for user-selected files (settings import/export) -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- Read access to chat.db for iMessage integration -->
    <!-- Note: Full Disk Access is a system permission granted by user, not an entitlement -->
    <!-- This temporary exception allows reading the Messages database path -->
    <key>com.apple.security.temporary-exception.files.absolute-path.read-only</key>
    <array>
        <string>/Users/</string>
    </array>

    <!-- Network access for LLM API calls -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- Keychain access for storing API keys securely -->
    <key>com.apple.security.keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.emberhearth.app</string>
    </array>
</dict>
</plist>
```

STEP 5: Create Info.plist

File: src/Info.plist
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>EmberHearth</string>

    <key>CFBundleDisplayName</key>
    <string>EmberHearth</string>

    <key>CFBundleIdentifier</key>
    <string>com.emberhearth.app</string>

    <key>CFBundleVersion</key>
    <string>1</string>

    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleExecutable</key>
    <string>EmberHearth</string>

    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>

    <!-- Run as menu bar app (no Dock icon) -->
    <key>LSUIElement</key>
    <true/>

    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026 EmberHearth. All rights reserved.</string>

    <!-- Required for Messages.app automation -->
    <key>NSAppleEventsUsageDescription</key>
    <string>EmberHearth needs permission to send messages through the Messages app on your behalf.</string>

    <!-- Hardened Runtime -->
    <key>NSSupportsAutomaticTermination</key>
    <false/>

    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
```

STEP 6: Create .gitignore for Xcode/Swift projects

File: .gitignore (at project root: /Users/robault/Documents/GitHub/emberhearth/.gitignore)

Check if a .gitignore already exists. If it does, append the Swift/Xcode-specific entries below to it. If it does not exist, create it with this content:

```
# Xcode
*.xcodeproj/
*.xcworkspace/
xcuserdata/
*.xcuserstate
*.xcschemes/
DerivedData/
build/
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3
*.moved-aside

# Swift Package Manager
.build/
.swiftpm/
Package.resolved

# macOS
.DS_Store
*.dSYM
*.dSYM.zip

# IDE
.idea/
*.swp
*.swo
*~

# Build artifacts
*.app
*.ipa
*.framework
*.dylib

# Signing
*.mobileprovision
*.provisionprofile

# Environment / Secrets
.env
*.env
credentials.json
```

STEP 7: Remove placeholder .gitkeep files

Delete these files as they are no longer needed (the directories now contain actual files):
- src/.gitkeep
- tests/.gitkeep

STEP 8: Create a minimal test file so `swift test` doesn't fail

File: tests/EmberHearthTests.swift
```swift
// EmberHearthTests.swift
// EmberHearth
//
// Basic test suite for EmberHearth.

import XCTest
@testable import EmberHearth

final class EmberHearthTests: XCTestCase {

    func testModulesExist() {
        // Verify all module placeholders are accessible
        XCTAssertEqual(AppModule.name, "App")
        XCTAssertEqual(CoreModule.name, "Core")
        XCTAssertEqual(DatabaseModule.name, "Database")
        XCTAssertEqual(LLMModule.name, "LLM")
        XCTAssertEqual(MemoryModule.name, "Memory")
        XCTAssertEqual(PersonalityModule.name, "Personality")
        XCTAssertEqual(SecurityModule.name, "Security")
        XCTAssertEqual(ViewsModule.name, "Views")
        XCTAssertEqual(LoggingModule.name, "Logging")
    }
}
```

IMPORTANT NOTES:
- Do NOT create an .xcodeproj file. We are using Swift Package Manager only.
- Do NOT add any third-party dependencies yet.
- Do NOT create any XPC service targets yet (MVP is single-process per mvp-scope.md).
- The entitlements and Info.plist files are excluded from the SPM build via the `exclude` array in Package.swift. They will be used when we create the .xcodeproj or during manual signing later.
- Every Swift file must have the filename as its first comment line.
- All files go under the paths specified above. Do not deviate from the directory structure.
- After creating all files, run `swift build` from the project root to verify the build succeeds.
```

---

## Acceptance Criteria

- [ ] `Package.swift` exists at project root with correct configuration
- [ ] All 9 module directories exist under `src/` (App, Core, Database, LLM, Memory, Personality, Security, Views, Logging)
- [ ] Each module directory contains a `[Name]Module.swift` placeholder file
- [ ] `src/App/EmberHearthApp.swift` exists with `@main` entry point
- [ ] `src/EmberHearth.entitlements` exists with all 5 entitlements (automation, file access, absolute path read, network client, keychain)
- [ ] `src/Info.plist` exists with correct bundle identifier, LSUIElement=true, and usage descriptions
- [ ] `.gitignore` includes Swift/Xcode/SPM patterns
- [ ] `src/.gitkeep` and `tests/.gitkeep` have been removed
- [ ] `tests/EmberHearthTests.swift` exists with a passing test
- [ ] `swift build` succeeds from project root
- [ ] No third-party dependencies are included
- [ ] No .xcodeproj or .xcworkspace files are created

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify directory structure exists
ls -la src/App/ src/Core/ src/Database/ src/LLM/ src/Memory/ src/Personality/ src/Security/ src/Views/ src/Logging/

# Verify key files exist
test -f Package.swift && echo "Package.swift exists" || echo "MISSING: Package.swift"
test -f src/App/EmberHearthApp.swift && echo "Entry point exists" || echo "MISSING: EmberHearthApp.swift"
test -f src/EmberHearth.entitlements && echo "Entitlements exist" || echo "MISSING: Entitlements"
test -f src/Info.plist && echo "Info.plist exists" || echo "MISSING: Info.plist"
test -f .gitignore && echo ".gitignore exists" || echo "MISSING: .gitignore"
test -f tests/EmberHearthTests.swift && echo "Test file exists" || echo "MISSING: Test file"

# Verify .gitkeep files are removed
test ! -f src/.gitkeep && echo ".gitkeep removed from src" || echo "WARNING: src/.gitkeep still exists"
test ! -f tests/.gitkeep && echo ".gitkeep removed from tests" || echo "WARNING: tests/.gitkeep still exists"

# Build the project
swift build 2>&1

# Run tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the EmberHearth project setup created in task 0001. Check for these common Sonnet failure modes:

1. PACKAGE.SWIFT CORRECTNESS:
   - Open Package.swift and verify swift-tools-version is 5.9
   - Verify the platform is .macOS(.v13) (not .v14 or something else)
   - Verify the executable target path is "src" (not "Sources")
   - Verify the test target path is "tests" (not "Tests")
   - Verify the entitlements and Info.plist are in the exclude array
   - Verify there are NO external dependencies

2. ENTRY POINT:
   - Verify src/App/EmberHearthApp.swift uses @main attribute
   - Verify it imports SwiftUI (not AppKit directly)
   - Verify there is only ONE @main entry point across all Swift files
   - Check that no other file has @main, main.swift, or top-level code

3. ENTITLEMENTS:
   - Verify src/EmberHearth.entitlements has valid XML
   - Verify it includes com.apple.security.automation.apple-events
   - Verify it includes com.apple.security.network.client
   - Verify it includes com.apple.security.keychain-access-groups
   - Verify it does NOT include com.apple.security.app-sandbox (we're not sandboxing for MVP since we need Full Disk Access for chat.db)

4. INFO.PLIST:
   - Verify LSUIElement is set to true (menu bar app)
   - Verify CFBundleIdentifier is com.emberhearth.app
   - Verify LSMinimumSystemVersion is 13.0
   - Verify NSAppleEventsUsageDescription is present

5. NAMING CONVENTIONS:
   - All Swift files must be PascalCase
   - Bundle identifier must be com.emberhearth.app (lowercase)
   - Module enum names should match directory names

6. BUILD VERIFICATION:
   - Run `swift build` and verify it succeeds
   - Run `swift test` and verify tests pass
   - Check that no warnings appear about missing files or invalid paths

Report any issues found, with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m1): initialize Xcode project with signing configuration
```

---

## Notes for Next Task

- The @main entry point is in `src/App/EmberHearthApp.swift`. Task 0002 will replace this minimal implementation with the full SwiftUI app shell including AppDelegate.
- Info.plist already has `LSUIElement = true` for menu bar behavior. Task 0002 should NOT change this.
- The entitlements file is at `src/EmberHearth.entitlements`. It is excluded from SPM compilation but will be referenced during code signing.
- All module directories have placeholder files. Future tasks will add real implementations alongside these placeholders (the placeholders can be removed once real code exists in each module).
- The project uses Swift Package Manager, NOT an .xcodeproj. If Xcode is needed later, run `swift package generate-xcodeproj` or open Package.swift directly in Xcode.
- There are no external dependencies. The first dependency will likely be added in M3 (LLM integration) or when SQLite wrapper is needed.
- The test target depends on the main EmberHearth target. Tests can `@testable import EmberHearth` to access internal types.
