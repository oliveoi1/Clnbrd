# Archived Documentation

This directory contains **historical documentation** from the development process. These documents capture completed tasks, setup summaries, and project snapshots that are no longer actively maintained but preserved for reference.

## 🚫 Do Not Use These

These documents are **historical snapshots** and may be outdated. They are kept for reference and context only.

## ✅ Current Documentation

For current documentation, see:

- **[Build Workflow](../Workflows/BUILD_WORKFLOW_UPDATED.md)** - Current build process
- **[Git Workflow](../Workflows/GIT_WORKFLOW.md)** - Git practices
- **[Xcode Setup](../Workflows/XCODE_GIT_SETUP.md)** - Development setup
- **[Roadmap](../../ROADMAP.md)** - Future development plans
- **[README](../../README.md)** - Project overview

---

## 📜 What's Archived Here

### Project Organization & Structure

#### `ORGANIZATION_SUMMARY.txt` (Oct 6, 2025)
- **What:** Summary of major project cleanup and reorganization
- **Status:** ✅ Completed task
- **Context:** Documents the reorganization of the repo on Oct 6, including:
  - Moving old projects to `_Archive/`
  - Organizing documentation into categories
  - Cleaning up root directory from 15+ scattered files to 3 essential files
  - Streamlining Distribution/ folder

#### `PROJECT_STRUCTURE.md` (Oct 6, 2025)
- **What:** Complete snapshot of project directory structure
- **Status:** 📸 Point-in-time snapshot
- **Context:** Detailed map of the entire project as of Oct 6, 2025. Useful for understanding the structure at that time, but will become outdated as the project evolves.

### Build & Automation

#### `SCRIPT_UPDATES_SUMMARY.md` (Oct 6, 2025)
- **What:** Summary of script updates to handle notarization requirements
- **Status:** ✅ Completed task
- **Context:** Documents the updates made to build scripts to:
  - Fix Sparkle framework signing issues
  - Clean extended attributes properly
  - Create notarization-ready packages
  - Automate post-notarization steps
- **Note:** Current build workflow is in `../Workflows/BUILD_WORKFLOW_UPDATED.md`

### Sparkle Integration

#### `SPARKLE_SETUP_COMPLETE.md` (Oct 5, 2025)
- **What:** Summary of Sparkle auto-update framework integration
- **Status:** ✅ Completed task
- **Context:** Documents the initial setup of Sparkle including:
  - Adding Sparkle via Swift Package Manager
  - Generating EdDSA signing keys
  - Creating signed appcast.xml
  - Configuring Info.plist
  - Integrating into AppDelegate
- **Note:** Sparkle is now fully integrated and working

---

## 📅 Timeline

| Date | Document | Type |
|------|----------|------|
| Oct 5, 2025 | SPARKLE_SETUP_COMPLETE.md | Setup Summary |
| Oct 6, 2025 | SCRIPT_UPDATES_SUMMARY.md | Build Fixes |
| Oct 6, 2025 | ORGANIZATION_SUMMARY.txt | Cleanup Summary |
| Oct 6, 2025 | PROJECT_STRUCTURE.md | Structure Snapshot |

---

## 📈 Why Archive?

These documents are archived because:

1. **Completed Tasks:** Some docs describe one-time setup/cleanup tasks that are now done
2. **Point-in-Time Snapshots:** Structure docs will become outdated as project evolves
3. **Historical Context:** Useful to understand decisions and evolution, but not current state
4. **Reduce Clutter:** Keep current docs clean and easy to find

---

## 🔍 Looking for Something?

- **How to build?** → `../Workflows/BUILD_WORKFLOW_UPDATED.md`
- **What's next?** → `../../ROADMAP.md`
- **Project overview?** → `../../README.md`
- **Git workflow?** → `../Workflows/GIT_WORKFLOW.md`

---

**Last Updated:** October 6, 2025  
**Archived By:** Automated cleanup
