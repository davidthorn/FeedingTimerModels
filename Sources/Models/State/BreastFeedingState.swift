//
//  BreastFeedingState.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 29.09.25.
//

import Foundation

public enum BreastFeedingState {
    case none
    case feeding
    case paused
    case completed
    
    public var isActive: Bool {
        [.feeding, .paused].contains(where: { $0 == self })
    }
}
