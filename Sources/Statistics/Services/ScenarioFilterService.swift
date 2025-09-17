//
//  ScenarioFilterService.swift
//  FeedingTimer
//
//  Scaffolding service for filtering feeds by scenario (All/Day/Night).
//  Current facade functions in FeedingStatsService remain the source of truth;
//  this service mirrors signatures for future extraction.
//

import Foundation
import FeedingTimerModels

public struct ScenarioFilterService {
    public let env: StatsEnvironment

    public init(env: StatsEnvironment = .init()) {
        self.env = env
    }

    public func filterByScenario(
        _ feeds: [FeedingLogEntry],
        scenario: AverageDurationScenario,
        calendar: Calendar
    ) -> [FeedingLogEntry] {
        switch scenario {
        case .all:
            return feeds
        case .day:
            return feeds.filter { (6...21).contains(calendar.component(.hour, from: $0.startTime)) }
        case .night:
            return feeds.filter { !(6...21).contains(calendar.component(.hour, from: $0.startTime)) }
        @unknown default:
            fatalError()
        }
    }
}
