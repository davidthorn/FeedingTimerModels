//
//  FeedingStatsService.swift
//  FeedingTimer
//
//  Created by David Thorn on 06.08.25.
//

import Foundation
import Models

/// Facade for high-level feeding statistics.
/// Delegates core computations to extracted sub-services to keep a thin surface
/// and consistent semantics across the app, while preserving public signatures.
public struct FeedingStatsService {
    
    public init() {}
    
    public struct NextFeedEstimate {
        public let nextFeedTime: Date
        public let interval: TimeInterval
        public init(nextFeedTime: Date, interval: TimeInterval) {
            self.nextFeedTime = nextFeedTime
            self.interval = interval
        }
    }
    
    // MARK: - Public API (kept)
    public func estimateNextFeed(from feeds: [FeedingLogEntry], now: Date = Date()) -> NextFeedEstimate? {
        ProjectionService().estimateNextFeed(from: feeds, now: now)
    }
    
    public func computeStats(from feeds: [FeedingLogEntry]) -> FeedingStats {
        return computeStats(from: feeds, ageDays: nil) // preserves legacy behavior
    }
    
    // MARK: - New, non-breaking overloads
    public func estimateNextFeed(from feeds: [FeedingLogEntry], ageDays: Int?, now: Date = Date()) -> NextFeedEstimate? {
        ProjectionService().estimateNextFeed(from: feeds, ageDays: ageDays, now: now)
    }
    
    public func computeStats(from feeds: [FeedingLogEntry], ageDays: Int?) -> FeedingStats {
        // Delegate to SummaryStatsService to avoid duplication.
        SummaryStatsService().computeStats(from: feeds, ageDays: ageDays)
    }
    
    // MARK: - Private helpers
}

// MARK: - Extensions (OPEN for extension, CLOSED for modification)

public extension FeedingStatsService {
    
    func averageDurationTimeOfDayBuckets(
        feeds: [FeedingLogEntry],
        daysBack: Int,
        outlierPolicy: OutlierPolicy,
        scenario: AverageDurationScenario,
        rollingHoursBack: Int?,
        now: Date,
        calendar: Calendar
    ) -> (overall: TimeInterval, groups: [TimeOfDayBucket]) {
        let window = resolvedWindow(daysBack: daysBack, rollingHoursBack: rollingHoursBack)
        return DurationStatsService().averageDurationTimeOfDayBuckets(
            feeds: feeds,
            window: window,
            outlierPolicy: outlierPolicy,
            scenario: scenario,
            now: now,
            calendar: calendar
        )
    }
    
