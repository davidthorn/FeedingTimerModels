//
//  StatsEnvironment.swift
//  FeedingTimer
//
//  Scaffolding for decomposing FeedingStatsService into focused sub-services.
//  This file introduces a shared environment (clock + calendar) that sub-services
//  can depend on for deterministic time/windows. Not yet used by the facade.
//

import Foundation
import Models

public struct StatsEnvironment: Sendable {
    public let nowProvider: NowProvider
    public let calendar: Calendar
    public init(nowProvider: NowProvider = SystemNowProvider(), calendar: Calendar = .current) {
        self.nowProvider = nowProvider
        self.calendar = calendar
    }
}

