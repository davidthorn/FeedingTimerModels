//
//  DailyTotalTrend.swift
//  FeedingTimer
//

import Foundation

public struct DailyTotalTrend: Sendable, Equatable {
    public let currentAvgPerDay: TimeInterval   // avg per day in current window
    public let previousAvgPerDay: TimeInterval  // avg per day in previous window
    public var delta: TimeInterval { currentAvgPerDay - previousAvgPerDay }
    public var percent: Double {
        guard previousAvgPerDay > 0 else { return 0 }
        return (delta / previousAvgPerDay) * 100.0
    }
    public init(currentAvgPerDay: TimeInterval, previousAvgPerDay: TimeInterval) {
        self.currentAvgPerDay = currentAvgPerDay
        self.previousAvgPerDay = previousAvgPerDay
    }
}

