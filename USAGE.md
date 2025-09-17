# Quick Usage: Average Duration

This guide shows how to compute average feed durations for common windows: last 24 hours, 3 days, 7 days, and 14 days.

## Setup

```swift
import Models
import Statistics

let feeds: [FeedingLogEntry] = /* your completed feed entries */
let service = FeedingStatsService()
let now = Date()
let calendar = Calendar.current
```

Notes:
- Only completed feeds are considered for averages.
- If `breastUnits` exist, their durations are summed; otherwise, the envelope `end - start` is used.
- Use `outlierPolicy: .excludeIQR` for more robust means.

## Last 24 hours (rolling)

Use a rolling window ending at `now` by passing `rollingHoursBack: 24`.

```swift
let last24h = service.averageDurations(
    feeds: feeds,
    daysBack: 1,                // ignored when rollingHoursBack is set
    grouping: .none,            // .none, .breast, or .timeOfDay
    outlierPolicy: .excludeIQR, // robust mean
    scenario: .all,             // .all, .day, or .night
    rollingHoursBack: 24,
    now: now,
    calendar: calendar
)

print("Avg duration (last 24h):", last24h.overall)
```

## Last 3, 7, 14 civil days

Use civil-day windows aligned to the calendar’s start-of-day.

```swift
let last3d = service.averageDurations(
    feeds: feeds,
    daysBack: 3,
    grouping: .none,
    outlierPolicy: .excludeIQR,
    scenario: .all,
    now: now,
    calendar: calendar
)

let last7d = service.averageDurations(
    feeds: feeds,
    daysBack: 7,
    grouping: .none,
    outlierPolicy: .excludeIQR,
    scenario: .all,
    now: now,
    calendar: calendar
)

let last14d = service.averageDurations(
    feeds: feeds,
    daysBack: 14,
    grouping: .none,
    outlierPolicy: .excludeIQR,
    scenario: .all,
    now: now,
    calendar: calendar
)

print("Avg duration (3d):", last3d.overall)
print("Avg duration (7d):", last7d.overall)
print("Avg duration (14d):", last14d.overall)
```

## Grouped examples (optional)

Per-breast and time-of-day breakdowns return labeled groups alongside the overall average.

```swift
let byBreast7d = service.averageDurations(
    feeds: feeds,
    daysBack: 7,
    grouping: .breast,
    outlierPolicy: .excludeIQR,
    scenario: .all,
    now: now,
    calendar: calendar
)
for g in byBreast7d.groups { print(g.label, g.average, g.count) }

let bySlot24h = service.averageDurations(
    feeds: feeds,
    daysBack: 1,
    grouping: .timeOfDay,
    outlierPolicy: .excludeIQR,
    scenario: .all,
    rollingHoursBack: 24,
    now: now,
    calendar: calendar
)
for slot in bySlot24h.groups { print(slot.label, slot.average, slot.count) }
```

## Helper: map from AverageDurationPeriod

If you store `AverageDurationPeriod`, you can route it to the correct call:

```swift
func averageDuration(
    for period: AverageDurationPeriod,
    feeds: [FeedingLogEntry],
    grouping: AverageDurationGrouping = .none,
    scenario: AverageDurationScenario = .all,
    now: Date = .now,
    calendar: Calendar = .current
) -> (overall: TimeInterval, groups: [GroupedAverage]) {
    let svc = FeedingStatsService()
    switch period {
    case .last24h:
        return svc.averageDurations(
            feeds: feeds,
            daysBack: 1,
            grouping: grouping,
            outlierPolicy: .excludeIQR,
            scenario: scenario,
            rollingHoursBack: 24,
            now: now,
            calendar: calendar
        )
    case .last3d:
        return svc.averageDurations(
            feeds: feeds,
            daysBack: 3,
            grouping: grouping,
            outlierPolicy: .excludeIQR,
            scenario: scenario,
            now: now,
            calendar: calendar
        )
    case .last7d:
        return svc.averageDurations(
            feeds: feeds,
            daysBack: 7,
            grouping: grouping,
            outlierPolicy: .excludeIQR,
            scenario: scenario,
            now: now,
            calendar: calendar
        )
    case .last14d:
        return svc.averageDurations(
            feeds: feeds,
            daysBack: 14,
            grouping: grouping,
            outlierPolicy: .excludeIQR,
            scenario: scenario,
            now: now,
            calendar: calendar
        )
    case .custom:
        fatalError("Use explicit daysBack for custom period.")
    }
}
```

