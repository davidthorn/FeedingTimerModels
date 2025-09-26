//
//  AverageDurationConfig.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 14.08.25.
//

import Foundation

public struct AverageDurationConfig: Codable, Equatable, Sendable {
    public var period: AverageDurationPeriod
    public var customDays: Int      // used when period == .custom (min 1)
    public var grouping: AverageDurationGrouping
    public var excludeOutliers: Bool
    public init(period: AverageDurationPeriod = .last7d,
                customDays: Int = 7,
                grouping: AverageDurationGrouping = .none,
                excludeOutliers: Bool = true) {
        self.period = period
        self.customDays = max(1, customDays)
        self.grouping = grouping
        self.excludeOutliers = excludeOutliers
    }
}
