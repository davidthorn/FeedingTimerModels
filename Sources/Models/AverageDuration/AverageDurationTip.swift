//
//  AverageDurationTip.swift
//  FeedingTimer
//
//  Created by David Thorn on 14.08.25.
//

import Foundation

public struct AverageDurationTip: Identifiable, Equatable, Sendable {
    public let id: String
    public let text: String
    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}
