#!/bin/bash

# Clnbrd Professional DMG Creator Script
# Creates a beautiful DMG installer with custom styling and drag-to-Applications interface

set -e

# Configuration
APP_NAME="Clnbrd"
APP_VERSION="1.3"
DMG_NAME="Clnbrd-${APP_VERSION}"
DMG_TEMP_NAME="${DMG_NAME}-temp"
DMG_FINAL_NAME="${DMG_NAME}.dmg"
VOLUME_NAME="Clnbrd"
APP_PATH="../build/Clnbrd.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DMG_DIR="${SCRIPT_DIR}/dmg_assets"

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

# Create DMG assets directory
mkdir -p "${DMG_DIR}"

# Clean up any existing DMG files
echo -e "${YELLOW}🧹 Cleaning up existing DMG files...${NC}"
rm -f "${DMG_FINAL_NAME}"
rm -f "${DMG_TEMP_NAME}.dmg"

# Create temporary DMG
echo -e "${YELLOW}📦 Creating temporary DMG (200MB)...${NC}"
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

# Create background directory
mkdir -p "${mountpoint}/.background"

# Create a beautiful background image using Python
echo -e "${YELLOW}🎨 Creating beautiful background image...${NC}"
cat > "${DMG_DIR}/create_background.py" << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os

def create_dmg_background():
    # DMG window dimensions
    width, height = 600, 400
    
    # Create image with gradient background
    img = Image.new('RGB', (width, height), color='#ffffff')
    draw = ImageDraw.Draw(img)
    
    # Create a subtle gradient from top to bottom
    for y in range(height):
        # Light blue to white gradient
        r = int(248 + (y / height) * 7)  # 248 to 255
        g = int(250 + (y / height) * 5)  # 250 to 255
        b = int(255)  # Keep blue constant
        color = (r, g, b)
        draw.line([(0, y), (width, y)], fill=color)
    
    # Add subtle border
    draw.rectangle([0, 0, width-1, height-1], outline='#d0d0d0', width=2)
    
    # Add some decorative elements
    # Top section with app name
    draw.rectangle([20, 20, width-20, 80], fill='#f8f9fa', outline='#e9ecef')
    
    # Try to add text (if font is available)
    try:
        # Try to use system font
        font_large = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
        font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
        
        # App title
        draw.text((40, 35), "Clnbrd", fill='#2c3e50', font=font_large)
        draw.text((40, 60), "Professional Clipboard Cleaning for macOS", fill='#7f8c8d', font=font_small)
        
    except:
        # Fallback: simple text without custom font
        draw.text((40, 35), "Clnbrd", fill='#2c3e50')
        draw.text((40, 60), "Professional Clipboard Cleaning for macOS", fill='#7f8c8d')
    
    # Add instruction text
    draw.text((40, height-60), "Drag Clnbrd to Applications to install", fill='#34495e')
    
    # Add some decorative dots
    for i in range(5):
        x = 100 + i * 80
        y = height - 30
        draw.ellipse([x, y, x+6, y+6], fill='#bdc3c7')
    
    return img

# Create and save the background
background = create_dmg_background()
background.save('${mountpoint}/.background/background.png', 'PNG')
print("Background image created successfully!")
PYEOF

python3 "${DMG_DIR}/create_background.py"

# Create AppleScript to set up the DMG window with enhanced styling
echo -e "${YELLOW}🎯 Configuring DMG layout and styling...${NC}"
cat > "${DMG_DIR}/setup_dmg.applescript" << 'EOF'
tell application "Finder"
    tell disk "Clnbrd"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set background picture of theViewOptions to file ".background:background.png"
        
        -- Position the app icon (left side)
        set position of item "Clnbrd.app" of container window to {150, 250}
        
        -- Position the Applications folder alias (right side)
        set position of item "Applications" of container window to {450, 250}
        
        -- Update the display
        update without registering applications
        delay 3
    end tell
end tell
EOF

# Run the AppleScript to set up the DMG
osascript "${DMG_DIR}/setup_dmg.applescript"

# Wait for changes to take effect
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
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    🎉 SUCCESS! 🎉                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}📁 DMG File: ${DMG_FINAL_NAME}${NC}"
    echo -e "${GREEN}📏 Size: ${DMG_SIZE}${NC}"
    echo -e "${GREEN}🏷️  Version: ${APP_VERSION}${NC}"
    echo ""
    
    # Optional: Mount and test the DMG
    echo -e "${BLUE}🧪 Testing DMG mount...${NC}"
    hdiutil attach "${DMG_FINAL_NAME}" -readonly
    sleep 2
    hdiutil detach "/Volumes/${VOLUME_NAME}"
    
    echo -e "${GREEN}✨ DMG installer is ready for distribution!${NC}"
    echo -e "${BLUE}💡 You can now distribute ${DMG_FINAL_NAME}${NC}"
    echo ""
    echo -e "${PURPLE}🚀 Next steps:${NC}"
    echo -e "${PURPLE}   1. Test the DMG by double-clicking it${NC}"
    echo -e "${PURPLE}   2. Verify the drag-to-Applications interface works${NC}"
    echo -e "${PURPLE}   3. Upload to your distribution platform${NC}"
    echo ""
else
    echo -e "${RED}❌ Error: DMG creation failed!${NC}"
    exit 1
fi
