# SleepBar Release Directory

This directory is used for building release DMGs.

## Directory Structure

```
releases/
├── 1.0.0/              # Version 1.0.0 release
│   ├── SleepBar.app   # Exported app from Xcode
│   └── SleepBar-1.0.0.dmg  # Final signed DMG
├── 1.0.1/              # Version 1.0.1 release (future)
├── build/              # Temporary build files (gitignored)
│   └── tmp/
├── build_release.sh   # Automated DMG creation script
└── README.md          # This file
```

## Usage

### 1. Export App from Xcode

1. In Xcode: **Product → Archive**
2. **Distribute App → Developer ID**
3. **Upload** and wait for notarization (~5-15 min)
4. **Export Notarized App**
5. Create version directory: `mkdir 1.0.0`
6. Copy `SleepBar.app` to `releases/1.0.0/`

### 2. Build DMG

```bash
cd "/Users/nofarrell/Library/Mobile Documents/com~apple~CloudDocs/Documents/SleepBar/SleepBar/releases"

# Make sure SleepBar.app is in the version directory:
# releases/1.0.0/SleepBar.app

# Then build:
./build_release.sh 1.0.0
```

### 3. Output

Your signed DMG will be at:
```
releases/1.0.0/SleepBar-1.0.0.dmg
```

## What the Script Does

1. ✓ Creates `build/tmp` directory
2. ✓ Copies `SleepBar.app` to temp
3. ✓ Creates symlink to `/Applications`
4. ✓ Creates compressed DMG
5. ✓ Signs DMG with Developer ID
6. ✓ Notarizes DMG with Apple
7. ✓ Staples notarization ticket
8. ✓ Generates appcast.xml for Sparkle updates
9. ✓ Copies appcast to website directory
10. ✓ Cleans up temp files

## Generate Appcast Separately

If you already have DMGs and just need to generate/update the appcast:

```bash
./generate_appcast.sh
```

This will:
- Find all DMGs in version directories (`1.0.0/`, `1.0.1/`, etc.)
- Generate `appcast.xml` with all releases
- Create delta updates for incremental patches
- Copy to website directory

## Next Steps

After building:
1. Test the DMG on a clean Mac
2. Upload to GitHub releases
3. Generate appcast.xml with Sparkle
4. Update website with download link

See [SETUP_GUIDE.md](../docs/SETUP_GUIDE.md) for complete release workflow.

