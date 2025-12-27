//
//  PeerSyncConfiguration.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 26.09.25.
//  Created by David Thorn on 27.12.25.
//

import Foundation

public struct PeerSyncConfiguration: Equatable, Codable, Sendable {
    public var isEnabled: Bool
    public var canSend: Bool
    public var canReceive: Bool
    public var canCreate: Bool
    public var canUpdate: Bool
    public var canDelete: Bool

    public init(
        isEnabled: Bool = false,
        canSend: Bool = true,
        canReceive: Bool = true,
        canCreate: Bool = true,
        canUpdate: Bool = true,
        canDelete: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.canSend = canSend
        self.canReceive = canReceive
        self.canCreate = canCreate
        self.canUpdate = canUpdate
        self.canDelete = canDelete
    }

    public var allowsMutations: Bool { canCreate || canUpdate || canDelete }
}
