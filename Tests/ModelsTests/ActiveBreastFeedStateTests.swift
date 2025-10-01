//
//  MockNowProvider.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 01.10.25.
//

import Foundation
import Testing
import Models
import Statistics

// Fixed clock for deterministic tests
struct MockNowProvider: NowProvider {
    var now: Date
}

@MainActor
@Suite("ActiveBreastingFeedState Test Suite", .serialized)
struct ActiveBreastFeedStateTests {

    // MARK: - Helpers
    private func makeBreastInfo(current: Breast, last: Breast? = nil) -> ActiveBreastingFeedState.BreastInfo {
        .init(last: last, current: current)
    }

    private func makeHistory(current: FeedingLogEntry, last: FeedingLogEntry? = nil) -> FeedHistory {
        // Assumes FeedHistory has a memberwise initializer (last:current:)
        return FeedHistory(current: current, last: last)
    }

    // MARK: - Start feed
    @Test("start feed sets lastUpdatedAt to now and uses now as startTime")
    func startFeed_setsLastUpdatedAt_andStartTime() async throws {
        let tStart = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = MockNowProvider(now: tStart)

        // Start a new feed with a fixed now
        let current = FeedingLogEntry.start(with: .left, nowProvider: clock)
        let info = makeBreastInfo(current: .left)
        let state = ActiveBreastingFeedState.feeding(
            breastInfo: info,
            history: makeHistory(current: current),
            lastUpdatedAt: tStart
        )

        #expect(state.lastUpdatedAt == current.lastUpdatedAt)
        #expect(current.startTime == tStart)
        #expect(current.endTime == nil)
        #expect(current.lastUpdatedAt == tStart)
        #expect(current.lastUpdatedAt == tStart)
    }

    // MARK: - Pause feed
    @Test("pause feed updates lastUpdatedAt and closes a unit from previous lastUpdatedAt to now")
    func pauseFeed_updatesLastUpdatedAt_andAppendsUnit() async throws {
        let tStart = Date(timeIntervalSince1970: 1_700_000_000)
        let tPause = tStart.addingTimeInterval(120)

        // Start
        let startClock = MockNowProvider(now: tStart)
        
        let initialFeed = FeedingLogEntry.start(with: .left, nowProvider: startClock)
        
        let feedingState = ActiveBreastingFeedState.feeding(
            breastInfo: makeBreastInfo(current: .left),
            history: makeHistory(current: initialFeed),
            lastUpdatedAt: tStart
        )

        // Pause at tPause
        let pauseClock = MockNowProvider(now: tPause)
        let pausedFeed = initialFeed.pause(with: feedingState, nowProvider: pauseClock)
        let pausedFeedState = feedingState.pausedState(with: pauseClock)

        #expect(pausedFeedState.history?.current == pausedFeed)
        #expect(pausedFeedState.lastUpdatedAt == tPause)
        #expect(pausedFeedState.lastUpdatedAt == pausedFeed.lastUpdatedAt)
        #expect(pausedFeed.lastUpdatedAt == tPause)
        #expect(pausedFeed.breastUnits.count == 1)

        let u = try #require(pausedFeed.breastUnits.first)
        #expect(u.breast == .left)
        #expect(u.startTime == tStart) // from state's lastUpdatedAt at start time
        #expect(u.endTime == tPause)
        #expect(abs(u.duration - tPause.timeIntervalSince(tStart)) < 0.001)
    }

    // MARK: - Resume feed
    @Test("resume feed sets lastUpdatedAt to resume time for the next unit's start")
    func resumeFeed_setsLastUpdatedAt_forNextUnitStart() async throws {
        let tStart = Date(timeIntervalSince1970: 1_700_000_000)
        let tPause = tStart.addingTimeInterval(120)
        let tResume = tStart.addingTimeInterval(300)

        // Start
        let startClock = MockNowProvider(now: tStart)
        let initialFeed = FeedingLogEntry.start(with: .left, nowProvider: startClock)
        let feedingState = ActiveBreastingFeedState.feeding(
            breastInfo: makeBreastInfo(current: .left),
            history: makeHistory(current: initialFeed),
            lastUpdatedAt: tStart
        )

        // Pause
        let pauseClock: MockNowProvider = MockNowProvider(now: tPause)
        let pausedFeed: FeedingLogEntry = initialFeed.pause(with: feedingState, nowProvider: pauseClock)
        let pausedFeedState: ActiveBreastingFeedState = feedingState.pausedState(with: pauseClock)

        // Resume at tResume: update state to feeding with new lastUpdatedAt
        let resumedState: ActiveBreastingFeedState = ActiveBreastingFeedState.feeding(
            breastInfo: makeBreastInfo(current: .right, last: .left),
            history: makeHistory(current: pausedFeed.resume(with: pausedFeedState, nowProvider: MockNowProvider(now: tResume))),
            lastUpdatedAt: tResume
        )
        let resumedFeedState: ActiveBreastingFeedState = pausedFeedState.resumedState(using: .right, with: MockNowProvider(now: tResume))

        #expect(resumedFeedState.history?.current == resumedState.history?.current)
        #expect(resumedState.lastUpdatedAt == tResume)
        // No feed mutation yet; verification will occur on stop
    }

