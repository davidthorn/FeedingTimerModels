//
//  DurationTrend.swift
//  FeedingTimer
//
//  Created by David Thorn on 14.08.25.
//

import Foundation

public struct DurationTrend: Sendable, Equatable {
    public let currentAvg: TimeInterval
    public let previousAvg: TimeInterval
    public var delta: TimeInterval { currentAvg - previousAvg }
    public var percent: Double {
        guard previousAvg > 0 else { return 0 }
        return (delta / previousAvg) * 100
    }
    
    public init(currentAvg: TimeInterval, previousAvg: TimeInterval) {
        self.currentAvg = currentAvg
        self.previousAvg = previousAvg
    }
}
