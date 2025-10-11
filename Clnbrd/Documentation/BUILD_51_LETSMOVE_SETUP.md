# Build 51 - LetsMove Integration Setup Guide

**Branch:** `build-51-letsmove`  
**Feature:** Automatic "Move to Applications" prompt  
**Build Number:** 51

---

## 📦 What's New in Build 51

### LetsMove Integration
When users run Clnbrd from the wrong location (Downloads, Desktop, or DMG), they'll see a friendly prompt asking to move the app to `/Applications`. This fixes:

- ✅ **Launch at Login issues** - SMAppService requires app to be in /Applications
- ✅ **Sparkle update issues** - Updates work better from /Applications  
- ✅ **Permission persistence** - macOS handles permissions better for apps in /Applications
- ✅ **User confusion** - Automates the "please move to Applications" instruction

---

## 🔧 Files Added

```
Clnbrd/
├── PFMoveApplication.h          ← LetsMove header
├── PFMoveApplication.m          ← LetsMove implementation
└── Clnbrd-Bridging-Header.h    ← Swift-Obj-C bridge
```

---

## ⚙️ Xcode Setup Required

### Step 1: Add Files to Xcode Project

1. Open `Clnbrd.xcodeproj` in Xcode
2. Right-click on the `Clnbrd` folder in Project Navigator
3. Select **Add Files to "Clnbrd"...**
4. Navigate to `Clnbrd/` folder and select:
   - `PFMoveApplication.h`
   - `PFMoveApplication.m`
   - `Clnbrd-Bridging-Header.h`
5. Make sure **"Copy items if needed"** is UNCHECKED (files are already in place)
6. Make sure **"Add to targets: Clnbrd"** is CHECKED
7. Click **Add**

### Step 2: Configure Bridging Header

1. Select the **Clnbrd** project in Project Navigator (top blue icon)
2. Select the **Clnbrd** target
3. Go to **Build Settings** tab
4. Search for "bridging"
5. Find **Objective-C Bridging Header**
6. Set its value to: `Clnbrd/Clnbrd-Bridging-Header.h`
   - Or just: `$(SRCROOT)/Clnbrd/Clnbrd-Bridging-Header.h`

### Step 3: Build and Test

1. Clean the build folder: **Product → Clean Build Folder** (⌘⇧K)
2. Build: **Product → Build** (⌘B)
3. Should build successfully!

**Note:** You'll only be able to test the "Move to Applications" prompt if you run the app from outside `/Applications` (like from Desktop or Downloads).

---

## 🧪 Testing the Feature

### Test Scenario 1: Run from Wrong Location
```bash
# Copy built app to Desktop
cp -R ~/Library/Developer/Xcode/DerivedData/.../Clnbrd.app ~/Desktop/

# Run from Desktop
open ~/Desktop/Clnbrd.app

# Expected: Dialog asking "Would you like to move Clnbrd to Applications?"
```

### Test Scenario 2: Already in Applications
```bash
# Copy to Applications
cp -R ~/Library/Developer/Xcode/DerivedData/.../Clnbrd.app /Applications/

# Run from Applications
open /Applications/Clnbrd.app

# Expected: No dialog, app launches normally
```

### Test Scenario 3: Development Build
When running from Xcode (⌘R), the prompt is **disabled** by the `#if !DEBUG` wrapper, so development is unaffected.

---

## 📝 Changes Made

### 1. Info.plist
```xml
<!-- Updated build number -->
<key>CFBundleShortVersionString</key>
<string>1.3 (51)</string>
<key>CFBundleVersion</key>
<string>51</string>
```

### 2. AppDelegate.swift
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // NEW: Prompt to move to Applications if needed
    #if !DEBUG
    PFMoveToApplicationsFolderIfNecessary()
    #endif
    
    // Existing code...
    SentryManager.shared.initialize()
    // ...
}
```

### 3. Added LetsMove Library
- `PFMoveApplication.h` - Header file
- `PFMoveApplication.m` - Implementation
- `Clnbrd-Bridging-Header.h` - Swift-Objective-C bridge

---

## 🚀 Building and Notarizing

Once Xcode is configured, use the same build process as Build 50:

```bash
# Build and sign
cd /Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd
./build_notarization_fixed.sh

# Notarize
xcrun notarytool submit Distribution-Clean/Upload/*.zip \
  --keychain-profile "CLNBRD_NOTARIZATION" \
  --wait

# Finalize
./finalize_notarized_clean.sh
```

**Note:** LetsMove is Objective-C code that gets compiled into your app. No additional frameworks to sign!

---

## ✅ Verification Checklist

After Xcode setup:

- [ ] Project builds without errors (⌘B)
- [ ] No bridging header warnings
- [ ] App runs from Xcode normally (no prompt in DEBUG mode)
- [ ] Copy app to Desktop and run - should show "Move to Applications" dialog
- [ ] After moving, app runs from /Applications normally
- [ ] Launch at Login works (from /Applications)
- [ ] Sparkle updates work

---

## 🔄 Merging to Main

Once tested and verified:

```bash
# Commit changes
git add .
git commit -m "Add LetsMove integration for Build 51

- Prompts users to move app to Applications folder
- Fixes SMAppService (Launch at Login) reliability
- Fixes Sparkle update issues
- Improved user experience and fewer support issues
- Only shows prompt when running from non-Applications location
- Disabled during development (#if !DEBUG)"

# Push branch
git push origin build-51-letsmove

# After testing, merge to main
git checkout main
git merge build-51-letsmove
git push origin main

# Tag the release
git tag -a v1.3.51 -m "Build 51 - LetsMove Integration"
git push origin v1.3.51
```

---

## 📚 Reference

### LetsMove Documentation
- **GitHub**: https://github.com/potionfactory/LetsMove
- **License**: Public Domain
- **Used by**: The Unarchiver, AppCleaner, and hundreds of other Mac apps

### Why This Matters
From Apple's documentation:
> "Apps distributed outside the Mac App Store should be placed in /Applications or /Applications/Utilities to ensure proper functionality of Launch Services, Sparkle updates, and SMAppService."

---

## 🎯 Expected User Experience

### Before Build 51:
```
User downloads DMG
→ Opens and runs app from Downloads
→ Launch at Login doesn't work
→ Updates fail mysteriously
→ User reads docs: "Please move to Applications"
→ User manually moves app
```

### After Build 51:
```
User downloads DMG
→ Opens and runs app
→ Dialog: "Clnbrd would like to move to Applications folder"
→ User clicks "Move to Applications"
→ App moves itself automatically
→ Everything works perfectly!
```

---

## ❓ Troubleshooting

### "Bridging header not found"
- Make sure path is: `Clnbrd/Clnbrd-Bridging-Header.h`
- Try absolute path: `$(SRCROOT)/Clnbrd/Clnbrd-Bridging-Header.h`
- Clean build folder (⌘⇧K) and rebuild

### "Use of undeclared identifier 'PFMoveToApplicationsFolderIfNecessary'"
- Make sure bridging header imports `PFMoveApplication.h`
- Make sure `.m` file is added to build target
- Clean and rebuild

### Prompt doesn't appear during testing
- Make sure you're running from outside `/Applications`
- Make sure it's a Release build (or remove `#if !DEBUG`)
- Check Console.app for any errors

---

**Status:** Ready for Xcode configuration and testing  
**Next:** Configure Xcode, build, test, and release Build 51! 🚀

