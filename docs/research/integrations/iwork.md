# iWork Apps Integration Research

**Status:** Complete
**Priority:** Low
**Last Updated:** February 2, 2026

---

## Overview

Apple's iWork suite includes Pages (documents), Numbers (spreadsheets), and Keynote (presentations). These apps have AppleScript support for automation.

## User Value

| Capability | User Benefit |
|------------|--------------|
| Document creation | "Create a memo about X" |
| Data extraction | "What's in my budget spreadsheet?" |
| Export options | "Export as PDF" |
| Template usage | Quick document creation |

---

## Technical Approach: AppleScript

All three iWork apps support AppleScript with a shared scripting terminology.

### Shared AppleScript Suites

The iWork apps share common scripting for:
- Text manipulation
- Charts and images
- Tables
- Audio/video elements
- Document management

---

# Pages (Word Processing)

### Capabilities

| Feature | AppleScript Support |
|---------|-------------------|
| Create documents | Yes |
| Add/edit text | Yes |
| Insert images | Yes |
| Apply styles | Yes |
| Export PDF | Yes |
| Use templates | Yes |

### Implementation

```applescript
-- Create a new document
tell application "Pages"
    set newDoc to make new document
    tell newDoc
        set body text to "Hello from EmberHearth"
    end tell
end tell

-- Export as PDF
tell application "Pages"
    tell document 1
        export to file "/Users/name/Desktop/output.pdf" as PDF
    end tell
end tell
```

### Swift Wrapper

```swift
func createPagesDocument(content: String, savePath: String) -> Bool {
    let script = """
    tell application "Pages"
        activate
        set newDoc to make new document
        tell newDoc
            set body text to "\(content.escapedForAppleScript)"
        end tell
        save newDoc in POSIX file "\(savePath)"
    end tell
    return true
    """

    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
        scriptObject.executeAndReturnError(&error)
        return error == nil
    }
    return false
}
```

---

# Numbers (Spreadsheets)

### Capabilities

| Feature | AppleScript Support |
|---------|-------------------|
| Create spreadsheets | Yes |
| Read/write cells | Yes |
| Create charts | Yes |
| Apply formulas | Yes |
| Export CSV/PDF | Yes |

### Implementation

```applescript
-- Read data from a spreadsheet
tell application "Numbers"
    tell document 1
        tell sheet 1
            tell table 1
                set cellValue to value of cell "A1"
            end tell
        end tell
    end tell
end tell

-- Write to a cell
tell application "Numbers"
    tell document 1
        tell sheet 1
            tell table 1
                set value of cell "B2" to "Hello"
            end tell
        end tell
    end tell
end tell
```

### Reading Spreadsheet Data

```swift
func readNumbersCell(document: String, sheet: String, table: String, cell: String) -> String? {
    let script = """
    tell application "Numbers"
        tell document "\(document)"
            tell sheet "\(sheet)"
                tell table "\(table)"
                    return value of cell "\(cell)" as string
                end tell
            end tell
        end tell
    end tell
    """

    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
        let result = scriptObject.executeAndReturnError(&error)
        return result.stringValue
    }
    return nil
}
```

---

# Keynote (Presentations)

### Capabilities

| Feature | AppleScript Support |
|---------|-------------------|
| Create presentations | Yes |
| Add/edit slides | Yes |
| Insert media | Yes |
| Control playback | Yes |
| Export PDF/video | Yes |

### Implementation

```applescript
-- Create a new presentation
tell application "Keynote"
    set newPresentation to make new document with properties {document theme: theme "Basic White"}
    tell newPresentation
        tell slide 1
            set object text of default title item to "My Title"
        end tell
    end tell
end tell

-- Start slideshow
tell application "Keynote"
    tell document 1
        start from first slide
    end tell
end tell
```

---

## EmberHearth Integration Design

### Conversation Examples

**User:** "Create a memo about the project update"
**EmberHearth:** "I'll create a Pages document with your memo. What should it say?"

**User:** "The project is on track. Key milestones completed: Phase 1 testing, Design review. Next steps: Begin Phase 2 development."

**EmberHearth:** "Created 'Project Update Memo.pages' on your Desktop with:
- Title: Project Update
- Date: February 2, 2026
- Content: [Your memo text]

Would you like me to export it as PDF?"

**User:** "What's my budget total in the Q1 spreadsheet?"
**EmberHearth:** "Looking at 'Q1 Budget.numbers'...
The total in column D (row 15) is $45,230.00."

**User:** "Create a simple presentation about our new product"
**EmberHearth:** "I can create a Keynote presentation. How many slides do you need, and what should each one cover?"

---

## Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| App must be running | Scripts require app to be open | Launch app via script |
| Complex formatting | Limited via AppleScript | Keep documents simple |
| Version compatibility | Scripts may break | Test across versions |
| No Swift API | AppleScript only | Scripting Bridge (limited) |

---

## Use Cases for EmberHearth

### High Value
- Quick document creation with content
- Reading data from spreadsheets
- Exporting documents as PDF

### Medium Value
- Creating presentations from outlines
- Updating specific cells in spreadsheets
- Batch document operations

### Low Value (Complex)
- Complex formatting
- Chart creation
- Interactive presentations

---

## Implementation Priority

| Feature | Priority | Complexity |
|---------|----------|------------|
| Create simple Pages doc | Medium | Low |
| Read Numbers data | Medium | Medium |
| Export to PDF | Medium | Low |
| Create Keynote | Low | Medium |
| Update spreadsheet cells | Low | Medium |

---

## Resources

- [iWorkAutomation.com](https://iworkautomation.com/) - Comprehensive iWork scripting guide
- [AppleScript for Pages](https://iworkautomation.com/pages/)
- [AppleScript for Numbers](https://iworkautomation.com/numbers/)
- [AppleScript for Keynote](https://iworkautomation.com/keynote/)

---

## Recommendation

**Feasibility: MEDIUM**

iWork apps have decent AppleScript support, but:

1. Complex operations are difficult
2. Limited to basic document manipulation
3. Apps must be running (disruptive UX)

Best suited for:
- Quick memo/document creation
- Reading simple spreadsheet data
- PDF export

Not recommended for complex document editing—better to guide users to do that directly in the apps.
