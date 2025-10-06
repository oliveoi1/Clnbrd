# Preferences UI Design - Granular Rule Control

## Overview

New preferences system allows users to configure **when** each cleaning rule applies:
- **On Hotkey Only** (⌘⌥V) - Manual cleaning when pasting
- **Auto-Clean** - Automatic cleaning on every copy
- **Disabled** - Don't apply this rule

## UI Layout

### Preferences Window/Panel

```
┌────────────────────────────────────────────────────────────────┐
│  Clnbrd Preferences                                            │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ Text Formatting Rules                                    │ │
│  ├──────────────────────────────────────────────────────────┤ │
│  │                                                          │ │
│  │  Rule Name                    On Hotkey    Auto-Clean   │ │
│  │  ───────────────────────────  ──────────   ──────────   │ │
│  │  ☑ Remove All Formatting        ◉             ○         │ │
│  │  ☑ Remove Em-dashes             ◉             ○         │ │
│  │  ☑ Normalize Spaces             ◉             ○         │ │
│  │  ☑ Remove Zero-Width Chars      ◉             ○         │ │
│  │  ☑ Normalize Line Breaks        ◉             ○         │ │
│  │  ☑ Convert Smart Quotes         ◉             ○         │ │
│  │  ☑ Remove Extra Line Breaks     ◉             ○         │ │
│  │  ☑ Trim Whitespace              ◉             ○         │ │
│  │  ☑ Remove HTML Tags             ◉             ○         │ │
│  │  ☐ Remove Emojis                ◉             ○         │ │
│  │                                                          │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ URL Cleaning Rules                                       │ │
│  ├──────────────────────────────────────────────────────────┤ │
│  │                                                          │ │
│  │  ☑ Clean Tracking from URLs     ◉             ○         │ │
│  │     Removes UTM, fbclid, affiliate links                │ │
│  │     • YouTube ?si= tracking                             │ │
│  │     • Amazon affiliate tags                             │ │
│  │     • Instagram, Twitter, TikTok tracking               │ │
│  │                                                          │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ℹ️  On Hotkey: Applies when you press ⌘⌥V to paste           │
│  ℹ️  Auto-Clean: Applies automatically when you copy          │
│                                                                 │
│                                    [Reset to Defaults] [Done]  │
└────────────────────────────────────────────────────────────────┘
```

## Interactive Elements

### Master Checkbox (Left Column)
- ☑ **Enabled** - Rule is active
- ☐ **Disabled** - Rule is completely off (grays out radio buttons)

### Application Mode (Right Columns)
**Radio Button Behavior:**
- **◉ On Hotkey** - Rule applies only when user presses ⌘⌥V
- **◉ Auto-Clean** - Rule applies automatically on every copy
- Only ONE can be selected (radio button group per rule)
- Disabled if master checkbox is unchecked

## User Workflows

### Scenario 1: Conservative User
"I want control - only clean when I explicitly paste cleaned"

**Configuration:**
```
☑ Remove Formatting       ◉ On Hotkey    ○ Auto-Clean
☑ Clean URL Tracking      ◉ On Hotkey    ○ Auto-Clean
```

**Behavior:**
- Normal copy (⌘C): No changes, clipboard unchanged
- Paste with hotkey (⌘⌥V): Applies all rules, pastes cleaned
- Regular paste (⌘V): Pastes original, uncleaned text

### Scenario 2: Power User
"I want my clipboard always clean"

**Configuration:**
```
☑ Remove Formatting       ○ On Hotkey    ◉ Auto-Clean
☑ Clean URL Tracking      ○ On Hotkey    ◉ Auto-Clean
```

**Behavior:**
- Copy (⌘C): Immediately cleans and stores cleaned version
- Any paste (⌘V or ⌘⌥V): Pastes the already-cleaned text
- Clipboard always contains cleaned text

### Scenario 3: Hybrid User
"Clean text automatically, but URLs only when I want"

**Configuration:**
```
☑ Remove Formatting       ○ On Hotkey    ◉ Auto-Clean
☑ Clean URL Tracking      ◉ On Hotkey    ○ Auto-Clean
```

**Behavior:**
- Copy text with URLs: Text cleaned immediately, URLs unchanged
- Paste normally (⌘V): Gets cleaned text with original URLs
- Paste with hotkey (⌘⌥V): Gets cleaned text AND cleaned URLs

### Scenario 4: Selective Cleaning
"I only want URL cleaning, keep my text as-is"

**Configuration:**
```
☐ Remove Formatting       ◉ On Hotkey    ○ Auto-Clean  [grayed out]
☑ Clean URL Tracking      ◉ On Hotkey    ○ Auto-Clean
```

**Behavior:**
- Copy: No text formatting changes
- Paste with hotkey (⌘⌥V): Only URLs are cleaned
- Regular paste (⌘V): Original text with original URLs

## Implementation Details

### SwiftUI View Structure

