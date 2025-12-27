//
//  TodayStatsService.swift
//  FeedingTimer
//
//  Extracted helpers for today's summaries, time-of-day breakdown, and pacing comparison.
//

import Foundation
import Models

public struct TodayStatsService: Sendable {
    public let env: StatsEnvironment

    public init(env: StatsEnvironment = .init()) {
        self.env = env
    }

    public func timeSpentFeedingToday(
        feeds: [FeedingLogEntry],
        activeFeed: FeedingLogEntry?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TodayFeedingSummary {
        let dayStart = calendar.startOfDay(for: now)
        let todayRange: ClosedRange<Date> = dayStart...now

        var total: TimeInterval = 0
        var left: TimeInterval = 0
        var right: TimeInterval = 0
        var completedCount: Int = 0
        var activeElapsed: TimeInterval = 0

        // Completed feeds (clip to today) — segment-aware when units exist
        for entry in feeds where entry.endTime != nil {
            if !entry.breastUnits.isEmpty {
                var contributed = false
                for u in entry.breastUnits {
                    let d = overlapDuration(start: u.startTime, end: u.endTime, within: todayRange)
                    if d > 0 {
                        total += d
                        if u.breast == .left { left += d } else { right += d }
                        contributed = true
                    }
                }
                if contributed { completedCount += 1 }
            } else {
                let d = overlapDuration(entry: entry, within: todayRange)
                if d > 0 {
                    total += d
                    if entry.breast == .left { left += d } else { right += d }
                    completedCount += 1
                }
            }
        }

        // Active feed (if any):
        // - Include any completed segments in its `breastUnits` (like completed feeds above).
        // - For the currently running segment, we do not know the in-memory start without `FeedLogService`.
        //   As a fallback for cases with no units (typical simple active session), use envelope from start..now.
        if let active = activeFeed, active.endTime == nil {
            // Count completed segments inside the active feed
            if !active.breastUnits.isEmpty {
                for u in active.breastUnits {
                    let d = overlapDuration(start: u.startTime, end: u.endTime, within: todayRange)
                    if d > 0 {
                        total += d
                        if u.breast == .left { left += d } else { right += d }
                    }
                }
                // We cannot infer a running segment start here; leave activeElapsed = 0
            } else {
                // Fallback: envelope since start (may overcount pause; refined in FeedLogService views)
                let d = overlapDurationForActive(entry: active, within: todayRange, now: now)
                if d > 0 {
                    total += d
                    activeElapsed = d
                    if active.breast == .left { left += d } else { right += d }
                }
            }
        }

        return TodayFeedingSummary(
            total: total,
            leftTotal: left,
            rightTotal: right,
            completedCount: completedCount,
            activeElapsed: activeElapsed,
            hasActive: activeFeed?.endTime == nil && activeElapsed > 0
        )
    }

    public func todayTimeOfDayBreakdown(
        feeds: [FeedingLogEntry],
        activeFeed: FeedingLogEntry?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [TimeOfDayBucket] {
        let dayStart = calendar.startOfDay(for: now)

        // Slot boundaries
        let d6  = calendar.date(byAdding: .hour, value: 6,  to: dayStart)!
        let d12 = calendar.date(byAdding: .hour, value: 12, to: dayStart)!
        let d18 = calendar.date(byAdding: .hour, value: 18, to: dayStart)!

        // Build ClosedRange<Date> for each slot with guaranteed lower <= upper (zero-length if future)
        let nightUpper   = min(d6, now)
        let night: ClosedRange<Date> = dayStart ... nightUpper

        let morningLower = d6
        let morningUpper = max(morningLower, min(d12, now))
        let morning: ClosedRange<Date> = morningLower ... morningUpper

        let afternoonLower = d12
        let afternoonUpper = max(afternoonLower, min(d18, now))
        let afternoon: ClosedRange<Date> = afternoonLower ... afternoonUpper

        let eveningLower = d18
        let eveningUpper = max(eveningLower, now)
        let evening: ClosedRange<Date> = eveningLower ... eveningUpper

        // Canonical order for display: Morning, Afternoon, Evening, Night
        let slots: [(TimeOfDayBucket.Slot, ClosedRange<Date>, String)] = [
            (.morning,   morning,   NSLocalizedString("Morning", comment: "")),
            (.afternoon, afternoon, NSLocalizedString("Afternoon", comment: "")),
            (.evening,   evening,   NSLocalizedString("Evening", comment: "")),
            (.night,     night,     NSLocalizedString("Night", comment: ""))
        ]

        // Accumulators
        var totals: [TimeOfDayBucket.Slot: TimeInterval] = [:]
        var counts: [TimeOfDayBucket.Slot: Int] = [:]
        TimeOfDayBucket.Slot.allCases.forEach { totals[$0] = 0; counts[$0] = 0 }

        // Helper to add overlap for an interval across slots
        func addInterval(_ start: Date, _ end: Date) {
            let interval = max(0, end.timeIntervalSince(start))
            guard interval > 0 else { return }
            for (slot, slotRange, _) in slots {
                let d = overlapDuration(start: start, end: end, within: slotRange)
                if d > 0 {
                    totals[slot, default: 0] += d
                    counts[slot, default: 0] += 1
                }
            }
        }

        // Today's window
        let todayRange: ClosedRange<Date> = dayStart ... now

        // Completed feeds — use segments when present
        for e in feeds where e.endTime != nil {
            if !e.breastUnits.isEmpty {
                for u in e.breastUnits {
                    if let (s, t) = clipInterval(start: u.startTime, end: u.endTime, to: todayRange) {
                        addInterval(s, t)
                    }
                }
            } else if let (s, t) = clip(entry: e, to: todayRange) {
                addInterval(s, t)
            }
        }

        // Active feed: include finished units; for running segment fallback to envelope only when no units exist
        if let a = activeFeed, a.endTime == nil {
            if !a.breastUnits.isEmpty {
                for u in a.breastUnits {
                    if let (s, t) = clipInterval(start: u.startTime, end: u.endTime, to: todayRange) {
                        addInterval(s, t)
                    }
                }
            } else if let (s, t) = clipActive(entry: a, to: todayRange, now: now) {
                addInterval(s, t)
            }
        }

        return [
            TimeOfDayBucket(id: .morning,   label: NSLocalizedString("Morning", comment: ""),   total: totals[.morning] ?? 0,   sessionCount: counts[.morning] ?? 0),
            TimeOfDayBucket(id: .afternoon, label: NSLocalizedString("Afternoon", comment: ""), total: totals[.afternoon] ?? 0, sessionCount: counts[.afternoon] ?? 0),
            TimeOfDayBucket(id: .evening,   label: NSLocalizedString("Evening", comment: ""),   total: totals[.evening] ?? 0,   sessionCount: counts[.evening] ?? 0),
            TimeOfDayBucket(id: .night,     label: NSLocalizedString("Night", comment: ""),     total: totals[.night] ?? 0,     sessionCount: counts[.night] ?? 0),
        ]
    }

    public func pacingComparisonLastDays(
        feeds: [FeedingLogEntry],
        activeFeed: FeedingLogEntry?,
        days: Int = 7,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PacingComparison {
        let dayStart = calendar.startOfDay(for: now)
        let secondsSinceStart = now.timeIntervalSince(dayStart)

        // Today cumulative
        let todaySummary = timeSpentFeedingToday(feeds: feeds, activeFeed: activeFeed, now: now, calendar: calendar)
        let cumulativeToday = todaySummary.total

        // For each previous day, compute cumulative up to same offset
        var totals: [TimeInterval] = []
        totals.reserveCapacity(days)

        for i in 1...max(1, days) {
            guard let prevStart = calendar.date(byAdding: .day, value: -i, to: dayStart) else { continue }
            let prevCutoff = prevStart.addingTimeInterval(secondsSinceStart)

            let window: ClosedRange<Date> = prevStart ... prevCutoff

            var total: TimeInterval = 0
            // Completed feeds overlapping window (segment-aware when units exist)
            for e in feeds where e.endTime != nil {
                if !e.breastUnits.isEmpty {
                    for u in e.breastUnits {
                        total += overlapDuration(start: u.startTime, end: u.endTime, within: window)
                    }
                } else {
                    total += overlapDuration(entry: e, within: window)
                }
            }
            totals.append(total)
        }

        // Use available days (some may be zero naturally)
        let sampleDays = totals.count
        let mean = totals.isEmpty ? 0 : totals.reduce(0, +) / Double(totals.count)
        let delta = cumulativeToday - mean
        let pct = (mean > 0) ? (delta / mean) * 100.0 : 0

        return PacingComparison(
            cumulativeToday: cumulativeToday,
            historicalMean: mean,
            delta: delta,
            percent: pct,
            sampleDays: sampleDays
        )
    }

    // MARK: - Private helpers for clipping/overlap
    private func overlapDuration(entry: FeedingLogEntry, within range: ClosedRange<Date>) -> TimeInterval {
        guard let end = entry.endTime else { return 0 }
        return overlapDuration(start: entry.startTime, end: end, within: range)
    }

    private func overlapDurationForActive(entry: FeedingLogEntry, within range: ClosedRange<Date>, now: Date) -> TimeInterval {
        guard entry.endTime == nil else { return 0 }
        let start = max(entry.startTime, range.lowerBound)
        let end = min(now, range.upperBound)
        return max(0, end.timeIntervalSince(start))
    }

    private func overlapDuration(start: Date, end: Date, within range: ClosedRange<Date>) -> TimeInterval {
        let s = max(start, range.lowerBound)
        let e = min(end, range.upperBound)
        return max(0, e.timeIntervalSince(s))
    }

    private func clip(entry: FeedingLogEntry, to range: ClosedRange<Date>) -> (Date, Date)? {
        guard let end = entry.endTime else { return nil }
        let s = max(entry.startTime, range.lowerBound)
        let e = min(end, range.upperBound)
        return (e > s) ? (s, e) : nil
    }

    private func clipActive(entry: FeedingLogEntry, to range: ClosedRange<Date>, now: Date) -> (Date, Date)? {
        guard entry.endTime == nil else { return nil }
        let s = max(entry.startTime, range.lowerBound)
        let e = min(now, range.upperBound)
        return (e > s) ? (s, e) : nil
    }

    private func clipInterval(start: Date, end: Date, to range: ClosedRange<Date>) -> (Date, Date)? {
        let s = max(start, range.lowerBound)
        let e = min(end, range.upperBound)
        return (e > s) ? (s, e) : nil
    }
}
