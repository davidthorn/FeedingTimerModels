//
//  AdaptiveInfoGridItem.swift
//  FeedingTimer
//
//  Created by David Thorn on 11.08.25.
//

import Foundation

public struct AdaptiveInfoGridItem: Identifiable, Hashable {
    public let id = UUID()
    public let icon: String
    public let title: String
    public let value: String
    public init(icon: String, title: String, value: String) {
        self.icon = icon
        self.title = title
        self.value = value
    }
}
