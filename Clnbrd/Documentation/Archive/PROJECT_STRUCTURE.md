# Clnbrd Project Structure

## Overview
This document describes the organized structure of the Clnbrd project after cleanup (October 2025).

## Directory Structure

```
Clnbrd/
├── Clnbrd.xcodeproj/           # Xcode project files
│   ├── project.pbxproj         # Main project configuration
│   └── xcuserdata/             # User-specific settings
│
├── Clnbrd/                     # SOURCE CODE
│   ├── AppDelegate.swift       # Main app delegate
│   ├── ClnbrdApp.swift         # SwiftUI app entry point
│   ├── ClipboardManager.swift  # Clipboard cleaning logic
│   ├── MenuBarManager.swift    # Menu bar UI management
│   ├── VersionManager.swift    # Version & build number management
│   ├── UpdateChecker.swift     # Auto-update functionality
│   ├── AnalyticsManager.swift  # Usage analytics
│   ├── SentryManager.swift     # Crash reporting
│   ├── PreferencesManager.swift # User preferences
│   ├── ErrorRecoveryManager.swift # Error handling
│   ├── PerformanceMonitor.swift # Performance tracking
│   ├── Info.plist              # App configuration & permissions
│   ├── Clnbrd.entitlements     # macOS entitlements
│   └── Assets.xcassets/        # App icons and assets
│
├── Assets/                     # PROJECT ASSETS
│   ├── clnbrd-version-1.3.json # Version info for updates
│   ├── clnbrd-version-template.json # Template for version files
│   └── dmg_assets/             # DMG background images, etc.
│
├── Distribution/               # BUILD OUTPUTS
│   ├── DMG/                    # Final DMG installers
│   │   └── Clnbrd-1.3-Build-XX.dmg
│   ├── Archive/                # Build archives & backups
│   │   ├── Previous_Builds/   # Archived old DMGs with timestamps
│   │   └── Clnbrd.xcarchive   # Latest Xcode archive (temp)
│   ├── Logs/                   # Build logs for debugging
│   │   ├── archive.log
│   │   └── export.log
│   ├── RELEASE_NOTES.txt       # Comprehensive changelog
│   └── Distribution-Info.txt   # Current build information
│
├── Documentation/              # ALL DOCUMENTATION
│   ├── INSTALLATION_GUIDE.txt  # User installation instructions
│   ├── README.md               # Main documentation
│   ├── PROJECT_STRUCTURE.md    # This file
│   ├── SENTRY_SETUP.md         # Crash reporting setup
│   ├── NOTARIZATION_GUIDE.md   # Apple notarization process
│   ├── BUILD_NUMBER_GUIDE.md   # Build numbering system
│   ├── DMG_ARCHIVING_GUIDE.md  # DMG archiving process
│   └── [other guides]          # Additional documentation
│
├── Scripts/                    # BUILD AUTOMATION
│   ├── Build/
│   │   ├── increment_build_number.sh  # Auto-increment build number
│   │   └── view_build_history.sh      # View build history
│   └── DMG/
│       └── create_dmg_working.sh      # DMG creation script
│
├── build_distribution.sh       # MAIN BUILD SCRIPT
│                               # (Orchestrates entire build process)
│
├── README.md                   # PROJECT README
└── BUILD_COMPLETE.txt          # Build status marker
```

## Key Files

### Build Scripts
- **`build_distribution.sh`** (ROOT) - Main build script that:
  - Increments build number automatically
  - Builds and archives the app
  - Creates the DMG installer
  - Archives previous DMGs with timestamps
  - Generates build logs and distribution info

- **`Scripts/Build/increment_build_number.sh`** - Increments build number and updates:
  - `Info.plist` (CFBundleVersion and CFBundleShortVersionString)
  - `VersionManager.swift` (hardcoded version constants)
  - Xcode project settings (CURRENT_PROJECT_VERSION, MARKETING_VERSION)

- **`Scripts/Build/view_build_history.sh`** - Displays build history from git commits

- **`Scripts/DMG/create_dmg_working.sh`** - Creates professional DMG with:
  - Clnbrd.app
  - Applications folder shortcut
  - Installation instructions
  - Release Notes

