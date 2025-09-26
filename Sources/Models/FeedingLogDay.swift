//
//  FeedingLogDay.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 06.08.25.
//

import Foundation

public struct FeedingLogDay: Hashable, Sendable {
    public let day: Date
    public init(day: Date) {
        self.day = day
    }
}
