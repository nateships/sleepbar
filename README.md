# SleepBar - Private Development Repository

A simple and elegant sleep timer for macOS. Set your Mac to sleep after a duration or at a specific time.

**⚠️ This is the private development repository. The public website is at [zcpnate/sleepbar](https://github.com/zcpnate/sleepbar).**

---

## 🚀 Publishing a New Release

### 1. Update Version Numbers

In Xcode:
1. Select **SleepBar** target → **General** tab
2. Update **Version** (e.g., `1.0.1`)
3. Update **Build** (increment by 1)

Or in Build Settings:
- `MARKETING_VERSION` = `1.0.1`
- `CURRENT_PROJECT_VERSION` = `2`

### 2. Update Changelog

Edit `sleepbar-website/CHANGELOG.md` (the website automatically parses this file):
```markdown
## [1.0.1] - 2025-11-15

### Added
- New feature description

### Fixed
- Bug fix description

### Changed
- Changed behavior description
```

**Note**: The website will automatically display your changelog entries. No need to edit HTML!

### 3. Build & Archive

In Xcode:
1. **Product** → **Archive**
2. **Distribute App** → **Developer ID**
3. **Upload** (this notarizes with Apple)
4. Wait for notarization (5-30 minutes)
5. **Export Notarized App**

### 4. Create DMG

```bash
# Create DMG
hdiutil create -volname "SleepBar" -srcfolder /path/to/SleepBar.app -ov -format UDZO ~/Desktop/SleepBar-1.0.1.dmg

# Sign DMG
codesign --sign "Developer ID Application: Your Name" ~/Desktop/SleepBar-1.0.1.dmg

# Verify signature
codesign -vvv --deep --strict ~/Desktop/SleepBar-1.0.1.dmg
spctl -a -vvv -t install ~/Desktop/SleepBar-1.0.1.dmg
```

### 5. Create GitHub Release

**Option A: Via GitHub CLI**
```bash
gh release create v1.0.1 \
  --repo zcpnate/sleepbar \
  --title "SleepBar 1.0.1" \
  --notes "$(cat sleepbar-website/CHANGELOG.md | sed -n '/## \[1.0.1\]/,/## \[/p' | sed '$d')" \
  ~/Desktop/SleepBar-1.0.1.dmg
```

**Option B: Via GitHub Web Interface**
1. Go to https://github.com/zcpnate/sleepbar/releases
2. Click **Draft a new release**
3. Tag: `v1.0.1`
4. Release title: `SleepBar 1.0.1`
5. Copy release notes from CHANGELOG.md
6. Upload `SleepBar-1.0.1.dmg`
7. Click **Publish release**

### 6. Generate Sparkle Appcast

```bash
# Go to website repo
cd "/Users/nofarrell/Library/Mobile Documents/com~apple~CloudDocs/Documents/SleepBar/sleepbar-website"

# Download the release DMG
wget https://github.com/zcpnate/sleepbar/releases/download/v1.0.1/SleepBar-1.0.1.dmg

# Generate appcast (finds Sparkle binary automatically)
~/Library/Developer/Xcode/DerivedData/SleepBar-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast .

# Or if you have Sparkle installed globally:
/path/to/Sparkle/bin/generate_appcast .

# Commit and push
git add appcast.xml *.delta
git commit -m "Update appcast for v1.0.1"
git push
```

### 7. Update Website (Optional)

The changelog updates automatically from `CHANGELOG.md`. Only update the website if you changed:
- Features section
- Pricing
- Hero text
- Download links

```bash
cd sleepbar-website
# Edit index.html
git add index.html
git commit -m "Update website content for v1.0.1"
git push
```

### 8. Test the Update

1. Download previous version from releases
2. Install and run it
3. Click "Check for Updates" in the app
4. Verify update downloads and installs correctly

---

## 🛠️ Development Setup

### Requirements
- Xcode 15.0+
- macOS 14.0+ (Sonoma or later)
- Apple Developer Program membership (for distribution)
- Sparkle framework (added via Swift Package Manager)

### First Time Setup

1. **Clone the repository**
```bash
git clone https://github.com/zcpnate/sleepbar-private.git
cd sleepbar-private
```

2. **Open in Xcode**
```bash
open SleepBar/SleepBar.xcodeproj
```

3. **Configure Signing**
   - Select **SleepBar** target
   - Go to **Signing & Capabilities**
   - Select your **Developer ID Application** certificate
   - Ensure **App Sandbox** is OFF (required for `pmset` commands)

4. **Add Sparkle Framework** (if not already added)
   - File → Add Packages...
   - URL: `https://github.com/sparkle-project/Sparkle`
   - Version: `2.0.0` - `3.0.0`
   - Add to SleepBar target

5. **Generate Sparkle Keys** (first time only)
```bash
cd ~/Library/Developer/Xcode/DerivedData/SleepBar-*/SourcePackages/artifacts/sparkle/Sparkle/bin/
./generate_keys
```

Save the private key in Keychain! Add the public key to `Info.plist`:
- Key: `SUPublicEDKey`
- Value: Your public key from above

6. **Configure Info.plist**

Add these keys (if not already present):
- `SUFeedURL`: `https://sleepbar.app/appcast.xml`
- `SUPublicEDKey`: Your Sparkle public key
- `CFBundleShortVersionString`: `1.0.0`
- `CFBundleVersion`: `1`

### Running Locally

```bash
# Build and run
cmd+R in Xcode

# Or via command line
xcodebuild -project SleepBar/SleepBar.xcodeproj -scheme SleepBar -configuration Debug
```

---

## 🧪 Testing Licensing

### Developer Tools (Debug Builds Only)

In debug builds, you have access to developer tools:
- **Cmd+Shift+D** or click "Developer Tools" in the menu

Available actions:
- **Reset Trial**: Start a fresh 7-day trial
- **Expire Trial**: Set trial to expired (for testing post-trial UX)
- **Generate Test Key**: Create a fake license key (doesn't work with Lemon Squeezy API)
- **Deactivate License**: Remove current license

### Testing with Real Lemon Squeezy License

1. Create a test product in Lemon Squeezy (sandbox mode)
2. Purchase a license
3. Use the real license key in the app
4. Test activation, validation, and deactivation

---

## 📁 Project Structure

```
SleepBar/
├── SleepBar/
│   ├── SleepBarApp.swift          # App entry point
│   ├── ContentView.swift          # Main menu UI
│   ├── MenuBarLabel.swift         # Menu bar icon/label
│   ├── SleepTimerManager.swift    # Timer logic
│   ├── SleepWarningView.swift     # Warning popup content
│   ├── SleepWarningWindow.swift   # Warning window manager
│   ├── AboutView.swift            # About window
│   ├── LicenseManager.swift       # Trial & licensing
│   ├── LicenseView.swift          # License activation UI
│   ├── DevMenuView.swift          # Developer tools (debug only)
│   ├── SparkleHelper.swift        # Sparkle auto-update wrapper
│   └── Assets.xcassets/           # App icon & resources
├── SleepBar.xcodeproj/            # Xcode project
├── docs/
│   └── SETUP_GUIDE.md             # Initial setup instructions
└── README.md                      # This file
```

---

## 🔐 Security & Signing

### Developer ID Certificate

Required for distributing outside Mac App Store:
1. Join Apple Developer Program ($99/year)
2. Xcode → Settings → Accounts → Manage Certificates
3. Add **Developer ID Application** certificate

### Hardened Runtime

Already enabled in project settings:
- Required for notarization
- Library validation disabled (for Sparkle framework)

### Notarization

Automatic when you:
- Archive with Developer ID certificate
- Choose "Upload" during distribution
- Wait 5-30 minutes for Apple's approval

### What NOT to Commit

Never commit to this repository:
- ❌ Sparkle private signing key (store in Keychain)
- ❌ Apple Developer certificates (managed by Xcode)
- ❌ Lemon Squeezy API keys (hardcoded in app, OK for this use case)
- ❌ Test license keys (generate as needed)

---

## 🔗 Related Repositories

- **Public Website**: https://github.com/zcpnate/sleepbar (public)
- **This Repo**: https://github.com/zcpnate/sleepbar-private (private)

---

## 🌐 Important URLs

| Service | URL |
|---------|-----|
| Website | https://sleepbar.app |
| Public Repo | https://github.com/zcpnate/sleepbar |
| Private Repo | https://github.com/zcpnate/sleepbar-private |
| Releases | https://github.com/zcpnate/sleepbar/releases |
| Appcast | https://sleepbar.app/appcast.xml |
| Lemon Squeezy | https://app.lemonsqueezy.com |

---

## 📚 Documentation

- **README.md** (this file) - Development & release guide
- **[docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)** - One-time initial setup instructions

---

## 🆘 Troubleshooting

### "Unable to obtain a task name port right" Warning
- Harmless warning from macOS sandbox system
- Doesn't affect functionality
- Can be ignored

### Sparkle Updates Not Working
- Verify `SUFeedURL` in Info.plist
- Check appcast.xml is accessible at https://sleepbar.app/appcast.xml
- Ensure DMG is signed and notarized

### License Activation Failing
- Check Lemon Squeezy API endpoint is correct
- Verify product is published (not in draft)
- Test with a real purchase in sandbox mode

### pmset Commands Not Working
- Verify App Sandbox is **OFF** in project settings
- Check `ENABLE_APP_SANDBOX = NO` in project.pbxproj

---

## 📧 Contact

- Email: nate@sleepbar.app
- GitHub: [@zcpnate](https://github.com/zcpnate)

---

## 📄 License

© 2025 Nate O'Farrell. All rights reserved.

This is proprietary software. Source code is private.

