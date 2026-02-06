//
//  MockStatsService.swift
//  BatteryBoi - Recharged
//
//  Mock implementation for unit testing.
//

@testable import BatteryBoi___Recharged
import Foundation

#if DEBUG

    /// Mock stats service for unit testing.
    @MainActor
    final class MockStatsService: StatsServiceProtocol {
        // MARK: - Observable Properties

        var display: String?
        var overlay: String?
        var title: String
        var subtitle: String
        var statsIcon: StatsIcon

        // MARK: - Test Helpers

        var recordActivityCallCount = 0
        var lastRecordedState: StatsStateType?
        var lastRecordedDevice: BluetoothObject?

        // MARK: - Initialization

        nonisolated init(
            display: String? = nil,
            overlay: String? = nil,
            title: String = "Test Title",
            subtitle: String = "Test Subtitle",
            statsIcon: StatsIcon = StatsIcon(name: "ChargingIcon", system: false)
        ) {
            self.display = display
            self.overlay = overlay
            self.title = title
            self.subtitle = subtitle
            self.statsIcon = statsIcon
        }

        // MARK: - Methods

        func recordActivity(_ state: StatsStateType, device: BluetoothObject?) async {
            recordActivityCallCount += 1
            lastRecordedState = state
            lastRecordedDevice = device
        }

        // MARK: - Test Simulation

        func simulateDisplayChange(_ newDisplay: String?) {
            display = newDisplay
        }

        func simulateTitleChange(_ newTitle: String, subtitle newSubtitle: String) {
            title = newTitle
            subtitle = newSubtitle
        }
    }

#endif
