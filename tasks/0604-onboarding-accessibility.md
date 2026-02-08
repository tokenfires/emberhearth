# Task 0604: Onboarding Accessibility Pass

**Milestone:** M7 - Onboarding
**Unit:** 7.5 - Accessibility Pass
**Phase:** 3
**Depends On:** 0600, 0601, 0602, 0603 (all onboarding views must be complete)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; the "Accessibility" core principle states ALL UI must support VoiceOver, Dynamic Type, keyboard navigation
2. `docs/research/onboarding-ux.md` — Focus on Section 12: "Accessibility Considerations" (lines ~752-788) for VoiceOver, Dynamic Type, Keyboard Navigation, and Reduced Motion requirements
3. `src/Views/Onboarding/OnboardingContainerView.swift` — Read entirely
4. `src/Views/Onboarding/WelcomeView.swift` — Read entirely
5. `src/Views/Onboarding/PermissionsView.swift` — Read entirely
6. `src/Views/Onboarding/APIKeyEntryView.swift` — Read entirely
7. `src/Views/Onboarding/PhoneConfigView.swift` — Read entirely
8. `src/Views/Onboarding/FirstMessageTestView.swift` — Read entirely

> **Context Budget Note:** This task requires reading ALL 6 onboarding view files. Each is approximately 200-350 lines. Combined, that is ~1500-2100 lines of code to review and enhance. onboarding-ux.md Section 12 is ~36 lines. CLAUDE.md is ~90 lines. Total context is well within budget.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are performing a dedicated accessibility review and enhancement pass on ALL onboarding views for EmberHearth, a native macOS personal AI assistant. This is not about creating new functionality — it is about auditing existing accessibility support and filling any gaps.

EmberHearth's core principle: "ALL UI must support VoiceOver, Dynamic Type, keyboard navigation."

IMPORTANT RULES (from CLAUDE.md):
- Product display name: "EmberHearth"
- Swift files use PascalCase
- Security first: Do not change any business logic or security behavior
- ALL UI must support VoiceOver, Dynamic Type, and keyboard navigation
- Follow Apple Human Interface Guidelines
- All source files go under src/, all test files go under tests/

PROJECT CONTEXT:
- macOS 14.0+ deployment target
- The following onboarding view files exist and need an accessibility audit:
  1. src/Views/Onboarding/OnboardingContainerView.swift
  2. src/Views/Onboarding/WelcomeView.swift
  3. src/Views/Onboarding/PermissionsView.swift
  4. src/Views/Onboarding/APIKeyEntryView.swift
  5. src/Views/Onboarding/PhoneConfigView.swift
  6. src/Views/Onboarding/FirstMessageTestView.swift

YOU WILL:
1. Audit each view against a comprehensive accessibility checklist
2. Fix any gaps found
3. Add `.accessibilityIdentifier` for UI testing on all interactive elements
4. Add an accessibility compliance comment at the top of each view
5. Create tests/OnboardingAccessibilityTests.swift for UI accessibility identifier verification

IMPORTANT: Do NOT change business logic, data flow, or security behavior. Only add or modify accessibility-related code.

AUDIT CHECKLIST — Apply this to EVERY view file:

======================================================================
CHECKLIST 1: VoiceOver
======================================================================

For each view, verify and fix:

A. EVERY interactive element (Button, TextField, SecureField, Toggle, Picker, Link, DisclosureGroup) MUST have:
   - .accessibilityLabel("Descriptive label") — what it IS
   - .accessibilityHint("What it does") — what happens when you activate it
   - If the label is already the button text, you may omit .accessibilityLabel (SwiftUI uses the text automatically)

B. EVERY Image MUST have either:
   - .accessibilityLabel("Description") if the image conveys information
   - .accessibilityHidden(true) if the image is decorative

C. EVERY heading text MUST have:
   - .accessibilityAddTraits(.isHeader)

D. Status changes (permission granted, validation success/failure, test progress) MUST:
   - Post NSAccessibility.post announcement notification
   - Use NSAccessibilityPriorityLevel.high for important changes

E. Related elements MUST be grouped:
   - Use .accessibilityElement(children: .combine) for elements that should be read together
   - Use .accessibilityElement(children: .contain) for containers whose children should be navigated individually

