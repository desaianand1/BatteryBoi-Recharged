//
//  StatsServiceTests.swift
//  BatteryBoi-RechargedTests
//
//  Behavioral tests for stats service functionality.
//

@testable import BatteryBoi___Recharged
import SwiftUI
@preconcurrency import XCTest

final class StatsServiceTests: XCTestCase {

    // MARK: - Properties

    /// Mock service (nonisolated for setUp/tearDown compatibility with Swift 6)
    nonisolated(unsafe) var mockStatsService: MockStatsService!

    // MARK: - Setup

    override nonisolated func setUp() {
        super.setUp()
        let service = MainActor.assumeIsolated {
            MockStatsService()
        }
        mockStatsService = service
    }

    override nonisolated func tearDown() {
        mockStatsService = nil
        super.tearDown()
    }

    // MARK: - Activity Recording Tests

    @MainActor
    func testRecordChargingActivity() async {
        // Given initial state
        XCTAssertEqual(mockStatsService.recordActivityCallCount, 0)

        // When recording charging activity
        await mockStatsService.recordActivity(.charging, device: nil)

        // Then activity should be recorded
        XCTAssertEqual(mockStatsService.recordActivityCallCount, 1)
        XCTAssertEqual(mockStatsService.lastRecordedState, .charging)
        XCTAssertNil(mockStatsService.lastRecordedDevice)
    }

    @MainActor
    func testRecordDepletedActivity() async {
        // When recording depleted activity
        await mockStatsService.recordActivity(.depleted, device: nil)

        // Then activity should be recorded
        XCTAssertEqual(mockStatsService.lastRecordedState, .depleted)
    }

    @MainActor
    func testRecordConnectedActivity() async {
        // When recording connected activity
        await mockStatsService.recordActivity(.connected, device: nil)

        // Then activity should be recorded
        XCTAssertEqual(mockStatsService.lastRecordedState, .connected)
    }

    @MainActor
    func testRecordDisconnectedActivity() async {
        // When recording disconnected activity
        await mockStatsService.recordActivity(.disconnected, device: nil)

        // Then activity should be recorded
        XCTAssertEqual(mockStatsService.lastRecordedState, .disconnected)
    }

    @MainActor
    func testRecordActivityWithDevice() async {
        // Given a bluetooth device
        let device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "AirPods",
            batteryPercent: 80
        )

        // When recording activity with device
        await mockStatsService.recordActivity(.depleted, device: device)

