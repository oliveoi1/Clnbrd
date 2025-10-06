#!/bin/bash

# Clnbrd Working DMG Creator Script
# Creates a DMG with Applications shortcut and instructions

set -e

# Configuration
APP_NAME="Clnbrd"
APP_VERSION="1.3"
DMG_NAME="Clnbrd-${APP_VERSION}"
DMG_FINAL_NAME="${DMG_NAME}"
VOLUME_NAME="Clnbrd Installer"
APP_PATH="../.././Distribution/App/Clnbrd.app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                    Clnbrd DMG Creator                        ║${NC}"
echo -e "${PURPLE}║              Professional Installer Generator               ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if app exists
if [ ! -d "${APP_PATH}" ]; then
    echo -e "${RED}❌ Error: ${APP_PATH} not found!${NC}"
    echo "Please build the app first or check the path."
    exit 1
fi

# Clean up existing DMG files
echo -e "${YELLOW}🧹 Cleaning up existing DMG files...${NC}"
rm -f "${DMG_FINAL_NAME}.dmg"

# Create a temporary directory for DMG contents
echo -e "${YELLOW}📁 Creating temporary directory...${NC}"
TEMP_DIR="dmg_contents"
rm -rf "${TEMP_DIR}"
mkdir "${TEMP_DIR}"

# Copy app to temp directory
echo -e "${YELLOW}📱 Copying app to temporary directory...${NC}"
cp -R "${APP_PATH}" "${TEMP_DIR}/"

# Create Applications folder alias
echo -e "${YELLOW}📁 Creating Applications folder alias...${NC}"
ln -s /Applications "${TEMP_DIR}/Applications"

# Create installation instructions file
echo -e "${YELLOW}📝 Creating installation instructions...${NC}"
cat > "${TEMP_DIR}/Install Instructions.txt" << 'EOF'
Clnbrd Installation Instructions
================================

Welcome to Clnbrd - Professional Clipboard Cleaning for macOS!

INSTALLATION:
1. Drag the "Clnbrd.app" icon to the "Applications" folder
2. Eject this disk image
3. Launch Clnbrd from your Applications folder

FIRST RUN:
- Clnbrd will appear in your menu bar
- Click the Clnbrd icon to access settings and features
- Grant accessibility permissions when prompted for full functionality

FEATURES:
- Automatic clipboard cleaning
- Customizable cleaning rules
- Hotkey support
- Menu bar integration
- Analytics and error reporting

SUPPORT:
If you encounter any issues, please contact support with:
- macOS version
- Error messages (if any)
- Steps to reproduce the issue

Thank you for using Clnbrd!
EOF

# Copy Release Notes to DMG
echo -e "${YELLOW}📝 Copying Release Notes...${NC}"
if [ -f "../../Distribution/RELEASE_NOTES.txt" ]; then
    cp "../../Distribution/RELEASE_NOTES.txt" "${TEMP_DIR}/Release Notes.txt"
    echo -e "${GREEN}✅ Release Notes included${NC}"
else
    echo -e "${YELLOW}⚠️  Release Notes not found - skipping${NC}"
fi

# Create DMG using srcfolder method
echo -e "${YELLOW}📦 Creating DMG installer...${NC}"
hdiutil create -srcfolder "${TEMP_DIR}" -volname "${VOLUME_NAME}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDZO -imagekey zlib-level=9 "${DMG_FINAL_NAME}.dmg"

# Clean up temporary directory
echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -rf "${TEMP_DIR}"

# Test the DMG
echo -e "${YELLOW}🧪 Testing DMG...${NC}"
hdiutil verify "${DMG_FINAL_NAME}.dmg"

# Get DMG size
DMG_SIZE=$(du -h "${DMG_FINAL_NAME}.dmg" | cut -f1)

# Generate version JSON file for auto-update system
echo -e "${YELLOW}📝 Generating version JSON for auto-update...${NC}"

# Get version and build number from Info.plist
VERSION_RAW=$(plutil -extract CFBundleShortVersionString raw "../../Clnbrd/Info.plist" 2>/dev/null || echo "1.3")
# Strip build number from version string (e.g., "1.3 (29)" -> "1.3")
VERSION=$(echo "$VERSION_RAW" | sed 's/ (.*//')
BUILD_NUMBER=$(plutil -extract CFBundleVersion raw "../../Clnbrd/Info.plist" 2>/dev/null || echo "29")
RELEASE_DATE=$(date +"%Y-%m-%d")

# Extract first few release notes items
RELEASE_NOTES=$(head -30 "../../Distribution/RELEASE_NOTES.txt" | grep "^•" | head -7 | sed 's/^• /• /' | tr '\n' '|' | sed 's/|/\\n/g' | sed 's/\\n$//')

# Create Upload directory
mkdir -p "../../Distribution/Upload"

# Generate JSON file (fixed filename for auto-update)
cat > "../../Distribution/Upload/clnbrd-version.json" << JSONEOF
{
  "version": "${VERSION}",
  "build": "${BUILD_NUMBER}",
  "dmg_filename": "Clnbrd-${VERSION}-Build-${BUILD_NUMBER}.dmg",
  "download_url": "https://naturalpod-downloads.s3.us-west-2.amazonaws.com/Clnbrd-${VERSION}-Build-${BUILD_NUMBER}.dmg",
  "release_notes": "${RELEASE_NOTES}",
  "release_date": "${RELEASE_DATE}",
  "minimum_os_version": "15.5"
}
JSONEOF

echo -e "${GREEN}✅ Version JSON created: Distribution/Upload/clnbrd-version.json${NC}"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    🎉 SUCCESS! 🎉                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}📦 DMG Created: ${DMG_FINAL_NAME}.dmg${NC}"
echo -e "${GREEN}📏 Size: ${DMG_SIZE}${NC}"
echo ""
echo -e "${BLUE}🚀 Your Clnbrd installer is ready!${NC}"
echo -e "${PURPLE}💡 Next steps:${NC}"
echo -e "${PURPLE}   1. Test the DMG: Double-click ${DMG_FINAL_NAME}.dmg${NC}"
echo -e "${PURPLE}   2. Verify the drag-to-Applications interface works${NC}"
echo -e "${PURPLE}   3. Check that the installation instructions are visible${NC}"
echo -e "${PURPLE}   4. Upload to S3:${NC}"
echo -e "${PURPLE}      • DMG: ${DMG_FINAL_NAME}.dmg${NC}"
echo -e "${PURPLE}      • JSON: Distribution/Upload/clnbrd-version.json (ALWAYS same name!)${NC}"
echo ""
