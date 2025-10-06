//
//  CleaningRuleConfiguration.swift
//  Clnbrd
//
//  Granular configuration for when cleaning rules apply
//  Created by Allan Alomes on 10/6/2025.
//

import Foundation

/// When a cleaning rule should be applied
enum RuleApplicationMode: String, Codable {
    case onHotkeyOnly = "hotkey"     // Only when user presses ⌘⌥V
    case autoClean = "auto"           // Automatically on every copy
    case disabled = "disabled"        // Never apply this rule
}

/// Configuration for a specific cleaning rule
struct RuleConfig: Codable {
    let ruleId: String
    var mode: RuleApplicationMode
    var enabled: Bool  // Master toggle
    
    init(ruleId: String, mode: RuleApplicationMode = .onHotkeyOnly, enabled: Bool = true) {
        self.ruleId = ruleId
        self.mode = mode
        self.enabled = enabled
    }
    
    /// Should this rule apply when using the hotkey?
    var appliesOnHotkey: Bool {
        return enabled && (mode == .onHotkeyOnly || mode == .autoClean)
    }
    
    /// Should this rule apply automatically on copy?
    var appliesOnAutoCopy: Bool {
        return enabled && mode == .autoClean
    }
}

/// All available cleaning rules with their configurations
class CleaningRuleConfigurations {
    static let shared = CleaningRuleConfigurations()
    
    // MARK: - Rule Definitions
    
    enum RuleID: String, CaseIterable {
        // Text Formatting Rules
        case removeFormatting = "remove_formatting"
        case removeEmdashes = "remove_emdashes"
        case normalizeSpaces = "normalize_spaces"
        case removeZeroWidthChars = "remove_zero_width"
        case normalizeLineBreaks = "normalize_line_breaks"
        case removeTrailingSpaces = "remove_trailing_spaces"
        case convertSmartQuotes = "convert_smart_quotes"
        case removeEmojis = "remove_emojis"
        case removeExtraLineBreaks = "remove_extra_line_breaks"
        case removeLeadingTrailingWhitespace = "remove_leading_trailing_whitespace"
        case removeHtmlTags = "remove_html_tags"
        
        // URL Cleaning Rules
        case cleanURLTracking = "clean_url_tracking"
        
        var displayName: String {
            switch self {
            case .removeFormatting: return "Remove All Formatting"
            case .removeEmdashes: return "Remove Em-dashes"
            case .normalizeSpaces: return "Normalize Spaces"
            case .removeZeroWidthChars: return "Remove Zero-Width Characters"
            case .normalizeLineBreaks: return "Normalize Line Breaks"
            case .removeTrailingSpaces: return "Remove Trailing Spaces"
            case .convertSmartQuotes: return "Convert Smart Quotes"
            case .removeEmojis: return "Remove Emojis"
            case .removeExtraLineBreaks: return "Remove Extra Line Breaks"
            case .removeLeadingTrailingWhitespace: return "Trim Whitespace"
            case .removeHtmlTags: return "Remove HTML Tags"
            case .cleanURLTracking: return "Clean Tracking from URLs"
            }
        }
        
        var description: String {
            switch self {
            case .removeFormatting: return "Strips all text formatting, styles, and fonts"
            case .removeEmdashes: return "Replaces — with commas or spaces"
            case .normalizeSpaces: return "Collapses multiple spaces into one"
            case .removeZeroWidthChars: return "Removes invisible Unicode characters"
            case .normalizeLineBreaks: return "Standardizes line endings"
            case .removeTrailingSpaces: return "Removes spaces at end of lines"
            case .convertSmartQuotes: return "Converts smart quotes to regular quotes"
            case .removeEmojis: return "Strips all emoji characters"
            case .removeExtraLineBreaks: return "Removes blank lines"
            case .removeLeadingTrailingWhitespace: return "Trims start and end whitespace"
            case .removeHtmlTags: return "Removes <html> tags"
            case .cleanURLTracking: return "Removes UTM, fbclid, and tracking parameters from URLs"
            }
        }
        
