//
//  FeedTimerState.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 29.09.25.
//

import Foundation

public struct FeedTimerState: Codable, Sendable {
    public var canSwitchBetweenFeed: Bool
    public var lastBreast: Breast
    public var choosenBreast: Breast
    public var currentFeed: FeedingLogEntry?
    public var feedingState: FeedingState
    public var isVoiceOverRunning: Bool
    public var gapSinceLast: TimeInterval?
    public var isPaused: Bool
    
    public init(
        canSwitchBetweenFeed: Bool,
        lastBreast: Breast = .left,
        choosenBreast: Breast = .left,
        currentFeed: FeedingLogEntry? = nil,
        feedingState: FeedingState = .waiting,
        isVoiceOverRunning: Bool = false,
        gapSinceLast: TimeInterval? = nil,
        isPaused: Bool = false
    ) {
        self.canSwitchBetweenFeed = canSwitchBetweenFeed
        self.lastBreast = lastBreast
        self.choosenBreast = choosenBreast
        self.currentFeed = currentFeed
        self.feedingState = feedingState
        self.isVoiceOverRunning = isVoiceOverRunning
        self.gapSinceLast = gapSinceLast
        self.isPaused = isPaused
    }
    
    public var isFeeding: Bool { feedingState == .feeding }
    
    public var isFeedCompleted: Bool {
        if feedingState == .completed { return true }
        guard let feed = currentFeed else { return false }
        return feed.endTime != nil
    }
    
    public var switchLeftToRightBreastDisabled: Bool {
        if isFeeding && !isPaused {
            return true
        }
        
        if canSwitchBetweenFeed {
            if choosenBreast == .left {
                return false // not disabled
            }
            return true // is disabled
        }
        
        return choosenBreast == .left
    }
    
    public var switchRightToLeftBreastDisabled: Bool {
        // if isFeeding boths buttons should be disabled
        if isFeeding && !isPaused {
            return true
        }
        
        if canSwitchBetweenFeed {
            if choosenBreast == .right {
                return false // not disabled
            }
            return true // is disabled
        }
        
        return choosenBreast == .right
    }
    
    public func getMostRecentFeed(from feeds: [FeedingLogEntry]) -> FeedingLogEntry? {
        if let cf = currentFeed, cf.endTime != nil { return cf }
        return feeds
            .filter { $0.endTime != nil }
            .sorted { $0.startTime > $1.startTime }
            .first
    }
    
    // MARK: - Mutating Methods
    
    public mutating func handlePendingBreastSelection(_ selection: Breast?) {
        guard feedingState != .feeding else { return }
        guard let selection else { return }
        choosenBreast = selection
    }
    
    public mutating func recomputeGapSinceLast(feeds: [FeedingLogEntry]) {
        let completedFeeds = feeds
            .filter { $0.endTime != nil }
            .sorted { $0.startTime > $1.startTime }
        
        guard completedFeeds.count >= 2,
              let previousEnd = completedFeeds[1].endTime else {
            gapSinceLast = nil
            return
        }
        
        let current = completedFeeds[0]
        let gap = current.startTime.timeIntervalSince(previousEnd)
        gapSinceLast = max(0, gap)
    }
}
