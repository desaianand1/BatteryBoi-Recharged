@testable import BatteryBoi___Recharged
import Foundation
import Testing

@Suite("Date.time formatting")
struct DateTimeFormattingTests {

    @Test
    func `today date has no tomorrow prefix`() {
        let twoHoursFromNow = Date(timeIntervalSinceNow: 7200)
        guard Calendar.current.isDateInToday(twoHoursFromNow) else { return }

        let result = twoHoursFromNow.time
        let prefix = "AlertChargeTomorrowPrefix".localise()
        #expect(!result.hasPrefix(prefix))
    }

    @Test
    func `tomorrow date has tomorrow prefix`() throws {
        let tomorrow = try #require(
            Calendar.current.date(byAdding: .day, value: 1, to: Date())
        )
        let result = tomorrow.time
        let prefix = "AlertChargeTomorrowPrefix".localise()
        #expect(result.hasPrefix(prefix))
    }

    @Test
    func `time string is non empty`() {
        let futureDate = Date(timeIntervalSinceNow: 3600)
        #expect(!futureDate.time.isEmpty)
    }
}
