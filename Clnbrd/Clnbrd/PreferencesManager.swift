import Foundation
import os.log

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "preferences")

class PreferencesManager {
    static let shared = PreferencesManager()
    
    private init() {}
    
    // MARK: - Cleaning Rules Persistence
    
    func saveCleaningRules(_ rules: CleaningRules) {
        UserDefaults.standard.set(rules.removeEmdashes, forKey: "RemoveEmdashes")
        UserDefaults.standard.set(rules.replaceEmdashWith, forKey: "ReplaceEmdashWith")
        UserDefaults.standard.set(rules.normalizeSpaces, forKey: "NormalizeSpaces")
        UserDefaults.standard.set(rules.removeZeroWidthChars, forKey: "RemoveZeroWidthChars")
        UserDefaults.standard.set(rules.normalizeLineBreaks, forKey: "NormalizeLineBreaks")
        UserDefaults.standard.set(rules.removeTrailingSpaces, forKey: "RemoveTrailingSpaces")
        UserDefaults.standard.set(rules.convertSmartQuotes, forKey: "ConvertSmartQuotes")
        UserDefaults.standard.set(rules.removeEmojis, forKey: "RemoveEmojis")
        UserDefaults.standard.set(rules.removeExtraLineBreaks, forKey: "RemoveExtraLineBreaks")
        UserDefaults.standard.set(rules.removeLeadingTrailingWhitespace, forKey: "RemoveLeadingTrailingWhitespace")
        UserDefaults.standard.set(rules.removeUrls, forKey: "RemoveUrls")
        UserDefaults.standard.set(rules.removeHtmlTags, forKey: "RemoveHtmlTags")
        UserDefaults.standard.set(rules.removeExtraPunctuation, forKey: "RemoveExtraPunctuation")
        
        // Save custom rules
        let customRulesData = try? JSONEncoder().encode(rules.customRules)
        UserDefaults.standard.set(customRulesData, forKey: "CustomRules")
        
        logger.info("Cleaning rules saved to UserDefaults")
    }
    
    func loadCleaningRules() -> CleaningRules {
        let rules = CleaningRules()
        
        rules.removeEmdashes = UserDefaults.standard.object(forKey: "RemoveEmdashes") as? Bool ?? true
        rules.replaceEmdashWith = UserDefaults.standard.string(forKey: "ReplaceEmdashWith") ?? ", "
        rules.normalizeSpaces = UserDefaults.standard.object(forKey: "NormalizeSpaces") as? Bool ?? true
        rules.removeZeroWidthChars = UserDefaults.standard.object(forKey: "RemoveZeroWidthChars") as? Bool ?? true
        rules.normalizeLineBreaks = UserDefaults.standard.object(forKey: "NormalizeLineBreaks") as? Bool ?? true
        rules.removeTrailingSpaces = UserDefaults.standard.object(forKey: "RemoveTrailingSpaces") as? Bool ?? true
        rules.convertSmartQuotes = UserDefaults.standard.object(forKey: "ConvertSmartQuotes") as? Bool ?? true
        rules.removeEmojis = UserDefaults.standard.object(forKey: "RemoveEmojis") as? Bool ?? false
        rules.removeExtraLineBreaks = UserDefaults.standard.object(forKey: "RemoveExtraLineBreaks") as? Bool ?? true
        rules.removeLeadingTrailingWhitespace = UserDefaults.standard.object(forKey: "RemoveLeadingTrailingWhitespace") as? Bool ?? true
        rules.removeUrls = UserDefaults.standard.object(forKey: "RemoveUrls") as? Bool ?? true
        rules.removeHtmlTags = UserDefaults.standard.object(forKey: "RemoveHtmlTags") as? Bool ?? true
        rules.removeExtraPunctuation = UserDefaults.standard.object(forKey: "RemoveExtraPunctuation") as? Bool ?? true
        
        // Load custom rules
        if let customRulesData = UserDefaults.standard.data(forKey: "CustomRules"),
           let customRules = try? JSONDecoder().decode([CustomRule].self, from: customRulesData) {
            rules.customRules = customRules
        }
        
        logger.info("Cleaning rules loaded from UserDefaults")
        return rules
    }
    
    // MARK: - App Settings Persistence
    
    func saveAutoCleanEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "AutoCleanEnabled")
        logger.info("Auto-clean setting saved: \(enabled)")
    }
    
    func loadAutoCleanEnabled() -> Bool {
        let enabled = UserDefaults.standard.object(forKey: "AutoCleanEnabled") as? Bool ?? false
        logger.info("Auto-clean setting loaded: \(enabled)")
        return enabled
    }
    
    func saveSkippedVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: "SkippedVersion")
        logger.info("Skipped version saved: \(version)")
    }
    
    func loadSkippedVersion() -> String? {
        let version = UserDefaults.standard.string(forKey: "SkippedVersion")
        logger.info("Skipped version loaded: \(version ?? "none")")
        return version
    }
    
    func saveFirstLaunchCompleted() {
        UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        logger.info("First launch completed flag saved")
    }
    
    func loadFirstLaunchCompleted() -> Bool {
        let completed = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        logger.info("First launch completed: \(completed)")
        return completed
    }
    
    // MARK: - Reset Preferences
    
    func resetAllPreferences() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        logger.info("All preferences reset")
    }
}
