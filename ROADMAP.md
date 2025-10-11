# Clnbrd Development Roadmap

**Last Updated:** October 11, 2025  
**Current Version:** 1.3 (Build 52)  
**Status:** Stable Release ✅

---

## 🎉 Recent Milestones

### Build 52 - Auto-Update Fix (October 2025)
**Status:** ✅ Current Release

**Critical Fixes:**
- Fixed auto-update installer error by removing app sandboxing
- Sparkle updates now work correctly for all users
- Updated entitlements for proper Hardened Runtime configuration

**Technical Improvements:**
- Removed `com.apple.security.app-sandbox` entitlement
- Added proper Hardened Runtime entitlements for Sparkle compatibility
- Created comprehensive build process documentation
- Automated Sparkle-ready ZIP creation from stapled builds

---

### Build 51 - macOS Sequoia Ready (October 2025)
**Status:** ✅ Released

**Major Features:**
- **LetsMove Integration:** Prompts users to move app to `/Applications` on first launch
- **UI Refinements:**
  - Compacted About window layout for better space utilization
  - Added menu separator between Settings and Quit
  - Improved text alignment throughout settings
  - Cleaned up Rules section headers (removed emojis)
- **Professional Share Dialog:** Updated with website link and polished messaging

**Technical Achievements:**
- Successfully integrated Objective-C library (LetsMove) with Swift codebase
- Created bridging header for seamless interoperability
- Resolved ARC compatibility issues

---

### Build 50 - Notarization Breakthrough (October 2025)
**Status:** ✅ Released

**Major Achievement:**
- Solved `com.apple.provenance` extended attribute issue on macOS Sequoia
- Created "clean-room" build process avoiding `xcodebuild -exportArchive`
- Successful notarization with new approach

**Technical Innovations:**
- New `build_notarization_fixed.sh` script with /tmp build process
- Aggressive extended attribute cleanup
- Inside-out code signing for all frameworks
- Proper Sparkle framework component signing

---

### Build 43-50 - Foundation Work
**Completed Features:**
- ✅ Profile management system (create, rename, delete, export, share)
- ✅ Custom find & replace rules
- ✅ Code architecture refactoring (CleaningRules, SettingsWindow, CleaningProfile)
- ✅ EdDSA signature implementation for secure updates
- ✅ Enhanced URL tracking detection
- ✅ SwiftLint integration for code quality
- ✅ Sentry crash reporting

---

## 🎯 Current Focus (Build 53+)

### High Priority

#### Build Automation
- [ ] **Automated Appcast Generation**
  - Extract version info automatically
  - Calculate file sizes and generate EdDSA signatures
  - Update appcast-v2.xml programmatically
  - **Effort:** 3 hours
  - **Impact:** Eliminates manual updates and errors

- [ ] **One-Command Release**
  - Single script to build, notarize, staple, and release
  - Automatic GitHub release creation
  - Upload DMG and ZIP files
  - **Effort:** 4 hours
  - **Impact:** Faster, error-free releases

#### User Experience
- [ ] **Keyboard Shortcut Customization**
  - Allow users to customize the ⌘⌥V hotkey
  - Conflict detection with system shortcuts
  - **Effort:** 4 hours
  - **Impact:** Better accessibility and flexibility

- [ ] **Enhanced First-Run Experience**
  - Welcome screen with feature overview
  - Guided permission setup
  - Quick tutorial for best practices
  - **Effort:** 5 hours
  - **Impact:** Better user onboarding

---

## 🚀 Medium Term (Next 3-6 Months)

### Features
- [ ] **Clipboard History** (Optional Feature)
  - View and search previous clipboard items
  - Clean historical entries
  - Privacy-focused (local only)
  - **Effort:** 12 hours
  - **Impact:** Major feature for power users

- [ ] **Preferences Window Redesign**
  - Modern SwiftUI interface
  - Better organization and grouping
  - Search/filter settings
  - **Effort:** 8 hours
  - **Impact:** Modern, native look and feel

- [ ] **Enhanced Analytics**
  - Track most-used cleaning rules
  - Usage pattern insights
  - Performance metrics
  - **Effort:** 3 hours
  - **Impact:** Data-driven improvements

