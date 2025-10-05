# DMG Archiving & Build Numbering System

**Status**: ✅ **IMPLEMENTED & WORKING**

---

## 🎯 Overview

Your build system now automatically:
1. ✅ **Archives old DMGs** before creating new ones
2. ✅ **Includes build number** in DMG filenames
3. ✅ **Organizes files** in a clean directory structure
4. ✅ **Timestamps archived DMGs** for reference

---

## 📦 DMG Naming Convention

### New Format:
```
Clnbrd-1.3-12.dmg   (Version 1.3, Build 12)
Clnbrd-1.3-13.dmg   (Version 1.3, Build 13)
Clnbrd-1.3-14.dmg   (Version 1.3, Build 14)
```

### Old Format (Archived):
```
Clnbrd-1.3-14_archived_20251004_100542.dmg
```

---

## 📁 Directory Structure

```
Distribution/
├── DMG/
│   └── Clnbrd-1.3-15.dmg  ← Current build (ready to share)
│
├── Archive/
│   └── Previous_Builds/
│       ├── Clnbrd-1.3-12_archived_20251004_095530.dmg
│       ├── Clnbrd-1.3-13_archived_20251004_095845.dmg
│       └── Clnbrd-1.3-14_archived_20251004_100542.dmg
│
├── App/
│   └── Clnbrd.app
│
├── Logs/
│   ├── archive.log
│   └── export.log
│
└── Distribution-Info.txt
```

---

## 🔄 How It Works

### 1. Build Number Increments
```bash
./build_distribution.sh
```
- Increments: Build 14 → Build 15
- Updates: Info.plist, VersionManager.swift, Xcode project

### 2. Archive Previous DMG
- If `Clnbrd-1.3-14.dmg` exists in `Distribution/DMG/`
- Moves to: `Distribution/Archive/Previous_Builds/`
- Renames to: `Clnbrd-1.3-14_archived_20251004_100542.dmg`
- Timestamp format: `YYYYMMDD_HHMMSS`

### 3. Create New DMG
- Builds new version: Build 15
- Creates: `Clnbrd-1.3-15.dmg`
- Places in: `Distribution/DMG/`

---

## 🎉 Benefits

### For You:
- ✅ **No confusion** - Build number in filename (Clnbrd-1.3-13.dmg)
- ✅ **No overwrites** - Old DMGs automatically archived
- ✅ **Easy tracking** - Timestamp shows when it was archived
- ✅ **Clean workspace** - Only current DMG in DMG/ folder
- ✅ **Full history** - All previous builds preserved

### For Users:
- ✅ **Clear versioning** - Know exactly which build they have
- ✅ **Easy identification** - "I have Build 14" vs "I have Build 15"
- ✅ **Support friendly** - You can ask "Which build number?"

---

## 📝 Examples

### Example 1: First Build
```bash
./build_distribution.sh
```
**Result:**
- Creates: `Distribution/DMG/Clnbrd-1.3-12.dmg`
- Archives: Nothing (first build)

### Example 2: Second Build
```bash
./build_distribution.sh
```
**Result:**
- Archives: `Clnbrd-1.3-12.dmg` → `Previous_Builds/Clnbrd-1.3-12_archived_20251004_100200.dmg`
- Creates: `Distribution/DMG/Clnbrd-1.3-13.dmg`

### Example 3: Third Build
```bash
./build_distribution.sh
```
**Result:**
- Archives: `Clnbrd-1.3-13.dmg` → `Previous_Builds/Clnbrd-1.3-13_archived_20251004_100530.dmg`
- Creates: `Distribution/DMG/Clnbrd-1.3-14.dmg`

**Archive folder now has:**
```
Previous_Builds/
├── Clnbrd-1.3-12_archived_20251004_100200.dmg
└── Clnbrd-1.3-13_archived_20251004_100530.dmg
```

---

## 🔍 Finding Builds

### Current Build (Ready to Share):
```bash
ls -lh Distribution/DMG/
```
Output: `Clnbrd-1.3-15.dmg`

### All Archived Builds:
```bash
ls -lh Distribution/Archive/Previous_Builds/
```
Output:
```
Clnbrd-1.3-12_archived_20251004_100200.dmg
Clnbrd-1.3-13_archived_20251004_100530.dmg
Clnbrd-1.3-14_archived_20251004_100542.dmg
```

### Build History:
```bash
./Scripts/Build/view_build_history.sh
```
Shows all builds with notes and timestamps.

---

## 🗂️ Managing Archives

### Keep Recent Builds Only
```bash
# Delete builds older than 30 days
find Distribution/Archive/Previous_Builds/ -name "*.dmg" -mtime +30 -delete
```

### Archive to External Storage
```bash
# Copy all archived builds to backup
cp -R Distribution/Archive/Previous_Builds/ ~/Backups/Clnbrd_Builds/
```

### Clean Up Old Archives
```bash
# Keep only last 5 builds
cd Distribution/Archive/Previous_Builds/
ls -t | tail -n +6 | xargs rm
```

---

## 📊 Current Status

**Last Build:** Build 14
- **DMG:** `Distribution/DMG/Clnbrd-1.3-14.dmg` (2.8 MB)
- **Archived:** `Previous_Builds/` contains previous builds
- **Status:** ✅ Ready for distribution

**Next Build:** Will be Build 15
- **Will create:** `Clnbrd-1.3-15.dmg`
- **Will archive:** Current `Clnbrd-1.3-14.dmg`

---

## 💡 Tips

### Sharing Builds
- Share: `Distribution/DMG/Clnbrd-1.3-15.dmg`
- Tell users: "Install Build 15"
- Easy for them to verify in Get Info window

### Testing Builds
- Keep archived builds in `Previous_Builds/`
- Compare: "Build 13 had the bug, Build 14 fixed it"
- Revert: Copy archived DMG back if needed

### Version Updates
When you update version (e.g., 1.3 → 1.4):
- Update: `Info.plist` → `CFBundleShortVersionString`
- Update: `VersionManager.swift` → `version`
- Next build: `Clnbrd-1.4-1.dmg` (new version, build counter continues)

---

## 🚀 Summary

✅ **Build numbers in filenames**: Easy identification  
✅ **Automatic archiving**: Never lose a build  
✅ **Timestamped archives**: Know when builds were made  
✅ **Organized structure**: Clean and professional  
✅ **No manual work**: Everything automated  

**Your next build will be: `Clnbrd-1.3-15.dmg`** 🎉


