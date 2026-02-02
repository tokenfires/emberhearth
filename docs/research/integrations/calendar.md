# Calendar & Reminders Integration Research

**Status:** Complete
**Priority:** High
**Last Updated:** February 2, 2026

---

## Overview

Calendar and Reminders are core productivity apps that sync across all Apple devices via iCloud. Integration via EventKit provides a robust, well-documented API for managing events and tasks.

## User Value

| Capability | User Benefit |
|------------|--------------|
| Morning briefings | "What's on my schedule today?" |
| Create events | "Schedule a meeting with John tomorrow at 2pm" |
| Manage reminders | "Remind me to call mom at 5pm" |
| Travel planning | Build itineraries with calendar integration |
| Conflict detection | Warn about double-bookings |

---

## Technical Approach: EventKit Framework

EventKit is Apple's official framework for Calendar and Reminders access. It's the recommended approach over AppleScript.

### Platform Support

| Platform | EventKit Support |
|----------|------------------|
| macOS | Full support (10.8+) |
| iOS | Full support |
| watchOS | Full support |
| visionOS | Full support |

### Key Classes

| Class | Purpose |
|-------|---------|
| `EKEventStore` | Central access point for calendars/reminders |
| `EKEvent` | Represents a calendar event |
| `EKReminder` | Represents a reminder/task |
| `EKCalendar` | A calendar container |
| `EKAlarm` | Alert/notification for events |
| `EKRecurrenceRule` | Repeating event rules |

---

## Implementation

### Authorization

```swift
import EventKit

class CalendarService {
    private let eventStore = EKEventStore()

    func requestCalendarAccess() async -> Bool {
        do {
            // iOS 17+ / macOS 14+
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }

    func requestRemindersAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToReminders()
        } catch {
            print("Reminders access error: \(error)")
            return false
        }
    }
}
```

### Reading Events

```swift
func getEventsForToday() -> [EKEvent] {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: Date())
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

    let predicate = eventStore.predicateForEvents(
        withStart: startOfDay,
        end: endOfDay,
        calendars: nil  // nil = all calendars
    )

    return eventStore.events(matching: predicate)
}

func getUpcomingEvents(days: Int) -> [EKEvent] {
    let startDate = Date()
    let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate)!

    let predicate = eventStore.predicateForEvents(
        withStart: startDate,
        end: endDate,
        calendars: nil
    )

    return eventStore.events(matching: predicate)
        .sorted { $0.startDate < $1.startDate }
}
```

### Creating Events

```swift
func createEvent(
    title: String,
    startDate: Date,
    endDate: Date,
    location: String? = nil,
    notes: String? = nil,
    calendarIdentifier: String? = nil
) throws -> EKEvent {

    let event = EKEvent(eventStore: eventStore)
    event.title = title
    event.startDate = startDate
    event.endDate = endDate
    event.location = location
    event.notes = notes

    // Use specified calendar or default
    if let identifier = calendarIdentifier,
       let calendar = eventStore.calendar(withIdentifier: identifier) {
        event.calendar = calendar
    } else {
        event.calendar = eventStore.defaultCalendarForNewEvents
    }

    // Add default reminder (15 minutes before)
    let alarm = EKAlarm(relativeOffset: -15 * 60)
    event.addAlarm(alarm)

    try eventStore.save(event, span: .thisEvent)
    return event
}
```

### Creating Reminders

```swift
func createReminder(
    title: String,
    dueDate: Date?,
    priority: Int = 0,
    notes: String? = nil
) throws -> EKReminder {

    let reminder = EKReminder(eventStore: eventStore)
    reminder.title = title
    reminder.notes = notes
    reminder.priority = priority  // 1-9, 0 = no priority
    reminder.calendar = eventStore.defaultCalendarForNewReminders()

    if let dueDate = dueDate {
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )

        // Add alarm at due time
        let alarm = EKAlarm(absoluteDate: dueDate)
        reminder.addAlarm(alarm)
    }

    try eventStore.save(reminder, commit: true)
    return reminder
}
```

### Fetching Reminders

