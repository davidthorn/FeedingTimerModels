//
//  GroupedAverage.swift
//  FeedingTimer
//
//  Created by David Thorn on 14.08.25.
//

import Foundation

public struct GroupedAverage: Hashable, Sendable {
    public let label: String
    public let average: TimeInterval
    public let count: Int
    public init(label: String, average: TimeInterval, count: Int) {
        self.label = label
        self.average = average
        self.count = count
    }
}


