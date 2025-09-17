//
//  DurationStatsService.swift
//  FeedingTimer
//
//  Scaffolding for duration averages, stability, milestones, and tips.
//

import Foundation
import Models

public struct DurationStatsService {
    public let env: StatsEnvironment

    public init(env: StatsEnvironment = .init()) {
        self.env = env
    }

    // Mirrors FeedingStatsService.averageDurations
    /// Average feeding durations over a window, with optional grouping.
    /// - Parameters:
    ///   - feeds: All feed entries; only completed feeds are considered.
    ///   - window: Time window (days or hours) resolved via WindowingService.
    ///   - grouping: `.none`, `.breast`, or `.timeOfDay`.
    ///   - outlierPolicy: Whether to exclude IQR outliers.
    ///   - scenario: Scenario for time-of-day grouping (affects late evening mapping under `.night`).
    ///   - now: Reference time for window anchoring.
    ///   - calendar: Calendar used for day boundaries and time-of-day slots.
    /// - Returns: Overall average and grouped averages if requested.
    public func averageDurations(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        grouping: AverageDurationGrouping,
        outlierPolicy: OutlierPolicy,
        scenario: AverageDurationScenario = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (overall: TimeInterval, groups: [GroupedAverage]) {
        guard !feeds.isEmpty else { return (0, []) }

        let windowed = windowedFeeds(
            feeds: feeds,
            window: window,
            now: now,
            calendar: calendar
        )

        let overall = overallAverage(
            durations: windowed.compactMap { entry in entry.effectiveDuration(use: entry.breastUnits) },
            outlierPolicy: outlierPolicy
        )

        switch grouping {
        case .none:
            return (overall, [])

        case .breast:
            let buckets = Dictionary(grouping: windowed, by: { $0.breast })
                .compactMap { (breast, entries) -> GroupedAverage? in
                    let vals = filteredDurations(entries.compactMap { entry in entry.effectiveDuration(use: entry.breastUnits) }, outlierPolicy: outlierPolicy)
                    guard !vals.isEmpty else { return nil }
                    let avg = vals.reduce(0,+) / Double(vals.count)
                    return .init(label: breast.adjectiveLabel, average: avg, count: vals.count)
                }
                .sorted { $0.label < $1.label }
            return (overall, buckets)

        case .timeOfDay:
            let buckets = timeOfDayBuckets(
                feeds: windowed,
                scenario: scenario,
                outlierPolicy: outlierPolicy,
                calendar: calendar
            )
            return (overall, buckets)
        @unknown default:
            fatalError()
        }
    }

    // Mirrors FeedingStatsService.durationTrend
    /// Compares average duration in the current window vs the previous same-sized window.
    /// - Parameters:
    ///   - feeds: All feed entries; only completed feeds are considered.
    ///   - window: Days or hours window. Values < 1 yield zeros.
    ///   - now: Reference time; current window ends at `now`, previous just before it.
    ///   - calendar: Calendar for resolving day windows.
    /// - Returns: DurationTrend with current and previous averages.
    public func durationTrend(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DurationTrend {
        switch window {
        case .days(let d) where d < 1: return .init(currentAvg: 0, previousAvg: 0)
        case .hours(let h) where h < 1: return .init(currentAvg: 0, previousAvg: 0)
        default: break
        }

        func avg(_ range: ClosedRange<Date>) -> TimeInterval {
            let d = feeds.filter { $0.endTime != nil && range.contains($0.startTime) }.compactMap { entry in entry.effectiveDuration(use: entry.breastUnits) }
            return d.isEmpty ? 0 : d.reduce(0,+) / Double(d.count)
        }

        let winSvc = WindowingService(env: .init(calendar: calendar))
        switch window {
        case .days(let d):
            let startCurrent = winSvc.dayStartEndExclusive(now: now, daysBack: d).start
            let startPrev    = calendar.date(byAdding: .day, value: -d, to: startCurrent)!
            let endPrev      = calendar.date(byAdding: .second, value: -1, to: startCurrent)!
            return .init(currentAvg: avg(startCurrent...now), previousAvg: avg(startPrev...endPrev))
        case .hours(let h):
            let curr = winSvc.rollingStartEnd(now: now, hoursBack: h)
            let prevEndExclusive = curr.start
            let prevStart = prevEndExclusive.addingTimeInterval(-TimeInterval(max(0, h)) * 3600)
            let prevEnd = calendar.date(byAdding: .second, value: -1, to: prevEndExclusive) ?? prevEndExclusive
            return .init(currentAvg: avg(curr.start...now), previousAvg: avg(prevStart...prevEnd))
        @unknown default:
            fatalError()
        }
    }

    // Mirrors FeedingStatsService.durationStability
    /// Coefficient of variation (stddev/mean) of durations within the window.
    /// - Parameters:
    ///   - feeds: All feed entries; only completed feeds are considered.
    ///   - window: Window for sampling.
    ///   - now: Reference time.
    ///   - calendar: Calendar for window resolution.
    /// - Returns: CV as a Double; returns 0 if insufficient data or mean == 0.
    public func durationStability(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Double {
        let resolved = WindowingService(env: .init(calendar: calendar)).resolveStartEnd(now: now, window: window)
        let start = resolved.start
        let end = now
        let vals = feeds.filter { $0.endTime != nil && $0.startTime >= start && $0.startTime <= end }
            .compactMap { entry in entry.effectiveDuration(use: entry.breastUnits) }
        guard vals.count >= 2 else { return 0 }
        let mean = vals.reduce(0,+)/Double(vals.count)
        guard mean > 0 else { return 0 }
        let variance = vals.reduce(0) { $0 + pow($1 - mean, 2) } / Double(vals.count - 1)
        return sqrt(variance)/mean
    }

    // Mirrors FeedingStatsService.longestFeed
    /// Longest completed feed within the window.
    /// - Parameters:
    ///   - feeds: All feed entries; only completed feeds are considered.
    ///   - window: Window for sampling.
    ///   - now: Reference time.
    ///   - calendar: Calendar for window resolution.
    /// - Returns: DurationMilestone if found; otherwise nil.
    public func longestFeed(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DurationMilestone? {
        let resolved = WindowingService(env: .init(calendar: calendar)).resolveStartEnd(now: now, window: window)
        let start = resolved.start
        guard let best = feeds
            .filter({ $0.endTime != nil && $0.startTime >= start && $0.startTime <= now })
            .max(by: { $0.effectiveDuration(use: $0.breastUnits) < $1.effectiveDuration(use: $1.breastUnits) })
        else { return nil }

        let dur = best.effectiveDuration(use: best.breastUnits)
        return .init(
            title: NSLocalizedString("Longest feed", comment: ""),
            value: dur,
            date: best.startTime,
            breast: best.breast
        )
    }

    // Mirrors FeedingStatsService.averageDurationTips
    public func averageDurationTips(
        trend: DurationTrend,
        stabilityCV: Double,
        scenario: AverageDurationScenario,
        sampleCount: Int
    ) -> [AverageDurationTip] {
        var tips: [AverageDurationTip] = []

        if sampleCount < 3 {
            tips.append(.init(id: "few", text: NSLocalizedString("Not enough recent feeds to show reliable patterns yet.", comment: "")))
            return tips
        }
        if trend.percent > 8 {
            tips.append(.init(id: "up", text: NSLocalizedString("Feeds are getting longer — babies sometimes take their time during growth phases.", comment: "")))
        } else if trend.percent < -8 {
            tips.append(.init(id: "down", text: NSLocalizedString("Slightly shorter feeds lately — many babies get more efficient as they grow.", comment: "")))
        }
        if stabilityCV > 0.35 {
            tips.append(.init(id: "variable", text: NSLocalizedString("Durations are quite variable — variability is common during routine changes.", comment: "")))
        }
        if scenario == .night {
            tips.append(.init(id: "night", text: NSLocalizedString("Night feeds often trend shorter as settling improves.", comment: "")))
        }
        return Array(tips.prefix(2))
    }

    // MARK: - Private helpers

    /// Completed feeds within the resolved window [start, now].
    private func windowedFeeds(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        now: Date,
        calendar: Calendar
    ) -> [FeedingLogEntry] {
        let resolved = WindowingService(env: .init(calendar: calendar)).resolveStartEnd(now: now, window: window)
        let start = resolved.start
        return feeds.filter { $0.endTime != nil && $0.startTime >= start && $0.startTime <= now }
    }

    /// Mean of durations with outlier policy applied.
    private func overallAverage(
        durations: [TimeInterval],
        outlierPolicy: OutlierPolicy
    ) -> TimeInterval {
        let vals = filteredDurations(durations, outlierPolicy: outlierPolicy)
        return vals.isEmpty ? 0 : vals.reduce(0,+) / Double(vals.count)
    }

    /// Applies outlier policy to a set of durations.
    private func filteredDurations(
        _ durations: [TimeInterval],
        outlierPolicy: OutlierPolicy
    ) -> [TimeInterval] {
        (outlierPolicy == .excludeIQR) ? OutlierService().excludeIQR(durations) : durations
    }

    /// Groups completed feeds by time-of-day slot, with night scenario merging late evening (>=22:00) into night.
    private func timeOfDayBuckets(
        feeds: [FeedingLogEntry],
        scenario: AverageDurationScenario,
        outlierPolicy: OutlierPolicy,
        calendar: Calendar
    ) -> [GroupedAverage] {
        let grouped = Dictionary(grouping: feeds, by: { (entry: FeedingLogEntry) -> TimeOfDaySlot in
            let slot: TimeOfDaySlot = calendar.timeOfDaySlot(for: entry.startTime)
            if scenario == .night && slot == .evening {
                let h: Int = calendar.component(.hour, from: entry.startTime)
                if h >= 22 { return .night }
            }
            return slot
        })
        let order: [TimeOfDaySlot] = [.morning, .afternoon, .evening, .night]
        return order.compactMap { s -> GroupedAverage? in
            guard let entries = grouped[s] else { return nil }
            let vals = filteredDurations(entries.compactMap { entry in entry.effectiveDuration(use: entry.breastUnits) }, outlierPolicy: outlierPolicy)
            guard !vals.isEmpty else { return nil }
            let avg = vals.reduce(0,+) / Double(vals.count)
            return .init(label: s.localizedLabel, average: avg, count: vals.count)
        }
    }
}

// MARK: - Protocol conformance

extension DurationStatsService: TimeOfDayBucketStatsServiceProtocol {
    public func averageDurationTimeOfDayBuckets(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        outlierPolicy: OutlierPolicy,
        scenario: AverageDurationScenario,
        now: Date,
        calendar: Calendar
    ) -> (overall: TimeInterval, groups: [TimeOfDayBucket]) {
        guard !feeds.isEmpty else { return (0, []) }

        let windowed = windowedFeeds(
            feeds: feeds,
            window: window,
            now: now,
            calendar: calendar
        )

        let overall = overallAverage(
            durations: windowed.compactMap { entry in entry.effectiveDuration(use: entry.breastUnits) },
            outlierPolicy: outlierPolicy
        )

        let grouped = timeOfDayBuckets(
            feeds: windowed,
            scenario: scenario,
            outlierPolicy: outlierPolicy,
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