```swift
func getIncompleteReminders() async -> [EKReminder] {
    let predicate = eventStore.predicateForIncompleteReminders(
        withDueDateStarting: nil,
        ending: nil,
        calendars: nil
    )

    return await withCheckedContinuation { continuation in
        eventStore.fetchReminders(matching: predicate) { reminders in
            continuation.resume(returning: reminders ?? [])
        }
    }
}

func completeReminder(_ reminder: EKReminder) throws {
    reminder.isCompleted = true
    reminder.completionDate = Date()
    try eventStore.save(reminder, commit: true)
}
```

### Recurring Events

```swift
func createWeeklyEvent(
    title: String,
    startDate: Date,
    duration: TimeInterval,
    daysOfWeek: [EKWeekday]
) throws -> EKEvent {

    let event = EKEvent(eventStore: eventStore)
    event.title = title
    event.startDate = startDate
    event.endDate = startDate.addingTimeInterval(duration)
    event.calendar = eventStore.defaultCalendarForNewEvents

    // Create weekly recurrence
    let recurrenceRule = EKRecurrenceRule(
        recurrenceWith: .weekly,
        interval: 1,
        daysOfTheWeek: daysOfWeek.map { EKRecurrenceDayOfWeek($0) },
        daysOfTheMonth: nil,
        monthsOfTheYear: nil,
        weeksOfTheYear: nil,
        daysOfTheYear: nil,
        setPositions: nil,
        end: nil  // No end date
    )
    event.addRecurrenceRule(recurrenceRule)

    try eventStore.save(event, span: .futureEvents)
    return event
}
```

---

## Permissions Required

| Permission | Key | Purpose |
|------------|-----|---------|
| Calendar Access | `NSCalendarsUsageDescription` | Read/write calendar events |
| Reminders Access | `NSRemindersUsageDescription` | Read/write reminders |

**Info.plist entries:**
```xml
<key>NSCalendarsUsageDescription</key>
<string>EmberHearth needs calendar access to help manage your schedule.</string>
<key>NSRemindersUsageDescription</key>
<string>EmberHearth needs reminders access to help you track tasks.</string>
```

**Entitlements:**
```xml
<key>com.apple.security.personal-information.calendars</key>
<true/>
```

---

## Natural Language Date Parsing

For conversational scheduling, parse natural language into dates:

```swift
import NaturalLanguage

func parseDate(from text: String) -> Date? {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    let range = NSRange(text.startIndex..., in: text)

    if let match = detector?.firstMatch(in: text, options: [], range: range) {
        return match.date
    }
    return nil
}

// Example usage:
// "tomorrow at 3pm" → Date
// "next Tuesday" → Date
// "in 2 hours" → Date
```

---

## EmberHearth Integration Design

### Conversation Examples

**User:** "What's on my calendar today?"
**EmberHearth:** "You have 3 events today:
- 9:00 AM: Team standup (30 min)
- 11:30 AM: Lunch with Sarah at Café Milano
- 3:00 PM: Dentist appointment

You also have 2 reminders due today:
- Pick up dry cleaning
- Submit expense report"

**User:** "Schedule a call with Mike next Tuesday at 2pm for an hour"
**EmberHearth:** "I'll create this event:
- **Call with Mike**
- Tuesday, Feb 10 at 2:00 PM - 3:00 PM
- Calendar: Work

Should I add this to your calendar?"

**User:** "Remind me to buy groceries when I get home"
**EmberHearth:** "I've created a location-based reminder:
- **Buy groceries**
- Trigger: When arriving at Home

Note: Location reminders require the Reminders app."

### Morning Briefing Feature

```swift
func generateMorningBriefing() async -> String {
    let todayEvents = getEventsForToday()
    let incompleteReminders = await getIncompleteReminders()
    let tomorrowEvents = getEventsForDate(Date().addingTimeInterval(86400))

    var briefing = "Good morning! Here's your day:\n\n"

    if todayEvents.isEmpty {
        briefing += "📅 No meetings scheduled today.\n"
    } else {
        briefing += "📅 Today's schedule:\n"
        for event in todayEvents {
            let time = formatTime(event.startDate)
            briefing += "  • \(time): \(event.title ?? "Untitled")\n"
        }
    }

    if !incompleteReminders.isEmpty {
        briefing += "\n✅ Reminders:\n"
        for reminder in incompleteReminders.prefix(5) {
            briefing += "  • \(reminder.title ?? "Untitled")\n"
        }
    }

    return briefing
}
```

