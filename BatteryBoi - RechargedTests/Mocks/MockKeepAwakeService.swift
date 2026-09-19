@testable import BatteryBoi___Recharged
import Foundation

#if DEBUG

    @Observable
    @MainActor
    final class MockKeepAwakeService: KeepAwakeServiceProtocol {
        var isActive: Bool = false
        var duration: KeepAwakeDuration = .thirtyMinutes
        var remainingTime: TimeInterval?
        var activateCallCount: Int = 0
        var deactivateCallCount: Int = 0

        var remainingFormatted: String? {
            guard let remaining = self.remainingTime else {
                return self.isActive ? "On" : nil
            }
            return "\(Int(remaining / 60)) min left"
        }

        func activate() {
            self.activateCallCount += 1
            self.isActive = true
            if let seconds = self.duration.seconds {
                self.remainingTime = seconds
            }
        }

        func deactivate() {
            self.deactivateCallCount += 1
            self.isActive = false
            self.remainingTime = nil
        }

        func handleWake() {
            guard self.isActive else { return }
        }

        func simulateCountdown(remaining: TimeInterval) {
            self.remainingTime = remaining
        }

        func simulateExpiry() {
            self.isActive = false; self.remainingTime = nil
        }
    }

#endif