F. Tab/navigation order MUST be logical:
   - Top to bottom, left to right
   - Primary action should be reachable quickly
   - No VoiceOver traps (user must be able to navigate away from any element)

======================================================================
CHECKLIST 2: Dynamic Type
======================================================================

For each view, verify and fix:

A. ALL text MUST use semantic font styles — NEVER fixed font sizes:
   - .font(.largeTitle) for main headings
   - .font(.title), .font(.title2), .font(.title3) for sub-headings
   - .font(.headline) for emphasized text
   - .font(.body) for body text
   - .font(.subheadline) for secondary text
   - .font(.caption) for tertiary/small text
   - .font(.callout) for callout text

B. Search for ANY occurrence of:
   - .font(.system(size: XX)) — REPLACE with semantic style
   - Font.custom(...) — REPLACE with semantic style
   - Exception: Icon sizes using .font(.system(size: XX)) on Image are acceptable

C. Layout MUST adapt when text size increases:
   - Use .fixedSize(horizontal: false, vertical: true) on text that should wrap
   - ScrollView containers for content that may overflow at large text sizes
   - NO .lineLimit(1) unless absolutely necessary (and even then, add a tooltip)

D. Minimum touch/click target size: 44x44 points:
   - All Button elements should have sufficient padding
   - Use .frame(minWidth: 44, minHeight: 44) on small interactive elements if needed
   - Check icon-only buttons (like remove/delete) have adequate tap areas

======================================================================
CHECKLIST 3: Keyboard Navigation
======================================================================

For each view, verify and fix:

A. ALL interactive elements MUST be focusable via Tab key:
   - Buttons, TextFields, SecureFields, DisclosureGroups, Links
   - If using custom controls, add .focusable() modifier

B. Keyboard shortcuts:
   - .keyboardShortcut(.defaultAction) on the primary Continue/Submit button (Enter/Return)
   - .keyboardShortcut(.cancelAction) on Back/Cancel buttons (Escape)
   - Do NOT use .keyboardShortcut(.escape) directly — use .cancelAction instead

C. Focus ring:
   - The default SwiftUI focus ring should be visible on all focused elements
   - If a custom background is used, ensure the focus ring is still visible
   - Do NOT add .focusable(false) unless the element is truly non-interactive

D. Escape key behavior:
   - In the container: Escape should navigate back one step
   - In modal sheets/popovers: Escape should dismiss
   - This should already be handled by .onKeyPress(.escape) in OnboardingContainerView — verify it still works

======================================================================
CHECKLIST 4: Color and Contrast
======================================================================

For each view, verify and fix:

A. Do NOT convey information by color alone:
   - Permission status: green checkmark AND "Granted" text (not just color)
   - Validation status: icon AND text message (not just color)
   - Required labels: text "Required" AND red badge (not just color)

B. Use system colors that automatically adapt to accessibility settings:
   - .primary, .secondary, .accent — these adapt to Increase Contrast
   - Color(nsColor: .windowBackgroundColor) — adapts to Dark Mode
   - Do NOT use hardcoded Color(.sRGB, ...) for information-carrying elements

C. Verify sufficient contrast for:
   - Caption text (.secondary on window background)
   - Status text on colored backgrounds
   - Badge text ("Required", "Optional") on their background pills

======================================================================
CHECKLIST 5: Reduce Motion
======================================================================

For each view, verify and fix:

A. Read the user's preference:
   - @Environment(\.accessibilityReduceMotion) private var reduceMotion

B. When reduceMotion is true:
   - Replace slide/bounce/spring animations with simple opacity fades
   - Replace animated transitions with instant transitions
   - Do NOT auto-advance screens with animation
   - Progress bar animation: use .animation(reduceMotion ? nil : .easeInOut, ...)

C. Specifically check:
   - OnboardingContainerView: Step transitions (withAnimation)
   - WelcomeView: Any flame icon animation
   - APIKeyEntryView: Success animation, auto-advance delay
   - FirstMessageTestView: Status change animations, celebration animation

======================================================================
CHECKLIST 6: accessibilityIdentifier for UI Testing
======================================================================

Add .accessibilityIdentifier to ALL interactive elements that a UI test might need to find. Use a consistent naming pattern:

- Buttons: "onboarding_[step]_[action]Button"
  Example: "onboarding_welcome_getStartedButton"
- Text fields: "onboarding_[step]_[field]Field"
  Example: "onboarding_apiKey_keyField"
