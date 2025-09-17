//
//  Breast.swift
//  Feeding Log
//
//  Created by David Thorn on 24.07.25.
//

import Foundation

public enum Breast: Codable, CaseIterable, Identifiable, Sendable {
    case left
    case right
    
    public var id: String { fullLabel }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        
        switch raw.lowercased() {
        case "left": self = .left
        case "right": self = .right
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid breast value: \(raw)"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .left: try container.encode("left")
        case .right: try container.encode("right")
        }
    }
    
    public var opposite: Breast {
        self == .left ? .right : .left
    }
    
    public var iconName: String {
        switch self {
        case .left: return "arrow.left.circle"
        case .right: return "arrow.right.circle"
        }
    }
    
    /// For use in context like: "Left side", "Rechte Seite"
    public var adjectiveLabel: String {
        switch self {
        case .left:
            return NSLocalizedString("left-adjective", comment: "Adjective: Linke")
        case .right:
            return NSLocalizedString("right-adjective", comment: "Adjective: Rechte")
        }
    }
    
    /// For use in context like: "Left Breast", "Linke Brust"
    public var fullLabel: String {
        switch self {
        case .left:
            return NSLocalizedString("left-breast", comment: "Label: Linke Brust")
        case .right:
            return NSLocalizedString("right-breast", comment: "Label: Rechte Brust")
        }
    }
    
    /// For use as button label: "Left" / "Right", "Links" / "Rechts"
    public var buttonLabel: String {
        switch self {
        case .left:
            return NSLocalizedString("left-button", comment: "Button: Links")
        case .right:
            return NSLocalizedString("right-button", comment: "Button: Rechts")
        }
    }
}

