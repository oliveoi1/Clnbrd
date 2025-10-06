#!/bin/bash

# Clnbrd Ultra Simple DMG Creator Script
# Creates a basic DMG installer

set -e

# Configuration
APP_NAME="Clnbrd"
APP_VERSION="1.3"
DMG_NAME="Clnbrd-${APP_VERSION}"
DMG_FINAL_NAME="${DMG_NAME}.dmg"
VOLUME_NAME="Clnbrd Installer"
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
rm -f "${DMG_FINAL_NAME}.dmg"

# Create Applications folder alias
echo -e "${YELLOW}📁 Creating Applications folder alias...${NC}"
ln -sf /Applications Applications

# Create DMG using srcfolder method
echo -e "${YELLOW}📦 Creating DMG installer...${NC}"
hdiutil create -srcfolder "${APP_PATH}" -volname "${VOLUME_NAME}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDZO -imagekey zlib-level=9 "${DMG_FINAL_NAME}.dmg"

# Clean up Applications alias
rm -f Applications

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
echo -e "${PURPLE}   2. Verify the app can be copied to Applications${NC}"
echo -e "${PURPLE}   3. Upload to your distribution platform${NC}"
echo ""
