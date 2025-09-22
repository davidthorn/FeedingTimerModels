//
//  ExportServiceProtocol.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 22.09.25.
//

import Foundation
import Combine

@MainActor
public protocol ExportServiceProtocol: AnyObject {
    var feedsPublisher: Published<[FeedingLogEntry]>.Publisher { get }
    var feeds: [FeedingLogEntry] { get }
    var totalCount: Int { get }
    
    func replaceAllData(with newFeeds: [FeedingLogEntry]) async throws
    func updateFeeds(_ newFeeds: [FeedingLogEntry]) async
}
