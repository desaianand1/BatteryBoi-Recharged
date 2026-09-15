@testable import BatteryBoi___Recharged
import Foundation
import Testing

// MARK: - Subtitle Tests

@Suite("Stats subtitle computation")
@MainActor
struct StatsSubtitleTests {

    @Test
    func `on battery with remaining shows time until empty`() {
        let remaining = BatteryRemaining(hour: 4, minute: 30)
        let result = StatsService.computeSubtitle(
            alert: nil,
            chargingState: .battery,
            percentage: 65,
            remaining: remaining,
            untilFull: nil,
            latestEventName: nil
        )
        #expect(result.contains("until empty"))
        #expect(result.contains("4"))
        #expect(result.contains("30"))
    }

    @Test
    func `on battery without remaining shows calculating`() {
        let result = StatsService.computeSubtitle(
            alert: nil,
            chargingState: .battery,
            percentage: 65,
            remaining: nil,
            untilFull: nil,
            latestEventName: nil
        )
        #expect(result.contains("until empty"))
        #expect(result.contains("Calculating"))
    }

    @Test
    func `charging with until full shows time`() throws {
        let futureDate = try #require(Calendar.current.date(byAdding: .hour, value: 2, to: Date()))
        let result = StatsService.computeSubtitle(
            alert: nil,
            chargingState: .charging,
            percentage: 65,
            remaining: nil,
            untilFull: futureDate,
            latestEventName: nil
        )
        #expect(result.contains("Fully charged at"))
    }

    @Test
    func `charging without until full shows calculating`() {
        let result = StatsService.computeSubtitle(
            alert: nil,
            chargingState: .charging,
            percentage: 65,
            remaining: nil,
            untilFull: nil,
            latestEventName: nil
        )
        #expect(result.contains("Fully charged at"))
        #expect(result.contains("Calculating"))
    }

    @Test
    func `charging at 100 percent shows fully charged`() {
        let result = StatsService.computeSubtitle(
            alert: nil,
            chargingState: .charging,
            percentage: 100,
            remaining: nil,
            untilFull: nil,
            latestEventName: nil
        )
        #expect(result.contains("fully charged"))
    }

    @Test
    func `charging complete alert shows fully charged`() {
        let result = StatsService.computeSubtitle(
            alert: .chargingComplete,
            chargingState: .charging,
            percentage: 100,
            remaining: nil,
            untilFull: nil,
            latestEventName: nil
        )
        #expect(result.contains("fully charged"))
    }

    @Test
    func `charging began alert shows charge time`() {
        let result = StatsService.computeSubtitle(
            alert: .chargingBegan,
            chargingState: .charging,
            percentage: 50,
            remaining: nil,
            untilFull: nil,
            latestEventName: nil
        )
        #expect(result.contains("Fully charged"))
    }

    @Test
    func `charging today shows fully charged at time`() throws {
        let twoHoursFromNow = try #require(Calendar.current.date(byAdding: .hour, value: 2, to: Date()))
        guard Calendar.current.isDateInToday(twoHoursFromNow) else { return }

        let result = StatsService.computeSubtitle(
            alert: nil,
            chargingState: .charging,
            percentage: 65,
            remaining: nil,
            untilFull: twoHoursFromNow,
            latestEventName: nil
        )
        #expect(result.contains("Fully charged at"))
        #expect(!result.lowercased().contains("tomorrow"))
    }

    @Test
    func `charging tomorrow shows tomorrow in subtitle`() throws {
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        guard Calendar.current.isDateInTomorrow(tomorrow) else { return }

        let result = StatsService.computeSubtitle(
            alert: nil,
            chargingState: .charging,
            percentage: 65,
            remaining: nil,
            untilFull: tomorrow,
            latestEventName: nil
        )
        #expect(result.lowercased().contains("tomorrow"))
    }

    @Test
    func `charging began alert with tomorrow date shows tomorrow`() throws {
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        guard Calendar.current.isDateInTomorrow(tomorrow) else { return }

        let result = StatsService.computeSubtitle(
            alert: .chargingBegan,
            chargingState: .charging,
            percentage: 50,
            remaining: nil,
            untilFull: tomorrow,
            latestEventName: nil
        )
        #expect(result.lowercased().contains("tomorrow"))
    }

    @Test
    func `charging with past untilFull shows calculating`() throws {
        let pastDate = try #require(Calendar.current.date(byAdding: .hour, value: -2, to: Date()))

        let result = StatsService.computeSubtitle(
            alert: nil,
            chargingState: .charging,
            percentage: 65,
            remaining: nil,
            untilFull: pastDate,
            latestEventName: nil
        )
        #expect(result.contains("Calculating"))
    }

