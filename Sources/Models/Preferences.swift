//
//  Preferences.swift
//  FeedingTimerModels
//
//  Centralized user preferences backed by UserDefaults.
//  Expose as an EnvironmentObject for app-wide access.
//

import Foundation
import Combine

@MainActor
public final class Preferences: ObservableObject {
    // Keys
    private enum Key {
        static let babyName = "babyName"
        static let dueDate = "dueDate"
        static let birthDate = "birthDate"
        static let birthWeight = "birthWeight"
        static let birthHeight = "birthHeight"
        static let allowBroadcasting = "allowBroadcasting"
        static let peerSyncConfiguration = "peerSyncConfiguration"
        static let deviceName = "deviceName"
        static let feedData = "activeFeed.snapshot"
    }

    private let defaults: UserDefaults
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    // Published properties
    @Published public var babyName: String {
        didSet { defaults.set(babyName, forKey: Key.babyName) }
    }

    @Published public var dueDate: Date {
        didSet { defaults.set(dueDate.timeIntervalSince1970, forKey: Key.dueDate) }
    }

    @Published public var birthDate: Date {
        didSet { defaults.set(birthDate.timeIntervalSince1970, forKey: Key.birthDate) }
    }

    @Published public var birthWeight: Double {
        didSet { defaults.set(birthWeight, forKey: Key.birthWeight) }
    }

    @Published public var birthHeight: Double {
        didSet { defaults.set(birthHeight, forKey: Key.birthHeight) }
    }

    @Published public var peerSyncConfiguration: PeerSyncConfiguration {
        didSet { savePeerSyncConfiguration(peerSyncConfiguration) }
    }

    @Published public var deviceName: String {
        didSet { defaults.set(deviceName, forKey: Key.deviceName) }
    }

    @Published public var activeFeedState: ActiveFeedState? {
        didSet {
            switch activeFeedState {
            case .some(let state):
                do {
                    let data = try Self.encoder.encode(state)
                    defaults.set(data, forKey: Key.feedData)
                } catch {
                    // Keep the previous value in UserDefaults if encoding fails
                    #if DEBUG
                    print("Preferences: Failed to encode ActiveFeedState: \(error)")
                    #endif
                }
            case .none:
                defaults.removeObject(forKey: Key.feedData)
            }
        }
    }
    
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.babyName = defaults.string(forKey: Key.babyName) ?? ""
        self.dueDate = Date(timeIntervalSince1970: defaults.object(forKey: Key.dueDate) as? Double ?? Date().timeIntervalSince1970)
        self.birthDate = Date(timeIntervalSince1970: defaults.object(forKey: Key.birthDate) as? Double ?? Date().timeIntervalSince1970)
        self.birthWeight = defaults.object(forKey: Key.birthWeight) as? Double ?? 3.2
        self.birthHeight = defaults.object(forKey: Key.birthHeight) as? Double ?? 50.0
        
        let loadedConfiguration: PeerSyncConfiguration
        if let data = defaults.data(forKey: Key.peerSyncConfiguration),
           let decoded = try? Self.decoder.decode(PeerSyncConfiguration.self, from: data) {
            loadedConfiguration = decoded
        } else if let legacyAllow = defaults.object(forKey: Key.allowBroadcasting) as? Bool {
            loadedConfiguration = PeerSyncConfiguration(canSend: legacyAllow)
        } else {
            loadedConfiguration = PeerSyncConfiguration()
        }
        
        self.peerSyncConfiguration = loadedConfiguration
        self.deviceName = defaults.string(forKey: Key.deviceName) ?? ""
        
        if let data = defaults.data(forKey: Key.feedData) {
            self.activeFeedState = try? Self.decoder.decode(ActiveFeedState.self, from: data)
        } else {
            self.activeFeedState = nil
        }
    }

    public var allowBroadcasting: Bool {
        get { peerSyncConfiguration.isEnabled && peerSyncConfiguration.canSend }
        set {
            var updated = peerSyncConfiguration
            updated.isEnabled = updated.isEnabled || newValue
            updated.canSend = newValue
            peerSyncConfiguration = updated
        }
    }

    public func resetAll() {
        babyName = ""
        dueDate = Date()
        birthDate = Date()
        birthWeight = 3.2
        birthHeight = 50.0
        peerSyncConfiguration = PeerSyncConfiguration()
        deviceName = ""
        activeFeedState = nil
    }

    private func savePeerSyncConfiguration(_ value: PeerSyncConfiguration) {
        guard let data = try? Self.encoder.encode(value) else { return }
        defaults.set(data, forKey: Key.peerSyncConfiguration)
        defaults.set(value.isEnabled && value.canSend, forKey: Key.allowBroadcasting)
    }
}
