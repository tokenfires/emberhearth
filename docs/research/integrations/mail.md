# Mail Integration Research

**Status:** Complete
**Priority:** High
**Last Updated:** February 2, 2026

---

## Overview

Mail.app is Apple's native email client, integral to many users' daily workflows. Integration would enable EmberHearth to help users manage their inbox through natural language via iMessage.

## User Value

| Capability | User Benefit |
|------------|--------------|
| Read & summarize emails | Quick briefings without opening Mail |
| Organize into folders | AI-powered email triage |
| Draft & send emails | Compose via conversational interface |
| Search emails | Natural language email search |
| Daily digests | "What's important today?" summaries |

---

## Technical Approaches

### 1. AppleScript (Primary Approach)

Mail.app has a comprehensive AppleScript dictionary, making it the most viable automation method.

**Capabilities:**
- Read messages (subject, sender, body, date, attachments)
- Create and send messages
- Move messages between mailboxes
- Create/delete mailboxes
- Search messages
- Mark as read/unread/flagged
- Apply rules

**Example - Read Recent Messages:**
```applescript
tell application "Mail"
    set recentMessages to (messages 1 thru 10 of inbox)
    repeat with msg in recentMessages
        set msgSubject to subject of msg
        set msgSender to sender of msg
        set msgDate to date received of msg
        -- Process message
    end repeat
end tell
```

**Example - Send Email:**
```applescript
tell application "Mail"
    set newMessage to make new outgoing message with properties {
        subject: "Hello from EmberHearth",
        content: "This is the message body.",
        visible: true
    }
    tell newMessage
        make new to recipient at end of to recipients with properties {
            address: "recipient@example.com"
        }
    end tell
    send newMessage
end tell
```

**Example - Search Messages:**
```applescript
tell application "Mail"
    set foundMessages to (every message of inbox whose subject contains "invoice")
end tell
```

### 2. Mail Rules with AppleScript

Mail.app can trigger AppleScripts when messages match certain rules.

**Setup:**
1. Mail → Settings → Rules
2. Create rule with conditions
3. Action: "Run AppleScript"
4. Script location: `~/Library/Application Scripts/com.apple.mail/`

**Rule Script Handler:**
```applescript
using terms from application "Mail"
    on perform mail action with messages theMessages for rule theRule
        repeat with eachMessage in theMessages
            -- Process incoming message
            set messageContent to content of eachMessage
            -- Trigger EmberHearth notification
        end repeat
    end perform mail action with messages
end using terms from
```

### 3. Swift with AppleScript Bridge

Execute AppleScript from Swift for programmatic control:

```swift
import Foundation

func getRecentEmails(count: Int) -> [EmailSummary]? {
    let script = """
    tell application "Mail"
        set output to ""
        set recentMessages to (messages 1 thru \(count) of inbox)
        repeat with msg in recentMessages
            set output to output & subject of msg & "|||"
            set output to output & sender of msg & "|||"
            set output to output & date received of msg & "\\n"
        end repeat
        return output
    end tell
    """

    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
        let output = scriptObject.executeAndReturnError(&error)
        // Parse output into EmailSummary objects
    }
    return nil
}
```

### 4. NSSharingService (Limited)

For sending only (not reading):

```swift
import AppKit

func shareViaEmail(subject: String, body: String, recipients: [String]) {
    let service = NSSharingService(named: .composeEmail)
    service?.recipients = recipients
    service?.subject = subject
    service?.perform(withItems: [body])
}
```

**Limitation:** Opens Mail.app compose window; cannot send silently.

---

## Permissions Required

| Permission | Purpose | How to Grant |
|------------|---------|--------------|
| Automation | Control Mail.app | Prompted on first AppleScript execution |
| (None for reading) | AppleScript access doesn't require FDA | N/A |

**Note:** Unlike Messages, Mail.app automation via AppleScript does not require Full Disk Access.

---

## Security Considerations

### Input Sanitization
```swift
func sanitizeForAppleScript(_ input: String) -> String {
    return input
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
}
```

### Permission-Based Sending

EmberHearth should implement permission tiers for sending:

| Tier | Behavior |
|------|----------|
| **Whitelist** | Auto-send to pre-approved contacts/domains |
| **Confirm** | Show draft and require user confirmation |
| **Block** | Never send to unknown recipients |

**User Configuration Example:**
```
"Always allow sending to: @work.com, family@gmail.com"
"Always confirm before sending to: new recipients"
"Never send to: @spam-domain.com"
```

### Content Logging

- **Never** log full email bodies
- Log only metadata for debugging (subject line, sender domain)
- Implement retention limits

---

## Work/Personal Context Routing

**Related:** `docs/research/work-personal-contexts.md`

Email access is highly context-sensitive. Users map their email accounts to personal or work contexts during onboarding.

### Account-to-Context Mapping

