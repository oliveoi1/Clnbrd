# Clnbrd Development Roadmap

**Last Updated:** October 8, 2025  
**Current Version:** 1.3 (Build 44 - Latest Release) ✅

---

## 🎉 Recent Accomplishments (Build 43-44)

### ✅ Completed in Latest Release
- [x] **Fixed Sparkle Update System** (Build 44)
  - Resolved "Update Error!" dialog issue
  - Created appcast-v2.xml to bypass GitHub cache
  - Updated Info.plist to use new appcast URL
  - **Status:** ✅ Complete
  - **Impact:** Users can now receive updates properly

- [x] **Enhanced Profile Management UI** (Build 43)
  - Consolidated all profile options into single dropdown menu
  - Improved settings interface organization
  - Better user experience for profile management
  - **Status:** ✅ Complete
  - **Impact:** Cleaner, more intuitive interface

- [x] **Code Signing & Notarization Fixes** (Build 43)
  - Fixed "resource fork" signing errors
  - Implemented /tmp directory signing approach
  - Successfully notarized with Apple (ID: d763a4df-2ca5-4450-b6e7-9a874f996223)
  - **Status:** ✅ Complete
  - **Impact:** Reliable build and distribution process

---

## 🎯 Immediate Priority

### Security & Distribution
- [x] **Add EdDSA Signature to Appcast** (High Priority) ✅
  - Locate Sparkle's `sign_update` tool
  - Generate signature for Build 43 DMG
  - Update `appcast-v2.xml` with `sparkle:edSignature`
  - Add signature generation to build automation
  - **Status:** ✅ **COMPLETED** - EdDSA signature added to Build 43
  - **Effort:** 15 minutes (completed)
  - **Impact:** Enhanced update security
  - **Signature:** `66gOpAxBfOaJ99+HILncZH+gH5n4KLf610LJRWX0vDOwgw+8X3ocjDxvgmHcfcoYPmVJ3sNTRlj2/k/WM0EqBQ==`

---

## 📋 Short Term (Next 1-2 Builds)

### Build Automation Improvements
- [x] **Fixed Code Signing Process** (Build 43)
  - Implemented /tmp directory signing to avoid file provider issues
  - Updated build_distribution.sh with robust signing approach
  - **Status:** ✅ Complete
  - **Impact:** Reliable automated builds

- [ ] **Automate EdDSA Signature Generation**
  - Integrate `sign_update` into `finalize_notarized_build.sh`
  - Store Sparkle private key securely
  - Auto-update `appcast-v2.xml` with signature
  - **Status:** Not Started
  - **Effort:** 2 hours
  - **Impact:** Fully automated releases

- [ ] **Automatic Appcast Update**
  - Script to update `appcast-v2.xml` automatically
  - Extract version, file size, date from build
  - Generate release notes from git commits
  - **Status:** Not Started
  - **Effort:** 3 hours
  - **Impact:** Eliminates manual appcast updates

- [ ] **Automated GitHub Release**
  - Integrate `gh release create` into finalization script
  - Auto-upload DMG, ZIP, JSON, and appcast
  - Generate release notes from template
  - **Status:** Not Started
  - **Effort:** 2 hours
  - **Impact:** One-command release process

### Testing & Validation
- [ ] **Build Number Validation**
  - Prevent duplicate build numbers
  - Check if build already exists on GitHub
  - Warn before overwriting
  - **Status:** Not Started
  - **Effort:** 1 hour
  - **Impact:** Prevents release conflicts

- [ ] **Automated Testing Before Notarization**
  - Unit tests for core functionality
  - Integration tests for clipboard operations
  - Accessibility permission checks
  - **Status:** Not Started
  - **Effort:** 4 hours
  - **Impact:** Fewer rejected builds

---

## ✅ Recently Completed (Build 34)

### Features & Code Architecture
- [x] **Code Refactoring: Separate CleaningRules & SettingsWindow** ✅
  - ✅ Extracted `CleaningRules` class → `CleaningRules.swift` (~400 lines with full URL tracking)
  - ✅ Extracted `SettingsWindow` class → `SettingsWindow.swift` (~1,323 lines)
  - ✅ Extracted `CustomRule` struct into `CleaningRules.swift`
  - ✅ Created `CleaningProfile.swift` for profile management (~180 lines)
  - ✅ Significantly reduced `AppDelegate.swift` complexity
  - **Status:** ✅ Completed (October 8, 2025)
  - **Actual Effort:** 2-3 hours (including profile management system)
  - **Impact:** Excellent maintainability, cleaner architecture, easier future development
  - **Benefits Achieved:** 
    - AppDelegate complexity greatly reduced
    - Follows existing pattern (ClipboardManager, MenuBarManager, etc.)
    - Much easier to add new features
    - Clean separation of concerns

