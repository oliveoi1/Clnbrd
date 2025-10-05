# Post-Update Authorization Guide for Clnbrd

## 🔐 **What Happens After Updates**

### **Permissions That Usually Persist:**
- ✅ **User Preferences** - All your settings are preserved
- ✅ **Analytics Data** - Usage statistics are maintained
- ✅ **Cleaning Rules** - Your custom rules stay intact
- ✅ **Menu Bar Position** - App remembers where it was placed

### **Permissions That May Need Re-authorization:**
- ⚠️ **Accessibility Permissions** - Sometimes reset after updates
- ⚠️ **Notification Permissions** - Occasionally need re-granting
- ⚠️ **Hotkey Registration** - May need to be re-registered

## 🚀 **Enhanced Post-Update Experience**

Your app now automatically detects post-update scenarios and handles them gracefully:

### **1. Automatic Detection**
- Tracks the last known version
- Compares with current version on launch
- Identifies when an update has occurred

### **2. Smart Permission Handling**
- **Accessibility**: Shows post-update specific message if permissions are lost
- **Notifications**: Automatically re-requests if needed
- **User-friendly**: Explains why permissions might need re-granting

### **3. User-Friendly Messages**
- **Post-update welcome**: "Clnbrd Updated Successfully!"
- **Permission explanation**: Why re-authorization might be needed
- **Clear instructions**: Step-by-step guidance

## 📱 **User Experience After Updates**

### **Scenario 1: Permissions Preserved**
```
✅ App launches normally
✅ All features work immediately
✅ Brief "Updated Successfully!" message
✅ User continues seamlessly
```

### **Scenario 2: Accessibility Permission Lost**
```
⚠️ App detects missing accessibility permission
📱 Shows post-update specific message:
   "After updating Clnbrd, accessibility permissions may need to be re-granted"
🔧 Provides clear instructions
⚡ User re-grants permission once
✅ Everything works normally
```

### **Scenario 3: Notification Permission Lost**
```
📱 App automatically detects missing notification permission
🔄 Silently re-requests permission
✅ User gets update notifications again
```

## 🛠️ **Technical Implementation**

### **Version Tracking**
```swift
// Stores last known version
UserDefaults.standard.set(currentVersion, forKey: "LastKnownVersion")

// Detects post-update scenario
let isPostUpdate = lastKnownVersion != nil && lastKnownVersion != currentVersion
```

### **Permission Checking**
```swift
// Checks accessibility permissions
let trusted = AXIsProcessTrusted()

// Checks notification permissions
UNUserNotificationCenter.current().getNotificationSettings { settings in
    if settings.authorizationStatus == .notDetermined {
        // Re-request permissions
    }
}
```

### **Smart Messaging**
- **First-time users**: Standard permission request
- **Post-update users**: Explains why re-authorization is needed
- **Reassuring**: "Your settings are preserved"

## 🎯 **Best Practices for Users**

### **After Installing an Update:**
1. **Launch the app** - It will automatically check permissions
2. **If prompted** - Re-grant accessibility permissions
3. **Check hotkeys** - Test ⌘⌥V to ensure it works
4. **Verify notifications** - Update notifications should work

### **If Something Doesn't Work:**
1. **Check System Settings** → Privacy & Security → Accessibility
2. **Ensure Clnbrd is enabled** in the accessibility list
3. **Restart the app** after granting permissions
4. **Contact support** if issues persist

## 📊 **Analytics Integration**

The system tracks:
- When post-update scenarios occur
- Permission re-granting success rates
- User experience after updates
- Common permission issues

## 🔧 **Developer Notes**

### **Why Permissions Reset:**
- **macOS Security Updates**: Apple sometimes resets permissions
- **App Bundle Changes**: New signatures can trigger permission resets
- **System Preferences**: User changes can affect permissions
- **Code Signing**: Different certificates can cause permission loss

### **Mitigation Strategies:**
- **Graceful Detection**: Automatically detect post-update scenarios
- **Clear Communication**: Explain why re-authorization is needed
- **Preserve Settings**: Keep all user preferences intact
- **Easy Recovery**: Provide direct links to system settings

## 🚀 **Future Enhancements**

Consider implementing:
- **Automatic Permission Recovery**: Try to re-grant permissions programmatically
- **Permission Status Dashboard**: Show current permission status in settings
- **Backup/Restore**: Save permission states for easier recovery
- **Smart Notifications**: Only show permission requests when actually needed

Your users will now have a much smoother experience after updates, with clear guidance when permissions need to be re-granted!
