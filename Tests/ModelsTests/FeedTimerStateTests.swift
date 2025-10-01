//
//  FeedTimerStateTests.swift
//  FeedingTimerModels
//
//  Created by David Thorn on 01.10.25.
//

import Testing
import Foundation
@testable import Models

@MainActor
@Suite("FeedTimerState Test Suite", .serialized)
struct FeedTimerStateTests {

    // MARK: - Helpers
    private func makeFeed(start: Date, duration: TimeInterval, breast: Breast = .left, completed: Bool = true) -> FeedingLogEntry {
        let end = completed ? start.addingTimeInterval(duration) : nil
        return FeedingLogEntry(
            id: UUID(),
            startTime: start,
            endTime: end,
            cues: [],
            breast: breast,
            breastUnits: [],
            createdAt: start,
            lastUpdatedAt: end ?? start
        )
    }
    
    private func makeState(
        canSwitchBetweenFeed: Bool = true,
        isPaused: Bool = false,
        lastBreast: Breast = .left,
        choosenBreast: Breast = .left,
        currentFeed: FeedingLogEntry? = nil,
        feedingState: FeedingState = .waiting,
        isVoiceOverRunning: Bool = false,
        gapSinceLast: TimeInterval? = nil
    ) -> FeedTimerState {
        FeedTimerState(
            canSwitchBetweenFeed: canSwitchBetweenFeed,
            isPaused: isPaused,
            lastBreast: lastBreast,
            choosenBreast: choosenBreast,
            currentFeed: currentFeed,
            feedingState: feedingState,
            isVoiceOverRunning: isVoiceOverRunning,
            gapSinceLast: gapSinceLast
        )
    }

    // MARK: - isFeeding
    @Test
    func isFeeding_true_whenStateIsFeeding() async throws {
        let state = makeState(feedingState: .feeding)
        #expect(state.isFeeding)
    }

    @Test
    func isFeeding_false_whenStateIsNotFeeding() async throws {
        let waiting = makeState(feedingState: .waiting)
        let completed = makeState(feedingState: .completed)
        #expect(waiting.isFeeding == false)
        #expect(completed.isFeeding == false)
    }

    // MARK: - isFeedCompleted
    @Test
    func isFeedCompleted_true_whenFeedingStateCompleted_evenIfCurrentActive() async throws {
        let activeCurrent = makeFeed(start: Date(), duration: 600, breast: .left, completed: false)
        let state = makeState(
            currentFeed: activeCurrent,
            feedingState: .completed
        )
        #expect(state.isFeedCompleted)
    }

    @Test
    func isFeedCompleted_true_whenCurrentFeedHasEndTime() async throws {
        let now = Date()
        let current = makeFeed(start: now.addingTimeInterval(-1200), duration: 600, breast: .right, completed: true)
        let state = makeState(
            currentFeed: current,
            feedingState: .waiting
        )
        #expect(state.isFeedCompleted)
        #expect(state.isFeeding == false)
    }

    @Test
    func isFeedCompleted_false_whenNoCurrentFeed_andStateNotCompleted() async throws {
        let state = makeState(canSwitchBetweenFeed: false)
        #expect(state.isFeedCompleted == false)
    }

    @Test
    func isFeedCompleted_false_whenCurrentFeedActive_andStateWaiting() async throws {
        let now = Date()
        let current = makeFeed(start: now.addingTimeInterval(-600), duration: 0, breast: .left, completed: false)
        let state = makeState(currentFeed: current)
        #expect(state.isFeedCompleted == false)
        #expect(state.isFeeding == false)
    }

    // MARK: - Switch buttons disabled logic (Left->Right)
    @Test
    func switchLeftToRight_isDisabled_whenFeedingAndNotPaused() async throws {
        let state = makeState(
            feedingState: .feeding,
        )
        #expect(state.canSwitch == false)
        #expect(state.switchLeftToRightBreastDisabled)
        #expect(state.switchRightToLeftBreastDisabled)
        #expect(state.isFeeding)
        #expect(state.isFeedCompleted == false)
    }

    @Test
    func switchLeftToRight_enabled_whenCanSwitch_andChosenLeft() async throws {
        let state = makeState()
        #expect(state.canSwitch == true)
        #expect(state.switchLeftToRightBreastDisabled == false)
        #expect(state.switchRightToLeftBreastDisabled == true)
        #expect(state.isFeeding == false)
        #expect(state.isFeedCompleted == false)
    }

