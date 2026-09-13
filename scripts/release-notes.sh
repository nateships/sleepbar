#!/bin/bash
# Print the CHANGELOG.md section for VERSION. Fails when the section is missing
# so that a release cannot ship without notes.

source "$(dirname "$0")/common.sh"
require_version

NOTES=$(awk -v v="$VERSION" '
    $0 ~ "^## \\[" v "\\]" { found = 1; next }
    found && /^## \[/       { exit }
    found                   { print }
' "$ROOT/CHANGELOG.md")

if [ -z "$(tr -d '[:space:]' <<< "$NOTES")" ]; then
    echo "No CHANGELOG.md section found for [$VERSION]" >&2
    exit 1
fi
printf '%s\n' "$NOTES"