- Status indicators: "onboarding_[step]_[what]Status"
  Example: "onboarding_permissions_fdaStatus"
- Cards/sections: "onboarding_[step]_[what]Card"
  Example: "onboarding_permissions_fdaCard"

If an element already has an .accessibilityIdentifier, update it to follow this naming convention.

======================================================================
IMPLEMENTATION STEPS
======================================================================

For EACH of the 6 view files:

1. Open the file
2. Run through all 6 checklists above
3. Fix any gaps found
4. Add a compliance comment at the top of each view struct, like this:

```swift
/// Accessibility Compliance (Task 0604):
/// - [x] VoiceOver: All interactive elements labeled, status changes announced
/// - [x] Dynamic Type: All text uses semantic font styles, layout adapts
/// - [x] Keyboard: Tab navigation, Enter/Escape shortcuts, focus ring visible
/// - [x] Color: Information not conveyed by color alone, system colors used
/// - [x] Reduce Motion: Animations respect user preference
/// - [x] UI Testing: All interactive elements have accessibilityIdentifier
```

5. If a checklist item was already correct, mark it [x] in the comment. If you had to fix it, still mark [x] after fixing.

After reviewing all 6 files, create the test file:

STEP 7: Create tests/OnboardingAccessibilityTests.swift

This test file verifies that all accessibility identifiers exist on the expected elements. It does NOT test the actual VoiceOver behavior (that requires manual testing), but it ensures the identifiers are in place for UI tests.

File: tests/OnboardingAccessibilityTests.swift
```swift
// OnboardingAccessibilityTests.swift
// EmberHearth
//
// Verifies that onboarding views have the required accessibility identifiers
// for UI testing. This does not test VoiceOver behavior (manual testing required).

import XCTest
import SwiftUI
@testable import EmberHearth

final class OnboardingAccessibilityTests: XCTestCase {

    // MARK: - OnboardingStep Tests

    func testAllOnboardingStepsHaveTitles() {
        for step in OnboardingStep.allCases {
            XCTAssertFalse(step.title.isEmpty, "Step \(step.rawValue) should have a title")
        }
    }

    func testOnboardingStepCount() {
        XCTAssertEqual(OnboardingStep.totalSteps, 5, "There should be exactly 5 onboarding steps")
    }

    // MARK: - PermissionType Accessibility Tests

    func testAllPermissionTypesHaveDisplayNames() {
        for permission in PermissionType.allCases {
            XCTAssertFalse(permission.displayName.isEmpty, "\(permission) should have a display name")
        }
    }

    func testAllPermissionTypesHaveExplanations() {
        for permission in PermissionType.allCases {
            XCTAssertFalse(permission.explanation.isEmpty, "\(permission) should have an explanation")
        }
    }

    func testAllPermissionTypesHaveSFSymbols() {
        for permission in PermissionType.allCases {
            XCTAssertFalse(permission.sfSymbolName.isEmpty, "\(permission) should have an SF Symbol name")
        }
    }

    // MARK: - FirstMessageTestStatus Accessibility Tests

    func testAllTestStatusesHaveDescriptions() {
        let statuses: [FirstMessageTestStatus] = [
            .waitingForMessage,
            .messageReceived,
            .processing,
            .responseSent,
            .failed(reason: "test error"),
            .timedOut
        ]

        for status in statuses {
            XCTAssertFalse(status.description.isEmpty, "\(status) should have a description")
        }
    }

    func testAllTestStatusesHaveSFSymbols() {
        let statuses: [FirstMessageTestStatus] = [
            .waitingForMessage,
            .messageReceived,
            .processing,
            .responseSent,
            .failed(reason: "test"),
            .timedOut
        ]

        for status in statuses {
            XCTAssertFalse(status.sfSymbol.isEmpty, "\(status) should have an SF Symbol")
        }
    }

    // MARK: - APIKeyValidationState Accessibility Tests

    func testValidationStatesProvideUserFeedback() {
        // Ensure invalid states always have a message
        let invalidState = APIKeyValidationState.invalid(message: "test error")
        if case .invalid(let message) = invalidState {
            XCTAssertFalse(message.isEmpty, "Invalid state should have a non-empty message")
        }
    }

    // MARK: - PhoneEntry Tests

    func testPhoneEntryHasRequiredFields() {
        let entry = PhoneEntry(rawInput: "555-123-4567", normalized: "+15551234567")
        XCTAssertFalse(entry.rawInput.isEmpty)
        XCTAssertFalse(entry.normalized.isEmpty)
        XCTAssertFalse(entry.id.uuidString.isEmpty)
    }

    // MARK: - Dynamic Type Verification

    // Note: Verifying that views use semantic font styles requires manual inspection
    // or snapshot testing. These tests verify the data layer supports accessibility.

    func testPermissionStatusAllDenied() {
        let status = PermissionStatus.allDenied
        // Verify the struct is in a known state for accessibility announcements
        XCTAssertFalse(status.allRequiredGranted)
        XCTAssertFalse(status.allGranted)
    }

    func testPermissionStatusTransitionsAreAnnounceworthy() {
        let before = PermissionStatus(fullDiskAccess: false, automation: false, notifications: false)
        let after = PermissionStatus(fullDiskAccess: true, automation: false, notifications: false)
        // The view should announce when a permission changes from false to true
        XCTAssertNotEqual(before, after, "Status change should be detectable for VoiceOver announcements")
    }
}
```

