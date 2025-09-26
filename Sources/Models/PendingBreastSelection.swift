//
//  PendingBreastSelection.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 26.09.25.
//

import Foundation

public struct PendingBreastSelection: Equatable, Codable {
    public let breast: Breast
    public let updatedAt: Date
    public init(breast: Breast, updatedAt: Date) {
        self.breast = breast
        self.updatedAt = updatedAt
    }
}
