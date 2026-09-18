@testable import BatteryBoi___Recharged
import SwiftUI
import Testing

// MARK: - BatteryDisplayHelpers

@Suite("BatteryDisplayHelpers")
@MainActor
struct BatteryDisplayHelpersTests {

    // MARK: - batterySummaryAdvisory boundaries

    @Test
    func `advisory nil returns unavailable`() {
        let result = BatteryDisplayHelpers.batterySummaryAdvisory(nil)
        #expect(result == "AboutBatterySummaryUnavailable".localise())
    }

    @Test
    func `advisory below 70 returns poor`() {
        let result = BatteryDisplayHelpers.batterySummaryAdvisory(69.9)
        #expect(result == "AboutBatterySummaryPoor".localise())
    }

    @Test
    func `advisory at 70 returns fair`() {
        let result = BatteryDisplayHelpers.batterySummaryAdvisory(70)
        #expect(result == "AboutBatterySummaryFair".localise())
    }

    @Test
    func `advisory at 79 returns fair`() {
        let result = BatteryDisplayHelpers.batterySummaryAdvisory(79.9)
        #expect(result == "AboutBatterySummaryFair".localise())
    }

    @Test
    func `advisory at 80 returns normal`() {
        let result = BatteryDisplayHelpers.batterySummaryAdvisory(80)
        #expect(result == "AboutBatterySummaryNormal".localise())
    }

    @Test
    func `advisory at 89 returns normal`() {
        let result = BatteryDisplayHelpers.batterySummaryAdvisory(89.9)
        #expect(result == "AboutBatterySummaryNormal".localise())
    }

    @Test
    func `advisory at 90 returns great`() {
        let result = BatteryDisplayHelpers.batterySummaryAdvisory(90)
        #expect(result == "AboutBatterySummaryGreat".localise())
    }

    // MARK: - batterySummaryColor boundaries

    @Test
    func `color nil returns subtitle`() {
        let result = BatteryDisplayHelpers.batterySummaryColor(nil)
        #expect(result == Color("BBSubtitle"))
    }

    @Test
    func `color below 70 returns error`() {
        let result = BatteryDisplayHelpers.batterySummaryColor(69.9)
        #expect(result == SemanticColor.error)
    }

    @Test
    func `color at 70 returns warning`() {
        let result = BatteryDisplayHelpers.batterySummaryColor(70)
        #expect(result == SemanticColor.warning)
    }

    @Test
    func `color at 80 returns subtitle`() {
        let result = BatteryDisplayHelpers.batterySummaryColor(80)
        #expect(result == Color("BBSubtitle"))
    }

    // MARK: - thermometerIcon boundaries

    @Test
    func `thermometer nil returns medium`() {
        #expect(BatteryDisplayHelpers.thermometerIcon(for: nil) == "thermometer.medium")
    }

    @Test
    func `thermometer below 35 returns low`() {
        #expect(BatteryDisplayHelpers.thermometerIcon(for: 34.9) == "thermometer.low")
    }

    @Test
    func `thermometer at 35 returns medium`() {
        #expect(BatteryDisplayHelpers.thermometerIcon(for: 35) == "thermometer.medium")
    }

    @Test
    func `thermometer at 45 returns medium`() {
        #expect(BatteryDisplayHelpers.thermometerIcon(for: 45) == "thermometer.medium")
    }

    @Test
    func `thermometer above 45 returns high`() {
        #expect(BatteryDisplayHelpers.thermometerIcon(for: 45.1) == "thermometer.high")
    }

    // MARK: - macBatterySubtitle states

    @Test
    func `subtitle fully charged`() {
        let result = BatteryDisplayHelpers.macBatterySubtitle(
            percentage: 100,
            chargingState: .charging,
            untilFull: nil,
            remaining: nil
        )
        #expect(result == "DashboardFullyChargedLabel".localise())
    }

    @Test
    func `subtitle charging with estimate`() {
        let futureDate = Date(timeIntervalSinceNow: 3600)
        let result = BatteryDisplayHelpers.macBatterySubtitle(
            percentage: 50,
            chargingState: .charging,
            untilFull: futureDate,
            remaining: nil
        )
        let chargingLabel = "DashboardChargingLabel".localise()
        #expect(result.contains(chargingLabel))
        #expect(result.contains("·"))
    }

    @Test
    func `subtitle charging without estimate`() {
        let result = BatteryDisplayHelpers.macBatterySubtitle(
            percentage: 50,
            chargingState: .charging,
            untilFull: nil,
            remaining: nil
        )
        #expect(result == "DashboardChargingLabel".localise())
    }

    @Test
    func `subtitle discharging with estimate`() {
        let remaining = BatteryRemaining(hour: 3, minute: 30)
        let result = BatteryDisplayHelpers.macBatterySubtitle(
            percentage: 80,
            chargingState: .battery,
            untilFull: nil,
            remaining: remaining
        )
        let batteryLabel = "DashboardOnBatteryLabel".localise()
        #expect(result.contains(batteryLabel))
        #expect(result.contains("·"))
    }

    @Test
    func `subtitle discharging without estimate`() {
        let result = BatteryDisplayHelpers.macBatterySubtitle(
            percentage: 80,
            chargingState: .battery,
            untilFull: nil,
            remaining: nil
        )
        #expect(result == "DashboardOnBatteryLabel".localise())
    }
}

// MARK: - BatteryTier Boundaries

@Suite("BatteryTier boundaries")
@MainActor
struct BatteryTierBoundaryTests {

    @Test
    func `negative percent is critical`() {
        #expect(BatteryTier(percent: -1) == .critical)
    }

    @Test
    func `zero is critical`() {
        #expect(BatteryTier(percent: 0) == .critical)
    }

    @Test
    func `fifteen is critical`() {
        #expect(BatteryTier(percent: 15) == .critical)
    }

    @Test
    func `sixteen is low`() {
        #expect(BatteryTier(percent: 16) == .low)
    }

    @Test
    func `forty is low`() {
        #expect(BatteryTier(percent: 40) == .low)
    }

    @Test
    func `forty one is medium`() {
        #expect(BatteryTier(percent: 41) == .medium)
    }

    @Test
    func `seventy is medium`() {
        #expect(BatteryTier(percent: 70) == .medium)
    }

    @Test
    func `seventy one is good`() {
        #expect(BatteryTier(percent: 71) == .good)
    }

    @Test
    func `ninety nine is good`() {
        #expect(BatteryTier(percent: 99) == .good)
    }

    @Test
    func `hundred is full`() {
        #expect(BatteryTier(percent: 100) == .full)
    }

    @Test
    func `over hundred is full`() {
        #expect(BatteryTier(percent: 101) == .full)
    }
}
