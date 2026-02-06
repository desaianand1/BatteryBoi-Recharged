import Combine
import Foundation
import Logging
import SwiftUI

struct ViewScrollMask: ViewModifier {
    @State var padding: CGFloat

    @Binding var scroll: CGPoint

    func body(content: Content) -> some View {
        content.mask(
            GeometryReader { geo in
                HStack(spacing: 0) {
                    LinearGradient(gradient: Gradient(colors: [
                        .black.opacity(opacity(for: scroll.x)),
                        .black.opacity(1),
                    ]), startPoint: .leading, endPoint: .trailing).frame(width: padding)

                    Rectangle().fill(.black).frame(width: geo.size.width - padding)

                }

            }

        )

    }

    func opacity(for offset: CGFloat) -> Double {
        let start: CGFloat = 0.0
        let end: CGFloat = -8.0

        if offset >= start {
            return 1.0

        } else if offset <= end {
            return 0.0

        } else {
            return Double(1.0 + (offset / 8.0))

        }

    }

}

struct ViewMarkdown: View {
    @Binding var text: String

    @State private var components = [String]()

    init(_ content: Binding<String>) {
        _text = content

    }

    var body: some View {
        HStack(spacing: 0) {
            if components.count == 1 {
                Text(components[0])
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color("BatterySubtitle"))
                    .lineLimit(3)

            } else {
                ForEach(0 ..< components.count, id: \.self) { number in
                    if number.isMultiple(of: 2) {
                        Text(components[number])
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color("BatterySubtitle"))
                            .lineLimit(1)

                    } else {
                        Text(components[number])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color("BatteryTitle").opacity(0.9))
                            .lineLimit(1)

                    }

                }

            }

        }
        .onChange(of: text) { _, newValue in
            components = newValue.components(separatedBy: "**")

        }

    }

}

struct ViewTextStyle: ViewModifier {
    @State var size: CGFloat

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .bold)).lineLimit(1).tracking(-0.4)
    }
}

public extension String {
    func append(_ string: String, seporator: String) -> String {
        "\(self)\(seporator)\(string)"

    }

    func width(_ font: NSFont) -> CGFloat {
        let attribute = NSAttributedString(string: self, attributes: [NSAttributedString.Key.font: font])

        return attribute.size().width

    }

    func localise(_ params: [CVarArg]? = nil, comment: String? = nil) -> String {
        var key = self
        var output = NSLocalizedString(self, tableName: "LocalizableMain", comment: comment ?? "")

        if let number = params?.first(where: { $0 is Int }) as? Int {
            switch number {
            case 1: key = "\(key)_Single"
            default: key = "\(key)_Plural"
            }

        }

        if output == self {
            output = NSLocalizedString(key, tableName: "LocalizableMain", comment: comment ?? "")

        }

        if let params {
            return String(format: output, arguments: params)

        }

        return output

    }
}

public extension [String] {
    func index(_ index: Int, fallback: String? = nil) -> String? {
        if indices.contains(index) {
            return self[index]

        }

        return fallback

    }

}

public extension Date {
    func string(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale.current

        return formatter.string(from: self)

    }

    var formatted: String {
        let components = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: self, to: Date())
        if let days = components.day, days > 1 {
            return "TimestampMinuteDaysLabel".localise([days])

        }

        if let hours = components.hour, hours > 1 {
            return "TimestampHourFullLabel".localise([hours])

        }

        return "TimestampNowLabel".localise()

    }

    var now: Bool {
        if let seconds = Calendar.current.dateComponents([.second], from: self, to: Date()).second {
            if seconds < 60 {
                return true

            }

        }

        return false

    }

    var time: String {
        let locale = NSLocale.current
        let formatter = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale)

        if let formatter {
            if formatter.contains("a") == true {
                return string("hh:mm a")

            } else {
                return string("HH:mm")

            }

        }

        return "AlertDeviceUnknownTitle".localise()

    }

}

extension View {
    func inverse(_ mask: some View) -> some View {
        let inversed = mask
            .foregroundColor(.black)
            .background(Color.white)
            .compositingGroup()
            .luminanceToAlpha()

        return self.mask(inversed)

    }

    func mask(_ padding: CGFloat = 10, scroll: Binding<CGPoint>) -> some View {
        modifier(ViewScrollMask(padding: padding, scroll: scroll))

    }

    func style(_ font: CGFloat) -> some View {
        modifier(ViewTextStyle(size: font))

    }

}

extension UserDefaults {
    /// Legacy Combine publisher for settings changes. Use `changedAsync()` for new code.
    /// Note: nonisolated(unsafe) is justified here because PassthroughSubject is
    /// thread-safe and used for cross-isolation communication per SE-0371.
    nonisolated(unsafe) static let changed = PassthroughSubject<SystemDefaultsKeys, Never>()

    /// Async stream for observing UserDefaults changes.
    static func changedAsync() -> AsyncStream<SystemDefaultsKeys> {
        AsyncStream { continuation in
            // Note: nonisolated(unsafe) justified for Combine subscription in async context
            nonisolated(unsafe) let cancellable = changed.sink { key in
                continuation.yield(key)
            }

            continuation.onTermination = { @Sendable _ in
                // Hold reference to prevent deallocation
                cancellable.cancel()
            }
        }
    }

    static var main: UserDefaults {
        UserDefaults.standard // Use standard singleton, not new instance!
    }

    static var list: [SystemDefaultsKeys] {
        UserDefaults.main.dictionaryRepresentation().keys.compactMap { SystemDefaultsKeys(rawValue: $0) }

    }

    static func save(_ key: SystemDefaultsKeys, value: Any?) {
        save(string: key.rawValue, value: value)

    }

    static func save(string key: String, value: Any?) {
        if let value {
            main.set(Date(), forKey: "\(key)_timestamp")
            main.set(value, forKey: key)
            main.synchronize()

            if let system = SystemDefaultsKeys(rawValue: key) {
                changed.send(system)

            }

            BLogger.settings.debug("Saved \(String(describing: value)) to '\(key)'")

        } else {
            main.removeObject(forKey: key)
            main.synchronize()

            if let system = SystemDefaultsKeys(rawValue: key) {
                changed.send(system)

            }

        }

    }

    static func timestamp(_ key: SystemDefaultsKeys) -> Date? {
        if let timetamp = UserDefaults.main.object(forKey: "\(key.rawValue)_timestamp") as? Date {
            return timetamp
        }

        return nil

    }

}

extension CodingUserInfoKey {
    static let device: CodingUserInfoKey = {
        guard let key = CodingUserInfoKey(rawValue: "device") else {
            fatalError("Failed to create CodingUserInfoKey for 'device'")
        }
        return key
    }()

    static let connected: CodingUserInfoKey = {
        guard let key = CodingUserInfoKey(rawValue: "connected") else {
            fatalError("Failed to create CodingUserInfoKey for 'connected'")
        }
        return key
    }()
}

extension String {
    /// Normalizes a Bluetooth MAC address to a consistent format.
    /// Converts to lowercase and replaces colons with dashes.
    /// Example: "AA:BB:CC:DD:EE:FF" -> "aa-bb-cc-dd-ee-ff"
    var normalizedBluetoothAddress: String {
        lowercased().replacingOccurrences(of: ":", with: "-")
    }

    /// Converts a normalized Bluetooth address back to colon-separated format.
    /// Example: "aa-bb-cc-dd-ee-ff" -> "aa:bb:cc:dd:ee:ff"
    var colonSeparatedBluetoothAddress: String {
        replacingOccurrences(of: "-", with: ":")
    }
}
