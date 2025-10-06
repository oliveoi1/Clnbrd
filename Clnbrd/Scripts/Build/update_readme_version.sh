#!/bin/bash

# Auto-update README.md with current version information
# This script is called automatically during the build process

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get version info from Info.plist
VERSION=$(plutil -extract CFBundleShortVersionString raw Clnbrd/Info.plist)
BUILD_NUMBER=$(plutil -extract CFBundleVersion raw Clnbrd/Info.plist)

echo -e "${YELLOW}📝 Updating README.md with version info...${NC}"
echo "   Version: ${VERSION}"
echo "   Build: ${BUILD_NUMBER}"

# Update both README files (repo root and Clnbrd subdirectory)
README_FILES=("../README.md" "README.md")

for README in "${README_FILES[@]}"; do
    if [ -f "$README" ]; then
        echo "   Updating: $README"
        
        # Update "Version History" section
        sed -i '' "s|### v[0-9.]* (Build [0-9]*) - Current|### v${VERSION} (Build ${BUILD_NUMBER}) - Current|g" "$README"
        
        # Update badge URLs (fix GitHub username and build number)
        sed -i '' "s|badge/build-[0-9]*-green|badge/build-${BUILD_NUMBER}-green|g" "$README"
        sed -i '' "s|github.com/yourusername/|github.com/oliveoi1/|g" "$README"
        
        # Update "For Testing" section
        sed -i '' "s|Clnbrd-1\\.3-Build-[0-9]*\\.dmg|Clnbrd-${VERSION}-Build-${BUILD_NUMBER}.dmg|g" "$README"
        
        # Update "Current Status" section
        sed -i '' "s|- \\*\\*Version\\*\\*: [0-9.]* (Build [0-9]*)|- **Version**: ${VERSION} (Build ${BUILD_NUMBER})|g" "$README"
        
        # Update "Current Build" section  
        sed -i '' "s|Clnbrd-Build[0-9]*\\.zip|Clnbrd-Build${BUILD_NUMBER}.zip|g" "$README"
        sed -i '' "s|Clnbrd-1\\.[0-9]-Build-[0-9]*\\.dmg|Clnbrd-${VERSION}-Build-${BUILD_NUMBER}.dmg|g" "$README"
        
        # Update footer with current date and build
        CURRENT_DATE=$(date +"%B %d, %Y")
        sed -i '' "s|\\*\\*Last Updated\\*\\*: .*$|**Last Updated**: ${CURRENT_DATE}  |g" "$README"
        sed -i '' "s|\\*\\*Current Build\\*\\*: .*$|**Current Build**: ${VERSION} (${BUILD_NUMBER})  |g" "$README"
    fi
done

echo -e "${GREEN}✅ README files updated successfully!${NC}"

