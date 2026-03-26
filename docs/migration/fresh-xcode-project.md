# EmberHearth: Fresh Xcode Project Migration Guide

**Target:** macOS 26.3 + Xcode 26.3
**Audience:** Someone new to Xcode/Swift
**Goal:** Replace the broken SPM-derived Xcode project with a proper native macOS Xcode project, migrating all existing source and test files.

---

## Before You Start

Read this entire document once before touching anything.

### What we're doing and why

The current Xcode project was converted from a Swift Package Manager (SPM) project. That conversion left structural artifacts in the project file that are causing the test target to fail to link — tests cannot see the compiled app code. The correct fix is a clean Xcode project created natively, then populated with the existing Swift source files.

Your existing code is completely fine. Nothing about the Swift files themselves is broken.

### What you'll preserve

- All Swift source files (untouched)
- All test files (untouched)
- The entitlements file
- The Info.plist

### Current directory structure (for reference)

```
/Users/robault/Documents/GitHub/emberhearth/
├── EmberHearth/                  ← existing Xcode project (being replaced)
│   ├── EmberHearth.xcodeproj/   ← the broken project file
│   ├── App/                     ← source files to migrate
│   ├── Core/
│   ├── Database/
│   ├── LLM/
│   ├── Logging/
│   ├── Memory/
│   ├── Personality/
│   ├── Security/
│   ├── Views/
│   ├── EmberHearth.entitlements
│   └── Info.plist
└── tests/                       ← test files to migrate
    ├── EmberHearthTests.swift
    ├── IntegrationTests/
    ├── SecurityTests/
    ├── TestHelpers/
    └── UnitTests/
```

---

## Step 1: Back Up the Current Project

Before making any changes, back up the current broken project.

1. Open **Terminal** (press `Cmd+Space`, type `Terminal`, press Return).
2. Run the following command exactly as written:

```bash
cp -R /Users/robault/Documents/GitHub/emberhearth/EmberHearth /Users/robault/Documents/GitHub/emberhearth/EmberHearth.backup
```

3. Verify the backup was created:

```bash
ls /Users/robault/Documents/GitHub/emberhearth/
```

You should see both `EmberHearth` and `EmberHearth.backup` listed.

---

## Step 2: Create the New Xcode Project

1. Open **Xcode**. If you see the Welcome window, proceed to step 2. If Xcode opens an existing project, close it first with **File > Close Workspace** (or `Cmd+Shift+W`).

2. In the Welcome window, click **Create New Project**.
   - *Alternative if you don't see the Welcome window:* Choose **File > New > Project** from the menu bar.

3. A template picker sheet appears. At the top of the sheet, you will see tabs for different platforms. Click the **macOS** tab.

4. Under the **Application** section (the first section), click **App** to select it. It should highlight in blue.

5. Click **Next** in the bottom-right corner of the sheet.

6. The **"Choose options for your new project"** sheet appears. Fill it in exactly as follows:

   | Field | Value |
   |---|---|
   | **Product Name** | `EmberHearth` |
   | **Team** | Select your developer team from the dropdown (the one associated with `GPKUTW7B5R`) |
   | **Organization Identifier** | `com.emberhearth` |
   | **Bundle Identifier** | This auto-fills as `com.emberhearth.EmberHearth` — leave it as-is |
   | **Language** | `Swift` |
   | **Storage** | `None` |
   | **Testing System** | `XCTest` |

   > **Why XCTest, not Swift Testing?** Your existing test files use `XCTestCase` subclasses and `XCTAssert*` macros. Choose **XCTest** to match. If you choose Swift Testing, the generated stub file uses a different syntax and you'd need to delete it anyway.

7. Click **Next**.

8. A save dialog appears. Navigate to the following location:

   - In the sidebar on the left of the save dialog, click **Locations** (or press `Cmd+Shift+H` to go to your home folder).
   - Navigate to: `Documents > GitHub > emberhearth`

   > **Critical:** You must save inside the `emberhearth` folder, NOT inside the existing `EmberHearth` subfolder.

9. At the bottom of the save dialog, there is a checkbox labeled **"Create Git repository on my Mac"**. **Uncheck this box.** The repository already exists.

10. Confirm the save location shows `.../emberhearth` in the path bar. Then click **Create**.

Xcode will create a new folder at `/Users/robault/Documents/GitHub/emberhearth/EmberHearth-new/` — actually, it will name it based on your Product Name. Since you already have a folder called `EmberHearth`, Xcode may name the new one `EmberHearth 2` or similar. That's fine for now — we'll sort this out in Step 3.

