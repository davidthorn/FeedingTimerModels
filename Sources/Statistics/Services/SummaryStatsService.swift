//
//  SummaryStatsService.swift
//  FeedingTimer
//
//  Extracted computeStats: totals, average duration, and average inter-feed interval.
//

import Foundation
import Models

/// Computes overall summary stats across all completed feeds: total duration,
/// average duration, and average start-to-start interval with sensible
/// outlier handling.
public struct SummaryStatsService: Sendable {
    public let env: StatsEnvironment
    
    public init(env: StatsEnvironment = .init()) {
        self.env = env
    }
    
    /// Computes totals and averages over all completed feeds.
    /// - Parameters:
    ///   - feeds: All feed entries; only completed feeds are considered.
    ///   - ageDays: Baby age in days (optional) for age-aware winsorization caps.
    /// - Returns: `FeedingStats` populated with total duration, average duration,
    ///            average start-to-start interval, interval count, and outlier count.
    public func computeStats(from feeds: [FeedingLogEntry], ageDays: Int?) -> FeedingStats {
        guard !feeds.isEmpty else {
            return FeedingStats(totalDuration: 0, averageDuration: 0, averageInterval: 0, intervalCount: 0, outlierCount: 0)
        }
        
        // Durations: completed feeds only
        let completed = feeds.filter { $0.endTime != nil }
        
        let totalDuration = completed.compactMap { item in
            return item.effectiveDuration(use: item.breastUnits)
        }.reduce(0, +)
        
        let averageDuration = completed.isEmpty ? 0 : totalDuration / Double(completed.count)
        
        // Intervals: start-to-start (completed only)
        let sorted = completed.sorted { $0.startTime < $1.startTime }
        let rawIntervals: [TimeInterval] = zip(sorted.dropFirst(), sorted).map { next, prev in
            let dt = next.startTime.timeIntervalSince(prev.startTime)
            return dt > 0 ? dt : 0
        }
        
        guard !rawIntervals.isEmpty else {
            return FeedingStats(totalDuration: totalDuration, averageDuration: averageDuration, averageInterval: 0, intervalCount: 0, outlierCount: 0)
        }
        
        // Small‑N path: legacy plain mean (no caps/drops)
        if rawIntervals.count < 4 {
            let mean = rawIntervals.reduce(0, +) / Double(rawIntervals.count)
            return FeedingStats(totalDuration: totalDuration, averageDuration: averageDuration, averageInterval: mean, intervalCount: rawIntervals.count, outlierCount: 0)
        }
        
        // IQR active: drop short, cap long
        let (processed, cappedCount) = OutlierService().winsorizeIntervals(rawIntervals, ageDays: ageDays)
        
        let averageInterval: TimeInterval = {
            guard !processed.isEmpty else {
                // Fallback: too much dropped → use raw mean
                return rawIntervals.reduce(0, +) / Double(rawIntervals.count)
            }
            return processed.reduce(0, +) / Double(processed.count)
        }()
        
        return FeedingStats(
            totalDuration: totalDuration,
            averageDuration: averageDuration,
            averageInterval: averageInterval,
            intervalCount: rawIntervals.count,
            outlierCount: cappedCount
        )
    }
}
