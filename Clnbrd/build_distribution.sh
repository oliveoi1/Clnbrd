#!/bin/bash

# Clnbrd Professional Build & Distribution Script
# Creates organized build directory with DMG ready for distribution

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="Clnbrd"
SCHEME_NAME="Clnbrd"
CONFIGURATION="Release"
BUILD_DIR="./Distribution"
ARCHIVE_PATH="${BUILD_DIR}/Archive/Clnbrd.xcarchive"
APP_PATH="${BUILD_DIR}/App/Clnbrd.app"
DMG_PATH="${BUILD_DIR}/Clnbrd-${VERSION}.dmg"
TEMP_DIR="${BUILD_DIR}/Temp"

# Increment build number automatically
echo -e "${YELLOW}🔢 Incrementing build number...${NC}"
./Scripts/Build/increment_build_number.sh "Automated build via build_distribution.sh"
echo ""

# Get version from Info.plist (after increment)
VERSION=$(plutil -extract CFBundleShortVersionString raw Clnbrd/Info.plist)
BUILD_NUMBER=$(plutil -extract CFBundleVersion raw Clnbrd/Info.plist)

# Update README with new version
echo -e "${YELLOW}📝 Updating README.md...${NC}"
./Scripts/Build/update_readme_version.sh
echo ""

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║              Clnbrd Professional Build System              ║${NC}"
echo -e "${PURPLE}║                Organized Distribution Creator               ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📦 Building Clnbrd v${VERSION} (Build ${BUILD_NUMBER})${NC}"
echo -e "${CYAN}📁 Output Directory: ${BUILD_DIR}${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}❌ Error: ${PROJECT_NAME}.xcodeproj not found!${NC}"
    echo "Please run this script from the project root directory."
    exit 1
fi

# Clean and create organized directory structure
echo -e "${YELLOW}🧹 Setting up organized build directory...${NC}"

