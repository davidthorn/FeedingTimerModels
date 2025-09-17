//
//  OutlierPolicy.swift
//  FeedingTimer
//
//  Created by David Thorn on 14.08.25.
//

import Foundation

public enum OutlierPolicy: Sendable { case includeAll, excludeIQR }
