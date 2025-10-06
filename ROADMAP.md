# Clnbrd Development Roadmap

**Last Updated:** October 6, 2025  
**Current Version:** 1.3 (Build 33) - Fully Notarized ✅

---

## 🎯 Immediate Priority

### Security & Distribution
- [ ] **Add EdDSA Signature to Appcast** (High Priority)
  - Locate Sparkle's `sign_update` tool
  - Generate signature for Build 33 DMG
  - Update `appcast.xml` with `sparkle:edSignature`
  - Add signature generation to build automation
  - **Status:** Pending
  - **Effort:** 30 minutes
  - **Impact:** Enhanced update security

---

## 📋 Short Term (Next 1-2 Builds)

### Build Automation Improvements
- [ ] **Automate EdDSA Signature Generation**
  - Integrate `sign_update` into `finalize_notarized_build.sh`
  - Store Sparkle private key securely
  - Auto-update `appcast.xml` with signature
  - **Status:** Not Started
  - **Effort:** 2 hours
  - **Impact:** Fully automated releases

- [ ] **Automatic Appcast Update**
  - Script to update `appcast.xml` automatically
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

## 🚀 Medium Term (Next 3-6 Builds)

### Features
- [ ] **URL Tracking Cleaner Enhancement**
  - Add granular per-rule configuration UI
  - `EnhancedSettingsUI.swift` integration
  - Finish implementation from feature branch
  - **Status:** Partially complete (see feature/url-tracking-removal branch)
  - **Effort:** 4 hours
  - **Impact:** Better user control

- [ ] **Custom Cleaning Rules**
  - UI for adding/editing custom regex patterns
  - Save/load custom rule sets
  - Import/export rule configurations
  - **Status:** Not Started
  - **Effort:** 6 hours
  - **Impact:** Power user feature

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

- [ ] **Code Organization**
  - `AppDelegate.swift` is 2400+ lines
  - **Goal:** Break into separate files
  - **Status:** Not Started
  - **Effort:** 4 hours
  - **Impact:** Better maintainability

### Low Priority
- [ ] **Documentation Updates**
  - Add video tutorials
  - Create FAQ section
  - **Status:** Not Started
  - **Effort:** Ongoing
  - **Impact:** User support

---

## 📊 Version Planning

### Version 1.4 (Next Release)
**Focus:** Automation & Polish
- EdDSA signature automation
- Automatic appcast updates
- Automatic GitHub releases
- Enhanced About window
- Bug fixes

**Target:** November 2025

### Version 1.5
**Focus:** Advanced Features
- URL tracking cleaner UI enhancements
- Custom cleaning rules
- Keyboard shortcut customization
- Preferences redesign

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

### Current (Build 33)
- ✅ Fully notarized by Apple
- ✅ Automated build process
- ✅ GitHub releases working
- ✅ Auto-updates via Sparkle
- ✅ Clean project organization

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
- **Oct 6, 2025:** Prioritized EdDSA signature for security
- **Oct 6, 2025:** Deferred iOS app to v2.0 for focus
- **Oct 6, 2025:** Committed to monthly release cadence

### Resources Needed
- [ ] Design assets for DMG background
- [ ] Beta testers for new features
- [ ] Feedback on URL tracking rules
- [ ] Localization translators (future)

---

**Maintained by:** Allan Alomes  
**Email:** olivedesignstudios@gmail.com  
**GitHub:** https://github.com/oliveoi1/Clnbrd

**Last Review:** October 6, 2025  
**Next Review:** November 1, 2025

