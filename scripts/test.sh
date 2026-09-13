#!/bin/bash
# Run unit tests. The test host needs a signed app, so Xcode must be signed in
# to the team for automatic signing to work.

source "$(dirname "$0")/common.sh"

xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    test | pretty
