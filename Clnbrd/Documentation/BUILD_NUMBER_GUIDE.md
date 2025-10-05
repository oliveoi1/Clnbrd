# Build Number Management Guide

## Overview

Clnbrd now uses automatic build number incrementing to help track changes between builds during development and testing.

---

## How It Works

### Automatic Incrementing
When you run `./build_distribution.sh`, the build number automatically increments:
- **Before**: Version 1.3 (Build 3)
- **After**: Version 1.3 (Build 4)

### What Gets Updated
1. **Info.plist**: `CFBundleVersion` is incremented
2. **VersionManager.swift**: `buildNumber` constant is updated
3. **.build_history.txt**: A timestamped entry is added

---

## Usage

### Build with Auto-Increment
```bash
./build_distribution.sh
```
This will:
1. ✅ Increment build number
2. ✅ Build the app
3. ✅ Create DMG
4. ✅ Record in build history

### Manual Increment (with note)
```bash
./Scripts/Build/increment_build_number.sh "Fixed hotkey registration bug"
```

### View Build History
```bash
./Scripts/Build/view_build_history.sh
```

Example output:
```
📦 Total Builds: 15

Recent Builds:
────────────────────────────────────────────────────────────────

2025-10-04 07:52:15 | Version 1.3 | Build 4
           └─ Automated build via build_distribution.sh

2025-10-04 08:15:30 | Version 1.3 | Build 5
           └─ Fixed hotkey registration bug

2025-10-04 09:00:00 | Version 1.3 | Build 6
           └─ Added permission dialog improvements
```

---

## Version vs Build Number

### Version Number (1.3)
- **User-facing** version
- **Changes manually** when you release new features
- Update in `Info.plist` and `VersionManager.swift`
- Format: `MAJOR.MINOR` (e.g., 1.3, 2.0, 2.1)

### Build Number (4, 5, 6...)
- **Internal** tracking number
- **Auto-increments** with every build
- Helps identify exactly which build you're testing
- Sequential: 1, 2, 3, 4, 5...

---

## When to Change Version Number

### Increment MAJOR version (1.x → 2.0)
- Major redesign
- Breaking changes
- Complete rewrites

### Increment MINOR version (1.3 → 1.4)
- New features
- Significant improvements
- User-visible changes

### Keep same version, auto-increment build (1.3.3 → 1.3.4)
- Bug fixes
- Small tweaks
- Internal changes
- Testing builds

---

## Examples

### Scenario 1: Testing a Fix
```bash
# Current: Version 1.3 (Build 3)
./build_distribution.sh
# Result: Version 1.3 (Build 4)

# Test the build, find another issue, fix it
./build_distribution.sh
# Result: Version 1.3 (Build 5)
```

### Scenario 2: Releasing New Version
```bash
# Current: Version 1.3 (Build 25)

# Manually update version to 1.4 in:
# - Info.plist: CFBundleShortVersionString = "1.4"
# - VersionManager.swift: version = "1.4"

./build_distribution.sh
# Result: Version 1.4 (Build 26)
```

### Scenario 3: Emergency Hotfix
```bash
# Current: Version 1.4 (Build 30)

# Fix critical bug
./Scripts/Build/increment_build_number.sh "Critical hotfix for crash on launch"
# Result: Version 1.4 (Build 31)

./build_distribution.sh
# Result: Version 1.4 (Build 32) - this is your hotfix build
```

---

## Build History File

### Location
`.build_history.txt` (in project root)

### Format
```
2025-10-04 08:15:30 | Version 1.3 | Build 5
           └─ Fixed hotkey registration bug
```

### Notes
- **Not committed to git** (in `.gitignore`)
- **Local tracking only** for your development machine
- Helps you remember what changed in each build
- Useful for troubleshooting "which build had X?"

---

## Troubleshooting

### Build number didn't increment
**Check**: Did the script run successfully?
```bash
./Scripts/Build/increment_build_number.sh
```

### Build number is out of sync
**Fix**: Manually set it in both files:
1. **Info.plist**: `CFBundleVersion`
2. **VersionManager.swift**: `buildNumber`

### Lost build history
**Result**: History is local only. If you want to track globally:
- Remove `.build_history.txt` from `.gitignore`
- Commit the history file to git

---

## Benefits

### For Development
- ✅ **Easy troubleshooting**: "Build 15 had the bug, Build 16 fixed it"
- ✅ **No confusion**: Each build has a unique identifier
- ✅ **Automatic**: No manual tracking needed

### For Testing
- ✅ **Clear communication**: "Test Build 23, not 22"
- ✅ **Progress tracking**: See how many iterations it took
- ✅ **Build notes**: Remember why you made each build

### For Distribution
- ✅ **User identification**: "What build are you on?"
- ✅ **Support**: "Please upgrade to Build 30 or later"
- ✅ **Analytics**: Track which builds users have

---

## Quick Commands

```bash
# Build with auto-increment
./build_distribution.sh

# Manual increment with note
./Scripts/Build/increment_build_number.sh "Your note here"

# View history
./Scripts/Build/view_build_history.sh

# Check current version
plutil -p Clnbrd/Info.plist | grep -E "(Version|Build)"
```

---

## Summary

- ✅ **Build numbers auto-increment** with every `./build_distribution.sh`
- ✅ **History is tracked** in `.build_history.txt`
- ✅ **Notes can be added** for each build
- ✅ **Version numbers** change manually for releases
- ✅ **No more confusion** about which build is which!

**Next build will be: Version 1.3 (Build 4)** 🚀

