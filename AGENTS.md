# FeedingTimerModels — Agent Guide

This document gives a fast, file-oriented map of the package so an agent can navigate and modify the code safely. It summarizes targets, responsibilities, and how types and services interact.

**Overview**
- **Purpose:** Domain models and statistics for breastfeeding sessions shared across apps.
- **Targets:** `Models` (data types + small utilities) and `Statistics` (pure/stateless services over models).
- **Dependency:** `Statistics` depends on `Models`; `Models` has no dependencies.
- **Style:** Value types (`struct`/`enum`) with `Codable`, `Equatable`, and `Sendable` where appropriate; services are small, pure functions parameterized by a time/calendar environment.

**Package**
- `Package.swift`: Defines two library products: `Models` and `Statistics`. `Statistics` depends on `Models`. One test target exists but is currently a stub.
- `README.md`: High-level blurb focused on reusable, testable models.
- `LICENSE`: Project license.

**Core Concepts**
- **Feed session:** A session is a `FeedingLogEntry` with optional `breastUnits` for segment-level tracking (e.g., left then right). If units exist, their summed durations define the effective duration; otherwise, envelope `end - start` is used when `endTime` is present.
- **Scenarios:** Many stats operate in All / Day / Night modes (`AverageDurationScenario`) and use calendar boundaries for civil days and time-of-day slots.
- **Windows:** Stats query periods are expressed by `TimeWindow` (`.days(n)` or `.hours(n)`), resolved via `WindowingService`.
- **Environment:** `StatsEnvironment` injects `NowProvider` and `Calendar` to make computations predictable and testable.

**Models Target (Sources/Models)**
- `FeedingLogEntry.swift`: Core feed model (id, start/end, cues, primary breast, segment `breastUnits`, timestamps). Computes `effectiveDuration`, `totalDuration`, `elapsedTime`. Provides an `example` instance.
- `BreastUnit.swift`: Segment within a feed (breast, duration, start/end). Enables split-feed accounting.
- `Breast.swift`: Left/right enumeration with decoding/encoding, opposite side, icon and localized labels.
- `FeedingCue.swift`: Enumerates common feeding cues with display names.
- `FeedingEntryType.swift`: Classification for feeds: `snack`, `cluster`, `normal`.
- `FeedingState.swift`: Lightweight UI/domain state: `waiting`, `feeding`, `completed`.
- `FeedingLogEntryStatsData.swift`: Wrapper pairing a `FeedingLogEntry` with its computed `FeedingEntryType`.
- `FeedingLogDay.swift`: Day bucket marker (date-only wrapper).
- `FeedingStats.swift`: Aggregate stats struct (total, avg duration, avg interval, counts).
- `TimeWindow.swift`: Enum for `.days(Int)` and `.hours(Int)` windows.
- `TrendGranularity.swift`: Enum for `.daily`, `.weekly`, `.monthly` trend grain.
- `TimeOfDaySlot.swift`: Night/Morning/Afternoon/Evening slots with localized labels.
- `Extensions/Model+extensions.swift`: Calendar helpers to map dates to time-of-day slots; sorting helpers for `TimeOfDayBucket` arrays.
- `Totals/DailyDurationPoint.swift`: Daily total duration data point.
- `Totals/WeeklyDurationPoint.swift`: Weekly total duration data point.
- `Totals/MonthlyDurationPoint.swift`: Monthly total duration data point.
- `Totals/DailyTotalTrend.swift`: Compares current vs previous per-day average totals with delta and percent.
- `Totals/WindowTrend.swift`: Generic trend (current vs previous average) with delta and percent.
- `AverageDuration/AverageDurationConfig.swift`: Configuration for averaging durations (period, customDays, grouping, outlier policy).
- `AverageDuration/AverageDurationPeriod.swift`: Preset windows (last24h/3d/7d/14d/custom).
- `AverageDuration/AverageDurationGrouping.swift`: Grouping for duration averages: `none`, `breast`, `timeOfDay`.
- `AverageDuration/OutlierPolicy.swift`: Outlier policy: include all or exclude via IQR.
- `AverageDuration/GroupedAverage.swift`: Labeled average with sample count for grouped duration stats.
- `AverageDuration/AverageDurationScenario.swift`: Scenario: `all`, `day`, `night`.
- `AverageDuration/DurationTrend.swift`: Trend for average durations across windows.
- `AverageDuration/AverageDurationBookmark.swift`: Saved presets for duration views.
- `AverageInterval/AverageIntervalGrouping.swift`: Grouping for interval averages: `none`, `breast`, `timeOfDay`.
- `AverageInterval/IntervalGroupedAverage.swift`: Labeled average with count for grouped intervals.
- `AverageInterval/IntervalTrend.swift`: Trend for average start-to-start intervals.
- `FeedsPerDay/FeedsPerDayPoint.swift`: Per-day feed count data point.
- `FeedsPerDay/FeedsPerDayGrouping.swift`: Counting mode: `all` or `breast`.
- `FeedsPerDay/FeedsPerDaySummary.swift`: Aggregate count stats (mean, median, min/max, samples).
- `TimeSpentFeeding/TimeOfDayBucket.swift`: Per-slot totals and sample counts for a given day.
- `TimeSpentFeeding/TodayFeedingSummary.swift`: Today’s totals split by breast with active-session info.
- `TimeSpentFeeding/PacingComparison.swift`: Today cumulative vs historical mean at same time-of-day.
- `Haptics.swift`: UI haptic helpers (main-actor, UIKit feedback generators).
- `DisplayLinkProxy.swift`: ObjC selector-friendly display-link proxy for per-frame ticks.
- `Preferences.swift`: Observable user preferences backed by `UserDefaults` (baby info, broadcast flag, device name) with reset support.
- `AdaptiveInfoGridItem.swift`: Simple view-model for icon/title/value grid entries.
- `FeedInProgressDisplayMode.swift`: UI mode for in-progress feed display (`total` vs `split`).
- `ExpectedWeightExplanationRoute.swift`: Navigation token for an info sheet/route.
- `AppColorScheme.swift`: System/Light/Dark theme mapping to SwiftUI `ColorScheme`.
- `StatCardPersistenceKey.swift`: Centralized `UserDefaults` keys for stat card UI state.
- `OldFeedingLogEntry.swift`: Legacy feed model + conversion helpers to `FeedingLogEntry` and arrays.

