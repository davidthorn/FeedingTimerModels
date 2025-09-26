//
//  DataExportPresetRange.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 22.09.25.
//

import Foundation

public enum DataExportPresetRange: String, CaseIterable, Identifiable, Codable, Sendable {
    case last24Hours
    case last3Days
    case last7Days
    case last30Days
    case all
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .all: return "All"
        case .last24Hours: return "Past 24 Hours"
        case .last3Days:   return "Past 3 Days"
        case .last7Days:   return "Past 7 Days"
        case .last30Days:  return "Past 30 Days"
        }
    }
}
