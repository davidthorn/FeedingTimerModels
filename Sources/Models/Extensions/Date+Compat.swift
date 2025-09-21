//
//  Date+Compat.swift
//  FeedingTimerModels
//
//  Backport for Date.now on older macOS versions.
//

import Foundation

extension Date {
    // Provide Date.now for macOS prior to 12.0 so the package
    // can compile with a macOS 10.15 deployment target.
    @available(macOS, introduced: 10.15, obsoleted: 12.0)
    public static var now: Date { Date() }
}

