//
//  FeedsPerDaySummary.swift
//  FeedingTimer
//

import Foundation

public struct FeedsPerDaySummary: Sendable, Equatable {
    public let average: Double         // mean over the window
    public let median: Double          // median over the window
    public let min: Int
    public let max: Int
    public let samples: Int            // number of days in window
    public init(average: Double, median: Double, min: Int, max: Int, samples: Int) {
        self.average = average
        self.median = median
        self.min = min
        self.max = max
        self.samples = samples
    }
}