        var category: RuleCategory {
            switch self {
            case .removeFormatting, .removeEmdashes, .normalizeSpaces, .removeZeroWidthChars,
                 .normalizeLineBreaks, .removeTrailingSpaces, .convertSmartQuotes, 
                 .removeEmojis, .removeExtraLineBreaks, .removeLeadingTrailingWhitespace,
                 .removeHtmlTags:
                return .textFormatting
            case .cleanURLTracking:
                return .urlCleaning
            }
        }
    }
    
    enum RuleCategory: String {
        case textFormatting = "Text Formatting"
        case urlCleaning = "URL Cleaning"
    }
    
    // MARK: - Configuration Storage
    
    private var configs: [String: RuleConfig] = [:]
    
    private init() {
        loadConfigurations()
    }
    
    // MARK: - Access Methods
    
    func getConfig(for ruleId: RuleID) -> RuleConfig {
        return configs[ruleId.rawValue] ?? RuleConfig(ruleId: ruleId.rawValue)
    }
    
    func setConfig(_ config: RuleConfig) {
        configs[config.ruleId] = config
        saveConfigurations()
    }
    
    func setMode(_ mode: RuleApplicationMode, for ruleId: RuleID) {
        var config = getConfig(for: ruleId)
        config.mode = mode
        setConfig(config)
    }
    
    func setEnabled(_ enabled: Bool, for ruleId: RuleID) {
        var config = getConfig(for: ruleId)
        config.enabled = enabled
        setConfig(config)
    }
    
    /// Get all rules that should apply when using hotkey
    func getRulesForHotkey() -> [RuleID] {
        return RuleID.allCases.filter { getConfig(for: $0).appliesOnHotkey }
    }
    
    /// Get all rules that should apply on auto-clean
    func getRulesForAutoCopy() -> [RuleID] {
        return RuleID.allCases.filter { getConfig(for: $0).appliesOnAutoCopy }
    }
    
    // MARK: - Persistence
    
    private func saveConfigurations() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(configs) {
            UserDefaults.standard.set(data, forKey: "CleaningRuleConfigurations")
        }
    }
    
    private func loadConfigurations() {
        guard let data = UserDefaults.standard.data(forKey: "CleaningRuleConfigurations"),
              let decoded = try? JSONDecoder().decode([String: RuleConfig].self, from: data) else {
            // Set defaults
            setDefaultConfigurations()
            return
        }
        configs = decoded
    }
    
    private func setDefaultConfigurations() {
        // Text formatting rules: Apply on hotkey only by default
        for rule in [RuleID.removeFormatting, .removeEmdashes, .normalizeSpaces, 
                     .removeZeroWidthChars, .normalizeLineBreaks, .removeTrailingSpaces,
                     .convertSmartQuotes, .removeExtraLineBreaks, 
                     .removeLeadingTrailingWhitespace, .removeHtmlTags] {
            configs[rule.rawValue] = RuleConfig(ruleId: rule.rawValue, mode: .onHotkeyOnly, enabled: true)
        }
        
        // Emoji removal: Off by default
        configs[RuleID.removeEmojis.rawValue] = RuleConfig(
            ruleId: RuleID.removeEmojis.rawValue, 
            mode: .onHotkeyOnly, 
            enabled: false
        )
        
        // URL tracking: On hotkey only, enabled
        configs[RuleID.cleanURLTracking.rawValue] = RuleConfig(
            ruleId: RuleID.cleanURLTracking.rawValue, 
            mode: .onHotkeyOnly, 
            enabled: true
        )
        
        saveConfigurations()
    }
    
    // MARK: - Convenience Methods
    
    /// Quick check if URL cleaning is enabled for hotkey
    var isURLCleaningEnabledForHotkey: Bool {
        return getConfig(for: .cleanURLTracking).appliesOnHotkey
    }
    
    /// Quick check if URL cleaning is enabled for auto-copy
    var isURLCleaningEnabledForAutoCopy: Bool {
        return getConfig(for: .cleanURLTracking).appliesOnAutoCopy
    }
    
    /// Get grouped rules by category for UI display
    func getRulesByCategory() -> [RuleCategory: [RuleID]] {
        var grouped: [RuleCategory: [RuleID]] = [:]
        for rule in RuleID.allCases {
            grouped[rule.category, default: []].append(rule)
        }
        return grouped
    }
}

