//
//  BBSettingsManagerTests.swift
//  BatteryBoiTests
//
//  Unit tests for settings manager functionality.
//

@testable import BatteryBoi
import XCTest

final class BBSettingsManagerTests: XCTestCase {

    // MARK: - Properties

    var mockSettingsService: MockSettingsService!

    // MARK: - Setup

    @MainActor
    override func setUp() {
        super.setUp()
        mockSettingsService = MockSettingsService()
    }

    override func tearDown() {
        mockSettingsService = nil
        super.tearDown()
    }

    // MARK: - Display Mode Tests

    @MainActor
    func testToggleDisplayFromCountdown() {
        // Given countdown display mode
        mockSettingsService.display = .countdown

        // When toggling display
        let newDisplay = mockSettingsService.toggleDisplay()

        // Then it should change to percent
        XCTAssertEqual(newDisplay, .percent)
        XCTAssertEqual(mockSettingsService.toggleDisplayCallCount, 1)
    }

    @MainActor
    func testToggleDisplayFromPercent() {
        // Given percent display mode
        mockSettingsService.display = .percent

        // When toggling display
        let newDisplay = mockSettingsService.toggleDisplay()

        // Then it should change to empty
        XCTAssertEqual(newDisplay, .empty)
    }

    @MainActor
    func testToggleDisplayFromEmpty() {
        // Given empty display mode
        mockSettingsService.display = .empty

        // When toggling display
        let newDisplay = mockSettingsService.toggleDisplay()

        // Then it should change to cycle
        XCTAssertEqual(newDisplay, .cycle)
    }

    @MainActor
    func testToggleDisplayFromCycle() {
        // Given cycle display mode
        mockSettingsService.display = .cycle

        // When toggling display
        let newDisplay = mockSettingsService.toggleDisplay()

        // Then it should change to hidden
        XCTAssertEqual(newDisplay, .hidden)
    }

    @MainActor
    func testToggleDisplayFromHidden() {
        // Given hidden display mode
        mockSettingsService.display = .hidden

        // When toggling display
        let newDisplay = mockSettingsService.toggleDisplay()

        // Then it should wrap back to countdown
        XCTAssertEqual(newDisplay, .countdown)
    }

    @MainActor
    func testDisplayCycleComplete() {
        // Given countdown display mode
        mockSettingsService.display = .countdown

        // When toggling through all modes
        mockSettingsService.toggleDisplay() // -> percent
        mockSettingsService.toggleDisplay() // -> empty
        mockSettingsService.toggleDisplay() // -> cycle
        mockSettingsService.toggleDisplay() // -> hidden
        let finalDisplay = mockSettingsService.toggleDisplay() // -> countdown

        // Then it should be back to countdown
        XCTAssertEqual(finalDisplay, .countdown)
        XCTAssertEqual(mockSettingsService.toggleDisplayCallCount, 5)
    }

    // MARK: - Theme Tests

    @MainActor
    func testThemeDark() {
        // Given dark theme
        mockSettingsService.theme = .dark

        // Then theme should be dark
        XCTAssertEqual(mockSettingsService.theme, .dark)
    }

    @MainActor
    func testThemeLight() {
        // Given light theme
        mockSettingsService.theme = .light

        // Then theme should be light
        XCTAssertEqual(mockSettingsService.theme, .light)
    }

    @MainActor
    func testThemeSystem() {
        // Given system theme
        mockSettingsService.theme = .system

        // Then theme should be system
        XCTAssertEqual(mockSettingsService.theme, .system)
    }

    // MARK: - Sound Effects Tests

    @MainActor
    func testSoundEffectsEnabled() {
        // Given sound effects enabled
        mockSettingsService.sfx = .enabled

        // Then sound effects should be enabled
        XCTAssertEqual(mockSettingsService.sfx, .enabled)
    }

    @MainActor
    func testSoundEffectsDisabled() {
        // Given sound effects disabled
        mockSettingsService.sfx = .disabled

        // Then sound effects should be disabled
        XCTAssertEqual(mockSettingsService.sfx, .disabled)
    }

    // MARK: - Pinned Setting Tests

    @MainActor
    func testPinnedEnabled() {
        // Given pinned enabled
        mockSettingsService.pinned = .enabled

        // Then pinned should be enabled
        XCTAssertEqual(mockSettingsService.pinned, .enabled)
    }

    @MainActor
    func testPinnedDisabled() {
        // Given pinned disabled
        mockSettingsService.pinned = .disabled

        // Then pinned should be disabled
        XCTAssertEqual(mockSettingsService.pinned, .disabled)
    }

    @MainActor
    func testPinnedSimulation() {
        // Given pinned disabled
        mockSettingsService.pinned = .disabled

        // When simulating pinned change
        mockSettingsService.simulatePinnedChange(.enabled)

        // Then pinned should be enabled
        XCTAssertEqual(mockSettingsService.pinned, .enabled)
    }

    // MARK: - Charge Setting Tests

    @MainActor
    func testChargeEightyEnabled() {
        // Given charge to 80% enabled
        mockSettingsService.charge = .enabled

        // Then charge should be enabled
        XCTAssertEqual(mockSettingsService.charge, .enabled)
    }

    @MainActor
    func testChargeEightyDisabled() {
        // Given charge to 80% disabled
        mockSettingsService.charge = .disabled

        // Then charge should be disabled
        XCTAssertEqual(mockSettingsService.charge, .disabled)
    }

    // MARK: - Action Perform Tests

    @MainActor
    func testPerformAction() {
        // Given a settings action
        let action = SettingsActionObject(.appQuit)

        // When performing the action
        mockSettingsService.performAction(action)

        // Then the action should be tracked
        XCTAssertEqual(mockSettingsService.performActionCallCount, 1)
        XCTAssertEqual(mockSettingsService.lastPerformedAction?.type, .appQuit)
    }
}
