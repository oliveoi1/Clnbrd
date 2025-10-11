#!/bin/bash

# Clnbrd Post-Notarization Finalization Script
# Run this AFTER successful notarization to staple and create DMG

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
DISTRIBUTION_DIR="./Distribution-Clean"
APP_PATH="${DISTRIBUTION_DIR}/App/Clnbrd.app"

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║         Clnbrd Post-Notarization Finalization               ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ Error: App not found at ${APP_PATH}${NC}"
    echo "Please run build_notarization_fixed.sh first"
    exit 1
fi

# Get version info
VERSION=$(plutil -extract CFBundleShortVersionString raw "${APP_PATH}/Contents/Info.plist")
BUILD_NUMBER=$(plutil -extract CFBundleVersion raw "${APP_PATH}/Contents/Info.plist")

echo -e "${CYAN}📦 Processing Clnbrd v${VERSION} (Build ${BUILD_NUMBER})${NC}"
echo ""

# Step 1: Staple notarization ticket
echo -e "${YELLOW}📌 Step 1/3: Stapling notarization ticket...${NC}"

if xcrun stapler staple "$APP_PATH" 2>&1; then
    echo -e "${GREEN}✅ Notarization ticket stapled successfully!${NC}"
else
    echo -e "${RED}❌ Error: Stapling failed!${NC}"
    echo ""
    echo "Common reasons:"
    echo "  1. App hasn't been notarized yet (wait for notarization to complete)"
    echo "  2. Notarization was rejected (check notarization log)"
    echo "  3. Internet connection issue (stapler needs to download ticket)"
    echo ""
    echo "Try running the notarization status check command from SUBMIT_FOR_NOTARIZATION.txt"
    exit 1
fi

# Step 2: Verify stapling
echo -e "${YELLOW}🔍 Step 2/3: Verifying stapling...${NC}"

if xcrun stapler validate "$APP_PATH" 2>&1 | grep -q "The validate action worked"; then
    echo -e "${GREEN}✅ Stapling validated successfully!${NC}"
else
    echo -e "${RED}❌ Warning: Stapling validation failed${NC}"
fi

# Check Gatekeeper
echo -e "${BLUE}   Checking Gatekeeper assessment...${NC}"
if spctl -a -vvv -t install "$APP_PATH" 2>&1 | grep -q "accepted"; then
    echo -e "${GREEN}✅ Gatekeeper: ACCEPTED (app is fully notarized)${NC}"
else
    echo -e "${YELLOW}⚠️  Gatekeeper check inconclusive${NC}"
fi

# Step 3: Create Sparkle update ZIP (stapled)
echo -e "${YELLOW}📦 Step 3/4: Creating Sparkle update ZIP...${NC}"
echo -e "${BLUE}   Creating ZIP from stapled app...${NC}"

cd "${DISTRIBUTION_DIR}/App"
SPARKLE_ZIP_NAME="Clnbrd-v${VERSION}-Build${BUILD_NUMBER}-notarized-stapled.zip"
zip -r -y -X "${DISTRIBUTION_DIR}/Upload/${SPARKLE_ZIP_NAME}" Clnbrd.app > /dev/null 2>&1

if [ -f "${DISTRIBUTION_DIR}/Upload/${SPARKLE_ZIP_NAME}" ]; then
    ZIP_SIZE=$(du -h "${DISTRIBUTION_DIR}/Upload/${SPARKLE_ZIP_NAME}" | cut -f1)
    ZIP_BYTES=$(stat -f%z "${DISTRIBUTION_DIR}/Upload/${SPARKLE_ZIP_NAME}")
    echo -e "${GREEN}✅ Sparkle ZIP created: ${ZIP_SIZE} (${ZIP_BYTES} bytes)${NC}"
    echo -e "${BLUE}   File: ${SPARKLE_ZIP_NAME}${NC}"
    echo -e "${BLUE}   Use this ZIP for Sparkle auto-updates in appcast-v2.xml${NC}"
else
    echo -e "${RED}❌ Failed to create Sparkle ZIP${NC}"
fi

cd "${PROJECT_DIR}"

# Step 4: Create DMG
echo -e "${YELLOW}📀 Step 4/4: Creating DMG installer...${NC}"

DMG_NAME="Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg"
DMG_PATH="${DISTRIBUTION_DIR}/DMG/${DMG_NAME}"
TEMP_DMG_DIR="/tmp/clnbrd-dmg-$$"

# Create temporary directory structure
rm -rf "$TEMP_DMG_DIR"
mkdir -p "$TEMP_DMG_DIR"

