//
//  DurationMilestone.swift
//  FeedingTimer
//
//  Created by David Thorn on 14.08.25.
//

import Foundation

public struct DurationMilestone: Sendable, Equatable {
    public let title: String  // e.g., "Longest feed"
    public let value: TimeInterval
    public let date: Date
    public let breast: Breast
    public init(title: String, value: TimeInterval, date: Date, breast: Breast) {
        self.title = title
        self.value = value
        self.date = date
        self.breast = breast
    }
}
