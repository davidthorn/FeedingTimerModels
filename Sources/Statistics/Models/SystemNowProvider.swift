//
//  NowProvider.swift
//  FeedingTimer
//
//  Created by David Thorn on 17.09.25.
//

import Foundation
import Models

public struct SystemNowProvider: NowProvider {
    public var now: Date { Date() }
    public init() { }
}

