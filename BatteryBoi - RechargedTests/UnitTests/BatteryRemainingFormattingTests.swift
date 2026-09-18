@testable import BatteryBoi___Recharged
import Foundation
import Testing

@Suite("BatteryRemaining.formatted output")
@MainActor
struct BatteryRemainingFormattingTests {

    @Test
    func `hours and minutes formatted has single space separator`() {
        let remaining = BatteryRemaining(hour: 4, minute: 30)
        let result = remaining.formatted ?? ""
        #expect(!result.contains("  "))
    }

    @Test
    func `one hour one minute uses singular labels`() {
        let remaining = BatteryRemaining(hour: 1, minute: 1)
        let result = remaining.formatted ?? ""
        #expect(result.lowercased().contains("hour"))
        #expect(result.lowercased().contains("minute"))
        #expect(!result.lowercased().contains("hours"))
        #expect(!result.lowercased().contains("minutes"))
    }
}

@Suite("BatteryRemaining.formattedShort output")
@MainActor
struct BatteryRemainingFormattedShortTests {

    @Test
    func `hours and minutes produces compact format`() throws {
        let remaining = BatteryRemaining(hour: 3, minute: 45)
        let result = remaining.formattedShort
        #expect(result != nil)
        #expect(try #require(result?.contains("3")))
        #expect(try #require(result?.contains("45")))
    }

    @Test
    func `hours only omits minutes`() throws {
        let remaining = BatteryRemaining(hour: 2, minute: 0)
        let result = remaining.formattedShort
        #expect(result != nil)
        #expect(try #require(result?.contains("2")))
    }

    @Test
    func `minutes only omits hours`() throws {
        let remaining = BatteryRemaining(hour: 0, minute: 15)
        let result = remaining.formattedShort
        #expect(result != nil)
        #expect(try #require(result?.contains("15")))
    }

    @Test
    func `zero hours zero minutes returns nil`() {
        let remaining = BatteryRemaining(hour: 0, minute: 0)
        #expect(remaining.formattedShort == nil)
    }

    @Test
    func `formattedShort is shorter than formatted`() {
        let remaining = BatteryRemaining(hour: 5, minute: 30)
        guard let short = remaining.formattedShort, let full = remaining.formatted else {
            Issue.record("Both formatted variants should be non-nil for 5h 30m")
            return
        }
        #expect(short.count < full.count)
    }
}
