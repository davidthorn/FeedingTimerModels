//
//  Haptics.swift
//  FeedingTimer
//
//  Created by David Thorn on 11.08.25.
//

import SwiftUI

@MainActor
public enum Haptics {
    public static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    public static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }

}