---

## Work/Personal Context Routing

**Related:** `docs/research/work-personal-contexts.md`

Calendar access must be context-aware. Users map their calendars to personal or work contexts during onboarding.

### Calendar-to-Context Mapping

```swift
// Configured during onboarding
struct CalendarContextMapping {
    var personalCalendarIDs: Set<String>  // "Home", "Family", etc.
    var workCalendarIDs: Set<String>      // "Work", "Project X", etc.

    func calendars(for context: Context) -> [EKCalendar] {
        let ids = context == .personal ? personalCalendarIDs : workCalendarIDs
        return eventStore.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
    }
}
```

### Context-Scoped Queries

```swift
// Always pass context - NEVER query all calendars
func getEvents(for context: Context, dateRange: DateInterval) -> [EKEvent] {
    let calendars = calendarMapping.calendars(for: context)
    let predicate = eventStore.predicateForEvents(
        withStart: dateRange.start,
        end: dateRange.end,
        calendars: calendars  // Scoped to context!
    )
    return eventStore.events(matching: predicate)
}
```

### Event Creation

When creating events, default to the current context:

```swift
func createEvent(title: String, start: Date, end: Date, context: Context) {
    let event = EKEvent(eventStore: eventStore)
    event.title = title
    event.startDate = start
    event.endDate = end

    // Use the default calendar for the current context
    event.calendar = defaultCalendar(for: context)

    try eventStore.save(event, span: .thisEvent)
}
```

### Cross-Context Time Blocking

Users may want to block time on their work calendar for personal events without revealing details:

```
User (Personal): "Add my dentist appointment to my work calendar"

EmberHearth: "I'll add a 'Personal Appointment' block to your work
             calendar from 2-3pm. Only the time will be shared,
             not the appointment details. [Confirm]"
```

This creates an event in the work context with generic title, no details from personal context.

---

## Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| Location-based reminders | Cannot create via EventKit | Guide user to Reminders app |
| Shared calendars | May have restricted write access | Check calendar permissions |
| Travel time | Read-only | Use MapKit for estimates |
| Attachments | Limited support | Store references only |

---

## Security Considerations

1. **Sensitive Data:** Calendar events may contain private information
   - Never log event details
   - Don't send calendar data to external services

2. **Modification Confirmation:** Always confirm before:
   - Deleting events
   - Modifying recurring events
   - Creating events on shared calendars

3. **Work vs Personal:** Respect calendar boundaries
   - Ask which calendar for new events
   - Don't mix work/personal without permission

---

## Implementation Priority

| Feature | Priority | Complexity |
|---------|----------|------------|
| Read today's events | High | Low |
| Create single events | High | Low |
| Create reminders | High | Low |
| Morning briefing | High | Medium |
| Recurring events | Medium | Medium |
| Calendar search | Medium | Low |
| Conflict detection | Medium | Medium |
| Travel time integration | Low | High |

---

## Resources

- [EventKit Documentation](https://developer.apple.com/documentation/eventkit)
- [Creating events and reminders](https://developer.apple.com/documentation/eventkit/creating-events-and-reminders)
- [Retrieving events and reminders](https://developer.apple.com/documentation/eventkit/retrieving-events-and-reminders)
- [WWDC: EventKit best practices](https://developer.apple.com/videos/)

---

## Recommendation

**Feasibility: HIGH**

EventKit is a well-documented, stable API that provides comprehensive access to Calendar and Reminders. This is one of the strongest integration points for EmberHearth because:

1. Official Apple API (not AppleScript workaround)
2. Works across all Apple platforms
3. Syncs automatically via iCloud
4. Natural fit for conversational assistant

Implement early in development as a showcase feature.
