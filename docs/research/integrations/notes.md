# Notes Integration Research

**Status:** Complete
**Priority:** High
**Last Updated:** February 2, 2026

---

## Overview

Apple Notes is a popular note-taking app that syncs across devices via iCloud. Integration would enable EmberHearth to help users capture, organize, and retrieve information through natural conversation.

## User Value

| Capability | User Benefit |
|------------|--------------|
| Quick capture | "Add this to my notes" via iMessage |
| Search notes | "What did I write about project X?" |
| Summarize notes | Condense long notes into key points |
| Organize | Create/manage folders, move notes |
| Synthesize | Combine related notes into new documents |

---

## Technical Approaches

### 1. AppleScript (Primary Approach)

Notes.app has AppleScript support, though with some limitations.

**Capabilities:**
- Create notes
- Read note content
- List notes and folders
- Move notes between folders
- Search notes (limited)
- Delete notes

**Example - Create a Note:**
```applescript
tell application "Notes"
    tell account "iCloud"
        make new note at folder "Notes" with properties {
            name: "Quick thought",
            body: "<html><body>This is the note content.</body></html>"
        }
    end tell
end tell
```

**Example - Read All Notes:**
```applescript
tell application "Notes"
    set allNotes to every note
    repeat with aNote in allNotes
        set noteName to name of aNote
        set noteBody to body of aNote  -- Returns HTML
        set noteFolder to container of aNote
        -- Process note
    end repeat
end tell
```

**Example - Search Notes:**
```applescript
tell application "Notes"
    set foundNotes to notes whose name contains "project"
end tell
```

**Example - Create Folder:**
```applescript
tell application "Notes"
    tell account "iCloud"
        make new folder with properties {name: "Work Projects"}
    end tell
end tell
```

### 2. Direct Database Access (Read-Only Alternative)

Notes data is stored in a SQLite database, accessible for faster read operations.

**Location:** `~/Library/Group Containers/group.com.apple.notes/`

