# Clnbrd Build & Notarization Workflow

**Last Updated:** October 6, 2025  
**Status:** ✅ Fully Automated & Tested

## Overview

This document describes the complete build, signing, notarization, and distribution workflow for Clnbrd. All scripts have been updated to handle:

- ✅ Proper code signing with Developer ID
- ✅ Sparkle framework component signing
- ✅ Extended attribute cleaning
- ✅ Notarization-ready ZIP creation
- ✅ Professional DMG generation
- ✅ Auto-update JSON generation
- ✅ GitHub release preparation

---

## Prerequisites

### Required Tools
- Xcode 16.0+
- Valid Developer ID Application certificate
- App-specific password for notarization
- GitHub CLI (`gh`) for releases

### Environment Variables
- **Apple ID:** `olivedesignstudios@gmail.com`
- **Team ID:** `58Y8VPZ7JG`
- **Developer ID:** `Developer ID Application: Allan Alomes (58Y8VPZ7JG)`

---

## Build Process

### Step 1: Build & Sign

Run the main build script:

```bash
cd /Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd
./build_distribution.sh
```

**What it does:**
1. ✅ Auto-increments build number
2. ✅ Updates README.md with new version
3. ✅ Builds and archives with code signing
4. ✅ Cleans all extended attributes (using `xattr -cr` and `dot_clean`)
5. ✅ Signs Sparkle framework components:
   - `XPCServices/Downloader.xpc`
   - `XPCServices/Installer.xpc`
   - `Updater.app`
   - `Autoupdate`
6. ✅ Signs main frameworks (Sparkle, Sentry)
7. ✅ Signs main app with hardened runtime
8. ✅ Creates notarization-ready ZIP using `ditto --sequesterRsrc`

**Output:**
- `Distribution/App/Clnbrd.app` - Signed app
- `Distribution/Upload/Clnbrd-Build{N}.zip` - Ready for notarization
- `Distribution/Logs/` - Build logs

---

### Step 2: Submit for Notarization

The build script will display the notarization command. Run it:

```bash
xcrun notarytool submit Distribution/Upload/Clnbrd-Build{N}.zip \
  --apple-id olivedesignstudios@gmail.com \
  --team-id 58Y8VPZ7JG \
  --password "YOUR-APP-SPECIFIC-PASSWORD" \
  --wait
```

**Wait for:** `status: Accepted`

If notarization fails, get the log:
```bash
xcrun notarytool log SUBMISSION_ID \
  --apple-id olivedesignstudios@gmail.com \
  --team-id 58Y8VPZ7JG \
  --password "YOUR-APP-SPECIFIC-PASSWORD"
```

---

### Step 3: Finalize Build

After notarization is **Accepted**, run:

```bash
./Scripts/Build/finalize_notarized_build.sh {BUILD_NUMBER}
```

**Example:**
```bash
./Scripts/Build/finalize_notarized_build.sh 33
```

**What it does:**
1. ✅ Extracts notarized app from ZIP
2. ✅ Staples notarization ticket
3. ✅ Validates with Gatekeeper
4. ✅ Creates final notarized ZIP
5. ✅ Generates professional DMG with:
   - Notarized Clnbrd.app
   - Applications folder shortcut
   - Installation instructions
6. ✅ Generates `clnbrd-version.json` for auto-updates
7. ✅ Creates GitHub release instructions

**Output:**
- `Distribution/DMG/Clnbrd-{VERSION}-Build-{N}-Notarized.dmg`
- `Distribution/Upload/Clnbrd-Build{N}-Notarized.zip`
- `Distribution/Upload/clnbrd-version.json`
- `Distribution/GITHUB_RELEASE_INSTRUCTIONS.txt`

---

### Step 4: Create GitHub Release

Follow the instructions in `Distribution/GITHUB_RELEASE_INSTRUCTIONS.txt`, or run:

```bash
cd /Users/allanalomes/Documents/AlsApp/Clnbrd

gh release create v{VERSION}-build{N} \
  --title "v{VERSION} (Build {N}) - ✅ Fully Notarized by Apple" \
  --notes "Release notes..." \
  --latest \
  Clnbrd/Distribution/DMG/Clnbrd-{VERSION}-Build-{N}-Notarized.dmg \
  Clnbrd/Distribution/Upload/Clnbrd-Build{N}-Notarized.zip \
  Clnbrd/Distribution/Upload/clnbrd-version.json
```

