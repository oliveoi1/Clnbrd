# Quick Notarization Reference Card

## 🚀 Fast Track: Build → Notarize → Distribute

### Prerequisites (One-Time Setup)
```bash
# Store Apple ID credentials in keychain
xcrun notarytool store-credentials "CLNBRD_NOTARIZATION" \
  --apple-id olivedesignstudios@gmail.com \
  --team-id 58Y8VPZ7JG
# Enter app-specific password when prompted
```

### The Three Commands You Need

```bash
# 1️⃣ BUILD (Clean-room process, ~2-3 min)
./build_notarization_fixed.sh

# 2️⃣ NOTARIZE (Wait for Apple, ~2-5 min)
xcrun notarytool submit Distribution-Clean/Upload/Clnbrd-*.zip \
  --keychain-profile "CLNBRD_NOTARIZATION" \
  --wait

# 3️⃣ FINALIZE (Staple & create DMG, ~1 min)
./finalize_notarized_clean.sh
```

**Total time**: ~5-10 minutes from source to distributable DMG

---

## 📋 Complete Workflow with Checks

### Step 1: Build
```bash
./build_notarization_fixed.sh

# ✅ Success indicators:
# - "CLEAN-ROOM BUILD COMPLETED SUCCESSFULLY"
# - "All extended attributes removed (verified)"
# - "App signature verified (deep check passed)"

# 📁 Output: Distribution-Clean/Upload/Clnbrd-*.zip
```

### Step 2: Notarize
```bash
# Option A: Using keychain profile (recommended)
xcrun notarytool submit Distribution-Clean/Upload/Clnbrd-*.zip \
  --keychain-profile "CLNBRD_NOTARIZATION" \
  --wait

# Option B: Using password directly
xcrun notarytool submit Distribution-Clean/Upload/Clnbrd-*.zip \
  --apple-id olivedesignstudios@gmail.com \
  --team-id 58Y8VPZ7JG \
  --password <APP_SPECIFIC_PASSWORD> \
  --wait

# ✅ Success indicator:
# - "status: Accepted"

# ❌ If rejected, get log:
xcrun notarytool log <SUBMISSION_ID> \
  --keychain-profile "CLNBRD_NOTARIZATION" \
  notarization-log.json
```

### Step 3: Finalize
```bash
./finalize_notarized_clean.sh

# ✅ Success indicators:
# - "Notarization ticket stapled successfully"
# - "Gatekeeper: ACCEPTED"
# - "DMG created: X.X MB"

# 📁 Output: Distribution-Clean/DMG/Clnbrd-*.dmg
```

---

## 🔍 Quick Diagnostics

### Check Build Status
```bash
# Verify no extended attributes
find Distribution-Clean/App/Clnbrd.app -exec xattr -l {} \; | wc -l
# Should return: 0

# Verify signature
codesign --verify --deep Distribution-Clean/App/Clnbrd.app
# Should return: (nothing = success)
```

### Check Notarization Status
```bash
# List recent submissions
xcrun notarytool history --keychain-profile "CLNBRD_NOTARIZATION"

# Get specific submission details
xcrun notarytool info <SUBMISSION_ID> \
  --keychain-profile "CLNBRD_NOTARIZATION"
```

### Check Final App
```bash
# Verify stapling
xcrun stapler validate Distribution-Clean/App/Clnbrd.app
# Should return: "The validate action worked"

# Check Gatekeeper
spctl -a -vvv -t install Distribution-Clean/App/Clnbrd.app
# Should return: "accepted source=Notarized Developer ID"
```

---

## 🆘 Common Issues & Quick Fixes

### Issue: "Signing identity not found"
```bash
# Check available identities
security find-identity -v -p codesigning

# Fix: Re-download certificate in Xcode
# Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application
```

### Issue: "Build failed"
```bash
# Check log
tail -50 Distribution-Clean/Logs/build.log

# Quick fixes:
rm -rf ~/Library/Developer/Xcode/DerivedData/*  # Clean derived data
xcodebuild clean -project Clnbrd.xcodeproj      # Clean project
```

### Issue: "Extended attributes still present"
```bash
# Manual cleanup
cd Distribution-Clean/App
sudo xattr -cr Clnbrd.app
find Clnbrd.app -name "._*" -delete

# Then re-sign
codesign --force --deep --sign "Developer ID Application: Allan Alomes (58Y8VPZ7JG)" \
  --options runtime --timestamp Clnbrd.app
```

### Issue: "Notarization rejected"
```bash
# Get detailed log
xcrun notarytool log <SUBMISSION_ID> \
  --keychain-profile "CLNBRD_NOTARIZATION" \
  notarization-log.json

# Check for specific issues
cat notarization-log.json | jq '.issues'

# Common issues:
# - Invalid signature → Re-run build_notarization_fixed.sh
# - Missing hardened runtime → Check build script has --options runtime
# - Entitlements mismatch → Check Clnbrd.entitlements file
```

---

## 📊 Build Variants

