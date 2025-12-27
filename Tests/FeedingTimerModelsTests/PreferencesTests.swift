//
//  PreferencesTests.swift
//  FeedingTimerModelsTests
//
//  Created by David Thorn on 26.09.25.
//

import Foundation
import Testing
import Models

@Suite("Preferences")
@MainActor
struct PreferencesTests {
    private static func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "PreferencesTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    
    @Test("Default peer sync configuration is fully enabled")
    func defaultPeerSyncConfiguration_isFullyEnabled() async throws {
        let (defaults, suiteName) = Self.makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = Preferences(defaults: defaults)

        #expect(preferences.peerSyncConfiguration == PeerSyncConfiguration())
        #expect(!preferences.allowBroadcasting)
    }

    @Test("Legacy allowBroadcasting flag seeds configuration")
    func legacyAllowBroadcastingSeedsConfiguration() async throws {
        let (defaults, suiteName) = Self.makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(false, forKey: "allowBroadcasting")

        let preferences = Preferences(defaults: defaults)
        let configuration = preferences.peerSyncConfiguration

        #expect(!configuration.isEnabled)
        #expect(!configuration.canSend)
        #expect(configuration.canReceive)
        #expect(configuration.canCreate)
        #expect(configuration.canUpdate)
        #expect(configuration.canDelete)
    }

    @Test("allowBroadcasting bridge updates configuration and persists")
    func allowBroadcastingBridge_updatesConfigurationAndPersists() async throws {
        let (defaults, suiteName) = Self.makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = Preferences(defaults: defaults)

        preferences.allowBroadcasting = false
        #expect(!preferences.peerSyncConfiguration.canSend)
        #expect(!preferences.peerSyncConfiguration.isEnabled)
        #expect(!defaults.bool(forKey: "allowBroadcasting"))

        preferences.allowBroadcasting = true
        #expect(preferences.peerSyncConfiguration.canSend)
        #expect(preferences.peerSyncConfiguration.isEnabled)
        #expect(defaults.bool(forKey: "allowBroadcasting"))

        let reloaded = Preferences(defaults: defaults)
        #expect(reloaded.peerSyncConfiguration.canSend)
        #expect(reloaded.peerSyncConfiguration.isEnabled)
    }
}