> **What just happened:** Xcode created a new project with two targets: `EmberHearth` (the app) and `EmberHearthTests` (the unit test bundle). It also created stub Swift files you'll replace with your actual source. The project structure is clean and correct.

---

## Step 3: Rename and Position the New Project

After creation, you need to position this new project correctly.

1. Switch to **Terminal**.

2. Check what Xcode created:
```bash
ls /Users/robault/Documents/GitHub/emberhearth/
```

You'll see a new directory. It may be named `EmberHearth 2` or similar if there was a name conflict.

3. We're going to delete the old broken project directory and rename the new one. Run these commands **one at a time**, reading each before pressing Return:

```bash
# Move the old broken project out of the way (the backup we made in Step 1 already protects us)
mv /Users/robault/Documents/GitHub/emberhearth/EmberHearth /Users/robault/Documents/GitHub/emberhearth/EmberHearth.old
```

```bash
# Rename the new project directory to the correct name
# Replace "EmberHearth 2" below with whatever Xcode actually named it
mv "/Users/robault/Documents/GitHub/emberhearth/EmberHearth 2" /Users/robault/Documents/GitHub/emberhearth/EmberHearth
```

> **Note:** If Xcode named the new directory something other than `EmberHearth 2`, substitute that name in the command above. Use quotes around the path if it contains spaces.

4. Verify:
```bash
ls /Users/robault/Documents/GitHub/emberhearth/
```

You should now see `EmberHearth` (the new project), `EmberHearth.old` (the broken one), and `EmberHearth.backup` (the original backup).

5. Back in Xcode, the project may show an error because you moved the folder. Close the project:
   - Choose **File > Close Workspace** from the menu bar (or press `Cmd+Shift+W`).

6. Open the new project:
   - Choose **File > Open Recent** — you may see the project there, but it might show with an error badge.
   - Better: Choose **File > Open** (`Cmd+O`), navigate to `Documents/GitHub/emberhearth/EmberHearth/`, and double-click the **`EmberHearth.xcodeproj`** file.

---

## Step 4: Understand the New Project Structure

With the project open, look at the **Project navigator** on the left side of Xcode (the folder icon — first icon in the left sidebar). You should see:

```
EmberHearth (project root)
├── EmberHearth (group/folder)
│   ├── EmberHearthApp.swift     ← stub file Xcode generated
│   ├── ContentView.swift        ← stub file Xcode generated
│   └── Assets.xcassets
├── EmberHearthTests (group/folder)
│   └── EmberHearthTests.swift   ← stub test file Xcode generated
├── EmberHearthUITests (group/folder)
│   └── EmberHearthUITests.swift ← stub UI test file
└── Products (group)
    └── EmberHearth.app
```

**Do not delete these stub files yet.** We'll replace them in the steps below. Deleting before adding can leave targets with no files, which can cause issues.

---

## Step 5: Configure Deployment Target

Before adding any source files, set the deployment target.

1. In the Project navigator, click the **EmberHearth** project icon at the very top (it has a small blueprint/gear icon, not a folder icon). The project editor opens in the main area.

2. In the project editor, make sure you have the **Project** selected (not a target) in the left column. You'll see "PROJECT" header above it and "TARGETS" below.

3. Click on **EmberHearth** under "PROJECT".

4. You should be on the **Info** tab. Look for **Deployment Target** or **macOS Deployment Target**. Set it to **macOS 26.2**.

   > The minimum version is 26.2 to match the existing codebase. Setting it to 26.3 would technically also work but 26.2 is more permissive.

5. Now do the same for each target. Under "TARGETS", click **EmberHearth**:
   - Click the **General** tab.
   - Find the **Minimum Deployments** section.
   - Set **macOS** to `26.2`.

6. Click **EmberHearthTests** target under "TARGETS":
   - Click the **General** tab.
   - Set **macOS Deployment Target** to `26.2`.

7. Click **EmberHearthUITests** target:
   - Set **macOS Deployment Target** to `26.2`.

---

## Step 6: Delete the Stub Files

Now delete the generated placeholder files that Xcode created. We'll replace them with the real source.

1. In the Project navigator, click on **ContentView.swift** (inside the `EmberHearth` group).
2. Press the **Delete** key (or right-click → **Delete**).
3. A dialog appears: **"Do you want to move the file to the Trash, or only remove the reference?"**
4. Click **"Move to Trash"** — this deletes the actual file.

