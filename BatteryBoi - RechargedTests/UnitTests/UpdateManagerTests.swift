//
//  UpdateManagerTests.swift
//  BatteryBoi-RechargedTests
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class UpdateManagerTests: XCTestCase {

    @MainActor
    func testUpdateCheckTransitionsToChecking() {
        let manager = MockUpdateManager()

        manager.updateCheck()

        XCTAssertEqual(manager.state, .checking)
    }

    @MainActor
    func testUpdateFoundSetsAvailablePayload() {
        let manager = MockUpdateManager()

        manager.simulateUpdateFound()

        XCTAssertNotNil(manager.available)
        XCTAssertEqual(manager.state, .completed)
    }

    @MainActor
    func testNoUpdateClearsAvailable() {
        let manager = MockUpdateManager()
        manager.simulateUpdateFound()

        manager.simulateNoUpdateFound()

        XCTAssertNil(manager.available)
    }

    @MainActor
    func testUpdateFailedSetsFailedState() {
        let manager = MockUpdateManager()

        manager.simulateUpdateFailed()

        XCTAssertEqual(manager.state, .failed)
    }

    @MainActor
    func testVersionDisplayFormatsCorrectly() {
        let manager = MockUpdateManager()

        XCTAssertEqual(manager.versionDisplay, "v1.0.0 (100)")
    }

    @MainActor
    func testMultipleUpdateChecksIncrementCallCount() {
        let manager = MockUpdateManager()

        manager.updateCheck()
        manager.updateCheck()

        XCTAssertEqual(manager.updateCheckCallCount, 2)
    }
}
