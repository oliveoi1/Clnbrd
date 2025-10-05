# Clnbrd - Clipboard Cleaner for macOS

A powerful macOS menu bar application that cleans your clipboard text by removing formatting, invisible characters, and other unwanted elements.

## Features

- **Smart Text Cleaning**: Removes formatting, AI watermarks, emojis, and more
- **Hotkey Support**: Use ⌘⌥V (Cmd+Option+V) to paste cleaned text
- **Auto-clean Mode**: Automatically clean clipboard when copying
- **Custom Rules**: Add your own find & replace patterns
- **Menu Bar Integration**: Easy access from your menu bar
- **Automatic Updates**: Built-in update checking system
- **Privacy-Focused Analytics**: Optional usage insights to improve the app
- **Persistent Settings**: Your preferences are saved automatically
- **Crash Reporting**: Professional error monitoring and crash detection

## Installation

### Important: macOS Security Warning

When you first try to open Clnbrd, macOS will show a security warning because the app is not signed by Apple. This is normal for apps distributed outside the App Store.

**What you'll see:**
- "Clnbrd.app cannot be opened because it is not from an identified developer"
- Or "Clnbrd.app was blocked from use because it is not from an identified developer"

**How to fix it:**

**Method 1 (Recommended):**
1. Go to System Settings → Privacy & Security
2. Scroll down to find "Clnbrd.app was blocked"
3. Click "Open Anyway"
4. Click "Open" in the confirmation dialog

**Method 2 (Alternative):**
1. Right-click on Clnbrd.app in Finder
2. Select "Open" from the context menu
3. Click "Open" in the security dialog

## Setup

After Clnbrd launches, you'll need to grant accessibility permissions for the hotkey to work:

1. Open System Settings → Privacy & Security → Accessibility
2. Find "Clnbrd" in the list
3. Toggle it ON
4. Restart Clnbrd

## Usage

### Keyboard Shortcuts
- **⌘⌥V**: Paste cleaned text (requires accessibility permission)
- **⌘C**: Clean clipboard manually
- **⌘,**: Open settings
- **⌘U**: Check for updates
- **⌘Q**: Quit application

### Menu Bar Options
- **Paste Cleaned (⌘⌥V)**: Use hotkey to paste cleaned text
- **Clean Clipboard Now**: Manually clean current clipboard
- **Auto-clean on Copy**: Automatically clean when copying
- **Settings**: Configure cleaning rules and preferences
- **Check for Updates**: Manually check for new versions
- **Installation Guide**: Help with setup issues
- **About Clnbrd**: Version and contact information

## Cleaning Rules

Clnbrd removes:
- Formatting (bold, italic, colors)
- AI watermarks (invisible characters)
- URLs, HTML tags, extra punctuation
- Emojis (optional)
- Smart quotes, em-dashes, extra spaces
- Extra line breaks and whitespace
- Custom find & replace patterns

### Built-in Cleaning Rules
1. **Remove zero-width and invisible characters** (AI watermarks)
2. **Replace em-dashes (—) with comma+space**
3. **Normalize multiple spaces to single space**
4. **Convert smart quotes to straight quotes**
5. **Normalize line breaks**
6. **Remove trailing spaces from lines**
7. **Remove emojis** (optional)
8. **Remove extra line breaks** (3+ → 2)
9. **Remove leading/trailing whitespace**
10. **Remove URLs** (http, https, www)
11. **Remove HTML tags and entities**
12. **Remove extra punctuation marks**

## Privacy & Analytics

Clnbrd includes optional privacy-focused analytics to help improve the app:

### What's Tracked (when enabled):
- Number of cleaning operations
- Which cleaning methods are used most
- Error types and frequency
- App session count
- Update check success/failure

### What's NOT Tracked:
- Clipboard content
- Personal information
- File names or paths
- User identity

### Privacy Controls:
- **Analytics enabled by default** to help improve the app
- **Can be disabled anytime** in Settings
- **All data stays local** on your device
- **No data is sent anywhere**
- **Automatic cleanup** of old data (1 year)

## Support

If you need help:
- Email: olivedesignstudios@gmail.com
- Include your macOS version and any error messages
- Use "View Analytics" in Settings to copy usage data for support

## Developer

Created by Allan Alomes
Contact: olivedesignstudios@gmail.com

---

**Note**: This app is not distributed through the App Store, which is why macOS shows security warnings. This is completely normal and safe.