```swift
// Configured during onboarding
struct EmailContextMapping {
    var personalAccounts: [String]  // "john@gmail.com", "john@icloud.com"
    var workAccounts: [String]      // "john.doe@company.com"

    func accounts(for context: Context) -> [String] {
        return context == .personal ? personalAccounts : workAccounts
    }
}
```

### Context-Scoped Email Access

```applescript
-- Query only accounts for current context
tell application "Mail"
    set targetAccount to account "john@gmail.com"  -- Personal context
    set recentMessages to (messages 1 thru 10 of inbox of targetAccount)
    -- Process messages
end tell
```

### Critical: Email Content Never Crosses Contexts

- Work emails NEVER appear in personal context summaries
- Personal emails NEVER appear in work context summaries
- No "you have 5 work emails" notifications in personal context

### Sending from Correct Account

When composing email, always send from the current context's account:

```applescript
tell application "Mail"
    set newMessage to make new outgoing message with properties {
        subject: "Meeting Follow-up",
        content: messageBody,
        sender: "john.doe@company.com"  -- Work context account
    }
    -- ...
end tell
```

### LLM Routing Implications

Work email content may have stricter requirements:
- **Local-only processing** for corporate policy compliance
- **Audit logging** of email access and summaries
- **No external API** if work policy requires it

```swift
func processEmail(_ email: Email, context: Context) {
    if context == .work && workPolicy.requireLocalLLM {
        // Route to local MLX model, never cloud
        processWithLocalLLM(email)
    } else {
        // Use configured LLM (may be cloud)
        processWithConfiguredLLM(email, context: context)
    }
}
```

---

## Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| Exchange server drafts | Scheduled sending may fail | Use native Mail scheduling |
| Attachments | Large attachments slow to process | Limit attachment handling |
| HTML emails | AppleScript returns plain text | Parse HTML separately if needed |
| Multiple accounts | Must specify account in scripts | Add account parameter |
| Offline mode | Scripts fail without connection | Check connectivity first |

---

## EmberHearth Integration Design

### Conversation Examples

**User:** "Do I have any important emails today?"
**EmberHearth:** "You have 3 flagged emails and 5 unread from your VIP contacts:
- Meeting rescheduled (from: boss@work.com)
- Invoice attached (from: accounting@vendor.com)
- RE: Project update (from: team@work.com)
Would you like me to summarize any of these?"

**User:** "Send a reply to the meeting email saying I'll be there"
**EmberHearth:** "I'll draft a reply to boss@work.com with subject 'RE: Meeting rescheduled':

'Thanks for letting me know. I'll be there.'

Should I send this now?"

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      EmberHearth                             │
├─────────────────────────────────────────────────────────────┤
│  MailService                                                 │
│  ├── MailReader                                             │
│  │   └── AppleScript queries for reading                    │
│  ├── MailSender                                             │
│  │   ├── Permission checker                                 │
│  │   ├── Draft generator                                    │
│  │   └── AppleScript execution                              │
│  ├── MailOrganizer                                          │
│  │   └── Move/flag/archive operations                       │
│  └── MailSummarizer                                         │
│       └── LLM-based email summarization                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Priority

| Feature | Priority | Complexity |
|---------|----------|------------|
| Read inbox summary | High | Low |
| Search emails | High | Low |
| Flag/archive messages | Medium | Low |
| Send with confirmation | Medium | Medium |
| Auto-organize | Low | High |
| Scheduled digests | Medium | Medium |

---

## Testing Checklist

- [ ] Read messages from multiple accounts
- [ ] Handle empty inbox gracefully
- [ ] Send to single recipient
- [ ] Send to multiple recipients (to, cc, bcc)
- [ ] Move messages between folders
- [ ] Search with various criteria
- [ ] Handle special characters in subjects/bodies
- [ ] Test with Exchange, Gmail, iCloud accounts
- [ ] Verify permission prompts appear correctly

---

## Resources

- [Apple Support: Automate tasks in Mail](https://support.apple.com/guide/mail/automate-mail-tasks-mlhlp1120/mac)
- [Apple Support: Use scripts as rule actions](https://support.apple.com/guide/mail/use-scripts-as-rule-actions-mlhlp1171/mac)
- [macosxautomation.com: Mail scripting](http://www.intergalactic.de/pages/eMail/trickreich/mail-automation.html)
- [Doug's AppleScripts](https://dougscripts.com/)

---

## Recommendation

**Feasibility: HIGH**

Mail.app has excellent AppleScript support, making it one of the most automatable Apple apps. EmberHearth should implement:

1. **Phase 1:** Read-only operations (inbox summary, search, flagging)
2. **Phase 2:** Sending with mandatory confirmation
3. **Phase 3:** Smart organization and scheduled digests

The permission model for sending should be conservative—always confirm with user before sending to prevent accidental emails.
