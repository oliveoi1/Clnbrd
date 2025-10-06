# Archived Build Scripts

These scripts are **old iterations** from the development process. They have been replaced by the current automated workflow and are kept here for reference only.

## 🚫 Do Not Use These

These scripts are **outdated** and may not work with the current project structure.

## ✅ Current Active Scripts

For the current build process, use:

- **`../../build_distribution.sh`** - Main build & sign script
- **`../../Scripts/Build/finalize_notarized_build.sh`** - Post-notarization finalization

## 📜 What's Archived Here

### Old Build Scripts (Replaced by `build_distribution.sh`)
- `Build/build_professional.sh` - Earlier iteration of build process
- `Build/build_and_dmg.sh` - Combined build and DMG creation (now split)

### Old DMG Scripts (Replaced by logic in `finalize_notarized_build.sh`)
- `DMG/create_dmg*.sh` (7 files) - Various DMG creation experiments
  - These were iterations while perfecting the DMG structure
  - Final logic is now integrated into `finalize_notarized_build.sh`

## 📅 Archived

**Date:** October 6, 2025  
**Reason:** Replaced by automated workflow with:
- Auto-increment build numbers
- Auto-update README
- Auto-generate version JSON
- Auto-update appcast.xml
- Integrated DMG creation with proper structure

---

*For current build documentation, see `/Documentation/BUILD_WORKFLOW_UPDATED.md`*
