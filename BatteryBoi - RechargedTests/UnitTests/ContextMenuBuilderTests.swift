//
//  ContextMenuBuilderTests.swift
//  BatteryBoi-RechargedTests
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class ContextMenuBuilderTests: XCTestCase {

    // MARK: - Helpers

    private func buildMenu(
        percentage: Int = 66,
        isCharging: Bool = false,
        autoLaunchEnabled: Bool = false,
        pinnedEnabled: Bool = false,
        sfxEnabled: Bool = true,
        isDirectDistribution: Bool = true
    ) -> NSMenu {
        let state = AppDelegate.ContextMenuState(
            percentage: percentage,
            isCharging: isCharging,
            autoLaunchEnabled: autoLaunchEnabled,
            pinnedEnabled: pinnedEnabled,
            sfxEnabled: sfxEnabled,
            isDirectDistribution: isDirectDistribution
        )
        return AppDelegate.buildContextMenu(state: state, target: NSObject())
    }

    private func findItem(_ menu: NSMenu, titleContaining text: String) -> NSMenuItem? {
        menu.items.first { $0.title.contains(text) }
    }

    // MARK: - Header Tests

    @MainActor
    func testHeaderShowsPercentageAndChargingWhenCharging() throws {
        let menu = buildMenu(percentage: 66, isCharging: true)
        let header = try XCTUnwrap(menu.items.first)

        XCTAssertTrue(header.title.contains("66%"))
        XCTAssertTrue(header.title.contains("Charging"))
    }

    @MainActor
    func testHeaderShowsPercentageWithoutChargingWhenDischarging() throws {
        let menu = buildMenu(percentage: 42, isCharging: false)
        let header = try XCTUnwrap(menu.items.first)

        XCTAssertTrue(header.title.contains("42%"))
        XCTAssertFalse(header.title.contains("Charging"))
    }

    @MainActor
    func testHeaderIsNotClickable() throws {
        let menu = buildMenu()
        let header = try XCTUnwrap(menu.items.first)

        XCTAssertFalse(header.isEnabled)
    }

    // MARK: - Toggle Checkmarks

    @MainActor
    func testLaunchAtLoginCheckmarkReflectsState() {
        let menuOn = buildMenu(autoLaunchEnabled: true)
        let menuOff = buildMenu(autoLaunchEnabled: false)

        let itemOn = findItem(menuOn, titleContaining: "Launch at Login")
        let itemOff = findItem(menuOff, titleContaining: "Launch at Login")

        XCTAssertEqual(itemOn?.state, .on)
        XCTAssertEqual(itemOff?.state, .off)
    }

    @MainActor
    func testPinnedCheckmarkReflectsState() {
        let menuOn = buildMenu(pinnedEnabled: true)
        let menuOff = buildMenu(pinnedEnabled: false)

        let itemOn = findItem(menuOn, titleContaining: "Pin to Screen")
        let itemOff = findItem(menuOff, titleContaining: "Pin to Screen")

        XCTAssertEqual(itemOn?.state, .on)
        XCTAssertEqual(itemOff?.state, .off)
    }

    @MainActor
    func testSoundEffectsCheckmarkReflectsState() {
        let menuOn = buildMenu(sfxEnabled: true)
        let menuOff = buildMenu(sfxEnabled: false)

        let itemOn = findItem(menuOn, titleContaining: "Sound Effects")
        let itemOff = findItem(menuOff, titleContaining: "Sound Effects")

        XCTAssertEqual(itemOn?.state, .on)
        XCTAssertEqual(itemOff?.state, .off)
    }

    // MARK: - Quit Item

    @MainActor
    func testQuitHasCommandQShortcut() throws {
        let menu = buildMenu()
        let nonSeparators = menu.items.filter { !$0.isSeparatorItem }
        let quitItem = try XCTUnwrap(nonSeparators.last)

        XCTAssertEqual(quitItem.keyEquivalent, "q")
        XCTAssertTrue(quitItem.keyEquivalentModifierMask.contains(.command))
    }

    // MARK: - Edge Percentages

    @MainActor
    func testBatteryAtZeroPercent() throws {
        let menu = buildMenu(percentage: 0)
        let header = try XCTUnwrap(menu.items.first)

        XCTAssertTrue(header.title.contains("0%"))
    }

    @MainActor
    func testBatteryAtHundredPercentCharging() throws {
        let menu = buildMenu(percentage: 100, isCharging: true)
        let header = try XCTUnwrap(menu.items.first)

        XCTAssertTrue(header.title.contains("100%"))
        XCTAssertTrue(header.title.contains("Charging"))
    }

    // MARK: - Check for Updates visibility

    @MainActor
    func testCheckForUpdatesHiddenOnAppStore() {
        let menu = buildMenu(isDirectDistribution: false)
        let updateItem = findItem(menu, titleContaining: "Check for Updates")

        XCTAssertNil(updateItem)
    }

    @MainActor
    func testCheckForUpdatesShownOnDirectDistribution() {
        let menu = buildMenu(isDirectDistribution: true)
        let updateItem = findItem(menu, titleContaining: "Check for Updates")

        XCTAssertNotNil(updateItem)
    }
}
