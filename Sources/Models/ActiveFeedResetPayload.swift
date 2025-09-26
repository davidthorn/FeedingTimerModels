//
//  ActiveFeedResetPayload.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 26.09.25.
//

import Foundation

public struct ActiveFeedResetPayload: Codable, Equatable, Sendable {
    public let deviceID: String
    public let lastFeed: FeedingLogEntry?
    public init(deviceID: String, lastFeed: FeedingLogEntry?) {
        self.deviceID = deviceID
        self.lastFeed = lastFeed
    }
}
