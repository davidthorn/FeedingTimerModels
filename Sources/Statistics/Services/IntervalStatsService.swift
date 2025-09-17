//
//  IntervalStatsService.swift
//  FeedingTimer
//
//  Computes start-to-start feeding intervals and trends with correct
//  Night and Time-of-Day semantics (same civil day, same slot pairing).
//

import Foundation
import FeedingTimerModels

public struct IntervalStatsService {
    public let env: StatsEnvironment

    public init(env: StatsEnvironment = .init()) {
        self.env = env
    }

    /// Computes start-to-start gaps for a chronologically ordered list of feeds.
    /// - Important: Expects `ordered` to be sorted by `startTime` ascending.
    /// - Parameter from: Chronologically ordered feeds.
    /// - Returns: Positive, strictly increasing start-to-start intervals. Non-positive gaps are skipped.
    public func startToStartIntervals(from ordered: [FeedingLogEntry]) -> [TimeInterval] {
        guard ordered.count >= 2 else { return [] }
        return (1..<ordered.count).compactMap { i in
            let dt = ordered[i].startTime.timeIntervalSince(ordered[i - 1].startTime)
            return dt > 0 ? dt : nil
        }
    }

    // MARK: - Average Intervals (Grouped)
    /// Average start-to-start intervals over a window, with optional grouping.
    /// - Parameters:
    ///   - feeds: All feed entries; only completed feeds are considered.
    ///   - daysBack: Number of civil days back from `now` when `rollingHoursBack` is nil.
    ///   - scenario: Scenario filter (all/day/night). Affects which feeds and pairs are considered.
    ///   - grouping: `.none`, `.breast`, or `.timeOfDay` for grouped breakdowns.
    ///   - excludeOutliers: Whether to drop IQR outliers when averaging.
    ///   - rollingHoursBack: Optional rolling window (hours). Overrides day window if provided.
    ///   - now: Reference time for windowing and trend anchoring.
    ///   - calendar: Calendar used for day boundaries and time-of-day slots.
    /// - Returns: Tuple containing overall average and grouped averages (if requested).
    public func averageIntervals(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        scenario: AverageDurationScenario = .all,
        grouping: AverageIntervalGrouping = .none,
        excludeOutliers: Bool = true,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (overall: TimeInterval, groups: [IntervalGroupedAverage]) {
        let (_, pairs) = scopedPairs(
            feeds: feeds,
            window: window,
            scenario: scenario,
            now: now,
            calendar: calendar
        )

        guard !pairs.isEmpty else { return (0, []) }

        let overall = averageForPairs(pairs, scenario: scenario, excludeOutliers: excludeOutliers, calendar: calendar)

        switch grouping {
        case .none:
            return (overall, [])

        case .breast:
            let groups = groupByBreast(pairs: pairs, excludeOutliers: excludeOutliers)
            return (overall, groups)

        case .timeOfDay:
            let groups = groupByTimeOfDay(pairs: pairs, excludeOutliers: excludeOutliers, calendar: calendar)
            return (overall, groups)
        }
    }

    // MARK: - Interval Trend
    /// Compares average start-to-start intervals in the current window vs the previous window.
    /// - Parameters:
    ///   - feeds: All feed entries; only completed feeds are considered.
    ///   - daysBack: Size of the comparison window in days. Must be >= 1; otherwise returns zeros.
    ///   - scenario: Scenario filter (all/day/night).
    ///   - excludeOutliers: Whether to drop IQR outliers when averaging.
    ///   - now: Reference time; current window ends at `now`, previous ends one second before current start.
    ///   - calendar: Calendar used for day boundaries and time-of-day slots.
    /// - Returns: IntervalTrend with `currentAvg` and `previousAvg`.
    public func averageIntervalTrend(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        scenario: AverageDurationScenario = .all,
        excludeOutliers: Bool = true,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> IntervalTrend {
        // Validate window size (days >= 1 or hours >= 1)
        switch window {
        case .days(let d) where d < 1: return .init(currentAvg: 0, previousAvg: 0)
        case .hours(let h) where h < 1: return .init(currentAvg: 0, previousAvg: 0)
        default: break
        }

        func averageFor(range: ClosedRange<Date>) -> TimeInterval {
            let scoped = ScenarioFilterService(env: .init(calendar: calendar))
                .filterByScenario(
                    feeds.filter { $0.endTime != nil && range.contains($0.startTime) },
                    scenario: scenario,
                    calendar: calendar
                )
                .sorted { $0.startTime < $1.startTime }

            guard scoped.count >= 2 else { return 0 }
            let pairs: [(prev: FeedingLogEntry, curr: FeedingLogEntry)] =
                (1..<scoped.count).map { (scoped[$0 - 1], scoped[$0]) }

            return averageForPairs(pairs, scenario: scenario, excludeOutliers: excludeOutliers, calendar: calendar)
        }

        let winSvc = WindowingService(env: .init(calendar: calendar))
        switch window {
        case .days(let d):
            let startCurrent = winSvc.dayStartEndExclusive(now: now, daysBack: d).start
            let startPrev = calendar.date(byAdding: .day, value: -d, to: startCurrent)!
            let endPrev   = calendar.date(byAdding: .second, value: -1, to: startCurrent)!
            return .init(currentAvg: averageFor(range: startCurrent...now), previousAvg: averageFor(range: startPrev...endPrev))
        case .hours(let h):
            let curr = winSvc.rollingStartEnd(now: now, hoursBack: h)
            let prevEndExclusive = curr.start
            let prevStart = prevEndExclusive.addingTimeInterval(-TimeInterval(max(0, h)) * 3600)
            let prevEnd = calendar.date(byAdding: .second, value: -1, to: prevEndExclusive) ?? prevEndExclusive
            return .init(currentAvg: averageFor(range: curr.start...now), previousAvg: averageFor(range: prevStart...prevEnd))
        }
    }

    // MARK: - Private helpers

    private typealias Pair = (prev: FeedingLogEntry, curr: FeedingLogEntry)

    // Common helpers to simplify calculations
    /// Applies IQR outlier exclusion if requested.
    /// - Parameters:
    ///   - values: Sample values.
    ///   - excludeOutliers: Whether to apply IQR outlier removal.
    /// - Returns: Possibly filtered values.
    private func cleaned(_ values: [TimeInterval], excludeOutliers: Bool) -> [TimeInterval] {
        excludeOutliers ? OutlierService().excludeIQR(values) : values
    }

    /// Mean of the provided values, or 0 for empty sets.
    private func mean(_ values: [TimeInterval]) -> TimeInterval {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Positive interval between a pair's start times.
    /// - Parameter p: Consecutive feed pair.
    /// - Returns: `curr.start - prev.start` if positive; otherwise nil.
    private func interval(_ p: Pair) -> TimeInterval? {
        let dt = p.curr.startTime.timeIntervalSince(p.prev.startTime)
        return dt > 0 ? dt : nil
    }

    /// Returns the scoped feeds and their consecutive start-to-start pairs for the given window and scenario.
    /// - Parameters:
    ///   - feeds: All feed entries; only completed feeds are considered.
    ///   - daysBack: Days window size when `rollingHoursBack` is nil.
    ///   - scenario: Scenario filter (all/day/night).
    ///   - rollingHoursBack: Optional rolling window in hours; overrides `daysBack` if present.
    ///   - now: Reference time for windowing.
    ///   - calendar: Calendar for windowing and slot detection.
    /// - Returns: Tuple of (scopedFeeds, consecutive start-to-start pairs).
    private func scopedPairs(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        scenario: AverageDurationScenario,
        now: Date,
        calendar: Calendar
    ) -> ([FeedingLogEntry], [Pair]) {
        let winSvc = WindowingService(env: .init(calendar: calendar))

        // Normalize the window so start <= end
        let resolved = winSvc.resolveStartEnd(now: now, window: window)
        let start = min(resolved.start, resolved.endExclusive)
        let end = max(resolved.start, resolved.endExclusive)

        // Select only feeds inside the window
        let scopedFeeds = ScenarioFilterService(env: .init(calendar: calendar))
            .filterByScenario(
                feeds.filter { $0.endTime != nil && $0.startTime >= start && $0.startTime <= end },
                scenario: scenario,
                calendar: calendar
            )
            .sorted { $0.startTime < $1.startTime }

        // Not enough feeds → nothing to pair
        guard scopedFeeds.count > 1 else { return (scopedFeeds, []) }

        // Build start-to-start pairs
        let pairs: [Pair] = (1..<scopedFeeds.count).map {
            (scopedFeeds[$0 - 1], scopedFeeds[$0])
        }

        return (scopedFeeds, pairs)
    }

    /// Average interval for provided pairs respecting scenario semantics and outlier policy.
    /// - Parameters:
    ///   - pairs: Consecutive feed pairs (assumed sorted by time).
    ///   - scenario: Scenario semantics, e.g., night-only pairs must be within same civil day and both night.
    ///   - excludeOutliers: Whether to drop IQR outliers before averaging.
    ///   - calendar: Calendar for same-day/night checks.
    /// - Returns: Average interval in seconds; 0 if no valid samples.
    private func averageForPairs(
        _ pairs: [Pair],
        scenario: AverageDurationScenario,
        excludeOutliers: Bool,
        calendar: Calendar
    ) -> TimeInterval {
        let validPairs: [Pair] = {
            guard scenario == .night else { return pairs }
            return pairs.filter { p in
                calendar.isDate(p.prev.startTime, inSameDayAs: p.curr.startTime) &&
                calendar.timeOfDaySlot(for: p.prev.startTime) == .night &&
                calendar.timeOfDaySlot(for: p.curr.startTime) == .night
            }
        }()

        let vals = validPairs.compactMap(interval)
        return mean(cleaned(vals, excludeOutliers: excludeOutliers))
    }

    /// Groups intervals by the breast side of the current feed in each pair.
    /// - Parameters:
    ///   - pairs: Consecutive pairs scoped to the analysis window.
    ///   - excludeOutliers: Whether to drop IQR outliers within each bucket.
    /// - Returns: Grouped averages keyed by localized breast label.
    private func groupByBreast(
        pairs: [Pair],
        excludeOutliers: Bool
    ) -> [IntervalGroupedAverage] {
        var buckets: [String: [TimeInterval]] = [:]
        for p in pairs { if let dt = interval(p) { buckets[p.curr.breast.adjectiveLabel, default: []].append(dt) } }
        return buckets
            .compactMap { (label, vals) -> IntervalGroupedAverage? in
                let clean = cleaned(vals, excludeOutliers: excludeOutliers)
                guard !clean.isEmpty else { return nil }
                return .init(label: label, average: mean(clean), count: clean.count)
            }
            .sorted { $0.label < $1.label }
    }

    /// Groups intervals by strict same-slot, same-day pairs (both prev and curr in the same time-of-day slot).
    /// - Parameters:
    ///   - pairs: Consecutive pairs scoped to the analysis window.
    ///   - excludeOutliers: Whether to drop IQR outliers within each bucket.
    ///   - calendar: Calendar for same-day and slot detection.
    /// - Returns: Grouped averages in Morning, Afternoon, Evening, Night order.
    private func groupByTimeOfDay(
        pairs: [Pair],
        excludeOutliers: Bool,
        calendar: Calendar
    ) -> [IntervalGroupedAverage] {
        // Strict same-slot, same-day pairing used by averageIntervals(grouping: .timeOfDay)
        var buckets: [TimeOfDaySlot: [TimeInterval]] = [:]
        for p in pairs {
            guard calendar.isDate(p.prev.startTime, inSameDayAs: p.curr.startTime) else { continue }
            let sPrev = calendar.timeOfDaySlot(for: p.prev.startTime)
            let sCurr = calendar.timeOfDaySlot(for: p.curr.startTime)
            guard sPrev == sCurr, let dt = interval(p) else { continue }
            buckets[sCurr, default: []].append(dt)
        }

        let order: [TimeOfDaySlot] = [.morning, .afternoon, .evening, .night]
        return order.compactMap { s -> IntervalGroupedAverage? in
            guard let vals = buckets[s] else { return nil }
            let clean = cleaned(vals, excludeOutliers: excludeOutliers)
            guard !clean.isEmpty else { return nil }
            return .init(label: s.localizedLabel, average: mean(clean), count: clean.count)
        }
    }

    // Looser bucketing used for TimeOfDayBucket API: attribute pair to CURRENT slot
    // if the pair occurs within the same civil day.
    /// Groups intervals by the slot of the current feed (within the same civil day),
    /// applying scenario-aware mapping where late evening (>=22:00) counts as Night under `.night`.
    /// - Parameters:
    ///   - pairs: Consecutive pairs scoped to the analysis window.
    ///   - scenario: Scenario for night mapping.
    ///   - excludeOutliers: Whether to drop IQR outliers within each bucket.
    ///   - calendar: Calendar for same-day and slot detection.
    /// - Returns: Grouped averages in Morning, Afternoon, Evening, Night order.
    private func groupByTimeOfDayCurrentSlot(
        pairs: [Pair],
        scenario: AverageDurationScenario,
        excludeOutliers: Bool,
        calendar: Calendar
    ) -> [IntervalGroupedAverage] {
        var buckets: [TimeOfDaySlot: [TimeInterval]] = [:]
        for p in pairs {
            guard calendar.isDate(p.prev.startTime, inSameDayAs: p.curr.startTime) else { continue }
            var sCurr = calendar.timeOfDaySlot(for: p.curr.startTime)
            if scenario == .night && sCurr == .evening {
                let hour = calendar.component(.hour, from: p.curr.startTime)
                if hour >= 22 { sCurr = .night }
            }
            if let dt = interval(p) { buckets[sCurr, default: []].append(dt) }
        }

        let order: [TimeOfDaySlot] = [.morning, .afternoon, .evening, .night]
        return order.compactMap { s -> IntervalGroupedAverage? in
            guard let vals = buckets[s] else { return nil }
            let clean = cleaned(vals, excludeOutliers: excludeOutliers)
            guard !clean.isEmpty else { return nil }
            return .init(label: s.localizedLabel, average: mean(clean), count: clean.count)
        }
    }
}

// MARK: - Protocol conformance

extension IntervalStatsService: TimeOfDayBucketIntervalStatsServiceProtocol {
    /// Protocol implementation for time-of-day bucketed interval averages.
    /// Uses current-slot bucketing and returns `TimeOfDayBucket` models for UI/consumers.
    public func averageIntervalsTimeOfBuckets(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        scenario: AverageDurationScenario,
        excludeOutliers: Bool,
        now: Date,
        calendar: Calendar
    ) -> (overall: TimeInterval, groups: [TimeOfDayBucket]) {
        let (_, pairs) = scopedPairs(
            feeds: feeds,
            window: window,
            scenario: scenario,
            now: now,
            calendar: calendar
        )

        guard !pairs.isEmpty else { return (0, []) }

        let overall = averageForPairs(pairs, scenario: scenario, excludeOutliers: excludeOutliers, calendar: calendar)

        let grouped = groupByTimeOfDayCurrentSlot(
            pairs: pairs,
            scenario: scenario,
            excludeOutliers: excludeOutliers,
            calendar: calendar
        )

        let buckets = grouped.compactMap { g -> TimeOfDayBucket? in
            guard let slot = TimeOfDaySlot.allCases.first(where: { $0.localizedLabel == g.label }) else { return nil }
            return TimeOfDayBucket(
                id: .init(rawValue: slot.rawValue)!,
                label: g.label,
                total: g.average,
                sessionCount: g.count
            )
        }

        return (overall, buckets)
    }
}
