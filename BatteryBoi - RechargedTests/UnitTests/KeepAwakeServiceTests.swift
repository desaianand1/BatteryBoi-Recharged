@testable import BatteryBoi___Recharged
import Foundation
import Testing

@Suite("Keep Awake service behavior")
@MainActor
struct KeepAwakeServiceTests {

    let mockProvider = MockPowerAssertionProvider()
    // swiftlint:disable:next force_unwrapping
    let defaults = UserDefaults(suiteName: "test-keep-awake-\(UUID().uuidString)")!

    // MARK: - Activation Lifecycle

    @Test
    func `activate creates assertion and sets active`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)

        service.activate()

        #expect(service.isActive == true)
        #expect(self.mockProvider.createCallCount == 1)
    }

    @Test
    func `activate while already active deactivates first`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)

        service.activate()
        service.activate()

        #expect(service.isActive == true)
        #expect(self.mockProvider.createCallCount == 2)
        #expect(self.mockProvider.releaseCallCount == 1)
    }

    @Test
    func `deactivate releases assertion and clears state`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)
        service.activate()

        service.deactivate()

        #expect(service.isActive == false)
        #expect(service.remainingTime == nil)
        #expect(self.mockProvider.releaseCallCount == 1)
    }

    @Test
    func `deactivate when not active is safe`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)

        service.deactivate()

        #expect(service.isActive == false)
        #expect(self.mockProvider.releaseCallCount == 0)
    }

    // MARK: - IOKit Assertion Behavior

    @Test
    func `activate stays inactive when assertion creation fails`() {
        self.mockProvider.createShouldSucceed = false
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)

        service.activate()

        #expect(service.isActive == false)
        #expect(service.remainingTime == nil)
    }

    @Test
    func `assertion name includes duration context`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)
        service.duration = .oneHour

        service.activate()

        let name = self.mockProvider.lastCreatedName
        #expect(name?.contains("Keep Awake") == true)
    }

    @Test
    func `deactivate after failed activate does not release`() {
        self.mockProvider.createShouldSucceed = false
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)
        service.activate()

        service.deactivate()

        #expect(self.mockProvider.releaseCallCount == 0)
    }

    // MARK: - Indefinite Mode

    @Test
    func `activate with indefinite sets no remaining time`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)
        service.duration = .indefinite

        service.activate()

        #expect(service.isActive == true)
        #expect(service.remainingTime == nil)
    }

    // MARK: - Timed Mode

    @Test
    func `activate with timed duration sets remaining time`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)
        service.duration = .fifteenMinutes

        service.activate()

        #expect(service.isActive == true)
        let remaining = try? #require(service.remainingTime)
        #expect((remaining ?? 0) > 890)
        #expect((remaining ?? 0) <= 900)
    }

    // MARK: - Duration Change While Active

    @Test
    func `duration change while active restarts session`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)
        service.activate()
        let initialCreateCount = self.mockProvider.createCallCount

        service.duration = .oneHour

        #expect(service.isActive == true)
        #expect(self.mockProvider.createCallCount == initialCreateCount + 1)
        #expect(self.mockProvider.releaseCallCount >= 1)
    }

    @Test
    func `duration change while inactive does not activate`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)

        service.duration = .twoHours

        #expect(service.isActive == false)
        #expect(self.mockProvider.createCallCount == 0)
    }

    @Test
    func `switching from timed to indefinite while active clears remaining time`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)
        service.duration = .thirtyMinutes
        service.activate()
        #expect(service.remainingTime != nil)

        service.duration = .indefinite

        #expect(service.isActive == true)
        #expect(service.remainingTime == nil)
    }

    @Test
    func `switching from indefinite to timed while active sets remaining time`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)
        service.duration = .indefinite
        service.activate()
        #expect(service.remainingTime == nil)

        service.duration = .oneHour

        #expect(service.isActive == true)
        let remaining = service.remainingTime ?? 0
        #expect(remaining > 3590)
        #expect(remaining <= 3600)
    }

    // MARK: - Wake Handling

    @Test
    func `handleWake when not active is no-op`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)

        service.handleWake()

        #expect(self.mockProvider.createCallCount == 0)
        #expect(self.mockProvider.releaseCallCount == 0)
    }

    @Test
    func `handleWake re-creates assertion when still valid`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)
        service.duration = .twoHours
        service.activate()
        let createsBefore = self.mockProvider.createCallCount

        service.handleWake()

        #expect(service.isActive == true)
        #expect(self.mockProvider.releaseCallCount == 1)
        #expect(self.mockProvider.createCallCount == createsBefore + 1)
    }

    @Test
    func `handleWake deactivates when assertion re-creation fails`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)
        service.duration = .twoHours
        service.activate()

        self.mockProvider.createShouldSucceed = false
        service.handleWake()

        #expect(service.isActive == false)
    }

    @Test
    func `handleWake with indefinite mode re-creates assertion`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)
        service.duration = .indefinite
        service.activate()
        let createsBefore = self.mockProvider.createCallCount

        service.handleWake()

        #expect(service.isActive == true)
        #expect(service.remainingTime == nil)
        #expect(self.mockProvider.createCallCount == createsBefore + 1)
    }

    @Test
    func `multiple wake cycles do not leak assertions`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)
        service.duration = .twoHours
        service.activate()

        service.handleWake()
        service.handleWake()
        service.handleWake()

        #expect(service.isActive == true)
        #expect(self.mockProvider.createCallCount == 4)
        #expect(self.mockProvider.releaseCallCount == 3)
    }

    // MARK: - Remaining Formatted

    @Test
    func `remainingFormatted nil when inactive`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)

        #expect(service.remainingFormatted == nil)
    }

    @Test
    func `remainingFormatted non-nil when active indefinite`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)
        service.duration = .indefinite
        service.activate()

        #expect(service.remainingFormatted != nil)
    }

    @Test
    func `remainingFormatted non-nil when active timed`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)
        service.duration = .thirtyMinutes
        service.activate()

        #expect(service.remainingFormatted != nil)
    }

    // MARK: - Duration Persistence

    @Test
    func `duration preference persists to defaults`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)

        service.duration = .oneHour

        let saved = self.defaults.string(forKey: SystemDefaultsKeys.keepAwakeDuration.rawValue)
        #expect(saved == KeepAwakeDuration.oneHour.rawValue)
    }

    @Test
    func `loads saved duration from defaults`() {
        self.defaults.set(
            KeepAwakeDuration.twoHours.rawValue,
            forKey: SystemDefaultsKeys.keepAwakeDuration.rawValue
        )

        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)

        #expect(service.duration == .twoHours)
    }

    @Test
    func `defaults to thirty minutes when no saved preference`() {
        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)

        #expect(service.duration == .thirtyMinutes)
    }

    @Test
    func `defaults to thirty minutes for invalid saved value`() {
        self.defaults.set("invalidValue", forKey: SystemDefaultsKeys.keepAwakeDuration.rawValue)

        let service = KeepAwakeService(assertionProvider: self.mockProvider, defaults: self.defaults)

        #expect(service.duration == .thirtyMinutes)
    }
}
