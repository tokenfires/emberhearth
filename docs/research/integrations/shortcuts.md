# Shortcuts & App Intents Integration Research

**Status:** Complete
**Priority:** High
**Last Updated:** February 2, 2026

---

## Overview

Shortcuts (formerly Workflow) and the App Intents framework allow EmberHearth to both expose its own capabilities and leverage user-created automations. This is key to extensibility.

## User Value

| Capability | User Benefit |
|------------|--------------|
| Run user shortcuts | "Run my morning routine" |
| Create shortcuts | Build automations via conversation |
| Expose EmberHearth actions | Use EmberHearth in other shortcuts |
| Siri integration | Voice-activated EmberHearth features |
| Automation triggers | Time/location-based EmberHearth actions |

---

## Technical Approaches

### 1. App Intents Framework (Primary)

App Intents is Apple's modern, Swift-native framework for creating Shortcuts actions and Siri commands.

**Capabilities:**
- Define custom actions for Shortcuts app
- Expose actions to Siri
- Appear in Spotlight search
- Work with Action button (iPhone/Watch)
- Parameter validation and type safety

### 2. Running Existing Shortcuts

EmberHearth can trigger user's existing shortcuts via AppleScript or URL schemes.

### 3. SiriKit (Legacy)

Older framework, mostly superseded by App Intents. Still relevant for specific domains.

---

## Implementation: App Intents

### Defining an Intent

```swift
import AppIntents

struct SendMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Message via EmberHearth"
    static var description = IntentDescription("Send a message through EmberHearth")

    @Parameter(title: "Recipient")
    var recipient: String

    @Parameter(title: "Message")
    var message: String

    func perform() async throws -> some IntentResult {
        // Send message via EmberHearth's message service
        try await MessageService.shared.send(message, to: recipient)
        return .result(dialog: "Message sent to \(recipient)")
    }
}
```

### App Shortcuts (Automatic Discovery)

```swift
import AppIntents

struct EmberHearthShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendMessageIntent(),
            phrases: [
                "Send a message with \(.applicationName)",
                "Text someone using \(.applicationName)"
            ],
            shortTitle: "Send Message",
            systemImageName: "message"
        )

        AppShortcut(
            intent: MorningBriefingIntent(),
            phrases: [
                "Get my morning briefing from \(.applicationName)",
                "What's my day look like with \(.applicationName)"
            ],
            shortTitle: "Morning Briefing",
            systemImageName: "sun.horizon"
        )

        AppShortcut(
            intent: QuickNoteIntent(),
            phrases: [
                "Save a note with \(.applicationName)",
                "Remember this with \(.applicationName)"
            ],
            shortTitle: "Quick Note",
            systemImageName: "note.text"
        )
    }
}
```

### Intent with Options

```swift
struct SearchNotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Notes"

    @Parameter(title: "Search Query")
    var query: String

    @Parameter(title: "Folder", optionsProvider: NoteFoldersProvider())
    var folder: String?

    func perform() async throws -> some ReturnsValue<[String]> {
        let notes = try await NotesService.shared.search(query, in: folder)
        let titles = notes.map { $0.title }
        return .result(value: titles)
    }
}

struct NoteFoldersProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        return try await NotesService.shared.getFolders()
    }
}
```

### Foreground Execution

```swift
struct ConfigureSettingsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open EmberHearth Settings"

    // Open app before running
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // App is now in foreground
        NotificationCenter.default.post(name: .openSettings, object: nil)
        return .result()
    }
}
```

---

## Running User Shortcuts

### Via URL Scheme

```swift
func runShortcut(named name: String) {
    let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
    if let url = URL(string: "shortcuts://run-shortcut?name=\(encodedName)") {
        NSWorkspace.shared.open(url)
    }
}

func runShortcutWithInput(named name: String, input: String) {
    let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
    let encodedInput = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
    if let url = URL(string: "shortcuts://run-shortcut?name=\(encodedName)&input=text&text=\(encodedInput)") {
        NSWorkspace.shared.open(url)
    }
}
```

### Via AppleScript

```applescript
tell application "Shortcuts Events"
    run shortcut "Morning Routine"
end tell
```

```swift
func runShortcutViaAppleScript(named name: String) -> Bool {
    let script = """
    tell application "Shortcuts Events"
        run shortcut "\(name)"
    end tell
    """

    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
        scriptObject.executeAndReturnError(&error)
        return error == nil
    }
    return false
}
```

### List User Shortcuts

```applescript
tell application "Shortcuts Events"
    get name of every shortcut
end tell
```

---

## EmberHearth Integration Design

