//
//  AverageDurationPeriod.swift
//  FeedingTimer
//
//  Created by David Thorn on 14.08.25.
//

import Foundation

public enum AverageDurationPeriod: Int, CaseIterable, Codable, Sendable {
    case last24h = 1, last3d = 3, last7d = 7, last14d = 14, custom
}



