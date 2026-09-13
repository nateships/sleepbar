#!/bin/bash
# Shared variables for the build scripts. Source this file, do not run it.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/SleepBar.xcodeproj"
SCHEME="SleepBar"
TEAM_ID="AMR56F4NQB"
BUNDLE_ID="app.sleepbar.SleepBar"
SIGNING_IDENTITY="Developer ID Application"
RELEASES_REPO="nateships/sleepbar"

BUILD_DIR="$ROOT/build"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$BUILD_DIR/DerivedData}"
ARCHIVE_PATH="$BUILD_DIR/SleepBar.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_PATH="$EXPORT_PATH/SleepBar.app"
DMG_PATH="$BUILD_DIR/SleepBar.dmg"

# Pipe xcodebuild output through xcbeautify when it is installed.
pretty() {
    if command -v xcbeautify >/dev/null 2>&1; then
        xcbeautify
    else
        cat
    fi
}

# Require VERSION (semver, for example 1.1.1) and derive the Sparkle build
# number from it: major*10000 + minor*100 + patch. 1.1.1 -> 10101.
# This number must always increase. It is larger than every build number
# that shipped before this scheme (last manual build number was 8).
require_version() {
    : "${VERSION:?Set VERSION, for example VERSION=1.1.1}"
    if ! [[ "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        echo "VERSION must be MAJOR.MINOR.PATCH, got: $VERSION" >&2
        exit 2
    fi
    BUILD_NUMBER=$(( BASH_REMATCH[1] * 10000 + BASH_REMATCH[2] * 100 + BASH_REMATCH[3] ))
}
