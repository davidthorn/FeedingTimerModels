//
//  Date+Compat.swift
//  FeedingTimerModels Statistics
//
//  Backport for Date.now on older macOS versions.
//

import Foundation

extension Date {
    @available(macOS, introduced: 10.15, obsoleted: 12.0)
    public static var now: Date { Date() }
}