- [x] **Profile Management System** ✅ *NEW FEATURE!*
  - ✅ Create, rename, and delete cleaning profiles
  - ✅ Switch between different rule configurations
  - ✅ Export profiles to `.clnbrd-profile` files
  - ✅ Import profiles from files
  - ✅ Share profiles via AirDrop, Messages, Mail (native macOS share sheet)
  - ✅ Profile persistence using UserDefaults
  - ✅ Deep copy mechanism to prevent shared references
  - ✅ Automatic profile switching with UI updates
  - **Status:** ✅ Completed (October 8, 2025)
  - **Effort:** 3-4 hours
  - **Impact:** Major user feature - enables multiple cleaning configurations
  - **User Benefits:**
    - Different profiles for different use cases (e.g., "Work", "Personal", "Minimal")
    - Share custom configurations with team members
    - Backup and restore cleaning settings
    - Quick switching between rule sets

### Code Quality & Development Tools
- [x] **SwiftLint Integration & Code Quality** ✅ *MAJOR IMPROVEMENT!*
  - ✅ Installed and configured SwiftLint with comprehensive rules
  - ✅ Created `.swiftlint.yml` with project-specific configuration
  - ✅ Integrated SwiftLint into Xcode build process
  - ✅ Fixed all 41 compilation errors from refactoring
  - ✅ Resolved all 3 Function Body Length Violations by refactoring large functions
  - ✅ Created `.cursorrules` for AI-assisted development
  - ✅ Created `.cursorignore` for optimal Cursor performance
  - ✅ Documented setup in `CURSOR_SETUP.md`
  - **Status:** ✅ Completed (October 8, 2025)
  - **Effort:** 4-5 hours
  - **Impact:** Significantly improved code quality and development workflow
  - **Technical Achievements:**
    - Fixed syntax errors in `CleaningRules.swift` refactoring
    - Broke down large functions into smaller, focused helper methods
    - Replaced `print()` statements with proper `Logger` usage
    - Resolved Xcode build phase integration challenges
    - Disabled user script sandboxing for SwiftLint execution
  - **Developer Benefits:**
    - Automated code style enforcement
    - Consistent code formatting across team
    - Early detection of code quality issues
    - Better maintainability through smaller functions
    - Professional development environment setup

---

## 🚀 Medium Term (Next 3-6 Builds)

### Features & Code Architecture

- [x] **Custom Cleaning Rules** ✅ *COMPLETED IN BUILD 34!*
  - ✅ UI for adding/editing custom find & replace rules
  - ✅ Dynamic rule creation and deletion
  - ✅ Save/load custom rule sets (per profile)
  - ✅ Import/export via profile system
  - **Status:** ✅ Completed (October 8, 2025)
  - **Effort:** Included in profile management system
  - **Impact:** Power user feature - highly requested!

- [ ] **Keyboard Shortcut Customization**
  - Allow users to change ⌘⌥V to custom hotkey
  - Conflict detection with system shortcuts
  - Multiple hotkey profiles
  - **Status:** Not Started
  - **Effort:** 4 hours
  - **Impact:** Better flexibility

### UI/UX Improvements
- [ ] **Enhanced About Window**
  - Show notarization status
  - Display build date
  - Add "Copy Debug Info" button
  - Link to GitHub releases
  - **Status:** Not Started
  - **Effort:** 2 hours
  - **Impact:** Better user support

- [ ] **First-Run Experience**
  - Welcome screen with feature tour
  - Guided permission setup
  - Tips for best usage
  - **Status:** Not Started
  - **Effort:** 3 hours
  - **Impact:** Better onboarding

- [ ] **Preferences Window Redesign**
  - SwiftUI-based modern interface
  - Grouped settings by category
  - Search/filter settings
  - **Status:** Partially designed (see PREFERENCES_UI_DESIGN.md)
  - **Effort:** 8 hours
  - **Impact:** Modern, native look

### Analytics & Monitoring
- [ ] **Enhanced Usage Analytics**
  - Track which cleaning rules are used most
  - Hotkey vs auto-clean usage patterns
  - Performance metrics
  - **Status:** Basic analytics in place
  - **Effort:** 2 hours
  - **Impact:** Better product decisions

