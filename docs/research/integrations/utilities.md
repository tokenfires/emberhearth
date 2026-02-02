# Utilities Integration Research

**Status:** Complete
**Priority:** Low
**Last Updated:** February 2, 2026

---

## Overview

This document covers Clock (alarms/timers), System Settings, and other utility functions.

---

# Clock (Alarms & Timers)

## User Value

| Capability | User Benefit |
|------------|--------------|
| Set alarms | "Wake me up at 7 AM" |
| Timers | "Set a 10-minute timer" |
| World clock | "What time is it in Tokyo?" |
| Sleep schedule | Manage wake/sleep times |

## Technical Reality

### Native Clock App

**Limited automation support.**

- Basic AppleScript exists but is buggy
- No official API for alarms/timers
- AlarmKit exists but documentation is sparse

### AlarmKit (Limited Info)

Apple provides AlarmKit for "scheduling prominent alarms and countdowns," but documentation is minimal.

### Workarounds

#### 1. Calendar Events as Alarms

```swift
import EventKit

func createAlarmEvent(title: String, at date: Date) throws {
    let eventStore = EKEventStore()
    let event = EKEvent(eventStore: eventStore)
    event.title = title
    event.startDate = date
    event.endDate = date.addingTimeInterval(60)
    event.calendar = eventStore.defaultCalendarForNewEvents

    // Add alert
    let alarm = EKAlarm(absoluteDate: date)
    event.addAlarm(alarm)

    try eventStore.save(event, span: .thisEvent)
}
```

#### 2. Local Notifications

```swift
import UserNotifications

func scheduleNotification(title: String, at date: Date) async throws {
    let center = UNUserNotificationCenter.current()

    let content = UNMutableNotificationContent()
    content.title = title
    content.sound = .default

    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
    try await center.add(request)
}
```

#### 3. Timer via DispatchSource

```swift
func startTimer(seconds: Int, completion: @escaping () -> Void) -> DispatchSourceTimer {
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + .seconds(seconds))
    timer.setEventHandler {
        completion()
        timer.cancel()
    }
    timer.resume()
    return timer
}
```

### World Clock

Easy via TimeZone:

```swift
func timeIn(city: String) -> String? {
    let timezones: [String: String] = [
        "tokyo": "Asia/Tokyo",
        "london": "Europe/London",
        "new york": "America/New_York",
        "paris": "Europe/Paris",
        "sydney": "Australia/Sydney"
    ]

    guard let identifier = timezones[city.lowercased()],
          let timezone = TimeZone(identifier: identifier) else {
        return nil
    }

    let formatter = DateFormatter()
    formatter.timeZone = timezone
    formatter.dateFormat = "h:mm a"

    return formatter.string(from: Date())
}
```

### Recommendation: **MEDIUM** - Use notifications/calendar instead of Clock app

---

# System Settings

## User Value

| Capability | User Benefit |
|------------|--------------|
| OS updates | "Is there a macOS update?" |
| System info | "How much storage do I have?" |
| Network status | "Am I connected to WiFi?" |

## Technical Approach

### System Information

```swift
import Foundation

func getSystemInfo() -> SystemInfo {
    let processInfo = ProcessInfo.processInfo

    return SystemInfo(
        osVersion: processInfo.operatingSystemVersionString,
        hostName: processInfo.hostName,
        processorCount: processInfo.processorCount,
        physicalMemory: processInfo.physicalMemory,
        uptime: processInfo.systemUptime
    )
}
```

### Storage Information

```swift
func getStorageInfo() -> StorageInfo? {
    let fileManager = FileManager.default
    guard let homeURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return nil
    }

    do {
        let values = try homeURL.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])

        return StorageInfo(
            total: values.volumeTotalCapacity ?? 0,
            available: values.volumeAvailableCapacity ?? 0,
            availableImportant: values.volumeAvailableCapacityForImportantUsage ?? 0
        )
    } catch {
        return nil
    }
}
```

### Network Status

```swift
import Network

class NetworkMonitor {
    private let monitor = NWPathMonitor()
    var isConnected: Bool = false
    var connectionType: NWInterface.InterfaceType?

    func start() {
        monitor.pathUpdateHandler = { path in
            self.isConnected = path.status == .satisfied

            if path.usesInterfaceType(.wifi) {
                self.connectionType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                self.connectionType = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                self.connectionType = .wiredEthernet
            }
        }
        monitor.start(queue: .global())
    }
}
```

### Software Updates

Cannot check for updates programmatically in a sandboxed app. Workaround:

```applescript
-- Opens Software Update preference pane
tell application "System Preferences"
    reveal anchor "SoftwareUpdate" of pane id "com.apple.preferences.softwareupdate"
    activate
end tell
```

### Recommendation: **MEDIUM** - System info is accessible, settings control is limited

---

# Summary

| Utility | API Support | Feasibility | Notes |
|---------|-------------|-------------|-------|
| Alarms | Limited | Medium | Use notifications instead |
| Timers | None | Medium | Implement in-app |
| World Clock | TimeZone API | High | Easy to implement |
| System Info | ProcessInfo | High | Good access |
| Storage | FileManager | High | Available |
| Network | Network.framework | High | Good monitoring |
| Software Updates | None | Low | Can only open Settings |

---

## EmberHearth Integration Design

### Alarm/Timer Conversations

**User:** "Wake me up at 7 AM tomorrow"
**EmberHearth:** "I'll set a reminder for 7:00 AM tomorrow. Note: For a loud alarm, you may want to use the Clock app directly. I'll also send you an iMessage at 7 AM."

**User:** "Set a timer for 15 minutes"
**EmberHearth:** "Timer set for 15 minutes. I'll message you when it's done."
[15 minutes later]
**EmberHearth:** "Timer's up! 15 minutes have passed."

**User:** "What time is it in London?"
**EmberHearth:** "It's currently 8:45 PM in London (GMT)."

### System Info Conversations

**User:** "How much storage do I have left?"
**EmberHearth:** "Your Mac has:
- Total: 500 GB
- Used: 342 GB (68%)
- Available: 158 GB

Your largest folders:
1. Applications: 45 GB
2. Library: 38 GB
3. Documents: 22 GB"

---

## Implementation Priority

| Feature | Priority | Complexity |
|---------|----------|------------|
| World clock | High | Low |
| Timer (in-app) | Medium | Low |
| Storage info | Medium | Low |
| Network status | Medium | Low |
| Alarm (via notification) | Low | Medium |

---

## Resources

- [TimeZone Documentation](https://developer.apple.com/documentation/foundation/timezone)
- [ProcessInfo Documentation](https://developer.apple.com/documentation/foundation/processinfo)
- [Network Framework](https://developer.apple.com/documentation/network)
- [UserNotifications](https://developer.apple.com/documentation/usernotifications)

---

## Recommendation

**Feasibility: MEDIUM overall**

Utilities are mixed:
- World clock: Easy and useful
- Timer: Implement in EmberHearth, not via Clock app
- System info: Good access for storage, network
- Alarms: Limited—guide users to Clock app for reliable wake alarms

These are supporting features rather than core value propositions.
