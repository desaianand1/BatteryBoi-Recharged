@testable import BatteryBoi___Recharged
import SwiftUI
@preconcurrency import XCTest

final class BatteryMetricsExtendedTests: XCTestCase {

    // MARK: - Health Percent Calculation

    @MainActor
    func testHealthPercentNormalBattery() throws {
        let m = BatteryMetricsObject(
            cycleCount: 764, condition: "Normal",
            temperature: 31.7, voltage: 12700, amperage: -2015,
            maxCapacity: 3477, designCapacity: 4382
        )
        XCTAssertEqual(try XCTUnwrap(m.healthPercent), 79.3, accuracy: 0.1)
    }

    @MainActor
    func testHealthPercentClampedAt100WhenMaxExceedsDesign() {
        let m = BatteryMetricsObject(
            cycleCount: 10, condition: "Normal",
            temperature: 25.0, voltage: 12000, amperage: -1000,
            maxCapacity: 5000, designCapacity: 4382
        )
        XCTAssertEqual(m.healthPercent, 100.0)
    }

    @MainActor
    func testHealthPercentNilWhenDesignCapacityZero() {
        let m = BatteryMetricsObject(
            cycleCount: 100, condition: "Normal",
            temperature: 25.0, voltage: 12000, amperage: -500,
            maxCapacity: 3000, designCapacity: 0
        )
        XCTAssertNil(m.healthPercent)
    }

    // MARK: - Apple Silicon Health Priority Chain

    @MainActor
    func testHealthPercentUsesNominalChargeCapacity() throws {
        let m = BatteryMetricsObject(
            cycleCount: 200, condition: "Normal",
            temperature: 30.0, voltage: 12000, amperage: -1000,
            maxCapacity: 100, designCapacity: 8579,
            nominalChargeCapacity: 7910, appleRawMaxCapacity: 7666
        )
        XCTAssertEqual(try XCTUnwrap(m.healthPercent), 92.2, accuracy: 0.1)
    }

    @MainActor
    func testHealthPercentFallsBackToAppleRawMaxCapacity() throws {
        let m = BatteryMetricsObject(
            cycleCount: 200, condition: "Normal",
            temperature: 30.0, voltage: 12000, amperage: -1000,
            maxCapacity: 100, designCapacity: 8579,
            nominalChargeCapacity: nil, appleRawMaxCapacity: 7666
        )
        XCTAssertEqual(try XCTUnwrap(m.healthPercent), 89.4, accuracy: 0.1)
    }

    @MainActor
    func testHealthPercentNilWhenOnlyPercentageMaxCapacity() {
        let m = BatteryMetricsObject(
            cycleCount: 200, condition: "Normal",
            temperature: 30.0, voltage: 12000, amperage: -1000,
            maxCapacity: 100, designCapacity: 8579,
            nominalChargeCapacity: nil, appleRawMaxCapacity: nil
        )
        XCTAssertNil(m.healthPercent)
    }

    @MainActor
    func testHealthPercentZeroNominalFallsThrough() throws {
        let m = BatteryMetricsObject(
            cycleCount: 200, condition: "Normal",
            temperature: 30.0, voltage: 12000, amperage: -1000,
            maxCapacity: 100, designCapacity: 8579,
            nominalChargeCapacity: 0, appleRawMaxCapacity: 7666
        )
        XCTAssertEqual(try XCTUnwrap(m.healthPercent), 89.4, accuracy: 0.1)
    }

    // MARK: - Effective Max Capacity mAh

