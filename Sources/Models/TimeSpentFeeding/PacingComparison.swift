//
//  PacingComparison.swift
//  FeedingTimer
//
//  Created by David Thorn on 14.08.25.
//

import Foundation

public struct PacingComparison: Sendable, Equatable {
    public let cumulativeToday: TimeInterval
    public let historicalMean: TimeInterval
    public let delta: TimeInterval        // cumulativeToday - historicalMean
    public let percent: Double            // (delta / historicalMean) * 100, or 0 if mean == 0
    public let sampleDays: Int            // number of past days used in the mean
    public init(
        cumulativeToday: TimeInterval,
        historicalMean: TimeInterval,
        delta: TimeInterval,
        percent: Double,
        sampleDays: Int
    ) {
        self.cumulativeToday = cumulativeToday
        self.historicalMean = historicalMean
        self.delta = delta
        self.percent = percent
        self.sampleDays = sampleDays
    }
}
