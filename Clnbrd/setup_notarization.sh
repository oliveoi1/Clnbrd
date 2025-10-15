#!/bin/bash

# Script to help set up notarization keychain profile

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Notarization Keychain Profile Setup                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "This will securely store your Apple notarization credentials"
echo "in your macOS Keychain, so you won't need to enter them manually."
echo ""
echo "You'll need:"
echo "  • Your Apple ID: olivedesignstudios@gmail.com"
echo "  • Your App-Specific Password (NOT your Apple ID password)"
echo ""
echo "If you don't have an app-specific password yet:"
echo "  1. Go to: https://appleid.apple.com/account/manage"
echo "  2. Sign in"
echo "  3. Navigate to 'Sign-In and Security' → 'App-Specific Passwords'"
echo "  4. Generate a new password (name it 'Clnbrd Notarization')"
echo ""
echo "Press Enter when ready to set up the keychain profile..."
read

xcrun notarytool store-credentials "CLNBRD_NOTARIZATION" \
  --apple-id "olivedesignstudios@gmail.com" \
  --team-id "58Y8VPZ7JG"

echo ""
echo "Setup complete! You can now use --keychain-profile CLNBRD_NOTARIZATION"
echo "for all future notarization submissions."

