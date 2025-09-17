//
//  BreastUnit.swift
//  FeedingTimer
//
//  Created by David Thorn on 04.08.25.
//

import Foundation

public struct BreastUnit: Codable, Hashable {
    public let breast: Breast
    public let duration: TimeInterval
    public let startTime: Date
    public let endTime: Date
    
    public init(breast: Breast, duration: TimeInterval, startTime: Date, endTime: Date) {
        self.breast = breast
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
    }
}
