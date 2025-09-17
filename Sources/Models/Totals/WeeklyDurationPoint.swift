//
//  WeeklyDurationPoint.swift
//  FeedingTimer
//

import Foundation

public struct WeeklyDurationPoint: Identifiable, Sendable, Equatable {
    public let id: Date          // startOfWeek
    public let weekStart: Date   // startOfWeek
    public let total: TimeInterval
    public init(id: Date, weekStart: Date, total: TimeInterval) {
        self.id = id
        self.weekStart = weekStart
        self.total = total
    }
}

