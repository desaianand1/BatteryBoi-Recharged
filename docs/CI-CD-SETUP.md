# CI/CD Setup Guide

Complete guide for setting up automated build, sign, test, and release pipeline for BatteryBoi-Recharged.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Doppler Setup](#doppler-setup)
- [GitHub Secrets](#github-secrets)
- [Fastlane Match Setup](#fastlane-match-setup)
- [Testing the Pipeline](#testing-the-pipeline)
- [Workflow Details](#workflow-details)
- [Troubleshooting](#troubleshooting)
- [Manual Release Process](#manual-release-process)

## Overview

This project uses:

- **Doppler** for secrets management across environments
- **Fastlane** for build automation
- **Match** for code signing certificate management
- **GitHub Actions** for CI/CD
- **Semantic Release** for versioning
- **Sparkle** for in-app auto-updates
- **Apple Notarization** for Gatekeeper approval

## Architecture

### Secrets Flow

```
Doppler (secrets source of truth)
  ├── dev config  → Developer machine (doppler run --)
  ├── ci config   → GitHub Actions CI (dopplerhq/secrets-fetch-action)
  └── prd config  → GitHub Actions Release (dopplerhq/secrets-fetch-action)
```

### Build & Sign Flow

```
Code Push → GitHub Actions
    ↓
Doppler Secrets Fetch (ci or prd config)
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
   - Uses EdDSA keypair (private key in Doppler `prd` config)
   - Prevents update spoofing/tampering
   - Verified by Sparkle framework before installing updates

## Prerequisites

### Required Accounts

1. **Apple Developer Account** (paid program membership)
   - Used for: Code signing certificates, notarization

2. **Doppler Account** (<https://doppler.com>)
   - Used for: Secrets management across dev/ci/prd environments

3. **GitHub Account** with access to:
   - This repository (BatteryBoi-Recharged)
   - `ios-certs` private repository (for Match)

### Required Tools (Local Development)

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# One-time project setup (installs all tools + configures Doppler)
cd BatteryBoi-Recharged
task setup
```

The `task setup` command installs:
- SwiftLint, SwiftFormat, pre-commit, go-task, Doppler CLI
- Fastlane via Bundler
- npm dependencies (commitlint, semantic-release)
- Pre-commit hooks (commit-msg)
- Doppler authentication and project selection

## Doppler Setup

### 1. Create the Doppler Project

1. Sign in at <https://dashboard.doppler.com>
2. Create a new project named `batteryboi-recharged`
3. Three configs are created automatically: `dev`, `stg`, `prd`
4. Rename `stg` to `ci` (or create a `ci` config if needed)

### 2. Populate Secrets by Environment

#### Secrets shared across all environments (`dev`, `ci`, `prd`)

| Secret | Description | How to get it |
|--------|-------------|---------------|
| `APPLE_TEAM_ID` | Apple Developer Team ID | <https://developer.apple.com/account> → Membership section |
| `MATCH_GIT_URL` | URL to ios-certs repo | `https://github.com/desaianand1/ios-certs` |
| `MATCH_PASSWORD` | Encryption password for stored certs | From initial `fastlane match init` setup |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Base64-encoded `github_user:PAT` | See [Generating Match Authorization](#generating-match-authorization) |

#### Production-only secrets (`prd`)

| Secret | Description | How to get it |
|--------|-------------|---------------|
| `APPLE_ID` | Apple Developer account email | Your App Store Connect login email |
| `APPLE_APP_PASSWORD` | App-specific password for notarization | See [Creating an App-Specific Password](#creating-an-app-specific-password) |
| `SPARKLE_PRIVATE_KEY` | EdDSA private key for signing DMGs | See [Sparkle Key Management](#sparkle-key-management) |

#### CI and production secrets (`ci`, `prd`)

| Secret | Description | How to get it |
|--------|-------------|---------------|
| `SENTRY_AUTH_TOKEN` | Sentry API auth token | <https://sentry.io/settings/auth-tokens/> |
| `SENTRY_ORG` | Sentry organization slug | Your Sentry dashboard URL slug |
| `SENTRY_PROJECT` | Sentry project slug | Your Sentry project settings |

### 3. Generate Service Tokens

Service tokens allow GitHub Actions to access Doppler without interactive login.

1. In Doppler dashboard, go to project `batteryboi-recharged`
2. For the `ci` config:
   - Go to Access → Service Tokens
   - Generate a token named `github-actions-ci`
   - Save as `DOPPLER_CI_TOKEN` (used in GitHub secrets)
3. For the `prd` config:
   - Generate a token named `github-actions-prd`
   - Save as `DOPPLER_PRD_TOKEN` (used in GitHub secrets)

### 4. Local Developer Setup

```bash
# Install Doppler CLI (if not done via task setup)
brew install dopplerhq/cli/doppler

# Authenticate
doppler login

# Select project (uses doppler.yaml defaults → dev config)
doppler setup

# Verify
doppler secrets   # Should list your dev secrets
```

### Generating Match Authorization

```bash
# Create a GitHub PAT at https://github.com/settings/tokens
# Scopes: select "repo" (full control of private repositories)
# Then encode:
echo -n "YOUR_GITHUB_USERNAME:YOUR_PAT_TOKEN" | base64
# Use the output as MATCH_GIT_BASIC_AUTHORIZATION
```

### Creating an App-Specific Password

1. Go to <https://account.apple.com/account/>
2. Sign in → Sign-in and Security → App-Specific Passwords
3. Generate password, label: `Fastlane Notarization -- BatteryBoi - Recharged`
4. Save the generated password (format: `xxxx-xxxx-xxxx-xxxx`)

### Sparkle Key Management

The Sparkle EdDSA keypair is used for signing update DMGs:

- **Public key** is in `BatteryBoi/Info.plist` as `SUPublicEDKey`
- **Private key** is stored in Doppler `prd` config as `SPARKLE_PRIVATE_KEY`

To generate a new keypair (only if needed — breaks existing users' update verification):

```bash
./Pods/Sparkle/bin/generate_keys
# Output shows public key (update Info.plist) and private key (store in Doppler prd)
```

## GitHub Secrets

After Doppler migration, only these secrets remain in GitHub Actions:

Navigate to: `https://github.com/desaianand1/BatteryBoi-Recharged/settings/secrets/actions`

| Secret | Purpose |
|--------|---------|
| `DOPPLER_CI_TOKEN` | Service token for Doppler `ci` config (used by CI workflow) |
| `DOPPLER_PRD_TOKEN` | Service token for Doppler `prd` config (used by Release workflow) |
| `SEMANTIC_RELEASE_PAT` | GitHub PAT for semantic-release (needs `contents:write`) |
| `HOMEBREW_GITHUB_API_TOKEN` | GitHub PAT for `brew bump-cask-pr` |

`GITHUB_TOKEN` is auto-provided by GitHub Actions — no setup needed.

## Fastlane Match Setup

### Initial Setup (First Time Only)

This creates the `batteryboirecharged` branch in your ios-certs repo and syncs certificates.

**Important:** Only do this ONCE. If certs already exist, use readonly mode.

```bash
# Option 1: If certificates already exist (RECOMMENDED)
doppler run -- bundle exec fastlane sync_certs readonly:true

# Option 2: If creating NEW certificates (ONLY if needed)
doppler run -- bundle exec fastlane sync_certs readonly:false
```

### Verify Installation

```bash
# List code signing identities
security find-identity -v -p codesigning
# You should see: "Developer ID Application: Your Name (TEAM_ID)"
```

### Fresh Match Setup (If Starting from Scratch)

**Warning:** Revoking certificates will break existing signed builds.

```bash
# 1. Revoke old certificates (if any)
doppler run -- bundle exec fastlane match nuke developer_id

# 2. Create new certificates
doppler run -- bundle exec fastlane sync_certs readonly:false
```

## Testing the Pipeline

### Test Locally

```bash
# Quick check — lint strict + format (matches CI, no secrets needed)
task check

# Full CI pipeline locally — lint strict + format + test (no secrets needed)
task ci

# Build with code signing (requires Doppler)
task build

# Full release pipeline — build, sign, notarize, DMG (requires Doppler)
task release
```

### Test on GitHub Actions

#### Test CI Pipeline (No Release)

1. Create a feature branch and push:

   ```bash
   git checkout -b test/ci-pipeline
   git commit --allow-empty -m "test: verify CI pipeline"
   git push -u origin test/ci-pipeline
   ```

2. Open Pull Request on GitHub

3. Watch CI run at `https://github.com/desaianand1/BatteryBoi-Recharged/actions`
   - Should see: SwiftLint, SwiftFormat, Tests, Build (with Doppler secrets)

#### Test Release Pipeline

**Warning:** This creates a real release!

1. Merge a commit to main with a conventional commit message:

   ```bash
   git checkout main
   git commit -m "fix: test release pipeline"
   git push origin main
   ```

2. Semantic Release creates a version tag and GitHub release
3. Release workflow triggers: build → sign → notarize → DMG → upload
4. Verify at: `https://github.com/desaianand1/BatteryBoi-Recharged/releases`

## Workflow Details

### CI Workflow (`.github/workflows/ci.yml`)

**Triggers:** Push to `main`, Pull requests to `main`

**Jobs:**

1. **validate-commits** — Validates conventional commit format (PRs only)
2. **swift-lint** — SwiftLint in strict mode on `BatteryBoi/`
3. **swift-format-check** — SwiftFormat lint check on `BatteryBoi/`
4. **test** — Unit tests via Fastlane (no signing, no secrets needed)
5. **build** — Full build with Match signing (Doppler `ci` config)
6. **semantic-release** — Version bump on main pushes (`SEMANTIC_RELEASE_PAT`)
7. **create-sentry-release-staging** — Sentry staging release (Doppler `ci` config)

### Release Workflow (`.github/workflows/release.yml`)

**Triggers:** Published releases

**Jobs:**

1. **build-release** — Full pipeline (Doppler `prd` config):
   - Match cert sync → Xcode build → Code sign → Notarize → Staple → DMG → Sparkle sign → Upload
   - Generates and uploads `appcast.xml` for Sparkle auto-updates
2. **create-sentry-release** — Sentry production release (Doppler `prd` config)

### Homebrew Workflow (`.github/workflows/homebrew-bump.yml`)

**Triggers:** Published releases (stable only, non-prerelease)

- Validates tag format (`vX.Y.Z`)
- Runs `brew bump-cask-pr` with `HOMEBREW_GITHUB_API_TOKEN`

### Commit Message Format

Uses [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>
```

**Types:**

- `feat`: New feature → MINOR version bump
- `fix`: Bug fix → PATCH version bump
- `refactor`, `test`, `docs`, `ci`, `build`, `chore`: No version bump
- `perf`: Performance improvement → PATCH version bump

**Breaking Changes:** Add `BREAKING CHANGE:` in commit body → MAJOR version bump

## Troubleshooting

### Doppler: "Could not find token"

**Cause:** Doppler CLI not authenticated or project not selected

**Fix:**

```bash
doppler login
doppler setup   # Uses doppler.yaml defaults
```

### Doppler: CI secrets not injected

**Cause:** `DOPPLER_CI_TOKEN` or `DOPPLER_PRD_TOKEN` expired or misconfigured

**Fix:**

1. Check token is set in GitHub repository secrets
2. Regenerate service token in Doppler dashboard if expired
3. Verify token has access to the correct config (`ci` or `prd`)

### Build Fails: "No signing certificate found"

**Cause:** Match certificates not synced or expired

**Fix:**

```bash
doppler run -- bundle exec fastlane sync_certs readonly:false

# Verify
security find-identity -v -p codesigning
```

### Release Fails: "Missing required environment variables"

**Cause:** Required Doppler secrets not set for the `prd` config

**Fix:**

The release lane validates: `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID`. Ensure these are populated in the Doppler `prd` config.

### Notarization Fails: "Authentication failed"

**Cause:** Invalid Apple ID or app-specific password

**Fix:**

1. Verify `APPLE_ID` is correct email address in Doppler `prd`
2. Regenerate `APPLE_APP_PASSWORD` at <https://account.apple.com>
3. Update in Doppler `prd` config

### Match Fails: "Could not clone repo"

**Cause:** Invalid `MATCH_GIT_BASIC_AUTHORIZATION`

**Fix:**

1. Verify GitHub PAT is valid and not expired
2. Verify PAT has `repo` scope
3. Re-encode and update in Doppler:

   ```bash
   echo -n "username:token" | base64
   ```

### Sparkle Updates Not Working

**Cause:** Appcast URL unreachable or signature mismatch

**Fix:**

1. Verify appcast exists:
   `https://github.com/desaianand1/BatteryBoi-Recharged/releases/latest/download/appcast.xml`
2. Verify public key in `Info.plist` matches private key in Doppler `prd`
3. Check Console.app for Sparkle error messages

### Tests Fail in CI but Pass Locally

**Cause:** Environment differences or timing issues

**Fix:**

1. Check test output artifacts in GitHub Actions
2. Run locally with same command: `task ci`
3. Add `@MainActor` to test classes if needed

### Certificate Expired

**Cause:** Developer ID certificates expire after 5 years

**Fix:**

```bash
# Revoke and regenerate
doppler run -- bundle exec fastlane match nuke developer_id
doppler run -- bundle exec fastlane sync_certs readonly:false
```

**Note:** This will invalidate all previously signed builds.

## Manual Release Process

If you need to create a release without CI/CD:

### 1. Build Locally

```bash
# Ensure Doppler is configured with prd secrets (or switch config)
doppler run --config prd -- bundle exec fastlane release
```

### 2. Manual Upload

```bash
# DMG will be in fastlane/build/ directory
DMG_PATH="fastlane/build/BatteryBoi - Recharged-X.Y.Z.dmg"

# Create GitHub release manually
gh release create vX.Y.Z \
  --title "vX.Y.Z" \
  --notes "Release notes here"

# Upload DMG
gh release upload vX.Y.Z "$DMG_PATH"

# Upload appcast
gh release upload vX.Y.Z "fastlane/build/appcast.xml"
gh release upload latest "fastlane/build/appcast.xml" --clobber
```

## Security Best Practices

### Secrets Management

- All credentials in Doppler (never in code or `.env` files)
- Environment compartmentalization: dev/ci/prd with least-privilege access
- Service tokens scoped to individual configs
- Rotate Doppler service tokens and GitHub PATs periodically

### Certificate Management

- Match for team-wide certificate sharing
- Encrypted certs in private git repo
- Readonly mode in CI (prevents accidental cert changes)

### Code Signing

- Always notarize macOS apps
- Hardened Runtime enabled
- Developer ID signing (not development certificates)
- Verify signatures before releasing:

  ```bash
  codesign -dv --verbose=4 "App.app"
  spctl -a -vv "App.app"
  ```

## Resources

- [Doppler Documentation](https://docs.doppler.com/)
- [Fastlane Documentation](https://docs.fastlane.tools/)
- [Match Documentation](https://docs.fastlane.tools/actions/match/)
- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Release](https://semantic-release.gitbook.io/)

---

**Last Updated:** 2026-09-07
**Maintainer:** @desaianand1
