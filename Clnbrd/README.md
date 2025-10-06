# Clnbrd - Professional Clipboard Cleaning for macOS

[![Version](https://img.shields.io/badge/version-1.3-blue.svg)](https://github.com/oliveoi1/Clnbrd)
[![Build](https://img.shields.io/badge/build-33-green.svg)](https://github.com/oliveoi1/Clnbrd)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://github.com/oliveoi1/Clnbrd)

## 📍 Project Location
```
/Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd/
```

## 🎯 Quick Start

### For Development
1. **Open Xcode Project**: `Clnbrd.xcodeproj`
2. **Main Files**:
   - `Clnbrd/AppDelegate.swift` - Core app logic
   - `Clnbrd/ClipboardManager.swift` - Clipboard operations
   - `Clnbrd/MenuBarManager.swift` - Menu bar UI

### For Building Distribution
```bash
# Build complete distribution DMG
./build_distribution.sh

# Output: Distribution/DMG/Clnbrd-1.3-Build-XX.dmg
```

### For Testing
```bash
# Mount the DMG
open Distribution/DMG/Clnbrd-1.3-Build-33.dmg

# Or run directly from Xcode
# Cmd+R in Xcode
```

## 📂 Project Structure

```
Clnbrd/
├── Clnbrd.xcodeproj/           # Xcode project
├── Clnbrd/                     # Source code
├── Distribution/               # Build outputs & DMGs
│   ├── DMG/                    # Final installers
│   ├── Archive/Previous_Builds/ # Archived DMGs
│   └── RELEASE_NOTES.txt       # Changelog
├── Documentation/              # All documentation
├── Scripts/                    # Build automation
│   ├── Build/                  # Build scripts
│   └── DMG/                    # DMG creation
└── build_distribution.sh       # Main build script
```

See [Documentation/PROJECT_STRUCTURE.md](Documentation/PROJECT_STRUCTURE.md) for detailed structure.

## 🚀 Current Status

- **Version**: 1.3 (Build 33)
- **Status**: ⏳ Awaiting Notarization
- **Features Complete**:
  - ✅ Clipboard cleaning with ⌘⌥V hotkey
  - ✅ Menu bar integration
  - ✅ Auto-clean on copy
  - ✅ Custom cleaning rules
  - ✅ Developer ID code signing
  - ✅ Build numbering system
  - ✅ DMG auto-archiving

## 🔧 Key Features

### Clipboard Cleaning
- **Hotkey**: ⌘⌥V (Cmd+Option+V) - paste cleaned text
- **Auto-clean**: Optional automatic cleaning on copy
- **Custom rules**: User-defined find & replace patterns

### Menu Bar App
- **Non-intrusive**: Lives in menu bar, no dock icon
- **Quick access**: Click icon for all features
- **Status updates**: Visual feedback for operations

### Permissions Management
- **Accessibility**: Required for paste simulation
- **Input Monitoring**: Required for hotkey detection
- **Guided setup**: In-app instructions with direct links

## 📚 Documentation

### User Documentation
- [INSTALLATION_GUIDE.txt](Documentation/INSTALLATION_GUIDE.txt) - User setup guide
- [RELEASE_NOTES.txt](Distribution/RELEASE_NOTES.txt) - Version history

### Developer Documentation
- [PROJECT_STRUCTURE.md](Documentation/PROJECT_STRUCTURE.md) - Complete structure guide
- [BUILD_NUMBER_GUIDE.md](Documentation/BUILD_NUMBER_GUIDE.md) - Build system docs
- [NOTARIZATION_GUIDE.md](Documentation/NOTARIZATION_GUIDE.md) - Apple notarization
- [SENTRY_SETUP.md](Documentation/SENTRY_SETUP.md) - Crash reporting setup

## 🛠️ Development Workflow

### Making Changes
1. Make code changes in Xcode
2. Test thoroughly
3. Run `./build_distribution.sh`
4. Build number auto-increments
5. Previous DMG auto-archived

### Build Script Process
1. **Auto-increment** build number
2. **Archive** previous DMG with timestamp
3. **Build** and archive Xcode project
4. **Export** app bundle
5. **Create** DMG with Release Notes
6. **Verify** DMG integrity
7. **Generate** distribution summary

### Release Process
1. Test build thoroughly
2. Sign app with Developer ID
3. Create ZIP for notarization
4. Submit to Apple notary service
5. Staple notarization ticket
6. Distribute DMG

## 🔐 Code Signing & Notarization

### Developer ID
- **Certificate**: Developer ID Application: Allan Alomes (58Y8VPZ7JG)
- **Team ID**: 58Y8VPZ7JG
- **Profile**: Clnbrd-Notarization (stored in Keychain)

### Signing Command
```bash
codesign --force --deep --sign "Developer ID Application: Allan Alomes (58Y8VPZ7JG)" \
         --options runtime --timestamp Clnbrd.app
```

### Notarization Command
```bash
xcrun notarytool submit Clnbrd.zip --keychain-profile "Clnbrd-Notarization" --wait
```

## 📦 Distribution

### Current Build
- **DMG**: `Distribution/Upload/Clnbrd-Build33.zip`
- **Size**: ~2.7 MB
- **Contents**: Signed App Bundle
- **Signed**: ✅ Developer ID
- **Notarized**: ⏳ In Progress (awaiting Apple response)

### DMG Contents
- Clnbrd.app (signed)
- Applications folder shortcut
- Install Instructions.txt
- Release Notes.txt

## 🐛 Known Issues

1. **First launch requires two permissions**:
   - Accessibility (for paste simulation)
   - Input Monitoring (for hotkey detection)
   
2. **App must be quit and relaunched** after granting permissions

3. **Email clients may not support long pre-filled emails** (fallback: copies to clipboard)

## 📝 Version History

See [RELEASE_NOTES.txt](Distribution/RELEASE_NOTES.txt) for complete changelog.

### Recent Updates (Build 33)
- ✅ Apple Developer ID properly configured
- ✅ App ID registered: com.allanray.Clnbrd
- ✅ Team ID verified: 58Y8VPZ7JG
- ✅ All certificates valid and installed
- ✅ Code signing with Developer ID Application
- ✅ Submitted for notarization

## 🤝 Support

- **Email**: olivedesignstudios@gmail.com
- **Issues**: Use "Report Issue" in app (includes system info)

## 📄 License

Proprietary - Allan Alomes © 2025

---

**Last Updated**: October 6, 2025  
**Current Build**: 1.3 (33)  
**Project Status**: ⏳ Awaiting Notarization