```swift
struct PreferencesView: View {
    @StateObject private var ruleConfigs = CleaningRuleConfigurations.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            Text("Cleaning Rules")
                .font(.title2)
                .bold()
            
            // Text Formatting Section
            RuleCategoryView(
                category: .textFormatting,
                rules: ruleConfigs.getRulesByCategory()[.textFormatting] ?? []
            )
            
            // URL Cleaning Section
            RuleCategoryView(
                category: .urlCleaning,
                rules: ruleConfigs.getRulesByCategory()[.urlCleaning] ?? []
            )
            
            // Help Text
            HelpTextView()
            
            // Buttons
            HStack {
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                Spacer()
                Button("Done") {
                    closeWindow()
                }
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }
}

struct RuleRowView: View {
    let rule: CleaningRuleConfigurations.RuleID
    @State private var config: RuleConfig
    
    var body: some View {
        HStack {
            // Master enable/disable checkbox
            Toggle(rule.displayName, isOn: $config.enabled)
                .toggleStyle(CheckboxToggleStyle())
            
            Spacer()
            
            // Application mode radio buttons
            RadioButton(
                title: "On Hotkey",
                isSelected: config.mode == .onHotkeyOnly,
                action: { config.mode = .onHotkeyOnly }
            )
            .disabled(!config.enabled)
            
            RadioButton(
                title: "Auto-Clean",
                isSelected: config.mode == .autoClean,
                action: { config.mode = .autoClean }
            )
            .disabled(!config.enabled)
        }
        .opacity(config.enabled ? 1.0 : 0.5)
    }
}
```

### Menu Bar Quick Toggle

Add to menu bar for quick access:

```
┌────────────────────────────────┐
│ Paste Cleaned        ⌘⌥V       │
│ Clean Clipboard Now            │
│ ────────────────────────────── │
│ Auto-Clean Mode:               │
│   ○ Off (Hotkey Only)          │
│   ◉ Text Only                  │
│   ○ Text + URLs                │
│   ○ Everything                 │
│ ────────────────────────────── │
│ Preferences...                 │
│ ────────────────────────────── │
│ Check for Updates              │
│ About Clnbrd                   │
│ Quit                       ⌘Q  │
└────────────────────────────────┘
```

## Visual Design Guidelines

### Colors
- **Enabled rule**: Primary text color (#000000)
- **Disabled rule**: Gray text (#888888)
- **Selected radio**: Accent color (blue)
- **Unselected radio**: Border only

### Spacing
- Section padding: 16px
- Rule row height: 32px
- Section spacing: 24px
- Radio button spacing: 16px

### Typography
- Section headers: 18pt Bold
- Rule names: 13pt Regular
- Help text: 11pt Regular
- Descriptions: 11pt Italic, Gray

## Accessibility

### VoiceOver Support
```
"Remove All Formatting, checkbox, checked"
"Application mode: On Hotkey, radio button, selected"
"Application mode: Auto-Clean, radio button, not selected"
```

### Keyboard Navigation
- **Tab**: Move between rules
- **Space**: Toggle checkbox
- **Arrow Keys**: Select radio button
- **⌘W**: Close preferences
- **⌘R**: Reset to defaults

## Default Configuration

**On First Launch:**
```
Text Formatting Rules:
  ☑ Remove All Formatting       ◉ On Hotkey    ○ Auto-Clean
  ☑ Other text rules...         ◉ On Hotkey    ○ Auto-Clean
  ☐ Remove Emojis               ◉ On Hotkey    ○ Auto-Clean  [disabled]

URL Cleaning Rules:
  ☑ Clean URL Tracking          ◉ On Hotkey    ○ Auto-Clean
```

**Rationale:**
- Conservative default: Users must explicitly trigger cleaning
- No surprises: Clipboard doesn't change without user action
- Users can opt-in to auto-clean for specific rules they trust

## Migration from Old System

**Old Setting:**
- "Auto-clean on copy" (boolean)

**Migration:**
```swift
if oldAutoCleanEnabled {
    // Set all enabled rules to Auto-Clean mode
    for rule in enabledRules {
        setMode(.autoClean, for: rule)
    }
} else {
    // Set all to On Hotkey Only (new default)
    for rule in enabledRules {
        setMode(.onHotkeyOnly, for: rule)
    }
}
```

## Future Enhancements

### Advanced Mode Toggle
Show additional options for power users:
- Custom regex patterns
- Rule execution order
- Per-app rule profiles
- Statistics (rules applied count)

### Quick Presets
```
Preset buttons at top:
[Hotkey Only] [Auto-Clean All] [Hybrid] [Custom]
```

### Rule Statistics
Show usage data:
```
☑ Clean URL Tracking    ◉ On Hotkey    ○ Auto-Clean
   ↳ Applied 1,234 times this month
```

---

**Status:** Design complete, ready for implementation  
**Next Steps:** 
1. Implement `CleaningRuleConfiguration.swift` ✅
2. Build SwiftUI preferences view
3. Update ClipboardManager to respect modes
4. Test all user workflows