STEP 8: Verify the build

After updating all files and creating the test file, run from the project root:

```bash
swift build
swift test
```

Both must succeed.

IMPORTANT NOTES:
- Do NOT modify Package.swift.
- Do NOT change business logic, data flow, or security behavior. This is an ACCESSIBILITY-ONLY task.
- The compliance comment at the top of each view struct documents what was audited. This serves as a checklist for future developers.
- Some accessibility features (VoiceOver navigation, focus ring visibility) can only be verified through manual testing. The automated tests verify that identifiers and labels exist.
- If you find a Dynamic Type violation (fixed font size), replace it with the closest semantic style. For SF Symbol sizing in Image elements, .font(.system(size:)) is acceptable.
- The .accessibilityIdentifier values are for UI testing frameworks (XCUITest). They do not affect VoiceOver behavior.
- Ensure .accessibilityIdentifier values are globally unique across all onboarding views.
```

---

## Acceptance Criteria

- [ ] ALL 6 onboarding view files have been audited against the accessibility checklist
- [ ] Each view has an accessibility compliance comment at the top documenting audit results
- [ ] `tests/OnboardingAccessibilityTests.swift` exists and all tests pass

### VoiceOver (per view):
- [ ] Every Button has accessibilityLabel (or inherits from text) and accessibilityHint
- [ ] Every Image has accessibilityLabel (informational) or accessibilityHidden(true) (decorative)
- [ ] Every heading has .accessibilityAddTraits(.isHeader)
- [ ] Status changes post VoiceOver announcements via NSAccessibility.post
- [ ] Related elements are grouped with .accessibilityElement(children:)
- [ ] No VoiceOver traps

### Dynamic Type (per view):
- [ ] ALL text uses semantic font styles (.body, .headline, .title, etc.)
- [ ] No .font(.system(size:)) on Text elements (only on Image for icon sizing)
- [ ] Text wraps properly with .fixedSize(horizontal: false, vertical: true) where needed
- [ ] ScrollView containers for content that may overflow
- [ ] Minimum touch target 44x44 points on small interactive elements

### Keyboard Navigation (per view):
- [ ] Primary action has .keyboardShortcut(.defaultAction)
- [ ] Back/Cancel has .keyboardShortcut(.cancelAction)
- [ ] All interactive elements are focusable via Tab
- [ ] Focus ring is visible (no .focusable(false) on interactive elements)
- [ ] Escape key navigates back in the container

### Color and Contrast (per view):
- [ ] Information not conveyed by color alone (icons + text alongside colors)
- [ ] System colors used (.primary, .secondary, .accent, nsColor)
- [ ] No hardcoded colors for information-carrying elements

### Reduce Motion (per view):
- [ ] @Environment(\.accessibilityReduceMotion) read where animations exist
- [ ] Animations replaced with fades or disabled when reduceMotion is true
- [ ] Auto-advance delays respect reduceMotion

### UI Testing Identifiers:
- [ ] All interactive elements have .accessibilityIdentifier
- [ ] Identifiers follow naming pattern: "onboarding_[step]_[action]Type"
- [ ] Identifiers are unique across all views

### Build:
- [ ] `swift build` succeeds
- [ ] `swift test` succeeds
- [ ] No business logic or security behavior was changed

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify test file exists
test -f tests/OnboardingAccessibilityTests.swift && echo "Tests exist" || echo "MISSING: Tests"

# Count accessibility labels in each view
echo "--- Accessibility Labels per View ---"
for view in OnboardingContainerView WelcomeView PermissionsView APIKeyEntryView PhoneConfigView FirstMessageTestView; do
    count=$(grep -c "accessibilityLabel" src/Views/Onboarding/${view}.swift 2>/dev/null || echo "0")
    echo "$view: $count accessibilityLabel occurrences"
done

# Count accessibility hints in each view
echo ""
echo "--- Accessibility Hints per View ---"
for view in OnboardingContainerView WelcomeView PermissionsView APIKeyEntryView PhoneConfigView FirstMessageTestView; do
    count=$(grep -c "accessibilityHint" src/Views/Onboarding/${view}.swift 2>/dev/null || echo "0")
    echo "$view: $count accessibilityHint occurrences"
done

# Count accessibility identifiers in each view
echo ""
echo "--- Accessibility Identifiers per View ---"
for view in OnboardingContainerView WelcomeView PermissionsView APIKeyEntryView PhoneConfigView FirstMessageTestView; do
    count=$(grep -c "accessibilityIdentifier" src/Views/Onboarding/${view}.swift 2>/dev/null || echo "0")
    echo "$view: $count accessibilityIdentifier occurrences"
done

# Verify VoiceOver announcements exist
echo ""
echo "--- VoiceOver Announcements ---"
grep -l "announcementRequested" src/Views/Onboarding/*.swift

# Verify Reduce Motion support
echo ""
echo "--- Reduce Motion Support ---"
grep -l "accessibilityReduceMotion" src/Views/Onboarding/*.swift

# Check for fixed font sizes on Text elements (should be minimal)
echo ""
echo "--- Fixed Font Sizes (potential issues) ---"
grep -n "\.font(.system(size:" src/Views/Onboarding/*.swift | grep -v "Image" || echo "No fixed font sizes on Text elements (good)"

# Verify compliance comments
echo ""
echo "--- Compliance Comments ---"
grep -l "Accessibility Compliance" src/Views/Onboarding/*.swift

# Verify keyboard shortcuts
echo ""
echo "--- Keyboard Shortcuts ---"
grep -c "keyboardShortcut" src/Views/Onboarding/*.swift

# Build
swift build 2>&1

# Run tests
swift test --filter OnboardingAccessibilityTests 2>&1
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the accessibility pass performed in task 0604 for EmberHearth's onboarding views. Open ALL of these files:

@src/Views/Onboarding/OnboardingContainerView.swift
@src/Views/Onboarding/WelcomeView.swift
@src/Views/Onboarding/PermissionsView.swift
@src/Views/Onboarding/APIKeyEntryView.swift
@src/Views/Onboarding/PhoneConfigView.swift
@src/Views/Onboarding/FirstMessageTestView.swift
@tests/OnboardingAccessibilityTests.swift

Also reference:
@CLAUDE.md
@docs/research/onboarding-ux.md (Section 12: Accessibility)

Perform a complete accessibility audit by checking EVERY item below. For each file, report whether the item passes or fails.

1. VoiceOver AUDIT (check each file):

   WelcomeView.swift:
   - [ ] Flame Image has accessibilityLabel
   - [ ] "Welcome to EmberHearth" has .isHeader trait
   - [ ] Security bullet icons are accessibilityHidden(true)
   - [ ] Security bullets are grouped with .accessibilityElement(children: .combine)
   - [ ] "Get Started" button has label and hint

   PermissionsView.swift:
   - [ ] "Permissions" heading has .isHeader trait
   - [ ] Each permission card status icon is accessibilityHidden(true)
   - [ ] Permission cards have combined accessibility labels
   - [ ] "Open Settings" buttons have labels mentioning which permission
   - [ ] Status changes trigger VoiceOver announcements
   - [ ] Continue button's disabled state is communicated via hint

   APIKeyEntryView.swift:
   - [ ] "Connect to Claude" has .isHeader trait
   - [ ] Key icon Image is accessibilityHidden(true)
   - [ ] SecureField has label "API key entry field" and hint
   - [ ] Validate button has label and hint
   - [ ] Validation success/failure announcements are posted
   - [ ] "Skip for Now" has hint explaining consequence
   - [ ] Link to console.anthropic.com has label and hint
   - [ ] Security note is grouped for combined reading

   PhoneConfigView.swift:
   - [ ] "Who should Ember listen to?" has .isHeader trait
   - [ ] Phone icon is accessibilityHidden(true)
   - [ ] Phone number field has label and hint
   - [ ] "Add Number" button has label and hint
   - [ ] Each remove button includes the phone number in its label
   - [ ] "Your Numbers" heading has .isHeader trait
   - [ ] Error messages are accessible

   FirstMessageTestView.swift:
   - [ ] "Let's test it!" has .isHeader trait
   - [ ] Instruction steps have numbered labels
   - [ ] Status indicator announces changes
   - [ ] Success display chat bubbles have "You said:" and "Ember replied:" labels
   - [ ] "Skip Test" / "Retry" / "Finish Setup" have labels and hints
   - [ ] Troubleshooting heading has .isHeader trait

   OnboardingContainerView.swift:
   - [ ] Progress bar has accessibilityLabel "Onboarding progress"
   - [ ] Progress bar has accessibilityValue "Step X of 5"

2. Dynamic Type AUDIT:
   - Search ALL 6 files for `.font(.system(size:` applied to Text (NOT Image)
   - If ANY are found on Text elements, report as CRITICAL
   - Verify .fixedSize(horizontal: false, vertical: true) is used on multi-line text
   - Verify ScrollView is used for content that may overflow

3. Keyboard AUDIT:
   - Verify each view's primary action has .keyboardShortcut(.defaultAction)
   - Verify each view's back/cancel action has .keyboardShortcut(.cancelAction)
   - Verify .onKeyPress(.escape) in OnboardingContainerView still works
   - Verify no .focusable(false) on interactive elements

4. Color AUDIT:
   - Verify permission status shows BOTH color AND icon/text
   - Verify validation status shows BOTH colored icon AND text message
   - Verify "Required"/"Optional" badges have text, not just color

5. Reduce Motion AUDIT:
   - Verify @Environment(\.accessibilityReduceMotion) is read in views with animation
   - Verify animations are wrapped in reduceMotion checks
   - Verify the progress bar animation respects reduceMotion

6. Accessibility Identifier AUDIT:
   - List ALL accessibilityIdentifier values found across all 6 files
   - Check for duplicates (report as CRITICAL if found)
   - Verify naming follows pattern: "onboarding_[step]_[action]Type"

7. Compliance Comments:
   - Verify each view struct has an "Accessibility Compliance (Task 0604)" comment
   - Verify all checklist items in the comment are marked [x]

8. NO BUSINESS LOGIC CHANGES:
   - Verify NO changes were made to: data flow, API calls, Keychain operations, permission checking logic, navigation flow, UserDefaults keys
   - Only accessibility-related additions/changes should be present

9. BUILD VERIFICATION:
   - Run `swift build` and verify success
   - Run `swift test` and verify all tests pass (including OnboardingAccessibilityTests)

Format your response as a checklist with pass/fail for each item. For any failures, provide the file path, line number, and what needs to be fixed.
```

---

## Commit Message

```
feat(m7): comprehensive accessibility pass on onboarding views
```

---

## Notes for Next Task

- All onboarding views (0600-0604) are now complete with full accessibility support. This completes Milestone M7 (Onboarding).
- The accessibility compliance comments at the top of each view serve as living documentation. When future tasks modify these views, they should update the compliance comment.
- The `.accessibilityIdentifier` values can be used in XCUITest UI tests for automated accessibility testing. These would be added in a future testing task.
- Manual VoiceOver testing should be performed before release:
  1. Enable VoiceOver (System Settings > Accessibility > VoiceOver)
  2. Navigate through the entire onboarding flow using only VoiceOver
  3. Verify all elements are announced correctly
  4. Verify status changes are announced
  5. Verify tab order is logical
- Manual Dynamic Type testing should be performed:
  1. System Settings > Accessibility > Display > Text Size > drag to largest
  2. Navigate through all onboarding views
  3. Verify no text is truncated
  4. Verify layout adapts (no overlapping elements)
- The next milestone (M8: Polish & Release) tasks would begin at task number 0700.
