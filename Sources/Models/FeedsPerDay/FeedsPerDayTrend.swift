//
//  FeedsPerDayTrend.swift
//  FeedingTimer
//

import Foundation

public struct FeedsPerDayTrend: Sendable, Equatable {
    public let currentAvg: Double
    public let previousAvg: Double
    public var delta: Double { currentAvg - previousAvg }
    public var percent: Double {
        guard previousAvg > 0 else { return 0 }
        return (delta / previousAvg) * 100
    }
    
    public init(currentAvg: Double, previousAvg: Double) {
        self.currentAvg = currentAvg
        self.previousAvg = previousAvg
    }
}

