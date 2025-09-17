//
//  AverageDurationBookmark.swift
//  FeedingTimer
//
//  Created by David Thorn on 14.08.25.
//

import Foundation

public struct AverageDurationBookmark: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let config: AverageDurationConfig
    public let scenario: AverageDurationScenario

    public init(id: UUID = .init(), name: String, config: AverageDurationConfig, scenario: AverageDurationScenario) {
        self.id = id; self.name = name; self.config = config; self.scenario = scenario
    }
}
