import AppKit
import Foundation

@MainActor
enum SystemInfoCollector {

    static func collect(
        battery: any BatteryServiceProtocol,
        bluetooth: any BluetoothServiceProtocol,
        app: any AppManagerProtocol,
        update: any UpdateManagerProtocol
    ) -> String {
        var lines: [String] = []

        let version = update.currentVersion
        let build = update.currentBuild
        lines.append("BatteryBoi \(version) (\(build))")

        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        lines.append("macOS \(osVersion)")

        let deviceName = app.appDeviceType.name
        let chip = Self.cpuBrandString() ?? "Unknown"
        lines.append("\(deviceName) (\(chip))")

        let ram = Self.formattedRAM()
        let display = Self.formattedDisplay()
        lines.append("\(ram) · \(display)")

        if app.appDeviceType.battery || battery.metrics != nil {
            var batteryParts: [String] = []
            batteryParts.append("\(Int(battery.percentage))%")
            batteryParts.append(battery.charging.state == .charging ? "Charging" : "On Battery")
            if let health = battery.metrics?.healthPercent {
                let cyclesStr = battery.metrics?.cycles.formatted ?? "—"
                let condition = battery.metrics?.health.displayName ?? "Unknown"
                batteryParts.append("Health \(Int(health))% (\(cyclesStr) cycles)")
                batteryParts.append(condition)
            }
            lines.append("Battery: \(batteryParts.joined(separator: " · "))")

            var powerParts: [String] = []
            powerParts.append(battery.thermal == .optimal ? "Nominal" : "Elevated")
            if let powerStr = battery.metrics?.powerFormatted, powerStr != "—" {
                let source = battery.charging.state == .charging ? "AC Adapter" : "Battery"
                powerParts.append("Power: \(powerStr) (\(source))")
            }
            lines.append("Thermal: \(powerParts.joined(separator: " · "))")
        }

        lines.append("Connected BT Devices: \(bluetooth.connected.count)")

        let locale = Locale.current.identifier
        let timezone = TimeZone.current.identifier
        lines.append("Locale: \(locale) · Timezone: \(timezone)")

        #if DIRECT_DISTRIBUTION
            lines.append("Distribution: Direct")
        #else
            lines.append("Distribution: App Store")
        #endif

        return lines.joined(separator: "\n")
    }

    // MARK: - Private Helpers

    private static func cpuBrandString() -> String? {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var result = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &result, &size, nil, 0)
        return String(cString: result)
    }

    private static func formattedRAM() -> String {
        let bytes = ProcessInfo.processInfo.physicalMemory
        let gb = Int(bytes / (1024 * 1024 * 1024))
        return "\(gb) GB RAM"
    }

    private static func formattedDisplay() -> String {
        guard let screen = NSScreen.main else { return "Unknown Display" }
        let frame = screen.frame
        let scale = screen.backingScaleFactor
        let w = Int(frame.width * scale)
        let h = Int(frame.height * scale)
        let prefix = scale >= 2.0 ? "Retina " : ""
        return "\(prefix)\(w)\u{00D7}\(h) @ \(Int(scale))x"
    }
}
