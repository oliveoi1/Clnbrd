# 🔧 Onboarding Fixes - Auto-Advance & Visibility Issues

## Problems Reported
1. **Onboarding went through super fast and closed** - Auto-advancing too quickly
2. **Menu "Show Welcome Screen" didn't show window** - Window visibility issue

---

## Root Causes

### Issue 1: Too-Fast Auto-Advance
**Problem:** If permissions were already granted (which they were), the onboarding would:
1. Show welcome screen
2. User clicks "Get Started"
3. Show permissions screen
4. Immediately detect permissions granted (within 0.5s)
5. Auto-advance after 0.5s delay
6. **Total time on permissions screen: ~1 second**

Users didn't have time to see what was happening!

### Issue 2: Window Not Showing
**Problem:** Window might not have been properly activated or brought to front when triggered from menu.

---

## Fixes Applied

### Fix 1: Slower Auto-Advance with Visual Feedback

#### Changed Auto-Advance Timing
```swift
// Before: 0.5 second delay
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)

// After: 2.0 second delay
DispatchQueue.main.asyncAfter(deadline: .now() + 2.0)
```

#### Added Success Message
When both permissions are granted, now shows:
```
✅ All permissions granted! Moving to next step...
```
This appears in green text for 2 seconds before auto-advancing.

#### Prevents Multiple Auto-Advances
```swift
private var hasAutoAdvanced = false  // New flag

// Only auto-advance once
if hasAccessibility && hasInputMonitoring && !hasAutoAdvanced {
    hasAutoAdvanced = true
    // ... advance logic
}

// Reset flag when returning to permissions
if screen == .permissions {
    hasAutoAdvanced = false
}
```

---

### Fix 2: Improved Window Visibility

#### Better Window Management
```swift
// Before: Simple show
onboardingWindow?.makeKeyAndOrderFront(nil)

// After: Comprehensive showing
NSApp.activate(ignoringOtherApps: true)  // Bring app to front first
window.center()                           // Center on screen
window.makeKeyAndOrderFront(nil)         // Make key window
window.orderFrontRegardless()            // Force to front
```

#### Added Logging
```swift
logger.info("🎓 Showing onboarding window (canDismiss: \(canDismiss))")
logger.info("✅ Onboarding window created and shown")
```

Now you can see in Console.app if the window is being shown.

---

### Fix 3: Debug Helper (DEBUG builds only)

Added menu item: **"🔄 Reset Onboarding (Debug)"**

**What it does:**
1. Resets onboarding state (marks as not completed)
2. Shows alert with option to immediately show onboarding
3. **Only appears in DEBUG builds** (not in Release)

**How to use:**
```
Menu Bar → 🔄 Reset Onboarding (Debug)
  ↓
Alert appears
  ↓
Click "Show Welcome Screen" or "OK"
```

---

## Testing Guide

### Test Auto-Advance with Already-Granted Permissions

1. **Clean slate:**
   ```
   Menu Bar → 🔄 Reset Onboarding (Debug)
   → Click "Show Welcome Screen"
   ```

2. **Observe behavior:**
   - Welcome screen appears
   - Click "Get Started"
   - Permissions screen appears
   - Both permissions show ✅ (green checkmarks)
   - **"✅ All permissions granted! Moving to next step..."** appears
   - **Waits 2 seconds**
   - Auto-advances to Quick Start

3. **Expected time:** ~5 seconds total (not instant!)

---

### Test Manual Show from Menu

1. **Trigger manually:**
   ```
   Menu Bar → Show Welcome Screen
   ```

2. **Expected:**
   - App comes to front
   - Window appears centered
   - Can navigate through all screens
   - Can close anytime

3. **Check Console logs:**
   ```
   🎓 Showing onboarding window (canDismiss: true)
   ✅ Onboarding window created and shown
   Showing screen: welcome
   ```

---

### Test Without Pre-Granted Permissions

If you want to test the "fresh user" experience:

1. **Revoke permissions:**
   ```
   System Settings → Privacy & Security → Accessibility
   → Remove Clnbrd
   
   System Settings → Privacy & Security → Input Monitoring
   → Remove Clnbrd
   ```

2. **Reset onboarding:**
   ```
   Menu Bar → 🔄 Reset Onboarding (Debug)
   ```

3. **Relaunch app or show manually**

4. **Observe behavior:**
   - Welcome screen
   - Click "Get Started"
   - Permissions screen shows both ⭕ (not granted)
   - Click "Open System Settings"
   - Grant both permissions
   - Returns to app
   - Status updates to ✅ ✅
   - Success message appears
   - Auto-advances after 2 seconds

---