---

## Key Improvements

### 1. Extended Attribute Handling
**Problem:** Resource forks and Finder info prevented signing  
**Solution:** 
```bash
xattr -cr Clnbrd.app
dot_clean -m Clnbrd.app
find Clnbrd.app -name "._*" -delete
```

### 2. Sparkle Framework Signing
**Problem:** Nested executables weren't signed, causing notarization rejection  
**Solution:** Sign all components individually with hardened runtime:
```bash
codesign --force --sign "${DEVELOPER_ID}" --options runtime --timestamp XPCServices/Downloader.xpc
codesign --force --sign "${DEVELOPER_ID}" --options runtime --timestamp XPCServices/Installer.xpc
codesign --force --sign "${DEVELOPER_ID}" --options runtime --timestamp Updater.app
codesign --force --sign "${DEVELOPER_ID}" --options runtime --timestamp Autoupdate
```

### 3. Notarization-Ready ZIP
**Problem:** Standard `zip` included resource forks  
**Solution:** Use `ditto` with `--sequesterRsrc`:
```bash
ditto -c -k --keepParent --sequesterRsrc App/Clnbrd.app Upload/Clnbrd-BuildN.zip
```

### 4. Version Automation
**Problem:** Version info wasn't always in sync  
**Solution:** 
- `VersionManager.swift` reads from `Info.plist` dynamically
- Build scripts update README.md automatically
- JSON file generated with correct version info

---

## Troubleshooting

### Notarization Rejected
**Check the log:**
```bash
xcrun notarytool log SUBMISSION_ID --apple-id ... --team-id ... --password ...
```

**Common issues:**
- ❌ `The binary is not signed with a valid Developer ID` → Re-sign component
- ❌ `The signature does not include a secure timestamp` → Add `--timestamp` flag
- ❌ `Disallowed xattr found` → Run `xattr -cr` again

### Code Signing Errors
**"resource fork, Finder information, or similar detritus not allowed"**
```bash
xattr -cr Clnbrd.app
dot_clean -m Clnbrd.app
find Clnbrd.app -name "._*" -delete
```

### Build Number Mismatch
**App shows wrong build number:**
- Rebuild from Xcode (⌘R)
- `VersionManager` reads from `Info.plist` dynamically
- Old cached builds may show outdated numbers

---

## File Locations

### Source
- **Main Script:** `build_distribution.sh`
- **Finalize Script:** `Scripts/Build/finalize_notarized_build.sh`
- **Version Manager:** `Clnbrd/VersionManager.swift`
- **Info.plist:** `Clnbrd/Info.plist`

### Distribution
- **App:** `Distribution/App/Clnbrd.app`
- **Notarized App:** `Distribution/Notarized/Clnbrd.app`
- **DMG:** `Distribution/DMG/Clnbrd-{VERSION}-Build-{N}-Notarized.dmg`
- **ZIP:** `Distribution/Upload/Clnbrd-Build{N}-Notarized.zip`
- **JSON:** `Distribution/Upload/clnbrd-version.json`
- **Logs:** `Distribution/Logs/`

---

## Quick Reference

### Full Build & Release (All Steps)
```bash
# 1. Build
./build_distribution.sh

# 2. Notarize (get command from build output)
xcrun notarytool submit Distribution/Upload/Clnbrd-Build{N}.zip \
  --apple-id olivedesignstudios@gmail.com \
  --team-id 58Y8VPZ7JG \
  --password "YOUR-PASSWORD" \
  --wait

# 3. Finalize
./Scripts/Build/finalize_notarized_build.sh {N}

# 4. Release
# Follow instructions in Distribution/GITHUB_RELEASE_INSTRUCTIONS.txt
```

---

## Support

- **Email:** olivedesignstudios@gmail.com
- **GitHub:** https://github.com/oliveoi1/Clnbrd
- **Documentation:** `/Users/allanalomes/Documents/AlsApp/Clnbrd/Documentation/`

---

**This workflow has been tested and verified for Build 33 (October 6, 2025)**

