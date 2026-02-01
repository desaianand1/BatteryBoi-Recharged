//
//  BBAppManager.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 8/9/23.
//

import Combine
import Foundation
import Sparkle
import SwiftUI

@Observable
@MainActor
final class AppManager {
    static let shared = AppManager()

    var counter = 0
    var device: BluetoothObject?
    var alert: HUDAlertTypes?
    var menu: SystemMenuView = .devices
    var profile: SystemProfileObject?

    private var updates = Set<AnyCancellable>()
    private var timer: AnyCancellable?
    private var timerTask: Task<Void, Never>?

    init() {
        // Start the main timer using async/await
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { break }

                if counter > 999 {
                    appUsageTracker()
                }

                counter += 1
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if self.appDistribution() == .direct {
                self.profile = self.appProfile(force: false)
            }
        }
    }

    deinit {
        timerTask?.cancel()
        timer?.cancel()
        updates.forEach { $0.cancel() }
    }

    func appToggleMenu(_ animate: Bool) {
        if animate {
            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.7, blendDuration: 1.0)) {
                switch self.menu {
                case .devices: self.menu = .settings
                default: self.menu = .devices
                }
            }

        } else {
            switch menu {
            case .devices: menu = .settings
            default: menu = .devices
            }

        }

    }

    /// Legacy Combine-based timer publisher. Use `appTimerAsync` for new code.
    func appTimer(_ multiple: Int) -> AnyPublisher<Int, Never> {
        $counter.filter { $0 % multiple == 0 }.eraseToAnyPublisher()
    }

    /// Async timer that emits at the specified interval in seconds.
    /// Returns an AsyncStream that yields the current counter value.
    func appTimerAsync(_ intervalSeconds: Int) -> AsyncStream<Int> {
        AsyncStream { continuation in
            let task = Task { @MainActor [weak self] in
                var lastEmitted = -intervalSeconds // Ensure first value is emitted
                while !Task.isCancelled {
                    guard let self else {
                        continuation.finish()
                        return
                    }

                    if counter - lastEmitted >= intervalSeconds {
                        lastEmitted = counter
                        continuation.yield(counter)
                    }

                    try? await Task.sleep(for: .seconds(1))
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
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
            let id = "\(Locale.current.regionCode?.uppercased() ?? "US")-\(UUID().uuidString)"

            UserDefaults.save(.versionIdenfiyer, value: id)

            return id

        }

    }

    var appDeviceType: SystemDeviceTypes {
        let platform = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))

        if let model = IORegistryEntryCreateCFProperty(platform, "model" as CFString, kCFAllocatorDefault, 0)
            .takeRetainedValue() as? Data,
            let type = String(data: model, encoding: .utf8)?.cString(using: .utf8)
        {
            let typeString = String(cString: type).lowercased()
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

        IOObjectRelease(platform)

        return .unknown

    }

    private func appProfile(force _: Bool = false) -> SystemProfileObject? {
        if let payload = UserDefaults.main.object(forKey: SystemDefaultsKeys.profilePayload.rawValue) as? String {

            if let object = try? JSONDecoder().decode([SystemProfileObject].self, from: Data(payload.utf8)) {
                return object.first

            }

        } else {
            if FileManager.default.fileExists(atPath: "/usr/bin/python3") {
                if let script = Bundle.main.path(forResource: "BBProfileScript", ofType: "py") {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                    process.arguments = [script]

                    let pipe = Pipe()
                    process.standardOutput = pipe

                    do {
                        try process.run()
                        process.waitUntilExit()

                        let data = pipe.fileHandleForReading.readDataToEndOfFile()

                        if let output = String(data: data, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        {

                            UserDefaults.save(.profilePayload, value: output)
                            UserDefaults.save(.profileChecked, value: Date())

                            if let object = try? JSONDecoder().decode(
                                [SystemProfileObject].self,
                                from: Data(output.utf8),
                            ) {
                                if let id = object.first?.id, let display = object.first?.display {
                                    return SystemProfileObject(id: id, display: display)
                                }

                            }

                        }

                    } catch {
                        print("Profile Error: ", error)

                    }

                }

            }

        }

        return nil

    }

    func appDistribution() -> SystemDistribution {
        let task = Process()
        task.launchPath = "/usr/bin/codesign"
        task.arguments = ["-dv", "--verbose=4", Bundle.main.bundlePath]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.launch()
        task.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()

        if let output = String(data: data, encoding: .utf8) {
            if output.contains("Authority=Apple Mac OS Application Signing") {
                return .appstore

            }

        }

        return .direct

    }

}
