//
//  Test.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 01.10.25.
//

import Foundation
import Testing
import Models
import Statistics

@MainActor
@Suite("FeedingLogEntry Extensions Test", .serialized)
struct Test {

    @Test("start(with:nowProvider:) initializes fields correctly for left breast")
    func start_initializesFields_left() async throws {
        let fixed = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = MockNowProvider(now: fixed)

        let entry = FeedingLogEntry.start(with: .left, nowProvider: clock)

        #expect(entry.breast == .left)
        #expect(entry.startTime == fixed)
        #expect(entry.endTime == nil)
        #expect(entry.cues.isEmpty)
        #expect(entry.breastUnits.isEmpty)
        #expect(entry.createdAt == fixed)
        #expect(entry.lastUpdatedAt == fixed)
        // sanity: createdAt and lastUpdatedAt align at creation
        #expect(entry.createdAt == entry.lastUpdatedAt)
    }

    @Test("start(with:nowProvider:) initializes fields correctly for right breast")
    func start_initializesFields_right() async throws {
        let fixed = Date(timeIntervalSince1970: 1_700_100_000)
        let clock = MockNowProvider(now: fixed)

        let entry = FeedingLogEntry.start(with: .right, nowProvider: clock)

        #expect(entry.breast == .right)
        #expect(entry.startTime == fixed)
        #expect(entry.endTime == nil)
        #expect(entry.cues.isEmpty)
        #expect(entry.breastUnits.isEmpty)
        #expect(entry.createdAt == fixed)
        #expect(entry.lastUpdatedAt == fixed)
    }

    @Test("start(with:nowProvider:) generates unique IDs on repeated calls and uses provided now")
    func start_generatesUniqueIDs_andUsesProvidedNow() async throws {
        let fixed = Date(timeIntervalSince1970: 1_700_200_000)
        let clock = MockNowProvider(now: fixed)

        let a = FeedingLogEntry.start(with: .left, nowProvider: clock)
        let b = FeedingLogEntry.start(with: .right, nowProvider: clock)

        // IDs should differ
        #expect(a.id != b.id)
        // Both should use the same provided now for timestamps
        #expect(a.startTime == fixed)
        #expect(b.startTime == fixed)
        #expect(a.createdAt == fixed)
        #expect(b.createdAt == fixed)
        #expect(a.lastUpdatedAt == fixed)
        #expect(b.lastUpdatedAt == fixed)
    }

    @Test("start(with:nowProvider:) yields zero durations for active entries (no end, no units)")
    func start_activeEntry_hasZeroDurations() async throws {
        let fixed = Date(timeIntervalSince1970: 1_700_300_000)
        let clock = MockNowProvider(now: fixed)

        let entry = FeedingLogEntry.start(with: .left, nowProvider: clock)

        // totalDuration is sum of units; none exist yet
        #expect(entry.totalDuration == 0)
        // effectiveDuration falls back to 0 when active (no endTime) and no units exist
        #expect(entry.effectiveDuration(use: []) == 0)
    }

    @Test("effectiveDuration uses units when present, ignoring envelope")
    func effectiveDuration_usesUnits_overEnvelope() async throws {
        // Given an entry whose envelope is longer than the sum of units
        let start = Date(timeIntervalSince1970: 1_700_400_000)
        let end = start.addingTimeInterval(600) // 10 minutes envelope
        let units: [BreastUnit] = [
            .init(breast: .left,  duration: 120, startTime: start,                    endTime: start.addingTimeInterval(120)),
            .init(breast: .right, duration: 180, startTime: start.addingTimeInterval(120), endTime: start.addingTimeInterval(300))
        ]
        let entry = FeedingLogEntry(
            startTime: start,
            endTime: end,
            cues: [],
            breast: .left,
            breastUnits: units
        )

        // When computing effective duration with units
        let eff = entry.effectiveDuration(use: entry.breastUnits)

        // Then it equals the sum of units (not the envelope)
        #expect(eff == 300)
    }

    @Test("effectiveDuration uses envelope when no units and entry completed")
    func effectiveDuration_usesEnvelope_whenNoUnits_completed() async throws {
        let start = Date(timeIntervalSince1970: 1_700_500_000)
        let end = start.addingTimeInterval(450) // 7.5 minutes
        let entry = FeedingLogEntry(
            startTime: start,
            endTime: end,
            cues: [],
            breast: .right,
            breastUnits: []
        )

        let eff = entry.effectiveDuration(use: entry.breastUnits)
        #expect(eff == 450)
    }

