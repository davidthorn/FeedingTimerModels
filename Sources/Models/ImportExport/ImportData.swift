//
//  ImportData.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 22.09.25.
//

import Foundation

public struct ImportData: Codable, Sendable {
    public let feeds: [FeedingLogEntry]
    public let transferType: DataExportPresetRange
    public init(feeds: [FeedingLogEntry], transferType: DataExportPresetRange) {
        self.feeds = feeds
        self.transferType = transferType
    }
}
