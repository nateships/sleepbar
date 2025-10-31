# SleepBar (Private Repository)

A beautiful sleep timer for macOS.

## 🔒 This is a Private Repository

- **Source Code**: Kept private for security
- **Website & Releases**: https://github.com/zcpnate/sleepbar (public)
- **Marketing Site**: https://sleepbar.app

## 🛠️ Development Setup

### Prerequisites
- Xcode 15.0+
- macOS 14.0+
- Swift 5.9+

### Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/zcpnate/sleepbar-private.git
   cd sleepbar-private
   ```

2. **Open in Xcode**
   ```bash
   open SleepBar.xcodeproj
   ```

3. **Add Sparkle Framework**
   - File → Add Packages...
   - Enter: `https://github.com/sparkle-project/Sparkle`
   - See `SPARKLE_SETUP.md` for details

4. **Configure Signing**
   - Select your development team in project settings
   - Update bundle identifier if needed

### Building

```bash
# Debug build
xcodebuild -project SleepBar.xcodeproj -scheme SleepBar -configuration Debug

# Release build (Archive)
# Use Xcode: Product → Archive
```

## 🎯 Features

- ⏱️ Quick timer presets (15m, 30m, 1h, 2h)
- 🎯 Custom duration timers
- 🕐 Specific time scheduling
- 💻 System or display-only sleep modes
- ⚠️ Pre-sleep warning (1 min before)
- 🔑 7-day trial with Lemon Squeezy licensing
- 🔄 Sparkle auto-updates

## 📋 Architecture

### Key Components

- **SleepTimerManager**: Core timer logic and sleep execution
- **LicenseManager**: Lemon Squeezy integration & trial management
- **SparkleHelper**: Auto-update functionality
- **ContentView**: Main menu bar UI
- **SleepWarningView**: Pre-sleep alert window

### Technologies

- **SwiftUI**: UI framework
- **Combine**: Reactive programming
- **Sparkle 2**: Auto-updates
- **Lemon Squeezy API**: Licensing
- **IOKit**: System/display sleep

## 🧪 Testing

### Developer Tools (DEBUG builds only)

Press `⌘⇧D` or access via menu to open developer tools:
- Reset trial period
- Generate test license keys
- Expire trial (test lock screen)
- View license status

## 🚀 Release Process

See `RELEASE.md` for detailed release instructions.

Quick overview:
1. Update version in Info.plist
2. Archive via Xcode
3. Export with Developer ID
4. Create release in public repo
5. Generate and upload appcast

## 📝 Documentation

- `SPARKLE_SETUP.md` - Auto-update configuration
- `RELEASE.md` - Release process
- `ARCHITECTURE.md` - Code architecture (TODO)

## 🔐 Security Notes

### Never Commit:
- Lemon Squeezy API keys
- Sparkle private signing keys
- Keychain files
- Developer certificates

### Keep in Keychain:
- Sparkle EdDSA private key
- Apple Developer certificates

## 📧 Support

For issues or questions:
- Email: nate@sleepbar.app
- Website: https://sleepbar.app

## 📄 License

Proprietary - All Rights Reserved © 2025 Nate O'Farrell
