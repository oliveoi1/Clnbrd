#!/bin/bash

# Clnbrd Professional Build & Distribution Script
# Creates fully notarized, signed builds ready for distribution

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
DEVELOPER_ID="Developer ID Application: Allan Alomes (58Y8VPZ7JG)"
TEAM_ID="58Y8VPZ7JG"

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
echo -e "${PURPLE}║       Clnbrd Professional Build & Notarization System      ║${NC}"
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
echo -e "${YELLOW}🧹 Setting up build environment...${NC}"

# Archive old DMG if it exists
if [ -d "${BUILD_DIR}/DMG" ] && [ "$(ls -A ${BUILD_DIR}/DMG/*.dmg 2>/dev/null)" ]; then
    echo -e "${BLUE}📦 Archiving previous DMG files...${NC}"
    mkdir -p "${BUILD_DIR}/Archive/Previous_Builds"
    
    for dmg in "${BUILD_DIR}"/DMG/*.dmg; do
        if [ -f "$dmg" ]; then
            filename=$(basename "$dmg")
            timestamp=$(date +"%Y%m%d_%H%M%S")
            mv "$dmg" "${BUILD_DIR}/Archive/Previous_Builds/${filename%.dmg}_archived_${timestamp}.dmg"
            echo -e "${GREEN}   ✅ Archived: $(basename "$dmg")${NC}"
        fi
    done
fi

rm -rf "${BUILD_DIR}/Export" "${BUILD_DIR}/Temp" "${BUILD_DIR}/Logs" "${BUILD_DIR}/App" "${BUILD_DIR}/Notarized"
mkdir -p "${BUILD_DIR}"/{Archive,App,DMG,Logs,Upload,Notarized,Archive/Previous_Builds}

# Build with Xcode (archive with code signing)
echo -e "${YELLOW}🔨 Building and archiving with code signing...${NC}"
xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME_NAME}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${BUILD_DIR}/Clnbrd.xcarchive" \
    CODE_SIGN_IDENTITY="${DEVELOPER_ID}" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    > "${BUILD_DIR}/Logs/archive.log" 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Archive failed! Check ${BUILD_DIR}/Logs/archive.log${NC}"
    tail -50 "${BUILD_DIR}/Logs/archive.log"
    exit 1
fi

echo -e "${GREEN}✅ Archive created successfully!${NC}"

# Export the app from archive
echo -e "${YELLOW}📦 Exporting app from archive...${NC}"
cp -R "${BUILD_DIR}/Clnbrd.xcarchive/Products/Applications/Clnbrd.app" "${BUILD_DIR}/App/"

# ===== CRITICAL: CLEAN EXTENDED ATTRIBUTES =====
echo -e "${YELLOW}🧹 Cleaning extended attributes (prevents notarization failures)...${NC}"
cd "${BUILD_DIR}/App"

# Remove all extended attributes recursively
xattr -cr Clnbrd.app

# Remove AppleDouble files (._*)
find Clnbrd.app -name "._*" -delete 2>/dev/null || true

# Remove resource forks and metadata
dot_clean -m Clnbrd.app 2>/dev/null || true

# Additional cleanup for file provider issues (iCloud, Dropbox, etc.)
find Clnbrd.app -type f -exec xattr -c {} \; 2>/dev/null || true

# Verify cleanup
echo -e "${BLUE}   Verifying extended attributes cleanup...${NC}"
if find Clnbrd.app -name "._*" | grep -q .; then
    echo -e "${RED}   ⚠️  Warning: Some AppleDouble files remain${NC}"
else
    echo -e "${GREEN}   ✅ All AppleDouble files removed${NC}"
fi

cd ../..
echo -e "${GREEN}✅ Extended attributes cleaned!${NC}"

# ===== SIGN SPARKLE FRAMEWORK COMPONENTS =====
echo -e "${YELLOW}🔏 Signing Sparkle framework components...${NC}"
cd "${BUILD_DIR}/App/Clnbrd.app/Contents/Frameworks/Sparkle.framework/Versions/Current"

# Sign nested executables first (deepest to shallowest)
codesign --force --sign "${DEVELOPER_ID}" --options runtime --timestamp XPCServices/Downloader.xpc
codesign --force --sign "${DEVELOPER_ID}" --options runtime --timestamp XPCServices/Installer.xpc
codesign --force --sign "${DEVELOPER_ID}" --options runtime --timestamp Updater.app
codesign --force --sign "${DEVELOPER_ID}" --options runtime --timestamp Autoupdate

cd ../../../../..
echo -e "${GREEN}✅ Sparkle components signed!${NC}"

# ===== SIGN FRAMEWORKS AND MAIN APP =====
echo -e "${YELLOW}🔏 Signing frameworks and main app...${NC}"

# Move app to /tmp to avoid file provider issues (iCloud, Dropbox, etc.)
echo -e "${BLUE}   Moving app to /tmp to avoid file provider issues...${NC}"
rm -rf /tmp/Clnbrd.app
cp -R "${BUILD_DIR}/App/Clnbrd.app" /tmp/

# Clean extended attributes again (file providers may re-add them)
echo -e "${BLUE}   Cleaning extended attributes in /tmp...${NC}"
xattr -cr /tmp/Clnbrd.app
find /tmp/Clnbrd.app -name "._*" -delete 2>/dev/null || true
find /tmp/Clnbrd.app -type f -exec xattr -c {} \; 2>/dev/null || true

# Sign frameworks with hardened runtime
echo -e "${BLUE}   Signing frameworks with hardened runtime...${NC}"
codesign --force --sign "${DEVELOPER_ID}" --options runtime --timestamp "/tmp/Clnbrd.app/Contents/Frameworks/Sparkle.framework"
codesign --force --sign "${DEVELOPER_ID}" --options runtime --timestamp "/tmp/Clnbrd.app/Contents/Frameworks/Sentry.framework"

# Sign main app with hardened runtime
echo -e "${BLUE}   Signing main app with hardened runtime...${NC}"
codesign --force --sign "${DEVELOPER_ID}" --options runtime --timestamp "/tmp/Clnbrd.app"

# Verify signing
echo -e "${BLUE}   Verifying app signature...${NC}"
codesign -dv /tmp/Clnbrd.app

# Move signed app back
echo -e "${BLUE}   Moving signed app back to build directory...${NC}"
rm -rf "${BUILD_DIR}/App/Clnbrd.app"
mv /tmp/Clnbrd.app "${BUILD_DIR}/App/"

echo -e "${GREEN}✅ App fully signed with hardened runtime!${NC}"

# ===== CREATE ZIP FOR NOTARIZATION =====
echo -e "${YELLOW}📦 Creating ZIP for notarization...${NC}"

# Copy app back to /tmp to create clean ZIP (avoid file provider issues)
echo -e "${BLUE}   Copying app to /tmp for clean ZIP creation...${NC}"
rm -rf /tmp/Clnbrd.app
cp -R "${BUILD_DIR}/App/Clnbrd.app" /tmp/

# Final extended attributes cleanup before ZIP
echo -e "${BLUE}   Final extended attributes cleanup...${NC}"
xattr -cr /tmp/Clnbrd.app
find /tmp/Clnbrd.app -name "._*" -delete 2>/dev/null || true
find /tmp/Clnbrd.app -type f -exec xattr -c {} \; 2>/dev/null || true

# Create ZIP with no extended attributes or resource forks
cd /tmp
echo -e "${BLUE}   Creating ZIP with --noextattr --norsrc flags...${NC}"
ditto -c -k --keepParent --noextattr --norsrc "Clnbrd.app" "${BUILD_DIR}/Upload/Clnbrd-Build${BUILD_NUMBER}.zip"
cd "${BUILD_DIR}/.."
cd ..

# Verify ZIP doesn't contain extended attributes
echo -e "${BLUE}   Verifying ZIP is clean...${NC}"
if zipinfo "${BUILD_DIR}/Upload/Clnbrd-Build${BUILD_NUMBER}.zip" | grep -q "._"; then
    echo -e "${RED}   ⚠️  Warning: ZIP may contain AppleDouble files${NC}"
else
    echo -e "${GREEN}   ✅ ZIP is clean (no AppleDouble files)${NC}"
fi

ZIP_SIZE=$(du -h "${BUILD_DIR}/Upload/Clnbrd-Build${BUILD_NUMBER}.zip" | cut -f1)
echo -e "${GREEN}✅ ZIP created: ${ZIP_SIZE}${NC}"

# ===== NOTARIZATION INSTRUCTIONS =====
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    NOTARIZATION REQUIRED                     ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}To notarize this build, run:${NC}"
echo ""
echo -e "${BLUE}xcrun notarytool submit Distribution/Upload/Clnbrd-Build${BUILD_NUMBER}.zip \\${NC}"
echo -e "${BLUE}  --apple-id YOUR_APPLE_ID \\${NC}"
echo -e "${BLUE}  --team-id ${TEAM_ID} \\${NC}"
echo -e "${BLUE}  --password YOUR_APP_SPECIFIC_PASSWORD \\${NC}"
echo -e "${BLUE}  --wait${NC}"
echo ""
echo -e "${YELLOW}After notarization is ACCEPTED, run this script to complete:${NC}"
echo ""
echo -e "${BLUE}./Scripts/Build/finalize_notarized_build.sh ${BUILD_NUMBER}${NC}"
echo ""

# Create distribution summary
cat > "${BUILD_DIR}/Distribution-Info.txt" <<EOF
Clnbrd Distribution Package
==========================

Version: ${VERSION} (Build ${BUILD_NUMBER})
Build Date: $(date)
Build Status: Ready for Notarization

Files Created:
- App/Clnbrd.app (Signed with Developer ID)
- Upload/Clnbrd-Build${BUILD_NUMBER}.zip (Ready for notarization)

Next Steps:
1. Submit ZIP for notarization using the command shown above
2. Wait for notarization approval
3. Run finalize_notarized_build.sh to:
   - Staple notarization ticket
   - Create DMG installer
   - Generate version JSON
   - Prepare GitHub release

Build Logs: Logs/ directory
EOF

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  ✅ BUILD COMPLETE!                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📦 Build: ${VERSION} (Build ${BUILD_NUMBER})${NC}"
echo -e "${CYAN}📁 ZIP for notarization: ${BUILD_DIR}/Upload/Clnbrd-Build${BUILD_NUMBER}.zip${NC}"
echo -e "${CYAN}📏 Size: ${ZIP_SIZE}${NC}"
echo ""