5. Repeat for **EmberHearthApp.swift** (inside the `EmberHearth` group):
   - Click it, press Delete, click "Move to Trash".

6. Delete the stub test file: click **EmberHearthTests.swift** (inside the `EmberHearthTests` group):
   - Delete → Move to Trash.

> **Do NOT delete** `Assets.xcassets` yet — we'll leave it. Do NOT delete the `EmberHearthUITests` group or its file for now.

---

## Step 7: Copy Source Files Into the Project Directory

Before adding files to Xcode, copy them into the new project folder in Finder. This is the key difference from the old approach — files will live *inside* the project, not be referenced from the old SPM location.

Switch to **Terminal**.

### Copy the app source directories:

```bash
# Copy each source directory into the new EmberHearth project folder
cp -R /Users/robault/Documents/GitHub/emberhearth/EmberHearth.old/App \
      /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearth/App

cp -R /Users/robault/Documents/GitHub/emberhearth/EmberHearth.old/Core \
      /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearth/Core

cp -R /Users/robault/Documents/GitHub/emberhearth/EmberHearth.old/Database \
      /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearth/Database

cp -R /Users/robault/Documents/GitHub/emberhearth/EmberHearth.old/LLM \
      /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearth/LLM

cp -R /Users/robault/Documents/GitHub/emberhearth/EmberHearth.old/Logging \
      /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearth/Logging

cp -R /Users/robault/Documents/GitHub/emberhearth/EmberHearth.old/Memory \
      /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearth/Memory

cp -R /Users/robault/Documents/GitHub/emberhearth/EmberHearth.old/Personality \
      /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearth/Personality

cp -R /Users/robault/Documents/GitHub/emberhearth/EmberHearth.old/Security \
      /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearth/Security

cp -R /Users/robault/Documents/GitHub/emberhearth/EmberHearth.old/Views \
      /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearth/Views
```

### Copy the entitlements and Info.plist:

```bash
cp /Users/robault/Documents/GitHub/emberhearth/EmberHearth.old/EmberHearth.entitlements \
   /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearth/EmberHearth.entitlements

cp /Users/robault/Documents/GitHub/emberhearth/EmberHearth.old/Info.plist \
   /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearth/Info.plist
```

### Copy the test files:

```bash
# Create the test directory structure
mkdir -p /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearthTests

cp -R /Users/robault/Documents/GitHub/emberhearth/tests/IntegrationTests \
      /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearthTests/IntegrationTests

cp -R /Users/robault/Documents/GitHub/emberhearth/tests/SecurityTests \
      /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearthTests/SecurityTests

cp -R /Users/robault/Documents/GitHub/emberhearth/tests/TestHelpers \
      /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearthTests/TestHelpers

cp -R /Users/robault/Documents/GitHub/emberhearth/tests/UnitTests \
      /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearthTests/UnitTests

cp /Users/robault/Documents/GitHub/emberhearth/tests/EmberHearthTests.swift \
   /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearthTests/EmberHearthTests.swift
```

### Verify the copies:

```bash
ls /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearth/
ls /Users/robault/Documents/GitHub/emberhearth/EmberHearth/EmberHearthTests/
```

The first command should show: `App  Core  Database  EmberHearth.entitlements  Info.plist  LLM  Logging  Memory  Personality  Security  Views  Assets.xcassets`

The second should show: `EmberHearthTests.swift  IntegrationTests  SecurityTests  TestHelpers  UnitTests`

---

## Step 8: Add App Source Files to Xcode

Now tell Xcode about the files you just copied.

1. Switch back to **Xcode**.

2. In the Project navigator, right-click (or Control-click) on the **EmberHearth** group (the folder icon named `EmberHearth` — the inner one, not the project root). A context menu appears.

3. Choose **"Add Files to 'EmberHearth'..."** from the context menu.

   > *Alternative:* With the EmberHearth group selected, use the menu bar: **File > Add Files to "EmberHearth"...**

4. A file picker sheet slides down. Navigate to the copied files:
   - The sheet should open to the project directory. Look for the `EmberHearth` folder inside the project.
   - Navigate into `EmberHearth/EmberHearth/` — you should see the `App`, `Core`, `Database`, etc. folders.

5. Before selecting any files, check the settings at the **bottom of the sheet**:
   - **Action (or "Destination")**: Set to **"Create groups"** (not "Create folder references"). This creates logical groups in Xcode's navigator that mirror the folder structure.
   - **Add to Targets**: You will see a list of targets with checkboxes. Make sure **only `EmberHearth`** is checked. Uncheck `EmberHearthTests` and `EmberHearthUITests`.

