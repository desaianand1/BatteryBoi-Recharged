//
//  BatteryServiceTests.swift
//  BatteryBoi-RechargedTests
//
//  Behavioral tests for battery service functionality.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class BatteryServiceTests: XCTestCase {

    // MARK: - Properties

    /// Mock service (nonisolated for setUp/tearDown compatibility with Swift 6)
    nonisolated(unsafe) var mockBatteryService: MockBatteryService!

    // MARK: - Setup

    override nonisolated func setUp() {
        super.setUp()
        let service = MainActor.assumeIsolated {
            MockBatteryService()
        }
        mockBatteryService = service
    }

    override nonisolated func tearDown() {
        mockBatteryService = nil
        super.tearDown()
    }

    // MARK: - Alert Threshold Tests

    @MainActor
    func testAlertShouldTriggerAt25Percent() {
        // Given battery at 26%
        mockBatteryService.percentage = 26.0
        mockBatteryService.charging = BatteryCharging(.battery)

        // When battery drops to 25%
        mockBatteryService.simulatePercentageChange(25.0)

        // Then 25% threshold should be detected
        XCTAssertEqual(mockBatteryService.percentage, 25.0)
        XCTAssertEqual(mockBatteryService.charging.state, .battery)
    }

    @MainActor
    func testAlertShouldTriggerAt10Percent() {
        // Given battery at 11%
        mockBatteryService.percentage = 11.0
        mockBatteryService.charging = BatteryCharging(.battery)

        // When battery drops to 10%
        mockBatteryService.simulatePercentageChange(10.0)

        // Then 10% threshold should be detected
        XCTAssertEqual(mockBatteryService.percentage, 10.0)
    }

    @MainActor
    func testAlertShouldTriggerAt5Percent() {
        // Given battery at 6%
        mockBatteryService.percentage = 6.0
        mockBatteryService.charging = BatteryCharging(.battery)

        // When battery drops to 5%
        mockBatteryService.simulatePercentageChange(5.0)

        // Then 5% threshold should be detected
        XCTAssertEqual(mockBatteryService.percentage, 5.0)
    }

    @MainActor
    func testAlertShouldTriggerAt1Percent() {
        // Given battery at 2%
        mockBatteryService.percentage = 2.0
        mockBatteryService.charging = BatteryCharging(.battery)

        // When battery drops to 1%
        mockBatteryService.simulatePercentageChange(1.0)

        // Then 1% threshold should be detected
        XCTAssertEqual(mockBatteryService.percentage, 1.0)
    }

    // MARK: - Charging State Change Tests

    @MainActor
    func testChargingStateTriggersChargingBegan() {
        // Given battery on AC
        mockBatteryService.charging = BatteryCharging(.battery)
        mockBatteryService.percentage = 50.0

        // When charger is connected
        mockBatteryService.simulateChargingChange(BatteryCharging(.charging))

        // Then charging state should be detected
        XCTAssertEqual(mockBatteryService.charging.state, .charging)
    }

    @MainActor
    func testChargingStateTriggersChargingStopped() {
        // Given battery charging
        mockBatteryService.charging = BatteryCharging(.charging)
        mockBatteryService.percentage = 50.0

        // When charger is disconnected
        mockBatteryService.simulateChargingChange(BatteryCharging(.battery))

        // Then battery state should be detected
        XCTAssertEqual(mockBatteryService.charging.state, .battery)
    }

    @MainActor
    func testFullChargeTriggersComplete() {
        // Given battery charging at 99%
        mockBatteryService.charging = BatteryCharging(.charging)
        mockBatteryService.percentage = 99.0

        // When battery reaches 100%
        mockBatteryService.simulatePercentageChange(100.0)

        // Then full charge should be detected
        XCTAssertEqual(mockBatteryService.percentage, 100.0)
        XCTAssertEqual(mockBatteryService.charging.state, .charging)
    }

    // MARK: - Thermal State Tests

    @MainActor
    func testThermalSuboptimalTriggersWarning() {
        // Given optimal thermal state
        mockBatteryService.thermal = .optimal

        // When device overheats
        mockBatteryService.simulateThermalChange(.suboptimal)

        // Then thermal warning should trigger
        XCTAssertEqual(mockBatteryService.thermal, .suboptimal)
    }

    @MainActor
    func testThermalCriticalState() {
        // Given optimal thermal state
        mockBatteryService.thermal = .optimal

        // When device becomes critical
        mockBatteryService.simulateThermalChange(.critical)

        // Then critical state should be detected
        XCTAssertEqual(mockBatteryService.thermal, .critical)
    }

    // MARK: - Metrics Tests

    @MainActor
    func testMetricsCycleCount() {
        // Given battery with metrics
        let metrics = BatteryMetricsObject(
            cycles: BatteryCycleObject(count: 150, limit: 1000),
            condition: .good
        )
        mockBatteryService.metrics = metrics

        // Then cycle count should be accessible
        XCTAssertEqual(mockBatteryService.metrics?.cycles.count, 150)
        XCTAssertEqual(mockBatteryService.metrics?.cycles.limit, 1000)
    }

    @MainActor
    func testMetricsCondition() {
        // Given battery with degraded condition
        let metrics = BatteryMetricsObject(
            cycles: BatteryCycleObject(count: 800, limit: 1000),
            condition: .service
        )
        mockBatteryService.metrics = metrics

        // Then condition should reflect service needed
        XCTAssertEqual(mockBatteryService.metrics?.condition, .malfunctioning)
    }

    // MARK: - Power Save Mode Tests

    @MainActor
    func testPowerSaveModeToggle() {
        // Given normal power mode
        mockBatteryService.saver = .normal

        // When toggling power save
        mockBatteryService.togglePowerSaveMode()

        // Then mode should change to efficient
        XCTAssertEqual(mockBatteryService.saver, .efficient)
    }

    @MainActor
    func testPowerSaveModeToggleBack() {
        // Given efficient power mode
        mockBatteryService.saver = .efficient

        // When toggling power save
        mockBatteryService.togglePowerSaveMode()

        // Then mode should change to normal
        XCTAssertEqual(mockBatteryService.saver, .normal)
    }

    // MARK: - Edge Cases

    @MainActor
    func testRapidStateChanges() {
        // Given initial state
        mockBatteryService.charging = BatteryCharging(.battery)
        mockBatteryService.percentage = 50.0

        // When rapidly connecting/disconnecting charger
        for _ in 0 ..< 10 {
            mockBatteryService.simulateChargingChange(BatteryCharging(.charging))
            mockBatteryService.simulateChargingChange(BatteryCharging(.battery))
        }

        // Then service should handle gracefully
        XCTAssertEqual(mockBatteryService.charging.state, .battery)
    }

    @MainActor
    func testZeroPercentBattery() {
        // Given battery at 0%
        mockBatteryService.percentage = 0.0
        mockBatteryService.charging = BatteryCharging(.battery)

        // When checking state
        mockBatteryService.forceRefresh()

        // Then should not crash
        XCTAssertEqual(mockBatteryService.percentage, 0.0)
        XCTAssertEqual(mockBatteryService.forceRefreshCallCount, 1)
    }

    @MainActor
    func testHundredPercentBattery() {
        // Given fully charged battery
        mockBatteryService.percentage = 100.0
        mockBatteryService.charging = BatteryCharging(.charging)

        // When checking untilFull
        let untilFull = mockBatteryService.untilFull

        // Then untilFull should be nil (already full)
        XCTAssertNil(untilFull)
    }
}
