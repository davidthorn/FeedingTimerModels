//
//  WindowingService.swift
//  FeedingTimer
//
//  Scaffolding for date window calculations (days/weeks/months & previous windows).
//

import Foundation
import Models

/// Date window calculations (days/weeks/months and rolling windows), using
/// the injected environment for `now` and `calendar`.
///
/// Invariants:
/// - All helpers return a start bound that is <= end bound.
/// - "EndExclusive" indicates the returned end is not included in the window.
/// - Day/Week/Month helpers align to civil boundaries in the provided calendar.
public struct WindowingService: Sendable {
    public let env: StatsEnvironment

    public init(env: StatsEnvironment = .init()) {
        self.env = env
    }

    /// Window covering the last `daysBack` civil days up to `now`.
    /// - Parameters:
    ///   - now: Anchor date; defaults to `env.nowProvider.now`.
    ///   - daysBack: Number of days to include, where `1` means "today" only.
    /// - Returns: Closed range `[start, now]` aligned to the start of day for `start`.
    public func dayWindow(now: Date? = nil, daysBack: Int) -> ClosedRange<Date> {
        let cal = env.calendar
        let anchor = now ?? env.nowProvider.now
        let day0 = cal.startOfDay(for: anchor)
        let start = cal.date(byAdding: .day, value: -(max(0, daysBack - 1)), to: day0)!
        return start...anchor
    }

    /// Start and end (exclusive) covering the last `daysBack` civil days ending at the end of today.
    /// - Parameters:
    ///   - now: Anchor date; defaults to `env.nowProvider.now`.
    ///   - daysBack: Number of days to include, where `1` means "today" only.
    /// - Returns: `(start, endExclusive)` where `endExclusive` equals the start of the next day.
    public func dayStartEndExclusive(now: Date? = nil, daysBack: Int) -> (start: Date, endExclusive: Date) {
        let cal = env.calendar
        let anchor = now ?? env.nowProvider.now
        let day0 = cal.startOfDay(for: anchor)
        let start = cal.date(byAdding: .day, value: -(max(0, daysBack - 1)), to: day0)!
        let endExclusive = cal.date(byAdding: .day, value: 1, to: day0)!
        return (start, endExclusive)
    }

    /// Rolling window of the last `hoursBack` hours ending at `now`.
    /// - Parameters:
    ///   - now: Anchor date; defaults to `env.nowProvider.now`.
    ///   - hoursBack: Number of hours to include; negative values are clamped to 0.
    /// - Returns: `(start, endExclusive)` where `endExclusive == now`.
    public func rollingStartEnd(now: Date? = nil, hoursBack: Int) -> (start: Date, endExclusive: Date) {
        let anchor = now ?? env.nowProvider.now
        let start = anchor.addingTimeInterval(-TimeInterval(max(0, hoursBack)) * 3600)
        return (start, anchor)
    }

    /// Resolves a `TimeWindow` to start and exclusive end timestamps.
    /// - Parameters:
    ///   - now: Anchor date; defaults to `env.nowProvider.now`.
    ///   - window: `.days(n)` uses `dayStartEndExclusive`, `.hours(n)` uses `rollingStartEnd`.
    /// - Returns: `(start, endExclusive)`.
    public func resolveStartEnd(now: Date? = nil, window: TimeWindow) -> (start: Date, endExclusive: Date) {
        switch window {
        case .days(let d):
            return dayStartEndExclusive(now: now, daysBack: d)
        case .hours(let h):
            return rollingStartEnd(now: now, hoursBack: h)
        }
    }

    /// Week window aligned to the calendar's week, using Monday as the first weekday.
    /// - Parameters:
    ///   - now: Anchor date; defaults to `env.nowProvider.now`.
    ///   - weeksBack: Number of weeks to include, where `1` means "this week".
    /// - Returns: `(start, endExclusive, calendar)`; returned calendar is adjusted to Monday-first.
    public func weekStartEndExclusive(now: Date? = nil, weeksBack: Int) -> (start: Date, endExclusive: Date, calendar: Calendar) {
        var cal = env.calendar
        cal.firstWeekday = 2 // Monday to match app logic
        let anchor = now ?? env.nowProvider.now
        let todayStart = cal.startOfDay(for: anchor)
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: todayStart))!
        let start = cal.date(byAdding: .weekOfYear, value: -(max(0, weeksBack - 1)), to: weekStart)!
        let endExclusive = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
        return (start, endExclusive, cal)
    }

    /// Month window aligned to the calendar's month boundaries.
    /// - Parameters:
    ///   - now: Anchor date; defaults to `env.nowProvider.now`.
    ///   - monthsBack: Number of months to include, where `1` means "this month".
    /// - Returns: `(start, endExclusive)` aligned to the current and next month starts.
    public func monthStartEndExclusive(now: Date? = nil, monthsBack: Int) -> (start: Date, endExclusive: Date) {
        let cal = env.calendar
        let anchor = now ?? env.nowProvider.now
        let todayStart = cal.startOfDay(for: anchor)
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: todayStart))!
        let start = cal.date(byAdding: .month, value: -(max(0, monthsBack - 1)), to: monthStart)!
        let endExclusive = cal.date(byAdding: .month, value: 1, to: monthStart)!
        return (start, endExclusive)
    }
}
