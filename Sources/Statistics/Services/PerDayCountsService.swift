//
//  PerDayCountsService.swift
//  FeedingTimer
//
//  Scaffolding for per-day counts series/summary/trends.
//

import Foundation
import Models

public struct PerDayCountsService: Sendable {
    public let env: StatsEnvironment

    public init(env: StatsEnvironment = .init()) {
        self.env = env
    }

    /// Contiguous per-day feed counts over a window, including zero-count days.
    /// - Parameters:
    ///   - feeds: All feed entries; only completed feeds are considered.
    ///   - window: Time window (days or hours) resolved via WindowingService.
    ///   - scenario: Scenario filter (all/day/night).
    ///   - grouping: `.all` or `.breast` (left/right). Overall is always returned.
    ///   - now: Reference time for windowing.
    ///   - calendar: Calendar used for day boundaries.
    /// - Returns: Overall per-day series, and optional left/right when grouping == .breast.
    public func feedsPerDaySeries(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        scenario: AverageDurationScenario = .all,
        grouping: FeedsPerDayGrouping = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (overall: [FeedsPerDayPoint], left: [FeedsPerDayPoint]?, right: [FeedsPerDayPoint]?) {
        let resolved = WindowingService(env: .init(calendar: calendar)).resolveStartEnd(now: now, window: window)
        let start = calendar.startOfDay(for: resolved.start)
        let endExclusive = resolved.endExclusive

        // Compute number of whole days in the window
        let endDay = calendar.startOfDay(for: endExclusive)
        let daysBack = max(0, calendar.dateComponents([.day], from: start, to: endDay).day ?? 0)

        // Scenario filter first
        let scoped = ScenarioFilterService(env: .init(calendar: calendar))
            .filterByScenario(
                feeds.filter { $0.endTime != nil && $0.startTime >= start && $0.startTime < endExclusive },
                scenario: scenario,
                calendar: calendar
            )

        func series(for subset: [FeedingLogEntry]) -> [FeedsPerDayPoint] {
            // Group by startOfDay
            let grouped = Dictionary(grouping: subset, by: { calendar.startOfDay(for: $0.startTime) })
            // Build contiguous series across the whole window (including zero days)
            return (0..<daysBack).map { i in
                let day = calendar.date(byAdding: .day, value: i, to: start)!
                let c = grouped[day]?.count ?? 0
                return FeedsPerDayPoint(id: day, date: day, count: c)
            }
        }

        switch grouping {
        case .all:
            return (series(for: scoped), nil, nil)
        case .breast:
            let left = series(for: scoped.filter { $0.breast == .left })
            let right = series(for: scoped.filter { $0.breast == .right })
            let overall = zip(left, right).map { FeedsPerDayPoint(id: $0.0.id, date: $0.0.date, count: $0.0.count + $0.1.count) }
            return (overall, left, right)
        }
    }

    public func feedsPerDaySummary(points: [FeedsPerDayPoint]) -> FeedsPerDaySummary {
        guard !points.isEmpty else {
            return .init(average: 0, median: 0, min: 0, max: 0, samples: 0)
        }
        let counts = points.map(\.count)
        let avg = Double(counts.reduce(0, +)) / Double(counts.count)
        let sorted = counts.sorted()
        let median: Double = {
            let n = sorted.count
            if n % 2 == 1 {
                return Double(sorted[n/2])
            } else {
                return Double(sorted[n/2 - 1] + sorted[n/2]) / 2.0
            }
        }()
        return .init(
            average: avg,
            median: median,
            min: sorted.first ?? 0,
            max: sorted.last ?? 0,
            samples: counts.count
        )
    }

    /// Average feeds per day in the current window vs the previous same-sized window.
    public func feedsPerDayTrend(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        scenario: AverageDurationScenario = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> FeedsPerDayTrend {
        let win = WindowingService(env: .init(calendar: calendar)).resolveStartEnd(now: now, window: window)
        let curStart = calendar.startOfDay(for: win.start)
        let curEndExclusive = win.endExclusive
        // Define previous window as the immediately preceding span of equal length in days.
        let dayCount = max(0, calendar.dateComponents([.day], from: curStart, to: calendar.startOfDay(for: curEndExclusive)).day ?? 0)
        let prevStart = calendar.date(byAdding: .day, value: -dayCount, to: curStart) ?? curStart
        let prevEnd = curStart

        func avgIn(_ range: Range<Date>) -> Double {
            let scoped = ScenarioFilterService(env: .init(calendar: calendar))
                .filterByScenario(
                    feeds.filter { $0.endTime != nil && range.contains($0.startTime) },
                    scenario: scenario,
                    calendar: calendar
                )
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: range.lowerBound), to: calendar.startOfDay(for: range.upperBound)).day ?? 0
            guard days > 0 else { return 0 }
            var counts: [Int] = []
            counts.reserveCapacity(days)
            for i in 0..<days {
                let d = calendar.date(byAdding: .day, value: i, to: calendar.startOfDay(for: range.lowerBound))!
                let next = calendar.date(byAdding: .day, value: 1, to: d)!
                let c = scoped.filter { $0.startTime >= d && $0.startTime < next }.count
                counts.append(c)
            }
            return Double(counts.reduce(0, +)) / Double(days)
        }

        let currentAvg = avgIn(curStart..<curEndExclusive)
        let previousAvg = avgIn(prevStart..<prevEnd)
        return .init(currentAvg: currentAvg, previousAvg: previousAvg)
    }
}
