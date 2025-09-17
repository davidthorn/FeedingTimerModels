//
//  AverageIntervalGrouping.swift
//  FeedingTimer
//
//  Created by David Thorn on 15.08.25.
//

import Foundation

public enum AverageIntervalGrouping: String, CaseIterable, Codable, Sendable {
    case none, breast, timeOfDay
}