    @MainActor
    func testEffectiveMaxCapacityReturnsNominal() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: nil, amperage: nil,
            maxCapacity: 100, designCapacity: 8579,
            nominalChargeCapacity: 7910, appleRawMaxCapacity: 7666
        )
        XCTAssertEqual(m.effectiveMaxCapacityMAh, 7910)
    }

    @MainActor
    func testEffectiveMaxCapacityFallsBackToRaw() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: nil, amperage: nil,
            maxCapacity: 100, designCapacity: 8579,
            nominalChargeCapacity: nil, appleRawMaxCapacity: 7666
        )
        XCTAssertEqual(m.effectiveMaxCapacityMAh, 7666)
    }

    @MainActor
    func testEffectiveMaxCapacityNilForPercentageOnly() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: nil, amperage: nil,
            maxCapacity: 100, designCapacity: 8579,
            nominalChargeCapacity: nil, appleRawMaxCapacity: nil
        )
        XCTAssertNil(m.effectiveMaxCapacityMAh)
    }

    @MainActor
    func testEffectiveMaxCapacityReturnsMaxOnIntel() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: nil, amperage: nil,
            maxCapacity: 3477, designCapacity: 4382,
            nominalChargeCapacity: nil, appleRawMaxCapacity: nil
        )
        XCTAssertEqual(m.effectiveMaxCapacityMAh, 3477)
    }

    // MARK: - Capacity Formatted

    @MainActor
    func testCapacityFormattedUsesEffectiveCapacity() {
        let m = BatteryMetricsObject(
            cycleCount: 200, condition: "Normal",
            temperature: 30.0, voltage: 12000, amperage: -1000,
            maxCapacity: 100, designCapacity: 8579,
            nominalChargeCapacity: 7910
        )
        XCTAssertTrue(m.capacityFormatted.contains("7,910"))
        XCTAssertTrue(m.capacityFormatted.contains("8,579"))
        XCTAssertTrue(m.capacityFormatted.contains("mAh"))
        XCTAssertTrue(m.capacityFormatted.contains("capacity"))
    }

    // MARK: - Unit Conversions

    @MainActor
    func testVoltageConvertedFromMillivoltsToVolts() throws {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: 12700, amperage: nil,
            maxCapacity: 0, designCapacity: 0
        )
        XCTAssertEqual(try XCTUnwrap(m.voltage), 12.7, accuracy: 0.001)
    }

    @MainActor
    func testAmperageConvertedFromMilliampsToAmps() throws {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: nil, amperage: -2015,
            maxCapacity: 0, designCapacity: 0
        )
        XCTAssertEqual(try XCTUnwrap(m.amperage), -2.015, accuracy: 0.001)
    }

    // MARK: - Power Calculation

    @MainActor
    func testPowerWattsCalculation() throws {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: 12700, amperage: -2015,
            maxCapacity: 0, designCapacity: 0
        )
        XCTAssertEqual(try XCTUnwrap(m.powerWatts), 25.6, accuracy: 0.1)
    }

    @MainActor
    func testPowerWattsNilWhenVoltageOrAmperageNil() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: 12700, amperage: nil,
            maxCapacity: 0, designCapacity: 0
        )
        XCTAssertNil(m.powerWatts)
    }

    // MARK: - Temperature Edge Cases

    @MainActor
    func testTemperatureZeroFromIOKitTreatedAsUnavailable() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: 0.0, voltage: nil, amperage: nil,
            maxCapacity: 0, designCapacity: 0
        )
        XCTAssertNil(m.temperature)
    }

    @MainActor
    func testTemperatureNonZeroPreserved() throws {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: 31.7, voltage: nil, amperage: nil,
            maxCapacity: 0, designCapacity: 0
        )
        XCTAssertEqual(try XCTUnwrap(m.temperature), 31.7, accuracy: 0.01)
    }

    // MARK: - Temperature Status

    @MainActor
    func testTemperatureStatusNormal() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: 30.0, voltage: nil, amperage: nil,
            maxCapacity: 0, designCapacity: 0
        )
        let status = m.temperatureStatus
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.label, "Normal")
        XCTAssertEqual(status?.color, SemanticColor.success)
    }

    @MainActor
    func testTemperatureStatusWarm() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: 40.0, voltage: nil, amperage: nil,
            maxCapacity: 0, designCapacity: 0
        )
        let status = m.temperatureStatus
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.label, "Warm")
        XCTAssertEqual(status?.color, SemanticColor.warning)
    }

    @MainActor
    func testTemperatureStatusHot() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: 50.0, voltage: nil, amperage: nil,
            maxCapacity: 0, designCapacity: 0
        )
        let status = m.temperatureStatus
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.label, "Hot")
        XCTAssertEqual(status?.color, SemanticColor.error)
    }

    // MARK: - Power Status

    @MainActor
    func testPowerStatusEfficient() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: 12000, amperage: -1000,
            maxCapacity: 0, designCapacity: 0
        )
        let status = m.powerStatus
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.label, "Efficient")
        XCTAssertEqual(status?.color, SemanticColor.success)
    }

    @MainActor
    func testPowerStatusModerate() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: 12000, amperage: -2000,
            maxCapacity: 0, designCapacity: 0
        )
        let status = m.powerStatus
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.label, "Moderate")
        XCTAssertEqual(status?.color, SemanticColor.warning)
    }

    @MainActor
    func testPowerStatusHigh() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: 12000, amperage: -3000,
            maxCapacity: 0, designCapacity: 0
        )
        let status = m.powerStatus
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.label, "Heavy")
        XCTAssertEqual(status?.color, SemanticColor.error)
    }

    // MARK: - Amperage Color

    @MainActor
    func testAmperageColorChargingIsSuccess() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: nil, amperage: 1500,
            maxCapacity: 0, designCapacity: 0
        )
        XCTAssertEqual(m.amperageColor, SemanticColor.success)
    }

    @MainActor
    func testAmperageColorNormalDrainIsNeutral() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: nil, amperage: -800,
            maxCapacity: 0, designCapacity: 0
        )
        XCTAssertEqual(m.amperageColor, Color("BBTitle"))
    }

    @MainActor
    func testAmperageColorHighDrainIsWarning() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: nil, amperage: -2500,
            maxCapacity: 0, designCapacity: 0
        )
        XCTAssertEqual(m.amperageColor, SemanticColor.warning)
    }

    @MainActor
    func testAmperageColorCriticalDrainIsError() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: nil, amperage: -3500,
            maxCapacity: 0, designCapacity: 0
        )
        XCTAssertEqual(m.amperageColor, SemanticColor.error)
    }

    // MARK: - Formatting

    @MainActor
    func testPowerFormattedWithValue() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: 12700, amperage: -2015,
            maxCapacity: 0, designCapacity: 0
        )
        XCTAssertEqual(m.powerFormatted, "25.6W")
    }

    @MainActor
    func testPowerFormattedWhenNil() {
        let m = BatteryMetricsObject(cycles: "100", health: "Normal")
        XCTAssertEqual(m.powerFormatted, "—")
    }

    @MainActor
    func testCapacityFormattedWithValues() {
        let m = BatteryMetricsObject(
            cycleCount: 764, condition: "Normal",
            temperature: 31.7, voltage: 12700, amperage: -2015,
            maxCapacity: 3477, designCapacity: 4382
        )
        XCTAssertTrue(m.capacityFormatted.contains("3,477"))
        XCTAssertTrue(m.capacityFormatted.contains("4,382"))
        XCTAssertTrue(m.capacityFormatted.contains("mAh"))
        XCTAssertTrue(m.capacityFormatted.contains("capacity"))
    }

    // MARK: - Discharge Direction

    @MainActor
    func testIsDischargingWhenAmperageNegative() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: nil, amperage: -1500,
            maxCapacity: 0, designCapacity: 0
        )
        XCTAssertTrue(m.isDischarging)
    }

    @MainActor
    func testIsNotDischargingWhenAmperagePositive() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: nil, amperage: 1200,
            maxCapacity: 0, designCapacity: 0
        )
        XCTAssertFalse(m.isDischarging)
    }

    @MainActor
    func testIsDischargingDefaultsToTrueWhenAmperageNil() {
        let m = BatteryMetricsObject(cycles: "0", health: "Normal")
        XCTAssertTrue(m.isDischarging)
    }

    // MARK: - Condition Display Name

    @MainActor
    func testConditionDisplayNames() {
        XCTAssertEqual(BatteryCondition.optimal.displayName, "Good")
        XCTAssertEqual(BatteryCondition.suboptimal.displayName, "Fair")
        XCTAssertEqual(BatteryCondition.malfunctioning.displayName, "Service")
        XCTAssertEqual(BatteryCondition.unknown.displayName, "Unknown")
    }

    // MARK: - Charging Power Status

    @MainActor
    func testChargingPowerStatusSlowBelow30W() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: 20000, amperage: 1000,
            maxCapacity: 0, designCapacity: 0
        )
        let status = m.powerStatusForState(isCharging: true)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.label, "Slow")
        XCTAssertEqual(status?.color, SemanticColor.warning)
    }

    @MainActor
    func testChargingPowerStatusNormal30To60W() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: 20000, amperage: 2000,
            maxCapacity: 0, designCapacity: 0
        )
        let status = m.powerStatusForState(isCharging: true)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.label, "Normal")
        XCTAssertEqual(status?.color, SemanticColor.success)
    }

    @MainActor
    func testChargingPowerStatusFastAbove60W() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: 20000, amperage: 3500,
            maxCapacity: 0, designCapacity: 0
        )
        let status = m.powerStatusForState(isCharging: true)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.label, "Fast")
        XCTAssertEqual(status?.color, SemanticColor.success)
    }

    @MainActor
    func testDischargePowerStatusMatchesLegacy() {
        let m = BatteryMetricsObject(
            cycleCount: 0, condition: "Normal",
            temperature: nil, voltage: 12000, amperage: -1000,
            maxCapacity: 0, designCapacity: 0
        )
        let legacy = m.powerStatus
        let explicit = m.powerStatusForState(isCharging: false)
        XCTAssertEqual(legacy?.label, explicit?.label)
        XCTAssertEqual(legacy?.color, explicit?.color)
    }

    // MARK: - Backward Compatibility

    @MainActor
    func testLegacyInitDefaultsExtendedFieldsToNil() {
        let m = BatteryMetricsObject(cycleCount: 500, condition: "Normal")
        XCTAssertNil(m.temperature)
        XCTAssertNil(m.voltage)
        XCTAssertNil(m.amperage)
        XCTAssertNil(m.maxCapacity)
        XCTAssertNil(m.designCapacity)
        XCTAssertNil(m.nominalChargeCapacity)
        XCTAssertNil(m.appleRawMaxCapacity)
        XCTAssertNil(m.healthPercent)
        XCTAssertEqual(m.cycles.numerical, 500)
        XCTAssertEqual(m.health, .optimal)
    }
}