    // Average Duration (overall + grouped)
    func averageDurations(
        feeds: [FeedingLogEntry],
        daysBack: Int,
        grouping: AverageDurationGrouping,
        outlierPolicy: OutlierPolicy,
        scenario: AverageDurationScenario = .all,
        rollingHoursBack: Int? = nil,
        recencyHalfLifeHours: Double? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (overall: TimeInterval, groups: [GroupedAverage]) {
        let window = resolvedWindow(daysBack: daysBack, rollingHoursBack: rollingHoursBack)
        return DurationStatsService().averageDurations(
            feeds: feeds,
            window: window,
            grouping: grouping,
            outlierPolicy: outlierPolicy,
            scenario: scenario,
            recencyHalfLifeHours: recencyHalfLifeHours,
            now: now,
            calendar: calendar
        )
    }
    
    // Scenario filter (All / Day / Night)
    func filterByScenario(
        _ feeds: [FeedingLogEntry],
        scenario: AverageDurationScenario,
        calendar: Calendar = .current
    ) -> [FeedingLogEntry] {
        ScenarioFilterService(env: .init(calendar: calendar))
            .filterByScenario(feeds, scenario: scenario, calendar: calendar)
    }
    
    // Trends (compares current window vs immediately previous window)
    func durationTrend(
        feeds: [FeedingLogEntry],
        daysBack: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DurationTrend {
        return DurationStatsService().durationTrend(
            feeds: feeds,
            window: .days(daysBack),
            now: now,
            calendar: calendar
        )
    }
    
    // Stability (coefficient of variation of durations in window)
    func durationStability(
        feeds: [FeedingLogEntry],
        daysBack: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Double {
        return DurationStatsService().durationStability(
            feeds: feeds,
            window: .days(daysBack),
            now: now,
            calendar: calendar
        )
    }
    
    // Milestone (longest completed feed within window)
    func longestFeed(
        feeds: [FeedingLogEntry],
        daysBack: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DurationMilestone? {
        return DurationStatsService().longestFeed(
            feeds: feeds,
            window: .days(daysBack),
            now: now,
            calendar: calendar
        )
    }
    
    // Tips (contextual, offline, gentle)
    func averageDurationTips(
        trend: DurationTrend,
        stabilityCV: Double,
        scenario: AverageDurationScenario,
        sampleCount: Int
    ) -> [AverageDurationTip] {
        DurationStatsService().averageDurationTips(
            trend: trend,
            stabilityCV: stabilityCV,
            scenario: scenario,
            sampleCount: sampleCount
        )
    }
    
    // MARK: - Private helpers (kept inside the extension)
}

// MARK: - Extensions

public extension FeedingStatsService {
    
    /// Total time spent feeding today, split by breast, including the ongoing feed (if any) up to `now`.
    /// Counts only the portion of each session that overlaps today.
    func timeSpentFeedingToday(
        feeds: [FeedingLogEntry],
        activeFeed: FeedingLogEntry?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TodayFeedingSummary {
        TodayStatsService().timeSpentFeedingToday(
            feeds: feeds,
            activeFeed: activeFeed,
            now: now,
            calendar: calendar
        )
    }
    
    /// Today’s breakdown by time of day (Night 0–6, Morning 6–12, Afternoon 12–18, Evening 18–24).
    /// Sessions spanning multiple slots are split proportionally across those slots.
    func todayTimeOfDayBreakdown(
        feeds: [FeedingLogEntry],
        activeFeed: FeedingLogEntry?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [TimeOfDayBucket] {
        TodayStatsService().todayTimeOfDayBreakdown(
            feeds: feeds,
            activeFeed: activeFeed,
            now: now,
            calendar: calendar
        )
    }
    
    /// Compares today's cumulative time (up to `now`) against the average of the past `days` days
    /// measured up to the same time-of-day mark.
    func pacingComparisonLastDays(
        feeds: [FeedingLogEntry],
        activeFeed: FeedingLogEntry?,
        days: Int = 7,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PacingComparison {
        TodayStatsService().pacingComparisonLastDays(
            feeds: feeds,
            activeFeed: activeFeed,
            days: days,
            now: now,
            calendar: calendar
        )
    }
}

// MARK: - Private helpers for clipping/overlap

private extension FeedingStatsService {
    func resolvedWindow(daysBack: Int, rollingHoursBack: Int?) -> TimeWindow {
        if let h = rollingHoursBack { return .hours(h) }
        return .days(daysBack)
    }
}

public extension FeedingStatsService {
    
    /// Core: average start-to-start intervals within last `daysBack` days.
    /// Applies optional grouping and simple outlier policy (IQR).
    func averageIntervals(
        feeds: [FeedingLogEntry],
        daysBack: Int,
        scenario: AverageDurationScenario = .all,
        grouping: AverageIntervalGrouping = .none,
        excludeOutliers: Bool = true,
        rollingHoursBack: Int? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (overall: TimeInterval, groups: [IntervalGroupedAverage]) {
        let window = resolvedWindow(daysBack: daysBack, rollingHoursBack: rollingHoursBack)
        return IntervalStatsService().averageIntervals(
            feeds: feeds,
            window: window,
            scenario: scenario,
            grouping: grouping,
            excludeOutliers: excludeOutliers,
            now: now,
            calendar: calendar
        )
    }
    
    /// Core: average start-to-start intervals within last `daysBack` days.
    /// Applies optional grouping and simple outlier policy (IQR).
    func averageIntervalsTimeOfDayBuckets(
        feeds: [FeedingLogEntry],
        daysBack: Int,
        scenario: AverageDurationScenario = .all,
        excludeOutliers: Bool = true,
        rollingHoursBack: Int? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (overall: TimeInterval, groups: [TimeOfDayBucket]) {
        let window = resolvedWindow(daysBack: daysBack, rollingHoursBack: rollingHoursBack)
        return IntervalStatsService().averageIntervalsTimeOfBuckets(
            feeds: feeds,
            window: window,
            scenario: scenario,
            excludeOutliers: excludeOutliers,
            now: now,
            calendar: calendar
        )
    }
    
    /// Trend of average intervals: compares current window vs immediately previous window.
    func averageIntervalTrend(
        feeds: [FeedingLogEntry],
        daysBack: Int,
        scenario: AverageDurationScenario = .all,
        excludeOutliers: Bool = true,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> IntervalTrend {
        let window: TimeWindow = .days(daysBack)
        return IntervalStatsService().averageIntervalTrend(
            feeds: feeds,
            window: window,
            scenario: scenario,
            excludeOutliers: excludeOutliers,
            now: now,
            calendar: calendar
        )
    }
}

// MARK: Private helpers (scoped to this extension)

private extension FeedingStatsService {
    func startToStartIntervals(from ordered: [FeedingLogEntry]) -> [TimeInterval] {
        IntervalStatsService().startToStartIntervals(from: ordered)
    }
    
    func dayStartEndExclusive(now: Date, daysBack: Int, calendar: Calendar) -> (Date, Date) {
        WindowingService(env: .init(calendar: calendar)).dayStartEndExclusive(now: now, daysBack: daysBack)
    }
    
    // Removed duplicated IQR helpers; call OutlierService directly where needed in services.
}

// MARK: Support types moved to Models/FeedsPerDay

public extension FeedingStatsService {

    /// Returns daily feed counts for the last `daysBack` days, inclusive of `now`'s day.
    /// Only completed feeds are counted. Scenario filter (All/Day/Night) reuses your existing one.
    func feedsPerDaySeries(
        feeds: [FeedingLogEntry],
        daysBack: Int,
        scenario: AverageDurationScenario = .all,
        grouping: FeedsPerDayGrouping = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (overall: [FeedsPerDayPoint], left: [FeedsPerDayPoint]?, right: [FeedsPerDayPoint]?) {
        let window: TimeWindow = .days(daysBack)
        return PerDayCountsService().feedsPerDaySeries(
            feeds: feeds,
            window: window,
            scenario: scenario,
            grouping: grouping,
            now: now,
            calendar: calendar
        )
    }

    /// Summary stats (mean/median/min/max) for a daily series.
    func feedsPerDaySummary(points: [FeedsPerDayPoint]) -> FeedsPerDaySummary {
        PerDayCountsService().feedsPerDaySummary(points: points)
    }

    /// Trend compares the current `daysBack` window vs the immediately previous window.
    func feedsPerDayTrend(
        feeds: [FeedingLogEntry],
        daysBack: Int,
        scenario: AverageDurationScenario = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> FeedsPerDayTrend {
        return PerDayCountsService().feedsPerDayTrend(
            feeds: feeds,
            window: .days(daysBack),
            scenario: scenario,
            now: now,
            calendar: calendar
        )
    }
}

// MARK: Support types moved to Models/Totals

public extension FeedingStatsService {
    /// Sum of completed feed durations per calendar day (includes only completed sessions).
    /// Returns a **contiguous** series for `daysBack` days ending today (including zeros).
    func dailyTotalDurationSeries(
        feeds: [FeedingLogEntry],
        daysBack: Int,
        scenario: AverageDurationScenario = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyDurationPoint] {
        return TotalsService().dailyTotalDurationSeries(
            feeds: feeds,
            window: .days(daysBack),
            scenario: scenario,
            now: now,
            calendar: calendar
        )
    }

    /// Compares average daily total in current window vs immediately previous window of the same length.
    func dailyTotalTrend(
        feeds: [FeedingLogEntry],
        daysBack: Int,
        scenario: AverageDurationScenario = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DailyTotalTrend {
        return TotalsService().dailyTotalTrend(
            feeds: feeds,
            window: .days(daysBack),
            scenario: scenario,
            now: now,
            calendar: calendar
        )
    }
}

// types relocated

public extension FeedingStatsService {

    /// Sum of completed feed durations per calendar week.
    /// Returns `weeksBack` contiguous weeks, newest last.
    func weeklyTotalDurationSeries(
        feeds: [FeedingLogEntry],
        weeksBack: Int,
        scenario: AverageDurationScenario = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [WeeklyDurationPoint] {
        TotalsService().weeklyTotalDurationSeries(
            feeds: feeds,
            weeksBack: weeksBack,
            scenario: scenario,
            now: now,
            calendar: calendar
        )
    }

    /// Sum of completed feed durations per calendar month.
    /// Returns `monthsBack` contiguous months, newest last.
    func monthlyTotalDurationSeries(
        feeds: [FeedingLogEntry],
        monthsBack: Int,
        scenario: AverageDurationScenario = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [MonthlyDurationPoint] {
        TotalsService().monthlyTotalDurationSeries(
            feeds: feeds,
            monthsBack: monthsBack,
            scenario: scenario,
            now: now,
            calendar: calendar
        )
    }

    /// Generic window trend: compares average of `current` vs average of the immediately preceding window of same length.
    func windowTrend(current: [TimeInterval], previous: [TimeInterval]) -> WindowTrend {
        TotalsService().windowTrend(current: current, previous: previous)
    }
}
