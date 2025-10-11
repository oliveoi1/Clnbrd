#!/bin/bash

# LetsMove Test Script
# This will build a Release version and test the "Move to Applications" feature

set -e

echo "🧪 Testing LetsMove Integration..."
echo ""

cd "$(dirname "$0")"

# Step 1: Build Release version
echo "📦 Step 1: Building Release version..."
xcodebuild -project Clnbrd.xcodeproj \
    -scheme Clnbrd \
    -configuration Release \
    clean build \
    CONFIGURATION_BUILD_DIR="$(pwd)/TestBuild" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded!"
else
    echo "❌ Build failed!"
    exit 1
fi

# Step 2: Copy to Desktop for testing
echo ""
echo "📋 Step 2: Copying app to Desktop for testing..."
rm -rf ~/Desktop/Clnbrd-Test.app
cp -R TestBuild/Clnbrd.app ~/Desktop/Clnbrd-Test.app

echo "✅ App copied to ~/Desktop/Clnbrd-Test.app"

# Step 3: Instructions
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 TEST INSTRUCTIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "A test version of Clnbrd has been copied to your Desktop."
echo ""
echo "TO TEST LETSMOVE:"
echo ""
echo "1. Open Finder and go to your Desktop"
echo "2. Double-click 'Clnbrd-Test.app'"
echo ""
echo "EXPECTED RESULT:"
echo "You should see a dialog asking:"
echo "  'Clnbrd would like to move to the Applications folder.'"
echo "  'This is required for proper functionality.'"
echo ""
echo "OPTIONS TO TRY:"
echo "  • Click 'Move to Applications Folder' - App moves and relaunches"
echo "  • Click 'Do Not Move' - App stays on Desktop and runs"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔍 WHAT TO VERIFY:"
echo ""
echo "✓ Dialog appears when running from Desktop"
echo "✓ 'Move to Applications' button works"
echo "✓ App moves itself successfully"
echo "✓ App relaunches from /Applications"
echo "✓ No dialog when already in /Applications"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Ready to test! Open Finder and double-click the app on your Desktop."
echo ""

# Offer to open Finder to Desktop
read -p "Open Finder to Desktop now? (y/n) " -n 1 -r
echo
if [[ $REPL =~ ^[Yy]$ ]]; then
    open ~/Desktop
fi

