#!/bin/bash

# Clnbrd DMG Creator Script
# Creates a professional DMG installer with drag-to-Applications interface

set -e

# Configuration
APP_NAME="Clnbrd"
APP_VERSION="1.3"
DMG_NAME="Clnbrd-${APP_VERSION}"
DMG_TEMP_NAME="${DMG_NAME}-temp"
DMG_FINAL_NAME="${DMG_NAME}.dmg"
VOLUME_NAME="Clnbrd"
APP_PATH="../Clnbrd.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DMG_DIR="${SCRIPT_DIR}/dmg_assets"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Creating DMG installer for ${APP_NAME} v${APP_VERSION}${NC}"

# Check if app exists
if [ ! -d "${APP_PATH}" ]; then
    echo -e "${RED}❌ Error: ${APP_PATH} not found!${NC}"
    echo "Please build the app first or check the path."
    exit 1
fi

# Create DMG assets directory
mkdir -p "${DMG_DIR}"

# Clean up any existing DMG files
echo -e "${YELLOW}🧹 Cleaning up existing DMG files...${NC}"
rm -f "${DMG_FINAL_NAME}"
rm -f "${DMG_TEMP_NAME}.dmg"

# Create temporary DMG
echo -e "${YELLOW}📦 Creating temporary DMG...${NC}"
hdiutil create -srcfolder "${APP_PATH}" -volname "${VOLUME_NAME}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 200m "${DMG_TEMP_NAME}.dmg"

# Mount the DMG
echo -e "${YELLOW}🔗 Mounting DMG...${NC}"
device=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP_NAME}.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 2

# Get mount point
mountpoint="/Volumes/${VOLUME_NAME}"

# Create Applications folder alias
echo -e "${YELLOW}📁 Creating Applications folder alias...${NC}"
ln -s /Applications "${mountpoint}/Applications"

# Set DMG window properties
echo -e "${YELLOW}🎨 Setting up DMG window properties...${NC}"

# Create AppleScript to set up the DMG window
cat > "${DMG_DIR}/setup_dmg.applescript" << 'EOF'
tell application "Finder"
    tell disk "Clnbrd"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 400}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set background picture of theViewOptions to file ".background:background.png"
        
        -- Position the app icon
        set position of item "Clnbrd.app" of container window to {150, 200}
        
        -- Position the Applications folder alias
        set position of item "Applications" of container window to {350, 200}
        
        -- Update the display
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Create background image (simple gradient)
echo -e "${YELLOW}🎨 Creating background image...${NC}"
mkdir -p "${mountpoint}/.background"

# Create a simple background using ImageMagick if available, otherwise use a solid color
if command -v convert &> /dev/null; then
    convert -size 500x300 gradient:'#f0f0f0-#e0e0e0' "${mountpoint}/.background/background.png"
else
    # Fallback: create a simple colored background
    python3 -c "
from PIL import Image, ImageDraw
import os

# Create a simple gradient background
width, height = 500, 300
img = Image.new('RGB', (width, height), color='#f0f0f0')
draw = ImageDraw.Draw(img)

# Draw a subtle gradient
for y in range(height):
    color_value = int(240 - (y / height) * 20)
    color = (color_value, color_value, color_value)
    draw.line([(0, y), (width, y)], fill=color)

img.save('${mountpoint}/.background/background.png')
" 2>/dev/null || {
    # Ultimate fallback: create a solid color background
    echo "Creating solid background..."
    # We'll use a simple approach - create a basic PNG
    cat > "${DMG_DIR}/create_bg.py" << 'PYEOF'
import struct
import os

# Create a simple 1x1 PNG with solid color
def create_simple_png(filename, width=500, height=300, color=(240, 240, 240)):
    # PNG header
    png_data = b'\x89PNG\r\n\x1a\n'
    
    # IHDR chunk
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    ihdr_crc = 0x4d4d4d4d  # Placeholder CRC
    png_data += struct.pack('>I', 13) + b'IHDR' + ihdr + struct.pack('>I', ihdr_crc)
    
    # IDAT chunk (minimal)
    idat = b'\x78\x9c\x63\x00\x00\x00\x02\x00\x01'
    idat_crc = 0x4d4d4d4d  # Placeholder CRC
    png_data += struct.pack('>I', len(idat)) + b'IDAT' + idat + struct.pack('>I', idat_crc)
    
    # IEND chunk
    png_data += struct.pack('>I', 0) + b'IEND' + struct.pack('>I', 0xae426082)
    
    with open(filename, 'wb') as f:
        f.write(png_data)

create_simple_png('${mountpoint}/.background/background.png')
PYEOF
    python3 "${DMG_DIR}/create_bg.py"
}

# Run the AppleScript to set up the DMG
echo -e "${YELLOW}🎯 Configuring DMG layout...${NC}"
osascript "${DMG_DIR}/setup_dmg.applescript"

# Wait a moment for the changes to take effect
sleep 3

# Unmount the DMG
echo -e "${YELLOW}🔓 Unmounting DMG...${NC}"
hdiutil detach "${device}"

# Convert to final compressed DMG
echo -e "${YELLOW}🗜️  Creating final compressed DMG...${NC}"
hdiutil convert "${DMG_TEMP_NAME}.dmg" -format UDZO -imagekey zlib-level=9 -o "${DMG_FINAL_NAME}"

# Clean up
echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -f "${DMG_TEMP_NAME}.dmg"
rm -rf "${DMG_DIR}"

# Verify the DMG
echo -e "${YELLOW}✅ Verifying DMG...${NC}"
if [ -f "${DMG_FINAL_NAME}" ]; then
    DMG_SIZE=$(du -h "${DMG_FINAL_NAME}" | cut -f1)
    echo -e "${GREEN}🎉 DMG created successfully!${NC}"
    echo -e "${GREEN}📁 File: ${DMG_FINAL_NAME}${NC}"
    echo -e "${GREEN}📏 Size: ${DMG_SIZE}${NC}"
    
    # Optional: Mount and test the DMG
    echo -e "${BLUE}🧪 Testing DMG...${NC}"
    hdiutil attach "${DMG_FINAL_NAME}" -readonly
    sleep 2
    hdiutil detach "/Volumes/${VOLUME_NAME}"
    
    echo -e "${GREEN}✨ DMG installer is ready for distribution!${NC}"
    echo -e "${BLUE}💡 You can now distribute ${DMG_FINAL_NAME}${NC}"
else
    echo -e "${RED}❌ Error: DMG creation failed!${NC}"
    exit 1
fi
