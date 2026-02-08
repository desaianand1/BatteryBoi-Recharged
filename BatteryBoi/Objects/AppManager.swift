import Foundation
import Logging
import Sparkle
import SwiftUI

@Observable
@MainActor
final class AppManager: AppManagerProtocol {
    static let shared = AppManager()

    /// App counter for tracking uptime (seconds since app launch)
    var counter = 0

    /// Current menu view state (synced with AppState for view compatibility)
    var menu: SystemMenuView = .settings {
        didSet {
            ServiceContainer.shared.state.currentMenu = menu
        }
    }

    /// Task for the uptime counter (nonisolated for deinit access per SE-0371)
    nonisolated(unsafe) private var counterTask: Task<Void, Never>?

    init() {
        // Start the uptime counter
        counterTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { break }

                if counter > 999 {
                    appUsageTracker()
                }

                counter += 1
            }
        }
    }

    deinit {
        counterTask?.cancel()
    }

    /// Toggle between menu views with optional animation
    func appToggleMenu(_ animate: Bool) {
        if animate {
            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.7, blendDuration: 1.0)) {
                menu = menu == .devices ? .settings : .devices
            }
        } else {
            menu = menu == .devices ? .settings : .devices
        }
    }

    var appInstalled: Date {
        if let date = UserDefaults.main.object(forKey: SystemDefaultsKeys.versionInstalled.rawValue) as? Date {
            return date

        } else {
            UserDefaults.save(.versionInstalled, value: Date())
            return Date()

        }

    }

    func appUsageTracker() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current

        if let latest = appUsage {
            let last = calendar.dateComponents([.year, .month, .day], from: latest.timestamp)
            let current = calendar.dateComponents([.year, .month, .day], from: Date())

            if let lastDate = calendar.date(from: last), let currentDate = calendar.date(from: current) {
                if currentDate > lastDate {
                    appUsage = .init(day: latest.day + 1, timestamp: Date())

                }

            }

        } else {
            appUsage = .init(day: 1, timestamp: Date())

        }

    }

    var appUsage: SystemAppUsage? {
        get {
            let days = UserDefaults.main.object(forKey: SystemDefaultsKeys.usageDay.rawValue) as? Int
            let timestamp = UserDefaults.main.object(forKey: SystemDefaultsKeys.usageTimestamp.rawValue) as? Date

            if let days, let timestamp {
                return .init(day: days, timestamp: timestamp)

            }

            return nil

        }

        set {
            if let newValue {
                UserDefaults.save(.usageDay, value: newValue.day)
                UserDefaults.save(.usageTimestamp, value: newValue.timestamp)
            }

        }

    }

    var appIdentifyer: String {
        if let id = UserDefaults.main.object(forKey: SystemDefaultsKeys.versionIdenfiyer.rawValue) as? String {
            return id

        } else {
            let id = "\(Locale.current.region?.identifier.uppercased() ?? "US")-\(UUID().uuidString)"

            UserDefaults.save(.versionIdenfiyer, value: id)

            return id

        }

    }

    var appDeviceType: SystemDeviceTypes {
        let platform = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard platform != IO_OBJECT_NULL else { return .unknown }
        defer { IOObjectRelease(platform) }

        if let model = IORegistryEntryCreateCFProperty(platform, "model" as CFString, kCFAllocatorDefault, 0)
            .takeRetainedValue() as? Data
        {
            // Truncate null termination before decoding
            let cleanedModel = model.prefix(while: { $0 != 0 })
            guard let typeString = String(bytes: cleanedModel, encoding: .utf8)?.lowercased() else {
                return .unknown
            }
            if typeString.contains("macbookpro") {
                return .macbookPro
            } else if typeString.contains("macbookair") {
                return .macbookAir
            } else if typeString.contains("macbook") {
                return .macbook
            } else if typeString.contains("imac") {
                return .imac
            } else if typeString.contains("macmini") {
                return .macMini
            } else if typeString.contains("macstudio") {
                return .macStudio
            } else if typeString.contains("macpro") {
                return .macPro
            } else {
                return .unknown
            }
        }

        return .unknown

    }

    func appDistribution() async -> SystemDistribution {
        do {
            let output = try await ProcessRunner.shared.run(
                executable: "/usr/bin/codesign",
                arguments: ["-dv", "--verbose=4", Bundle.main.bundlePath],
                timeout: .seconds(10)
            )

            if output.contains("Authority=Apple Mac OS Application Signing") {
                return .appstore
            }
        } catch {
            // codesign outputs to stderr, so non-zero exit is expected for non-App Store builds
            // Check if the error message contains the App Store signing info
            if case let ProcessRunnerError.nonZeroExitCode(_, errorOutput) = error {
                if errorOutput.contains("Authority=Apple Mac OS Application Signing") {
                    return .appstore
                }
            }
        }

        return .direct

    }

}
