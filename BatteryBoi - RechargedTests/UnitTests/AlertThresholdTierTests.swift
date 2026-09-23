//
//  AlertThresholdTierTests.swift
//  BatteryBoi-RechargedTests
//
//  Unit tests for alert threshold tier logic, threshold items, and HUD alert type mapping.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class AlertThresholdTierTests: XCTestCase {

    // MARK: - tier(for:) Boundary Tests

    @MainActor
    func testTier_1percent_isCritical() {
        XCTAssertEqual(AlertThresholdTier.tier(for: 1), .critical)
    }

    @MainActor
    func testTier_3percent_isCritical() {
        XCTAssertEqual(AlertThresholdTier.tier(for: 3), .critical)
    }

    @MainActor
    func testTier_4percent_isUrgent() {
        XCTAssertEqual(AlertThresholdTier.tier(for: 4), .urgent)
    }

    @MainActor
    func testTier_9percent_isUrgent() {
        XCTAssertEqual(AlertThresholdTier.tier(for: 9), .urgent)
    }

    @MainActor
    func testTier_10percent_isStandard() {
        XCTAssertEqual(AlertThresholdTier.tier(for: 10), .standard)
    }

    @MainActor
    func testTier_50percent_isStandard() {
        XCTAssertEqual(AlertThresholdTier.tier(for: 50), .standard)
    }

    // MARK: - subtitle(for:) Copy Escalation Boundaries

    @MainActor
    func testSubtitle_1percent_isPlugInImmediately() {
        let subtitle = AlertThresholdTier.subtitle(for: 1)
        XCTAssertEqual(subtitle, "Plug in immediately")
    }

    @MainActor
    func testSubtitle_3percent_isPlugInImmediately() {
        let subtitle = AlertThresholdTier.subtitle(for: 3)
        XCTAssertEqual(subtitle, "Plug in immediately")
    }

    @MainActor
    func testSubtitle_4percent_isPlugInNow() {
        let subtitle = AlertThresholdTier.subtitle(for: 4)
        XCTAssertEqual(subtitle, "Plug in now")
    }

    @MainActor
    func testSubtitle_9percent_isPlugInNow() {
        let subtitle = AlertThresholdTier.subtitle(for: 9)
        XCTAssertEqual(subtitle, "Plug in now")
    }

    @MainActor
    func testSubtitle_10percent_isPlugInSoon() {
        let subtitle = AlertThresholdTier.subtitle(for: 10)
        XCTAssertTrue(subtitle.contains("soon"), "Expected 'soon' in subtitle, got: \(subtitle)")
    }

    @MainActor
    func testSubtitle_19percent_isPlugInSoon() {
        let subtitle = AlertThresholdTier.subtitle(for: 19)
        XCTAssertTrue(subtitle.contains("soon"), "Expected 'soon' in subtitle, got: \(subtitle)")
    }

    @MainActor
    func testSubtitle_20percent_isGettingLow() {
        let subtitle = AlertThresholdTier.subtitle(for: 20)
        XCTAssertTrue(subtitle.contains("low"), "Expected 'low' in subtitle, got: \(subtitle)")
    }

    @MainActor
    func testSubtitle_50percent_isGettingLow() {
        let subtitle = AlertThresholdTier.subtitle(for: 50)
        XCTAssertTrue(subtitle.contains("low"), "Expected 'low' in subtitle, got: \(subtitle)")
    }

    // MARK: - Priority Mapping

    @MainActor
    func testPriority_criticalTier_isCritical() {
        XCTAssertEqual(AlertThresholdTier.critical.priority, .critical)
    }

    @MainActor
    func testPriority_urgentTier_isHigh() {
        XCTAssertEqual(AlertThresholdTier.urgent.priority, .high)
    }

    @MainActor
    func testPriority_standardTier_isMedium() {
        XCTAssertEqual(AlertThresholdTier.standard.priority, .medium)
    }

    // MARK: - AlertThresholdItem Safety Invariants

    @MainActor
    func testItem_1percent_isNotRemovable() {
        let item = AlertThresholdItem(percent: 1)
        XCTAssertFalse(item.isRemovable)
    }

    @MainActor
    func testItem_2percent_isRemovable() {
        let item = AlertThresholdItem(percent: 2)
        XCTAssertTrue(item.isRemovable)
    }

    @MainActor
    func testItem_id_equalsPercent() {
        let item = AlertThresholdItem(percent: 15)
        XCTAssertEqual(item.id, 15)
    }

    // MARK: - HUDAlertTypes.alertType(for:) Backward Compat

    @MainActor
    func testAlertType_1_mapsToPercentOne() {
        XCTAssertEqual(HUDAlertTypes.alertType(for: 1), .percentOne)
    }

    @MainActor
    func testAlertType_5_mapsToPercentFive() {
        XCTAssertEqual(HUDAlertTypes.alertType(for: 5), .percentFive)
    }

    @MainActor
    func testAlertType_10_mapsToPercentTen() {
        XCTAssertEqual(HUDAlertTypes.alertType(for: 10), .percentTen)
    }

    @MainActor
    func testAlertType_25_mapsToPercentTwentyFive() {
        XCTAssertEqual(HUDAlertTypes.alertType(for: 25), .percentTwentyFive)
    }

    @MainActor
    func testAlertType_15_mapsToPercentCustom15() {
        XCTAssertEqual(HUDAlertTypes.alertType(for: 15), .percentCustom(15))
    }

    // MARK: - HUDAlertTypes.sfx Critical Sound Routing

    @MainActor
    func testSfx_percentOne_isCritical() {
        XCTAssertEqual(HUDAlertTypes.percentOne.sfx, .critical)
    }

    @MainActor
    func testSfx_percentCustom2_isCritical() {
        XCTAssertEqual(HUDAlertTypes.percentCustom(2).sfx, .critical)
    }

    @MainActor
    func testSfx_percentCustom4_isLow() {
        XCTAssertEqual(HUDAlertTypes.percentCustom(4).sfx, .low)
    }

    @MainActor
    func testSfx_percentTen_isLow() {
        XCTAssertEqual(HUDAlertTypes.percentTen.sfx, .low)
    }
}