    @Test
    func switchLeftToRight_disabled_whenCanSwitch_andChosenRight() async throws {
        let state = makeState(
            choosenBreast: .right
        )
        #expect(state.canSwitch == true)
        #expect(state.switchLeftToRightBreastDisabled == true)
        #expect(state.switchRightToLeftBreastDisabled == false)
        #expect(state.isFeeding == false)
        #expect(state.isFeedCompleted == false)
    }

    @Test
    func switchLeftToRight_disabled_whenCannotSwitch_andChosenLeft() async throws {
        let state = makeState(
            canSwitchBetweenFeed: false
        )
        // When cannot switch, disabled mirrors choosenBreast == .left
        #expect(state.canSwitch == false)
        #expect(state.switchLeftToRightBreastDisabled == true)
        #expect(state.switchRightToLeftBreastDisabled == true)
        #expect(state.isFeeding == false)
        #expect(state.isFeedCompleted == false)
    }

    @Test
    func switchLeftToRight_enabled_whenCannotSwitch_andChosenRight() async throws {
        let state = makeState(
            canSwitchBetweenFeed: false,
            choosenBreast: .right
        )
        #expect(state.canSwitch == false)
        #expect(state.switchLeftToRightBreastDisabled == true)
        #expect(state.switchRightToLeftBreastDisabled == true)
        #expect(state.isFeeding == false)
        #expect(state.isFeedCompleted == false)
    }

    // MARK: - Switch buttons disabled logic (Right->Left)
    @Test
    func switchRightToLeft_isDisabled_whenFeedingAndNotPaused() async throws {
        let state = makeState(
            choosenBreast: .right,
            feedingState: .feeding
        )
        #expect(state.canSwitch == false)
        #expect(state.switchLeftToRightBreastDisabled == true)
        #expect(state.switchRightToLeftBreastDisabled == true)
        #expect(state.isFeeding == true)
        #expect(state.isFeedCompleted == false)
    }

    @Test
    func switchRightToLeft_enabled_whenCanSwitch_andChosenRight() async throws {
        let state = makeState(
            choosenBreast: .right
        )
        #expect(state.canSwitch == true)
        #expect(state.switchLeftToRightBreastDisabled == true)
        #expect(state.switchRightToLeftBreastDisabled == false)
        #expect(state.isFeeding == false)
        #expect(state.isFeedCompleted == false)
    }

    @Test
    func switchRightToLeft_disabled_whenCanSwitch_andChosenLeft() async throws {
        let state = makeState()
        #expect(state.canSwitch == true)
        #expect(state.switchLeftToRightBreastDisabled == false)
        #expect(state.switchRightToLeftBreastDisabled == true)
        #expect(state.isFeeding == false)
        #expect(state.isFeedCompleted == false)
    }

    @Test
    func switchRightToLeft_disabled_whenCannotSwitch_andChosenRight() async throws {
        let state = makeState(
            canSwitchBetweenFeed: false,
            choosenBreast: .right
        )
        #expect(state.canSwitch == false)
        #expect(state.switchLeftToRightBreastDisabled == true)
        #expect(state.switchRightToLeftBreastDisabled == true)
        #expect(state.isFeeding == false)
        #expect(state.isFeedCompleted == false)
    }

    @Test
    func switchRightToLeft_enabled_whenCannotSwitch_andChosenLeft() async throws {
        let state = makeState(
            canSwitchBetweenFeed: false
        )
        #expect(state.canSwitch == false)
        #expect(state.switchLeftToRightBreastDisabled == true)
        #expect(state.switchRightToLeftBreastDisabled == true)
        #expect(state.isFeeding == false)
        #expect(state.isFeedCompleted == false)
    }

    @Test
    func switchButtons_respectRules_whenFeedingPaused() async throws {
        // isFeeding true but paused -> should not auto-disable; falls back to canSwitch rules
        let leftState = makeState(
            isPaused: true,
            feedingState: .feeding
        )
        #expect(leftState.canSwitch == false)
        #expect(leftState.switchLeftToRightBreastDisabled == false)
        #expect(leftState.switchRightToLeftBreastDisabled == true)
        #expect(leftState.isFeeding == true)
        #expect(leftState.isFeedCompleted == false)
        #expect(leftState.isPaused == true)

        let rightState = makeState(
            isPaused: true,
            choosenBreast: .right,
            feedingState: .feeding
        )
        
        #expect(rightState.canSwitch == false)
        #expect(rightState.switchLeftToRightBreastDisabled == true)
        #expect(rightState.switchRightToLeftBreastDisabled == false)
        #expect(rightState.isFeeding == true)
        #expect(rightState.isFeedCompleted == false)
        #expect(rightState.isPaused == true)
    }

