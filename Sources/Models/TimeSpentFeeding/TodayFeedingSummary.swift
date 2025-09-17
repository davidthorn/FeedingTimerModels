//
//  TodayFeedingSummary.swift
//  FeedingTimer
//
//  Created by David Thorn on 14.08.25.
//

import Foundation

public struct TodayFeedingSummary: Sendable, Equatable {
    public let total: TimeInterval
    public let leftTotal: TimeInterval
    public let rightTotal: TimeInterval
    public let completedCount: Int
    public let activeElapsed: TimeInterval
    public let hasActive: Bool
    public init(
        total: TimeInterval,
        leftTotal: TimeInterval,
        rightTotal: TimeInterval,
        completedCount: Int,
        activeElapsed: TimeInterval,
        hasActive: Bool
    ) {
        self.total = total
        self.leftTotal = leftTotal
        self.rightTotal = rightTotal
        self.completedCount = completedCount
        self.activeElapsed = activeElapsed
        self.hasActive = hasActive
    }
}
