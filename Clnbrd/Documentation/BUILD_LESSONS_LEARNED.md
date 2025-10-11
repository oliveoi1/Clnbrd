# Build Process - Lessons Learned

## Critical Issues Resolved in Build 51-52

### Issue 1: Sparkle ZIP Created Before Stapling
**Problem:** The original `build_notarization_fixed.sh` created a ZIP for Sparkle BEFORE notarization was stapled. This meant the ZIP contained an app without the notarization ticket, causing installation failures.

**Solution:** Updated `finalize_notarized_clean.sh` to automatically create a stapled ZIP after notarization is complete.

**Files Changed:**
- `finalize_notarized_clean.sh` - Added Step 3 to create `*-notarized-stapled.zip`

### Issue 2: App Sandboxing Prevented Sparkle Auto-Updates
**Problem:** The app had `com.apple.security.app-sandbox` enabled in entitlements. Sandboxed apps cannot use Sparkle's XPC installer because they can't launch external processes.

**Symptoms:**
- Error: "An error occurred while launching the installer"
- Update downloads but fails to install
- Works for DMG manual installation but not auto-update

**Solution:** Removed app sandboxing from `Clnbrd.entitlements` and replaced with Hardened Runtime entitlements:
```xml
<key>com.apple.security.cs.allow-jit</key>
<true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
```

**Why This Is Acceptable:**
- Clnbrd already requires Accessibility and Input Monitoring permissions
- These permissions are incompatible with sandboxing anyway
- The app doesn't need sandbox protection for its use case
- Sparkle requires the ability to replace the app bundle

**Files Changed:**
- `Clnbrd/Clnbrd.entitlements` - Removed sandboxing, kept Hardened Runtime

### Issue 3: Build 50 Users Couldn't Auto-Update
**Problem:** Users running sandboxed Build 50 couldn't install ANY auto-updates (including Build 52) because the sandboxing restriction is on the RUNNING app, not the target.

**Solution:** Manual update required for Build 50 → Build 52 transition. After Build 52, all future auto-updates work correctly.

## Updated Build Process

### 1. Build & Sign
```bash
./build_notarization_fixed.sh
```
Creates:
- Signed app in `Distribution-Clean/App/`
- Pre-stapling ZIP in `Distribution-Clean/Upload/` (NOT for Sparkle!)

### 2. Notarize
```bash
xcrun notarytool submit "Distribution-Clean/Upload/Clnbrd-v1.3-Build52-clean.zip" \
  --keychain-profile "CLNBRD_NOTARIZATION" \
  --wait
```

### 3. Finalize (Staple + Create Sparkle ZIP + DMG)
```bash
./finalize_notarized_clean.sh
```
Now creates:
- Stapled app in `Distribution-Clean/App/`
- **NEW:** Stapled ZIP in `Distribution-Clean/Upload/*-notarized-stapled.zip` (FOR SPARKLE!)
- DMG in `Distribution-Clean/DMG/`

### 4. Upload to GitHub
Upload BOTH files:
- DMG: For manual downloads from website/GitHub
- Stapled ZIP: For Sparkle auto-updates

### 5. Update appcast-v2.xml
Use the **stapled ZIP** URL and byte size from finalize output.

## Checklist for Future Builds

- [ ] Run `build_notarization_fixed.sh`
- [ ] Submit ZIP for notarization
- [ ] Wait for "Accepted" status
- [ ] Run `finalize_notarized_clean.sh`
- [ ] **Verify stapled ZIP was created** in `Distribution-Clean/Upload/`
- [ ] Upload BOTH DMG and stapled ZIP to GitHub
- [ ] Update `appcast-v2.xml` with **stapled ZIP** URL
- [ ] Update `Info.plist` build number for next build
- [ ] **NEVER re-enable app sandboxing** (breaks Sparkle)

## Key Takeaways

1. **Always use the stapled ZIP for Sparkle**, not the pre-stapling one
2. **Never enable app sandboxing** if using Sparkle auto-updates
3. **Test auto-updates** from previous builds before releasing
4. **Manual update required** when fixing sandboxing issues (one-time transition)

## Files That Must Stay Correct

### Clnbrd.entitlements
```xml
<!-- ✅ CORRECT - No sandboxing, Hardened Runtime only -->
<key>com.apple.security.cs.allow-jit</key>
<true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
```

### appcast-v2.xml
```xml
<!-- ✅ CORRECT - Points to stapled ZIP -->
<enclosure 
    url="https://github.com/oliveoi1/Clnbrd/releases/download/v1.3.52/Clnbrd-v1.3-Build52-notarized-stapled.zip" 
    length="1918004"
    type="application/octet-stream"
/>
```

## References
- Build 50: Had sandboxing (auto-update broken)
- Build 51: No sandboxing but ZIP wasn't stapled (installer error)
- Build 52: No sandboxing + stapled ZIP (working correctly)