### Quick Build (Skip Version Increment)
```bash
# If you just want to rebuild without changing version
./build_notarization_fixed.sh
# Version stays the same
```

### Production Build (With Version Update)
```bash
# Increment version first
./Scripts/Build/increment_build_number.sh "Release v1.4"

# Then build
./build_notarization_fixed.sh
```

---

## 🧪 Testing Checklist

### Pre-Distribution Tests
```bash
# 1. Verify DMG
hdiutil verify Distribution-Clean/DMG/*.dmg

# 2. Mount and test
open Distribution-Clean/DMG/*.dmg
# → Drag to Applications
# → Launch app
# → Test core features

# 3. Check on clean Mac (if available)
# → Copy DMG to another Mac
# → Double-click to mount
# → Verify no Gatekeeper warnings
# → Test full functionality
```

---

## 📤 Distribution

### Upload to GitHub Releases
```bash
# Using GitHub CLI (recommended)
gh release create v1.3.50 \
  Distribution-Clean/DMG/Clnbrd-*.dmg \
  --title "Clnbrd v1.3 (Build 50)" \
  --notes "Release notes here"

# Or manually:
# 1. Go to https://github.com/oliveoi1/Clnbrd/releases/new
# 2. Tag: v1.3.50
# 3. Upload DMG
# 4. Add release notes
# 5. Publish
```

### Update Sparkle Appcast
```bash
# 1. Get DMG download URL from GitHub release
# 2. Edit appcast-v2.xml
# 3. Update version, build number, URL, release notes
# 4. Commit and push

# Example appcast entry:
# <item>
#   <title>Version 1.3 (Build 50)</title>
#   <sparkle:version>50</sparkle:version>
#   <sparkle:shortVersionString>1.3</sparkle:shortVersionString>
#   <link>https://github.com/oliveoi1/Clnbrd/releases/tag/v1.3.50</link>
#   <enclosure
#     url="https://github.com/oliveoi1/Clnbrd/releases/download/v1.3.50/Clnbrd-1.3-Build-50-Notarized.dmg"
#     sparkle:edSignature="..."
#     length="..."
#     type="application/octet-stream"
#   />
# </item>
```

---

## 🔐 Security Best Practices

### Protect Your Credentials
```bash
# ✅ DO: Use keychain-profile
xcrun notarytool store-credentials "CLNBRD_NOTARIZATION" ...

# ❌ DON'T: Put password in scripts
# ❌ DON'T: Put password in shell history
# ❌ DON'T: Commit password to git
```

### App-Specific Password Setup
1. Go to https://appleid.apple.com
2. Sign In
3. Security → App-Specific Passwords
4. Generate → "Clnbrd Notarization"
5. Save in 1Password/Keychain

---

## 📈 Version History Tracking

### Before Each Build
```bash
# Check current version
plutil -extract CFBundleShortVersionString raw Clnbrd/Info.plist
plutil -extract CFBundleVersion raw Clnbrd/Info.plist

# Increment if needed
./Scripts/Build/increment_build_number.sh "Your commit message"
```

### After Each Release
```bash
# Tag in git
git tag -a v1.3.50 -m "Release v1.3 (Build 50)"
git push origin v1.3.50

# Archive build
mv Distribution-Clean Distribution-Archive/Build-50-$(date +%Y%m%d)
```

---

## 🎯 Success Checklist

Before distributing, ensure:

- [ ] Build completed without errors
- [ ] No extended attributes present (verified)
- [ ] Code signature verified (deep check)
- [ ] Notarization accepted by Apple
- [ ] Notarization ticket stapled
- [ ] Gatekeeper accepts app
- [ ] DMG created and verified
- [ ] Tested on local Mac
- [ ] (Optional) Tested on clean Mac
- [ ] GitHub release created
- [ ] Appcast updated and pushed
- [ ] Auto-update tested

---

## 🔗 Useful Commands

```bash
# Clean everything and start fresh
rm -rf Distribution-Clean
./build_notarization_fixed.sh

# Check certificate expiration
security find-identity -v -p codesigning | grep "Developer ID Application"
# Look for expiration date in certificate details

# View app bundle info
defaults read Distribution-Clean/App/Clnbrd.app/Contents/Info.plist

# Check frameworks
ls -la Distribution-Clean/App/Clnbrd.app/Contents/Frameworks/

# View entitlements
codesign -d --entitlements - Distribution-Clean/App/Clnbrd.app
```

---

## 📞 Quick Support

**Build Issues**: Check `Distribution-Clean/Logs/build.log`  
**Notarization Issues**: Get log with `xcrun notarytool log`  
**Signature Issues**: Run `codesign --verify --verbose=4`  
**DMG Issues**: Run `hdiutil verify` on DMG

**Full Guide**: See `NOTARIZATION_FIX_GUIDE.md` for detailed troubleshooting

---

**Last Updated**: October 9, 2025  
**Script Version**: 1.0  
**macOS Compatibility**: Sequoia (15.0+)

