#!/bin/bash

# Clnbrd Beta Release Script
# Handles version bumping, building, notarizing, and GitHub release for beta versions

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
INFO_PLIST="${PROJECT_DIR}/Clnbrd/Info.plist"

# Apple Developer Configuration
APPLE_ID="olivedesignstudios@gmail.com"
TEAM_ID="58Y8VPZ7JG"
NOTARIZATION_PROFILE="CLNBRD_NOTARIZATION"  # Update if using keychain profile

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║              Clnbrd Beta Release Automation                 ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get current version info
CURRENT_VERSION=$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")
CURRENT_BUILD=$(plutil -extract CFBundleVersion raw "$INFO_PLIST")

echo -e "${CYAN}📋 Current Version Information:${NC}"
echo -e "${BLUE}   Version: ${CURRENT_VERSION}${NC}"
echo -e "${BLUE}   Build: ${CURRENT_BUILD}${NC}"
echo ""

# Parse version components
if [[ $CURRENT_VERSION =~ ^([0-9]+\.[0-9]+\.[0-9]+)-beta\.([0-9]+)$ ]]; then
    BASE_VERSION="${BASH_REMATCH[1]}"
    BETA_NUM="${BASH_REMATCH[2]}"
    IS_BETA=true
else
    echo -e "${YELLOW}⚠️  Current version is not a beta version${NC}"
    echo -e "${YELLOW}   Would you like to create a new beta from this version? (y/n)${NC}"
    read -r CREATE_BETA
    if [[ $CREATE_BETA != "y" ]]; then
        echo -e "${RED}❌ Aborted${NC}"
        exit 1
    fi
    BASE_VERSION="$CURRENT_VERSION"
    BETA_NUM=0
    IS_BETA=false
fi

# Increment build number
NEW_BUILD=$((CURRENT_BUILD + 1))

# Determine new version
echo ""
echo -e "${YELLOW}📊 Version Update Options:${NC}"
echo -e "${BLUE}   1. Increment beta number: ${BASE_VERSION}-beta.$((BETA_NUM + 1))${NC}"
echo -e "${BLUE}   2. Keep same beta number: ${BASE_VERSION}-beta.${BETA_NUM}${NC}"
echo -e "${BLUE}   3. Create new beta series: [enter custom version]${NC}"
echo ""
echo -n "Select option (1-3) [1]: "
read -r VERSION_OPTION

case $VERSION_OPTION in
    2)
        NEW_VERSION="${BASE_VERSION}-beta.${BETA_NUM}"
        ;;
    3)
        echo -n "Enter new version (e.g., 1.4.1-beta.1): "
        read -r NEW_VERSION
        ;;
    *)
        NEW_VERSION="${BASE_VERSION}-beta.$((BETA_NUM + 1))"
        ;;
esac

echo ""
echo -e "${CYAN}📦 New Version Information:${NC}"
echo -e "${GREEN}   Version: ${CURRENT_VERSION} → ${NEW_VERSION}${NC}"
echo -e "${GREEN}   Build: ${CURRENT_BUILD} → ${NEW_BUILD}${NC}"
echo ""
echo -n "Proceed with this version? (y/n): "
read -r CONFIRM

if [[ $CONFIRM != "y" ]]; then
    echo -e "${RED}❌ Aborted${NC}"
    exit 1
fi

# Update Info.plist
echo ""
echo -e "${YELLOW}📝 Updating Info.plist...${NC}"

# Update CFBundleShortVersionString
plutil -replace CFBundleShortVersionString -string "$NEW_VERSION" "$INFO_PLIST"

# Update CFBundleVersion
plutil -replace CFBundleVersion -string "$NEW_BUILD" "$INFO_PLIST"

# Update CFBundleGetInfoString
plutil -replace CFBundleGetInfoString -string "Clnbrd ${NEW_VERSION} (Build ${NEW_BUILD}), Copyright © 2025 Allan Alomes" "$INFO_PLIST"

echo -e "${GREEN}✅ Info.plist updated${NC}"

# Verify updates
VERIFY_VERSION=$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")
VERIFY_BUILD=$(plutil -extract CFBundleVersion raw "$INFO_PLIST")

echo -e "${BLUE}   Verified: ${VERIFY_VERSION} (Build ${VERIFY_BUILD})${NC}"

