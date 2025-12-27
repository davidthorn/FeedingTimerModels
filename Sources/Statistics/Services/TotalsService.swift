//
//  TotalsService.swift
//  FeedingTimer
//
//  Scaffolding for daily/weekly/monthly total duration series and related trends.
//

import Foundation
import Models

public struct TotalsService: Sendable {
    public let env: StatsEnvironment

    public init(env: StatsEnvironment = .init()) {
        self.env = env
    }

    // Mirrors FeedingStatsService.dailyTotalDurationSeries
    /// Daily total duration series over a window of days.
    public func dailyTotalDurationSeries(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        scenario: AverageDurationScenario = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyDurationPoint] {
        let resolved = WindowingService(env: .init(calendar: calendar)).resolveStartEnd(now: now, window: window)
        let start = calendar.startOfDay(for: resolved.start)
        let endExclusive = resolved.endExclusive

        // Filter sessions by scenario and window, but we will distribute by segment overlap.
        let scoped = ScenarioFilterService(env: .init(calendar: calendar))
            .filterByScenario(
                feeds.filter { $0.endTime != nil && $0.startTime < endExclusive && ($0.endTime ?? $0.startTime) >= start },
                scenario: scenario,
                calendar: calendar
            )

        var totalsByDay: [Date: TimeInterval] = [:]

        func accumulateByDay(_ s: Date, _ e: Date) {
            var curStart = max(s, start)
            let hardEnd = min(e, endExclusive)
            guard hardEnd > curStart else { return }
            while curStart < hardEnd {
                let day = calendar.startOfDay(for: curStart)
                let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? hardEnd
                let chunkEnd = min(hardEnd, nextDay)
                let dt = max(0, chunkEnd.timeIntervalSince(curStart))
                if dt > 0 { totalsByDay[day, default: 0] += dt }
                curStart = chunkEnd
            }
        }

        for e in scoped {
            if !e.breastUnits.isEmpty {
                for u in e.breastUnits { accumulateByDay(u.startTime, u.endTime) }
            } else if let end = e.endTime {
                accumulateByDay(e.startTime, end)
            }
        }

        let endDay = calendar.startOfDay(for: endExclusive)
        let dayCount = max(0, calendar.dateComponents([.day], from: start, to: endDay).day ?? 0)
        return (0..<dayCount).map { i in
            let d = calendar.date(byAdding: .day, value: i, to: start)!
            return DailyDurationPoint(id: d, date: d, total: totalsByDay[d] ?? 0)
        }
    }

    // Mirrors FeedingStatsService.dailyTotalTrend
    public func dailyTotalTrend(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        scenario: AverageDurationScenario = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DailyTotalTrend {
        let series = dailyTotalDurationSeries(feeds: feeds, window: window, scenario: scenario, now: now, calendar: calendar)
        let currentAvg = series.isEmpty ? 0 : series.map(\.total).reduce(0, +) / Double(series.count)

        let prevEnd = calendar.startOfDay(for: now)
        let prevNow = calendar.date(byAdding: .day, value: -1, to: prevEnd)!
        let prevSeries = dailyTotalDurationSeries(feeds: feeds, window: window, scenario: scenario, now: prevNow, calendar: calendar)
        let previousAvg = prevSeries.isEmpty ? 0 : prevSeries.map(\.total).reduce(0, +) / Double(prevSeries.count)

        return .init(currentAvgPerDay: currentAvg, previousAvgPerDay: previousAvg)
    }

    // Mirrors FeedingStatsService.weeklyTotalDurationSeries
    public func weeklyTotalDurationSeries(
        feeds: [FeedingLogEntry],
        weeksBack: Int,
        scenario: AverageDurationScenario = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [WeeklyDurationPoint] {
        precondition(weeksBack >= 1, "weeksBack must be >= 1")

        let (start, endExclusive, cal) = WindowingService(env: .init(calendar: calendar)).weekStartEndExclusive(now: now, weeksBack: weeksBack)

        // Build daily series across the span, then fold by week start
        let daily = dailyTotalDurationSeries(
            feeds: feeds,
            window: .days(max(1, cal.dateComponents([.day], from: start, to: endExclusive).day ?? weeksBack * 7)),
            scenario: scenario,
            now: endExclusive, // end anchor ensures the days cover [start, endExclusive)
            calendar: cal
        )

        var totalsByWeek: [Date: TimeInterval] = [:]
        for p in daily {
            let ws = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: p.date))!
            totalsByWeek[ws, default: 0] += p.total
        }

        return (0..<weeksBack).map { i in
            let ws = cal.date(byAdding: .weekOfYear, value: i, to: start)!
            return WeeklyDurationPoint(id: ws, weekStart: ws, total: totalsByWeek[ws] ?? 0)
        }
    }

    // Mirrors FeedingStatsService.monthlyTotalDurationSeries
    public func monthlyTotalDurationSeries(
        feeds: [FeedingLogEntry],
        monthsBack: Int,
        scenario: AverageDurationScenario = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [MonthlyDurationPoint] {
        precondition(monthsBack >= 1, "monthsBack must be >= 1")

        let (start, endExclusive) = WindowingService(env: .init(calendar: calendar)).monthStartEndExclusive(now: now, monthsBack: monthsBack)

        // Build daily series across the span, then fold by month start
        let daily = dailyTotalDurationSeries(
            feeds: feeds,
            window: .days(max(1, calendar.dateComponents([.day], from: start, to: endExclusive).day ?? monthsBack * 30)),
            scenario: scenario,
            now: endExclusive,
            calendar: calendar
        )

        var totalsByMonth: [Date: TimeInterval] = [:]
        for p in daily {
            let ms = calendar.date(from: calendar.dateComponents([.year, .month], from: p.date))!
            totalsByMonth[ms, default: 0] += p.total
        }

        return (0..<monthsBack).map { i in
            let ms = calendar.date(byAdding: .month, value: i, to: start)!
            return MonthlyDurationPoint(id: ms, monthStart: ms, total: totalsByMonth[ms] ?? 0)
        }
    }

    // Mirrors FeedingStatsService.windowTrend
    public func windowTrend(current: [TimeInterval], previous: [TimeInterval]) -> WindowTrend {
        let cAvg = current.isEmpty ? 0 : current.reduce(0, +) / Double(current.count)
        let pAvg = previous.isEmpty ? 0 : previous.reduce(0, +) / Double(previous.count)
        return .init(currentAvg: cAvg, previousAvg: pAvg)
    }
}
