//
//  WindowTrend.swift
//  FeedingTimer
//

import Foundation

public struct WindowTrend: Sendable, Equatable {
    public let currentAvg: TimeInterval
    public let previousAvg: TimeInterval
    public var delta: TimeInterval { currentAvg - previousAvg }
    public var percent: Double {
        guard previousAvg > 0 else { return 0 }
        return (delta / previousAvg) * 100.0
    }
    public init(currentAvg: TimeInterval, previousAvg: TimeInterval) {
        self.currentAvg = currentAvg
        self.previousAvg = previousAvg
    }
}

