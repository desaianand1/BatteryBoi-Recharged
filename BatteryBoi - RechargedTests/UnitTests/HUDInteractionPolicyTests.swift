@testable import BatteryBoi___Recharged
import Foundation
import Testing

// MARK: - Alert Delivery Policy

@Suite("HUD interaction policy — alert delivery")
@MainActor
struct AlertDeliveryPolicyTests {

    @Test
    func `hidden state always delivers`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .chargingBegan, currentState: .hidden, currentAlert: nil
        )
        #expect(result == .deliver)
    }

    @Test
    func `hidden state delivers regardless of alert type`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .userEvent, currentState: .hidden, currentAlert: nil
        )
        #expect(result == .deliver)
    }

    @Test
    func `progress state always queues`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .percentOne, currentState: .progress, currentAlert: nil
        )
        #expect(result == .queue)
    }

    @Test
    func `progress queues even critical alerts`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .deviceOverheating, currentState: .progress, currentAlert: nil
        )
        #expect(result == .queue)
    }

    @Test
    func `detailed state queues alerts to avoid interrupting interaction`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .chargingBegan, currentState: .detailed, currentAlert: .userInitiated
        )
        #expect(result == .queue)
    }

    @Test
    func `detailed queues even critical alerts`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .percentOne, currentState: .detailed, currentAlert: nil
        )
        #expect(result == .queue)
    }

    @Test
    func `dismissed queues high priority alerts`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .percentFive, currentState: .dismissed, currentAlert: nil
        )
        #expect(result == .queue)
    }

    @Test
    func `dismissed queues critical alerts`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .percentOne, currentState: .dismissed, currentAlert: nil
        )
        #expect(result == .queue)
    }

    @Test
    func `dismissed suppresses medium priority alerts`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .chargingBegan, currentState: .dismissed, currentAlert: nil
        )
        #expect(result == .suppress)
    }

    @Test
    func `dismissed suppresses low priority alerts`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .userEvent, currentState: .dismissed, currentAlert: nil
        )
        #expect(result == .suppress)
    }

    // MARK: - Revealed State Nuances

    @Test
    func `revealed delivers when no current alert`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .userInitiated, currentState: .revealed, currentAlert: nil
        )
        #expect(result == .deliver)
    }

    @Test
    func `revealed queues lower priority than current`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .userEvent, currentState: .revealed, currentAlert: .percentFive
        )
        #expect(result == .queue)
    }

    @Test
    func `revealed flashes flashable alert at equal or higher priority`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .chargingBegan, currentState: .revealed, currentAlert: .deviceConnected
        )
        if case .flash = result {
            // expected
        } else {
            Issue.record("Expected .flash, got \(result)")
        }
    }

    @Test
    func `revealed delivers non-flashable alert at equal or higher priority`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .percentOne, currentState: .revealed, currentAlert: .chargingBegan
        )
        #expect(result == .deliver)
    }

    @Test
    func `revealed delivers non-flashable alert with no flash mapping`() {
        let result = HUDInteractionPolicy.shouldDeliverAlert(
            .deviceConnected, currentState: .revealed, currentAlert: .userEvent
        )
        #expect(result == .deliver)
    }
}

// MARK: - Dismiss Policy

@Suite("HUD interaction policy — dismiss decisions")
@MainActor
struct DismissPolicyTests {

    let protectedAge: TimeInterval = 0.5
    let unprotectedAge: TimeInterval = RevealTiming.totalReveal + 1.0

    // MARK: - Timeout Trigger