    @Test
    func `charging stopped alert shows estimate`() {
        let remaining = BatteryRemaining(hour: 3, minute: 15)
        let result = StatsService.computeSubtitle(
            alert: .chargingStopped,
            chargingState: .battery,
            percentage: 70,
            remaining: remaining,
            untilFull: nil,
            latestEventName: nil
        )
        #expect(result.contains("until empty"))
    }

    @Test
    func `low battery alerts show cable prompt`() {
        for alert: HUDAlertTypes in [.percentFive, .percentTen, .percentTwentyFive, .percentOne] {
            let result = StatsService.computeSubtitle(
                alert: alert,
                chargingState: .battery,
                percentage: 5,
                remaining: nil,
                untilFull: nil,
                latestEventName: nil
            )
            #expect(result.contains("cable") || result.contains("grab"), "Alert \(alert) should show cable prompt")
        }
    }

    @Test
    func `overheating alert shows temperature warning`() {
        let result = StatsService.computeSubtitle(
            alert: .deviceOverheating,
            chargingState: .battery,
            percentage: 50,
            remaining: nil,
            untilFull: nil,
            latestEventName: nil
        )
        #expect(result.contains("temperature") || result.contains("deplete"))
    }

    @Test
    func `user event alert shows event name`() {
        let result = StatsService.computeSubtitle(
            alert: .userEvent,
            chargingState: .battery,
            percentage: 30,
            remaining: nil,
            untilFull: nil,
            latestEventName: "Team Meeting"
        )
        #expect(result.contains("Team Meeting"))
    }
}

// MARK: - Countdown Tests

@Suite("Stats countdown computation")
@MainActor
struct StatsCountdownTests {

    @Test
    func `hours and minutes shows abbreviated with plus`() throws {
        let remaining = BatteryRemaining(hour: 4, minute: 15)
        let result = try #require(StatsService.computeCountdown(remaining: remaining))
        #expect(result.contains("+"))
        #expect(result.contains("4"))
        #expect(result.contains("h"))
    }

    @Test
    func `hours only without plus prefix`() throws {
        let remaining = BatteryRemaining(hour: 3, minute: 0)
        let result = try #require(StatsService.computeCountdown(remaining: remaining))
        #expect(result == "3h")
    }

    @Test
    func `minutes only shows minutes`() throws {
        let remaining = BatteryRemaining(hour: 0, minute: 45)
        let result = try #require(StatsService.computeCountdown(remaining: remaining))
        #expect(result.contains("45"))
        #expect(result.contains("m"))
    }

    @Test
    func `nil remaining returns nil`() {
        let result = StatsService.computeCountdown(remaining: nil)
        #expect(result == nil)
    }

    @Test
    func `zero hours zero minutes returns nil`() {
        let remaining = BatteryRemaining(hour: 0, minute: 0)
        let result = StatsService.computeCountdown(remaining: remaining)
        #expect(result == nil)
    }
}

// MARK: - Title Tests

@Suite("Stats title computation")
@MainActor
struct StatsTitleTests {

    @Test
    func `on battery shows percentage remaining`() {
        let result = StatsService.computeTitle(
            alert: nil,
            chargingState: .battery,
            percentage: 42
        )
        #expect(result.contains("42"))
        #expect(result.contains("Remaining"))
    }

    @Test
    func `charging shows charging text`() {
        let result = StatsService.computeTitle(
            alert: nil,
            chargingState: .charging,
            percentage: 65
        )
        #expect(result.contains("Charging"))
    }

    @Test
    func `charging at 100 shows charging complete`() {
        let result = StatsService.computeTitle(
            alert: nil,
            chargingState: .charging,
            percentage: 100
        )
        #expect(result.contains("Charging Complete"))
    }

    @Test
    func `charging complete alert overrides`() {
        let result = StatsService.computeTitle(
            alert: .chargingComplete,
            chargingState: .charging,
            percentage: 100
        )
        #expect(result.contains("Charging Complete"))
    }

    @Test
    func `charging began alert shows charging`() {
        let result = StatsService.computeTitle(
            alert: .chargingBegan,
            chargingState: .charging,
            percentage: 50
        )
        #expect(result.contains("Charging"))
    }

    @Test
    func `charging stopped alert shows charger removed`() {
        let result = StatsService.computeTitle(
            alert: .chargingStopped,
            chargingState: .battery,
            percentage: 70
        )
        #expect(result.contains("Charger Removed") || result.contains("Removed"))
    }