### Quality & Polish
- [ ] **Build Validation**
  - Prevent duplicate build numbers
  - Check if build already exists on GitHub
  - Pre-notarization testing
  - **Effort:** 2 hours
  - **Impact:** Fewer release conflicts

- [ ] **Enhanced About Window**
  - Show notarization status and build date
  - "Copy Debug Info" button for support
  - Direct link to GitHub releases
  - **Effort:** 2 hours
  - **Impact:** Better user support

---

## 🔮 Long Term Vision (Version 2.0+)

### Major Features
- **Cloud Sync:** iCloud sync for settings and profiles
- **Multi-Language Support:** Localization for international users
- **iOS Companion App:** iPhone/iPad version with universal clipboard
- **Mac App Store Release:** Wider distribution channel

### Platform Expansion
- **Homebrew Distribution:** Easy installation via `brew install clnbrd`
- **Community Profiles:** Share and discover cleaning profiles
- **Plugin System:** Allow third-party extensions

---

## 📊 Success Metrics

### Current Status (Build 52)
- ✅ Fully notarized for macOS Sequoia
- ✅ Automated build and distribution process
- ✅ Working auto-updates via Sparkle
- ✅ Professional GitHub presence with screenshots
- ✅ Clean, organized codebase
- ✅ Comprehensive documentation

### Goals for Next 3 Months
- [ ] 1,000+ downloads
- [ ] Zero critical bugs in production
- [ ] < 30 minutes from build to release
- [ ] 95%+ crash-free users
- [ ] Active user feedback and engagement

### Goals for 2026
- [ ] 10,000+ users
- [ ] 4.5+ star rating
- [ ] Featured on MacStories or 9to5Mac
- [ ] Mac App Store presence
- [ ] Sustainable development model

---

## 🛠️ Technical Debt

### Low Priority
- [ ] **DMG Background Image:** Professional branded background
- [ ] **Extended Attribute Research:** Understand Sparkle XPC service attributes
- [ ] **Performance Optimization:** Profile and optimize hot paths
- [ ] **Documentation Videos:** Create tutorial videos for advanced features

---

## 📋 Version Planning

### Version 1.3 (Current)
**Builds 43-52** | Stable Release
- Complete notarization solution for macOS Sequoia
- LetsMove integration
- Auto-update fixes
- UI polish and refinements
- Professional development workflow

### Version 1.4 (Q4 2025)
**Focus:** Automation & Customization
- Automated release process
- Keyboard shortcut customization
- Enhanced first-run experience
- Build validation and testing

### Version 1.5 (Q1 2026)
**Focus:** Power User Features
- Clipboard history (optional)
- Enhanced analytics
- Preferences window redesign
- Performance optimizations

### Version 2.0 (Q2 2026)
**Focus:** Ecosystem Expansion
- Cloud sync
- iOS companion app
- Mac App Store release
- Localization

---

## 🤝 Contributing

### How to Contribute
1. Check [open issues](https://github.com/oliveoi1/Clnbrd/issues) for current needs
2. Discuss feature ideas before implementing
3. Follow code style guidelines (SwiftLint enforced)
4. Submit pull requests with clear descriptions

### Priority Definitions
- **High:** Critical for next release
- **Medium:** Important but not blocking
- **Low:** Nice to have, when time permits

---

## 📝 Development Notes

### Recent Decisions
- **Oct 11, 2025:** Completed major project organization and cleanup
- **Oct 10, 2025:** Fixed auto-update installer error (removed sandboxing)
- **Oct 10, 2025:** Successfully integrated LetsMove for better UX
- **Oct 9, 2025:** Solved macOS Sequoia notarization issues
- **Oct 8, 2025:** Implemented profile management and custom rules

### Lessons Learned
- App sandboxing prevents Sparkle auto-updates
- macOS Sequoia requires clean-room build process
- Hardened Runtime entitlements are critical for XPC services
- Stapled apps must be used for Sparkle ZIP files
- Professional UI polish matters for user perception

---

**Maintained by:** Allan Alomes  
**Website:** http://olvbrd.x10.network/wp/  
**GitHub:** https://github.com/oliveoi1/Clnbrd  
**Email:** olivedesignstudios@gmail.com

**Next Review:** November 15, 2025