    // MARK: - Stop feed
    @Test("stop feed uses state's lastUpdatedAt as unit start and updates lastUpdatedAt to now")
    func stopFeed_usesLastUpdatedAtAsUnitStart_andUpdatesToNow() async throws {
        let tStart = Date(timeIntervalSince1970: 1_700_000_000)
        let tPause = tStart.addingTimeInterval(120)
        let tResume = tStart.addingTimeInterval(300)
        let tStop = tStart.addingTimeInterval(600)

        // Start
        let startClock = MockNowProvider(now: tStart)
        let initialFeed = FeedingLogEntry.start(with: .left, nowProvider: startClock)
        let feedingState = ActiveBreastingFeedState.feeding(
            breastInfo: makeBreastInfo(current: .left),
            history: makeHistory(current: initialFeed),
            lastUpdatedAt: tStart
        )

        // Pause
        let pauseClock = MockNowProvider(now: tPause)
        let pausedFeed = initialFeed.pause(with: feedingState, nowProvider: pauseClock)

        // Resume (state only; this sets the reference start for the next unit)
        let resumedState = ActiveBreastingFeedState.feeding(
            breastInfo: makeBreastInfo(current: .right, last: .left),
            history: makeHistory(current: pausedFeed),
            lastUpdatedAt: tResume
        )

        // Stop at tStop
        let stopClock = MockNowProvider(now: tStop)
        let completedFeed = pausedFeed.stop(with: resumedState, nowProvider: stopClock)

        #expect(completedFeed.endTime == tStop)
        #expect(completedFeed.lastUpdatedAt == tStop)
        #expect(completedFeed.breastUnits.count == 2)

        let first = completedFeed.breastUnits[0]
        let second = completedFeed.breastUnits[1]

        // First segment from start..pause on left
        #expect(first.breast == .left)
        #expect(first.startTime == tStart)
        #expect(first.endTime == tPause)

        // Second segment from resume..stop on right (start = state's lastUpdatedAt at resume)
        #expect(second.breast == .right)
        #expect(second.startTime == tResume)
        #expect(second.endTime == tStop)
    }
    
    // MARK: - Focused tests on ActiveBreastingFeedState transitions
    @Test("pausedState returns .paused with updated history and timestamp")
    func pausedState_setsPaused_updatesHistoryAndLastUpdatedAt() async throws {
        let tStart = Date(timeIntervalSince1970: 1_700_000_000)
        let tPause = tStart.addingTimeInterval(90)
        
        // Start feed at tStart
        let startClock = MockNowProvider(now: tStart)
        let initialFeed = FeedingLogEntry.start(with: .left, nowProvider: startClock)
        let feedingState = ActiveBreastingFeedState.feeding(
            breastInfo: .init(last: nil, current: .left),
            history: .init(current: initialFeed, last: nil),
            lastUpdatedAt: tStart
        )
        
        // Pause via state API at tPause
        let pauseClock = MockNowProvider(now: tPause)
        let pausedViaModel = initialFeed.pause(with: feedingState, nowProvider: pauseClock)
        let pausedState = feedingState.pausedState(with: pauseClock)
        
        // Assertions: state, history, timestamps, and breastInfo remain unchanged
        #expect(pausedState.state == .paused)
        #expect(pausedState.history?.current == pausedViaModel)
        #expect(pausedState.lastUpdatedAt == tPause)
        #expect(pausedViaModel.lastUpdatedAt == tPause)
        #expect(pausedState.breastInfo.current == .left)
        #expect(pausedState.breastInfo.last == nil)
        
        // The pause should append a unit from lastUpdatedAt(start) to now(pause)
        let u = try #require(pausedViaModel.breastUnits.first)
        #expect(u.breast == .left)
        #expect(u.startTime == tStart)
        #expect(u.endTime == tPause)
        #expect(abs(u.duration - tPause.timeIntervalSince(tStart)) < 0.001)
    }
    
    @Test("resumedState returns .feeding with provided current breast and timestamp")
    func resumedState_setsFeeding_updatesBreastInfoCurrent_andLastUpdatedAt() async throws {
        let tStart = Date(timeIntervalSince1970: 1_700_000_000)
        let tPause = tStart.addingTimeInterval(120)
        let tResume = tStart.addingTimeInterval(300)
        
        // Start and then pause
        let startClock = MockNowProvider(now: tStart)
        let initialFeed = FeedingLogEntry.start(with: .left, nowProvider: startClock)
        let feedingState = ActiveBreastingFeedState.feeding(
            breastInfo: .init(last: nil, current: .left),
            history: .init(current: initialFeed, last: nil),
            lastUpdatedAt: tStart
        )
        let pauseClock = MockNowProvider(now: tPause)
        let pausedFeed = initialFeed.pause(with: feedingState, nowProvider: pauseClock)
        let pausedState = feedingState.pausedState(with: pauseClock)
        
        // Resume via state API using right breast at tResume
        let resumeClock = MockNowProvider(now: tResume)
        let expectedResumedFeed = pausedFeed.resume(with: pausedState, nowProvider: resumeClock)
        let resumedState = pausedState.resumedState(using: .right, with: resumeClock)
        
        // Assertions: state, history, timestamps, and breastInfo current is updated
        #expect(resumedState.state == .feeding)
        #expect(resumedState.history?.current == expectedResumedFeed)
        #expect(resumedState.lastUpdatedAt == tResume)
        #expect(resumedState.breastInfo.current == .right)
        
        // Per current implementation, `last` is preserved from previous state (remains nil here)
        #expect(resumedState.breastInfo.last == pausedState.breastInfo.last)
    }
}