    @Test("effectiveDuration sums units for active entries (no endTime)")
    func effectiveDuration_unitsForActiveEntry() async throws {
        let start = Date(timeIntervalSince1970: 1_700_600_000)
        let units: [BreastUnit] = [
            .init(breast: .left,  duration: 90,  startTime: start,                    endTime: start.addingTimeInterval(90)),
            .init(breast: .right, duration: 210, startTime: start.addingTimeInterval(90), endTime: start.addingTimeInterval(300))
        ]
        let entry = FeedingLogEntry(
            startTime: start,
            endTime: nil,
            cues: [],
            breast: .left,
            breastUnits: units
        )

        let eff = entry.effectiveDuration(use: entry.breastUnits)
        #expect(eff == 300)
    }

    @Test("totalDuration equals sum of unit durations")
    func totalDuration_sumsUnits() async throws {
        let start = Date(timeIntervalSince1970: 1_700_700_000)
        let units: [BreastUnit] = [
            .init(breast: .left,  duration: 30,  startTime: start,                    endTime: start.addingTimeInterval(30)),
            .init(breast: .left,  duration: 60,  startTime: start.addingTimeInterval(30), endTime: start.addingTimeInterval(90)),
            .init(breast: .right, duration: 120, startTime: start.addingTimeInterval(90), endTime: start.addingTimeInterval(210))
        ]
        let entry = FeedingLogEntry(
            startTime: start,
            endTime: start.addingTimeInterval(300), // envelope longer than units
            cues: [],
            breast: .left,
            breastUnits: units
        )

        #expect(entry.totalDuration == 210)
    }

    @Test("totalDuration is zero when there are no units")
    func totalDuration_zero_whenNoUnits() async throws {
        let start = Date(timeIntervalSince1970: 1_700_800_000)
        let entry = FeedingLogEntry(
            startTime: start,
            endTime: start.addingTimeInterval(120),
            cues: [],
            breast: .right,
            breastUnits: []
        )
        #expect(entry.totalDuration == 0)
    }

    @Test("pause appends a unit and updates end/lastUpdatedAt using state's lastUpdatedAt as unit start")
    func pause_appendsUnit_andUpdatesTimestamps() async throws {
        let tStart = Date(timeIntervalSince1970: 1_800_000_000)
        let tPause = tStart.addingTimeInterval(120)

        // Start feed at tStart on left
        let startClock = MockNowProvider(now: tStart)
        let entry0 = FeedingLogEntry.start(with: .left, nowProvider: startClock)
        let state = ActiveBreastingFeedState.feeding(
            breastInfo: .init(last: nil, current: .left),
            history: .init(current: entry0, last: nil),
            lastUpdatedAt: tStart
        )

        // Pause at tPause
        let pauseClock = MockNowProvider(now: tPause)
        let paused = entry0.pause(with: state, nowProvider: pauseClock)

        // Assertions
        #expect(paused.id == entry0.id)
        #expect(paused.startTime == tStart) // from state's lastUpdatedAt
        #expect(paused.endTime == tPause)
        #expect(paused.lastUpdatedAt == tPause)
        #expect(paused.breast == .left)
        #expect(paused.cues == entry0.cues)
        #expect(paused.breastUnits.count == 1)

        let u = try #require(paused.breastUnits.first)
        #expect(u.breast == .left)
        #expect(u.startTime == tStart)
        #expect(u.endTime == tPause)
        #expect(abs(u.duration - tPause.timeIntervalSince(tStart)) < 0.001)
    }

    @Test("pause uses state's current breast and lastUpdatedAt for the unit, regardless of entry.breast")
    func pause_usesStateCurrentBreast_andStateLastUpdatedAt() async throws {
        let tStart = Date(timeIntervalSince1970: 1_800_100_000)
        let tPause = tStart.addingTimeInterval(90)

        // Start feed at tStart on left, but state will say current is right
        let startClock = MockNowProvider(now: tStart)
        let entry0 = FeedingLogEntry.start(with: .left, nowProvider: startClock)
        let state = ActiveBreastingFeedState.feeding(
            breastInfo: .init(last: nil, current: .right),
            history: .init(current: entry0, last: nil),
            lastUpdatedAt: tStart
        )

        let pauseClock = MockNowProvider(now: tPause)
        let paused = entry0.pause(with: state, nowProvider: pauseClock)

        // Should adopt state's current breast (right)
        #expect(paused.breast == .right)
        #expect(paused.breastUnits.count == 1)
        let u = try #require(paused.breastUnits.first)
        #expect(u.breast == .right)
        #expect(u.startTime == tStart) // from state's lastUpdatedAt
        #expect(u.endTime == tPause)
        #expect(abs(u.duration - (tPause.timeIntervalSince(tStart))) < 0.001)
    }

