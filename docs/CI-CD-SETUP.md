# CI/CD Setup Guide

Complete guide for setting up automated build, sign, test, and release pipeline for BatteryBoi-Recharged.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [GitHub Secrets Setup](#github-secrets-setup)
- [Fastlane Match Setup](#fastlane-match-setup)
- [Testing the Pipeline](#testing-the-pipeline)
- [Workflow Details](#workflow-details)
- [Troubleshooting](#troubleshooting)
- [Manual Release Process](#manual-release-process)

## Overview

This project uses:
- **Fastlane** for build automation
- **Match** for code signing certificate management
- **GitHub Actions** for CI/CD
- **Semantic Release** for versioning
- **Sparkle** for in-app auto-updates
- **Apple Notarization** for Gatekeeper approval

## Architecture

### Build & Sign Flow

```
Code Push → GitHub Actions
    ↓
Semantic Release (versioning)
    ↓
Fastlane Match (fetch certs from ios-certs repo)
    ↓
Xcode Build & Sign (Developer ID)
    ↓
Apple Notarization (Gatekeeper)
    ↓
Stapling (attach notarization ticket)
    ↓
DMG Creation
    ↓
Sparkle Signing (EdDSA for auto-updates)
    ↓
Upload to GitHub Releases
```

### Code Signing vs Sparkle Signing

These are **two separate signing systems** that work together:

1. **Code Signing (Match/Developer ID)**
   - Signs the `.app` bundle for macOS Gatekeeper
   - Uses Apple Developer certificates (managed by Match)
   - Required for app to run on user machines
   - Verified by macOS on first launch

2. **Sparkle Signing (EdDSA)**
   - Signs the `.dmg` for in-app update verification
   - Uses EdDSA keypair (private key in GitHub secrets)
   - Prevents update spoofing/tampering
   - Verified by Sparkle framework before installing updates

## Prerequisites

### Required Accounts

1. **Apple Developer Account** (paid program membership)
   - Team ID: `QYKKXLKZD6`
   - Used for: Code signing certificates, notarization

2. **GitHub Account** with access to:
   - This repository (BatteryBoi-Recharged)
   - `ios-certs` private repository (for Match)

### Required Tools (Local Development)

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install project tools
brew install swiftlint swiftformat pre-commit go-task

# Install Fastlane via Bundler (recommended)
cd BatteryBoi-Recharged
bundle install

# Install npm dependencies
npm install

# Install pre-commit hooks
pre-commit install
pre-commit install --hook-type commit-msg
```

## GitHub Secrets Setup

Navigate to: `https://github.com/desaianand1/BatteryBoi-Recharged/settings/secrets/actions`

### 1. MATCH_GIT_URL

**Purpose:** URL to the private repository storing code signing certificates

**Value:**
```
https://github.com/nirnshard/ios-certs
```

**How to get it:**
- This should already exist from your ReMorse iOS project
- Same repo, different branch (`batteryboirecharged` vs `remorse`)

---

### 2. MATCH_GIT_BASIC_AUTHORIZATION

**Purpose:** Allows Match to access the private ios-certs repository

**How to create:**

1. Create a GitHub Personal Access Token (PAT):
   - Go to: `https://github.com/settings/tokens`
   - Click "Generate new token (classic)"
   - Name: `Match Access - BatteryBoi`
   - Scopes: Select `repo` (full control of private repositories)
   - Click "Generate token"
   - **SAVE THE TOKEN** - you can't see it again!

2. Encode the token:
   ```bash
   echo -n "YOUR_GITHUB_USERNAME:YOUR_PAT_TOKEN" | base64
   ```

3. Use the base64 output as the secret value

**Example encoding (DO NOT use these values):**
```bash
# If username is "anand" and PAT is "ghp_abc123xyz"
echo -n "anand:ghp_abc123xyz" | base64
# Outputs: YW5hbmQ6Z2hwX2FiYzEyM3h5eg==
```

---

### 3. MATCH_PASSWORD

**Purpose:** Encryption password for the certificates stored in ios-certs repo

**How to get it:**
- You should already have this from your ReMorse iOS setup
- This is the password you chose when first running `fastlane match init`
- **DO NOT lose this password** - you can't recover encrypted certs without it

**If you don't have it:**
- You'll need to revoke old certs and create new ones (see "Fresh Match Setup" below)

---

### 4. TEAM_ID

**Purpose:** Your Apple Developer Team ID

**Value:**
```
QYKKXLKZD6
```

**How to verify:**
1. Go to: `https://developer.apple.com/account`
2. Log in with your Apple ID
3. Look for "Team ID" in the top right or membership section

---

### 5. APPLE_ID

**Purpose:** Apple ID used for notarization

**What is it:**
- Your Apple Developer account email address
- Example: `your.email@example.com`

**How to get it:**
- This is the email you use to log into developer.apple.com
- Same as your App Store Connect login

---

### 6. APPLE_APP_PASSWORD

**Purpose:** App-specific password for notarization API access

**What is it:**
- NOT your regular Apple ID password
- A special password generated for command-line tools
- Required because regular passwords don't work with 2FA

**How to create:**

1. Go to: `https://appleid.apple.com`
2. Sign in with your Apple ID
3. In the "Security" section, find "App-Specific Passwords"
4. Click "Generate an app-specific password"
5. Label: `Fastlane Notarization - BatteryBoi`
6. Copy the generated password (format: `xxxx-xxxx-xxxx-xxxx`)
7. **SAVE THIS** - you can't see it again!

**Note:** If you change your Apple ID password, you'll need to regenerate this.

---

### 7. SPARKLE_PRIVATE_KEY

**Purpose:** EdDSA private key for signing update DMGs

**Status:** ✅ Already configured (from previous setup)

**How to verify:**
- Check if secret exists in GitHub settings
- Public key in `BatteryBoi/Info.plist` should match: `luVX4/2YuPZ5Ly2UfWCf+Mr+63xxC642sFONANdzGek=`

**If you need to regenerate:**
```bash
# Generate new keypair
./Pods/Sparkle/bin/generate_keys

# Output shows:
# - Public key (add to Info.plist as SUPublicEDKey)
# - Private key (add to GitHub secrets as SPARKLE_PRIVATE_KEY)
```

---

### 8. GITHUB_TOKEN

**Status:** ✅ Automatically provided by GitHub Actions (no setup needed)

**Purpose:** Upload release assets, create releases

---

### Summary Checklist

- [ ] MATCH_GIT_URL
- [ ] MATCH_GIT_BASIC_AUTHORIZATION
- [ ] MATCH_PASSWORD
- [ ] TEAM_ID
- [ ] APPLE_ID
- [ ] APPLE_APP_PASSWORD
- [ ] SPARKLE_PRIVATE_KEY (should already exist)

## Fastlane Match Setup

### Initial Setup (First Time Only)

This creates the `batteryboirecharged` branch in your ios-certs repo and syncs certificates.

**Important:** Only do this ONCE. If certs already exist, use readonly mode.

```bash
# Navigate to project directory
cd /path/to/BatteryBoi-Recharged

# Set environment variables (replace with actual values)
export MATCH_GIT_URL="https://github.com/nirnshard/ios-certs"
export MATCH_PASSWORD="your-match-password"
export TEAM_ID="QYKKXLKZD6"

# Option 1: If certificates already exist (RECOMMENDED)
bundle exec fastlane sync_certs readonly:true

# Option 2: If creating NEW certificates (ONLY if needed)
bundle exec fastlane sync_certs readonly:false
```

**What this does:**
1. Clones ios-certs repo
2. Creates/switches to `batteryboirecharged` branch
3. Downloads Developer ID certificate and provisioning profile
4. Installs them in your macOS keychain

### Verify Installation

```bash
# List code signing identities
security find-identity -v -p codesigning

# You should see something like:
# 1) ABC123... "Developer ID Application: Your Name (QYKKXLKZD6)"
```

### Fresh Match Setup (If Starting from Scratch)

**Only do this if you need to completely reset certificates:**

```bash
# 1. Revoke old certificates (if any)
bundle exec fastlane match nuke developer_id

# 2. Create new certificates
export MATCH_GIT_URL="https://github.com/nirnshard/ios-certs"
export MATCH_PASSWORD="choose-a-new-password"
export TEAM_ID="QYKKXLKZD6"

bundle exec fastlane sync_certs readonly:false

# 3. Save the new MATCH_PASSWORD to GitHub secrets
```

**Warning:** Revoking certificates will break existing signed builds. Only do this if absolutely necessary.

## Testing the Pipeline

### Test Locally

```bash
# Run all checks (lint, format, test)
task check

# Run tests only
task test

# Build with code signing
task build

# Full release pipeline (local test - won't upload)
task release
```

### Test on GitHub Actions

#### Test CI Pipeline (No Release)

1. Create a feature branch:
   ```bash
   git checkout -b test/ci-pipeline
   ```

2. Make a small change (add comment, update README)

3. Commit and push:
   ```bash
   git add .
   git commit -m "test: verify CI pipeline"
   git push -u origin test/ci-pipeline
   ```

4. Open Pull Request on GitHub

5. Watch CI run:
   - `https://github.com/desaianand1/BatteryBoi-Recharged/actions`
   - Should see: SwiftLint, SwiftFormat, Tests, Build

#### Test Release Pipeline

**Warning:** This creates a real release!

1. Merge a commit to main with a conventional commit message:
   ```bash
   git checkout main
   git add .
   git commit -m "fix: test release pipeline"
   git push origin main
   ```

2. Watch release workflow:
   - Semantic Release determines version bump
   - Build job runs if new version created
   - DMG uploaded to GitHub Releases
   - Appcast uploaded for Sparkle updates

3. Verify release:
   - Check: `https://github.com/desaianand1/BatteryBoi-Recharged/releases`
   - Download DMG
   - Verify it's signed: `codesign -dv --verbose=4 "BatteryBoi - Recharged.app"`
   - Verify it's notarized: `spctl -a -vv "BatteryBoi - Recharged.app"`

## Workflow Details

### CI Workflow (`.github/workflows/ci.yml`)

**Triggers:**
- Push to `main`
- Pull requests to `main`

**Jobs:**

1. **validate-commits**
   - Runs only on PRs
   - Validates commit messages follow conventional commits format
   - Uses commitlint

2. **swift-lint**
   - Runs SwiftLint in strict mode
   - Fails on any warnings

3. **swift-format-check**
   - Verifies code formatting
   - Uses SwiftFormat

4. **test**
   - Syncs certificates with Match (readonly)
   - Runs unit tests via Fastlane
   - Uploads test results as artifacts

5. **build**
   - Runs after lint, format, and tests pass
   - Syncs certificates with Match (readonly)
   - Builds release configuration with code signing
   - Verifies app can be built and signed

### Release Workflow (`.github/workflows/release.yml`)

**Triggers:**
- Push to `main` branch only

**Jobs:**

1. **semantic-release**
   - Analyzes commit messages since last release
   - Determines version bump (major.minor.patch)
   - Creates Git tag
   - Creates GitHub release
   - Updates CHANGELOG.md

2. **build-release** (only if new version created)
   - Pulls latest code (including new tag)
   - Syncs certificates with Match
   - Builds app with Release configuration
   - Signs with Developer ID (via Match)
   - Notarizes with Apple
   - Staples notarization ticket
   - Creates DMG
   - Signs DMG with Sparkle (EdDSA)
   - Generates appcast.xml for Sparkle
   - Uploads DMG to version-specific release (e.g., v1.2.3)
   - Uploads appcast.xml to both version-specific and `latest` releases

3. **create-sentry-release**
   - Creates release in Sentry for error tracking
   - Links version to production environment

### Commit Message Format

Uses [Conventional Commits](https://www.conventionalcommits.org/):

**Format:**
```
<type>(<scope>): <subject>

<body>
```

**Types:**
- `feat`: New feature (triggers MINOR version bump)
- `fix`: Bug fix (triggers PATCH version bump)
- `refactor`: Code refactoring (no version bump)
- `perf`: Performance improvement (triggers PATCH)
- `test`: Adding tests (no version bump)
- `docs`: Documentation changes (no version bump)
- `ci`: CI/CD changes (no version bump)
- `build`: Build system changes (no version bump)
- `chore`: Other changes (no version bump)

**Breaking Changes:**
- Add `BREAKING CHANGE:` in commit body
- Triggers MAJOR version bump

**Examples:**
```bash
# Patch release (1.2.3 → 1.2.4)
git commit -m "fix(battery): correct time-to-full calculation"

# Minor release (1.2.3 → 1.3.0)
git commit -m "feat(bluetooth): add RSSI distance filtering"

# Major release (1.2.3 → 2.0.0)
git commit -m "feat(ui): redesign settings panel

BREAKING CHANGE: Settings structure changed, old preferences migrated automatically"

# No release
git commit -m "docs: update README installation steps"
```

## Troubleshooting

### Build Fails: "No signing certificate found"

**Cause:** Match certificates not synced or expired

**Fix:**
```bash
# Re-sync certificates
export MATCH_GIT_URL="..."
export MATCH_PASSWORD="..."
export TEAM_ID="QYKKXLKZD6"

bundle exec fastlane sync_certs readonly:false

# Verify
security find-identity -v -p codesigning
```

### Notarization Fails: "Authentication failed"

**Cause:** Invalid Apple ID or app-specific password

**Fix:**
1. Verify APPLE_ID is correct email address
2. Regenerate APPLE_APP_PASSWORD at appleid.apple.com
3. Update GitHub secret with new password

### Match Fails: "Could not clone repo"

**Cause:** Invalid MATCH_GIT_BASIC_AUTHORIZATION

**Fix:**
1. Verify GitHub PAT is valid and not expired
2. Verify PAT has `repo` scope
3. Re-encode and update secret:
   ```bash
   echo -n "username:token" | base64
   ```

### Sparkle Updates Not Working

**Cause:** Appcast URL unreachable or signature mismatch

**Fix:**
1. Verify appcast exists:
   - `https://github.com/desaianand1/BatteryBoi-Recharged/releases/latest/download/appcast.xml`
2. Verify public key in Info.plist matches private key
3. Check Console.app for Sparkle error messages

### Tests Fail in CI but Pass Locally

**Cause:** Environment differences or timing issues

**Fix:**
1. Check test output artifacts in GitHub Actions
2. Run tests with same configuration:
   ```bash
   bundle exec fastlane test
   ```
3. Add `@MainActor` to test classes if needed

### Certificate Expired

**Cause:** Developer ID certificates expire after 5 years

**Fix:**
```bash
# Revoke and regenerate
bundle exec fastlane match nuke developer_id
bundle exec fastlane sync_certs readonly:false
```

**Note:** This will invalidate all previously signed builds.

## Manual Release Process

If you need to create a release without CI/CD:

### 1. Build Locally

```bash
# Set all environment variables
export MATCH_GIT_URL="..."
export MATCH_PASSWORD="..."
export TEAM_ID="QYKKXLKZD6"
export APPLE_ID="your.email@example.com"
export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export SPARKLE_PRIVATE_KEY="..."

# Run full release pipeline
bundle exec fastlane release
```

### 2. Manual Upload

```bash
# DMG will be in build/ directory
DMG_PATH="./build/BatteryBoi - Recharged-X.Y.Z.dmg"

# Create GitHub release manually
gh release create vX.Y.Z \
  --title "vX.Y.Z" \
  --notes "Release notes here"

# Upload DMG
gh release upload vX.Y.Z "$DMG_PATH"

# Upload appcast
gh release upload vX.Y.Z "./build/appcast.xml"
gh release upload latest "./build/appcast.xml" --clobber
```

### 3. Update Homebrew Cask (Optional)

The Homebrew cask bump workflow runs automatically on releases, but you can do it manually:

```bash
# Fork homebrew-cask if not already done
# Update cask file with new version and SHA256

# Calculate SHA256
shasum -a 256 "$DMG_PATH"

# Submit PR to homebrew-cask
```

## Security Best Practices

### Secrets Management

- ✅ Store all credentials in GitHub Secrets (never in code)
- ✅ Use app-specific passwords (not regular passwords)
- ✅ Rotate PATs periodically
- ✅ Use minimal scope for PATs (only `repo`)
- ✅ Keep MATCH_PASSWORD in secure password manager

### Certificate Management

- ✅ Use Match for team-wide certificate sharing
- ✅ Store encrypted certs in private git repo
- ✅ Use readonly mode in CI (prevents accidental cert changes)
- ✅ Regular backups of ios-certs repo

### Code Signing

- ✅ Always notarize macOS apps
- ✅ Enable Hardened Runtime
- ✅ Sign with Developer ID (not development certificates)
- ✅ Verify signatures before releasing:
  ```bash
  codesign -dv --verbose=4 "App.app"
  spctl -a -vv "App.app"
  ```

## Resources

### Documentation

- [Fastlane Documentation](https://docs.fastlane.tools/)
- [Match Documentation](https://docs.fastlane.tools/actions/match/)
- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Release](https://semantic-release.gitbook.io/)

### Tools

- [Fastlane](https://fastlane.tools/)
- [Homebrew](https://brew.sh/)
- [SwiftLint](https://github.com/realm/SwiftLint)
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)
- [Task (go-task)](https://taskfile.dev/)

### Support

- **Issues:** https://github.com/desaianand1/BatteryBoi-Recharged/issues
- **Discussions:** https://github.com/desaianand1/BatteryBoi-Recharged/discussions

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-02-02 | Initial CI/CD setup with Fastlane/Match | - |
| 2026-02-02 | Added comprehensive documentation | - |

---

**Last Updated:** 2026-02-02
**Maintainer:** @desaianand1
