# 🔧 Onboarding Fixes V2 - Permission Checking & Navigation

## Issues Fixed

### 1. ❌ Permissions Not Properly Checked
**Problem:** Both Accessibility and Input Monitoring were checking the same thing (`AXIsProcessTrusted()`), causing false positives.

**Fix:** Implemented proper Input Monitoring check using IOKit:
```swift
var hasGrantedInputMonitoring: Bool {
    let accessGranted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
    return accessGranted == kIOHIDAccessTypeGranted
}
```

Now properly distinguishes between:
- **Accessibility**: `AXIsProcessTrusted()`
- **Input Monitoring**: `IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)`

---

### 2. ❌ No Back Button
**Problem:** Users couldn't go back if they wanted to review previous screens.

**Fix:** Added back buttons to all screens:
- **Permissions Screen**: "← Back" → Returns to Welcome
- **Quick Start Screen**: "← Back" → Returns to Permissions

---

### 3. ⚠️ Auto-Advance Too Fast / No Manual Control
**Problem:** Users had no control - it either auto-advanced or they were stuck.

**Fix:** Added "Continue" button to Permissions screen:
- Disabled until BOTH permissions are granted
- Becomes the default button (Enter key) when enabled
- Auto-advance still works after 3 seconds, but users can click Continue immediately
- Shows clear visual feedback

---

## What Changed

### Files Modified:

#### 1. **OnboardingManager.swift**
```swift
// Added IOKit import
import IOKit.hid

// Fixed Input Monitoring check
var hasGrantedInputMonitoring: Bool {
    let accessGranted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
    logger.info("Input Monitoring access status: \(accessGranted)")
    return accessGranted == kIOHIDAccessTypeGranted
}
```

#### 2. **OnboardingWindow.swift**

**Added Back Buttons:**
```swift
// Permissions Screen
let backButton = NSButton(frame: NSRect(x: 40, y: 40, width: 100, height: 40))
backButton.title = "← Back"
backButton.action = #selector(backToWelcome)

// Quick Start Screen
let backButton = NSButton(frame: NSRect(x: 40, y: 55, width: 100, height: 36))
backButton.title = "← Back"
backButton.action = #selector(backToPermissions)
```

**Added Continue Button:**
```swift
let continueButton = NSButton(frame: NSRect(x: windowWidth - 140, y: 40, width: 100, height: 40))
continueButton.title = "Continue"
continueButton.identifier = NSUserInterfaceItemIdentifier("continueButton")
continueButton.isEnabled = false  // Disabled until permissions granted
continueButton.action = #selector(continueToQuickStart)
```

**Enhanced Permission Monitoring:**
```swift
// Logs every check
logger.info("Permission check - Accessibility: \(hasAccessibility), Input Monitoring: \(hasInputMonitoring)")

// Enables Continue button when both granted
if let continueButton = findViewByIdentifier("continueButton", in: permissionsView) as? NSButton {
    let bothGranted = hasAccessibility && hasInputMonitoring
    continueButton.isEnabled = bothGranted
    if bothGranted {
        continueButton.keyEquivalent = "\r"  // Make it default
    }
}
```

**Auto-Advance Improvements:**
- Increased delay: 2s → 3s
- Only advances if still on permissions screen
- Better logging

---

## New UI Layout

### Permissions Screen
```
┌─────────────────────────────────────────────────────┐
│            Required Permissions                     │
│                                                     │
│  ┌────────────────────────────────────────────┐    │
│  │ 1️⃣ Accessibility              ⭕/✅      │    │
│  │ 2️⃣ Input Monitoring           ⭕/✅      │    │
│  └────────────────────────────────────────────┘    │
│                                                     │
│  [← Back]  [Open System Settings]  [Continue]      │
│                                        ^disabled    │
│                                                     │
│  ✅ All permissions granted! (when both checked)   │
│     Moving to next step...                         │
└─────────────────────────────────────────────────────┘
```

**Button States:**
- **Back**: Always enabled
- **Open System Settings**: Always enabled (default button initially)
- **Continue**: Disabled → Enabled when both ✅ (becomes default button)

---

### Quick Start Screen
```
┌─────────────────────────────────────────────────────┐
│              You're All Set!                        │
│                                                     │
│                  ⌘ ⇧ V                              │
│                                                     │
│  [← Back]      [Try It Now]      [Done]            │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## Permission Checking Flow

### Fresh User (No Permissions)
```
1. User clicks "Get Started"
   → Permissions screen loads
   
2. Permission check runs every 0.5s:
   Accessibility: false ⭕
   Input Monitoring: false ⭕
   Continue button: DISABLED
   
