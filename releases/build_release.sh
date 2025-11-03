#!/bin/bash
# SleepBar Release Build Script
# Run from: /Users/nofarrell/Library/Mobile Documents/com~apple~CloudDocs/Documents/SleepBar/SleepBar/releases

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VERSION="$1"
if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Version number required${NC}"
    echo "Usage: ./build_release.sh 1.0.0"
    exit 1
fi

SIGNING_IDENTITY="Developer ID Application"
APP_NAME="SleepBar"
WORKING_DIR="$(pwd)"
VERSION_DIR="$WORKING_DIR/$VERSION"
TMP_DIR="$WORKING_DIR/build/tmp"
APP_PATH="$VERSION_DIR/${APP_NAME}.app"
DMG_PATH="$VERSION_DIR/${APP_NAME}-${VERSION}.dmg"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Building ${APP_NAME} v${VERSION}${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if version directory exists
if [ ! -d "$VERSION_DIR" ]; then
    echo -e "${RED}Error: Version directory not found: $VERSION_DIR${NC}"
    echo -e "${BLUE}Creating version directory...${NC}"
    mkdir -p "$VERSION_DIR"
fi

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: ${APP_NAME}.app not found at: $APP_PATH${NC}"
    echo -e "\n${BLUE}Please ensure you have:${NC}"
    echo "  1. Created an Archive in Xcode (Product → Archive)"
    echo "  2. Exported the notarized app"
    echo "  3. Placed ${APP_NAME}.app in: $VERSION_DIR/"
    exit 1
fi

# Clean and create directories
echo -e "\n${GREEN}→ Preparing build directories...${NC}"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# Copy app to temp directory
echo -e "\n${GREEN}→ Copying app to temp directory...${NC}"
cp -R "$APP_PATH" "$TMP_DIR/"

# Create Applications symlink
echo -e "${GREEN}→ Creating Applications symlink...${NC}"
ln -s /Applications "$TMP_DIR/Applications"

# Create DMG
echo -e "\n${GREEN}→ Creating DMG...${NC}"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$TMP_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# Sign DMG
echo -e "\n${GREEN}→ Signing DMG...${NC}"
codesign --sign "$SIGNING_IDENTITY" "$DMG_PATH"

# Verify signature
echo -e "\n${GREEN}→ Verifying signature...${NC}"
codesign -vvv --deep --strict "$DMG_PATH"

# Clean up
echo -e "\n${GREEN}→ Cleaning up temp files...${NC}"
rm -rf "$TMP_DIR"

# Notarize DMG
echo -e "\n${GREEN}→ Notarizing DMG with Apple...${NC}"
echo -e "${BLUE}This will take 5-15 minutes.${NC}"

xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "notarytool" \
    --wait

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}→ Stapling notarization ticket...${NC}"
    xcrun stapler staple "$DMG_PATH"
    
    echo -e "\n${GREEN}→ Final verification...${NC}"
    spctl -a -vvv -t install "$DMG_PATH"
    
    # Success!
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ Build complete and notarized!${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo -e "\n${RED}========================================${NC}"
    echo -e "${RED}Notarization failed!${NC}"
    echo -e "${RED}========================================${NC}"
    echo -e "\n${BLUE}Troubleshooting:${NC}"
    echo "  1. Ensure notarytool is configured:"
    echo "     xcrun notarytool store-credentials \"notarytool\" \\"
    echo "       --apple-id \"your@email.com\" \\"
    echo "       --team-id \"AMR56F4NQB\" \\"
    echo "       --password \"app-specific-password\""
    echo ""
    echo "  2. Check submission history:"
    echo "     xcrun notarytool history --keychain-profile \"notarytool\""
    echo ""
    exit 1
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Build complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nDMG location:"
echo -e "  ${BLUE}$DMG_PATH${NC}"
echo -e "\nVersion directory:"
echo -e "  ${BLUE}$VERSION_DIR/${NC}"
# Create generic filename for GitHub releases
GENERIC_DMG_PATH="$VERSION_DIR/SleepBar.dmg"
cp "$DMG_PATH" "$GENERIC_DMG_PATH"
echo -e "${GREEN}✓ Created generic DMG: SleepBar.dmg${NC}"

echo -e "\nNext steps:"
echo "  1. Test the DMG on a clean Mac"
echo "  2. Generate appcast: ./generate_appcast.sh"
echo "  3. Create GitHub release:"
echo "     gh release create v${VERSION} --title \"SleepBar ${VERSION}\" \"$GENERIC_DMG_PATH\" -F CHANGELOG.md"
echo "  4. Push website updates with appcast.xml"
echo ""

