import AppKit

enum SystemSoundEffects: String {
    case high = "highnote"
    case low = "lownote"
    case critical

    func play(_ force: Bool = false, soundEffects: SettingsSoundEffects = .disabled) {
        guard soundEffects == .enabled || force else { return }

        guard let sound = NSSound(named: rawValue) else {
            BLogger.app.warning("Sound effect '\(rawValue)' not found in bundle")
            return
        }

        _ = sound.play()
    }
}
