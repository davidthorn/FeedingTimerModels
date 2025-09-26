//
//  ActiveFeedState.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 26.09.25.
//

import Foundation

public struct ActiveFeedState: Codable, Equatable {
    public var feed: FeedingLogEntry
    public var activeSegmentStart: Date?
    public var activeSegmentBreast: Breast?
    public var lastUpdatedAt: Date
    
    public init(feed: FeedingLogEntry, activeSegmentStart: Date? = nil, activeSegmentBreast: Breast? = nil, lastUpdatedAt: Date) {
        self.feed = feed
        self.activeSegmentStart = activeSegmentStart
        self.activeSegmentBreast = activeSegmentBreast
        self.lastUpdatedAt = lastUpdatedAt
    }
}
