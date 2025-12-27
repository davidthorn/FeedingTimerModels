//
//  FeedingStyleService.swift
//  FeedingTimer
//
//  Created by David Thorn on 24.08.25.
//

import Foundation
import Models

public struct FeedingStyleService: Sendable {
    private let feeds: [FeedingLogEntry]

    // Tunables
    private let minSample = 20
    private let trimLower = 0.05
    private let trimUpper = 0.95
    private let pCutoff  = 0.25
    private let clusterGapFloor: TimeInterval = 120 * 60 // 120m
    private let clusterMinCount = 3
    private let clusterMinSample = 4
    private let snackDurationFloor: TimeInterval = 10 * 60 // 10m (fallback)

    public init(feeds: [FeedingLogEntry]) {
        // newest-first for convenience
        self.feeds = feeds.sorted { $0.startTime > $1.startTime }
    }

    // MARK: Public

    public func feedsWithTypes() -> [FeedingLogEntryStatsData] {
        guard !feeds.isEmpty else { return [] }

        let prevGaps = computePrevGaps()
        let durations = feeds.compactMap(effectiveDuration)
        let gapVals = prevGaps.compactMap { $0 }

        let p25Duration = percentileTrimmed(durations, p: pCutoff)
        let p25Gap = percentileTrimmed(gapVals, p: pCutoff)
        let snackDurCut = (!durations.isEmpty && durations.count >= minSample) ? p25Duration : snackDurationFloor
        let snackGapCut = (!gapVals.isEmpty && gapVals.count >= minSample) ? p25Gap : clusterGapFloor
        let clusterGapCut = min(clusterGapFloor, snackGapCut) // ← was max(...)

        let inCluster = clusterMembership(prevGaps: prevGaps, maxGap: clusterGapCut)

        return feeds.enumerated().map { i, e in
            let t = classify(index: i,
                             prevGaps: prevGaps,          // ← pass array
                             inCluster: inCluster.contains(i),
                             snackDurCut: snackDurCut,
                             snackGapCut: snackGapCut,
                             gapSamplesSufficient: gapVals.count >= minSample)
            return FeedingLogEntryStatsData(entry: e, type: t)
        }
    }

    public func type(for entry: FeedingLogEntry) -> FeedingEntryType {
        feedsWithTypes().first { $0.id == entry.id }?.type ?? .normal
    }

    // MARK: Internals

    private func effectiveDuration(_ e: FeedingLogEntry) -> TimeInterval? {
        e.effectiveDuration(use: e.breastUnits)
    }

    private func computePrevGaps() -> [TimeInterval?] {
        guard feeds.count > 1 else { return Array(repeating: nil, count: feeds.count) }
        var gaps = Array(repeating: Optional<TimeInterval>.none, count: feeds.count)
        for i in 0..<(feeds.count - 1) {
            gaps[i] = feeds[i].startTime.timeIntervalSince(feeds[i+1].startTime)
        }
        return gaps
    }

    private func clusterMembership(prevGaps: [TimeInterval?], maxGap: TimeInterval) -> Set<Int> {
        var result: Set<Int> = []
        guard feeds.count >= clusterMinSample else { return result } // NEW: no clusters on tiny samples

        var runStart: Int? = nil
        var runEnd: Int? = nil

        func commit() {
            if let s = runStart, let e = runEnd, (e - s + 1) >= clusterMinCount {
                for i in s...e { result.insert(i) }
            }
            runStart = nil; runEnd = nil
        }

        for i in 0..<(feeds.count - 1) {
            let close = (prevGaps[i] ?? .infinity) <= maxGap
            if close {
                if runStart == nil { runStart = i }
                runEnd = i + 1
            } else {
                commit()
            }
        }
        commit()
        return result
    }

    private func classify(index i: Int,
                          prevGaps: [TimeInterval?],
                          inCluster: Bool,
                          snackDurCut: TimeInterval,
                          snackGapCut: TimeInterval,
                          gapSamplesSufficient: Bool) -> FeedingEntryType {
        if inCluster { return .cluster }

        let dur = effectiveDuration(feeds[i])

        // Duration rule with strict '<'
        if let d = dur, d < snackDurCut { return .snack }

        // NEW: boundary protection — duration equals P25 (±1s) => normal,
        // and do NOT allow gap to flip it to snack.
        if let d = dur, abs(d - snackDurCut) <= 1 { return .normal }

        // Gap rule (unchanged except fallback chaining guard)
        if let g = prevGaps[i], g < snackGapCut {
            if gapSamplesSufficient {
                return .snack
            } else {
                let nextOlderGap = (i + 1 < prevGaps.count) ? (prevGaps[i + 1] ?? .infinity) : .infinity
                if nextOlderGap >= snackGapCut { return .snack }
            }
        }
        return .normal
    }

    // Trimmed percentile (inclusive p in 0...1). Returns fallback if not enough data.
    private func percentileTrimmed(_ values: [TimeInterval], p: Double) -> TimeInterval {
        guard values.count >= 3 else { return values.sorted().first ?? snackDurationFloor }
        let sorted = values.sorted()
        let lo = Int(Double(sorted.count) * trimLower)
        let hi = Int(Double(sorted.count) * trimUpper)
        let clipped = Array(sorted[max(0,lo)..<max(lo+1, min(sorted.count, hi))])
        guard !clipped.isEmpty else { return sorted[sorted.count/4] }
        let idx = max(0, min(clipped.count - 1, Int(round(p * Double(clipped.count - 1)))))
        return clipped[idx]
    }
}
