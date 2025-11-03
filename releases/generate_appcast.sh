#!/bin/bash
# SleepBar Appcast Generator
# Run from: /Users/nofarrell/Library/Mobile Documents/com~apple~CloudDocs/Documents/SleepBar/SleepBar/releases

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

WORKING_DIR="$(pwd)"
TEMP_APPCAST_DIR="$WORKING_DIR/build/appcast_temp"
WEBSITE_DIR="/Users/nofarrell/Library/Mobile Documents/com~apple~CloudDocs/Documents/SleepBar/sleepbar-website"

# GitHub Releases configuration
GITHUB_USER="zcpnate"
GITHUB_REPO="sleepbar"
USE_GITHUB_RELEASES=true  # Set to true to use GitHub Releases URLs

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Generating Appcast for SleepBar${NC}"
echo -e "${BLUE}========================================${NC}"

# Find Sparkle's generate_appcast tool
echo -e "\n${GREEN}→ Finding Sparkle tools...${NC}"
SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -path "*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast" 2>/dev/null | head -n 1)

if [ -z "$SPARKLE_BIN" ]; then
    echo -e "${RED}Error: Could not find Sparkle's generate_appcast tool${NC}"
    echo -e "${BLUE}Make sure Sparkle is added to your Xcode project via Swift Package Manager${NC}"
    echo -e "\nTo find it manually:"
    echo "  find ~/Library/Developer/Xcode/DerivedData -name generate_appcast"
    exit 1
fi

echo -e "${GREEN}✓ Found: $SPARKLE_BIN${NC}"

# Create temp directory and copy all DMGs to root level
echo -e "\n${GREEN}→ Preparing DMGs for appcast generation...${NC}"
rm -rf "$TEMP_APPCAST_DIR"
mkdir -p "$TEMP_APPCAST_DIR"

# Find and copy all DMGs from version directories
DMG_COUNT=0
for dmg in "$WORKING_DIR"/*/*.dmg; do
    if [ -f "$dmg" ]; then
        cp "$dmg" "$TEMP_APPCAST_DIR/"
        echo "  • $(basename "$dmg")"
        DMG_COUNT=$((DMG_COUNT + 1))
    fi
done

if [ $DMG_COUNT -eq 0 ]; then
    echo -e "${RED}Error: No DMG files found in version directories${NC}"
    echo -e "${BLUE}Make sure you have DMGs in subdirectories like: releases/1.0.0/SleepBar-1.0.0.dmg${NC}"
    rm -rf "$TEMP_APPCAST_DIR"
    exit 1
fi

echo -e "${GREEN}✓ Found $DMG_COUNT DMG(s)${NC}"

# Generate appcast
echo -e "\n${GREEN}→ Generating appcast.xml...${NC}"

if [ "$USE_GITHUB_RELEASES" = true ]; then
    # Use GitHub Releases URL format
    DOWNLOAD_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download"
    echo -e "${BLUE}Using GitHub Releases for downloads${NC}"
    "$SPARKLE_BIN" --download-url-prefix "$DOWNLOAD_URL" "$TEMP_APPCAST_DIR"
else
    # Use website URL format
    echo -e "${BLUE}Using website for downloads${NC}"
    "$SPARKLE_BIN" "$TEMP_APPCAST_DIR"
fi

if [ ! -f "$TEMP_APPCAST_DIR/appcast.xml" ]; then
    echo -e "${RED}Error: Appcast generation failed${NC}"
    rm -rf "$TEMP_APPCAST_DIR"
    exit 1
fi

# Copy appcast to releases root
cp "$TEMP_APPCAST_DIR/appcast.xml" "$WORKING_DIR/"
echo -e "${GREEN}✓ Appcast saved: $WORKING_DIR/appcast.xml${NC}"

# Copy to website directory
if [ -d "$WEBSITE_DIR" ]; then
    echo -e "\n${GREEN}→ Copying to website directory...${NC}"
    
    # Copy appcast
    cp "$TEMP_APPCAST_DIR/appcast.xml" "$WEBSITE_DIR/"
    
    if [ "$USE_GITHUB_RELEASES" = true ]; then
        # Only copy appcast and deltas, not DMGs (those go to GitHub Releases)
        if ls "$TEMP_APPCAST_DIR"/*.delta 2>/dev/null; then
            cp "$TEMP_APPCAST_DIR"/*.delta "$WEBSITE_DIR/"
            echo -e "${GREEN}✓ Copied appcast and delta updates${NC}"
        else
            echo -e "${GREEN}✓ Copied appcast${NC}"
        fi
        
        echo -e "\n${BLUE}Remember to upload DMGs to GitHub Releases:${NC}"
        for dmg in "$WORKING_DIR"/*/*.dmg; do
            if [ -f "$dmg" ] && [[ ! "$dmg" =~ SleepBar\.dmg$ ]]; then
                BASENAME=$(basename "$dmg")
                VERSION=$(echo "$BASENAME" | sed 's/SleepBar-\(.*\)\.dmg/\1/')
                DIRNAME=$(dirname "$dmg")
                GENERIC_DMG="$DIRNAME/SleepBar.dmg"
                
                # Copy with generic name
                cp "$dmg" "$GENERIC_DMG"
                echo "  • Created $GENERIC_DMG for release"
                echo "  • Command: gh release create v${VERSION} --title \"SleepBar ${VERSION}\" \"$GENERIC_DMG\" -F CHANGELOG.md"
            fi
        done
    else
        # Copy DMGs to website root
        for dmg in "$WORKING_DIR"/*/*.dmg; do
            if [ -f "$dmg" ]; then
                cp "$dmg" "$WEBSITE_DIR/"
                echo "  • Copied $(basename "$dmg")"
            fi
        done
        
        # Copy any delta updates
        if ls "$TEMP_APPCAST_DIR"/*.delta 2>/dev/null; then
            cp "$TEMP_APPCAST_DIR"/*.delta "$WEBSITE_DIR/"
            echo -e "${GREEN}✓ Copied appcast, DMGs, and delta updates${NC}"
        else
            echo -e "${GREEN}✓ Copied appcast and DMGs${NC}"
        fi
    fi
else
    echo -e "${BLUE}Note: Website directory not found, skipping copy${NC}"
fi

# Clean up
rm -rf "$TEMP_APPCAST_DIR"

# Success!
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Appcast generation complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nAppcast location:"
echo -e "  ${BLUE}$WORKING_DIR/appcast.xml${NC}"

if [ -d "$WEBSITE_DIR" ]; then
    echo -e "\nNext steps:"
    echo "  1. Review the appcast.xml"
    echo "  2. Push to website:"
    echo "     cd \"$WEBSITE_DIR\""
    echo "     git add appcast.xml *.delta"
    echo "     git commit -m \"Update appcast\""
    echo "     git push"
fi

echo ""

