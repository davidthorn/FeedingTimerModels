//
//  MonthlyDurationPoint.swift
//  FeedingTimer
//

import Foundation

public struct MonthlyDurationPoint: Identifiable, Sendable, Equatable {
    public let id: Date          // startOfMonth
    public let monthStart: Date  // startOfMonth
    public let total: TimeInterval
    public init(id: Date, monthStart: Date, total: TimeInterval) {
        self.id = id
        self.monthStart = monthStart
        self.total = total
    }
}

