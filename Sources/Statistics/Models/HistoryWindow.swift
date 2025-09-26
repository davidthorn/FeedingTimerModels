//
//  HistoryWindow.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 24.09.25.
//

import Foundation

public enum HistoryWindow: Int, CaseIterable, Hashable, Identifiable, Sendable {
    private static let key = "TimeSpentCompact.daysBack"
    
    case last3d = 3
    case last7d = 7
    case last14d = 14
    case last21d = 21

    public var id: Int { rawValue }

    public static func load() -> HistoryWindow {
        let d = UserDefaults.standard
        let v = d.integer(forKey: key)
        return HistoryWindow(rawValue: v) ?? .last7d
    }
    
    public static func persist(_ v: HistoryWindow) {
        UserDefaults.standard.set(v.rawValue, forKey: key)
    }
}
