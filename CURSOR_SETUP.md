# Cursor + Xcode Setup for Clnbrd

This document outlines the enhanced development setup for Clnbrd.

## ✅ What's Been Configured

### 1. SwiftLint Integration
- **Status:** ✅ Installed and configured
- **Version:** 0.59.1
- **Config File:** `.swiftlint.yml`
- **Purpose:** Enforces consistent code style and catches common issues

#### Key Rules Enabled:
- Line length: 140 chars (warning), 200 chars (error)
- File length: 600 lines (warning), 1500 lines (error)
- Function body length: 80 lines (warning)
- Type body length: 400 lines (warning), 600 lines (error)
- Custom rule: No print statements (prefer Logger)
- Opt-in rules: empty_count, empty_string, first_where, etc.

#### Next Step:
**Add SwiftLint to Xcode Build Phase:**
1. Open `Clnbrd.xcodeproj` in Xcode
2. Select "Clnbrd" target → Build Phases
3. Click "+" → New Run Script Phase
4. Add this script:
```bash
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed"
fi
```
5. Drag the phase BEFORE "Compile Sources"
6. Rename to "SwiftLint"

### 2. Cursor Rules (.cursorrules)
- **Status:** ✅ Created
- **Purpose:** Guides AI code generation for your project
- **Benefits:**
  - AI generates code matching your architecture patterns
  - Understands AppKit (not UIKit/SwiftUI)
  - Follows your Manager pattern
  - Uses proper Logger instead of print()
  - Knows your project structure

#### What It Includes:
- Manager pattern (singleton) guidelines
- AppKit-specific UI components
- Naming conventions
- Error handling with Logger
- Profile management patterns
- Keyboard event handling
- Menu bar app patterns
- URL cleaning architecture

### 3. Cursor Ignore (.cursorignore)
- **Status:** ✅ Created
- **Purpose:** Excludes unnecessary files from indexing
- **Benefits:**
  - Faster Cursor performance
  - Reduced memory usage
  - Focus on actual source code

#### What's Excluded:
- Xcode project metadata
- Build artifacts (DerivedData, .build)
- Dependencies (Carthage, Pods)
- System files (.DS_Store)
- Asset catalogs (binary files)
- Git internals

---

## 📊 SwiftLint Findings Summary

SwiftLint found **several categories of issues** to address:

### Critical Issues (Errors - 14 total)
- **Line Length Violations:** Lines exceeding 200 characters
  - `SettingsWindow.swift`: 2 errors
  - `AppDelegate.swift`: 12 errors
- **Type Body Length:** 
  - `SettingsWindow.swift`: 990 lines (limit: 600)
  - `AppDelegate.swift`: 825 lines (limit: 600)

### Major Issues (Warnings by Category)

#### 1. Print Statements → Logger (15 warnings)
Files with print() that should use Logger:
- `CleaningProfile.swift`: 1
- `SettingsWindow.swift`: 3
- `AppDelegate.swift`: 11

#### 2. File/Function Length (8 warnings)
- `SettingsWindow.swift`: File too long (905 lines), setupUI() too long (88 lines)
- `AppDelegate.swift`: File too long (1019 lines), 3 functions too long
- `ClipboardManager.swift`: 1 function too long (85 lines)

#### 3. Line Length (32 warnings)
Lines between 140-200 characters that should be broken up.

#### 4. Whitespace Issues (13 warnings)
- Missing trailing newlines
- Extra vertical whitespace
- Empty lines after opening/before closing braces

#### 5. Code Style (5 warnings)
- Unused closure parameters
- Redundant string enum values
- Prefer for-where over for-if

---

## 🎯 Recommended Action Plan

### Immediate (Do Now)
1. ✅ **Add SwiftLint to Xcode Build Phase** (see instructions above)
2. ✅ **Restart Cursor** to pick up .cursorrules and .cursorignore

### Short Term (Next Coding Session)
3. **Fix Critical Errors (14)** - Lines over 200 characters
   - Break long lines in SettingsWindow.swift (2 lines)
   - Break long lines in AppDelegate.swift (12 lines)

4. **Replace Print Statements (15)** - Easy wins
   - Add Logger to files that don't have it
   - Replace print() with logger.info() or logger.warning()

### Medium Term (Over Next Week)
5. **Fix Whitespace Issues (13)** - Auto-fixable
   - Add trailing newlines
   - Remove extra blank lines

6. **Break Up Long Functions** - Refactoring
   - Extract helpers from long functions
   - Consider additional manager classes

### Long Term (Future Releases)
7. **Consider Further Refactoring**
   - AppDelegate is still large (825 lines in type body)
   - SettingsWindow could be broken into sections
   - Extract view creation into separate helper classes

---

## 🚀 Quick Commands

```bash
# Lint your code
swiftlint lint

# Auto-fix what can be fixed
swiftlint lint --fix

# Lint specific file
swiftlint lint --path Clnbrd/Clnbrd/AppDelegate.swift

# See stats
swiftlint analyze

# Update SwiftLint
brew upgrade swiftlint
```

---

## 💡 Tips for Using Cursor with SwiftLint

### 1. Ask AI to Fix SwiftLint Issues
```
"Fix the SwiftLint line length violations in AppDelegate.swift lines 588-600"
"Replace all print statements with Logger in SettingsWindow.swift"
```

### 2. Use Composer for Refactoring
```
"Break the setupUI() function into smaller helper functions"
"Extract the profile management section into a separate file"
```

### 3. Generate Code with Rules
```
"Create a new manager class following the Manager pattern from .cursorrules"
"Add a new cleaning rule with proper Logger integration"
```

### 4. Auto-Format on Save
Consider adding to Cursor settings:
```json
{
  "[swift]": {
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      "source.fixAll": true
    }
  }
}
```

---

## 📈 Expected Benefits

### Code Quality
- ✅ Consistent style across all files
- ✅ Catch issues before commit
- ✅ Self-documenting code standards

### Development Speed
- ✅ AI generates better Swift code
- ✅ Faster Cursor indexing
- ✅ Fewer code review issues

### Maintainability
- ✅ Easier onboarding for contributors
- ✅ Clear architectural patterns
- ✅ Better separation of concerns

---

## 🎓 Learning Resources

- [SwiftLint Rules](https://realm.github.io/SwiftLint/rule-directory.html)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Apple's Coding Guidelines](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CodingGuidelines/)

---

**Setup Date:** October 8, 2025  
**Last Updated:** October 8, 2025  
**Cursor Version:** Latest  
**SwiftLint Version:** 0.59.1





