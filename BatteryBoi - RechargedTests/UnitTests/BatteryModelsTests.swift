//
//  BatteryModelsTests.swift
//  BatteryBoi-RechargedTests
//
//  Unit tests for battery model types.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class BatteryModelsTests: XCTestCase {

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

    // MARK: - Progress Clamping Tests

    @MainActor
    func testProgressAt0PercentClampsToMinimum() {
        let width: CGFloat = 100
        let adjusted = width - Constants.Progress.batteryBarPadding
        let expected = CGFloat(Constants.Progress.lowBatteryMinDisplay / 100) * adjusted

        let progress = BatteryChargingState.battery.progress(0.1, width: width)

        XCTAssertEqual(progress, expected, accuracy: 0.01)
    }

    @MainActor
    func testProgressAt5PercentClampsToMinimum() {
        let width: CGFloat = 100
        let adjusted = width - Constants.Progress.batteryBarPadding
        let expected = CGFloat(Constants.Progress.lowBatteryMinDisplay / 100) * adjusted

        let progress = BatteryChargingState.battery.progress(5, width: width)

        XCTAssertEqual(progress, expected, accuracy: 0.01)
    }

    @MainActor
    func testProgressAt50PercentIsLinear() {
        let width: CGFloat = 100
        let adjusted = width - Constants.Progress.batteryBarPadding
        let expected = CGFloat(50.0 / 100) * adjusted

        let progress = BatteryChargingState.battery.progress(50, width: width)

        XCTAssertEqual(progress, expected, accuracy: 0.01)
    }

    @MainActor
    func testProgressAt99PercentClampsToMaximum() {
        let width: CGFloat = 100
        let adjusted = width - Constants.Progress.batteryBarPadding
        let expected = CGFloat(Constants.Progress.highBatteryMaxDisplay / 100) * adjusted

        let progress = BatteryChargingState.battery.progress(99, width: width)

        XCTAssertEqual(progress, expected, accuracy: 0.01)
    }

    @MainActor
    func testProgressChargingAlwaysReturnsFullWidth() {
        let width: CGFloat = 100
        let adjusted = width - Constants.Progress.batteryBarPadding

        let progress = BatteryChargingState.charging.progress(50, width: width)

        XCTAssertEqual(progress, adjusted, accuracy: 0.01)
    }

    // MARK: - BatteryRemaining Tests

    @MainActor
    func testRemainingHoursAndMinutes() throws {
        let remaining = BatteryRemaining(hour: 4, minute: 30)
        XCTAssertEqual(remaining.hours, 4)
        XCTAssertEqual(remaining.minutes, 30)
        let formatted = try XCTUnwrap(remaining.formatted)
        XCTAssertTrue(formatted.contains("4"))
        XCTAssertTrue(formatted.contains("30"))
    }

    @MainActor
    func testRemainingHoursOnly() throws {
        let remaining = BatteryRemaining(hour: 2, minute: 0)
        XCTAssertEqual(remaining.hours, 2)
        XCTAssertEqual(remaining.minutes, 0)
        let formatted = try XCTUnwrap(remaining.formatted)
        XCTAssertTrue(formatted.contains("2"))
    }

    @MainActor
    func testRemainingMinutesOnly() throws {
        let remaining = BatteryRemaining(hour: 0, minute: 45)
        XCTAssertEqual(remaining.hours, 0)
        XCTAssertEqual(remaining.minutes, 45)
        let formatted = try XCTUnwrap(remaining.formatted)
        XCTAssertTrue(formatted.contains("45"))
    }

    @MainActor
    func testRemainingZeroZeroFormattedIsNil() {
        let remaining = BatteryRemaining(hour: 0, minute: 0)
        XCTAssertNil(remaining.formatted)
    }

    @MainActor
    func testRemainingEqualityByHoursAndMinutes() {
        let a = BatteryRemaining(hour: 2, minute: 30)
        let b = BatteryRemaining(hour: 2, minute: 30)
        let c = BatteryRemaining(hour: 3, minute: 30)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    @MainActor
    func testRemainingEqualityIgnoresDate() {
        let a = BatteryRemaining(hour: 1, minute: 0)
        // Creating another instance a moment later — dates differ but hours/minutes match
        let b = BatteryRemaining(hour: 1, minute: 0)
        XCTAssertEqual(a, b)
    }
}
