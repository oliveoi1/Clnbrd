# 🐛 Debug Onboarding Window Issue

## Changes Made to Fix & Debug

### 1. **Enhanced Window Configuration**
Added critical NSPanel settings to ensure visibility:
```swift
self.becomesKeyOnlyIfNeeded = false  // Always become key when clicked
self.isFloatingPanel = true          // Stay floating
self.hidesOnDeactivate = false       // Don't auto-hide
```

### 2. **Extensive Logging Added**
Every step now logs to Console:
- MenuBarManager: When menu item clicked
- AppDelegate: When showWelcomeScreen() called
- OnboardingManager: Window creation and visibility status
- OnboardingWindow: Initialization

### 3. **Better Showing Logic**
- Create window FIRST, then activate app
- Multiple attempts to make window visible
- Double-check visibility and retry if needed

---

## How to Debug

### Step 1: Open Console.app
```
Applications → Utilities → Console.app
```

### Step 2: Filter for Clnbrd logs
In the search box, enter:
```
process:Clnbrd
```

Or filter by subsystem:
```
subsystem:com.allanalomes.Clnbrd
```

### Step 3: Click "Show Welcome Screen" in Menu

Watch for these log messages in order:

```
🎓 MenuBarManager.showWelcomeScreen() called
✅ Got AppDelegate, calling showWelcomeScreen()
📖 AppDelegate.showWelcomeScreen() called
📖 About to call OnboardingManager.shared.showOnboarding()
🎓 Showing onboarding window (canDismiss: true)
Creating new OnboardingWindow...
OnboardingWindow initialized
Window created, frame: ...
Window level: ...
Window isVisible: true/false  ← KEY LINE
After makeKeyAndOrderFront - isVisible: true/false
After orderFrontRegardless - isVisible: true/false
✅ Onboarding window shown. Final state - isVisible: true/false
```

### Step 4: Check the Key Line

**If you see `isVisible: false` at the end:**
The window is being created but not shown. Possible causes:
- Window level issue
- App activation policy
- NSPanel configuration

**If you see `isVisible: true`:**
The window IS showing, but maybe off-screen or behind other windows.

**If you DON'T see the logs at all:**
The menu action isn't connected properly.

---

## Expected Console Output (Working)

```
2024-01-15 10:30:45.123 🎓 MenuBarManager.showWelcomeScreen() called
2024-01-15 10:30:45.124 ✅ Got AppDelegate, calling showWelcomeScreen()
2024-01-15 10:30:45.125 📖 AppDelegate.showWelcomeScreen() called
2024-01-15 10:30:45.126 📖 About to call OnboardingManager.shared.showOnboarding()
2024-01-15 10:30:45.127 🎓 Showing onboarding window (canDismiss: true)
2024-01-15 10:30:45.128 Creating new OnboardingWindow...
2024-01-15 10:30:45.130 OnboardingWindow initialized
2024-01-15 10:30:45.131 Window created, frame: {{0, 0}, {600, 450}}
2024-01-15 10:30:45.132 Window level: 3
2024-01-15 10:30:45.133 Window isVisible: false
2024-01-15 10:30:45.134 Window centered at: {710, 390}
2024-01-15 10:30:45.135 After makeKeyAndOrderFront - isVisible: true, isKeyWindow: true
2024-01-15 10:30:45.136 After orderFrontRegardless - isVisible: true
2024-01-15 10:30:45.137 ✅ Onboarding window shown. Final state - isVisible: true, isKey: true
```

---

## What to Look For

### ✅ Good Signs
- All log messages appear
- `isVisible: true` at the end
- `isKeyWindow: true`
- Window level is `3` (floating)

### ⚠️ Warning Signs
- `isVisible: false` after all attempts
- `isKeyWindow: false`
- Missing log messages
- "Could not get AppDelegate" error

### ❌ Bad Signs  
- No logs at all → Menu action not connected
- Window level is `0` → Wrong configuration
- "Failed to create window" → Initialization error

---

## Alternative Test

### Test via Debug Menu
Instead of "Show Welcome Screen", try:
```
Menu Bar → 🔄 Reset Onboarding (Debug)
```

This shows an alert with a button that directly calls `showWelcomeScreen()`. 
If THIS works but the menu item doesn't, the issue is with the menu action.

---

## Nuclear Option: Change to NSWindow

If the panel still doesn't work, we can change from NSPanel to NSWindow:

**In OnboardingWindow.swift:**
```swift
// Change class declaration from:
class OnboardingWindow: NSPanel {

// To:
class OnboardingWindow: NSWindow {
```

This sacrifices some panel-specific features but guarantees visibility.

---

## Quick Fixes to Try

### Fix 1: Change Window Level
If window is behind others, try changing level:
```swift
self.level = .modalPanel  // Instead of .floating
```

### Fix 2: Remove Defer
Window is already `defer: false`, which is correct.

### Fix 3: Explicitly Show
Add at the end of `showOnboarding()`:
```swift
newWindow.display()
newWindow.makeKeyAndOrderFront(self)
```

---

## What I Changed

### OnboardingWindow.swift
- Added `becomesKeyOnlyIfNeeded = false`
- Added `isFloatingPanel = true`
- Added `hidesOnDeactivate = false`

### OnboardingManager.swift
- Created window BEFORE activating app
- Added 10+ log statements
- Added double-check logic
- Retry if visibility fails

### AppDelegate.swift
- Added detailed logging
- Track each step

### MenuBarManager.swift
- Added logging
- Check AppDelegate exists
- Log success/failure

---

## Next Steps

1. **Build and run the app**
2. **Open Console.app** and filter for Clnbrd
3. **Click "Show Welcome Screen"** from menu bar
4. **Check Console logs** - paste them back to me
5. **Look for the key visibility lines**

If you share the Console output, I can tell you exactly what's failing!

---

## Test Checklist

Try these in order and report which works:

- [ ] Menu Bar → "Show Welcome Screen" → Does window appear?
- [ ] Menu Bar → "🔄 Reset Onboarding (Debug)" → Alert → "Show Welcome Screen" → Does window appear?
- [ ] Relaunch app (should show on first launch) → Does window appear?
- [ ] Check Console.app → Do you see the log messages?
- [ ] Check Console.app → What does `isVisible:` say?

**Please share:**
1. Which tests worked/failed
2. Console.app output when you click the menu item
3. Any error messages

Then I can pinpoint the exact issue! 🔍


