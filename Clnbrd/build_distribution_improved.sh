#!/bin/bash

# Clnbrd Professional Build & Distribution Script (Improved)
# Creates fully notarized, signed builds ready for distribution
# Fixed issues: double increment, extended attributes, export process

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

# Function to clean extended attributes aggressively
clean_extended_attributes() {
    local target_path="$1"
    local description="$2"
    
    echo -e "${BLUE}   Cleaning extended attributes for $description...${NC}"
    
    # Remove all extended attributes recursively
    xattr -cr "$target_path" 2>/dev/null || true
    
    # Remove AppleDouble files (._*)
    find "$target_path" -name "._*" -delete 2>/dev/null || true
    
    # Remove resource forks and metadata
    dot_clean -m "$target_path" 2>/dev/null || true
    
    # Additional cleanup for file provider issues (iCloud, Dropbox, etc.)
    find "$target_path" -type f -exec xattr -c {} \; 2>/dev/null || true
    
    # Remove specific problematic attributes
    find "$target_path" -type f -exec xattr -d com.apple.provenance {} \; 2>/dev/null || true
    find "$target_path" -type f -exec xattr -d com.apple.metadata:_kMDItemUserTags {} \; 2>/dev/null || true
    find "$target_path" -type f -exec xattr -d com.apple.quarantine {} \; 2>/dev/null || true
    find "$target_path" -type f -exec xattr -d com.apple.metadata:kMDItemWhereFroms {} \; 2>/dev/null || true
    
    # Force remove all extended attributes (more aggressive)
    find "$target_path" -type f -exec xattr -c {} \; 2>/dev/null || true
    find "$target_path" -type d -exec xattr -c {} \; 2>/dev/null || true
    
    # Verify cleanup
    local remaining_attrs=$(find "$target_path" -type f -exec xattr -l {} \; 2>/dev/null | wc -l)
    if [ "$remaining_attrs" -gt 0 ]; then
        echo -e "${YELLOW}   ⚠️  Warning: $remaining_attrs files still have extended attributes${NC}"
    else
        echo -e "${GREEN}   ✅ All extended attributes removed${NC}"
    fi
}

# Function to verify app structure
verify_app_structure() {
    local app_path="$1"
    
    echo -e "${BLUE}   Verifying app structure...${NC}"
    
    # Check for required frameworks
    if [ ! -d "$app_path/Contents/Frameworks/Sparkle.framework" ]; then
        echo -e "${RED}   ❌ Error: Sparkle framework missing!${NC}"
        return 1
    fi
    
    if [ ! -d "$app_path/Contents/Frameworks/Sentry.framework" ]; then
        echo -e "${RED}   ❌ Error: Sentry framework missing!${NC}"
        return 1
    fi
    
    # Check for main executable
    if [ ! -f "$app_path/Contents/MacOS/Clnbrd" ]; then
        echo -e "${RED}   ❌ Error: Main executable missing!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}   ✅ App structure verified${NC}"
    return 0
}

# Parse command line arguments
INCREMENT_BUILD=true
SKIP_NOTARIZATION=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-increment)
            INCREMENT_BUILD=false
            shift
            ;;
        --skip-notarization)
            SKIP_NOTARIZATION=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--no-increment] [--skip-notarization]"
            echo "  --no-increment: Skip automatic build number increment"
            echo "  --skip-notarization: Skip notarization instructions"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Increment build number only if requested
if [ "$INCREMENT_BUILD" = true ]; then
    echo -e "${YELLOW}🔢 Incrementing build number...${NC}"
    ./Scripts/Build/increment_build_number.sh "Automated build via build_distribution_improved.sh"
    echo ""
fi

# Get version from Info.plist
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

# Export the app from archive using xcodebuild (more reliable than cp)
echo -e "${YELLOW}📦 Exporting app from archive...${NC}"
xcodebuild -exportArchive \
    -archivePath "${BUILD_DIR}/Clnbrd.xcarchive" \
    -exportPath "${BUILD_DIR}/App" \
    -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" \
    > "${BUILD_DIR}/Logs/export.log" 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Export failed! Check ${BUILD_DIR}/Logs/export.log${NC}"
    tail -50 "${BUILD_DIR}/Logs/export.log"
    exit 1
fi

echo -e "${GREEN}✅ App exported successfully!${NC}"

# Verify app structure
if ! verify_app_structure "${BUILD_DIR}/App/Clnbrd.app"; then
    echo -e "${RED}❌ App structure verification failed!${NC}"
    exit 1
fi

# Clean extended attributes from exported app
clean_extended_attributes "${BUILD_DIR}/App/Clnbrd.app" "exported app"

# ===== SIGN SPARKLE FRAMEWORK COMPONENTS =====
echo -e "${YELLOW}🔏 Signing Sparkle framework components...${NC}"

# Move app to /tmp to avoid file provider issues
echo -e "${BLUE}   Moving app to /tmp to avoid file provider issues...${NC}"
rm -rf /tmp/Clnbrd-build${BUILD_NUMBER}.app
cp -R "${BUILD_DIR}/App/Clnbrd.app" "/tmp/Clnbrd-build${BUILD_NUMBER}.app"

# Clean extended attributes again in /tmp
clean_extended_attributes "/tmp/Clnbrd-build${BUILD_NUMBER}.app" "app in /tmp"

# Sign Sparkle components
cd "/tmp/Clnbrd-build${BUILD_NUMBER}.app/Contents/Frameworks/Sparkle.framework/Versions/Current"

