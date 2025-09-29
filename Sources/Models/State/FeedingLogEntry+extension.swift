//
//  Untitled.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 29.09.25.
//

import Foundation

public extension FeedingLogEntry {
    
    static func start(with breast: Breast, nowProvider: NowProvider) -> FeedingLogEntry {
        let now = nowProvider.now
        return .init(
            id: UUID(),
            startTime: now,
            cues: [],
            breast: breast,
            breastUnits: [
                
            ],
            createdAt: now,
            lastUpdatedAt: now
        )
    }
    
    func pause(with state: ActiveBreastingFeedState, nowProvider: NowProvider) -> FeedingLogEntry {
        guard let current = state.history?.current, current.id == id else {
            fatalError("There should be history pause a feed")
        }
        
        let now = nowProvider.now
        var units = breastUnits
        
        // This was set as the startTime when start was called
        let startTime = state.lastUpdatedAt
        
        let newUnit = BreastUnit(
            breast: state.breastInfo.current,
            duration: now.timeIntervalSince(startTime),
            startTime: startTime,
            endTime: now
        )
        
        units.append(newUnit)
        
        return .init(
            id: id,
            startTime: startTime,
            cues: cues,
            breast: breast,
            breastUnits: units,
            createdAt: createdAt,
            lastUpdatedAt: now
        )
    }
    
    func stop(with state: ActiveBreastingFeedState, nowProvider: NowProvider) -> FeedingLogEntry {
        guard let current = state.history?.current, current.id == id else {
            fatalError("There should be history pause a feed")
        }

        let now = nowProvider.now
        var units = breastUnits
        
        // This was set as the startTime when start was called
        let startTime = state.lastUpdatedAt
        
        let newUnit = BreastUnit(
            breast: state.breastInfo.current,
            duration: now.timeIntervalSince(startTime),
            startTime: startTime,
            endTime: now
        )
        
        units.append(newUnit)
        
        return .init(
            id: id,
            startTime: startTime,
            endTime: now,
            cues: cues,
            breast: breast,
            breastUnits: units,
            createdAt: createdAt,
            lastUpdatedAt: now
        )
    }
}
