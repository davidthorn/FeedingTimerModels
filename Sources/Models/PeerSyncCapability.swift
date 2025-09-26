//
//  PeerSyncCapability.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 26.09.25.
//

import Foundation

public enum PeerSyncCapability: String, Codable, CaseIterable, Sendable {
    case send
    case receive
    case create
    case update
    case delete
}
