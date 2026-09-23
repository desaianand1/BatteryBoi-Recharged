import Foundation

// MARK: - Alert Delivery

enum AlertDelivery: Equatable {
    case deliver
    case queue
    case suppress
    case flash(FlashEvent)
}

// MARK: - Dismiss Trigger

enum DismissTrigger {
    case timeout
    case clickOutside
    case statusBarToggle
    case hoverMax
    case sleepWake
}

// MARK: - HUD Interaction Policy

enum HUDInteractionPolicy {

    // MARK: - Alert Delivery

    static func shouldDeliverAlert(
        _ alert: HUDAlertTypes,
        currentState: HUDState,
        currentAlert: HUDAlertTypes?
    ) -> AlertDelivery {
        switch currentState {
        case .hidden:
            return .deliver

        case .progress:
            return .queue

        case .revealed:
            if let current = currentAlert, alert.priority < current.priority {
                return .queue
            }
            if let flash = FlashEvent.from(alert) {
                return .flash(flash)
            }
            return .deliver

        case .detailed:
            return .queue

        case .dismissed:
            if alert.priority >= .high {
                return .queue
            }
            return .suppress
        }
    }

    // MARK: - Dismiss Policy

    static func shouldAllowDismiss(
        trigger: DismissTrigger,
        currentState: HUDState,
        revealAge: TimeInterval,
        reduceMotion: Bool = false
    ) -> Bool {
        // Animations are instant with Reduce Motion — only a brief guard against races
        let protectionWindow = reduceMotion ? 0.3 : (RevealTiming.totalReveal + 0.5)
        let revealProtected = revealAge < protectionWindow

        switch trigger {
        case .timeout:
            if currentState == .progress {
                return false
            }
            if currentState == .detailed {
                return false
            }
            if revealProtected {
                return false
            }
            return true

        case .clickOutside:
            if currentState == .progress {
                return false
            }
            if revealProtected {
                return false
            }
            return true

        case .statusBarToggle:
            if currentState == .progress {
                return false
            }
            return true

        case .hoverMax:
            if revealProtected {
                return false
            }
            return currentState == .revealed

        case .sleepWake:
            return true
        }
    }
}
