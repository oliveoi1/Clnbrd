# Clnbrd Project Structure

**Last Updated:** October 6, 2025

## 📁 Root Directory Structure

```
/Users/allanalomes/Documents/AlsApp/Clnbrd/
├── Clnbrd/                  # Main project directory
│   ├── Clnbrd/              # Source code
│   ├── Clnbrd.xcodeproj/    # Xcode project
│   ├── Distribution/        # Build outputs & releases
│   ├── Scripts/             # Build automation scripts
│   ├── Documentation/       # Project documentation
│   ├── Assets/              # Version templates & DMG assets
│   └── build_distribution.sh # Main build script
│
├── Documentation/           # Repository-level documentation
│   ├── Workflows/           # Build & Git workflows
│   └── Archive/             # Historical documentation
│
├── _Archive/                # Old projects & builds
│   ├── Old_DMGs/            # Previous DMG releases
│   ├── Backups/             # Old project backups
│   ├── CleanPaste/          # Original project name
│   └── Experiments/         # Test projects
│
├── README.md                # Repository README
├── appcast.xml              # Sparkle auto-update feed
└── version.json             # Current version info
```

---

## 🏗️ Main Project: Clnbrd/

### Source Code: `Clnbrd/Clnbrd/`
```
Clnbrd/
├── AppDelegate.swift          # Main app delegate
├── ClnbrdApp.swift            # SwiftUI app entry
├── VersionManager.swift       # Version management (reads from Info.plist)
├── ClipboardManager.swift     # Clipboard operations
├── MenuBarManager.swift       # Menu bar UI
├── PreferencesManager.swift   # Settings persistence
├── AnalyticsManager.swift     # Usage analytics
├── PerformanceMonitor.swift   # Performance tracking
├── ErrorRecoveryManager.swift # Error handling
├── SentryManager.swift        # Crash reporting
├── UpdateChecker.swift        # Auto-update checking
├── Info.plist                 # App configuration & version
└── Assets.xcassets/           # App icons & images
```

### Distribution: `Clnbrd/Distribution/`
```
Distribution/
├── DMG/                       # Final DMG installers
│   └── Clnbrd-{VERSION}-Build-{N}-Notarized.dmg
│
├── Upload/                    # Files for upload
│   ├── Clnbrd-Build{N}-Notarized.zip
│   └── clnbrd-version.json
│
├── Notarized/                 # Notarized app with stapled ticket
│   └── Clnbrd.app
│
├── App/                       # Built app (before notarization)
│   └── Clnbrd.app
│
├── Archive/                   # Previous builds
│   ├── Previous_Builds/       # Archived DMGs
│   └── Build_29_Notarization/ # Old notarization files
│
├── Clnbrd.xcarchive/          # Xcode archive
├── Logs/                      # Build logs
│   ├── archive.log
│   └── export.log
│
├── Distribution-Info.txt      # Build summary
└── RELEASE_NOTES.txt          # Release notes
```

### Scripts: `Clnbrd/Scripts/`
```
Scripts/
├── Build/
│   ├── increment_build_number.sh      # Auto-increment build
│   ├── finalize_notarized_build.sh   # Post-notarization script
│   ├── update_readme_version.sh      # Update README with version
│   └── view_build_history.sh         # Show build history
│
└── DMG/
    └── create_dmg*.sh                 # DMG creation scripts
```

### Documentation: `Clnbrd/Documentation/`
```
Documentation/
├── Workflows/
│   └── BUILD_WORKFLOW_UPDATED.md     # Complete build process
│
├── Guides/
│   ├── NOTARIZATION_GUIDE.md
│   ├── SENTRY_SETUP.md
│   ├── BUILD_NUMBER_GUIDE.md
│   └── QUICK_REFERENCE.md
│
├── Archive/                          # Historical docs
│
├── README.md                         # Documentation index
└── apple_dev_config.example          # Config template
```

---

## 🚀 Build Workflow

### Quick Reference

1. **Build & Sign:**
   ```bash
   cd Clnbrd
   ./build_distribution.sh
   ```

2. **Notarize:**
   ```bash
   xcrun notarytool submit Distribution/Upload/Clnbrd-Build{N}.zip \
     --apple-id olivedesignstudios@gmail.com \
     --team-id 58Y8VPZ7JG \
     --password "APP_SPECIFIC_PASSWORD" \
     --wait
   ```

3. **Finalize:**
   ```bash
   ./Scripts/Build/finalize_notarized_build.sh {BUILD_NUMBER}
   ```

---

## 📦 Distribution Files

### For GitHub Releases:
```
Distribution/DMG/Clnbrd-{VERSION}-Build-{N}-Notarized.dmg
Distribution/Upload/Clnbrd-Build{N}-Notarized.zip
Distribution/Upload/clnbrd-version.json
```

### Auto-Update Feed:
```
/Users/allanalomes/Documents/AlsApp/Clnbrd/appcast.xml
```

---

## 🗄️ Archive Directory

Old and experimental projects are stored in `_Archive/`:
- **Old_DMGs/**: Previous releases (Build 30, 31)
- **Backups/**: Old project backups
- **CleanPaste/**: Original project (pre-rename)
- **Experiments/**: Test projects (SnakeGame)

---

## 📝 Key Files

| File | Location | Purpose |
|------|----------|---------|
| **Info.plist** | `Clnbrd/Clnbrd/Info.plist` | Version source of truth |
| **VersionManager.swift** | `Clnbrd/Clnbrd/VersionManager.swift` | Reads version from Info.plist |
| **build_distribution.sh** | `Clnbrd/build_distribution.sh` | Main build script |
| **finalize_notarized_build.sh** | `Clnbrd/Scripts/Build/` | Post-notarization script |
| **appcast.xml** | Root | Sparkle auto-update feed |
| **version.json** | Root | Current version info |
| **README.md** | Root | Repository README |

---

## 🧹 Maintenance

### Build Artifacts Cleanup
```bash
# Archive old DMGs (automatic)
# When you run build_distribution.sh, it automatically archives
# previous DMGs to Distribution/Archive/Previous_Builds/
```

### Manual Cleanup
```bash
# Clean Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Clnbrd-*

# Remove old archives
rm -rf Clnbrd/Distribution/Archive/Previous_Builds/*_archived_*
```

---

## 📚 Documentation Index

- **Build Workflow:** `Clnbrd/Documentation/Workflows/BUILD_WORKFLOW_UPDATED.md`
- **Notarization Guide:** `Clnbrd/Documentation/Guides/NOTARIZATION_GUIDE.md`
- **Quick Reference:** `Clnbrd/Documentation/Guides/QUICK_REFERENCE.md`
- **Change History:** `Documentation/Archive/SCRIPT_UPDATES_SUMMARY.md`

---

## ✅ Organization Principles

1. **Single Source of Truth**: Version info comes from `Info.plist`
2. **Automated Archiving**: Old builds automatically moved to Archive
3. **Clear Separation**: Source, builds, docs, and archives in separate directories
4. **Minimal Root Clutter**: Only essential files at repository root
5. **Documentation Organization**: Grouped by type (Workflows, Guides, Archive)

---

**Maintained by:** Allan Alomes  
**Email:** olivedesignstudios@gmail.com  
**Last Cleanup:** October 6, 2025

