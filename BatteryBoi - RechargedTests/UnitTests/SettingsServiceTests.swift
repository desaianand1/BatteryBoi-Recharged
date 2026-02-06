//
//  SettingsServiceTests.swift
//  BatteryBoi-RechargedTests
//
//  Behavioral tests for settings service functionality.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class SettingsServiceTests: XCTestCase {

    // MARK: - Properties

    /// Mock service (nonisolated for setUp/tearDown compatibility with Swift 6)
    nonisolated(unsafe) var mockSettingsService: MockSettingsService!

    // MARK: - Setup

    override nonisolated func setUp() {
        super.setUp()
        let service = MainActor.assumeIsolated {
            MockSettingsService()
        }
        mockSettingsService = service
    }

    override nonisolated func tearDown() {
        mockSettingsService = nil
        super.tearDown()
    }

    // MARK: - Display Toggle Tests

    @MainActor
    func testToggleDisplayCycles() {
        // Given countdown display
        mockSettingsService.display = .countdown

        // When toggling display
        var result = mockSettingsService.toggleDisplay()
        XCTAssertEqual(result, .percent)

        result = mockSettingsService.toggleDisplay()
        XCTAssertEqual(result, .empty)

        result = mockSettingsService.toggleDisplay()
        XCTAssertEqual(result, .cycle)

        result = mockSettingsService.toggleDisplay()
        XCTAssertEqual(result, .hidden)

        result = mockSettingsService.toggleDisplay()
        XCTAssertEqual(result, .countdown)
    }

    @MainActor
    func testToggleDisplayTracksCallCount() {
        // Given initial state
        XCTAssertEqual(mockSettingsService.toggleDisplayCallCount, 0)

        // When toggling
        mockSettingsService.toggleDisplay()
        mockSettingsService.toggleDisplay()

        // Then call count should be tracked
        XCTAssertEqual(mockSettingsService.toggleDisplayCallCount, 2)
    }

    // MARK: - Persistence Tests

    @MainActor
    func testAutoLaunchSetting() {
        // Given enabled auto-launch
        mockSettingsService.autoLaunch = .enabled

        // Then setting should persist
        XCTAssertEqual(mockSettingsService.autoLaunch, .enabled)

        // When disabled
        mockSettingsService.autoLaunch = .disabled

        // Then change should persist
        XCTAssertEqual(mockSettingsService.autoLaunch, .disabled)
    }

    @MainActor
    func testThemeSetting() {
        // Given system theme
        mockSettingsService.theme = .system

        // When changing to dark
        mockSettingsService.theme = .dark

        // Then theme should update
        XCTAssertEqual(mockSettingsService.theme, .dark)

        // When changing to light
        mockSettingsService.theme = .light

        // Then theme should update
        XCTAssertEqual(mockSettingsService.theme, .light)
    }

    @MainActor
    func testPinnedSetting() {
        // Given unpinned
        mockSettingsService.pinned = .disabled

        // When enabling pinned mode
        mockSettingsService.pinned = .enabled

        // Then setting should update
        XCTAssertEqual(mockSettingsService.pinned, .enabled)
    }

    @MainActor
    func testChargeSetting() {
        // Given charge notification disabled
        mockSettingsService.charge = .disabled

        // When enabling
        mockSettingsService.charge = .enabled

        // Then setting should update
        XCTAssertEqual(mockSettingsService.charge, .enabled)
    }

    @MainActor
    func testChargeEightySetting() {
        // Given 80% charge notification disabled
        mockSettingsService.chargeEighty = .disabled

        // When enabling
        mockSettingsService.chargeEighty = .enabled

        // Then setting should update
        XCTAssertEqual(mockSettingsService.chargeEighty, .enabled)
    }

    // MARK: - Style Tests

    @MainActor
    func testBatteryStyleChange() {
        // Given chunky style
        mockSettingsService.style = .chunky

        // When changing to basic
        mockSettingsService.style = .basic

        // Then style should update
        XCTAssertEqual(mockSettingsService.style, .basic)
    }

    // MARK: - Sound Effects Tests

    @MainActor
    func testSoundEffectsToggle() {
        // Given sound effects enabled
        mockSettingsService.soundEffects = .enabled

        // When disabling
        mockSettingsService.soundEffects = .disabled

        // Then setting should update
        XCTAssertEqual(mockSettingsService.soundEffects, .disabled)
    }

    // MARK: - Progress Bar Tests

    @MainActor
    func testProgressBarToggle() {
        // Given progress bar enabled
        mockSettingsService.progressBar = true

        // When disabling
        mockSettingsService.progressBar = false

        // Then setting should update
        XCTAssertFalse(mockSettingsService.progressBar)
    }

    // MARK: - Bluetooth Status Tests

    @MainActor
    func testBluetoothStatusToggle() {
        // Given bluetooth enabled
        mockSettingsService.bluetoothStatus = .enabled

        // When disabling
        mockSettingsService.bluetoothStatus = .disabled

        // Then setting should update
        XCTAssertEqual(mockSettingsService.bluetoothStatus, .disabled)
    }

    // MARK: - Action Tests

    @MainActor
    func testPerformActionTracking() {
        // Given a settings action
        let action = SettingsActionObject(.appWebsite)

        // When performing action
        mockSettingsService.performAction(action)

        // Then action should be tracked
        XCTAssertEqual(mockSettingsService.performActionCallCount, 1)
        XCTAssertEqual(mockSettingsService.lastPerformedAction?.type, .appWebsite)
    }

    @MainActor
    func testMultipleActionsTracking() {
        // Given multiple actions
        let action1 = SettingsActionObject(.appWebsite)
        let action2 = SettingsActionObject(.appQuit)

        // When performing multiple actions
        mockSettingsService.performAction(action1)
        mockSettingsService.performAction(action2)

        // Then all actions should be counted
        XCTAssertEqual(mockSettingsService.performActionCallCount, 2)
        XCTAssertEqual(mockSettingsService.lastPerformedAction?.type, .appQuit)
    }

    // MARK: - Edge Cases

    @MainActor
    func testRapidSettingChanges() {
        // When rapidly changing settings
        for _ in 0 ..< 10 {
            mockSettingsService.toggleDisplay()
            mockSettingsService.autoLaunch = mockSettingsService.autoLaunch == .enabled ? .disabled : .enabled
        }

        // Then should handle gracefully
        XCTAssertEqual(mockSettingsService.toggleDisplayCallCount, 10)
    }

    @MainActor
    func testSimulateDisplayChange() {
        // Given initial display
        mockSettingsService.display = .percent

        // When simulating change
        mockSettingsService.simulateDisplayChange(.countdown)

        // Then display should update
        XCTAssertEqual(mockSettingsService.display, .countdown)
    }

    @MainActor
    func testSimulatePinnedChange() {
        // Given unpinned
        mockSettingsService.pinned = .disabled

        // When simulating change
        mockSettingsService.simulatePinnedChange(.enabled)

        // Then pinned should update
        XCTAssertEqual(mockSettingsService.pinned, .enabled)
    }
}
