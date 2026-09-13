# SleepBar - Private Development Repository

A simple and elegant sleep timer for macOS. Set your Mac to sleep after a duration or at a specific time.

**This is the private development repository. The public website, changelog mirror, and release downloads live at [nateships/sleepbar](https://github.com/nateships/sleepbar).**

---

## Development

### Requirements

- Xcode 26 (macOS 15+)
- [mise](https://mise.jdx.dev) for the CLI toolchain (`gh`, `xcbeautify`, `actionlint`)
- Xcode signed in to team `AMR56F4NQB` for running tests and debug builds with CloudKit entitlements

### Setup

```bash
git clone git@github.com:nateships/sleepbar-private.git
cd sleepbar-private
mise install
open SleepBar.xcodeproj
```

### Tasks

```bash
mise run build     # Debug build, no code signing
mise run test      # Unit tests (needs Xcode signed in)
mise run lint      # Lint GitHub Actions workflows
mise tasks         # List everything
```

Build output goes to `build/` (gitignored).

### Developer Tools (Debug Builds Only)

**Cmd+Shift+D** or "Developer Tools" in the menu:
- **Reset Trial**: Start a fresh 7-day trial
- **Expire Trial**: Set trial to expired
- **Generate Test Key**: Create a fake license key (does not work with the Lemon Squeezy API)
- **Deactivate License**: Remove current license

---

## Releasing

Releases are built, signed, notarized, and published by GitHub Actions (`.github/workflows/release.yml`). Nothing is built on a developer machine.

### 1. Write the changelog

Add a section to `CHANGELOG.md`. The release fails if the section is missing.

```markdown
## [1.1.1] - 09-20-2026

#### Bug Fixes
- Description
```

### 2. Tag and push

```bash
git tag v1.1.1
git push origin main v1.1.1
```

The tag is the source of truth for the version. CI sets:
- `MARKETING_VERSION` = `1.1.1`
- `CURRENT_PROJECT_VERSION` (Sparkle build number) = `10101` (major×10000 + minor×100 + patch)

The version numbers in the Xcode project are not used for releases.

### 3. What CI does

1. Imports the Developer ID certificate and provisioning profile into a temporary keychain
2. Archives and exports the app with Developer ID (`scripts/archive.sh`)
3. Builds and signs the DMG (`scripts/dmg.sh`)
4. Notarizes and staples (`scripts/notarize.sh`)
5. Signs the DMG with the Sparkle EdDSA key and updates `appcast.xml` (`scripts/appcast.sh`)
6. Creates the GitHub release on `nateships/sleepbar` with `SleepBar-1.1.1.dmg` and `SleepBar.dmg`
7. Commits `appcast.xml` and `CHANGELOG.md` to `nateships/sleepbar` main. Cloudflare Pages deploys the site.

### Dry run

Actions → Release → Run workflow with `publish` unchecked. Builds and notarizes, uploads the DMG as a workflow artifact, publishes nothing.

### 4. Verify

1. Install the previous version, open "Check for Updates", confirm the update installs.
2. `https://sleepbar.app/appcast.xml` shows the new version (cached for 5 minutes).

---

## CI Secrets

Set in this repository under Settings → Secrets and variables → Actions.

| Secret | Content | How to produce |
|---|---|---|
| `DEVELOPER_ID_P12_BASE64` | Developer ID Application cert + private key | Keychain Access → export identity as `.p12`, then `base64 -i cert.p12 \| pbcopy` |
| `DEVELOPER_ID_P12_PASSWORD` | Password chosen at export | |
| `DEVELOPER_ID_PROFILE_BASE64` | Developer ID provisioning profile for `app.sleepbar.SleepBar` | developer.apple.com → Profiles → Distribution → Developer ID → download, then `base64 -i x.provisionprofile \| pbcopy` |
| `NOTARY_APPLE_ID` | Apple ID email | |
| `NOTARY_PASSWORD` | App-specific password | appleid.apple.com → Sign-In and Security → App-Specific Passwords |
| `SPARKLE_PRIVATE_KEY` | Sparkle EdDSA private key (base64 string) | From 1Password. Public key must match `SUPublicEDKey` in `SleepBar/Info.plist` |
| `SLEEPBAR_SITE_TOKEN` | Fine-grained PAT, repo `nateships/sleepbar`, Contents: read and write | github.com → Settings → Developer settings → Fine-grained tokens |

The Sparkle private key is the only thing that cannot be re-issued. If it is lost, installed apps reject every future update. Keep the 1Password copy.

---

## Project Structure

```
sleepbar-private/
├── SleepBar/
│   ├── SleepBarApp.swift          # App entry point
│   ├── ContentView.swift          # Main menu UI
│   ├── MenuBarLabel.swift         # Menu bar icon/label
│   ├── SleepTimerManager.swift    # Timer logic
│   ├── SleepWarningView.swift     # Warning popup content
│   ├── SleepWarningWindow.swift   # Warning window manager
│   ├── AboutView.swift            # About window
│   ├── LicenseManager.swift       # Trial & licensing (Lemon Squeezy)
│   ├── LicenseView.swift          # License activation UI
│   ├── TelemetryManager.swift     # Opt-out CloudKit analytics
│   ├── DevMenuView.swift          # Developer tools (debug only)
│   ├── SparkleHelper.swift        # Sparkle auto-update wrapper
│   └── Info.plist                 # Sparkle feed URL and public key
├── SleepBarTests/                 # Unit tests
├── scripts/                       # Build, sign, notarize, appcast (used by mise tasks and CI)
├── .github/workflows/
│   ├── ci.yml                     # Build on PRs and main
│   └── release.yml                # Tag-driven release
├── CHANGELOG.md                   # Source of truth; CI copies it to the website
└── mise.toml                      # Toolchain pins and tasks
```

---

## Signing Notes

- **Hardened Runtime** is enabled. Library validation is disabled for the Sparkle framework.
- **App Sandbox** is off. Required for `pmset` and drive ejection.
- Entitlements include CloudKit and push, so a Developer ID **provisioning profile** is required at export. Xcode manages this automatically in the GUI; CI uses the profile from `DEVELOPER_ID_PROFILE_BASE64`.

### Never commit

- Sparkle private key
- `.p12` certificates or `.provisionprofile` files (gitignored)