    @Test
    func `percent alerts show percentage`() {
        let result = StatsService.computeTitle(
            alert: .percentFive,
            chargingState: .battery,
            percentage: 5
        )
        #expect(result.contains("5"))
    }

    @Test
    func `one percent alert shows power down warning`() {
        let result = StatsService.computeTitle(
            alert: .percentOne,
            chargingState: .battery,
            percentage: 1
        )
        #expect(result.contains("Power Down") || result.contains("about to"))
    }

    @Test
    func `overheating alert shows overheating`() {
        let result = StatsService.computeTitle(
            alert: .deviceOverheating,
            chargingState: .battery,
            percentage: 50
        )
        #expect(result.contains("Overheating"))
    }
}

// MARK: - Display Tests

@Suite("Stats display computation")
@MainActor
struct StatsDisplayTests {

    @Test
    func `hidden mode returns nil`() {
        let result = StatsService.computeDisplay(
            displayType: .hidden,
            chargingState: .battery,
            percentage: 50,
            countdown: "+4h",
            cycleFormatted: nil
        )
        #expect(result == nil)
    }

    @Test
    func `empty mode returns nil`() {
        let result = StatsService.computeDisplay(
            displayType: .empty,
            chargingState: .battery,
            percentage: 50,
            countdown: "+4h",
            cycleFormatted: nil
        )
        #expect(result == nil)
    }

    @Test
    func `countdown mode not charging shows countdown`() {
        let result = StatsService.computeDisplay(
            displayType: .countdown,
            chargingState: .battery,
            percentage: 50,
            countdown: "+4h",
            cycleFormatted: nil
        )
        #expect(result == "+4h")
    }

    @Test
    func `countdown mode nil countdown falls to percentage`() {
        let result = StatsService.computeDisplay(
            displayType: .countdown,
            chargingState: .battery,
            percentage: 42,
            countdown: nil,
            cycleFormatted: nil
        )
        #expect(result == "42")
    }

    @Test
    func `charging shows percentage`() {
        let result = StatsService.computeDisplay(
            displayType: .countdown,
            chargingState: .charging,
            percentage: 65,
            countdown: "+4h",
            cycleFormatted: nil
        )
        #expect(result == "65")
    }

    @Test
    func `cycle mode shows cycle count`() {
        let result = StatsService.computeDisplay(
            displayType: .cycle,
            chargingState: .battery,
            percentage: 50,
            countdown: nil,
            cycleFormatted: "342"
        )
        #expect(result == "342")
    }

    @Test
    func `percent mode shows percentage`() {
        let result = StatsService.computeDisplay(
            displayType: .percent,
            chargingState: .battery,
            percentage: 73,
            countdown: "+4h",
            cycleFormatted: nil
        )
        #expect(result == "73")
    }
}

// MARK: - Overlay Tests

@Suite("Stats overlay computation")
@MainActor
struct StatsOverlayTests {

    @Test
    func `hidden mode returns nil`() {
        let result = StatsService.computeOverlay(
            displayType: .hidden,
            chargingState: .battery,
            percentage: 50,
            countdown: "+4h"
        )
        #expect(result == nil)
    }

    @Test
    func `charging returns nil`() {
        let result = StatsService.computeOverlay(
            displayType: .countdown,
            chargingState: .charging,
            percentage: 65,
            countdown: "+4h"
        )
        #expect(result == nil)
    }

    @Test
    func `countdown mode shows percentage as overlay`() {
        let result = StatsService.computeOverlay(
            displayType: .countdown,
            chargingState: .battery,
            percentage: 42,
            countdown: "+4h"
        )
        #expect(result == "42")
    }

    @Test
    func `empty mode shows percentage as overlay`() {
        let result = StatsService.computeOverlay(
            displayType: .empty,
            chargingState: .battery,
            percentage: 42,
            countdown: nil
        )
        #expect(result == "42")
    }

    @Test
    func `percent mode shows countdown as overlay`() {
        let result = StatsService.computeOverlay(
            displayType: .percent,
            chargingState: .battery,
            percentage: 42,
            countdown: "+4h"
        )
        #expect(result == "+4h")
    }

    @Test
    func `percent mode nil countdown returns nil overlay`() {
        let result = StatsService.computeOverlay(
            displayType: .percent,
            chargingState: .battery,
            percentage: 42,
            countdown: nil
        )
        #expect(result == nil)
    }
}
