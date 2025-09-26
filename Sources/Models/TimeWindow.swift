//
//  TimeWindow.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 23.08.25.
//

import Foundation

/// Unified time window representation for stats queries.
/// - Note: `.days(_:)` uses civil-day boundaries from the provided `calendar`.
///         `.hours(_:)` uses a rolling window ending at `now`.
public enum TimeWindow: Equatable, Sendable {
    /// A window spanning the last `n` civil days including today.
    case days(Int)
    /// A rolling window of the last `n` hours ending at `now`.
    case hours(Int)
}