**Statistics Target (Sources/Statistics)**
- `Models/StatsEnvironment.swift`: Shared environment for stats computations (clock + calendar). Promotes determinism/testing.
- `Models/SystemNowProvider.swift`: Default `NowProvider` returning `Date()`.
- `Protocols/NowProvider.swift`: Protocol for pluggable time source.
- `Protocols/TimeOfDayBucketStatsServiceProtocol.swift`: Contract for services computing duration averages per time-of-day.
- `Protocols/TimeOfDayBucketIntervalStatsServiceProtocol.swift`: Contract for services computing interval averages per time-of-day.
- `Services/FeedingStatsService.swift`: Facade exposing high-level APIs used by the app; delegates to specialized services for actual computations. Also defines `NextFeedEstimate` type.
- `Services/WindowingService.swift`: Resolves `TimeWindow` to concrete date ranges; provides day/week/month and rolling window helpers with civil boundaries.
- `Services/ScenarioFilterService.swift`: Filters feeds by `AverageDurationScenario` (all/day/night) using hour-of-day.
- `Services/OutlierService.swift`: IQR-based outlier exclusion; age-aware winsorization for intervals; utilities for age-dependent bounds.
- `Services/SummaryStatsService.swift`: Computes overall totals/averages across all completed feeds, including winsorized average intervals and outlier counts.
- `Services/DurationStatsService.swift`: Duration-centric analytics: overall/grouped averages, trends, stability (coefficient of variation), longest-feed milestone, and gentle tips.
- `Services/IntervalStatsService.swift`: Interval-centric analytics: start-to-start intervals, grouped averages, and current-vs-previous-window trends. Scenario-aware filtering and same-day/night pairing rules.
- `Services/PerDayCountsService.swift`: Builds contiguous per-day feed-count series (including zero days), summary stats, and trends across windows; supports breast-split.
- `Services/TotalsService.swift`: Daily/weekly/monthly total duration series; daily total trends; generic window trend helper.
- `Services/TodayStatsService.swift`: Today-only helpers: total time split by breast (segment-aware), time-of-day breakdown, and pacing vs previous N days at the same day-time.
- `Services/ProjectionService.swift`: Next-feed time estimate based on latest completed feed and average interval (legacy and age-aware variants).
- `Services/FeedingStyleService.swift`: Classifies each feed as `snack`/`cluster`/`normal` using durations and adjacent gaps with trimmed percentiles and cluster detection.

**Behavioral Notes**
- **Segment awareness:** Where `breastUnits` exist, services split and clip by unit start/end, otherwise fall back to envelope times.
- **Active sessions:** Today-based summaries include completed segments from the active feed; running-segment time may fall back to envelope when start isn’t known from services.
- **Outliers:** IQR filtering is used in many averages; winsorization caps long intervals using age-aware bounds to avoid unrealistic predictions.
- **Scenario semantics:** Night is 0–6 and Evening starts at 18; Day is 6–21 by hour checks. Some services apply stricter “both in night and same civil day” pairing for intervals.
- **Windows:** `.days(n)` operates on civil days with `Calendar.startOfDay`; `.hours(n)` is a rolling window ending at `now`.

**Typical Flows**
- **Overall stats:** `FeedingStatsService().computeStats(from: feeds, ageDays: …)` → totals, average duration, winsorized average interval.
- **Next feed estimate:** `FeedingStatsService().estimateNextFeed(from: feeds, ageDays: …, now: …)` → adds average interval to last completed feed’s start.
- **Average durations:** `FeedingStatsService().averageDurations(feeds:…, daysBack:…, grouping:…, outlierPolicy:…, scenario:… )`.
- **Average intervals:** `FeedingStatsService().averageIntervals(feeds:…, daysBack:…, scenario:…, grouping:…, excludeOutliers:…)`.
- **Per-day counts:** `PerDayCountsService.feedsPerDaySeries` then `feedsPerDaySummary`/`feedsPerDayTrend`.
- **Totals over time:** `TotalsService.dailyTotalDurationSeries/week/month` and `dailyTotalTrend`.
- **Today views:** `TodayStatsService.timeSpentFeedingToday`, `todayTimeOfDayBreakdown`, `pacingComparisonLastDays`.

**Edge Cases & Guarantees**
- **Empty inputs:** Services return zeros/empties gracefully.
- **Non-positive intervals:** Skipped when computing start-to-start gaps.
- **Low samples (<4):** Interval averages fall back to plain mean without winsorization.
- **Calendar alignment:** Day/Week/Month series align to civil boundaries; week uses Monday as first weekday.

**Testing & Usage**
- The test target is currently a stub. Most services are pure and can be tested by injecting custom `Calendar`/`NowProvider` via `StatsEnvironment`.
- When adding new stats, prefer small services that accept (`feeds`, `window`, `scenario`, `now`, `calendar`) rather than expanding the facade directly.

**Quick File Index**
- Models: core types and DTOs under `Sources/Models/**`.
- Statistics: pure services and environment under `Sources/Statistics/**`.
- Tests: placeholder at `Tests/FeedingTimerModelsTests/FeedingTimerModelsTests.swift`.

