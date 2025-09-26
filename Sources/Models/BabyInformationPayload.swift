//
//  BabyInformationPayload.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 26.09.25.
//

import Foundation

public struct BabyInformationPayload: Codable, Equatable, Sendable {
    public let deviceID: String
    public let babyName: String
    public let dueDate: Date
    public let birthDate: Date
    public let birthWeight: Double
    public let birthHeight: Double
    public let updatedAt: Date
    public init(deviceID: String, babyName: String, dueDate: Date, birthDate: Date, birthWeight: Double, birthHeight: Double, updatedAt: Date) {
        self.deviceID = deviceID
        self.babyName = babyName
        self.dueDate = dueDate
        self.birthDate = birthDate
        self.birthWeight = birthWeight
        self.birthHeight = birthHeight
        self.updatedAt = updatedAt
    }
}
