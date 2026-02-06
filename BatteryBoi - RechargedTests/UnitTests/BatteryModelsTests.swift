//
//  BatteryModelsTests.swift
//  BatteryBoi-RechargedTests
//
//  Unit tests for battery model types.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class BatteryModelsTests: XCTestCase {

    // MARK: - BatteryThermalState Tests

    @MainActor
    func testThermalStateOptimal() {
        let state: BatteryThermalState = .optimal
        XCTAssertEqual(state, .optimal)
    }

    @MainActor
    func testThermalStateSuboptimal() {
        let state: BatteryThermalState = .suboptimal
        XCTAssertEqual(state, .suboptimal)
    }

    // MARK: - BatteryCondition Tests

    @MainActor
    func testBatteryConditionOptimal() {
        let condition = BatteryCondition.optimal
        XCTAssertEqual(condition.rawValue, "Normal")
    }

    @MainActor
    func testBatteryConditionSuboptimal() {
        let condition = BatteryCondition.suboptimal
        XCTAssertEqual(condition.rawValue, "Replace Soon")
    }

    @MainActor
    func testBatteryConditionMalfunctioning() {
        let condition = BatteryCondition.malfunctioning
        XCTAssertEqual(condition.rawValue, "Service Battery")
    }

    @MainActor
    func testBatteryConditionUnknown() {
        let condition = BatteryCondition.unknown
        XCTAssertEqual(condition.rawValue, "Unknown")
    }

    @MainActor
    func testBatteryConditionFromRawValue() {
        XCTAssertEqual(BatteryCondition(rawValue: "Normal"), .optimal)
        XCTAssertEqual(BatteryCondition(rawValue: "Replace Soon"), .suboptimal)
        XCTAssertEqual(BatteryCondition(rawValue: "Service Battery"), .malfunctioning)
        XCTAssertEqual(BatteryCondition(rawValue: "Unknown"), .unknown)
        XCTAssertNil(BatteryCondition(rawValue: "Invalid"))
    }

    // MARK: - BatteryCycleObject Tests

    @MainActor
    func testCycleCountNormal() {
        let cycles = BatteryCycleObject(500)
        XCTAssertEqual(cycles.numerical, 500)
        XCTAssertEqual(cycles.formatted, "500")
    }

    @MainActor
    func testCycleCountZero() {
        let cycles = BatteryCycleObject(0)
        XCTAssertEqual(cycles.numerical, 0)
        XCTAssertEqual(cycles.formatted, "0")
    }

    @MainActor
    func testCycleCountOverThousand() {
        let cycles = BatteryCycleObject(1500)
        XCTAssertEqual(cycles.numerical, 1500)
        XCTAssertEqual(cycles.formatted, "1.5k")
    }

    @MainActor
    func testCycleCountExactlyThousand() {
        let cycles = BatteryCycleObject(1000)
        XCTAssertEqual(cycles.numerical, 1000)
        XCTAssertEqual(cycles.formatted, "1.0k")
    }

    // MARK: - BatteryMetricsObject Tests

    @MainActor
    func testMetricsFromStrings() {
        let metrics = BatteryMetricsObject(cycles: "250", health: "Normal")
        XCTAssertEqual(metrics.cycles.numerical, 250)
        XCTAssertEqual(metrics.health, .optimal)
    }

    @MainActor
    func testMetricsFromInvalidString() {
        let metrics = BatteryMetricsObject(cycles: "invalid", health: "InvalidHealth")
        XCTAssertEqual(metrics.cycles.numerical, 0)
        XCTAssertEqual(metrics.health, .optimal) // Default fallback
    }

    @MainActor
    func testMetricsFromInts() {
        let metrics = BatteryMetricsObject(cycleCount: 750, condition: "Replace Soon")
        XCTAssertEqual(metrics.cycles.numerical, 750)
        XCTAssertEqual(metrics.health, .suboptimal)
    }

    // MARK: - BatteryModeType Tests

    @MainActor
    func testBatteryModeNormal() {
        let mode: BatteryModeType = .normal
        XCTAssertFalse(mode.flag)
    }

    @MainActor
    func testBatteryModeEfficient() {
        let mode: BatteryModeType = .efficient
        XCTAssertTrue(mode.flag)
    }

    @MainActor
    func testBatteryModeUnavailable() {
        let mode: BatteryModeType = .unavailable
        XCTAssertFalse(mode.flag)
    }

    // MARK: - BatteryChargingState Tests

    @MainActor
    func testChargingStateCharging() {
        let state: BatteryChargingState = .charging
        XCTAssertTrue(state.charging)
    }

    @MainActor
    func testChargingStateBattery() {
        let state: BatteryChargingState = .battery
        XCTAssertFalse(state.charging)
    }

    // MARK: - BatteryCharging Tests

    @MainActor
    func testBatteryChargingInitCharging() {
        let charging = BatteryCharging(.charging)
        XCTAssertEqual(charging.state, .charging)
        XCTAssertNotNil(charging.started)
        XCTAssertNil(charging.ended)
    }

    @MainActor
    func testBatteryChargingInitBattery() {
        let charging = BatteryCharging(.battery)
        XCTAssertEqual(charging.state, .battery)
        XCTAssertNil(charging.started)
        XCTAssertNotNil(charging.ended)
    }

    @MainActor
    func testBatteryChargingEquality() {
        let charging1 = BatteryCharging(.charging)
        let charging2 = BatteryCharging(.charging)
        let charging3 = BatteryCharging(.battery)

        // Same state should be equal
        XCTAssertEqual(charging1.state, charging2.state)
        // Different states should not be equal
        XCTAssertNotEqual(charging1.state, charging3.state)
    }

    // MARK: - BatteryEstimateObject Tests

    @MainActor
    func testBatteryEstimateInit() {
        let estimate = BatteryEstimateObject(75.0)
        XCTAssertEqual(estimate.percent, 75.0)
        XCTAssertNotNil(estimate.timestamp)
    }

    // MARK: - BatteryStyle Tests

    @MainActor
    func testBatteryStyleChunky() {
        let style: BatteryStyle = .chunky
        XCTAssertEqual(style.rawValue, "chunky")
        XCTAssertEqual(style.radius, 5)
        XCTAssertEqual(style.size.width, 32)
        XCTAssertEqual(style.size.height, 15)
        XCTAssertEqual(style.padding, 2)
    }

    @MainActor
    func testBatteryStyleBasic() {
        let style: BatteryStyle = .basic
        XCTAssertEqual(style.rawValue, "basic")
        XCTAssertEqual(style.radius, 3)
        XCTAssertEqual(style.size.width, 28)
        XCTAssertEqual(style.size.height, 13)
        XCTAssertEqual(style.padding, 1)
    }

    @MainActor
    func testBatteryStyleFromRawValue() {
        XCTAssertEqual(BatteryStyle(rawValue: "chunky"), .chunky)
        XCTAssertEqual(BatteryStyle(rawValue: "basic"), .basic)
        XCTAssertNil(BatteryStyle(rawValue: "invalid"))
    }

    // MARK: - Progress Calculation Tests

    @MainActor
    func testProgressCalculationCharging() {
        let state: BatteryChargingState = .charging
        let width: CGFloat = 100

        // When charging, progress should be at max
        let progress = state.progress(50, width: width)
        XCTAssertGreaterThan(progress, 0)
    }

    @MainActor
    func testProgressCalculationBattery() {
        let state: BatteryChargingState = .battery
        let width: CGFloat = 100

        // Battery at 50% should return proportional progress
        let progress = state.progress(50, width: width)
        XCTAssertGreaterThan(progress, 0)
        XCTAssertLessThanOrEqual(progress, width)
    }

    @MainActor
    func testProgressCalculationLowBattery() {
        let state: BatteryChargingState = .battery
        let width: CGFloat = 100

        // Very low battery should have minimum display
        let progress = state.progress(1, width: width)
        XCTAssertGreaterThan(progress, 0)
    }

    @MainActor
    func testProgressCalculationHighBattery() {
        let state: BatteryChargingState = .battery
        let width: CGFloat = 100

        // High battery (not quite 100) should cap at max display
        let progress = state.progress(99, width: width)
        XCTAssertGreaterThan(progress, 0)
        XCTAssertLessThanOrEqual(progress, width)
    }
}