codesign --force --sign "${DEVELOPER_ID}" --options runtime XPCServices/Downloader.xpc
codesign --force --sign "${DEVELOPER_ID}" --options runtime XPCServices/Installer.xpc
codesign --force --sign "${DEVELOPER_ID}" --options runtime Updater.app
codesign --force --sign "${DEVELOPER_ID}" --options runtime Autoupdate

cd /tmp
echo -e "${GREEN}✅ Sparkle components signed!${NC}"

# ===== SIGN FRAMEWORKS AND MAIN APP =====
echo -e "${YELLOW}🔏 Signing frameworks and main app...${NC}"

# Sign frameworks with hardened runtime
echo -e "${BLUE}   Signing frameworks with hardened runtime...${NC}"
codesign --force --sign "${DEVELOPER_ID}" --options runtime "/tmp/Clnbrd-build${BUILD_NUMBER}.app/Contents/Frameworks/Sparkle.framework"
codesign --force --sign "${DEVELOPER_ID}" --options runtime "/tmp/Clnbrd-build${BUILD_NUMBER}.app/Contents/Frameworks/Sentry.framework"

# Sign main app with hardened runtime
echo -e "${BLUE}   Signing main app with hardened runtime...${NC}"
codesign --force --sign "${DEVELOPER_ID}" --options runtime "/tmp/Clnbrd-build${BUILD_NUMBER}.app"

# Verify signing
echo -e "${BLUE}   Verifying app signature...${NC}"
if codesign --verify --verbose "/tmp/Clnbrd-build${BUILD_NUMBER}.app" 2>&1 | grep -q "valid on disk"; then
    echo -e "${GREEN}   ✅ App signature verified${NC}"
else
    echo -e "${RED}   ❌ App signature verification failed!${NC}"
    codesign --verify --verbose "/tmp/Clnbrd-build${BUILD_NUMBER}.app"
    exit 1
fi

# Move signed app back
echo -e "${BLUE}   Moving signed app back to build directory...${NC}"
mkdir -p "${BUILD_DIR}/App"
rm -rf "${BUILD_DIR}/App/Clnbrd.app"
mv "/tmp/Clnbrd-build${BUILD_NUMBER}.app" "${BUILD_DIR}/App/Clnbrd.app"

echo -e "${GREEN}✅ App fully signed with hardened runtime!${NC}"

# ===== CREATE ZIP FOR NOTARIZATION =====
echo -e "${YELLOW}📦 Creating ZIP for notarization...${NC}"

# Copy app back to /tmp to create clean ZIP
echo -e "${BLUE}   Copying app to /tmp for clean ZIP creation...${NC}"
rm -rf /tmp/Clnbrd-build${BUILD_NUMBER}.app
cp -R "${BUILD_DIR}/App/Clnbrd.app" "/tmp/Clnbrd-build${BUILD_NUMBER}.app"

# Final extended attributes cleanup before ZIP
clean_extended_attributes "/tmp/Clnbrd-build${BUILD_NUMBER}.app" "app before ZIP"

# Create ZIP with no extended attributes or resource forks
cd /tmp
echo -e "${BLUE}   Creating ZIP with --noextattr --norsrc flags...${NC}"
ditto -c -k --keepParent --noextattr --norsrc "Clnbrd-build${BUILD_NUMBER}.app" "${BUILD_DIR}/Upload/Clnbrd-Build${BUILD_NUMBER}.zip"

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
if [ "$SKIP_NOTARIZATION" = false ]; then
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    NOTARIZATION REQUIRED                     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}To notarize this build, run:${NC}"
    echo ""
    echo -e "${BLUE}xcrun notarytool submit Distribution/Upload/Clnbrd-Build${BUILD_NUMBER}.zip \\${NC}"
    echo -e "${BLUE}  --apple-id olivedesignstudios@gmail.com \\${NC}"
    echo -e "${BLUE}  --team-id ${TEAM_ID} \\${NC}"
    echo -e "${BLUE}  --password YOUR_APP_SPECIFIC_PASSWORD \\${NC}"
    echo -e "${BLUE}  --wait${NC}"
    echo ""
    echo -e "${YELLOW}After notarization is ACCEPTED, run this script to complete:${NC}"
    echo ""
    echo -e "${BLUE}./Scripts/Build/finalize_notarized_build.sh ${BUILD_NUMBER}${NC}"
    echo ""
fi

# Create distribution summary
cat > "${BUILD_DIR}/Distribution-Info.txt" <<EOF
Clnbrd Distribution Package (Improved)
=====================================

Version: ${VERSION} (Build ${BUILD_NUMBER})
Build Date: $(date)
Build Status: Ready for Notarization

Files Created:
- App/Clnbrd.app (Signed with Developer ID)
- Upload/Clnbrd-Build${BUILD_NUMBER}.zip (Ready for notarization)

Improvements Made:
- Fixed double build number increment
- Improved extended attributes handling
- Better app structure verification
- Enhanced error handling and validation
- More reliable export process

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
echo -e "${GREEN}║                    BUILD COMPLETED SUCCESSFULLY!             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📦 Build ${BUILD_NUMBER} is ready for notarization!${NC}"
echo -e "${CYAN}📁 Files created in: ${BUILD_DIR}/${NC}"
echo ""
echo -e "${YELLOW}Next: Submit for notarization and then run finalize script${NC}"
