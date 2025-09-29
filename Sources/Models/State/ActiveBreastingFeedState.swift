//
//  ActiveBreastingFeedState.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 29.09.25.
//

import Foundation

public struct ActiveBreastingFeedState {
    public struct BreastInfo {
        let last: Breast?
        let current: Breast
    }
    public let state: BreastFeedingState
    public let breastInfo: BreastInfo

    public let last: FeedingLogEntry?
    public let current: FeedingLogEntry
    public let startTime: Date
    public let lastUpdated: Date

    
    public init(
        state: BreastFeedingState = .feeding,
        current: FeedingLogEntry,
        last: FeedingLogEntry?,
        breastInfo: BreastInfo,
        startTime: Date,
        lastUpdated: Date
    ) {
        self.state = state
        self.current = current
        self.last = last
        self.breastInfo = breastInfo
        self.startTime = startTime
        self.lastUpdated = lastUpdated
    }
}
