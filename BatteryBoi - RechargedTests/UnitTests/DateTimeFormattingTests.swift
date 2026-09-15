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
        #expect(!result.lowercased().contains("tomorrow"))
    }

    @Test
    func `tomorrow date returns bare time without day prefix`() throws {
        let tomorrow = try #require(
            Calendar.current.date(byAdding: .day, value: 1, to: Date())
        )
        let result = tomorrow.time
        #expect(!result.isEmpty)
        #expect(!result.lowercased().contains("tomorrow"))
    }

    @Test
    func `time string is non empty`() {
        let futureDate = Date(timeIntervalSinceNow: 3600)
        #expect(!futureDate.time.isEmpty)
    }
}

// MARK: - Relative Timestamp Tests

@Suite("Date.formatted relative timestamps")
struct RelativeTimestampTests {

    @Test
    func `one hour ago shows hour label`() throws {
        let oneHourAgo = try #require(Calendar.current.date(byAdding: .hour, value: -1, to: Date()))
        let result = oneHourAgo.formatted
        #expect(result.contains("1"))
        #expect(result.lowercased().contains("hour"))
    }

    @Test
    func `one day ago shows day label`() throws {
        let oneDayAgo = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        let result = oneDayAgo.formatted
        #expect(result.contains("1"))
        #expect(result.lowercased().contains("day"))
    }

    @Test
    func `under one hour shows now label`() throws {
        let thirtyMinAgo = try #require(Calendar.current.date(byAdding: .minute, value: -30, to: Date()))
        let result = thirtyMinAgo.formatted
        #expect(result == "TimestampNowLabel".localise())
    }
}
