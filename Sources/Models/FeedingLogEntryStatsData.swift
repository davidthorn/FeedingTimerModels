//
//  FeedingLogEntryStatsData.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 24.08.25.
//

import Foundation

public struct FeedingLogEntryStatsData: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let entry: FeedingLogEntry
    public let type: FeedingEntryType
    public var id: UUID {
        entry.id
    }
    
    public init(entry: FeedingLogEntry, type: FeedingEntryType) {
        self.entry = entry
        self.type = type
    }
}
