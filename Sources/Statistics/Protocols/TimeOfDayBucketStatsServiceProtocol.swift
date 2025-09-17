//
//  TimeOfDayBucketStatsServiceProtocol.swift
//  FeedingTimer
//
//  Created by David Thorn on 17.09.25.
//

import Foundation
import FeedingTimerModels

public protocol TimeOfDayBucketStatsServiceProtocol {
    /// Computes average durations overall and per time-of-day bucket for a given window.
    /// - Parameters:
    ///   - feeds: All feed entries; only completed feeds are considered.
    ///   - window: Time window (days or hours) resolved via WindowingService.
    ///   - outlierPolicy: Whether to exclude IQR outliers when averaging.
    ///   - scenario: Scenario filter (all/day/night) applied before bucketing.
    ///   - now: Reference time for windowing.
    ///   - calendar: Calendar used for day boundaries and time-of-day slots.
    /// - Returns: Overall average duration and per-slot buckets.
    /// Protocol conformance: averages and time-of-day buckets over a window.
    func averageDurationTimeOfDayBuckets(
        feeds: [FeedingLogEntry],
        window: TimeWindow,
        outlierPolicy: OutlierPolicy,
        scenario: AverageDurationScenario,
        now: Date,
        calendar: Calendar
    ) -> (overall: TimeInterval, groups: [TimeOfDayBucket])
}
