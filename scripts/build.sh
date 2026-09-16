#!/bin/bash
# Debug build without code signing. Used by CI on pull requests.

source "$(dirname "$0")/common.sh"

xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    build | pretty
