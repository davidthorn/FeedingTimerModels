//
//  TimeOfDaySlot.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 17.09.25.
//

import Foundation

public enum TimeOfDaySlot: String, CaseIterable {
    case night, morning, afternoon, evening
    
    public var localizedLabel: String {
        NSLocalizedString(rawValue.capitalized, comment: "")
    }
}