6. Now select the folders to add. Click **App** to select it, then hold **Cmd** and click each of the following to add them to the selection:
   - `Core`
   - `Database`
   - `LLM`
   - `Logging`
   - `Memory`
   - `Personality`
   - `Security`
   - `Views`

7. Click **Add** in the bottom-right corner.

Xcode will add all those directories and their Swift files to the `EmberHearth` app target. You should see them appear in the Project navigator under the `EmberHearth` group.

---

## Step 9: Add the Entitlements and Info.plist

1. Right-click on the **EmberHearth** group (inner group) in the Project navigator.

2. Choose **"Add Files to 'EmberHearth'..."**.

3. Navigate to the `EmberHearth/EmberHearth/` folder (same location as before).

4. Hold **Cmd** and click both:
   - `EmberHearth.entitlements`
   - `Info.plist`

5. At the bottom:
   - **Action**: `Create groups`
   - **Add to Targets**: Check **only `EmberHearth`** (uncheck both test targets)

6. Click **Add**.

---

## Step 10: Add Test Files to Xcode

1. In the Project navigator, right-click (or Control-click) on the **EmberHearthTests** group (the folder named `EmberHearthTests`).

2. Choose **"Add Files to 'EmberHearth'..."** from the context menu.

3. In the file picker, navigate to `EmberHearth/EmberHearthTests/`.

4. At the bottom of the sheet:
   - **Action**: `Create groups`
   - **Add to Targets**: Check **only `EmberHearthTests`**. Uncheck `EmberHearth` and `EmberHearthUITests`.

5. Hold **Cmd** and click to select all of the following:
   - `EmberHearthTests.swift`
   - `IntegrationTests` (folder)
   - `SecurityTests` (folder)
   - `TestHelpers` (folder)
   - `UnitTests` (folder)

6. Click **Add**.

---

## Step 11: Configure Code Signing and Entitlements

1. In the Project navigator, click the **project root** (the topmost `EmberHearth` icon with the blueprint).

2. Under "TARGETS", click **EmberHearth** (the app target).

3. Click the **"Signing & Capabilities"** tab.

4. Under **Signing**:
   - Check **"Automatically manage signing"** if it isn't already checked.
   - **Team**: Select your team (associated with `GPKUTW7B5R`).
   - **Bundle Identifier**: Should read `com.emberhearth.EmberHearth` — change this to `com.emberhearth.app`.

   > **Important:** The bundle ID must be `com.emberhearth.app` to match the keychain access group in the entitlements file.

5. Now wire up the entitlements file. We need to set the build setting directly:
   - Click the **"Build Settings"** tab.
   - In the search box at the top right, type `entitlements`.
   - You'll see a setting called **"Code Signing Entitlements"** (build setting name: `CODE_SIGN_ENTITLEMENTS`).
   - Double-click the value column for the **EmberHearth** target row.
   - Enter: `EmberHearth/EmberHearth.entitlements`
   - Press Return to confirm.

   > **Why this path?** The entitlements file is at `EmberHearth/EmberHearth.entitlements` relative to the project file. If Xcode can't find it at build time, try just `EmberHearth.entitlements` — the exact path depends on where Xcode placed the file.

6. Verify the entitlements file has the correct content. In the Project navigator, click `EmberHearth.entitlements`. The editor should show these keys:
   - `com.apple.security.automation.apple-events` = YES
   - `com.apple.security.get-task-allow` = YES (for Debug builds)
   - `com.apple.security.network.client` = YES
   - `keychain-access-groups` = `$(AppIdentifierPrefix)com.emberhearth.app`

   If any are missing, click the `+` button to add them.

---

## Step 12: Configure Test Target Build Settings

This is the most critical step — these settings are what was broken in the old project.

1. In the Project navigator, click the **project root**.

2. Under "TARGETS", click **EmberHearthTests**.

3. Click the **"Build Settings"** tab.

4. At the top of the Build Settings area, click **All** (to show all settings, not just "Basic").

5. In the search box, type `TEST_HOST`.

6. Find the setting **"Test Host"** (`TEST_HOST`). The current value may be set to something like `$(BUILT_PRODUCTS_DIR)/EmberHearth.app/...`.

   **This must be empty.** Double-click the value and delete all content, leaving it blank. Press Return.

7. Clear the search box and type `BUNDLE_LOADER`.

