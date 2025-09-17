import Testing
import Foundation
import Models
import Statistics

// Helpers
private func makeEntry(start: Date, units: [(Breast, TimeInterval)]) -> FeedingLogEntry {
    var cur = start
    var breastUnits: [BreastUnit] = []
    for (breast, dur) in units {
        let end = cur.addingTimeInterval(dur)
        breastUnits.append(BreastUnit(breast: breast, duration: dur, startTime: cur, endTime: end))
        cur = end
    }
    let endTime = breastUnits.last?.endTime
    return FeedingLogEntry(startTime: start, endTime: endTime, cues: [], breast: units.first?.0 ?? .left, breastUnits: breastUnits)
}

private func utcCalendar() -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal
}

@Test func averageDurations_usesUnitsOnly_excludesEnvelope() async throws {
    let svc = DurationStatsService()
    let cal = utcCalendar()
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    // A: units-only 120s
    let aStart = now.addingTimeInterval(-5 * 3600)
    let a = makeEntry(start: aStart, units: [(.left, 120)])

    // B: has envelope 300s but NO units → should be excluded from average durations
    let bStart = now.addingTimeInterval(-4 * 3600)
    let b = FeedingLogEntry(startTime: bStart, endTime: bStart.addingTimeInterval(300), cues: [], breast: .right, breastUnits: [])

    // C: units-only 180s
    let cStart = now.addingTimeInterval(-3 * 3600)
    let c = makeEntry(start: cStart, units: [(.right, 180)])

    let result = svc.averageDurations(
        feeds: [a, b, c],
        window: .days(1),
        grouping: .none,
        outlierPolicy: .includeAll,
        scenario: .all,
        recencyHalfLifeHours: nil,
        now: now,
        calendar: cal
    )

    // Expected mean of [120, 180] = 150
    #expect(abs(result.overall - 150) < 0.001)
}

@Test func averageDurations_breastGrouping_sumsPerSide() async throws {
    let svc = DurationStatsService()
    let cal = utcCalendar()
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    // E1: Left 120, Right 180
    let e1 = makeEntry(start: now.addingTimeInterval(-8 * 3600), units: [(.left, 120), (.right, 180)])
    // E2: Left 60
    let e2 = makeEntry(start: now.addingTimeInterval(-6 * 3600), units: [(.left, 60)])
    // E3: Right 240
    let e3 = makeEntry(start: now.addingTimeInterval(-4 * 3600), units: [(.right, 240)])

    let res = svc.averageDurations(
        feeds: [e1, e2, e3],
        window: .days(1),
        grouping: .breast,
        outlierPolicy: .includeAll,
        scenario: .all,
        recencyHalfLifeHours: nil,
        now: now,
        calendar: cal
    )

    let groups = Dictionary(uniqueKeysWithValues: res.groups.map { ($0.label, $0) })
    // Left samples: [120, 60] → avg 90, count 2
    #expect(abs((groups[Breast.left.adjectiveLabel]?.average ?? -1) - 90) < 0.001)
    #expect(groups[Breast.left.adjectiveLabel]?.count == 2)
    // Right samples: [180, 240] → avg 210, count 2
    #expect(abs((groups[Breast.right.adjectiveLabel]?.average ?? -1) - 210) < 0.001)
    #expect(groups[Breast.right.adjectiveLabel]?.count == 2)
}

@Test func averageDurations_recencyWeighted_emphasizesRecent() async throws {
    let svc = DurationStatsService()
    let cal = utcCalendar()
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    // Old: 600s @ now-6h, Recent: 60s @ now-1h
    let old = makeEntry(start: now.addingTimeInterval(-6 * 3600), units: [(.left, 600)])
    let recent = makeEntry(start: now.addingTimeInterval(-1 * 3600), units: [(.left, 60)])

    let halfLife: Double = 1 // hours
    let res = svc.averageDurations(
        feeds: [old, recent],
        window: .days(1),
        grouping: .none,
        outlierPolicy: .includeAll,
        scenario: .all,
        recencyHalfLifeHours: halfLife,
        now: now,
        calendar: cal
    )

    // Compute expected EWMA
    let tau = halfLife * 3600.0 / log(2.0)
    let wOld = exp(-(now.timeIntervalSince(old.startTime)) / tau)
    let wRecent = exp(-(now.timeIntervalSince(recent.startTime)) / tau)
    let expected = (wOld * 600 + wRecent * 60) / (wOld + wRecent)

    #expect(abs(res.overall - expected) < 0.001)
    // And ensure it is much closer to 60 than to 600
    #expect(res.overall < 150)
}

@Test func averageDurations_timeOfDayBuckets_unitsOnly() async throws {
    let facade = FeedingStatsService()
    let cal = utcCalendar()
    // Fixed day: 2023-10-10 00:00:00 UTC
    let dayStart = Date(timeIntervalSince1970: 1_696_900_800)
    let now = dayStart.addingTimeInterval(20 * 3600) // 20:00 UTC

    // Morning feed at 09:00, 120s (units)
    let morning = makeEntry(start: dayStart.addingTimeInterval(9 * 3600), units: [(.left, 120)])
    // Evening feed at 19:00, 300s (units)
    let evening = makeEntry(start: dayStart.addingTimeInterval(19 * 3600), units: [(.right, 300)])

    let result = facade.averageDurations(
        feeds: [morning, evening],
        daysBack: 1,
        grouping: .timeOfDay,
        outlierPolicy: .includeAll,
        scenario: .all,
        rollingHoursBack: nil,
        recencyHalfLifeHours: nil,
        now: now,
        calendar: cal
    )

    let groups = Dictionary(uniqueKeysWithValues: result.groups.map { ($0.label, $0) })
    #expect(abs((groups["Morning"]?.average ?? -1) - 120) < 0.001)
    #expect(abs((groups["Evening"]?.average ?? -1) - 300) < 0.001)
}

@Test func averageDurations_iqrFiltering_dropsOutlier() async throws {
    let svc = DurationStatsService()
    let cal = utcCalendar()
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    // Four left-only samples: 10, 11, 12, 1000 (seconds)
    let e1 = makeEntry(start: now.addingTimeInterval(-10 * 3600), units: [(.left, 10)])
    let e2 = makeEntry(start: now.addingTimeInterval(-9 * 3600), units: [(.left, 11)])
    let e3 = makeEntry(start: now.addingTimeInterval(-8 * 3600), units: [(.left, 12)])
    let e4 = makeEntry(start: now.addingTimeInterval(-7 * 3600), units: [(.left, 1000)])

    let res = svc.averageDurations(
        feeds: [e1, e2, e3, e4],
        window: .days(2),
        grouping: .breast,
        outlierPolicy: .excludeIQR,
        scenario: .all,
        recencyHalfLifeHours: nil,
        now: now,
        calendar: cal
    )

    let groups = Dictionary(uniqueKeysWithValues: res.groups.map { ($0.label, $0) })
    let left = groups[Breast.left.adjectiveLabel]
    #expect(left?.count == 3) // outlier dropped
    #expect((left?.average ?? 0) > 9 && (left?.average ?? 0) < 13)
}

