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
=================================

Welcome to Clnbrd - Professional Clipboard Cleaning for macOS!

📦 INSTALLATION STEPS:

1. Drag "Clnbrd.app" to the "Applications" folder
2. Eject this disk image
3. Launch Clnbrd from your Applications folder

⚠️ SECURITY NOTICE (If app won't open):

If macOS blocks the app with "cannot be opened because it is from an 
unidentified developer":

METHOD 1 - Right-Click to Open:
   a) Right-click (or Control-click) on Clnbrd.app in Applications
   b) Select "Open" from the menu
   c) Click "Open" in the security dialog
   d) This only needs to be done once!

METHOD 2 - System Settings:
   a) Go to System Settings → Privacy & Security
   b) Scroll down to find "Clnbrd was blocked from use..."
   c) Click "Open Anyway"
   d) Confirm by clicking "Open" again

⚙️ REQUIRED PERMISSIONS:

After launching Clnbrd, you'll need to grant two permissions:

1. ACCESSIBILITY PERMISSION:
   • Click "Open System Settings" when prompted
   • Or manually: System Settings → Privacy & Security → Accessibility
   • Toggle ON the switch next to "Clnbrd"
   • Required for: Monitoring the ⌘⌥V hotkey

2. INPUT MONITORING PERMISSION:
   • Click "Open System Settings" when prompted
   • Or manually: System Settings → Privacy & Security → Input Monitoring
   • Toggle ON the switch next to "Clnbrd"
   • Required for: Pasting cleaned text automatically

⚡ QUICK START:

1. After granting permissions, Clnbrd appears in your menu bar
2. Copy some formatted text from anywhere
3. Press ⌘⌥V (Command + Option + V) to paste cleaned text
4. Click the menu bar icon for settings and features

📋 FEATURES:

• ⌘⌥V Hotkey - Paste cleaned text instantly
• Auto-clean on Copy - Automatic formatting removal
• Customizable Rules - Choose what to remove
• Menu Bar Access - Always available
• Launch at Login - Optional automatic startup

🆘 TROUBLESHOOTING:

Problem: Hotkey (⌘⌥V) doesn't work
Solution: Ensure both Accessibility AND Input Monitoring are enabled

Problem: App won't open
Solution: Use Method 1 (right-click → Open) above

Problem: Permissions keep resetting
Solution: Restart Clnbrd after enabling permissions

📧 SUPPORT:

Website: https://github.com/oliveoi1/Clnbrd
Email: olivedesignstudios@gmail.com

Please include when reporting issues:
• macOS version
• Error messages (if any)
• Steps to reproduce

Thank you for using Clnbrd! 🎉
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