# Step 1: Build and Sign
echo ""
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔨 Step 1/5: Building and Signing...${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

cd "$PROJECT_DIR"
if ! bash build_notarization_fixed.sh; then
    echo -e "${RED}❌ Build failed!${NC}"
    echo "Reverting version changes..."
    plutil -replace CFBundleShortVersionString -string "$CURRENT_VERSION" "$INFO_PLIST"
    plutil -replace CFBundleVersion -string "$CURRENT_BUILD" "$INFO_PLIST"
    exit 1
fi

echo -e "${GREEN}✅ Build completed successfully${NC}"

# Step 2: Submit for Notarization
echo ""
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📤 Step 2/5: Submitting for Notarization...${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

ZIP_FILE="${PROJECT_DIR}/Distribution-Clean/Upload/Clnbrd-v${NEW_VERSION}-Build${NEW_BUILD}-clean.zip"

if [ ! -f "$ZIP_FILE" ]; then
    echo -e "${RED}❌ Error: ZIP file not found at ${ZIP_FILE}${NC}"
    exit 1
fi

echo -e "${CYAN}📦 Submitting: $(basename "$ZIP_FILE")${NC}"
echo ""

# Check if using keychain profile or password
if security find-generic-password -s "CLNBRD_NOTARIZATION" &> /dev/null; then
    echo -e "${BLUE}🔑 Using keychain profile: ${NOTARIZATION_PROFILE}${NC}"
    NOTARIZATION_CMD="xcrun notarytool submit \"$ZIP_FILE\" --keychain-profile \"$NOTARIZATION_PROFILE\" --wait"
else
    echo -e "${YELLOW}⚠️  No keychain profile found. You'll need to enter your app-specific password.${NC}"
    echo -e "${BLUE}💡 Tip: Set up keychain profile with:${NC}"
    echo -e "${BLUE}   xcrun notarytool store-credentials CLNBRD_NOTARIZATION${NC}"
    echo ""
    echo -e "${YELLOW}Press Enter to submit with manual password entry...${NC}"
    read -r
    NOTARIZATION_CMD="xcrun notarytool submit \"$ZIP_FILE\" --apple-id \"$APPLE_ID\" --team-id \"$TEAM_ID\" --wait"
fi

echo ""
echo -e "${BLUE}⏳ Submitting to Apple (this usually takes 2-5 minutes)...${NC}"

if eval $NOTARIZATION_CMD; then
    echo ""
    echo -e "${GREEN}✅ Notarization ACCEPTED!${NC}"
else
    echo ""
    echo -e "${RED}❌ Notarization FAILED or REJECTED${NC}"
    echo ""
    echo "To get detailed error log:"
    echo "xcrun notarytool log <SUBMISSION_ID> --keychain-profile \"$NOTARIZATION_PROFILE\" error.json"
    exit 1
fi

# Step 3: Finalize (Staple + Create Release Files)
echo ""
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📌 Step 3/5: Finalizing (Stapling + DMG/ZIP Creation)...${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

cd "$PROJECT_DIR"
if ! bash finalize_notarized_clean.sh; then
    echo -e "${RED}❌ Finalization failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Finalization completed${NC}"

# Step 4: Commit Version Changes
echo ""
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}💾 Step 4/5: Committing Version Changes...${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

cd "$PROJECT_DIR"
git add Clnbrd/Info.plist

if git diff --cached --quiet; then
    echo -e "${BLUE}   No changes to commit${NC}"
else
    echo -e "${BLUE}   Committing version bump...${NC}"
    git commit -m "Bump version to ${NEW_VERSION} (Build ${NEW_BUILD})"
    echo -e "${GREEN}✅ Version changes committed${NC}"
fi

# Step 5: Create GitHub Release
echo ""
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🚀 Step 5/5: Creating GitHub Release...${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

DMG_FILE="${PROJECT_DIR}/Distribution-Clean/DMG/Clnbrd-${NEW_VERSION}-Build-${NEW_BUILD}-Notarized.dmg"
STAPLED_ZIP="${PROJECT_DIR}/Distribution-Clean/Upload/Clnbrd-v${NEW_VERSION}-Build${NEW_BUILD}-notarized-stapled.zip"

if [ ! -f "$DMG_FILE" ]; then
    echo -e "${RED}❌ Error: DMG not found at ${DMG_FILE}${NC}"
    exit 1
fi

if [ ! -f "$STAPLED_ZIP" ]; then
    echo -e "${RED}❌ Error: Stapled ZIP not found at ${STAPLED_ZIP}${NC}"
    exit 1
fi

echo -e "${CYAN}📦 Release Files:${NC}"
echo -e "${BLUE}   DMG: $(basename "$DMG_FILE") ($(du -h "$DMG_FILE" | cut -f1))${NC}"
echo -e "${BLUE}   ZIP: $(basename "$STAPLED_ZIP") ($(du -h "$STAPLED_ZIP" | cut -f1))${NC}"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}⚠️  GitHub CLI (gh) not found${NC}"
    echo -e "${BLUE}📝 Manual upload instructions:${NC}"
    echo -e "${BLUE}1. Go to: https://github.com/oliveoi1/Clnbrd/releases/new${NC}"
    echo -e "${BLUE}2. Tag: v${NEW_VERSION}${NC}"
    echo -e "${BLUE}3. Title: Clnbrd ${NEW_VERSION}${NC}"
    echo -e "${BLUE}4. Mark as pre-release (beta)${NC}"
    echo -e "${BLUE}5. Upload both files:${NC}"
    echo -e "${BLUE}   • ${DMG_FILE}${NC}"
    echo -e "${BLUE}   • ${STAPLED_ZIP}${NC}"
    echo ""
else
    echo -e "${YELLOW}Creating GitHub release notes...${NC}"
    
    RELEASE_NOTES="## Clnbrd ${NEW_VERSION} Beta

### What's New in This Beta

- UI improvements and refinements
- Enhanced settings window layout
- Bug fixes and performance improvements

### Installation

**For Manual Installation:**
Download the DMG file below and drag Clnbrd to your Applications folder.

**For Auto-Update (if you have a previous version):**
Your app will automatically update to this version.

### Beta Testing Notes

This is a beta release. Please report any issues you encounter:
- GitHub Issues: https://github.com/oliveoi1/Clnbrd/issues
- Email: olivedesignstudios@gmail.com

### Files

- **Clnbrd-${NEW_VERSION}-Build-${NEW_BUILD}-Notarized.dmg** - Manual installation
- **Clnbrd-v${NEW_VERSION}-Build${NEW_BUILD}-notarized-stapled.zip** - Sparkle auto-update (don't download manually)

---

**Note:** This is a pre-release beta version. Feedback is appreciated!"

    echo ""
    echo -e "${BLUE}Release notes:${NC}"
    echo "$RELEASE_NOTES" | sed 's/^/   /'
    echo ""
    echo -n "Create GitHub release now? (y/n): "
    read -r CREATE_RELEASE
    
    if [[ $CREATE_RELEASE == "y" ]]; then
        echo ""
        echo -e "${BLUE}🚀 Creating release...${NC}"
        
        # Push version commit first
        git push origin main || echo -e "${YELLOW}⚠️  Warning: Could not push to main${NC}"
        
        # Create release with both files
        if gh release create "v${NEW_VERSION}" \
            "$DMG_FILE" \
            "$STAPLED_ZIP" \
            --title "Clnbrd ${NEW_VERSION}" \
            --notes "$RELEASE_NOTES" \
            --prerelease; then
            echo ""
            echo -e "${GREEN}✅ GitHub release created successfully!${NC}"
            
            # Get the download URL for the ZIP (needed for appcast)
            RELEASE_URL=$(gh release view "v${NEW_VERSION}" --json assets --jq ".assets[] | select(.name | contains(\"clean.zip\")) | .url")
            ZIP_SIZE=$(stat -f%z "/Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd/Distribution-Clean/Upload/Clnbrd-v${NEW_VERSION}-Build${NEW_BUILD}-clean.zip")
            
            echo ""
            echo -e "${CYAN}📋 Appcast Update Information:${NC}"
            echo -e "${BLUE}   Version: ${NEW_VERSION}${NC}"
            echo -e "${BLUE}   Build: ${NEW_BUILD}${NC}"
            echo -e "${BLUE}   ZIP URL: ${RELEASE_URL}${NC}"
            echo -e "${BLUE}   ZIP Size: ${ZIP_SIZE} bytes${NC}"
            echo ""
            
            # Auto-update appcast
            echo -e "${YELLOW}📝 Auto-updating appcast-v2.xml...${NC}"
            APPCAST_FILE="${PROJECT_DIR}/appcast-v2.xml"
            
            if [ -f "$APPCAST_FILE" ]; then
                # Create backup
                cp "$APPCAST_FILE" "${APPCAST_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
                
                # Generate new appcast entry
                APPCAST_ENTRY="        <item>
            <title>⚠️ Version ${NEW_VERSION} (Build ${NEW_BUILD}) - BETA RELEASE</title>
            <link>https://github.com/oliveoi1/Clnbrd/releases/tag/v${NEW_VERSION}</link>
            <sparkle:version>${NEW_BUILD}</sparkle:version>
            <sparkle:shortVersionString>${NEW_VERSION}</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>⚠️ BETA RELEASE - Latest Updates</h2>
                
                <p><strong style=\"color: orange;\">This is a BETA release with latest improvements. 
                Build 52 (v1.3) remains the stable release.</strong></p>
                
                <h3>🔧 Build ${NEW_BUILD} Updates</h3>
                <ul>
                    <li><strong>Latest improvements and bug fixes</strong></li>
                    <li><strong>Enhanced UI and performance</strong></li>
                    <li><strong>Better user experience</strong></li>
                </ul>
                
                <h3>✨ All Previous Beta Features Included</h3>
                <ul>
                    <li>Complete onboarding system with permission handling</li>
                    <li>Clipboard History Strip with ⌘⇧V hotkey</li>
                    <li>Screenshot capture with ⌘⌥C</li>
                    <li>Modern \"liquid glass\" UI aesthetic</li>
                    <li>Light/Dark/Auto appearance modes</li>
                    <li>Performance optimizations</li>
                </ul>
                
                <h3>Technical Details</h3>
                <ul>
                    <li>Fully notarized for macOS Sequoia</li>
                    <li>Universal binary (Apple Silicon + Intel)</li>
                    <li>Compatible with macOS 15.5+</li>
                </ul>
            ]]></description>
            <pubDate>$(date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
            <enclosure 
                url=\"${RELEASE_URL}\" 
                sparkle:version=\"${NEW_BUILD}\" 
                sparkle:shortVersionString=\"${NEW_VERSION}\" 
                length=\"${ZIP_SIZE}\"
                type=\"application/octet-stream\"
            />
        </item>
        
        <item>"
                
                # Insert new entry after the first <item> tag
                sed -i '' "1,8a\\
${APPCAST_ENTRY}" "$APPCAST_FILE"
                
                # Update the comment at the bottom
                sed -i '' "s/<!-- Updated .* -->/<!-- Updated $(date '+%a %b %d %H:%M:%S PDT %Y') -->/" "$APPCAST_FILE"
                
                echo -e "${GREEN}✅ Appcast updated successfully${NC}"
                echo -e "${BLUE}   Backup created: ${APPCAST_FILE}.backup-$(date +%Y%m%d-%H%M%S)${NC}"
                
                # Commit appcast changes
                git add "$APPCAST_FILE"
                if git diff --cached --quiet; then
                    echo -e "${BLUE}   No appcast changes to commit${NC}"
                else
                    git commit -m "Update appcast for ${NEW_VERSION} (Build ${NEW_BUILD})"
                    git push origin main
                    echo -e "${GREEN}✅ Appcast changes committed and pushed${NC}"
                fi
            else
                echo -e "${RED}❌ Appcast file not found at ${APPCAST_FILE}${NC}"
                echo -e "${YELLOW}⚠️  Please update appcast-v2.xml manually${NC}"
            fi
        else
            echo ""
            echo -e "${RED}❌ Failed to create GitHub release${NC}"
            echo "You can create it manually or try again"
        fi
    else
        echo -e "${BLUE}📝 Skipped GitHub release creation${NC}"
        echo "You can create it manually later"
    fi
fi

# Summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            BETA RELEASE PROCESS COMPLETE!                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📦 Release: Clnbrd ${NEW_VERSION} (Build ${NEW_BUILD})${NC}"
echo -e "${CYAN}✅ Status: Fully built, notarized, and stapled${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo -e "${BLUE}1. Test the DMG on a clean Mac${NC}"
echo -e "${BLUE}2. Verify auto-update from previous beta${NC}"
echo -e "${BLUE}3. Announce beta release to testers${NC}"
echo ""
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