    @Test("pause appends a second unit after a resume, preserving the first")
    func pause_appendsSecondUnit_afterResume_preservesFirst() async throws {
        let tStart  = Date(timeIntervalSince1970: 1_800_200_000)
        let tPause1 = tStart.addingTimeInterval(120)
        let tResume = tStart.addingTimeInterval(180)
        let tPause2 = tStart.addingTimeInterval(300)

        // Start on left
        let startClock = MockNowProvider(now: tStart)
        let entry0 = FeedingLogEntry.start(with: .left, nowProvider: startClock)
        let feedingState0 = ActiveBreastingFeedState.feeding(
            breastInfo: .init(last: nil, current: .left),
            history: .init(current: entry0, last: nil),
            lastUpdatedAt: tStart
        )

        // First pause at tPause1 → closes left segment [tStart, tPause1]
        let pauseClock1 = MockNowProvider(now: tPause1)
        let entry1 = entry0.pause(with: feedingState0, nowProvider: pauseClock1)

        // Create a paused state reflecting the first pause, and resume on right at tResume
        let pausedState = ActiveBreastingFeedState.paused(
            breastInfo: .init(last: .left, current: .right),
            history: .init(current: entry1, last: nil),
            lastUpdatedAt: tPause1
        )
        let resumeClock = MockNowProvider(now: tResume)
        let resumedEntry = entry1.resume(with: pausedState, nowProvider: resumeClock)
        let feedingState1 = ActiveBreastingFeedState.feeding(
            breastInfo: .init(last: .left, current: .right),
            history: .init(current: resumedEntry, last: nil),
            lastUpdatedAt: tResume
        )

        // Second pause at tPause2 → closes right segment [tResume, tPause2]
        let pauseClock2 = MockNowProvider(now: tPause2)
        let entry2 = resumedEntry.pause(with: feedingState1, nowProvider: pauseClock2)

        // Assertions
        #expect(entry2.endTime == tPause2)
        #expect(entry2.lastUpdatedAt == tPause2)
        #expect(entry2.breastUnits.count == 2)

        let first = entry2.breastUnits[0]
        let second = entry2.breastUnits[1]

        #expect(first.breast == .left)
        #expect(first.startTime == tStart)
        #expect(first.endTime == tPause1)
        #expect(abs(first.duration - (tPause1.timeIntervalSince(tStart))) < 0.001)

        #expect(second.breast == .right)
        #expect(second.startTime == tResume)
        #expect(second.endTime == tPause2)
        #expect(abs(second.duration - (tPause2.timeIntervalSince(tResume))) < 0.001)
    }

    @Test("restart(from paused) clears endTime, preserves units/cues/id/start/createdAt, updates lastUpdatedAt, and sets breast to provided")
    func restart_fromPaused_clearsEnd_preservesUnits_updatesBreastAndTimestamp() async throws {
        let tStart  = Date(timeIntervalSince1970: 1_900_000_000)
        let tPause  = tStart.addingTimeInterval(120)
        let tResume = tStart.addingTimeInterval(240) // time we call restart

        // Start on left at tStart
        let startClock = MockNowProvider(now: tStart)
        let entry0 = FeedingLogEntry.start(with: .left, nowProvider: startClock)
        let feedingState0 = ActiveBreastingFeedState.feeding(
            breastInfo: .init(last: nil, current: .left),
            history: .init(current: entry0, last: nil),
            lastUpdatedAt: tStart
        )

        // Pause at tPause -> closes first unit [tStart, tPause] on left
        let pauseClock = MockNowProvider(now: tPause)
        let pausedEntry = entry0.pause(with: feedingState0, nowProvider: pauseClock)

        // Restart at tResume using right breast
        let restartClock = MockNowProvider(now: tResume)
        let restarted = pausedEntry.restart(with: .right, nowProvider: restartClock)

        // Assertions
        #expect(restarted.id == pausedEntry.id)
        #expect(restarted.startTime == entry0.startTime)
        #expect(restarted.endTime == nil)
        #expect(restarted.createdAt == entry0.createdAt)
        #expect(restarted.lastUpdatedAt == tResume)
        #expect(restarted.cues == pausedEntry.cues)

        // Breast should change to provided value
        #expect(restarted.breast == .right)

        // Units should be preserved from paused entry (one unit on left)
        #expect(restarted.breastUnits.count == 1)
        let u = try #require(restarted.breastUnits.first)
        #expect(u.breast == .left)
        #expect(u.startTime == tStart)
        #expect(u.endTime == tPause)
        #expect(abs(u.duration - (tPause.timeIntervalSince(tStart))) < 0.001)
    }

