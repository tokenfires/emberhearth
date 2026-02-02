# Health & Fitness Integration Research

**Status:** Complete
**Priority:** Medium
**Last Updated:** February 2, 2026

---

## Overview

Health and Fitness data on Apple devices is managed through HealthKit. This integration could provide wellness insights, medication reminders, and activity tracking via iMessage.

## User Value

| Capability | User Benefit |
|------------|--------------|
| Health summaries | "How did I sleep last night?" |
| Activity tracking | "Did I hit my move goal?" |
| Medication reminders | "Time to take your medication" |
| Trend analysis | "How's my heart rate this week?" |
| Goal support | "Am I on track for my fitness goals?" |

---

## Critical Limitation: No macOS HealthKit

**HealthKit is NOT available on macOS.**

HealthKit runs on:
- iOS
- iPadOS
- watchOS
- visionOS

Health data syncs between devices via iCloud, but **cannot be accessed directly from a Mac app.**

---

## Architectural Options

### Option 1: iOS/iPadOS Companion App

Create a companion iOS app that:
1. Reads HealthKit data
2. Syncs relevant summaries to iCloud/CloudKit
3. EmberHearth macOS app reads from CloudKit

```
┌──────────────────────┐     iCloud      ┌────────────────────────┐
│  EmberHearth iOS     │ ──────────────▶ │  EmberHearth macOS     │
│  (HealthKit access)  │    CloudKit     │  (Reads synced data)   │
└──────────────────────┘                 └────────────────────────┘
```

### Option 2: iOS Shortcut Bridge

User creates iOS Shortcut that:
1. Reads HealthKit data
2. Sends summary to EmberHearth via iMessage

This is user-driven, not automatic.

### Option 3: Apple Watch Complication

Watch app reads health data and syncs to Mac.

---

## HealthKit API (iOS Reference)

For the companion app approach, here's how HealthKit works:

### Authorization

```swift
import HealthKit

class HealthService {
    private let healthStore = HKHealthStore()

    func requestAuthorization() async throws -> Bool {
        // Types to read
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.bodyMass)
        ]

        // Types to write (if needed)
        let typesToWrite: Set<HKSampleType> = []

        try await healthStore.requestAuthorization(
            toShare: typesToWrite,
            read: typesToRead
        )

        return true
    }
}
```

### Reading Data

```swift
func getStepsToday() async throws -> Double {
    let stepsType = HKQuantityType(.stepCount)
    let startOfDay = Calendar.current.startOfDay(for: Date())
    let predicate = HKQuery.predicateForSamples(
        withStart: startOfDay,
        end: Date(),
        options: .strictStartDate
    )

    let statistics = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKStatistics, Error>) in
        let query = HKStatisticsQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, statistics, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else if let statistics = statistics {
                continuation.resume(returning: statistics)
            }
        }
        healthStore.execute(query)
    }

    return statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
}

func getHeartRateToday() async throws -> [HKQuantitySample] {
    let heartRateType = HKQuantityType(.heartRate)
    let startOfDay = Calendar.current.startOfDay(for: Date())
    let predicate = HKQuery.predicateForSamples(
        withStart: startOfDay,
        end: Date()
    )

    return try await withCheckedThrowingContinuation { continuation in
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
        }
        healthStore.execute(query)
    }
}

func getSleepData(for date: Date) async throws -> [HKCategorySample] {
    let sleepType = HKCategoryType(.sleepAnalysis)
    let startOfDay = Calendar.current.startOfDay(for: date)
    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

    let predicate = HKQuery.predicateForSamples(
        withStart: startOfDay,
        end: endOfDay
    )

    return try await withCheckedThrowingContinuation { continuation in
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }
        }
        healthStore.execute(query)
    }
}
```

### New Medications API (WWDC25)

```swift
// iOS 26+ / macOS 26 (if supported)
import HealthKit

func getMedications() async throws -> [HKUserAnnotatedMedication] {
    let medicationType = HKUserAnnotatedMedicationType.self

    // Request per-object authorization
    // User selects which medications to share

    return try await healthStore.medications()
}
```

---

## Data Types Available

| Category | Types |
|----------|-------|
| **Activity** | Steps, distance, flights climbed, active energy |
| **Heart** | Heart rate, HRV, resting HR, walking HR |
| **Body** | Weight, BMI, body fat %, height |
| **Sleep** | Sleep analysis, time in bed |
| **Nutrition** | Calories, water, caffeine, nutrients |
| **Vitals** | Blood pressure, blood oxygen, respiratory rate |
| **Medications** | Prescriptions, doses, schedules (new) |

---

## EmberHearth Integration Design

### With Companion iOS App

**User:** "How did I sleep last night?"
**EmberHearth:** "Last night's sleep:
- Total: 7h 23m
- Deep sleep: 1h 45m
- REM: 1h 52m
- Time to fall asleep: 12 minutes

This is 15 minutes more than your weekly average."

**User:** "Did I hit my move goal today?"
**EmberHearth:** "You're at 423/500 calories burned. 77 more to go! A 20-minute walk would get you there."

**User:** "Remind me about my medication"
**EmberHearth:** "You have medications scheduled today:
- 8:00 AM: Vitamin D (taken ✓)
- 12:00 PM: Omega-3 (due now)
- 8:00 PM: Melatonin

Want me to remind you for the noon dose?"

### CloudKit Sync Model

```swift
struct HealthSummary: Codable {
    let date: Date
    let steps: Int
    let activeCalories: Double
    let sleepHours: Double
    let restingHeartRate: Int?
    let weight: Double?
}

// iOS app syncs this daily
// macOS app reads for EmberHearth responses
```

---

## Privacy Considerations

Health data is extremely sensitive:

1. **Explicit consent** for each data type
2. **Minimal data** - only sync what's needed
3. **No logging** of health values
4. **Local processing** preferred
5. **Clear data retention** policy

---

## Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| No macOS HealthKit | Cannot read directly | Use companion iOS app |
| Per-type authorization | Complex permission UX | Request progressively |
| Background access limited | No constant monitoring | Use scheduled syncs |
| Medications new | Limited device support | Graceful degradation |

---

## Implementation Priority

| Feature | Priority | Complexity |
|---------|----------|------------|
| iOS companion app | High | High |
| Activity summary | High | Medium |
| Sleep summary | Medium | Medium |
| Medication reminders | Medium | High |
| Trend analysis | Low | Medium |
| Weight tracking | Low | Low |

---

## Resources

- [HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
- [Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [WWDC25: Meet the HealthKit Medications API](https://developer.apple.com/videos/play/wwdc2025/321/)

---

## Recommendation

**Feasibility: LOW-MEDIUM**

The lack of macOS HealthKit is a significant barrier. Options:

1. **Phase 1:** Skip Health integration (v1)
2. **Phase 2:** Build iOS companion app
3. **Phase 3:** Full health insights via CloudKit sync

If building companion app:
- Activity and sleep are highest value
- Medication reminders are compelling but complex
- Heart data requires careful handling

This is a "nice to have" rather than core feature given the architectural complexity.