    @Test
    func `timeout blocked during progress`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .timeout, currentState: .progress, revealAge: self.unprotectedAge
        )
        #expect(allowed == false)
    }

    @Test
    func `timeout blocked during detailed`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .timeout, currentState: .detailed, revealAge: self.unprotectedAge
        )
        #expect(allowed == false)
    }

    @Test
    func `timeout blocked during reveal protection window`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .timeout, currentState: .revealed, revealAge: self.protectedAge
        )
        #expect(allowed == false)
    }

    @Test
    func `timeout allowed after reveal protection expires`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .timeout, currentState: .revealed, revealAge: self.unprotectedAge
        )
        #expect(allowed == true)
    }

    // MARK: - Click Outside Trigger

    @Test
    func `click outside blocked during progress`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .clickOutside, currentState: .progress, revealAge: self.unprotectedAge
        )
        #expect(allowed == false)
    }

    @Test
    func `click outside blocked during reveal protection`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .clickOutside, currentState: .revealed, revealAge: self.protectedAge
        )
        #expect(allowed == false)
    }

    @Test
    func `click outside allowed after reveal protection`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .clickOutside, currentState: .revealed, revealAge: self.unprotectedAge
        )
        #expect(allowed == true)
    }

    @Test
    func `click outside allowed in detailed after protection`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .clickOutside, currentState: .detailed, revealAge: self.unprotectedAge
        )
        #expect(allowed == true)
    }

    // MARK: - Status Bar Toggle Trigger

    @Test
    func `status bar toggle blocked during progress`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .statusBarToggle, currentState: .progress, revealAge: self.protectedAge
        )
        #expect(allowed == false)
    }

    @Test
    func `status bar toggle allowed during reveal protection`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .statusBarToggle, currentState: .revealed, revealAge: self.protectedAge
        )
        #expect(allowed == true)
    }

    @Test
    func `status bar toggle always allowed in revealed`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .statusBarToggle, currentState: .revealed, revealAge: self.unprotectedAge
        )
        #expect(allowed == true)
    }

    @Test
    func `status bar toggle allowed in detailed`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .statusBarToggle, currentState: .detailed, revealAge: self.unprotectedAge
        )
        #expect(allowed == true)
    }

    // MARK: - Hover Max Trigger

    @Test
    func `hover max blocked during reveal protection`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .hoverMax, currentState: .revealed, revealAge: self.protectedAge
        )
        #expect(allowed == false)
    }

    @Test
    func `hover max allowed only in revealed state`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .hoverMax, currentState: .revealed, revealAge: self.unprotectedAge
        )
        #expect(allowed == true)
    }

    @Test
    func `hover max blocked in detailed state`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .hoverMax, currentState: .detailed, revealAge: self.unprotectedAge
        )
        #expect(allowed == false)
    }

    @Test
    func `hover max blocked in hidden state`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .hoverMax, currentState: .hidden, revealAge: self.unprotectedAge
        )
        #expect(allowed == false)
    }

    // MARK: - Sleep/Wake Trigger

    @Test
    func `sleep wake always allows dismiss`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .sleepWake, currentState: .progress, revealAge: self.protectedAge
        )
        #expect(allowed == true)
    }

    @Test
    func `sleep wake allows dismiss in revealed`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .sleepWake, currentState: .revealed, revealAge: self.protectedAge
        )
        #expect(allowed == true)
    }

    @Test
    func `sleep wake allows dismiss in detailed`() {
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .sleepWake, currentState: .detailed, revealAge: self.unprotectedAge
        )
        #expect(allowed == true)
    }

    // MARK: - Reveal Protection Boundary

    @Test
    func `just under protection boundary is still protected`() {
        let justUnder = RevealTiming.totalReveal + 0.499
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .timeout, currentState: .revealed, revealAge: justUnder
        )
        #expect(allowed == false)
    }

    @Test
    func `exactly at protection boundary is no longer protected`() {
        let boundaryAge = RevealTiming.totalReveal + 0.5
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .timeout, currentState: .revealed, revealAge: boundaryAge
        )
        #expect(allowed == true)
    }

    // MARK: - Reduce Motion

    @Test
    func `reduce motion shortens protection window`() {
        let midRevealAge: TimeInterval = 1.0
        let normalAllowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .timeout, currentState: .revealed, revealAge: midRevealAge, reduceMotion: false
        )
        let reduceMotionAllowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .timeout, currentState: .revealed, revealAge: midRevealAge, reduceMotion: true
        )
        #expect(normalAllowed == false)
        #expect(reduceMotionAllowed == true)
    }

    @Test
    func `reduce motion still protects during brief guard`() {
        let veryEarlyAge: TimeInterval = 0.1
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .timeout, currentState: .revealed, revealAge: veryEarlyAge, reduceMotion: true
        )
        #expect(allowed == false)
    }

    @Test
    func `reduce motion allows click outside after brief guard`() {
        let afterGuard: TimeInterval = 0.5
        let allowed = HUDInteractionPolicy.shouldAllowDismiss(
            trigger: .clickOutside, currentState: .revealed, revealAge: afterGuard, reduceMotion: true
        )
        #expect(allowed == true)
    }
}

// MARK: - Flash Event Mapping

@Suite("Flash event alert mapping")
@MainActor
struct FlashEventMappingTests {

    @Test(arguments: [
        HUDAlertTypes.deviceOverheating,
        HUDAlertTypes.chargingComplete,
        HUDAlertTypes.chargingBegan,
        HUDAlertTypes.chargingStopped,
    ])
    func `flashable alerts produce flash events`(alert: HUDAlertTypes) {
        #expect(FlashEvent.from(alert) != nil)
    }

    @Test(arguments: [
        HUDAlertTypes.userInitiated,
        HUDAlertTypes.userLaunched,
        HUDAlertTypes.percentOne,
        HUDAlertTypes.percentFive,
        HUDAlertTypes.percentTen,
        HUDAlertTypes.percentTwentyFive,
        HUDAlertTypes.deviceConnected,
        HUDAlertTypes.deviceRemoved,
        HUDAlertTypes.userEvent,
    ])
    func `non-flashable alerts return nil`(alert: HUDAlertTypes) {
        #expect(FlashEvent.from(alert) == nil)
    }

    @Test
    func `overheating flash is critical priority`() {
        let flash = FlashEvent.from(.deviceOverheating)
        #expect(flash?.priority == .critical)
    }

    @Test
    func `charging complete flash is high priority`() {
        let flash = FlashEvent.from(.chargingComplete)
        #expect(flash?.priority == .high)
    }

    @Test
    func `charging began flash is medium priority`() {
        let flash = FlashEvent.from(.chargingBegan)
        #expect(flash?.priority == .medium)
    }

    @Test
    func `charging stopped flash is medium priority`() {
        let flash = FlashEvent.from(.chargingStopped)
        #expect(flash?.priority == .medium)
    }

    @Test
    func `overheating flash has longer duration than charging`() {
        let overheating = FlashEvent.from(.deviceOverheating)
        let charging = FlashEvent.from(.chargingBegan)
        #expect((overheating?.duration ?? 0) > (charging?.duration ?? 0))
    }
}
