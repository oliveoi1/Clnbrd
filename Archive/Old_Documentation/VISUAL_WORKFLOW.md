# Clnbrd Notarization Visual Workflow

## 🎯 The Complete Process (Visual Guide)

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  START: Your Swift Source Code (Clnbrd.xcodeproj)             │
│                                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 1: BUILD                                                  │
│  Command: ./build_notarization_fixed.sh                         │
│  Time: ~2-3 minutes                                             │
│                                                                 │
│  What happens:                                                  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ 1. Clean build environment                              │  │
│  │ 2. Build app to /tmp (avoids cloud sync)               │  │
│  │ 3. Strip ALL extended attributes                        │  │
│  │ 4. Sign frameworks (Sparkle, Sentry)                    │  │
│  │ 5. Sign XPC services and helpers                        │  │
│  │ 6. Sign main app bundle                                 │  │
│  │ 7. Verify signatures (deep check)                       │  │
│  │ 8. Create clean ZIP for notarization                    │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ✅ Success indicators:                                         │
│    • "All extended attributes removed (verified)"              │
│    • "App signature verified (deep check passed)"              │
│    • "CLEAN-ROOM BUILD COMPLETED SUCCESSFULLY"                 │
│                                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  OUTPUT: Distribution-Clean/Upload/Clnbrd-*.zip                │
│          (Ready for Apple notarization)                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 2: NOTARIZE                                               │
│  Command: xcrun notarytool submit ... --wait                    │
│  Time: ~2-5 minutes (Apple's servers)                           │
│                                                                 │
│  What happens:                                                  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ 1. ZIP uploaded to Apple                                │  │
│  │ 2. Apple scans for malware                              │  │
│  │ 3. Apple validates code signatures                      │  │
│  │ 4. Apple checks entitlements                            │  │
│  │ 5. Apple issues notarization ticket                     │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ✅ Success indicator:                                          │
│    • "status: Accepted"                                         │
│    • Submission ID provided                                    │
│                                                                 │
│  ❌ If rejected:                                                │
│    • Get log: xcrun notarytool log <ID> ... log.json           │
│    • Review issues in log.json                                 │
│    • Fix issues and rebuild                                    │
│                                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Apple's Notarization Ticket Issued                             │
│  (Stored on Apple's servers, linked to your app)                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 3: FINALIZE                                               │
│  Command: ./finalize_notarized_clean.sh                         │
│  Time: ~1 minute                                                │
│                                                                 │
│  What happens:                                                  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ 1. Download notarization ticket from Apple              │  │
│  │ 2. Staple ticket to app bundle                          │  │
│  │ 3. Verify stapling worked                               │  │
│  │ 4. Check Gatekeeper acceptance                          │  │
│  │ 5. Create DMG installer                                 │  │
│  │ 6. Generate release documentation                       │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ✅ Success indicators:                                         │
│    • "Notarization ticket stapled successfully"                │
│    • "Gatekeeper: ACCEPTED"                                     │
│    • "DMG created: X.X MB"                                      │
│                                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  OUTPUT: Distribution-Clean/DMG/Clnbrd-*.dmg                   │
│          ✨ READY FOR DISTRIBUTION! ✨                          │
│                                                                 │
│  This DMG can be:                                               │
│  • Uploaded to GitHub Releases                                 │
│  • Distributed on your website                                 │
│  • Shared directly with users                                  │
│  • Used for Sparkle auto-updates                               │
│                                                                 │
│  Users will NOT see Gatekeeper warnings!                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Problem vs Solution Flow

### ❌ OLD BROKEN PROCESS (What Was Happening)

```
Source Code
    │
    ▼
xcodebuild archive
    │
    ▼
xcodebuild -exportArchive  ← 💥 PROBLEM: Adds com.apple.provenance
    │                           attribute here!
    ▼
Try to remove attribute    ← ❌ FAILS: Can't remove system attribute
    │
    ▼
Try to sign                ← ❌ FAILS: Attribute still there
    │
    ▼
Try to notarize            ← ❌ REJECTED: Invalid signature
    │
    ▼
😤 FRUSTRATION
```

### ✅ NEW WORKING PROCESS (What Happens Now)

```
Source Code
    │
    ▼
xcodebuild build           ← ✅ Direct build, no archive
    │                         (No provenance attribute added!)
    ▼
Copy to /tmp               ← ✅ Clean environment
    │
    ▼
Strip attributes           ← ✅ Multiple passes, verified clean
    │
    ▼
Code sign                  ← ✅ Inside-out signing, all valid
    │
    ▼
Create clean ZIP           ← ✅ No attributes, no resource forks
    │
    ▼
Notarize                   ← ✅ ACCEPTED by Apple
    │
    ▼
Staple & DMG               ← ✅ Ready for distribution
    │
    ▼
😊 SUCCESS!
```

---

## 📊 Timeline Breakdown

### Full Build-to-Distribution Timeline

```
Time    Step                        What You See
─────   ───────────────────────    ────────────────────────────────
0:00    Start build                "Building Clnbrd v1.3..."
0:30    Building app               "Build successful"
1:00    Cleaning attributes        "All extended attributes removed"
1:30    Signing components         "Signing frameworks..."
2:00    Verifying                  "App signature verified"
2:30    Creating ZIP               "ZIP created: 12.5 MB"
3:00    ✅ Build complete          "READY FOR NOTARIZATION"

        📤 Submit to Apple         "Uploading..."
3:30    Waiting for Apple          "Processing..."
5:00    Apple scanning             "In Progress..."
7:00    ✅ Notarization accepted   "status: Accepted"

        🔧 Finalize                "Stapling..."
7:30    Stapling ticket            "Ticket stapled successfully"
8:00    Creating DMG               "DMG created: 13.2 MB"
8:30    ✅ Complete                "READY FOR DISTRIBUTION"

Total: ~8-9 minutes from source to distributable DMG
```

---

## 🏗️ Inside-Out Signing Order (Critical!)

```
┌─────────────────────────────────────────────────────────────┐
│ Clnbrd.app                                      ← 4. Last   │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Contents/                                               │ │
│ │ ┌─────────────────────────────────────────────────────┐ │ │
│ │ │ Frameworks/                                         │ │ │
│ │ │ ┌─────────────────────────────────────────────────┐ │ │ │
│ │ │ │ Sparkle.framework               ← 3. Third      │ │ │ │
│ │ │ │ ┌───────────────────────────────────────────┐   │ │ │ │
│ │ │ │ │ XPCServices/                              │   │ │ │ │
│ │ │ │ │ ├─ Downloader.xpc    ← 1. First           │   │ │ │ │
│ │ │ │ │ └─ Installer.xpc     ← 1. First           │   │ │ │ │
│ │ │ │ │                                           │   │ │ │ │
│ │ │ │ │ Updater.app          ← 2. Second          │   │ │ │ │
│ │ │ │ │ Autoupdate           ← 2. Second          │   │ │ │ │
│ │ │ │ └───────────────────────────────────────────┘   │ │ │ │
│ │ │ └─────────────────────────────────────────────────┘ │ │ │
│ │ │                                                     │ │ │
│ │ │ ┌─────────────────────────────────────────────────┐ │ │ │
│ │ │ │ Sentry.framework                ← 3. Third      │ │ │ │
│ │ │ └─────────────────────────────────────────────────┘ │ │ │
│ │ └─────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

Why this order matters:
• If you sign a parent before its children, the parent signature
  becomes invalid when you sign the children
• Inside-out ensures each layer is signed before the next layer
  wraps it
• The outermost signature (main app) validates all inner signatures
```

---

## 🧹 Extended Attribute Cleanup Process

```
Phase 1: After Build
├─ xattr -cr (recursive clear)
├─ find + xattr -c (file-by-file)
├─ find + xattr -d com.apple.provenance (specific attribute)
└─ find + delete ._* files (AppleDouble)

Phase 2: Before Signing
├─ ditto --noextattr (clean copy)
├─ xattr -cr (again)
└─ Verify: count attributes (should be 0)

Phase 3: Before ZIP
├─ Final xattr -cr pass
├─ Final ._* cleanup
└─ Verify: count attributes (should be 0)

ZIP Creation:
└─ ditto -c -k --noextattr --norsrc
   (Creates ZIP without any attributes or resource forks)
```

---

## 📁 Directory Structure Evolution

```
BEFORE (Source)                DURING (Build)              AFTER (Distribution)
───────────────                ──────────────              ────────────────────

Clnbrd/                        /tmp/clnbrd-**/             Distribution-Clean/
├─ Clnbrd.xcodeproj            ├─ DerivedData/             ├─ App/
├─ Clnbrd/                     │  └─ Build/                │  └─ Clnbrd.app/
│  ├─ *.swift                  │     └─ Release/           │     └─ [Signed ✅]
│  ├─ Info.plist               │        └─ Clnbrd.app/     ├─ Upload/
│  └─ *.entitlements           │           [Unsigned]      │  └─ Clnbrd-*.zip
└─ Frameworks/                 │                           │     [Clean ✅]
                               └─ Clnbrd.app/              ├─ DMG/
                                  [Cleaning & Signing]     │  └─ Clnbrd-*.dmg
                                                           │     [Notarized ✅]
                                                           └─ Logs/
                                                              ├─ build.log
                                                              └─ clean.log
```

---

## 🎯 Decision Tree: What to Do If...

```
Did build complete successfully?
├─ YES → Did you see "All extended attributes removed"?
│        ├─ YES → Did signature verification pass?
│        │        ├─ YES → ✅ Ready to notarize!
│        │        └─ NO → ❌ Check signing identity
│        └─ NO → ❌ Check build log for errors
└─ NO → Did you see "Archive failed"?
         ├─ YES → Check Logs/archive.log
         └─ NO → Did you see "Export failed"?
                  ├─ YES → Check ExportOptions.plist
                  └─ NO → Check build.log for details

Did notarization succeed?
├─ YES → Did stapling succeed?
│        ├─ YES → ✅ Create DMG and distribute!
│        └─ NO → ❌ Check internet connection
│                 Wait 5 mins and retry
└─ NO → Get log: xcrun notarytool log <ID>
         ├─ "Invalid signature" → Rebuild from scratch
         ├─ "Missing entitlement" → Check .entitlements file
         ├─ "Unsigned component" → Check all frameworks signed
         └─ Other issues → Review log.json details
```

---

## 🔍 Verification Checkpoints

### ✅ After Build (Step 1)

```
Check #1: Extended Attributes
─────────────────────────────
Command: find Distribution-Clean/App/Clnbrd.app -exec xattr -l {} \;
Expected: (empty output or only blank lines)
If fails: Re-run build script

Check #2: Code Signature
────────────────────────
Command: codesign --verify --deep Distribution-Clean/App/Clnbrd.app
Expected: (no output = success)
If fails: Check signing identity

Check #3: Signature Details
───────────────────────────
Command: codesign -dvvv Distribution-Clean/App/Clnbrd.app
Expected: See "Authority=Developer ID Application: Allan Alomes"
If fails: Wrong identity was used

Check #4: ZIP Cleanliness
─────────────────────────
Command: unzip -l Distribution-Clean/Upload/*.zip | grep "\._"
Expected: (no matches)
If fails: ZIP has AppleDouble files, rebuild
```

### ✅ After Notarization (Step 2)

```
Check #5: Notarization Status
─────────────────────────────
Command: xcrun notarytool history ...
Expected: Most recent submission shows "Accepted"
If fails: Get log with: xcrun notarytool log <ID> ...
```

### ✅ After Finalization (Step 3)

```
Check #6: Staple Validation
───────────────────────────
Command: xcrun stapler validate Distribution-Clean/App/Clnbrd.app
Expected: "The validate action worked"
If fails: Notarization may not have completed, wait and retry

Check #7: Gatekeeper Assessment
───────────────────────────────
Command: spctl -a -vvv -t install Distribution-Clean/App/Clnbrd.app
Expected: "accepted source=Notarized Developer ID"
If fails: Stapling failed, retry finalize script

Check #8: DMG Verification
──────────────────────────
Command: hdiutil verify Distribution-Clean/DMG/*.dmg
Expected: "verified"
If fails: DMG corrupted, re-run finalize script
```

---

## 🎓 Understanding the Three Key Concepts

### 1. Extended Attributes (xattr)

```
What they are:
• Metadata attached to files (like tags, comments, etc.)
• Invisible in normal file listings
• Can interfere with code signing

Why com.apple.provenance is problematic:
• Added automatically by macOS Sequoia during exportArchive
• System-protected (can't be removed normally)
• Conflicts with code signature validation
• Causes notarization to fail

How we fix it:
• Avoid the process that adds it (exportArchive)
• Use direct build instead
• Multiple cleanup passes to ensure none remain
```

### 2. Code Signing Order

```
Why order matters:
• Signatures are nested (like Russian dolls)
• Inner signatures must exist before outer signatures
• Signing a parent invalidates if you later sign a child

Correct order (inside-out):
1. Deepest components (XPC services)
2. Middle components (frameworks)
3. Outer component (main app)

Wrong order (outside-in):
1. Main app ← This signature becomes invalid...
2. Frameworks ← ...when these are signed
3. XPC services ← ...and these are signed
❌ Result: Invalid signature!
```

### 3. Notarization vs Stapling

```
Notarization:
• Upload app to Apple
• Apple scans and validates
• Apple stores notarization ticket on their servers
• Ticket is linked to app's code signature

Stapling:
• Download the notarization ticket from Apple
• Attach (staple) it to your app bundle
• Now app works even without internet
• Users don't see Gatekeeper warnings

Why both are needed:
• Notarization = Apple's approval
• Stapling = Offline proof of approval
```

---

## 🚀 Quick Command Cheat Sheet

```bash
# Build
./build_notarization_fixed.sh

# Notarize (store credentials first time)
xcrun notarytool store-credentials "CLNBRD" \
  --apple-id olivedesignstudios@gmail.com \
  --team-id 58Y8VPZ7JG

# Notarize (submit)
xcrun notarytool submit Distribution-Clean/Upload/*.zip \
  --keychain-profile "CLNBRD" \
  --wait

# Finalize
./finalize_notarized_clean.sh

# Verify everything
codesign --verify --deep Distribution-Clean/App/Clnbrd.app
spctl -a -vvv -t install Distribution-Clean/App/Clnbrd.app
hdiutil verify Distribution-Clean/DMG/*.dmg
```

---

**Ready to start? Run: `./build_notarization_fixed.sh`** 🚀

