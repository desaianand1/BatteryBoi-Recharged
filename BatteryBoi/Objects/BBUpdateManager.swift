import AppKit
import Foundation
import Sparkle

#if canImport(Sentry)
    import Sentry
#endif

struct UpdateVersionObject: Codable {
    var formatted: String
    var semver: String

}

struct UpdatePayloadObject: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id

    }

    var id: String
    var name: String
    var version: UpdateVersionObject
    var binary: String?
    var cached: Bool?
    var ignore: Bool = false

}

enum UpdateStateType {
    case idle
    case checking
    case updating
    case failed
    case completed

    func subtitle(_ last: Date?, version: String? = nil) -> String {
        switch self {
        case .idle: "UpdateStatusIdleLabel".localise([last?.formatted ?? "TimestampNeverLabel".localise()])
        case .checking: "UpdateStatusCheckingLabel".localise()
        case .updating: "UpdateStatusNewLabel".localise([version ?? ""])
        case .failed: "UpdateStatusEmptyLabel".localise()
        case .completed: "UpdateStatusEmptyLabel".localise()
        }

    }

}

@Observable
@MainActor
final class UpdateManager: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()

    /// Task for resetting state to idle after completion/failure.
    /// Cancels previous task to prevent race conditions.
    private var stateResetTask: Task<Void, Never>?

    var state: UpdateStateType = .completed {
        didSet {
            if state == .completed || state == .failed {
                // Cancel any existing reset task to prevent race conditions
                stateResetTask?.cancel()
                stateResetTask = Task { @MainActor [weak self] in
                    do {
                        try await Task.sleep(for: .seconds(5))
                        self?.state = .idle
                    } catch {
                        // Task was cancelled, don't update state
                    }
                }
            }
        }
    }

    var available: UpdatePayloadObject?
    var checked: Date?

    /// Single toggle for automatic updates (combines check + download).
    var automaticUpdates: Bool {
        get { updater?.automaticallyChecksForUpdates ?? true }
        set {
            updater?.automaticallyChecksForUpdates = newValue
            updater?.automaticallyDownloadsUpdates = newValue
        }
    }

    /// Current app version string (e.g., "3.0.0").
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /// Current app build number (e.g., "30000").
    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    /// Formatted version string for display (e.g., "v3.0.0 (30000)").
    var versionDisplay: String {
        "v\(currentVersion) (\(currentBuild))"
    }

    private let driver = SPUStandardUserDriver(hostBundle: Bundle.main, delegate: nil)

    private var updater: SPUUpdater?

    override init() {
        super.init()

        updater = SPUUpdater(
            hostBundle: Bundle.main,
            applicationBundle: Bundle.main,
            userDriver: driver,
            delegate: self,
        )
        updater?.automaticallyChecksForUpdates = true
        updater?.automaticallyDownloadsUpdates = true
        updater?.updateCheckInterval = 60.0 * 60.0 * 12

        do {
            try updater?.start()
        } catch {
            #if canImport(Sentry)
                SentrySDK.capture(error: error)
            #endif
        }

        checked = updater?.lastUpdateCheckDate

    }

    deinit {
        stateResetTask?.cancel()
    }

    func updateCheck() {
        updater?.checkForUpdatesInBackground()
        state = .checking

    }

    func updater(
        _: SPUUpdater,
        willInstallUpdateOnQuit _: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void,
    ) -> Bool {
        immediateInstallHandler()
        return true

    }

    func updater(
        _: SPUUpdater,
        shouldPostponeRelaunchForUpdate _: SUAppcastItem,
        untilInvokingBlock _: @escaping () -> Void,
    ) -> Bool {
        false

    }

    func updaterShouldDownloadReleaseNotes(_: SPUUpdater) -> Bool {
        true

    }

    func updater(_: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        guard let title = item.title,
              let id = item.propertiesDictionary["id"] as? String
        else {
            DispatchQueue.main.async {
                self.state = .failed
                self.checked = self.updater?.lastUpdateCheckDate

            }
            return
        }

        let semver = item.propertiesDictionary["sparkle:shortVersionString"] as? String ?? item.versionString ?? "0.0.0"
        let version: UpdateVersionObject = .init(formatted: title, semver: semver)

        DispatchQueue.main.async {
            self.available = .init(id: id, name: title, version: version)
            self.state = .completed
            self.checked = self.updater?.lastUpdateCheckDate

        }

    }

    func updater(_: SPUUpdater, failedToDownloadUpdate _: SUAppcastItem, error: Error) {
        #if canImport(Sentry)
            SentrySDK.capture(error: error)
        #endif
    }

    func updater(_: SPUUpdater, failedToDownloadAppcastWithError error: Error) {
        #if canImport(Sentry)
            SentrySDK.capture(error: error)
        #endif
    }

    func updaterDidNotFindUpdate(_: SPUUpdater) {
        DispatchQueue.main.async {
            self.available = nil
            self.state = .completed

        }

    }

    func updater(_: SPUUpdater, willShowModalAlert _: NSAlert) {}

    func updater(_: SPUUpdater, didAbortWithError error: Error) {
        if let error = error as NSError? {
            if error.code == 4005 {
                // WindowManager.shared.windowOpenWebsite(.update, view: .main)

                state = .completed

            }

        }

    }

    var updateVersion: String {
        get {
            if let version = UserDefaults.main.object(forKey: SystemDefaultsKeys.versionCurrent.rawValue) as? String {
                return version

            } else {
                self.updateVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"

            }

            return (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"

        }

        set {
            UserDefaults.save(
                .versionCurrent,
                value: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? newValue,
            )

        }

    }

}
