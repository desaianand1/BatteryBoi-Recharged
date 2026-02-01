//
//  BBUpdateManager.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 8/25/23.
//

import AppKit
import Combine
import Foundation
import Sparkle

struct UpdateVersionObject: Codable {
    var formatted: String
    var numerical: Double

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

    var state: UpdateStateType = .completed {
        didSet {
            if state == .completed || state == .failed {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(5))
                    self?.state = .idle
                }
            }
        }
    }

    var available: UpdatePayloadObject?
    var checked: Date?

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
            print("Failed to start Sparkle updater: \(error.localizedDescription)")
        }

        checked = updater?.lastUpdateCheckDate

    }

    deinit {
        self.updates.forEach { $0.cancel() }

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

        let build = item.propertiesDictionary["sparkle:shortVersionString"] as? Double ?? 0.0
        let version: UpdateVersionObject = .init(formatted: title, numerical: build)

        DispatchQueue.main.async {
            self.available = .init(id: id, name: title, version: version)
            self.state = .completed
            self.checked = self.updater?.lastUpdateCheckDate

        }

    }

    func updater(_: SPUUpdater, failedToDownloadUpdate _: SUAppcastItem, error: Error) {
        print("update could not get update", error)

    }

    func updater(_: SPUUpdater, failedToDownloadAppcastWithError error: Error) {
        // Handle the case when the appcast fails to download
        print("update could not get appcast", error)

    }

    func updaterDidNotFindUpdate(_: SPUUpdater) {
        print(
            "✅ Version \(String(describing: Bundle.main.infoDictionary?["CFBundleShortVersionString"])) is the Latest",
        )

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

@objc
class UpdateDriver: NSObject, SPUUserDriver {
    func show(_: SPUUpdatePermissionRequest) async -> SUUpdatePermissionResponse {
        SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: true)

    }

    func showUserInitiatedUpdateCheck(cancellation _: @escaping () -> Void) {
        // Ideally we should show progress but do nothing for now
    }

    func showUpdateFound(with _: SUAppcastItem, state _: SPUUserUpdateState) async -> SPUUserUpdateChoice {
        .install

    }

    func showUpdateReleaseNotes(with _: SPUDownloadData) {}

    func showUpdateReleaseNotesFailedToDownloadWithError(_: Error) {}

    func showUpdateNotFoundWithError(_: Error, acknowledgement _: @escaping () -> Void) {}

    func showUpdaterError(_ error: Error, acknowledgement _: @escaping () -> Void) {
        print("error", error)
    }

    func showDownloadInitiated(cancellation _: @escaping () -> Void) {}

    func showDownloadDidReceiveExpectedContentLength(_: UInt64) {}

    func showDownloadDidReceiveData(ofLength _: UInt64) {}

    func showDownloadDidStartExtractingUpdate() {}

    func showExtractionReceivedProgress(_: Double) {}

    func showReadyToInstallAndRelaunch() async -> SPUUserUpdateChoice {
        .install

    }

    func showInstallingUpdate(withApplicationTerminated _: Bool, retryTerminatingApplication _: @escaping () -> Void) {}

    func showUpdateInstalledAndRelaunched(_: Bool, acknowledgement _: @escaping () -> Void) {}

    func showUpdateInFocus() {}

    func dismissUpdateInstallation() {}
}
