//
//  FeedingStats.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 06.08.25.
//

import Foundation

public struct FeedingStats: Codable, Equatable, Hashable, Sendable {
    public let totalDuration: TimeInterval
    public let averageDuration: TimeInterval
    public let averageInterval: TimeInterval
    public let intervalCount: Int
    public let outlierCount: Int
    public init(
        totalDuration: TimeInterval,
        averageDuration: TimeInterval,
        averageInterval: TimeInterval,
        intervalCount: Int,
        outlierCount: Int
    ) {
        self.totalDuration = totalDuration
        self.averageDuration = averageDuration
        self.averageInterval = averageInterval
        self.intervalCount = intervalCount
        self.outlierCount = outlierCount
    }
}