8. Find the setting **"Bundle Loader"** (`BUNDLE_LOADER`).

   **This must also be empty.** Double-click the value and delete all content. Press Return.

   > **Why empty?** Your tests use `@testable import EmberHearth` — they import the compiled Swift module directly. They do NOT need to inject into a running app. Host-app injection (what `TEST_HOST` enables) is only for UI tests or legacy integration tests that need a live app process. Setting these to empty tells Xcode to build and run the test bundle standalone.

9. Clear the search and type `SWIFT_VERSION`. Verify it's set to `5.0`.

10. Search for `MACOSX_DEPLOYMENT_TARGET`. Verify it's `26.2`.

---

## Step 13: Configure App Target Build Settings

1. Under "TARGETS", click **EmberHearth** (the app target).

2. Click **"Build Settings"** tab, make sure **All** is selected.

3. Search for `ENABLE_APP_SANDBOX`. Set it to **No** (disabled).

   > EmberHearth needs full disk access to read the Messages database. App Sandbox would prevent this. Since you're distributing outside the Mac App Store with Developer ID, sandboxing is optional.

4. Search for `ENABLE_HARDENED_RUNTIME`. Set it to **Yes** (enabled).

   > Required for notarization and Developer ID distribution.

5. Search for `SWIFT_APPROACHABLE_CONCURRENCY`. Set to **Yes**.

6. Search for `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`. Set to **Yes**.

---

## Step 14: Configure Info.plist

The new project may have generated a new `Info.plist` or it may be handling Info.plist settings in the project file. Let's make sure the custom `Info.plist` is being used.

1. Click the **EmberHearth** app target.

2. Click the **"Build Settings"** tab.

3. Search for `INFOPLIST_FILE`.

4. The setting **"Info.plist File"** should show the path to your Info.plist. If Xcode generated its own Info.plist settings inline (showing `GENERATE_INFOPLIST_FILE = YES`), you need to:
   - Set `GENERATE_INFOPLIST_FILE` to **No**.
   - Set `INFOPLIST_FILE` to `EmberHearth/Info.plist`.

5. If `GENERATE_INFOPLIST_FILE` doesn't appear in search, it may already be using a file. Check that the `Info.plist` file appears in the Project navigator under the `EmberHearth` group (you added it in Step 9).

---

## Step 15: First Build Attempt

1. Make sure the scheme is set to **EmberHearth** and the destination is **My Mac**. Look at the toolbar at the top of Xcode — there's a scheme/destination picker in the center. It should read something like `EmberHearth > My Mac`.

2. Press **Cmd+B** to build (or choose **Product > Build** from the menu bar).

3. The build will likely show errors because the existing Swift files reference each other and some may have `@main` or other entry points that conflict with what Xcode expects.

### Common errors and fixes:

**Error: "Expressions are not allowed at the top level"** or **"'main' attribute cannot be applied"**:
- This happens when both the template-generated `EmberHearthApp.swift` and your app's entry point exist simultaneously.
- In the Project navigator, look for `EmberHearthApp.swift` inside the `App/` folder (the one you copied from the old project).
- Also look for any `ContentView.swift` you may have missed deleting in Step 6.
- We deleted the Xcode-generated stubs in Step 6 — if you still see them, delete them now.

**Error: "Module 'EmberHearth' not found"** in test files:
- The test files import `@testable import EmberHearth`. If this fails at build time, the test target is not correctly linked to the app target.
- Click the **EmberHearthTests** target → **"Build Phases"** tab → expand **"Target Dependencies"**.
- Click the `+` button and add **EmberHearth** as a dependency.

**Error: "Cannot find type 'XCTestCase'"** or similar in test files:
- The test files need `import XCTest`. Verify the test files have this at the top.
- Also verify the test files are assigned to the `EmberHearthTests` target, not the `EmberHearth` target. Select a test file in the navigator, then look at the **File Inspector** on the right side (press `Cmd+Option+1` to open it). Under **Target Membership**, only `EmberHearthTests` should be checked.

---

## Step 16: Verify Target Membership for All Files

This is tedious but essential — every file must be in exactly the right target.

### Check app source files:

1. In the Project navigator, click on any Swift file in the `App/`, `Core/`, `Database/`, etc. folders.
2. Open the **File Inspector** (`Cmd+Option+1` or the rightmost panel icon → first tab).
3. Scroll to **Target Membership**.
4. For app source files: only **EmberHearth** should be checked.
5. For test files: only **EmberHearthTests** should be checked.

