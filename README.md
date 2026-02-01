# BatteryBoi - Recharged

A beautiful, powerful battery indicator for your macOS menu bar.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Swift Version](https://img.shields.io/badge/Swift-6.x-orange.svg)]()
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue)]()

> [!NOTE]
> This is a faithful revival of the original [BatteryBoi](https://github.com/thebarbican19/BatteryBoi) app by Joe Barbour, updated and maintained for modern macOS versions.

## Features

- Real-time battery percentage and time remaining in your menu bar
- Beautiful Dynamic Island-style notifications for charging events
- Bluetooth device battery monitoring (AirPods, mice, keyboards, etc.)
- Charge limit notification (80% threshold)
- Support for both Intel and Apple Silicon Macs
- Customizable display options (percentage, time, cycle count, hidden)
- Sound effects for battery events
- Automatic updates via Sparkle
- Full keyboard navigation and VoiceOver accessibility
- Localized in 15+ languages

## Installation

### Homebrew (Recommended)

```bash
brew install --cask batteryboi-recharged
```

### Manual Download

1. Download the latest `.dmg` from [Releases](https://github.com/desaianand1/BatteryBoi-Recharged/releases)
2. Open the DMG and drag BatteryBoi to your Applications folder
3. Launch BatteryBoi from Applications

> [!TIP]
> To hide the default macOS battery icon, go to **System Settings** → **Control Center** → **Battery** → disable **Show in Menu Bar**

## Compatibility

| macOS Version | Supported |
|---------------|-----------|
| 14.0 Sonoma | ✅ Yes |
| 15.0 Sequoia | ✅ Yes |
| 26.0 Tahoe | ✅ Yes |

> [!WARNING]
> Minimum supported version is now macOS 14.0 (Sonoma). Earlier versions are no longer supported.

Works on both **Intel** and **Apple Silicon** Macs.

## Localization

BatteryBoi is available in:

English, Japanese, Russian, Dutch, Turkish, Chinese (Simplified & Traditional), Slovenian, Slovak, Vietnamese, Spanish, German, Korean, French, Italian, Portuguese

Want to help translate? Contributions welcome via pull request.

## FAQ

<details>
<summary><strong>Does this app collect my data?</strong></summary>

BatteryBoi only logs anonymous install events (device architecture, macOS version, locale, theme). No personal data is collected, stored, or transferred.
</details>

<details>
<summary><strong>Why doesn't the estimated time show up?</strong></summary>

Estimated time until depletion is calculated by the system. Sometimes this information isn't available, in which case BatteryBoi falls back to showing the battery percentage.
</details>

<details>
<summary><strong>Can I use this alongside the default battery icon?</strong></summary>

Yes! Go to **System Settings** → **Control Center** → **Battery** → enable **Show in Menu Bar**.
</details>

<details>
<summary><strong>Some Bluetooth devices don't show battery level?</strong></summary>

BatteryBoi uses System Information to get battery data. Some devices simply don't report this information.
</details>

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Credits

**Original App:** [Joe Barbour (@thebarbican19)](https://github.com/thebarbican19) - Creator of the original [BatteryBoi](https://github.com/thebarbican19/BatteryBoi)

**Maintained by:** [Anand Desai (@desaianand1)](https://github.com/desaianand1)

## License

This project is licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0).