        // Then device should be recorded
        XCTAssertNotNil(mockStatsService.lastRecordedDevice)
        XCTAssertEqual(mockStatsService.lastRecordedDevice?.device, "AirPods")
    }

    // MARK: - Display Tests

    @MainActor
    func testDisplayProperty() {
        // Given a display value
        mockStatsService.display = "75%"

        // Then display should be accessible
        XCTAssertEqual(mockStatsService.display, "75%")
    }

    @MainActor
    func testOverlayProperty() {
        // Given an overlay value
        mockStatsService.overlay = "2h 30m"

        // Then overlay should be accessible
        XCTAssertEqual(mockStatsService.overlay, "2h 30m")
    }

    @MainActor
    func testNilDisplay() {
        // Given nil display
        mockStatsService.display = nil

        // Then display should be nil
        XCTAssertNil(mockStatsService.display)
    }

    // MARK: - Title and Subtitle Tests

    @MainActor
    func testTitleProperty() {
        // Given a title
        mockStatsService.title = "Charging"

        // Then title should be accessible
        XCTAssertEqual(mockStatsService.title, "Charging")
    }

    @MainActor
    func testSubtitleProperty() {
        // Given a subtitle
        mockStatsService.subtitle = "Fully charged in 1 hour"

        // Then subtitle should be accessible
        XCTAssertEqual(mockStatsService.subtitle, "Fully charged in 1 hour")
    }

    @MainActor
    func testTitleChange() {
        // Given initial title
        mockStatsService.title = "Initial"

        // When simulating title change
        mockStatsService.simulateTitleChange("New Title", subtitle: "New Subtitle")

        // Then title and subtitle should update
        XCTAssertEqual(mockStatsService.title, "New Title")
        XCTAssertEqual(mockStatsService.subtitle, "New Subtitle")
    }

    // MARK: - Icon Tests

    @MainActor
    func testStatsIcon() {
        // Given a stats icon
        let icon = mockStatsService.statsIcon

        // Then icon should have properties
        XCTAssertNotNil(icon.name)
    }

    @MainActor
    func testStatsIconWithEffect() {
        mockStatsService = MockStatsService(
            statsIcon: StatsIcon(name: "bolt.fill", color: .green, effect: .pulseByLayer)
        )

        XCTAssertEqual(mockStatsService.statsIcon.name, "bolt.fill")
        XCTAssertEqual(mockStatsService.statsIcon.effect, .pulseByLayer)
    }

    @MainActor
    func testStatsIconNoEffect() {
        mockStatsService = MockStatsService(
            statsIcon: StatsIcon(name: "battery.100percent", color: .gray, effect: .none)
        )

        XCTAssertEqual(mockStatsService.statsIcon.name, "battery.100percent")
        XCTAssertEqual(mockStatsService.statsIcon.effect, .none)
    }

    // MARK: - Display Simulation Tests

    @MainActor
    func testSimulateDisplayChange() {
        // Given initial display
        mockStatsService.display = "50%"

        // When simulating display change
        mockStatsService.simulateDisplayChange("75%")

        // Then display should update
        XCTAssertEqual(mockStatsService.display, "75%")
    }

    @MainActor
    func testSimulateDisplayChangeToNil() {
        // Given a display value
        mockStatsService.display = "50%"

        // When simulating nil display
        mockStatsService.simulateDisplayChange(nil)

        // Then display should be nil
        XCTAssertNil(mockStatsService.display)
    }

    // MARK: - Multiple Activity Recording Tests

    @MainActor
    func testMultipleActivityRecording() async {
        // When recording multiple activities
        await mockStatsService.recordActivity(.charging, device: nil)
        await mockStatsService.recordActivity(.depleted, device: nil)
        await mockStatsService.recordActivity(.connected, device: nil)

        // Then all activities should be counted
        XCTAssertEqual(mockStatsService.recordActivityCallCount, 3)
        XCTAssertEqual(mockStatsService.lastRecordedState, .connected)
    }

    // MARK: - Edge Cases

    @MainActor
    func testEmptyTitle() {
        // Given empty title
        mockStatsService.title = ""

        // Then title should be empty string
        XCTAssertEqual(mockStatsService.title, "")
    }

    @MainActor
    func testEmptySubtitle() {
        // Given empty subtitle
        mockStatsService.subtitle = ""

        // Then subtitle should be empty string
        XCTAssertEqual(mockStatsService.subtitle, "")
    }

    // MARK: - StatsIcon Alert Type Tests

    @MainActor
    func testStatsIconReturnsCorrectIconForChargingBegan() {
        mockStatsService = MockStatsService(
            statsIcon: StatsIcon(
                name: "bolt.fill",
                color: BatteryTier.chargingBoltColor,
                effect: .pulseByLayer
            )
        )

        XCTAssertEqual(mockStatsService.statsIcon.name, "bolt.fill")
        XCTAssertEqual(mockStatsService.statsIcon.color, BatteryTier.chargingBoltColor)
        XCTAssertEqual(mockStatsService.statsIcon.effect, .pulseByLayer)
    }

    @MainActor
    func testStatsIconReturnsCorrectIconForCriticalBattery() {
        let criticalColor = Color(red: 1.0, green: 0.176, blue: 0.333)
        mockStatsService = MockStatsService(
            statsIcon: StatsIcon(name: "battery.0percent", color: criticalColor, effect: .pulseByLayer)
        )

        XCTAssertEqual(mockStatsService.statsIcon.name, "battery.0percent")
        XCTAssertEqual(mockStatsService.statsIcon.effect, .pulseByLayer)
    }

    @MainActor
    func testStatsIconReturnsCorrectIconForDeviceOverheating() {
        mockStatsService = MockStatsService(
            statsIcon: StatsIcon(
                name: "thermometer.sun.fill",
                color: Color(red: 1.0, green: 0.176, blue: 0.333),
                effect: .variableColor
            )
        )

        XCTAssertEqual(mockStatsService.statsIcon.name, "thermometer.sun.fill")
        XCTAssertEqual(mockStatsService.statsIcon.effect, .variableColor)
    }

    @MainActor
    func testStatsIconChangesWithAlertType() {
        let chargingIcon = StatsIcon(name: "bolt.fill", color: .green, effect: .pulseByLayer)
        let depletedIcon = StatsIcon(name: "battery.25percent", color: .orange, effect: .pulse)

        mockStatsService.statsIcon = chargingIcon
        XCTAssertEqual(mockStatsService.statsIcon.name, "bolt.fill")

        mockStatsService.statsIcon = depletedIcon
        XCTAssertEqual(mockStatsService.statsIcon.name, "battery.25percent")
        XCTAssertNotEqual(mockStatsService.statsIcon.effect, chargingIcon.effect)
    }

    // MARK: - BatteryTier Tests

    @MainActor
    func testBatteryTierBoundaries() {
        XCTAssertEqual(BatteryTier(percent: 0), .critical)
        XCTAssertEqual(BatteryTier(percent: 15), .critical)
        XCTAssertEqual(BatteryTier(percent: 16), .low)
        XCTAssertEqual(BatteryTier(percent: 40), .low)
        XCTAssertEqual(BatteryTier(percent: 41), .medium)
        XCTAssertEqual(BatteryTier(percent: 70), .medium)
        XCTAssertEqual(BatteryTier(percent: 71), .good)
        XCTAssertEqual(BatteryTier(percent: 99), .good)
        XCTAssertEqual(BatteryTier(percent: 100), .full)
    }

    @MainActor
    func testBatteryTierGradientColorsNotEmpty() {
        let tiers: [BatteryTier] = [.critical, .low, .medium, .good, .full]
        for tier in tiers {
            XCTAssertGreaterThanOrEqual(tier.gradientColors.count, 2, "\(tier) should have at least 2 gradient stops")
        }
    }

    // MARK: - SettingsStateValue Localization Tests

    @MainActor
    func testAllSettingsStateValuesHaveNonEmptyTitle() {
        let cases: [SettingsStateValue] = [.enabled, .disabled, .undetermined, .restricted]
        for value in cases {
            XCTAssertFalse(value.title.isEmpty, "\(value) should have a non-empty title")
        }
    }

    @MainActor
    func testSettingsStateValuesHaveUniqueTitle() {
        let cases: [SettingsStateValue] = [.enabled, .disabled, .undetermined, .restricted]
        let titles = cases.map(\.title)
        XCTAssertEqual(titles.count, Set(titles).count, "All SettingsStateValue titles should be unique")
    }
}
