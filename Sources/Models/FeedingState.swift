//
//  FeedingState.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 30.07.25.
//

import Foundation

public enum FeedingState: Sendable, Codable {
    case waiting
    case feeding
    case completed
}
