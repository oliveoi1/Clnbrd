# Notarization Instructions for Beta 1.4.0-beta.2 Build 55

## Current Status ✅
- ✅ Version bumped to 1.4.0-beta.2 Build 55
- ✅ App built and signed successfully
- ✅ ZIP created for notarization: `Distribution-Clean/Upload/Clnbrd-v1.4.0-beta.2-Build55-clean.zip`
- ⏳ **NEXT STEP:** Submit for notarization

---

## Option 1: One-Time Keychain Setup (RECOMMENDED)

This is the easiest method going forward. You'll only need to do this once:

```bash
./setup_notarization.sh
```

This will prompt you for:
- Apple ID: `olivedesignstudios@gmail.com` (pre-filled)
- Team ID: `58Y8VPZ7JG` (pre-filled)
- App-Specific Password: You'll need to provide this

**Don't have an App-Specific Password?**
1. Go to https://appleid.apple.com/account/manage
2. Sign-In and Security → App-Specific Passwords
3. Generate new password (name it "Clnbrd Notarization")
4. Copy the password (you can't view it again!)
5. Use it in the setup script

**After setup, submit for notarization:**
```bash
xcrun notarytool submit "Distribution-Clean/Upload/Clnbrd-v1.4.0-beta.2-Build55-clean.zip" \
  --keychain-profile "CLNBRD_NOTARIZATION" \
  --wait
```

---

## Option 2: Manual Submission with Password

If you prefer not to store credentials in keychain, run this command and enter your app-specific password when prompted:

```bash
xcrun notarytool submit "Distribution-Clean/Upload/Clnbrd-v1.4.0-beta.2-Build55-clean.zip" \
  --apple-id "olivedesignstudios@gmail.com" \
  --team-id "58Y8VPZ7JG" \
  --password "YOUR-APP-SPECIFIC-PASSWORD-HERE" \
  --wait
```

Replace `YOUR-APP-SPECIFIC-PASSWORD-HERE` with your actual app-specific password.

---

## After Notarization Succeeds

Once you see "**Successfully received submission info**" and "**status: Accepted**", run:

```bash
./finalize_notarized_clean.sh
```

This will:
1. Staple the notarization ticket to the app
2. Create the stapled ZIP for Sparkle auto-updates
3. Create the DMG for manual distribution
4. Verify everything

---

## Then: Upload to GitHub

After finalization completes, you'll have:
- `Distribution-Clean/DMG/Clnbrd-1.4.0-beta.2-Build-55-Notarized.dmg`
- `Distribution-Clean/Upload/Clnbrd-v1.4.0-beta.2-Build55-notarized-stapled.zip`

Upload BOTH files to GitHub:

```bash
gh release create v1.4.0-beta.2 \
  "Distribution-Clean/DMG/Clnbrd-1.4.0-beta.2-Build-55-Notarized.dmg" \
  "Distribution-Clean/Upload/Clnbrd-v1.4.0-beta.2-Build55-notarized-stapled.zip" \
  --title "Clnbrd 1.4.0-beta.2" \
  --notes "## Clnbrd 1.4.0-beta.2 Beta

### What's New in This Beta

- **UI Improvements**: Settings window now follows Apple HIG more closely
  - More compact layout (16px edges, 12px spacing)
  - Consistent SF Pro Rounded headers (15pt semibold)
  - Optimized hotkey section (28px rows, tighter spacing)
  - Smaller table views and controls
- Enhanced keyboard shortcuts section with better visual hierarchy
- Improved overall aesthetics and space efficiency

### Installation

**For Manual Installation:**
Download the DMG file and drag Clnbrd to your Applications folder.

**For Auto-Update:**
If you have a previous version, your app will automatically update.

### Beta Testing
This is a beta release. Please report any issues on GitHub or via email at olivedesignstudios@gmail.com.

---
**Note:** This is a pre-release beta version. Feedback is appreciated!" \
  --prerelease
```

---

## Quick Reference - Full Process

1. ✅ **Build** - Already done!
2. **Notarize** - Choose Option 1 or 2 above
3. **Finalize** - Run `./finalize_notarized_clean.sh`
4. **Upload** - Run `gh release create` command above
5. **Update Appcast** - Update `appcast-v2.xml` with new version info

---

## Key Lessons from Previous Builds

- ✅ Always use the **stapled ZIP** for Sparkle auto-updates
- ✅ Upload BOTH DMG and stapled ZIP to GitHub
- ✅ Never re-enable app sandboxing (breaks Sparkle)
- ✅ Build numbers must increment for each beta
- ✅ Use `--prerelease` flag for beta releases

---

## Need Help?

If notarization fails, get the detailed log:
```bash
xcrun notarytool history \
  --keychain-profile "CLNBRD_NOTARIZATION"
```

Then get the submission ID and view the log:
```bash
xcrun notarytool log <SUBMISSION_ID> \
  --keychain-profile "CLNBRD_NOTARIZATION" \
  error.json
```

