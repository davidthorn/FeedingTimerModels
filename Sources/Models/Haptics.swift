//
//  Haptics.swift
//  FeedingTimer
//
//  Created by David Thorn on 11.08.25.
//
import Foundation
#if os(iOS)
import UIKit
#endif

@MainActor
public enum Haptics {
    #if os(iOS)
    public static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    public static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    #else
    // No-op implementations for non-iOS platforms (e.g., macOS)
    public static func success() { }
    public static func tap() { }
    #endif
}
