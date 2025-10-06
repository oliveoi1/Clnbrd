#!/bin/bash

# Clnbrd Post-Notarization Finalization Script
# Staples notarization ticket, creates DMG, generates JSON, and prepares GitHub release

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check for build number argument
if [ -z "$1" ]; then
    echo -e "${RED}❌ Error: Build number required${NC}"
    echo "Usage: $0 <BUILD_NUMBER>"
    echo "Example: $0 33"
    exit 1
fi

BUILD_NUMBER=$1
BUILD_DIR="./Distribution"
ZIP_FILE="${BUILD_DIR}/Upload/Clnbrd-Build${BUILD_NUMBER}.zip"

# Get version from Info.plist
VERSION=$(plutil -extract CFBundleShortVersionString raw Clnbrd/Info.plist)

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           Finalizing Notarized Build ${BUILD_NUMBER}                   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if ZIP exists
if [ ! -f "${ZIP_FILE}" ]; then
    echo -e "${RED}❌ Error: ${ZIP_FILE} not found!${NC}"
    exit 1
fi

# Extract and staple
echo -e "${YELLOW}📦 Extracting notarized app...${NC}"
rm -rf "${BUILD_DIR}/Notarized"
mkdir -p "${BUILD_DIR}/Notarized"
cd "${BUILD_DIR}/Notarized"
ditto -xk "../Upload/Clnbrd-Build${BUILD_NUMBER}.zip" .
cd ../..

echo -e "${YELLOW}✏️  Stapling notarization ticket...${NC}"
xcrun stapler staple "${BUILD_DIR}/Notarized/Clnbrd.app"
xcrun stapler validate "${BUILD_DIR}/Notarized/Clnbrd.app"
echo -e "${GREEN}✅ Notarization ticket stapled!${NC}"

# Verify with Gatekeeper
echo -e "${YELLOW}🔍 Verifying with Gatekeeper...${NC}"
spctl -a -vv "${BUILD_DIR}/Notarized/Clnbrd.app"
echo -e "${GREEN}✅ Gatekeeper approved!${NC}"

# Create notarized ZIP
echo -e "${YELLOW}📦 Creating final notarized ZIP...${NC}"
cd "${BUILD_DIR}"
ditto -c -k --keepParent Notarized/Clnbrd.app "Upload/Clnbrd-Build${BUILD_NUMBER}-Notarized.zip"
cd ..
ZIP_SIZE=$(du -h "${BUILD_DIR}/Upload/Clnbrd-Build${BUILD_NUMBER}-Notarized.zip" | cut -f1)
echo -e "${GREEN}✅ Notarized ZIP: ${ZIP_SIZE}${NC}"

# Create professional DMG
echo -e "${YELLOW}💿 Creating professional DMG installer...${NC}"
mkdir -p "${BUILD_DIR}/dmg_temp"
cp -R "${BUILD_DIR}/Notarized/Clnbrd.app" "${BUILD_DIR}/dmg_temp/"
ln -s /Applications "${BUILD_DIR}/dmg_temp/Applications"

cat > "${BUILD_DIR}/dmg_temp/INSTALL.txt" << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                    Clnbrd Installation                       ║
╚══════════════════════════════════════════════════════════════╝

✅ FULLY NOTARIZED BY APPLE - No security warnings!

📦 INSTALLATION INSTRUCTIONS
────────────────────────────────────────────────────────────────

1. Drag Clnbrd.app to the Applications folder
2. Open Clnbrd from your Applications folder or Spotlight
3. Grant Accessibility permissions when prompted
4. Start using the ⌘⌥V hotkey to paste clean text!

🎯 QUICK START
────────────────────────────────────────────────────────────────

• Copy any text with formatting
• Press ⌘⌥V to paste it clean
• Or enable Auto-clean in settings (⚙️ menu bar icon)

🔐 PERMISSIONS REQUIRED
────────────────────────────────────────────────────────────────

Clnbrd needs two permissions to work:

✓ Accessibility Access - To detect the ⌘⌥V hotkey
✓ Input Monitoring - To paste cleaned text

Grant these in System Settings → Privacy & Security

🔗 SUPPORT & FEEDBACK
────────────────────────────────────────────────────────────────

• GitHub: https://github.com/oliveoi1/Clnbrd
• Email: olivedesignstudios@gmail.com
• Issues: https://github.com/oliveoi1/Clnbrd/issues

