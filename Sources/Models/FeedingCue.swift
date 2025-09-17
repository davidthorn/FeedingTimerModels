//
//  FeedingCue.swift
//  Feeding Log
//
//  Created by David Thorn on 23.07.25.
//

import Foundation

public enum FeedingCue: String, CaseIterable, Identifiable, Codable {
    case rooting = "Rooting"
    case suckingFists = "Sucking fists"
    case crying = "Crying"
    case headTurning = "Head turning"
    case handToMouth = "Hand to mouth"

    public var displayName: String { rawValue }
    public var id: String { rawValue }
}