If any file is checked for the wrong target, uncheck the wrong one.

### Quick check via Build Phases:

1. Click the **EmberHearth** app target.
2. Click **"Build Phases"** tab.
3. Expand **"Compile Sources"**.
4. Verify this list contains only app source files (no test files).

1. Click the **EmberHearthTests** target.
2. Click **"Build Phases"** tab.
3. Expand **"Compile Sources"**.
4. Verify this contains all the test `.swift` files.
5. Also expand **"Target Dependencies"** — verify `EmberHearth` is listed here.

---

## Step 17: Run the Tests

1. Press **Cmd+U** (or choose **Product > Test** from the menu bar) to run all tests.

2. The test navigator (diamond icon in the left panel) will show test results as they run.

3. All previously passing tests should pass. The two previously-canceled tests (`test_credentialScannerFalsePositives_belowThreshold` and `test_tronPipeline_crisisDetectedBeforeInjection`) should now run and pass, because the linker errors that were causing them to fail are gone.

### If tests are still canceled:

- Open the **Report navigator** (the last icon in the left panel, looks like a speech bubble). Click the most recent test run.
- Look for any "Testing was canceled" entries and check if there's a crash log.
- Run **Product > Clean Build Folder** (`Cmd+Shift+K`) then try again.

---

## Step 18: Clean Up

Once all tests pass and the app builds cleanly:

1. In **Terminal**, remove the old project backup folders:

```bash
rm -rf /Users/robault/Documents/GitHub/emberhearth/EmberHearth.old
rm -rf /Users/robault/Documents/GitHub/emberhearth/EmberHearth.backup
```

2. The `tests/` directory at the repo root is now superseded by the test files inside `EmberHearth/EmberHearthTests/`. You can keep it for reference or remove it:

```bash
# Optional — only do this once you've confirmed all tests pass in the new project
# rm -rf /Users/robault/Documents/GitHub/emberhearth/tests
```

3. Update `.gitignore` if needed. The new project will have a `.xcodeproj` inside `EmberHearth/` — this is the correct artifact to commit.

---

## Step 19: Commit the New Project

1. In **Terminal**:

```bash
cd /Users/robault/Documents/GitHub/emberhearth
git status
```

2. You'll see the old project files marked for deletion and the new project files as untracked.

3. Stage and commit:

```bash
git add EmberHearth/
git add -u  # stages deletions of old files
git commit -m "Migrate from SPM-derived project to native Xcode macOS project

Replaces the broken SPM-converted Xcode project with a proper native
macOS Xcode 26.3 project. Resolves test target linking failures that
were causing tests to be canceled at runtime.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Troubleshooting Reference

### "Supported platforms for the buildables in the current scheme is empty"
This means the scheme is looking for targets that don't exist. Check that the EmberHearth scheme (in the scheme picker at the top of Xcode) points to the `EmberHearth` app target.

### "Undefined symbol" errors during test build
The test target can't see the app code. Check:
1. `EmberHearthTests` → Build Phases → Target Dependencies → `EmberHearth` is listed
2. `TEST_HOST` and `BUNDLE_LOADER` are both empty in the test target's Build Settings
3. All app source files are in the `EmberHearth` target's Compile Sources build phase

### The app launches multiple times during testing
This means `TEST_HOST` was set back to the app binary. Return to Step 12 and clear it again.

### "Cannot find type X in module 'EmberHearth'"
The app module isn't building. Build the app target alone first (`Cmd+B` with the `EmberHearth` scheme), fix all errors, then run tests.

### Entitlements errors during signing
Verify the path in `CODE_SIGN_ENTITLEMENTS` matches where the `.entitlements` file actually lives relative to the project file. You can drag the file from the Finder onto the build setting field to auto-populate the path.

---

## Summary of What Makes This Work

The fundamental difference between the new project and the old one:

| Old (broken) | New (correct) |
|---|---|
| SPM-derived `.pbxproj` with accumulated artifacts | Native Xcode macOS app project from scratch |
| Test target failed to link to app module | Test target has `EmberHearth` as explicit dependency |
| Stale binary was being executed | Clean build from source every time |
| `TEST_HOST` pointed to app binary (ran app during tests) | `TEST_HOST = ""` (standalone test bundle) |
| Scheme in non-standard `.swiftpm/` directory | Scheme in standard `xcshareddata/xcschemes/` directory |
| Source files referenced via SPM package paths | Source files living inside the Xcode project directory |