Made with ❤️ for macOS by Allan Alomes
EOF

hdiutil create -volname "Clnbrd ${VERSION}" \
    -srcfolder "${BUILD_DIR}/dmg_temp" \
    -ov -format UDZO \
    -imagekey zlib-level=9 \
    "${BUILD_DIR}/DMG/Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg"

rm -rf "${BUILD_DIR}/dmg_temp"
DMG_SIZE=$(du -h "${BUILD_DIR}/DMG/Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg" | cut -f1)
echo -e "${GREEN}✅ Professional DMG created: ${DMG_SIZE}${NC}"

# Generate version JSON for auto-updates
echo -e "${YELLOW}📝 Generating version JSON...${NC}"
RELEASE_DATE=$(date +"%Y-%m-%d")

cat > "${BUILD_DIR}/Upload/clnbrd-version.json" <<EOF
{
  "version": "${VERSION}",
  "build": "${BUILD_NUMBER}",
  "dmg_filename": "Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg",
  "download_url": "https://github.com/oliveoi1/Clnbrd/releases/latest/download/Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg",
  "release_notes": "• ✅ Fully Notarized by Apple - No security warnings!\\n• 🔐 Code Signed with Developer ID - Verified and secure\\n• 🎯 ⌘⌥V Hotkey - Paste cleaned text instantly\\n• 🤖 Auto-clean on Copy - Automatically strip formatting\\n• 📋 Menu Bar Integration - Quick access from your Mac\\n• 🧹 Format Removal - Strips all formatting, styles, and metadata\\n• 🚀 Performance Monitoring - Built-in memory and CPU optimization\\n• 🔄 Error Recovery - Automatic recovery from clipboard issues\\n• 📊 Privacy-focused Analytics - Track usage patterns\\n• ⚡ Auto-updates - Seamless future updates",
  "release_date": "${RELEASE_DATE}",
  "minimum_os_version": "15.5"
}
EOF

echo -e "${GREEN}✅ Version JSON created!${NC}"

# Create GitHub release instructions
cat > "${BUILD_DIR}/GITHUB_RELEASE_INSTRUCTIONS.txt" <<EOF
GitHub Release Instructions for Build ${BUILD_NUMBER}
=====================================================

Files to Upload:
1. DMG: Distribution/DMG/Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg
2. ZIP: Distribution/Upload/Clnbrd-Build${BUILD_NUMBER}-Notarized.zip
3. JSON: Distribution/Upload/clnbrd-version.json

Command to create release:
--------------------------
cd /Users/allanalomes/Documents/AlsApp/Clnbrd

gh release create v${VERSION}-build${BUILD_NUMBER} \\
  --title "v${VERSION} (Build ${BUILD_NUMBER}) - ✅ Fully Notarized by Apple" \\
  --notes "Release notes here..." \\
  --latest \\
  Clnbrd/Distribution/DMG/Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg \\
  Clnbrd/Distribution/Upload/Clnbrd-Build${BUILD_NUMBER}-Notarized.zip \\
  Clnbrd/Distribution/Upload/clnbrd-version.json

Or to update existing release:
------------------------------
gh release upload v${VERSION}-build${BUILD_NUMBER} \\
  Clnbrd/Distribution/DMG/Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg \\
  Clnbrd/Distribution/Upload/Clnbrd-Build${BUILD_NUMBER}-Notarized.zip \\
  Clnbrd/Distribution/Upload/clnbrd-version.json \\
  --clobber
EOF

# Final summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              🎉 FINALIZATION COMPLETE! 🎉                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📦 Version: ${VERSION} (Build ${BUILD_NUMBER})${NC}"
echo ""
echo -e "${YELLOW}Distribution Files Created:${NC}"
echo -e "  • DMG: ${DMG_SIZE} - ${BUILD_DIR}/DMG/Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg"
echo -e "  • ZIP: ${ZIP_SIZE} - ${BUILD_DIR}/Upload/Clnbrd-Build${BUILD_NUMBER}-Notarized.zip"
echo -e "  • JSON: ${BUILD_DIR}/Upload/clnbrd-version.json"
echo ""
echo -e "${YELLOW}Next Step:${NC}"
echo -e "  📤 Upload to GitHub using instructions in:"
echo -e "     ${BUILD_DIR}/GITHUB_RELEASE_INSTRUCTIONS.txt"
echo ""

