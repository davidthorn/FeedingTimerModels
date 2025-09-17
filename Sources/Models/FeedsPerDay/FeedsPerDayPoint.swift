//
//  FeedsPerDayPoint.swift
//  FeedingTimer
//

import Foundation

public struct FeedsPerDayPoint: Identifiable, Sendable, Equatable {
    public let id: Date            // startOfDay (calendar)
    public let date: Date          // startOfDay
    public let count: Int
    public init(id: Date, date: Date, count: Int) {
        self.id = id
        self.date = date
        self.count = count
    }
}

