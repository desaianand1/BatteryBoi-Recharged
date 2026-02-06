//
//  MockUpdateManager.swift
//  BatteryBoi - Recharged
//
//  Mock implementation for unit testing.
//

@testable import BatteryBoi___Recharged
import Foundation

#if DEBUG

    /// Mock update manager for unit testing.
    @MainActor
    final class MockUpdateManager: UpdateManagerProtocol {
        // MARK: - Observable Properties

        var state: UpdateStateType
        var available: UpdatePayloadObject?
        var checked: Date?
        var automaticUpdates: Bool
        var currentVersion: String
        var currentBuild: String

        var versionDisplay: String {
            "v\(currentVersion) (\(currentBuild))"
        }

        // MARK: - Test Helpers

        var updateCheckCallCount = 0

        // MARK: - Initialization

        nonisolated init(
            state: UpdateStateType = .idle,
            available: UpdatePayloadObject? = nil,
            checked: Date? = nil,
            automaticUpdates: Bool = true,
            currentVersion: String = "1.0.0",
            currentBuild: String = "100"
        ) {
            self.state = state
            self.available = available
            self.checked = checked
            self.automaticUpdates = automaticUpdates
            self.currentVersion = currentVersion
            self.currentBuild = currentBuild
        }

        // MARK: - Methods

        func updateCheck() {
            updateCheckCallCount += 1
            state = .checking
        }

        // MARK: - Test Simulation

        func simulateUpdateFound(
            id: String = UUID().uuidString,
            name: String = "Version 2.0.0",
            version: UpdateVersionObject = UpdateVersionObject(formatted: "2.0.0", semver: "2.0.0")
        ) {
            available = UpdatePayloadObject(id: id, name: name, version: version)
            state = .completed
            checked = Date()
        }

        func simulateNoUpdateFound() {
            available = nil
            state = .completed
            checked = Date()
        }

        func simulateUpdateFailed() {
            state = .failed
            checked = Date()
        }

        func simulateStateChange(_ newState: UpdateStateType) {
            state = newState
        }
    }

#endif
