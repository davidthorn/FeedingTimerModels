//
//  OldFeedingLogEntry.swift
//  Feeding Log
//
//  Created by David Thorn on 24.07.25.
//

import Foundation

public struct OldFeedingLogEntry: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var startTime: Date
    public var endTime: Date?
    public var cues: Set<FeedingCue>
    public var breast: Breast
    public let createdAt: Date
    public var lastUpdatedAt: Date
    public init(
        id: UUID,
        startTime: Date,
        endTime: Date? = nil,
        cues: Set<FeedingCue>,
        breast: Breast,
        createdAt: Date,
        lastUpdatedAt: Date
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.cues = cues
        self.breast = breast
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
}

public extension OldFeedingLogEntry {
    var toFeedingLogEntry: FeedingLogEntry {
        .init(
            id: id,
            startTime: startTime,
            endTime: endTime,
            cues: cues,
            breast: breast,
            createdAt: startTime,
            lastUpdatedAt: endTime ?? startTime
        )
    }
}

public extension Array where Element == OldFeedingLogEntry {
    var toFeedingLogEntries: [FeedingLogEntry] {
        self.map { old in
                .init(id: old.id, startTime: old.startTime, endTime: old.endTime, cues: old.cues,breast: old.breast, createdAt: old.createdAt, lastUpdatedAt: old.lastUpdatedAt)
        }
    }
}
