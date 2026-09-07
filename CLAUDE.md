## General Rules

- Comments: only explain *why*, not *what*. No tautologies, no purple prose.
- Tests: arrange/act/assert, test behaviors not implementation, cover happy path + edge cases.
- Use skill `swiftui-expert` for all SwiftUI code, refactors, or UI overhauls.
- Use skill `swift-testing-expert` for unit testing.
- Use skill `xcode-build-skill` for builds, release optimization, and build-time best practices.

## Libraries

### Homebrew

- Documentation for Homebrews, casks and the upload process: `docs/homebrew/`

### Sparkle

- This app uses Sparkle for auto-updates at runtime.
- Documentation provided at `docs/sparkle/`

## CI CD and Developer setup

- When any Github Actions, workflows, developer setup, Fastlane or other config changes are made, please update the `docs/CI-CD-SETUP.md` document and update relevant sections and any stale references or dead references.

## Taskfile

- This app uses a Taskfile.yml for all developer setup, scripting and automation
- `task fix` — format + lint autofix (run before committing)
- `task check` — lint + format check (local CI equivalent)
- `task dev` — ad-hoc debug build, no signing certs required
- `task test` — run tests via Fastlane
- `task release` — build, sign, notarize, create DMG
- `task clean` — remove build artifacts and DerivedData

## Build

- Scheme: `BatteryBoi - Recharged` (quotes required in CLI)
- Swift 6.2, strict concurrency. Xcode 16.3+

## Code Style

- SwiftFormat (`.swiftformat`) and SwiftLint (`.swiftlint.yml`) at repo root
- 4-space indent, 120 char max, LF endings
- `--self insert` with `--disable redundantSelf` — always use explicit `self`

## Architecture

- Full details: `docs/architecture-decisions.md` | Roadmap: `docs/improvements-prd.md` (index) → `docs/prd/` (sub-PRDs)
- Services are `@Observable @MainActor`, accessed via protocol interfaces, DI via `ServiceContainer`
- IOKit on background actors (`IOKitBatteryService`, `IOKitBluetoothService`)
- IOBluetooth `@objc` callbacks use `BluetoothBridge` — never put on actors directly
- HUD uses `NSPanel` not `MenuBarExtra`/`NSWindow` — see architecture doc Decision #6
