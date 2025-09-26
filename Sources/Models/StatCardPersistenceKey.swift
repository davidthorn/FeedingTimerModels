//
//  StatCardPersistenceKey.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 11.08.25.
//

// MARK: - StatCardPersistenceKey

/// Centralised storage keys for all StatCards in the app.
/// Used to persist expand/collapse state via UserDefaults.
public enum StatCardPersistenceKey: String, Sendable {
    case averageDuration       = "statcard.averageDuration"
    case averageInterval       = "statcard.averageInterval"
    case totalDurationToday    = "statcard.totalDurationToday"
    case nextExpectedFeedMain  = "statcard.nextExpectedFeed.main"
    case nextExpectedFeed      = "statcard.nextExpectedFeed"
    case feedsPerDay           = "statcard.feedsPerDay"
    case expectedWeightRange   = "statcard.expectedWeightRange"
    case growthTrend           = "statcard.growthTrend"
    case timeSpentFeedingToday = "statcard.timeSpentFeedingToday"
    case feedingTrend          = "statcard.feedingTrend"
    // Add more as needed...
}