# Archive old DMG if it exists
if [ -d "${BUILD_DIR}/DMG" ] && [ "$(ls -A ${BUILD_DIR}/DMG/*.dmg 2>/dev/null)" ]; then
    echo -e "${BLUE}📦 Archiving previous DMG files...${NC}"
    mkdir -p "${BUILD_DIR}/Archive/Previous_Builds"
    
    # Move existing DMGs to archive with timestamp
    for dmg in "${BUILD_DIR}"/DMG/*.dmg; do
        if [ -f "$dmg" ]; then
            filename=$(basename "$dmg")
            timestamp=$(date +"%Y%m%d_%H%M%S")
            mv "$dmg" "${BUILD_DIR}/Archive/Previous_Builds/${filename%.dmg}_archived_${timestamp}.dmg"
            echo -e "${GREEN}   ✅ Archived: $(basename "$dmg")${NC}"
        fi
    done
fi

rm -rf "${BUILD_DIR}/Export"
rm -rf "${BUILD_DIR}/Temp"
rm -rf "${BUILD_DIR}/Logs"
mkdir -p "${BUILD_DIR}"/{Archive,App,DMG,Temp,Logs,Archive/Previous_Builds}

# Create export options plist file
echo -e "${YELLOW}📝 Creating export options...${NC}"
cat > "${BUILD_DIR}/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string></string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>Q7A38DCZ98</string>
</dict>
</plist>
EOF

# Build and archive
echo -e "${YELLOW}🔨 Building and archiving...${NC}"
xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME_NAME}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    DEVELOPMENT_TEAM="" \
    > "${BUILD_DIR}/Logs/archive.log" 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Archive failed! Check ${BUILD_DIR}/Logs/archive.log${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Archive created successfully!${NC}"

# Export the app
echo -e "${YELLOW}📦 Exporting app...${NC}"
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${BUILD_DIR}/Export" \
    -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" \
    > "${BUILD_DIR}/Logs/export.log" 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Export failed! Check ${BUILD_DIR}/Logs/export.log${NC}"
    exit 1
fi

echo -e "${GREEN}✅ App exported successfully!${NC}"

# Copy app to organized location
echo -e "${YELLOW}📱 Organizing app files...${NC}"
cp -R "${BUILD_DIR}/Export/Clnbrd.app" "${APP_PATH}"

# Clean app bundle
echo -e "${YELLOW}🧹 Cleaning app bundle...${NC}"
find "${APP_PATH}" -name "._*" -delete 2>/dev/null || true
xattr -cr "${APP_PATH}" 2>/dev/null || true

# Create DMG using the working DMG script
echo -e "${YELLOW}💿 Creating professional DMG installer...${NC}"

# Update the DMG script to use the correct app path
DMG_SCRIPT="./Scripts/DMG/create_dmg_working.sh"
if [ -f "${DMG_SCRIPT}" ]; then
    # Temporarily update the script to use the correct path
    sed -i.bak "s|APP_PATH=.*|APP_PATH=\"../../${APP_PATH}\"|" "${DMG_SCRIPT}"
    
    # Run the DMG creation script
    cd Scripts/DMG
    ./create_dmg_working.sh
    
    # Move the DMG to the correct location with build number in filename
    DMG_FILENAME="Clnbrd-${VERSION}-Build-${BUILD_NUMBER}.dmg"
    
    # Look for the generated DMG (it might have different naming)
    GENERATED_DMG=$(ls -t Clnbrd-*.dmg 2>/dev/null | head -1)
    
    if [ -n "$GENERATED_DMG" ] && [ -f "$GENERATED_DMG" ]; then
        mv "$GENERATED_DMG" "../../${BUILD_DIR}/DMG/${DMG_FILENAME}"
        echo -e "${GREEN}✅ DMG created: ${DMG_FILENAME}${NC}"
    else
        echo -e "${RED}❌ DMG file not found${NC}"
        echo -e "${YELLOW}Looking for: Clnbrd-*.dmg${NC}"
        ls -la
        exit 1
    fi
    
    # Restore the original script
    mv create_dmg_working.sh.bak create_dmg_working.sh 2>/dev/null || true
    
    cd ../..
else
    echo -e "${RED}❌ DMG script not found: ${DMG_SCRIPT}${NC}"
    exit 1
fi

# Clean up temporary files
echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -rf "${TEMP_DIR}"
rm -rf "${BUILD_DIR}/Export"
# Don't delete the Archive directory - it contains Previous_Builds!
# Only delete the Clnbrd.xcarchive file
rm -rf "${BUILD_DIR}/Archive/Clnbrd.xcarchive"
rm -f "${BUILD_DIR}/ExportOptions.plist"

# Create distribution summary
DMG_FILENAME="Clnbrd-${VERSION}-Build-${BUILD_NUMBER}.dmg"
cat > "${BUILD_DIR}/Distribution-Info.txt" <<EOF
Clnbrd Distribution Package
==========================

Version: ${VERSION} (Build ${BUILD_NUMBER})
Build Date: $(date)
DMG File: ${DMG_FILENAME}
DMG Size: $(du -h "${BUILD_DIR}/DMG/${DMG_FILENAME}" | cut -f1)

Contents:
- Clnbrd.app (Ready to install)
- Applications folder shortcut
- Installation instructions
- Professional drag-and-drop interface

Distribution Ready:
✅ DMG created and verified
✅ Temporary files cleaned up
✅ Organized directory structure
✅ Ready for sharing

Next Steps:
1. Test the DMG: Double-click ${DMG_FILENAME}
2. Verify installation works
3. Share the DMG file
4. Upload to distribution platform

Build Logs: Logs/ directory contains detailed build information
EOF

# Final verification
echo -e "${YELLOW}🧪 Verifying DMG...${NC}"
hdiutil verify "${BUILD_DIR}/DMG/${DMG_FILENAME}" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ DMG verification passed!${NC}"
else
    echo -e "${RED}❌ DMG verification failed!${NC}"
    exit 1
fi

# Display final results
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    🎉 BUILD COMPLETE! 🎉                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📁 Distribution Directory: ${BUILD_DIR}${NC}"
echo -e "${CYAN}📦 DMG File: ${BUILD_DIR}/DMG/${DMG_FILENAME}${NC}"
echo -e "${CYAN}📏 DMG Size: $(du -h "${BUILD_DIR}/DMG/${DMG_FILENAME}" | cut -f1)${NC}"
echo ""
echo -e "${PURPLE}📋 Directory Structure:${NC}"
echo -e "${PURPLE}${BUILD_DIR}/${NC}"
echo -e "${PURPLE}├── DMG/${NC}"
echo -e "${PURPLE}│   └── ${DMG_FILENAME}  ← Ready to share!${NC}"
echo -e "${PURPLE}├── App/${NC}"
echo -e "${PURPLE}│   └── Clnbrd.app${NC}"
echo -e "${PURPLE}├── Logs/${NC}"
echo -e "${PURPLE}│   ├── archive.log${NC}"
echo -e "${PURPLE}│   └── export.log${NC}"
echo -e "${PURPLE}├── Archive/${NC}"
echo -e "${PURPLE}│   └── Previous_Builds/  ← Archived DMGs${NC}"
echo -e "${PURPLE}└── Distribution-Info.txt${NC}"
echo ""
echo -e "${GREEN}🚀 Your Clnbrd installer is ready for distribution!${NC}"
echo -e "${YELLOW}💡 Simply share the DMG file: ${BUILD_DIR}/DMG/${DMG_FILENAME}${NC}"
echo ""
echo -e "${BLUE}📧 Support: olivedesignstudios@gmail.com${NC}"
echo -e "${BLUE}🌐 Version: ${VERSION} (Build ${BUILD_NUMBER})${NC}"