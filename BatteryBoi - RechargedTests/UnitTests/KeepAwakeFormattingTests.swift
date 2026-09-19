@testable import BatteryBoi___Recharged
import Foundation
import Testing

@Suite("Keep Awake remaining time formatting")
struct KeepAwakeFormattingTests {

    @Test
    func `last 59 seconds clamps to 1 minute`() {
        let c = KeepAwakeFormatting.components(from: 45)
        #expect(c.hours == 0)
        #expect(c.minutes == 1)
    }

    @Test
    func `one second remaining shows 1 minute`() {
        let c = KeepAwakeFormatting.components(from: 1)
        #expect(c.hours == 0)
        #expect(c.minutes == 1)
    }

    @Test
    func `exactly 60 seconds shows 1 minute`() {
        let c = KeepAwakeFormatting.components(from: 60)
        #expect(c.hours == 0)
        #expect(c.minutes == 1)
    }

    @Test
    func `90 seconds shows 1 minute`() {
        let c = KeepAwakeFormatting.components(from: 90)
        #expect(c.hours == 0)
        #expect(c.minutes == 1)
    }

    @Test
    func `two minutes remaining`() {
        let c = KeepAwakeFormatting.components(from: 120)
        #expect(c.hours == 0)
        #expect(c.minutes == 2)
    }

    @Test
    func `28 minutes remaining`() {
        let c = KeepAwakeFormatting.components(from: 1680)
        #expect(c.hours == 0)
        #expect(c.minutes == 28)
    }

    @Test
    func `exact hour boundary`() {
        let c = KeepAwakeFormatting.components(from: 3600)
        #expect(c.hours == 1)
        #expect(c.minutes == 0)
    }

    @Test
    func `one hour twenty three minutes`() {
        let c = KeepAwakeFormatting.components(from: 4980)
        #expect(c.hours == 1)
        #expect(c.minutes == 23)
    }

    @Test
    func `two hours full duration`() {
        let c = KeepAwakeFormatting.components(from: 7200)
        #expect(c.hours == 2)
        #expect(c.minutes == 0)
    }

    @Test
    func `hour boundary with fractional seconds truncates to integer`() {
        let c = KeepAwakeFormatting.components(from: 3659.7)
        #expect(c.hours == 1)
        #expect(c.minutes == 0)
    }

    @Test
    func `just under one hour`() {
        let c = KeepAwakeFormatting.components(from: 3599)
        #expect(c.hours == 0)
        #expect(c.minutes == 59)
    }

    @Test
    func `fifteen minutes default`() {
        let c = KeepAwakeFormatting.components(from: 900)
        #expect(c.hours == 0)
        #expect(c.minutes == 15)
    }

    @Test
    func `zero seconds clamps to 1 minute`() {
        let c = KeepAwakeFormatting.components(from: 0)
        #expect(c.hours == 0)
        #expect(c.minutes == 1)
    }

    @Test
    func `sub-second value clamps to 1 minute`() {
        let c = KeepAwakeFormatting.components(from: 0.5)
        #expect(c.hours == 0)
        #expect(c.minutes == 1)
    }
}

// MARK: - Duration Seconds Mapping

@Suite("Keep Awake duration seconds mapping")
@MainActor
struct KeepAwakeDurationSecondsTests {

    @Test(arguments: [
        (KeepAwakeDuration.fifteenMinutes, TimeInterval(900)),
        (.thirtyMinutes, TimeInterval(1800)),
        (.oneHour, TimeInterval(3600)),
        (.twoHours, TimeInterval(7200)),
    ])
    func `timed durations map to correct seconds`(
        duration: KeepAwakeDuration, expected: TimeInterval
    ) {
        #expect(duration.seconds == expected)
    }

    @Test
    func `indefinite duration has no seconds value`() {
        #expect(KeepAwakeDuration.indefinite.seconds == nil)
    }
}
