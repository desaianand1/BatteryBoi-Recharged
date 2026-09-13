@testable import BatteryBoi___Recharged
import Foundation
import Testing

@Suite("Battery remaining time calculation")
@MainActor
struct BuildRemainingTests {

    @Test
    func `nil minutes and nil depletion returns nil`() {
        let result = BatteryService.buildRemaining(
            fromMinutes: nil,
            depletionAverage: nil,
            percentage: 50
        )
        #expect(result == nil)
    }

    @Test
    func `valid minutes returns correct hours and minutes`() throws {
        let result = try #require(BatteryService.buildRemaining(
            fromMinutes: 150,
            depletionAverage: nil,
            percentage: 50
        ))
        #expect(result.hours == 2)
        #expect(result.minutes == 30)
    }

    @Test
    func `nil minutes with valid depletion computes remaining`() throws {
        let rate = 60.0
        let percentage = 50.0
        let result = try #require(BatteryService.buildRemaining(
            fromMinutes: nil,
            depletionAverage: rate,
            percentage: percentage
        ))
        #expect(result.hours != nil)
        #expect(result.minutes != nil)
    }

    @Test
    func `nil minutes with depletion producing zero returns nil`() {
        let result = BatteryService.buildRemaining(
            fromMinutes: nil,
            depletionAverage: 0.0,
            percentage: 0.0
        )
        #expect(result == nil)
    }

    @Test
    func `iokit minutes preferred over depletion average`() throws {
        let result = try #require(BatteryService.buildRemaining(
            fromMinutes: 120,
            depletionAverage: 9999.0,
            percentage: 50
        ))
        #expect(result.hours == 2)
        #expect(result.minutes == 0)
    }

    @Test
    func `zero minutes returns nil`() {
        let result = BatteryService.buildRemaining(
            fromMinutes: 0,
            depletionAverage: nil,
            percentage: 50
        )
        #expect(result == nil)
    }

    @Test
    func `negative minutes returns nil without depletion`() {
        let result = BatteryService.buildRemaining(
            fromMinutes: -5,
            depletionAverage: nil,
            percentage: 50
        )
        #expect(result == nil)
    }

    @Test
    func `negative minutes falls to depletion average`() throws {
        let result = try #require(BatteryService.buildRemaining(
            fromMinutes: -1,
            depletionAverage: 120.0,
            percentage: 50
        ))
        #expect(result.hours != nil || result.minutes != nil)
    }

    @Test
    func `exact hour boundary has zero minutes`() throws {
        let result = try #require(BatteryService.buildRemaining(
            fromMinutes: 60,
            depletionAverage: nil,
            percentage: 50
        ))
        #expect(result.hours == 1)
        #expect(result.minutes == 0)
    }

    @Test
    func `minutes only under one hour`() throws {
        let result = try #require(BatteryService.buildRemaining(
            fromMinutes: 45,
            depletionAverage: nil,
            percentage: 50
        ))
        #expect(result.hours == 0)
        #expect(result.minutes == 45)
    }
}
