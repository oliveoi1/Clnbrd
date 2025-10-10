#!/bin/bash

# LetsMove Setup Verification Script
# Run this before and after Xcode configuration

echo "🔍 Verifying LetsMove Integration Setup..."
echo ""

cd "$(dirname "$0")"

# Check if files exist
echo "📁 Checking if LetsMove files exist..."
FILES=(
    "Clnbrd/PFMoveApplication.h"
    "Clnbrd/PFMoveApplication.m"
    "Clnbrd/Clnbrd-Bridging-Header.h"
)

ALL_EXIST=true
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file - MISSING!"
        ALL_EXIST=false
    fi
done

echo ""

if [ "$ALL_EXIST" = false ]; then
    echo "❌ Some files are missing. Cannot continue."
    exit 1
fi

echo "✅ All files exist!"
echo ""

# Check if bridging header is properly configured
echo "📝 Checking bridging header content..."
if grep -q "PFMoveApplication.h" "Clnbrd/Clnbrd-Bridging-Header.h"; then
    echo "  ✅ Bridging header imports PFMoveApplication.h"
else
    echo "  ❌ Bridging header doesn't import PFMoveApplication.h"
fi

echo ""

# Check if AppDelegate has the call
echo "🔧 Checking AppDelegate integration..."
if grep -q "PFMoveToApplicationsFolderIfNecessary()" "Clnbrd/AppDelegate.swift"; then
    echo "  ✅ AppDelegate calls PFMoveToApplicationsFolderIfNecessary()"
else
    echo "  ❌ AppDelegate doesn't call PFMoveToApplicationsFolderIfNecessary()"
fi

echo ""

# Check build number
echo "📊 Checking build number..."
BUILD_NUM=$(plutil -extract CFBundleVersion raw Clnbrd/Info.plist)
if [ "$BUILD_NUM" = "51" ]; then
    echo "  ✅ Build number is 51"
else
    echo "  ⚠️  Build number is $BUILD_NUM (expected 51)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 NEXT STEPS IN XCODE:"
echo ""
echo "1. Open Clnbrd.xcodeproj in Xcode"
echo ""
echo "2. Add files to project:"
echo "   • Right-click 'Clnbrd' folder in Project Navigator"
echo "   • Select 'Add Files to Clnbrd...'"
echo "   • Navigate to Clnbrd/ folder"
echo "   • Select these 3 files:"
echo "     - PFMoveApplication.h"
echo "     - PFMoveApplication.m"
echo "     - Clnbrd-Bridging-Header.h"
echo "   • UNCHECK 'Copy items if needed'"
echo "   • CHECK 'Add to targets: Clnbrd'"
echo "   • Click Add"
echo ""
echo "3. Configure bridging header:"
echo "   • Click Clnbrd project (blue icon at top)"
echo "   • Click Clnbrd target"
echo "   • Go to Build Settings tab"
echo "   • Search for 'bridging'"
echo "   • Find 'Objective-C Bridging Header'"
echo "   • Double-click to edit"
echo "   • Enter: Clnbrd/Clnbrd-Bridging-Header.h"
echo "   • Press Enter"
echo ""
echo "4. Build and test:"
echo "   • Press ⌘⇧K (Clean Build Folder)"
echo "   • Press ⌘B (Build)"
echo "   • Should build successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "After Xcode configuration, run this script again to verify!"

