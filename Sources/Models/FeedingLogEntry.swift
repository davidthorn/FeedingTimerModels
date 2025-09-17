//
//  FeedingLogEntry.swift
//  Models
//
//  Created by David Thorn on 19.07.25.
//

import Foundation

public struct FeedingLogEntry: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var startTime: Date
    public var endTime: Date?
    public var cues: Set<FeedingCue>
    public var breast: Breast
    public let createdAt: Date
    public var lastUpdatedAt: Date
    public var breastUnits: [BreastUnit]

    public init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        cues: Set<FeedingCue> = [],
        breast: Breast,
        breastUnits: [BreastUnit] = [],
        createdAt: Date = Date(),
        lastUpdatedAt: Date = Date()
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.cues = cues
        self.breast = breast
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.breastUnits = breastUnits
    }

    /// Returns the total breastfeeding time for this entry.
    /// - If `breastUnits` are present, sums their durations.
    /// - Otherwise, falls back to the envelope duration (end - start) when `endTime` exists.
    /// - For active (no `endTime`), returns 0 here — callers that need live elapsed time
    ///   should compute it with access to the active segment start (e.g., in `FeedLogService`).
    public func effectiveDuration(use breastUnit: [BreastUnit]) -> TimeInterval {
        if !breastUnits.isEmpty {
            return breastUnits.reduce(0) { $0 + $1.duration }
        }
        guard let endTime else { return 0.0 }
        return max(0, endTime.timeIntervalSince(startTime))
    }

    public var totalDuration: TimeInterval {
        breastUnits.reduce(0) { $0 + $1.duration }
    }

    public var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    // MARK: - Codable Compatibility

    public enum CodingKeys: String, CodingKey {
        case id
        case startTime
        case endTime
        case cues
        case breast
        case createdAt
        case lastUpdatedAt
        case breastUnits
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        cues = try container.decodeIfPresent(Set<FeedingCue>.self, forKey: .cues) ?? []
        breast = try container.decode(Breast.self, forKey: .breast)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? startTime
        lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt) ?? endTime ?? startTime

        // If breastUnits is missing, create a fallback with single entry
        if let units = try container.decodeIfPresent([BreastUnit].self, forKey: .breastUnits) {
            breastUnits = units
        } else if let end = endTime {
            let duration = end.timeIntervalSince(startTime)
            breastUnits = [.init(breast: breast, duration: duration, startTime: startTime, endTime: end)]
        } else {
            breastUnits = []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(cues, forKey: .cues)
        try container.encode(breast, forKey: .breast)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
        try container.encode(breastUnits, forKey: .breastUnits)
    }
}

public extension FeedingLogEntry    {
    static var example: Self {
        // Example: 2 segments (Left 12m, Right 9m with 1m gap)
        let now = Date()
        let start = now.addingTimeInterval(-22 * 60)
        let lStart = start
        let lEnd = lStart.addingTimeInterval(12 * 60)
        let rStart = lEnd.addingTimeInterval(1 * 60)
        let rEnd = rStart.addingTimeInterval(9 * 60)

        let units: [BreastUnit] = [
            .init(breast: .left, duration: lEnd.timeIntervalSince(lStart), startTime: lStart, endTime: lEnd),
            .init(breast: .right, duration: rEnd.timeIntervalSince(rStart), startTime: rStart, endTime: rEnd)
        ]

        return .init(
            id: .init(),
            startTime: start,
            endTime: rEnd,
            cues: [.rooting, .handToMouth],
            breast: .right,
            breastUnits: units,
            createdAt: start,
            lastUpdatedAt: now
        )
    }
}