- [ ] **Crash Reporting Improvements**
  - Enhanced Sentry integration
  - User feedback on crashes
  - Automatic bug reports with context
  - **Status:** Basic Sentry in place
  - **Effort:** 3 hours
  - **Impact:** Faster bug fixes

---

## 🔮 Long Term (Future Versions)

### Major Features
- [ ] **Cloud Sync for Settings**
  - iCloud sync for preferences
  - Multiple device support
  - **Status:** Not Started
  - **Effort:** 10+ hours
  - **Impact:** Multi-device users

- [ ] **Clipboard History**
  - Optional clipboard history feature
  - Search previous clips
  - Clean historical items
  - **Status:** Not Started
  - **Effort:** 12+ hours
  - **Impact:** Major feature addition

- [ ] **iOS Companion App**
  - iPhone/iPad version
  - Universal clipboard with Mac
  - **Status:** Not Started
  - **Effort:** 40+ hours
  - **Impact:** Ecosystem expansion

### Platform Expansion
- [ ] **Mac App Store Release**
  - Prepare for App Store requirements
  - Sandbox compliance
  - In-app purchases for premium features?
  - **Status:** Not Started
  - **Effort:** 20+ hours
  - **Impact:** Wider distribution

- [ ] **Localization**
  - Support for multiple languages
  - Localized documentation
  - **Status:** Not Started
  - **Effort:** 8+ hours per language
  - **Impact:** International users

---

## 🐛 Known Issues & Tech Debt

### High Priority
- [ ] **Sparkle Framework Extended Attributes**
  - Current workaround: manual xattr cleaning
  - **Permanent Fix:** Investigate why Sparkle includes extended attributes
  - **Status:** Workaround in place
  - **Effort:** 3 hours research
  - **Impact:** Cleaner build process

- [ ] **Settings Window Crash**
  - `EnhancedSettingsUI.swift` causes runtime crash
  - Temporarily commented out
  - **Status:** Needs debugging
  - **Effort:** 2 hours
  - **Impact:** Enables advanced features

### Medium Priority
- [ ] **DMG Background Image**
  - Current: Solid color fallback
  - **Goal:** Professional branded background
  - **Status:** Working but basic
  - **Effort:** 1 hour + design
  - **Impact:** Polish

- [x] **Code Organization** ✅
  - ~~`AppDelegate.swift` is 2400+ lines~~
  - **Goal:** ✅ Break into separate files
  - **Status:** ✅ Completed (October 8, 2025)
  - **Actual Effort:** 3 hours
  - **Impact:** ✅ Significantly better maintainability achieved!
  - **Files Created:**
    - `CleaningRules.swift` (~400 lines)
    - `SettingsWindow.swift` (~1,323 lines)
    - `CleaningProfile.swift` (~180 lines)

### Low Priority
- [ ] **Documentation Updates**
  - Add video tutorials
  - Create FAQ section
  - **Status:** Not Started
  - **Effort:** Ongoing
  - **Impact:** User support

---

## 📊 Version Planning

### Version 1.3 (Build 34) - Current Development
**Focus:** Code Architecture & User Features ✅
- ✅ Complete code refactoring (CleaningRules, SettingsWindow, CleaningProfile)
- ✅ Profile management system (create, rename, delete, import/export, share)
- ✅ Custom find & replace rules
- ✅ Improved code maintainability
- ✅ SwiftLint integration and code quality enforcement
- ✅ Professional development environment setup
- ✅ All compilation errors resolved
- 🚧 Final testing and bug fixes
- 🚧 Performance optimizations

**Status:** Nearly Complete - Ready for Release  
**Target Release:** October 2025

### Version 1.4 (Next Release)
**Focus:** Automation & Polish
- EdDSA signature automation
- Automatic appcast updates
- Automatic GitHub releases
- Enhanced About window
- Bug fixes

**Target:** November 2025

### Version 1.5
**Focus:** UI/UX Enhancements
- Enhanced About window with build info
- First-run experience and onboarding
- Keyboard shortcut customization
- Preferences window redesign (SwiftUI)
- Advanced URL tracking UI

**Target:** December 2025

### Version 2.0
**Focus:** Major Features
- Clipboard history
- iCloud sync
- iOS companion app
- Mac App Store release

**Target:** Q1 2026

---

## 🎯 Success Metrics

