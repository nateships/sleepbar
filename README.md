# SleepBar - Private Development Repository

A simple and elegant sleep timer for macOS. Set your Mac to sleep after a duration or at a specific time.

**This is the private development repository. The public website, release downloads, appcast, and the release workflow live at [nateships/sleepbar](https://github.com/nateships/sleepbar).**

---

## Development

### Requirements

- Xcode 26 (macOS 15+)
- [mise](https://mise.jdx.dev) for the CLI toolchain (`gh`, `xcbeautify`)
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

Releases are built, signed, notarized, and published by GitHub Actions. The workflow file is `.github/workflows/release.yml` in the **public** repo `nateships/sleepbar`, because macOS runners are free there. It checks this repo out with a read-only token. Nothing is built on a developer machine.

Build logs are public. GitHub masks secrets. Source file names appear in the logs.

### 1. Write the changelog

Add a section to `CHANGELOG.md` here and merge to `main`. The release fails if the section is missing.

```markdown
## [1.1.1] - 09-20-2026

#### Bug Fixes
- Description
```

### 2. Dry run

```bash
mise run release-dry-run 1.1.1          # builds main
mise run release-dry-run 1.1.1 my-branch
```

Builds, signs, notarizes, uploads `SleepBar.dmg` as a workflow artifact. Publishes nothing. Download the artifact and test it.

### 3. Release

```bash
mise run release 1.1.1
```

Runs the workflow against `main` of this repo with `publish=true`. Equivalent: push tag `v1.1.1` to `nateships/sleepbar`, or run the workflow from the Actions tab there.

The version input is the source of truth. CI sets:
- `MARKETING_VERSION` = `1.1.1`
- `CURRENT_PROJECT_VERSION` (Sparkle build number) = `10101` (major×10000 + minor×100 + patch)

The version numbers in the Xcode project are not used for releases. The release notes record which commit of this repo was built.

### What the workflow does

1. Checks out `nateships/sleepbar` (site) and this repo (source)
2. Imports the Developer ID certificate and provisioning profile into a temporary keychain
3. Archives and exports the app with Developer ID (`scripts/archive.sh`)
4. Builds and signs the DMG (`scripts/dmg.sh`)
5. Notarizes and staples (`scripts/notarize.sh`)
6. Signs the DMG with the Sparkle EdDSA key and updates `appcast.xml` (`scripts/appcast.sh`)
7. Creates the GitHub release on `nateships/sleepbar` with `SleepBar-1.1.1.dmg` and `SleepBar.dmg`
8. Commits `appcast.xml` and `CHANGELOG.md` to `nateships/sleepbar` main. Cloudflare Pages deploys the site.

### 4. Verify

1. Install the previous version, open "Check for Updates", confirm the update installs.
2. `https://sleepbar.app/appcast.xml` shows the new version (cached for 5 minutes).

---

## CI Secrets

Set on **`nateships/sleepbar`** (the public repo) under Settings → Secrets and variables → Actions. Sources of truth are in the 1Password `sleepbar` and `Private` vaults.

| Secret | Content | Source |
|---|---|---|
| `PRIVATE_REPO_TOKEN` | Fine-grained PAT, repository `sleepbar-private`, Contents: read | github.com → Settings → Developer settings → Fine-grained tokens |
| `DEVELOPER_ID_P12_BASE64` | Developer ID Application cert + private key, base64 | 1Password "Apple Developer Cert pfx", attached `.p12` |
| `DEVELOPER_ID_P12_PASSWORD` | Password of that `.p12` | same item |
| `DEVELOPER_ID_PROFILE_BASE64` | Developer ID provisioning profile for `app.sleepbar.SleepBar`, base64 | 1Password document "SleepBar Developer ID provisioning profile" |
| `NOTARY_APPLE_ID` | Apple ID email | 1Password "Apple" login |
| `NOTARY_PASSWORD` | App-specific password | 1Password "notarytool app specific password" |
| `SPARKLE_PRIVATE_KEY` | Sparkle EdDSA private key, base64 string | 1Password "SleepBar Sparkle Keys". Public key must match `SUPublicEDKey` in `SleepBar/Info.plist` |

The Sparkle private key is the only thing that cannot be re-issued. If it is lost, installed apps reject every future update.

The Developer ID certificate expires 2027-02-01. When renewed: export the new `.p12`, regenerate the provisioning profile with the new cert, update both secrets and 1Password.

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
├── scripts/                       # Build, sign, notarize, appcast (used by mise tasks and the release workflow)
├── CHANGELOG.md                   # Source of truth; the release workflow copies it to the website
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
