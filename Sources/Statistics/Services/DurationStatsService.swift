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
        recencyHalfLifeHours: Double? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (overall: TimeInterval, groups: [GroupedAverage]) {
        guard !feeds.isEmpty else { return (0, []) }

        // Completed feeds within window
        let windowed = windowedFeeds(
            feeds: feeds,
            window: window,
            now: now,
            calendar: calendar
        )

        // Build samples: only entries that have breastUnits; average per feed is sum(units)
        let samples: [(date: Date, value: TimeInterval)] = windowed.compactMap { e in
            guard !e.breastUnits.isEmpty else { return nil }
            return (e.startTime, e.breastUnits.reduce(0) { $0 + $1.duration })
        }

        // Apply outlier filter (IQR) on values only, keeping pairs by bounds
        let overall: TimeInterval = {
            let kept = applyIQRIfNeeded(samples, policy: outlierPolicy)
            return weightedMean(kept, halfLifeHours: recencyHalfLifeHours, now: now)
        }()

        switch grouping {
        case .none:
            return (overall, [])

        case .breast:
            // Build per-breast samples summing unit durations for that breast per feed
            var left: [(Date, TimeInterval)] = []
            var right: [(Date, TimeInterval)] = []
            left.reserveCapacity(samples.count)
            right.reserveCapacity(samples.count)
            for e in windowed {
                guard !e.breastUnits.isEmpty else { continue }
                let l = e.breastUnits.filter { $0.breast == .left }.reduce(0) { $0 + $1.duration }
                let r = e.breastUnits.filter { $0.breast == .right }.reduce(0) { $0 + $1.duration }
                if l > 0 { left.append((e.startTime, l)) }
                if r > 0 { right.append((e.startTime, r)) }
            }
            func make(label: String, smps: [(Date, TimeInterval)]) -> GroupedAverage? {
                guard !smps.isEmpty else { return nil }
                let kept = applyIQRIfNeeded(smps, policy: outlierPolicy)
                let avg = weightedMean(kept, halfLifeHours: recencyHalfLifeHours, now: now)
                return .init(label: label, average: avg, count: kept.count)
            }
            let groups = [
                make(label: Breast.left.adjectiveLabel, smps: left),
                make(label: Breast.right.adjectiveLabel, smps: right)
            ].compactMap { $0 }
            return (overall, groups.sorted { $0.label < $1.label })

        case .timeOfDay:
            let buckets = timeOfDayBuckets(
                feeds: windowed,
                scenario: scenario,
                outlierPolicy: outlierPolicy,
                recencyHalfLifeHours: recencyHalfLifeHours,
                calendar: calendar,
                now: now
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
        recencyHalfLifeHours: Double?,
        calendar: Calendar,
        now: Date
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
            // samples per entry using units-only
            let smps: [(Date, TimeInterval)] = entries.compactMap { e in
                guard !e.breastUnits.isEmpty else { return nil }
                return (e.startTime, e.breastUnits.reduce(0) { $0 + $1.duration })
            }
            let kept = applyIQRIfNeeded(smps, policy: outlierPolicy)
            guard !kept.isEmpty else { return nil }
            let avg = weightedMean(kept, halfLifeHours: recencyHalfLifeHours, now: now)
            return .init(label: s.localizedLabel, average: avg, count: kept.count)
        }
    }

    // MARK: - IQR filtering with bounds (to retain dates)
    private func applyIQRIfNeeded(_ samples: [(Date, TimeInterval)], policy: OutlierPolicy) -> [(Date, TimeInterval)] {
        switch policy {
        case .includeAll:
            return samples
        case .excludeIQR:
            let values = samples.map { $0.1 }
            guard let bounds = iqrBounds(values) else { return samples }
            let low = bounds.low, high = bounds.high
            return samples.filter { $0.1 >= low && $0.1 <= high }
        }
    }

    private func iqrBounds(_ values: [TimeInterval]) -> (low: TimeInterval, high: TimeInterval)? {
        let n = values.count
        guard n >= 4 else { return nil }
        let sorted = values.sorted()
        func q(_ p: Double) -> TimeInterval {
            let x = max(0, min(Double(n - 1), p * Double(n - 1)))
            let lo = Int(floor(x)), hi = Int(ceil(x))
            if lo == hi { return sorted[lo] }
            let w = x - Double(lo)
            return sorted[lo] * (1 - w) + sorted[hi] * w
        }
        let q1 = q(0.25), q3 = q(0.75), iqr = q3 - q1
        return (q1 - 1.5 * iqr, q3 + 1.5 * iqr)
    }

    // MARK: - Recency weighting
    private func weightedMean(_ samples: [(Date, TimeInterval)], halfLifeHours: Double?, now: Date) -> TimeInterval {
        guard !samples.isEmpty else { return 0 }
        guard let hl = halfLifeHours, hl > 0 else {
            let vals = samples.map { $0.1 }
            return vals.reduce(0, +) / Double(vals.count)
        }
        let tau = hl * 3600.0 / log(2.0)
        var num: Double = 0
        var den: Double = 0
        for (date, value) in samples {
            let age = max(0, now.timeIntervalSince(date))
            let w = exp(-age / tau)
            num += w * value
            den += w
        }
        return den > 0 ? num / den : 0
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
            recencyHalfLifeHours: nil,
            calendar: calendar,
            now: now
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