### Current (Build 34 - In Development)
- ✅ Fully notarized by Apple
- ✅ Automated build process
- ✅ GitHub releases working
- ✅ Auto-updates via Sparkle
- ✅ Excellent project organization (refactored architecture)
- ✅ Profile management system implemented
- ✅ Custom cleaning rules support
- ✅ Professional development environment (SwiftLint, Cursor optimization)
- ✅ All compilation errors resolved
- ✅ Code quality standards enforced
- 🚧 Testing and performance optimization ongoing

### Goals for Next 3 Months
- [ ] 1000+ downloads
- [ ] 4.5+ star rating
- [ ] Zero critical bugs
- [ ] < 1 hour from build to release
- [ ] 90%+ crash-free users

### Goals for Next Year
- [ ] 10,000+ downloads
- [ ] Mac App Store presence
- [ ] iOS app launched
- [ ] Featured on MacStories/9to5Mac
- [ ] Sustainable revenue model

---

## 🤝 Contributing

### How to Add to Roadmap
1. Create GitHub issue for feature request
2. Discuss feasibility and priority
3. Add to appropriate roadmap section
4. Update status as progress is made

### Priority Levels
- **High:** Critical for next release
- **Medium:** Important but not blocking
- **Low:** Nice to have, when time permits

### Effort Estimates
- **< 2 hours:** Quick win
- **2-8 hours:** Single feature
- **8-20 hours:** Major feature
- **20+ hours:** Epic/milestone

---

## 📝 Notes

### Decision Log
- **Oct 8, 2025:** ✅ Completed major code refactoring (CleaningRules, SettingsWindow, CleaningProfile)
- **Oct 8, 2025:** ✅ Implemented profile management system with import/export/share
- **Oct 8, 2025:** ✅ Added custom find & replace rules functionality
- **Oct 8, 2025:** ✅ Integrated SwiftLint for automated code quality enforcement
- **Oct 8, 2025:** ✅ Optimized Cursor AI development environment
- **Oct 8, 2025:** ✅ Fixed all 41 compilation errors and code quality issues
- **Oct 8, 2025:** Shifted Build 34 focus from automation to architecture and user features
- **Oct 6, 2025:** Prioritized EdDSA signature for security (deferred to Build 35)
- **Oct 6, 2025:** Deferred iOS app to v2.0 for focus
- **Oct 6, 2025:** Committed to monthly release cadence

### Resources Needed
- [ ] Design assets for DMG background
- [ ] Beta testers for profile management system ⭐ NEW
- [ ] User feedback on custom rules feature ⭐ NEW
- [ ] Feedback on URL tracking rules
- [ ] Localization translators (future)

---

**Maintained by:** Allan Alomes  
**Email:** olivedesignstudios@gmail.com  
**GitHub:** https://github.com/oliveoi1/Clnbrd

**Last Review:** October 8, 2025  
**Next Review:** November 1, 2025

---

## 🎉 Build 34 Highlights

This build represents a **major architectural milestone** with significant code improvements and professional development setup:

### What Changed:
1. **Complete Code Refactoring** 
   - Separated monolithic `AppDelegate.swift` into focused modules
   - Created `CleaningRules.swift`, `SettingsWindow.swift`, `CleaningProfile.swift`
   - Improved maintainability and development velocity

2. **Profile Management System** (Major New Feature!)
   - Create unlimited cleaning profiles for different use cases
   - Import/Export profiles as `.clnbrd-profile` files
   - Share profiles via AirDrop, Messages, or Mail
   - Switch between profiles instantly

3. **Custom Find & Replace Rules**
   - Add your own text replacement rules
   - Saved per profile for flexibility
   - Applied before built-in cleaning rules

4. **Professional Development Environment** (Major Infrastructure!)
   - SwiftLint integration for automated code quality
   - Cursor AI optimization with `.cursorrules` and `.cursorignore`
   - Fixed all compilation errors and code quality issues
   - Comprehensive development documentation

### User Benefits:
- 🎯 Multiple cleaning configurations (Work, Personal, Minimal, etc.)
- 🤝 Share custom rule sets with team members
- 💾 Backup and restore your settings
- ⚡ Better app performance from cleaner code architecture
- 🛡️ More reliable app with better error handling

### Developer Benefits:
- 📦 Modular, maintainable codebase
- 🧪 Easier to add new features
- 🐛 Simpler debugging and testing
- 📚 Clear separation of concerns
- 🔧 Professional development tools and workflows
- 📏 Automated code quality enforcement
- 🤖 AI-assisted development optimization