3. User clicks "Open System Settings"
   → System Settings opens
   
4. User grants Accessibility
   → Accessibility: true ✅
   → Input Monitoring: false ⭕
   → Continue button: STILL DISABLED
   
5. User grants Input Monitoring
   → Accessibility: true ✅
   → Input Monitoring: true ✅
   → Continue button: ENABLED (becomes default)
   → Success message appears
   → Auto-advance in 3 seconds (or user clicks Continue)
```

### Returning User (Already Granted)
```
1. User clicks "Show Welcome Screen"
   → Welcome screen appears
   
2. User clicks "Get Started"
   → Permissions screen loads
   
3. Permission check runs immediately:
   Accessibility: true ✅
   Input Monitoring: true ✅
   Continue button: ENABLED (default)
   Success message appears
   
4. User can either:
   - Wait 3 seconds (auto-advance)
   - Click Continue immediately (faster)
   - Click Back (review welcome)
```

---

## Console Logs (for Debugging)

When permissions screen loads:
```
Showing screen: permissions
Permission check - Accessibility: false, Input Monitoring: false
Input Monitoring access status: 1  (1 = denied, 0 = granted, 2 = unknown)
Permission check - Accessibility: false, Input Monitoring: false
```

When first permission granted:
```
Permission check - Accessibility: true, Input Monitoring: false
Input Monitoring access status: 1
```

When both permissions granted:
```
Permission check - Accessibility: true, Input Monitoring: true
Input Monitoring access status: 0
✅ Both permissions granted, will auto-advance in 3 seconds
```

When user clicks Continue:
```
Continue button clicked, moving to Quick Start
Showing screen: quickStart
```

---

## Testing Checklist

### Test 1: Fresh Install (No Permissions)
- [ ] Welcome screen appears
- [ ] Click "Get Started"
- [ ] Permissions screen shows ⭕ ⭕
- [ ] Continue button is DISABLED and grayed out
- [ ] Click "Open System Settings"
- [ ] Grant Accessibility → First ✅ appears
- [ ] Continue button still DISABLED
- [ ] Grant Input Monitoring → Second ✅ appears
- [ ] Continue button ENABLES
- [ ] Success message appears
- [ ] Can click Continue OR wait for auto-advance
- [ ] Moves to Quick Start

### Test 2: Permissions Already Granted
- [ ] Click "Show Welcome Screen" from menu
- [ ] Welcome screen appears
- [ ] Click "Get Started"
- [ ] Permissions screen shows ✅ ✅ immediately
- [ ] Continue button is ENABLED
- [ ] Success message visible
- [ ] Can click Continue immediately (don't have to wait)

### Test 3: Back Button Navigation
- [ ] On Permissions screen, click "← Back"
- [ ] Returns to Welcome screen
- [ ] Click "Get Started" again
- [ ] Back on Permissions screen
- [ ] Grant permissions and click Continue
- [ ] On Quick Start screen
- [ ] Click "← Back"
- [ ] Returns to Permissions screen
- [ ] Click Continue
- [ ] Back to Quick Start

### Test 4: Input Monitoring Check
- [ ] System Settings → Privacy & Security → Input Monitoring
- [ ] Remove Clnbrd from list
- [ ] Relaunch app and open onboarding
- [ ] Permissions screen shows: ✅ ⭕ (Accessibility yes, Input Monitoring no)
- [ ] Continue button DISABLED
- [ ] Re-grant Input Monitoring
- [ ] Both become ✅
- [ ] Continue button ENABLES

---

## IOKit Access Types

For reference:
```swift
kIOHIDAccessTypeGranted = 0    // ✅ Permission granted
kIOHIDAccessTypeDenied = 1     // ❌ Permission denied
kIOHIDAccessTypeUnknown = 2    // ⚠️ Not determined yet
```

---

## Key Improvements Summary

| Issue | Before | After |
|-------|--------|-------|
| **Input Monitoring Check** | Used AXIsProcessTrusted (wrong!) | Uses IOHIDCheckAccess (correct!) |
| **Navigation** | No way to go back | Back buttons on all screens |
| **User Control** | Only auto-advance or stuck | Continue button + auto-advance |
| **Feedback** | Silent checking | Logs every check to Console |
| **UX** | Confusing/fast | Clear states, controlled pacing |

---

## Status: ✅ Ready to Test!

All changes implemented and linted. Should now:
1. ✅ Properly check BOTH permissions independently
2. ✅ Allow navigation backwards
3. ✅ Give users control via Continue button
4. ✅ Provide clear visual feedback
5. ✅ Log everything for debugging


