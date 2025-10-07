# Clnbrd

**Clean clipboard text and paste with hotkey tool for macOS**

A lightweight, menu bar utility that removes formatting from clipboard text (including hidden Chat GPT and AI Watermarks), making it easy to paste clean text anywhere.

## 📥 Download

**[⬇️ Download Latest Version (Clnbrd 1.3 Build 33)](https://github.com/oliveoi1/Clnbrd/releases/latest/download/Clnbrd-1.3-Build-33-Notarized.dmg)**

*Or view [all releases](https://github.com/oliveoi1/Clnbrd/releases)*

### ✅ Fully Notarized by Apple

This app is **officially notarized by Apple** and will install without any security warnings. Just download, open the DMG, and drag to Applications!

**No bypassing Gatekeeper required** - it's signed with a Developer ID and approved by Apple's notarization service.

---

## 🎯 Features

- **⌘⌥V Hotkey** - Paste cleaned text with a simple keyboard shortcut
- **Auto-clean on Copy** - Automatically remove formatting when you copy
- **Menu Bar Integration** - Quick access from your Mac's menu bar
- **Format Removal** - Strips all formatting, links, styles, and metadata
- **Performance Monitoring** - Built-in memory and CPU optimization
- **Error Recovery** - Automatic recovery from clipboard issues
- **Analytics** - Track usage patterns (privacy-focused)
- **Auto-updates** - Check for new versions automatically
- **Sentry Integration** - Crash reporting and error tracking

---

## 🚀 Installation

### Requirements
- macOS 15.5 or later
- Apple Silicon or Intel Mac

### Setup
1. Download the latest release
2. Open `Clnbrd.app`
3. Grant Accessibility and Input Monitoring permissions when prompted
4. Use ⌘⌥V to paste cleaned text!

---

## 🎮 Usage

### Keyboard Shortcut
- **⌘⌥V** (Command + Option + V) - Paste cleaned text

### Menu Bar Options
- **Paste Cleaned** - Clean and paste clipboard content
- **Clean Clipboard Now** - Clean clipboard without pasting
- **Auto-clean on Copy** - Toggle automatic cleaning
- **Settings** - Configure preferences
- **Check for Updates** - Get the latest version

---

## 🛠️ Technology Stack

- **Language:** Swift 5.0
- **Platform:** macOS 15.5+
- **Frameworks:** 
  - AppKit
  - Cocoa
  - IOKit (for keyboard monitoring)
- **Dependencies:**
  - Sentry (crash reporting)
- **Architecture:** Menu bar app with NSStatusItem

---

## 📂 Project Structure

```
Clnbrd/
├── Clnbrd/              # Main app source code
│   ├── AnalyticsManager.swift
│   ├── AppDelegate.swift
│   ├── ClipboardManager.swift
│   ├── ClnbrdApp.swift
│   ├── ErrorRecoveryManager.swift
│   ├── MenuBarManager.swift
│   ├── PerformanceMonitor.swift
│   ├── PreferencesManager.swift
│   ├── SentryManager.swift
│   ├── UpdateChecker.swift
│   └── VersionManager.swift
├── Documentation/       # Guides and documentation
├── Scripts/            # Build and distribution scripts
└── Assets/             # Icons and resources
```

---

## 🔐 Privacy & Permissions

Clnbrd requires:
- **Accessibility Access** - To monitor keyboard shortcuts (⌘⌥V)
- **Input Monitoring** - To paste cleaned text

**Privacy Promise:**
- No clipboard data is stored or transmitted
- All processing happens locally on your Mac
- Analytics are anonymous and optional

---

## 🏗️ Building from Source

```bash
# Clone the repository
git clone https://github.com/oliveoi1/Clnbrd.git
cd Clnbrd

# Open in Xcode
open Clnbrd/Clnbrd.xcodeproj

# Build and run (⌘R)
```

### Requirements for Building
- Xcode 16.0+
- macOS 15.5+ SDK
- Apple Developer account (for code signing)

---

## 📋 Version History

### v1.3 (Build 33) - Current ✅ Notarized
- **✅ Fully Notarized by Apple** - Approved October 6, 2025
- Apple Developer ID properly configured
- App ID registered: com.allanray.Clnbrd
- Team ID verified: 58Y8VPZ7JG
- All certificates valid and installed
- Code signing with Developer ID Application
- Stapled notarization ticket for offline verification
- Passes Gatekeeper without warnings
- Enhanced error recovery
- Performance monitoring
- Sentry integration
- Auto-update system
- Analytics tracking
- Version management

---

## 🤝 Contributing

This is a personal project, but suggestions and bug reports are welcome!

### Reporting Issues
- Use the "Report Issue" option in the app menu
- Or open an issue on GitHub

---

## 📄 License

Copyright © 2025 Allan Alomes. All rights reserved.

---

## 👨‍💻 Author

**Allan Alomes**
- GitHub: [@oliveoi1](https://github.com/oliveoi1)
- Email: olivedesignstudios@gmail.com

---

## 🙏 Acknowledgments

- Built with Swift and AppKit
- Error tracking by Sentry
- Inspired by the need for clean, formatting-free text

---

## 📊 Stats

- **Language:** Swift
- **Lines of Code:** ~2,300
- **Files:** 11 Swift files
- **Size:** <5 MB
- **Launch Time:** <0.5s

---

**Made with ❤️ for macOS**

