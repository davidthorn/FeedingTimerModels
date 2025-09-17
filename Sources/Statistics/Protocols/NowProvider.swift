//
//  NowProvider.swift
//  FeedingTimer
//
//  Created by David Thorn on 17.09.25.
//

import Foundation

public protocol NowProvider {
    var now: Date { get }
}