### Exposing EmberHearth Capabilities

EmberHearth should expose key functions as App Intents:

| Intent | Description | Siri Phrase |
|--------|-------------|-------------|
| `SendMessageIntent` | Send iMessage | "Text [person] with EmberHearth" |
| `MorningBriefingIntent` | Get daily summary | "Morning briefing from EmberHearth" |
| `QuickNoteIntent` | Save a note | "Save a note with EmberHearth" |
| `SearchIntent` | Search across services | "Search for [query] in EmberHearth" |
| `ReminderIntent` | Create reminder | "Remind me with EmberHearth" |

### Running User Shortcuts via Conversation

**User:** "Run my morning routine shortcut"
**EmberHearth:** "Running 'Morning Routine'..."
[Executes shortcut]
**EmberHearth:** "Done! Your morning routine shortcut has completed."

**User:** "What shortcuts do I have?"
**EmberHearth:** "You have 12 shortcuts:
- Morning Routine
- Evening Wind Down
- Work Mode
- Quick Note to Self
- Share Location
[...]
Would you like me to run any of these?"

### Creating Shortcuts via Conversation

**User:** "Create a shortcut that texts my wife 'On my way home' and starts navigation to home"
**EmberHearth:** "I can help you create that shortcut. Here's what it will do:
1. Send 'On my way home' to [Wife's contact]
2. Open Maps with directions to Home

I'll open Shortcuts to finalize this. The shortcut will be called 'Heading Home'."

[Opens Shortcuts with pre-populated actions]

---

## Permissions Required

| Permission | Purpose |
|------------|---------|
| Shortcuts Events | Run shortcuts programmatically |
| Automation | AppleScript access to Shortcuts |

**Info.plist (for Siri):**
```xml
<key>NSSiriUsageDescription</key>
<string>EmberHearth uses Siri to enable voice commands.</string>
```

---

## Automation Triggers

Shortcuts can trigger EmberHearth actions based on:

| Trigger | Example Use |
|---------|-------------|
| Time of Day | Morning briefing at 7 AM |
| Location | "Welcome home" when arriving |
| App Open | Start tracking when app opens |
| CarPlay Connect | Send ETA when connecting |
| Focus Mode | Adjust behavior for Work/Personal |
| Apple Watch | Workout completion triggers |

### Creating Automations Programmatically

Automations cannot be created programmatically—users must set them up in Shortcuts. EmberHearth can:
1. Guide users through setup
2. Provide the intent for them to add
3. Explain trigger options

---

## Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| Can't create automations | Must guide user | Provide instructions |
| Shortcut output capture | Results not always available | Use intents for EmberHearth actions |
| Background execution | Some intents require foreground | Mark as openAppWhenRun |
| Siri recognition | May not understand all phrases | Provide multiple phrase options |

---

## Implementation Priority

| Feature | Priority | Complexity |
|---------|----------|------------|
| Expose core intents | High | Medium |
| Run user shortcuts | High | Low |
| List user shortcuts | Medium | Low |
| Siri phrase registration | Medium | Low |
| Shortcut creation assistance | Low | High |

---

## Testing Checklist

- [ ] App Intents appear in Shortcuts
- [ ] Siri phrases recognized
- [ ] Run shortcut by name
- [ ] Handle missing shortcut
- [ ] Intent with parameters
- [ ] Intent returning values
- [ ] Background vs foreground execution
- [ ] Spotlight integration

---

## Resources

- [App Intents Documentation](https://developer.apple.com/documentation/appintents)
- [App Shortcuts Documentation](https://developer.apple.com/documentation/appintents/app-shortcuts)
- [WWDC25: Get to know App Intents](https://developer.apple.com/videos/play/wwdc2025/244/)
- [WWDC25: Develop for Shortcuts and Spotlight](https://developer.apple.com/videos/play/wwdc2025/260/)
- [Shortcuts URL Schemes](https://support.apple.com/guide/shortcuts/apd624386f42/ios)

---

## Recommendation

**Feasibility: HIGH**

App Intents is Apple's strategic investment in automation. Benefits:

1. **Future-proof:** Apple is actively developing this
2. **Siri integration:** Voice control for free
3. **Spotlight:** Discoverability
4. **Composability:** Users can build on EmberHearth

This is a key differentiator—EmberHearth becomes a building block in users' automation workflows, not just a standalone assistant.

**Implementation Strategy:**
1. Phase 1: Expose 3-5 core intents (messaging, notes, briefing)
2. Phase 2: Add ability to run user shortcuts
3. Phase 3: Rich parameter support and shortcut creation guidance
