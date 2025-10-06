# Clnbrd Quick Reference Card

## 🚀 **Quick Start**

### **Open Project:**
```bash
cd /Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd
open Clnbrd.xcodeproj
```

### **Build & Run:**
- **Xcode**: ⌘+R (Product → Run)
- **Command Line**: `xcodebuild -project Clnbrd.xcodeproj -scheme Clnbrd -configuration Release build`

### **Create Distribution:**
```bash
./build_distribution.sh
```

---

## 📁 **Key Files**

| File | Purpose |
|------|---------|
| `Clnbrd.xcodeproj` | **Main Xcode project** |
| `Clnbrd/AppDelegate.swift` | Main app logic + Version History |
| `Clnbrd/MenuBarManager.swift` | Menu bar + hotkey handling |
| `build_distribution.sh` | **Main build script** |
| `Distribution/DMG/Clnbrd-1.3.dmg` | **Ready-to-share installer** |

---

## 🎯 **Current Status**

- **Version**: 1.3 (Build 3)
- **Status**: ✅ Production Ready
- **DMG Size**: 1.4MB
- **Features**: All working (12 rules + Version History)

---

## 🔧 **Quick Commands**

```bash
# Build distribution package
./build_distribution.sh

# Check git status
git status

# Commit changes
git add . && git commit -m "Description"

# Open project in Xcode
open Clnbrd.xcodeproj
```

---

## 📦 **Distribution**

**Ready to Share**: `Distribution/DMG/Clnbrd-1.3.dmg`

**Features**:
- Drag-to-Applications interface
- Installation instructions included
- Professional layout
- All features working

---

## 🆘 **Quick Fixes**

- **Hotkey not working**: Grant accessibility permissions in System Settings
- **Build errors**: Clean build folder (⌘+Shift+K) in Xcode
- **DMG issues**: Run `./build_distribution.sh` to recreate

---

*Location: `/Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd/`*  
*Main File: `Clnbrd.xcodeproj`*
