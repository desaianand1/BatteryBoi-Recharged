@testable import BatteryBoi___Recharged
import Foundation
import Testing

@Suite("Charge completion date calculation")
@MainActor
struct PowerUntilFullTests {

    @Test
    func `returns nil at full charge`() {
        let result = BatteryService.chargeCompletionDate(
            percentage: 100,
            ioKitMinutes: 10,
            storedSecondsPerPercent: nil
        )
        #expect(result == nil)
    }

    @Test
    func `uses IO kit when available`() throws {
        let result = try #require(BatteryService.chargeCompletionDate(
            percentage: 50,
            ioKitMinutes: 120,
            storedSecondsPerPercent: nil
        ))
        #expect(abs(result.timeIntervalSinceNow - 7200) < 2)
    }

    @Test
    func `io kit zero falls to stored rate`() throws {
        let result = try #require(BatteryService.chargeCompletionDate(
            percentage: 80,
            ioKitMinutes: 0,
            storedSecondsPerPercent: 120.0
        ))
        #expect(abs(result.timeIntervalSinceNow - 2400) < 2)
    }

    @Test
    func `io kit nil falls to stored rate`() throws {
        let result = try #require(BatteryService.chargeCompletionDate(
            percentage: 80,
            ioKitMinutes: nil,
            storedSecondsPerPercent: 120.0
        ))
        #expect(abs(result.timeIntervalSinceNow - 2400) < 2)
    }

    @Test
    func `stored rate exceeding cap returns nil`() {
        let result = BatteryService.chargeCompletionDate(
            percentage: 95,
            ioKitMinutes: nil,
            storedSecondsPerPercent: 7440.0
        )
        #expect(result == nil)
    }

    @Test
    func `stored rate nil returns nil`() {
        let result = BatteryService.chargeCompletionDate(
            percentage: 50,
            ioKitMinutes: nil,
            storedSecondsPerPercent: nil
        )
        #expect(result == nil)
    }

    @Test
    func `negative IO kit minutes falls to stored rate`() throws {
        let result = try #require(BatteryService.chargeCompletionDate(
            percentage: 50,
            ioKitMinutes: -1,
            storedSecondsPerPercent: 60.0
        ))
        #expect(abs(result.timeIntervalSinceNow - 3000) < 2)
    }

    @Test
    func `io kit preferred over stored rate`() throws {
        let result = try #require(BatteryService.chargeCompletionDate(
            percentage: 50,
            ioKitMinutes: 30,
            storedSecondsPerPercent: 999.0
        ))
        #expect(abs(result.timeIntervalSinceNow - 1800) < 2)
    }

    @Test
    func `near full charge small estimate`() throws {
        let result = try #require(BatteryService.chargeCompletionDate(
            percentage: 99,
            ioKitMinutes: nil,
            storedSecondsPerPercent: 60.0
        ))
        #expect(abs(result.timeIntervalSinceNow - 60) < 2)
    }

    @Test
    func `stored rate at exact cap boundary`() throws {
        let result = try #require(BatteryService.chargeCompletionDate(
            percentage: 90,
            ioKitMinutes: nil,
            storedSecondsPerPercent: 300.0
        ))
        #expect(abs(result.timeIntervalSinceNow - 3000) < 2)
    }

    @Test
    func `stored rate just over cap returns nil`() {
        let result = BatteryService.chargeCompletionDate(
            percentage: 90,
            ioKitMinutes: nil,
            storedSecondsPerPercent: 301.0
        )
        #expect(result == nil)
    }
}
