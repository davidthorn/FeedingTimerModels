//
//  ActiveFeedSnapshot.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 26.09.25.
//

import Foundation

public struct ActiveFeedSnapshot: Codable, Equatable {
    public let deviceID: String
    public let feed: FeedingLogEntry
    public let activeSegmentStart: Date?
    public let activeSegmentBreast: Breast?
    public let lastUpdatedAt: Date
    public init(deviceID: String, feed: FeedingLogEntry, activeSegmentStart: Date?, activeSegmentBreast: Breast?, lastUpdatedAt: Date) {
        self.deviceID = deviceID
        self.feed = feed
        self.activeSegmentStart = activeSegmentStart
        self.activeSegmentBreast = activeSegmentBreast
        self.lastUpdatedAt = lastUpdatedAt
    }
}
