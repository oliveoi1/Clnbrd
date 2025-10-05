# Clnbrd Project Organization Guide

## 📁 **New Project Structure**

```
Clnbrd/
├── Clnbrd/                          # Main app source code
│   ├── AppDelegate.swift            # Main application logic
│   ├── ClnbrdApp.swift             # App entry point
│   ├── AnalyticsManager.swift      # Analytics tracking
│   ├── ClipboardManager.swift       # Clipboard operations
│   ├── MenuBarManager.swift        # Menu bar interface
│   ├── PreferencesManager.swift    # User preferences
│   ├── SentryManager.swift         # Error reporting
│   ├── UpdateChecker.swift         # Update checking
│   ├── Assets.xcassets/           # App icons and assets
│   ├── Info.plist                 # App configuration
│   └── Clnbrd.entitlements        # App permissions
├── Scripts/                        # Build and deployment scripts
│   ├── Build/
│   │   ├── build_and_dmg.sh       # Main build script
│   │   └── install.sh             # Installation script
│   └── DMG/
│       ├── create_dmg_working.sh  # Working DMG creator
│       ├── create_dmg_simple.sh   # Simple DMG creator
│       ├── create_dmg_pro.sh      # Professional DMG creator
│       └── create_dmg_complete.sh # Complete DMG creator
├── Documentation/                  # All documentation
│   ├── README.md                  # Main project documentation
│   ├── INSTALLATION_GUIDE.txt     # Installation instructions
│   ├── SENTRY_SETUP.md           # Sentry configuration
│   ├── DMG_README.md             # DMG creation guide
│   ├── PUSH_NOTIFICATIONS_GUIDE.md # Push notifications setup
│   └── POST_UPDATE_AUTHORIZATION_GUIDE.md # Post-update handling
├── Assets/                        # Static assets and templates
│   ├── clnbrd-version-template.json # Version file template
│   └── dmg_assets/               # DMG creation assets
│       └── create_background.py  # Background image generator
├── Clnbrd.xcodeproj/             # Xcode project files
└── .gitignore                    # Git ignore rules
```

## 🔧 **Version Management**

### **Automatic Version Detection**
The app now automatically reads version information from `Info.plist`:

```swift
struct AppConstants {
    static let version: String = {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }()
    
    static let buildNumber: String = {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }()
}
```

### **How to Update Versions**
1. **In Xcode**: Update `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`
2. **For releases**: Update `Assets/clnbrd-version-template.json`
3. **The app automatically uses the correct version** from Xcode settings

## 🚀 **Build Process**

### **Main Build Script**
```bash
./Scripts/Build/build_and_dmg.sh
```

This script:
1. Builds the Xcode project
2. Creates an archive
3. Exports the app
4. Calls the DMG creation script
5. Creates a professional installer

### **DMG Creation**
Multiple DMG creation scripts available:
- `create_dmg_working.sh` - **Recommended** (includes app, Applications alias, instructions)
- `create_dmg_simple.sh` - Basic DMG
- `create_dmg_pro.sh` - Professional with custom background
- `create_dmg_complete.sh` - Full-featured installer

## 📝 **Documentation**

All documentation is now organized in the `Documentation/` folder:
- **README.md** - Main project overview
- **INSTALLATION_GUIDE.txt** - User installation instructions
- **SENTRY_SETUP.md** - Error reporting setup
- **DMG_README.md** - DMG creation guide
- **PUSH_NOTIFICATIONS_GUIDE.md** - Push notification system
- **POST_UPDATE_AUTHORIZATION_GUIDE.md** - Post-update handling

## 🎯 **Key Improvements**

### **1. Clean Structure**
- ✅ Source code separated from scripts
- ✅ Documentation centralized
- ✅ Assets organized
- ✅ Build artifacts ignored

### **2. Proper Versioning**
- ✅ Uses Xcode project settings
- ✅ No more hardcoded versions
- ✅ Automatic version detection
- ✅ Template for release versions

### **3. Better Build Process**
- ✅ Organized build scripts
- ✅ Multiple DMG options
- ✅ Proper path handling
- ✅ Clean build artifacts

### **4. Version Control**
- ✅ Comprehensive .gitignore
- ✅ Ignores build artifacts
- ✅ Keeps templates
- ✅ Clean repository

## 🔄 **Workflow**

### **Development**
1. Make changes to source code in `Clnbrd/`
2. Test locally
3. Commit changes

### **Release**
1. Update version in Xcode (`Info.plist`)
2. Update `Assets/clnbrd-version-template.json`
3. Run `./Scripts/Build/build_and_dmg.sh`
4. Test the DMG
5. Upload to distribution

### **Documentation Updates**
- Add new guides to `Documentation/`
- Update existing docs as needed
- Keep README.md current

## 🎉 **Benefits**

- **Cleaner repository** - No build artifacts cluttering the project
- **Easier maintenance** - Organized structure makes finding files simple
- **Better versioning** - Automatic version detection from Xcode
- **Professional builds** - Organized build process
- **Comprehensive docs** - All documentation in one place
- **Version control ready** - Proper .gitignore and structure

Your Clnbrd project is now professionally organized and ready for efficient development and distribution! 🚀
