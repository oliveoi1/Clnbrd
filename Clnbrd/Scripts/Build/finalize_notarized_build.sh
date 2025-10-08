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

# Generate EdDSA signature for Sparkle
echo -e "${YELLOW}🔐 Generating EdDSA signature for Sparkle updates...${NC}"
SPARKLE_SIGN_TOOL=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -type f 2>/dev/null | grep "Sparkle/bin/sign_update" | head -1)
SPARKLE_PRIVATE_KEY="../../.sparkle_keys/sparkle_eddsa_private.key"

if [ -f "${SPARKLE_PRIVATE_KEY}" ] && [ -n "${SPARKLE_SIGN_TOOL}" ]; then
    EDDSA_SIGNATURE=$("${SPARKLE_SIGN_TOOL}" "${BUILD_DIR}/DMG/Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg" -f "${SPARKLE_PRIVATE_KEY}" | grep 'sparkle:edSignature=' | cut -d '"' -f 2)
    echo -e "${GREEN}✅ EdDSA signature generated!${NC}"
    echo -e "${BLUE}   Signature: ${EDDSA_SIGNATURE}${NC}"
else
    echo -e "${RED}⚠️  Warning: EdDSA signature not generated${NC}"
    if [ ! -f "${SPARKLE_PRIVATE_KEY}" ]; then
        echo -e "${YELLOW}   Private key not found at: ${SPARKLE_PRIVATE_KEY}${NC}"
    fi
    if [ -z "${SPARKLE_SIGN_TOOL}" ]; then
        echo -e "${YELLOW}   Sparkle sign_update tool not found${NC}"
    fi
    EDDSA_SIGNATURE=""
fi

# Update appcast.xml
echo -e "${YELLOW}📡 Updating appcast.xml...${NC}"
APPCAST_FILE="../appcast.xml"
DMG_FILE_SIZE=$(stat -f%z "${BUILD_DIR}/DMG/Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg")
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")

# Create new item entry
NEW_ITEM=$(cat <<APPCAST_ITEM
        <item>
            <title>Version ${VERSION} (Build ${BUILD_NUMBER}) - ✅ Fully Notarized by Apple</title>
            <link>https://github.com/oliveoi1/Clnbrd/releases/tag/v${VERSION}-build${BUILD_NUMBER}</link>
            <sparkle:version>${BUILD_NUMBER}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>🎉 Build ${BUILD_NUMBER} - Fully Notarized by Apple!</h2>
                <ul>
                    <li>✅ <strong>Fully Notarized by Apple</strong> - No security warnings!</li>
                    <li>🔐 Code Signed with Developer ID - Verified and secure</li>
                    <li>🎯 ⌘⌥V Hotkey - Paste cleaned text instantly</li>
                    <li>🤖 Auto-clean on Copy - Automatically strip formatting</li>
                    <li>📋 Menu Bar Integration - Quick access from your Mac</li>
                    <li>🧹 Format Removal - Strips all formatting, styles, and metadata</li>
                    <li>🚀 Performance Monitoring - Built-in memory and CPU optimization</li>
                    <li>🔄 Error Recovery - Automatic recovery from clipboard issues</li>
                    <li>📊 Privacy-focused Analytics - Track usage patterns</li>
                    <li>⚡ Auto-updates - Seamless future updates</li>
                </ul>
                <p><strong>This is a fully notarized release approved by Apple's security team!</strong></p>
            ]]></description>
            <pubDate>${PUB_DATE}</pubDate>
            <enclosure 
                url="https://github.com/oliveoi1/Clnbrd/releases/download/v${VERSION}-build${BUILD_NUMBER}/Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg" 
                sparkle:version="${BUILD_NUMBER}" 
                sparkle:shortVersionString="${VERSION}" 
                length="${DMG_FILE_SIZE}"
                type="application/octet-stream"${EDDSA_SIGNATURE:+
                sparkle:edSignature=\"${EDDSA_SIGNATURE}\"}
            />
        </item>
        
APPCAST_ITEM
)

# Insert new item after the opening <channel> tag
if [ -f "${APPCAST_FILE}" ]; then
    # Create backup
    cp "${APPCAST_FILE}" "${APPCAST_FILE}.bak"
    
    # Use awk to insert the new item after <language>en</language>
    awk -v new_item="$NEW_ITEM" '
    /<language>en<\/language>/ {
        print
        print ""
        print new_item
        next
    }
    { print }
    ' "${APPCAST_FILE}.bak" > "${APPCAST_FILE}"
    
    echo -e "${GREEN}✅ Appcast updated with Build ${BUILD_NUMBER}!${NC}"
    echo -e "${BLUE}   File: ${APPCAST_FILE}${NC}"
    if [ -n "${EDDSA_SIGNATURE}" ]; then
        echo -e "${GREEN}   ✅ EdDSA signature included for enhanced security!${NC}"
    else
        echo -e "${YELLOW}   ⚠️  Warning: EdDSA signature not included${NC}"
    fi
else
    echo -e "${RED}❌ Warning: appcast.xml not found at ${APPCAST_FILE}${NC}"
    echo -e "${YELLOW}   Skipping appcast update...${NC}"
fi

# Create GitHub release instructions
cat > "${BUILD_DIR}/GITHUB_RELEASE_INSTRUCTIONS.txt" <<EOF
GitHub Release Instructions for Build ${BUILD_NUMBER}
=====================================================

Files to Upload:
1. DMG: Distribution/DMG/Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg
2. ZIP: Distribution/Upload/Clnbrd-Build${BUILD_NUMBER}-Notarized.zip
3. JSON: Distribution/Upload/clnbrd-version.json
4. Appcast: appcast.xml (auto-updated)

Command to create release:
--------------------------
cd /Users/allanalomes/Documents/AlsApp/Clnbrd

gh release create v${VERSION}-build${BUILD_NUMBER} \\
  --title "v${VERSION} (Build ${BUILD_NUMBER}) - ✅ Fully Notarized by Apple" \\
  --notes "Release notes here..." \\
  --latest \\
  Clnbrd/Distribution/DMG/Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg \\
  Clnbrd/Distribution/Upload/Clnbrd-Build${BUILD_NUMBER}-Notarized.zip \\
  Clnbrd/Distribution/Upload/clnbrd-version.json \\
  appcast.xml

Or to update existing release:
------------------------------
gh release upload v${VERSION}-build${BUILD_NUMBER} \\
  Clnbrd/Distribution/DMG/Clnbrd-${VERSION}-Build-${BUILD_NUMBER}-Notarized.dmg \\
  Clnbrd/Distribution/Upload/Clnbrd-Build${BUILD_NUMBER}-Notarized.zip \\
  Clnbrd/Distribution/Upload/clnbrd-version.json \\
  appcast.xml \\
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
echo -e "  • Appcast: ../appcast.xml (updated)"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. 📡 Review & commit appcast.xml changes"
echo -e "  2. 📤 Upload to GitHub using instructions in:"
echo -e "     ${BUILD_DIR}/GITHUB_RELEASE_INSTRUCTIONS.txt"
echo ""