### Source Code Organization
- **`AppDelegate.swift`** - Main application lifecycle, permissions, settings UI
- **`ClipboardManager.swift`** - Core clipboard cleaning and paste functionality
- **`MenuBarManager.swift`** - Menu bar icon, menu, and hotkey registration
- **`VersionManager.swift`** - Centralized version and build number management

### Configuration Files
- **`Info.plist`** - App configuration including:
  - Version strings (CFBundleShortVersionString, CFBundleVersion)
  - Permission descriptions (NSAccessibilityUsageDescription, NSInputMonitoringUsageDescription)
  - Bundle identifiers and metadata
  - LSUIElement (menu bar app configuration)

- **`Clnbrd.entitlements`** - macOS security entitlements

## Build Process Flow

1. **Run `build_distribution.sh`**
   ```bash
   ./build_distribution.sh
   ```

2. **Automatic Steps:**
   - Increments build number (e.g., 27 → 28)
   - Updates all version references
   - Archives previous DMGs to `Distribution/Archive/Previous_Builds/`
   - Builds and archives the app
   - Exports the app bundle
   - Creates signed DMG with Release Notes
   - Verifies DMG integrity
   - Generates distribution summary

3. **Output:**
   - DMG: `Distribution/DMG/Clnbrd-1.3-Build-28.dmg`
   - Logs: `Distribution/Logs/`
   - Info: `Distribution/Distribution-Info.txt`

## Distribution Process

### For Testing (Current)
1. Build with `build_distribution.sh`
2. Test the DMG installation
3. Verify all functionality
4. When ready, sign and notarize

### For Production Release
1. Build with `build_distribution.sh`
2. Sign the app with Developer ID:
   ```bash
   codesign --force --deep --sign "Developer ID Application: Allan Alomes (58Y8VPZ7JG)" \
            --options runtime --timestamp Clnbrd.app
   ```
3. Create ZIP for notarization:
   ```bash
   ditto -c -k --keepParent Clnbrd.app Clnbrd.zip
   ```
4. Submit for notarization:
   ```bash
   xcrun notarytool submit Clnbrd.zip --keychain-profile "Clnbrd-Notarization" --wait
   ```
5. Staple notarization ticket:
   ```bash
   xcrun stapler staple Clnbrd.app
   ```
6. Create final DMG with notarized app

## Cleanup Summary (October 4, 2025)

### Deleted Files (20+):
- 6 redundant DMG creation scripts
- 3 redundant build scripts
- Old `build/` directory (replaced by `Distribution/`)
- Log files (*.log)
- Test files (test_paste.swift)
- Old archives (Clnbrd.zip)
- Setup scripts (create_certificate.sh)

### Moved Files (11):
- All .md documentation files moved to `Documentation/`
- Config examples moved to `Documentation/`

### Result:
- Clean, organized root directory
- All documentation centralized
- Only essential scripts remain
- Clear separation of source, build, and distribution

## Maintenance

### Adding a New Build
1. Make code changes
2. Run `./build_distribution.sh`
3. Test the generated DMG
4. Old DMG automatically archived

### Updating Documentation
- All docs in `Documentation/`
- Update `RELEASE_NOTES.txt` for each significant build
- Keep `PROJECT_STRUCTURE.md` updated with major changes

### Version Updates
- Edit `VersionManager.swift` to change version number (e.g., 1.3 → 1.4)
- Build number auto-increments on each build
- Both are updated in `Info.plist` automatically

## Best Practices

1. **Always use `build_distribution.sh`** for releases
2. **Test DMG before notarization** - notarization is final
3. **Keep Release Notes updated** - included in every DMG
4. **Archive old builds** - automatic backup system
5. **Version control** - commit after successful builds
6. **Documentation** - update guides when adding features

## Support Files

- **Build logs**: `Distribution/Logs/` for troubleshooting
- **Previous builds**: `Distribution/Archive/Previous_Builds/` for rollback
- **Version info**: `Assets/clnbrd-version-1.3.json` for update checks
- **Installation guide**: `Documentation/INSTALLATION_GUIDE.txt` for users