## Visual Flow (With Pre-Granted Permissions)

```
┌─────────────────────────────────────┐
│ SCREEN 1: WELCOME                   │
│ User sees: Welcome message          │
│ Duration: User controlled           │
│ Action: Click "Get Started"         │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│ SCREEN 2: PERMISSIONS               │
│ User sees:                          │
│   ✅ Accessibility [green]          │
│   ✅ Input Monitoring [green]       │
│                                     │
│ After 0.5s checking:                │
│   "✅ All permissions granted!      │
│    Moving to next step..."          │
│                                     │
│ Duration: 2 seconds                 │
│ Action: Auto-advance                │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│ SCREEN 3: QUICK START               │
│ User sees: Hotkey (⌘⇧V)            │
│ Duration: User controlled           │
│ Actions:                            │
│   - "Try It Now" → Opens history    │
│   - "Done" → Closes & marks complete│
└─────────────────────────────────────┘
```

---

## Technical Details

### Auto-Advance Logic
```swift
// Checks every 0.5 seconds while on permissions screen
Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
    self?.updatePermissionStatus()
}

// When both granted
if hasAccessibility && hasInputMonitoring && !hasAutoAdvanced {
    hasAutoAdvanced = true
    
    // Show success message
    successLabel.isHidden = false
    
    // Wait 2 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self?.showScreen(.quickStart)
    }
}
```

### Window Lifecycle
```swift
// OnboardingManager keeps strong reference
private var onboardingWindow: OnboardingWindow?

// Only one instance at a time
if let existingWindow = onboardingWindow {
    existingWindow.close()
    onboardingWindow = nil
}

// Create fresh instance
onboardingWindow = OnboardingWindow(canDismiss: true)
```

---

## Debug Menu (Development Only)

In DEBUG builds, menu shows:
```
Menu Bar
├── ...
├── Settings...
├── Show Welcome Screen
├── 🔄 Reset Onboarding (Debug)  ← NEW!
├── ────────────────────
└── Quit
```

**In Release builds:** Debug item does NOT appear.

**Implementation:**
```swift
#if DEBUG
let resetItem = NSMenuItem(title: "🔄 Reset Onboarding (Debug)", ...)
menu.addItem(resetItem)
#endif
```

---

## What Changed

### Files Modified:
- ✅ **OnboardingWindow.swift**
  - Added `hasAutoAdvanced` flag
  - Increased auto-advance delay (0.5s → 2.0s)
  - Added success message label
  - Reset flag when navigating to permissions

- ✅ **OnboardingManager.swift**
  - Enhanced `showOnboarding()` with better logging
  - Added `orderFrontRegardless()` for visibility
  - Activate app before showing window

- ✅ **MenuBarManager.swift**
  - Added DEBUG menu item "Reset Onboarding"
  - Added `resetOnboarding()` action method

---

## Expected Behavior Now

### First Launch (Permissions Already Granted)
```
1. App launches
2. After 0.5s, onboarding appears
3. Welcome screen (user controlled)
4. Permissions screen: 2 seconds with success message
5. Quick Start screen (user controlled)
6. Total minimum time: ~5 seconds
```

### Manual Trigger from Menu
```
1. User clicks "Show Welcome Screen"
2. App activates and comes to front
3. Window appears centered
4. Same flow as above
5. Can close anytime (not blocking)
```

### Fresh User (No Permissions)
```
1. Welcome screen
2. Permissions screen (shows ⭕ ⭕)
3. User clicks "Open System Settings"
4. User grants permissions
5. Returns to app
6. Status updates to ✅ ✅
7. Success message appears
8. Auto-advances after 2 seconds
9. Quick Start screen
```

---

## Performance Impact

**Minimal:**
- Permission checking: Every 0.5s while on permissions screen only
- Timer stops when leaving permissions screen
- Single window instance (no leaks)
- Lightweight check (`AXIsProcessTrusted()`)

---

## Success Criteria

✅ **Onboarding visible for reasonable time** (minimum 2s on permissions if granted)
✅ **Success message shows** when permissions granted
✅ **Menu item works** - window appears when clicked
✅ **Can be re-shown** anytime from menu
✅ **Debug helper works** for easy testing
✅ **No crashes or errors**
✅ **Proper window activation**

---

## Next Steps for Testing

1. **Build and run in DEBUG**
2. **Click "🔄 Reset Onboarding"**
3. **Click "Show Welcome Screen"**
4. **Observe:**
   - Welcome appears
   - Permissions shows for 2+ seconds with success message
   - Auto-advances smoothly
5. **Test menu item** works consistently
6. **Check Console logs** for confirmation

**Status: ✅ Ready to Test!**


