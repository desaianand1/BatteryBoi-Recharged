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