    // MARK: - getMostRecentFeed
    @Test
    func getMostRecentFeed_returnsCurrent_whenCurrentCompleted() async throws {
        let now = Date()
        let current = makeFeed(start: now.addingTimeInterval(-1800), duration: 600, breast: .left, completed: true)
        let older = makeFeed(start: now.addingTimeInterval(-7200), duration: 900, breast: .right, completed: true)
        let newer = makeFeed(start: now.addingTimeInterval(-2400), duration: 300, breast: .left, completed: true)

        let state = makeState(currentFeed: current)
        let result = state.getMostRecentFeed(from: [older, newer])
        #expect(result?.id == current.id)
    }

    @Test
    func getMostRecentFeed_picksLatestCompletedFromList_whenNoCurrentOrCurrentActive() async throws {
        let now = Date()
        let a = makeFeed(start: now.addingTimeInterval(-7200), duration: 900, breast: .right, completed: true)
        let b = makeFeed(start: now.addingTimeInterval(-3600), duration: 600, breast: .left, completed: true)
        let cActive = makeFeed(start: now.addingTimeInterval(-1200), duration: 0, breast: .left, completed: false)

        // With no current
        let state1 = makeState()
        let res1 = state1.getMostRecentFeed(from: [a, b])
        #expect(res1?.id == b.id)

        // With active current (should ignore it and choose most recent completed from list)
        let state2 = makeState(currentFeed: cActive, feedingState: .feeding)
        let res2 = state2.getMostRecentFeed(from: [a, b])
        #expect(res2?.id == b.id)
    }

    @Test
    func getMostRecentFeed_returnsNil_whenNoCompletedFeeds() async throws {
        let now = Date()
        let a = makeFeed(start: now.addingTimeInterval(-3600), duration: 0, breast: .left, completed: false)
        let b = makeFeed(start: now.addingTimeInterval(-1800), duration: 0, breast: .right, completed: false)
        let state = makeState()
        let result = state.getMostRecentFeed(from: [a, b])
        #expect(result == nil)
    }

    // MARK: - handlePendingBreastSelection
    @Test
    func handlePendingBreastSelection_changesWhenNotFeeding() async throws {
        var state = makeState()
        state.handlePendingBreastSelection(.right)
        #expect(state.choosenBreast == .right)
    }

    @Test
    func handlePendingBreastSelection_noChangeWhenFeeding() async throws {
        var state = makeState(feedingState: .feeding)
        state.handlePendingBreastSelection(.right)
        #expect(state.choosenBreast == .left)
    }

    @Test
    func handlePendingBreastSelection_noChangeWhenNilSelection() async throws {
        var state = makeState(choosenBreast: .right)
        state.handlePendingBreastSelection(nil)
        #expect(state.choosenBreast == .right)
    }

    // MARK: - recomputeGapSinceLast
    @Test
    func recomputeGapSinceLast_nilWhenFewerThanTwoCompletedFeeds() async throws {
        let now = Date()
        let a = makeFeed(start: now.addingTimeInterval(-3600), duration: 600, completed: true)
        var state0 = makeState()
        state0.recomputeGapSinceLast(feeds: [])
        #expect(state0.gapSinceLast == nil)

        var state1 = makeState()
        state1.recomputeGapSinceLast(feeds: [a])
        #expect(state1.gapSinceLast == nil)
    }

    @Test
    func recomputeGapSinceLast_computesPositiveGap_betweenMostRecentCompletedFeeds() async throws {
        let now = Date()
        // Two completed feeds; sorted by start desc inside the method
        let first = makeFeed(start: now.addingTimeInterval(-7200), duration: 900, completed: true) // older
        let second = makeFeed(start: now.addingTimeInterval(-3600), duration: 600, completed: true) // newer
        var state = makeState()
        state.recomputeGapSinceLast(feeds: [first, second])
        // gap = second.start - first.end
        let expected = second.startTime.timeIntervalSince(first.endTime!)
        #expect(state.gapSinceLast == max(0, expected))
    }

    @Test
    func recomputeGapSinceLast_zeroWhenOverlappingOrNegativeGap() async throws {
        let now = Date()
        // Overlap: previous ends after current starts
        let previous = makeFeed(start: now.addingTimeInterval(-3600), duration: 2400, completed: true) // ends at -1200s
        let current = makeFeed(start: now.addingTimeInterval(-1800), duration: 600, completed: true)   // starts at -1800s
        var state = makeState()
        state.recomputeGapSinceLast(feeds: [previous, current])
        #expect(state.gapSinceLast == 0)
    }
}
