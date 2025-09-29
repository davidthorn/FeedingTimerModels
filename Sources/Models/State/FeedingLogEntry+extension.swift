//
//  Untitled.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 29.09.25.
//

import Foundation

public extension FeedingLogEntry {
    func pause(with state: ActiveBreastingFeedState, nowProvider: NowProvider) -> FeedingLogEntry {
        
        let now = nowProvider.now
        var units = breastUnits
        
        let newUnit = BreastUnit(
            breast: state.breastInfo.current,
            duration: now.timeIntervalSince(state.lastUpdated),
            startTime: state.startTime,
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
        let now = nowProvider.now
        var units = breastUnits
        
        let newUnit = BreastUnit(
            breast: state.breastInfo.current,
            duration: now.timeIntervalSince(state.startTime),
            startTime: state.startTime,
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