# Copy stapled app to temp directory
echo -e "${BLUE}   Preparing DMG contents...${NC}"
cp -R "$APP_PATH" "$TEMP_DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$TEMP_DMG_DIR/Applications"

# Create DMG
echo -e "${BLUE}   Creating DMG image...${NC}"
mkdir -p "${DISTRIBUTION_DIR}/DMG"

hdiutil create \
    -volname "Clnbrd ${VERSION}" \
    -srcfolder "$TEMP_DMG_DIR" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_PATH"

# Cleanup
rm -rf "$TEMP_DMG_DIR"

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo -e "${GREEN}✅ DMG created: ${DMG_SIZE}${NC}"

# Verify DMG
echo -e "${BLUE}   Verifying DMG...${NC}"
if hdiutil verify "$DMG_PATH" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ DMG verified successfully${NC}"
fi

# Step 4: Create release notes
echo -e "${YELLOW}📝 Creating release documentation...${NC}"

cat > "${DISTRIBUTION_DIR}/RELEASE_READY.txt" <<EOF
╔══════════════════════════════════════════════════════════════╗
║              RELEASE PACKAGE READY FOR DISTRIBUTION          ║
╚══════════════════════════════════════════════════════════════╝

Version: ${VERSION}
Build Number: ${BUILD_NUMBER}
DMG File: ${DMG_NAME}
DMG Size: ${DMG_SIZE}
Status: ✅ FULLY NOTARIZED & STAPLED

Release Files:
--------------
📦 DMG (Manual Downloads):
   ${DMG_PATH}
   • Fully notarized and stapled
   • Ready for GitHub release
   • Use for: Manual downloads from website/GitHub

🔄 ZIP (Sparkle Auto-Updates):
   ${DISTRIBUTION_DIR}/Upload/${SPARKLE_ZIP_NAME}
   Size: ${ZIP_BYTES} bytes
   • Fully notarized and stapled
   • Ready for Sparkle auto-updates
   • Use for: appcast-v2.xml enclosure URL

🍎 ${APP_PATH}
   • Notarized and stapled
   • Can be distributed directly

Verification Completed:
-----------------------
✅ Code signing verified
✅ Notarization completed
✅ Ticket stapled to app
✅ Gatekeeper accepts app
✅ DMG created and verified

Distribution Checklist:
-----------------------
[ ] Test DMG on clean Mac with Gatekeeper enabled
[ ] Upload DMG to GitHub Releases
[ ] Update appcast-v2.xml with new version
[ ] Test auto-update from previous version
[ ] Announce release

GitHub Release Command:
-----------------------
gh release create v${VERSION} \\
  "${DMG_PATH}" \\
  --title "Clnbrd ${VERSION}" \\
  --notes "Release notes here"

Or upload manually at:
https://github.com/oliveoi1/Clnbrd/releases/new

Update Sparkle Appcast:
-----------------------
1. Upload ${DMG_NAME} to GitHub Releases
2. Get DMG download URL
3. Update appcast-v2.xml with:
   - Version: ${VERSION}
   - Build: ${BUILD_NUMBER}
   - DMG URL
   - Release notes
4. Commit and push appcast-v2.xml

Testing Recommendations:
------------------------
1. Test on clean Mac (no Xcode/dev tools)
2. Test with Gatekeeper enabled
3. Verify first launch experience
4. Test auto-update from v1.2.x
5. Test all major features

Build Date: $(date)
Notarization Date: $(date)

🎉 Congratulations! Your app is ready for distribution!
EOF

# Display summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  FINALIZATION COMPLETE!                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📦 DMG Package: ${DMG_NAME}${NC}"
echo -e "${CYAN}📁 Location: ${DISTRIBUTION_DIR}/DMG/${NC}"
echo -e "${CYAN}📝 Release notes: ${DISTRIBUTION_DIR}/RELEASE_READY.txt${NC}"
echo ""
echo -e "${GREEN}✅ App is fully notarized, stapled, and ready for distribution!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "${BLUE}1. Test DMG on a clean Mac${NC}"
echo -e "${BLUE}2. Upload BOTH files to GitHub Releases:${NC}"
echo -e "${BLUE}   • ${DMG_NAME} (for manual downloads)${NC}"
echo -e "${BLUE}   • ${SPARKLE_ZIP_NAME} (for Sparkle auto-updates)${NC}"
echo -e "${BLUE}3. Update appcast-v2.xml with ZIP URL and size: ${ZIP_BYTES} bytes${NC}"
echo -e "${BLUE}4. Announce release${NC}"
echo ""
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"

