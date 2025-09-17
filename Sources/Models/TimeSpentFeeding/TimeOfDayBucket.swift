//
//  TimeOfDayBucket.swift
//  FeedingTimer
//
//  Created by David Thorn on 14.08.25.
//

import Foundation

public struct TimeOfDayBucket: Identifiable, Sendable, Equatable {
    public enum Slot: String, CaseIterable, Sendable {
        case night, morning, afternoon, evening
    }
    public let id: Slot
    public let label: String
    public let total: TimeInterval
    public let sessionCount: Int
    
    public init(id: Slot, label: String, total: TimeInterval, sessionCount: Int) {
        self.id = id
        self.label = label
        self.total = total
        self.sessionCount = sessionCount
    }
}


