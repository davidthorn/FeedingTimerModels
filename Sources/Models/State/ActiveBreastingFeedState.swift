//
//  ActiveBreastingFeedState.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 29.09.25.
//

import Foundation

public struct ActiveBreastingFeedState: Codable, Sendable {
    
    public struct BreastInfo: Codable, Sendable {
        public let last: Breast?
        public let current: Breast
        public init(last: Breast?, current: Breast) {
            self.last = last
            self.current = current
        }
    }
    
    public let state: BreastFeedingState
    public let breastInfo: BreastInfo
    public let history: FeedHistory?
    
    // if ready then this and a last feed, this is the time since a feed
    // if ready and no last feed, this is just a date
    // if start feed we use now from the nowProvider to update lastUpdatedAt and use now as the startTime
    // if pause feed, we use now from the nowProvider to update lastUpdatedAt and use now as the endTime for a breastUnit
    // if resume feed, we use now from the nowProvider to update lastUpdatedAt and use now as the startTime for a future breastUnit
    // if stop feed, we use the lastUpdatedAt for the startTime of a breastUnit and now from the nowProvider to update lastUpdatedAt and use now as the endTime for breastUnit
    public let lastUpdatedAt: Date
    
    private init(
        state: BreastFeedingState = .feeding,
        breastInfo: BreastInfo,
        history: FeedHistory?,
        lastUpdatedAt: Date
    ) {
        self.state = state
        self.breastInfo = breastInfo
        self.history = history
        self.lastUpdatedAt = lastUpdatedAt
        if state != .ready {
            assert(history != nil)
        }
    }
    
    public static func ready(
        breastInfo: BreastInfo,
        history: FeedHistory,
        lastUpdatedAt: Date
    ) -> ActiveBreastingFeedState {
        .init(state: .ready, breastInfo: breastInfo, history: history, lastUpdatedAt: lastUpdatedAt)
    }
    
    public static func feeding(
        breastInfo: BreastInfo,
        history: FeedHistory,
        lastUpdatedAt: Date
    ) -> ActiveBreastingFeedState {
        .init(state: .feeding, breastInfo: breastInfo, history: history, lastUpdatedAt: lastUpdatedAt)
    }
    
    public static func paused(
        breastInfo: BreastInfo,
        history: FeedHistory,
        lastUpdatedAt: Date
    ) -> ActiveBreastingFeedState {
        .init(state: .paused, breastInfo: breastInfo, history: history, lastUpdatedAt: lastUpdatedAt)
    }
    
    public static func completed(
        breastInfo: BreastInfo,
        history: FeedHistory,
        lastUpdatedAt: Date
    ) -> ActiveBreastingFeedState {
        .init(state: .completed, breastInfo: breastInfo, history: history, lastUpdatedAt: lastUpdatedAt)
    }
}
