import Foundation

// MARK: - Keep Awake Duration

enum KeepAwakeDuration: String, CaseIterable, Identifiable {
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case indefinite

    var id: String {
        self.rawValue
    }

    var seconds: TimeInterval? {
        switch self {
        case .fifteenMinutes: 900
        case .thirtyMinutes: 1800
        case .oneHour: 3600
        case .twoHours: 7200
        case .indefinite: nil
        }
    }

    var displayName: String {
        switch self {
        case .fifteenMinutes: "KeepAwakeDuration15Label".localise()
        case .thirtyMinutes: "KeepAwakeDuration30Label".localise()
        case .oneHour: "KeepAwakeDuration1HLabel".localise()
        case .twoHours: "KeepAwakeDuration2HLabel".localise()
        case .indefinite: "KeepAwakeDurationIndefiniteLabel".localise()
        }
    }
}

// MARK: - Power Assertion Provider

@MainActor
protocol PowerAssertionProviding {
    func createAssertion(name: String) -> UInt32?
    func releaseAssertion(_ id: UInt32)
}

// MARK: - Keep Awake Formatting

nonisolated enum KeepAwakeFormatting {
    struct Components: Sendable {
        let hours: Int
        let minutes: Int
    }

    static func components(from remaining: TimeInterval) -> Components {
        let totalMinutes = Int(remaining) / 60
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        return Components(hours: hours, minutes: hours > 0 ? mins : max(mins, 1))
    }
}

// MARK: - Keep Awake Service Protocol

@MainActor
protocol KeepAwakeServiceProtocol: AnyObject, Observable {
    var isActive: Bool { get }
    var duration: KeepAwakeDuration { get set }
    var remainingTime: TimeInterval? { get }
    var remainingFormatted: String? { get }
    func activate()
    func deactivate()
    func handleWake()
}
