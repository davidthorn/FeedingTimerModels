//
//  DailyDurationPoint.swift
//  FeedingTimer
//

import Foundation

public struct DailyDurationPoint: Identifiable, Sendable, Equatable {
    public let id: Date          // startOfDay
    public let date: Date        // startOfDay
    public let total: TimeInterval
    public init(id: Date, date: Date, total: TimeInterval) {
        self.id = id
        self.date = date
        self.total = total
    }
}

