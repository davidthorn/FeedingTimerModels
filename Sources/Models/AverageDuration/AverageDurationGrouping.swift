//
//  AverageDurationGrouping.swift
//  FeedingTimer
//
//  Created by David Thorn on 14.08.25.
//

import Foundation

public enum AverageDurationGrouping: String, CaseIterable, Codable, Sendable {
    case none, breast, timeOfDay
}
