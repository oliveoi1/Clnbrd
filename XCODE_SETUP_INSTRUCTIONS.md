# Xcode Setup Instructions - URL Tracking Feature

## Quick Setup (5 minutes)

### Step 1: Add New Files to Xcode Project

Xcode should be open now. If not, open it:
```bash
cd /Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd
open Clnbrd.xcodeproj
```

**Add these 3 files to your Xcode project:**

1. In Xcode, **right-click** on the **"Clnbrd"** folder (the one with the blue icon)
2. Select **"Add Files to 'Clnbrd'..."**
3. Navigate to: `/Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd/Clnbrd/`
4. **Select these files** (hold ⌘ to multi-select):
   - `URLTrackingCleaner.swift`
   - `CleaningRuleConfiguration.swift`
   - `URLTrackingCleanerTests.swift` (optional, for manual testing)

5. Make sure these options are checked:
   - ✅ **"Copy items if needed"** (leave unchecked, they're already in place)
   - ✅ **"Create groups"** (selected)
   - ✅ **"Add to targets: Clnbrd"** (checked)

6. Click **"Add"**

### Step 2: Build the Project

1. Press **⌘B** (Command+B) to build
2. Wait for compilation to finish
3. Check for any errors in the Issue Navigator (⌘1)

### Step 3: Run and See the Test!

1. Press **⌘R** (Command+R) to run the app
2. **Immediately check the console** (⌘⇧Y to show it)
3. You should see output like this:

```
============================================================
🧪 URL TRACKING CLEANER TEST
============================================================

✅ YouTube
   Input:  https://youtu.be/dQw4w9WgXcQ?si=ABC123tracking
   Output: https://youtu.be/dQw4w9WgXcQ

✅ Amazon
   Input:  https://www.amazon.com/product/B08N5WRWNW/ref=sr_1_1?crid=ABC&sr=8-1
   Output: https://www.amazon.com/product/B08N5WRWNW

✅ Spotify
   Input:  https://open.spotify.com/track/3n3Ppam7vgaVa1iaRUc9Lp?si=abc123
   Output: https://open.spotify.com/track/3n3Ppam7vgaVa1iaRUc9Lp

✅ Google
   Input:  https://www.google.com/search?q=test&gs_lcrp=abc&ved=123
   Output: https://www.google.com/search?q=test

✅ Instagram
   Input:  https://www.instagram.com/p/ABC123/?igsh=xyz789
   Output: https://www.instagram.com/p/ABC123/

✅ Twitter
   Input:  https://x.com/user/status/123?s=20&t=abc123
   Output: https://x.com/user/status/123

✅ UTM Tracking
   Input:  https://example.com/?utm_source=twitter&utm_campaign=spring&fbclid=123
   Output: https://example.com/

✅ Multiple URLs in Text
   Cleaned successfully!

============================================================
RESULTS: 8 passed, 0 failed
============================================================
```

## Troubleshooting

### If Build Fails

**Error: "Cannot find 'URLTrackingCleaner' in scope"**
- Make sure you added the files to the project correctly
- Check the file is in the **"Clnbrd" target** (select file → File Inspector → Target Membership)

**Error: String multiplication not supported**
- This is expected - I used Python-style string repetition
- Just replace `"="*60` with `String(repeating: "=", count: 60)` in AppDelegate.swift

### If Console Doesn't Show

1. Make sure Console is visible: **View → Debug Area → Show Debug Area** (⌘⇧Y)
2. Or **View → Debug Area → Activate Console** (⌘⇧C)

### Can't See Full Output

The test runs on app launch and prints to console immediately. If you miss it:
1. Stop the app (⌘.)
2. Clear console (**right-click → Clear Console**)
3. Run again (⌘R)
4. Watch console output

## Next Steps After Test Works

Once you see the tests passing:

### 1. Remove the Test Call (Optional)
In `AppDelegate.swift`, comment out or remove line 204:
```swift
// testURLCleaning()  // Comment this out after testing
```

### 2. Integrate with ClipboardManager
See `INTEGRATION_GUIDE.md` for step-by-step integration

### 3. Test Manually
1. Copy a YouTube URL with tracking: `https://youtu.be/VIDEO?si=tracking123`
2. Use your cleaning hotkey (⌘⌥V)
3. See it paste without the `?si=` part!

## File Locations

If you need to find the files:
```
/Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd/Clnbrd/
├── URLTrackingCleaner.swift          ← Core URL cleaning engine
├── CleaningRuleConfiguration.swift   ← Preference system
└── URLTrackingCleanerTests.swift     ← Test suite
```

## Quick Reference

**View Console:** ⌘⇧Y  
**Build:** ⌘B  
**Run:** ⌘R  
**Stop:** ⌘.  
**Clean Build Folder:** ⌘⇧K  

---

**Need Help?** Check the console output for errors, or look at the detailed documentation in:
- `Documentation/URL_TRACKING_REMOVAL_FEATURE.md`
- `Documentation/PREFERENCES_UI_DESIGN.md`