    @Test("restart(from active) preserves id/start/createdAt, keeps units empty, sets breast, and updates lastUpdatedAt")
    func restart_fromActive_preservesCoreFields_setsBreast_updatesTimestamp() async throws {
        let tStart   = Date(timeIntervalSince1970: 1_900_100_000)
        let tRestart = tStart.addingTimeInterval(90)

        // Active entry started on left
        let startClock = MockNowProvider(now: tStart)
        let active = FeedingLogEntry.start(with: .left, nowProvider: startClock)

        // Restart to right at tRestart
        let restartClock = MockNowProvider(now: tRestart)
        let restarted = active.restart(with: .right, nowProvider: restartClock)

        // Assertions
        #expect(restarted.id == active.id)
        #expect(restarted.startTime == active.startTime)
        #expect(restarted.createdAt == active.createdAt)
        #expect(restarted.endTime == nil)
        #expect(restarted.lastUpdatedAt == tRestart)
        #expect(restarted.breast == .right)
        #expect(restarted.cues == active.cues)
        #expect(restarted.breastUnits.isEmpty)
    }

    @Test("stop(from active with no prior pause) creates a single unit from lastUpdatedAt to now and completes the entry")
    func stop_fromActive_createsSingleUnit_andCompletesEntry() async throws {
        let tStart = Date(timeIntervalSince1970: 1_800_300_000)
        let tStop  = tStart.addingTimeInterval(180)

        // Start on left at tStart
        let startClock = MockNowProvider(now: tStart)
        let entry0 = FeedingLogEntry.start(with: .left, nowProvider: startClock)
        let feedingState = ActiveBreastingFeedState.feeding(
            breastInfo: .init(last: nil, current: .left),
            history: .init(current: entry0, last: nil),
            lastUpdatedAt: tStart
        )

        // Stop at tStop
        let stopClock = MockNowProvider(now: tStop)
        let stopped = entry0.stop(with: feedingState, nowProvider: stopClock)

        // Assertions
        #expect(stopped.id == entry0.id)
        #expect(stopped.endTime == tStop)
        #expect(stopped.lastUpdatedAt == tStop)
        #expect(stopped.breast == .left)
        #expect(stopped.cues == entry0.cues)
        #expect(stopped.breastUnits.count == 1)

        let u = try #require(stopped.breastUnits.first)
        #expect(u.breast == .left)
        #expect(u.startTime == tStart) // from state's lastUpdatedAt at start
        #expect(u.endTime == tStop)
        #expect(abs(u.duration - (tStop.timeIntervalSince(tStart))) < 0.001)
    }

    @Test("stop(after resume) appends a unit from state's lastUpdatedAt to now with state's current breast and completes the entry")
    func stop_afterResume_appendsUnit_andCompletesEntry() async throws {
        let tStart  = Date(timeIntervalSince1970: 1_800_400_000)
        let tPause  = tStart.addingTimeInterval(60)
        let tResume = tStart.addingTimeInterval(120)
        let tStop   = tStart.addingTimeInterval(300)

        // Start on left and pause at tPause (closes first unit [tStart, tPause])
        let startClock = MockNowProvider(now: tStart)
        let entry0 = FeedingLogEntry.start(with: .left, nowProvider: startClock)
        let feedingState0 = ActiveBreastingFeedState.feeding(
            breastInfo: .init(last: nil, current: .left),
            history: .init(current: entry0, last: nil),
            lastUpdatedAt: tStart
        )
        let pauseClock = MockNowProvider(now: tPause)
        let paused = entry0.pause(with: feedingState0, nowProvider: pauseClock)

        // Resume state (without mutating the entry) sets lastUpdatedAt = tResume and current breast = right
        let resumedState = ActiveBreastingFeedState.feeding(
            breastInfo: .init(last: .left, current: .right),
            history: .init(current: paused, last: nil),
            lastUpdatedAt: tResume
        )

        // Stop at tStop (appends second unit [tResume, tStop] on right)
        let stopClock = MockNowProvider(now: tStop)
        let completed = paused.stop(with: resumedState, nowProvider: stopClock)

        // Assertions
        #expect(completed.endTime == tStop)
        #expect(completed.lastUpdatedAt == tStop)
        #expect(completed.breastUnits.count == 2)
        #expect(completed.breast == .right)

        let first = completed.breastUnits[0]
        let second = completed.breastUnits[1]

        // First unit from start..pause on left
        #expect(first.breast == .left)
        #expect(first.startTime == tStart)
        #expect(first.endTime == tPause)
        #expect(abs(first.duration - (tPause.timeIntervalSince(tStart))) < 0.001)

        // Second unit from resume..stop on right (start = state's lastUpdatedAt at resume)
        #expect(second.breast == .right)
        #expect(second.startTime == tResume)
        #expect(second.endTime == tStop)
        #expect(abs(second.duration - (tStop.timeIntervalSince(tResume))) < 0.001)
    }
}