**Tools:**
- [apple-notes-parser](https://github.com/threeplanetssoftware/apple_cloud_notes_parser) - Read-only parser
- Supports tags, folders, and attachments
- Faster than AppleScript for bulk reads

**Caution:** Database schema may change between macOS versions. AppleScript is more stable for production use.

### 3. MCP Server Solutions

Several MCP (Model Context Protocol) servers exist for Notes integration:

- **mcp-apple-notes** (PyPI) - Python-based MCP server
- Enables CRUD operations through standardized interface
- Works with MCP-compatible AI clients

---

## Permissions Required

| Permission | Purpose | How to Grant |
|------------|---------|--------------|
| Automation | Control Notes.app | Prompted on first AppleScript |
| Full Disk Access | Direct database reads | System Settings → Privacy |

**Note:** AppleScript access alone doesn't require Full Disk Access.

---

## Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| Password-protected notes | Cannot access locked notes | Skip or prompt user to unlock |
| Tags (#tagname) | Can read but not add via AppleScript | Tags appear as plaintext if added |
| Nested folders | Only top-level folders accessible | Flatten structure or use naming conventions |
| Attachments | Position info not available | Reference attachments by name |
| HTML formatting | Body returns HTML, not plain text | Parse HTML or strip tags |
| iCloud sync delay | Changes may take time to sync | Wait for sync confirmation |

---

## Implementation

### Swift AppleScript Wrapper

```swift
import Foundation

class NotesService {

    func createNote(title: String, content: String, folder: String = "Notes") throws -> Bool {
        let escapedContent = content
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "<br>")

        let script = """
        tell application "Notes"
            tell account "iCloud"
                make new note at folder "\(folder)" with properties {
                    name: "\(title)",
                    body: "<html><body>\(escapedContent)</body></html>"
                }
            end tell
        end tell
        return true
        """

        return executeAppleScript(script)
    }

    func getAllNotes() -> [NoteSummary] {
        let script = """
        tell application "Notes"
            set output to ""
            repeat with aNote in notes
                set output to output & id of aNote & "|||"
                set output to output & name of aNote & "|||"
                set output to output & modification date of aNote & "\\n"
            end repeat
            return output
        end tell
        """

        // Parse output into NoteSummary objects
        guard let output = executeAppleScriptWithOutput(script) else { return [] }
        return parseNotesList(output)
    }

    func getNoteContent(noteId: String) -> String? {
        let script = """
        tell application "Notes"
            set targetNote to first note whose id is "\(noteId)"
            return body of targetNote
        end tell
        """

        return executeAppleScriptWithOutput(script)
    }

    func searchNotes(query: String) -> [NoteSummary] {
        let script = """
        tell application "Notes"
            set output to ""
            set foundNotes to notes whose name contains "\(query)" or body contains "\(query)"
            repeat with aNote in foundNotes
                set output to output & id of aNote & "|||"
                set output to output & name of aNote & "\\n"
            end repeat
            return output
        end tell
        """

        guard let output = executeAppleScriptWithOutput(script) else { return [] }
        return parseNotesList(output)
    }

    func appendToNote(noteId: String, content: String) throws {
        let script = """
        tell application "Notes"
            set targetNote to first note whose id is "\(noteId)"
            set currentBody to body of targetNote
            set body of targetNote to currentBody & "<br><br>\(content)"
        end tell
        """

        _ = executeAppleScript(script)
    }

    private func executeAppleScript(_ script: String) -> Bool {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            return error == nil
        }
        return false
    }

    private func executeAppleScriptWithOutput(_ script: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)
            return output.stringValue
        }
        return nil
    }
}

struct NoteSummary {
    let id: String
    let title: String
    let modificationDate: Date?
}
```

### HTML to Plain Text

```swift
import Foundation

extension String {
    func strippingHTML() -> String {
        guard let data = self.data(using: .utf8) else { return self }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }

        // Fallback: regex strip
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
```

---

## EmberHearth Integration Design

### Conversation Examples

**User:** "Save this to my notes: Meeting with client went well. They want to proceed with Phase 2."
**EmberHearth:** "I've created a new note:
- **Title:** Meeting Notes (Feb 2, 2026)
- **Folder:** Notes
- **Content:** Meeting with client went well. They want to proceed with Phase 2.

Want me to add it to a specific folder?"

**User:** "What notes do I have about the Johnson project?"
**EmberHearth:** "I found 3 notes mentioning 'Johnson project':
1. **Johnson Project Kickoff** (Jan 15) - Initial requirements and timeline
2. **Johnson Project Budget** (Jan 22) - Cost estimates and approvals
3. **Johnson Meeting Notes** (Jan 30) - Status update and next steps

Would you like me to summarize any of these?"

**User:** "Combine those into a single project summary"
**EmberHearth:** "I've created a new note **Johnson Project Summary** that combines the key points from all 3 notes:

## Overview
- Kickoff: Jan 15, 2026
- Budget: Approved at $50,000
- Status: Phase 1 complete, Phase 2 starting Feb 10

## Key Decisions
[...]

The original notes are unchanged. Want me to move them to an archive folder?"

### Quick Capture Flow

```
User sends photo via iMessage
    → EmberHearth: "Would you like me to save this image to Notes?"
    → User: "Yes, add it to my receipts folder"
    → EmberHearth creates note with image attachment
```

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      EmberHearth                             │
├─────────────────────────────────────────────────────────────┤
│  NotesService                                                │
│  ├── NoteCreator                                            │
│  │   ├── Text notes                                         │
│  │   └── Notes with attachments                             │
│  ├── NoteReader                                             │
│  │   ├── AppleScript (default)                              │
│  │   └── Database (bulk reads, optional)                    │
│  ├── NoteSearcher                                           │
│  │   └── Title/content search                               │
│  ├── NoteSummarizer                                         │
│  │   └── LLM-based summarization                            │
│  └── NoteSynthesizer                                        │
│       └── Combine multiple notes                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Security Considerations

1. **Sensitive Content:** Notes may contain passwords, personal info
   - Never log note content
   - Don't send to external services without consent

2. **iCloud Sync:** Notes sync across devices
   - Changes affect all devices
   - Warn before bulk operations

3. **Shared Notes:** Some notes may be shared with others
   - Check sharing status before modifications
   - Warn user about shared note edits

---

## Implementation Priority

| Feature | Priority | Complexity |
|---------|----------|------------|
| Create note | High | Low |
| List notes | High | Low |
| Search notes | High | Low |
| Read note content | High | Low |
| Append to note | Medium | Low |
| Summarize note | Medium | Medium |
| Combine notes | Low | Medium |
| Folder management | Low | Low |

---

## Testing Checklist

- [ ] Create note in default folder
- [ ] Create note in specific folder
- [ ] List all notes
- [ ] Search by title
- [ ] Search by content
- [ ] Read note with HTML formatting
- [ ] Handle special characters
- [ ] Handle empty notes
- [ ] Test with multiple iCloud accounts
- [ ] Verify sync after modifications

---

## Resources

- [macosxautomation.com: Notes AppleScript](https://www.macosxautomation.com/applescript/notes/)
- [RhetTbull/macnotesapp](https://github.com/RhetTbull/macnotesapp) - Python CLI for Notes
- [mcp-apple-notes](https://pypi.org/project/mcp-apple-notes/) - MCP Server

---

## Recommendation

**Feasibility: MEDIUM-HIGH**

Notes.app has usable AppleScript support, though with limitations around tags, nested folders, and password-protected notes. For EmberHearth:

1. **Phase 1:** Basic CRUD operations (create, read, search)
2. **Phase 2:** LLM-powered summarization and synthesis
3. **Phase 3:** Smart organization and tagging workarounds

The inability to properly handle tags is a notable gap, but the core note-taking functionality works well. This integration is valuable for quick capture scenarios where users want to save thoughts via iMessage without switching apps.
