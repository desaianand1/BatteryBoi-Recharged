import Foundation

public enum SystemDistribution {
    case direct
    case appstore
}

public struct SystemProfileObject: Codable {
    var id: String
    var display: String
}

public enum SystemMenuView: String {
    case settings
    case stats
    case devices
}

public struct SystemAppUsage {
    var day: Int
    var timestamp: Date
}

enum SystemDeviceTypes: String, Codable {
    case macbook
    case macbookPro
    case macbookAir
    case imac
    case macMini
    case macPro
    case macStudio
    case unknown

    var name: String {
        if let name = Host.current().localizedName {
            name
        } else {
            switch self {
            case .macbook: "Macbook"
            case .macbookPro: "Macbook Pro"
            case .macbookAir: "Macbook Air"
            case .imac: "iMac"
            case .macMini: "Mac Mini"
            case .macPro: "Mac Pro"
            case .macStudio: "Mac Studio"
            case .unknown: "AlertDeviceUnknownTitle".localise()
            }
        }
    }

    var battery: Bool {
        switch self {
        case .macbook: true
        case .macbookPro: true
        case .macbookAir: true
        case .imac: false
        case .macMini: false
        case .macPro: false
        case .macStudio: false
        case .unknown: false
        }
    }

    var icon: String {
        switch self {
        case .imac: "desktopcomputer"
        case .macMini: "macmini"
        case .macPro: "macpro.gen3"
        case .macStudio: "macstudio"
        default: "laptopcomputer"
        }
    }
}

enum SystemEvents: String {
    case fatalError = "fatal.error"
    case userInstalled = "user.installed"
    case userUpdated = "user.updated"
    case userActive = "user.active"
    case userProfile = "user.profile.detected"
    case userTerminated = "user.quit"
    case userClicked = "user.cta"
    case userPreferences = "user.preferences"
    case userLaunched = "user.launched"
}
