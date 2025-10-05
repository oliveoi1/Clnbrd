#!/bin/bash

# Clnbrd Final DMG Creator Script
# Creates a clean DMG installer with drag-to-Applications interface

set -e

# Configuration
APP_NAME="Clnbrd"
APP_VERSION="1.3"
DMG_NAME="Clnbrd-${APP_VERSION}"
DMG_TEMP_NAME="${DMG_NAME}-temp"
DMG_FINAL_NAME="${DMG_NAME}.dmg"
VOLUME_NAME="Clnbrd"
APP_PATH="../build/Clnbrd.app"

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
rm -f "${DMG_TEMP_NAME}.dmg" "${DMG_FINAL_NAME}.dmg"

# Create temporary DMG
echo -e "${YELLOW}📦 Creating temporary DMG (200MB)...${NC}"
hdiutil create -volname "${VOLUME_NAME}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -size 200m "${DMG_TEMP_NAME}.dmg"

# Mount the DMG
echo -e "${YELLOW}🔗 Mounting DMG...${NC}"
device=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP_NAME}.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 2

# Get mount point
mountpoint="/Volumes/${VOLUME_NAME}"

# Copy app to DMG
echo -e "${YELLOW}📱 Copying app to DMG...${NC}"
cp -R "${APP_PATH}" "${mountpoint}/"

# Create Applications folder alias
echo -e "${YELLOW}📁 Creating Applications folder alias...${NC}"
ln -s /Applications "${mountpoint}/Applications"

# Set window properties
echo -e "${YELLOW}🎨 Setting window properties...${NC}"
osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set position of item "${APP_NAME}.app" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Unmount the DMG
echo -e "${YELLOW}🔓 Unmounting DMG...${NC}"
hdiutil detach "${device}"

# Convert to final compressed DMG
echo -e "${YELLOW}🗜️  Creating final compressed DMG...${NC}"
hdiutil convert "${DMG_TEMP_NAME}.dmg" -format UDZO -imagekey zlib-level=9 -o "${DMG_FINAL_NAME}.dmg"

# Clean up temporary DMG
echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -f "${DMG_TEMP_NAME}.dmg"

# Test the DMG
echo -e "${YELLOW}🧪 Testing DMG...${NC}"
hdiutil verify "${DMG_FINAL_NAME}.dmg"

# Get DMG size
DMG_SIZE=$(du -h "${DMG_FINAL_NAME}.dmg" | cut -f1)

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
echo -e "${PURPLE}   3. Upload to your distribution platform${NC}"
echo ""
