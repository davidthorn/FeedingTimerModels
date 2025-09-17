//
//  DisplayLinkProxy.swift
//  FeedingTimer
//
//  Created by David Thorn on 11.08.25.
//

import Foundation

// MARK: - CADisplayLink Proxy (for Swift selector)
@MainActor
final public class DisplayLinkProxy: NSObject {
    private let tick: () -> Void
    public init(_ tick: @escaping () -> Void) { self.tick = tick }
    @objc public func step() { tick() }
}
