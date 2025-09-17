//
//  TimeOfDayBucketIntervalStatsServiceProtocol.swift
//  FeedingTimer
//
//  Created by David Thorn on 17.09.25.
//

import Foundation
import Models

protocol TimeOfDayBucketIntervalStatsServiceProtocol {
    /// Computes average start-to-start intervals and time-of-day buckets for a window.
    /// - Parameters:
    ///   - feeds: All feed entries; only completed feeds are considered.
    ///   - daysBack: Number of civil days back from `now` to include when `rollingHoursBack` is nil.
    ///   - scenario: Scenario filter (all/day/night) applied before bucketing.
    ///   - excludeOutliers: Whether to exclude IQR outliers when averaging.
    ///   - rollingHoursBack: Optional rolling window in hours; overrides `daysBack` if set.
    ///   - now: Reference time for windowing.
    ///   - calendar: Calendar used for day boundaries and time-of-day slots.
    /// - Returns: Overall average interval and per-time-of-day buckets (sessionCount = samples used).
    func averageIntervalsTimeOfBuckets(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        scenario: AverageDurationScenario,
        excludeOutliers: Bool,
        now: Date,
        calendar: Calendar
    ) -> (overall: TimeInterval, groups: [TimeOfDayBucket])
}
