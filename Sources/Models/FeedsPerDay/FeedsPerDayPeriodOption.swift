//
//  FeedsPerDayPeriodOption.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 24.09.25.
//

import Foundation

public enum FeedsPerDayPeriodOption: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    
    private static let key = "FeedsPerDay.period"
    
    case last24h
    case last3d
    case last7d
    case last14d
    case last21d

    public var id: String { rawValue }
    
    public var window: (daysBack: Int, rollingHoursBack: Int?) {
        switch self {
        case .last24h:  return (1, 24)
        case .last3d:   return (3, nil)
        case .last7d:   return (7, nil)
        case .last14d:  return (14, nil)
        case .last21d:  return (21, nil)
        }
    }
    
    public static func load() -> FeedsPerDayPeriodOption {
        if let raw = UserDefaults.standard.string(forKey: key), let p = FeedsPerDayPeriodOption(rawValue: raw) { return p }
        return .last7d
    }
    
    public static func persist(_ p: FeedsPerDayPeriodOption) { UserDefaults.standard.set(p.rawValue, forKey: key) }
}
