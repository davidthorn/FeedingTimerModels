//
//  AppColorScheme.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 06.08.25.
//

import Foundation
import SwiftUI

public enum AppColorScheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
