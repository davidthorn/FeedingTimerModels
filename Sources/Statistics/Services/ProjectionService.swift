//
//  ProjectionService.swift
//  FeedingTimer
//
//  Scaffolding for projections such as next-feed estimate based on recent stats.
//

import Foundation
import FeedingTimerModels

public struct ProjectionService {
    public let env: StatsEnvironment

    public init(env: StatsEnvironment = .init()) {
        self.env = env
    }

    // Mirrors FeedingStatsService.estimateNextFeed(from:now:)
    public func estimateNextFeed(
        from feeds: [FeedingLogEntry],
        now: Date = Date()
    ) -> FeedingStatsService.NextFeedEstimate? {
        // Use the last completed feed's end time, then add the average interval
        guard let last = feeds
            .filter({ $0.endTime != nil })
            .max(by: { $0.startTime < $1.startTime })
        else {
            return nil
        }

        // Preserve legacy behavior (no age-aware cap when not provided)
        let stats = FeedingStatsService().computeStats(from: feeds)
        guard stats.averageInterval > 0 else { return nil }

        return FeedingStatsService.NextFeedEstimate(
            nextFeedTime: last.startTime.addingTimeInterval(stats.averageInterval),
            interval: stats.averageInterval
        )
    }

    // Mirrors FeedingStatsService.estimateNextFeed(from:ageDays:now:)
    public func estimateNextFeed(
        from feeds: [FeedingLogEntry],
        ageDays: Int?,
        now: Date = Date()
    ) -> FeedingStatsService.NextFeedEstimate? {
        guard let last = feeds
            .filter({ $0.endTime != nil })
            .max(by: { $0.startTime < $1.startTime })
        else {
            return nil
        }

        let stats = FeedingStatsService().computeStats(from: feeds, ageDays: ageDays)
        guard stats.averageInterval > 0 else { return nil }

        return FeedingStatsService.NextFeedEstimate(
            nextFeedTime: last.startTime.addingTimeInterval(stats.averageInterval),
            interval: stats.averageInterval
        )
    }
}
