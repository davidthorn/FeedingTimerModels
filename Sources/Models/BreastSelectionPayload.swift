//
//  BreastSelectionPayload.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 26.09.25.
//

import Foundation

public struct BreastSelectionPayload: Codable, Equatable, Sendable {
    public let deviceID: String
    public let breast: Breast
    public let updatedAt: Date
    public init(deviceID: String, breast: Breast, updatedAt: Date) {
        self.deviceID = deviceID
        self.breast = breast
        self.updatedAt = updatedAt
    }
}
