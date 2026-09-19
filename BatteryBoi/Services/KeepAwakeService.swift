import Foundation
import IOKit.pwr_mgt

// MARK: - System Power Assertion Provider

@MainActor
struct SystemPowerAssertionProvider: PowerAssertionProviding {
    func createAssertion(name: String) -> UInt32? {
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name as CFString,
            &id
        )
        return result == kIOReturnSuccess ? id : nil
    }

    func releaseAssertion(_ id: UInt32) {
        IOPMAssertionRelease(id)
    }
}

// MARK: - Keep Awake Service

@Observable
@MainActor
final class KeepAwakeService: KeepAwakeServiceProtocol {

    // MARK: - Observable Properties

    private(set) var isActive: Bool = false
    var duration: KeepAwakeDuration = .thirtyMinutes {
        didSet {
            self.saveDurationPreference()
            if self.isActive {
                self.restart()
            }
        }
    }

    private(set) var remainingTime: TimeInterval?

    // MARK: - Private Properties

    @ObservationIgnored private var assertionProvider: any PowerAssertionProviding = SystemPowerAssertionProvider()
    @ObservationIgnored private var defaults: UserDefaults = .standard
    private var assertionID: UInt32 = 0
    private var endTime: Date?

    // SAFETY: nonisolated(unsafe) required because `isolated deinit` triggers a heap corruption
    // crash (StopLookupScope) when back-deploying Swift 6.2 with deployment target < macOS 15.4.
    // These properties are only accessed on @MainActor (read/written in activate/deactivate/
    // startCountdown/deinit, all MainActor-isolated). The annotation bypasses the compiler's
    // isolation check for deinit access — actual thread safety is guaranteed by MainActor.
    // REMOVAL: Switch to `isolated deinit` when deployment target ≥ macOS 15.4.
    // BLAST RADIUS: Removing without switching to `isolated deinit` causes a compiler error.
    nonisolated(unsafe) private var deactivationTask: Task<Void, Never>?
    nonisolated(unsafe) private var displayRefreshTask: Task<Void, Never>?

    // MARK: - Initialization

    convenience init(
        assertionProvider: any PowerAssertionProviding,
        defaults: UserDefaults
    ) {
        self.init()
        self.assertionProvider = assertionProvider
        self.defaults = defaults
        self.duration = Self.loadDurationPreference(from: defaults)
    }

    init() {
        self.duration = Self.loadDurationPreference(from: self.defaults)
    }

    deinit {
        deactivationTask?.cancel()
        deactivationTask = nil
        displayRefreshTask?.cancel()
        displayRefreshTask = nil
    }

    // MARK: - Computed Properties

    var remainingFormatted: String? {
        guard let remaining = self.remainingTime else {
            return self.isActive ? "KeepAwakeStatusOnLabel".localise() : nil
        }
        let c = KeepAwakeFormatting.components(from: remaining)
        if c.hours > 0 {
            return "KeepAwakeRemainingHMLabel".localise([c.hours, c.minutes])
        }
        return "KeepAwakeRemainingMinLabel".localise([c.minutes])
    }

    // MARK: - Public Methods

    func activate() {
        if self.isActive {
            self.deactivate()
        }

        let name = "BatteryBoi: Keep Awake (\(self.duration.displayName))"
        guard let id = self.assertionProvider.createAssertion(name: name) else {
            BLogger.services.error("Keep Awake: IOPMAssertion creation failed")
            return
        }
        self.assertionID = id
        self.isActive = true
        self.startCountdown()
    }

    func handleWake() {
        guard self.isActive else { return }
        if let end = self.endTime, end.timeIntervalSinceNow <= 0 {
            self.deactivate()
            return
        }
        if self.assertionID != 0 {
            self.assertionProvider.releaseAssertion(self.assertionID)
            self.assertionID = 0
        }
        let name = "BatteryBoi: Keep Awake (\(self.duration.displayName))"
        if let id = self.assertionProvider.createAssertion(name: name) {
            self.assertionID = id
        } else {
            BLogger.services.error("Keep Awake: IOPMAssertion re-creation on wake failed")
            self.deactivate()
        }
    }

    func deactivate() {
        self.deactivationTask?.cancel()
        self.deactivationTask = nil
        self.displayRefreshTask?.cancel()
        self.displayRefreshTask = nil
        if self.assertionID != 0 {
            self.assertionProvider.releaseAssertion(self.assertionID)
            self.assertionID = 0
        }
        self.isActive = false
        self.remainingTime = nil
        self.endTime = nil
    }

    // MARK: - Private Methods

    private func restart() {
        self.deactivate()
        self.activate()
    }

    private func startCountdown() {
        self.deactivationTask?.cancel()
        self.displayRefreshTask?.cancel()

        guard let totalSeconds = self.duration.seconds else {
            self.remainingTime = nil
            self.endTime = nil
            return
        }

        self.endTime = Date().addingTimeInterval(totalSeconds)
        self.remainingTime = totalSeconds

        self.deactivationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(totalSeconds))
            guard let self, !Task.isCancelled else { return }
            self.deactivate()
        }

        self.displayRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, !Task.isCancelled else { return }
                guard let end = self.endTime else { return }
                let remaining = end.timeIntervalSinceNow
                guard remaining > 0 else { return }

                self.remainingTime = remaining

                let secsUntilNextMinute = remaining.truncatingRemainder(dividingBy: 60)
                let sleepInterval = secsUntilNextMinute < 1 ? 60.0 : secsUntilNextMinute
                try? await Task.sleep(for: .seconds(sleepInterval))
            }
        }
    }

    private func saveDurationPreference() {
        self.defaults.set(
            self.duration.rawValue,
            forKey: SystemDefaultsKeys.keepAwakeDuration.rawValue
        )
    }

    private static func loadDurationPreference(from defaults: UserDefaults) -> KeepAwakeDuration {
        guard let raw = defaults.string(
            forKey: SystemDefaultsKeys.keepAwakeDuration.rawValue
        ),
            let duration = KeepAwakeDuration(rawValue: raw)
        else {
            return Constants.KeepAwake.defaultDuration
        }
        return duration
    }
}
