//
//  FeedHistory.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 29.09.25.
//

import Foundation

public struct FeedHistory: Codable, Sendable {
    public let current: FeedingLogEntry
    public let last: FeedingLogEntry?

    public init(
        current: FeedingLogEntry,
        last: FeedingLogEntry?
    ) {
        self.current = current
        self.last = last
    }
}
