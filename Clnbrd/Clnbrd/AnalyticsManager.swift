import Foundation
import os.log

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "analytics")

enum CleaningMethod: String, Codable, CaseIterable {
    case hotkey = "hotkey"
    case autoClean = "autoClean"
    case manual = "manual"
}

struct AnalyticsData: Codable {
    var totalCleaningOperations: Int = 0
    var totalHotkeyUses: Int = 0
    var totalAutoCleanOperations: Int = 0
    var totalManualCleanOperations: Int = 0
    var totalUpdateChecks: Int = 0
    var totalErrors: Int = 0
    var cleaningRulesUsage: [String: Int] = [:]
    var errorTypes: [String: Int] = [:]
    var sessionCount: Int = 0
    var firstLaunchDate: Date?
    var lastLaunchDate: Date?
    var appVersion: String = ""
    
    // Privacy-focused: No personal data, only aggregated usage patterns
}

class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private var analyticsData = AnalyticsData()
    private let analyticsKey = "ClnbrdAnalytics"
    private let maxDataAge: TimeInterval = 365 * 24 * 60 * 60 // 1 year
    
    private init() {
        loadAnalytics()
        analyticsData.sessionCount += 1
        analyticsData.lastLaunchDate = Date()
        analyticsData.appVersion = VersionManager.version
        
        if analyticsData.firstLaunchDate == nil {
            analyticsData.firstLaunchDate = Date()
        }
        
        logger.info("Analytics initialized - Session #\(self.analyticsData.sessionCount)")
    }
    
    // MARK: - Data Collection
    
    func trackCleaningOperation(rule: String, method: CleaningMethod) {
        analyticsData.totalCleaningOperations += 1
        
        switch method {
        case .hotkey:
            analyticsData.totalHotkeyUses += 1
        case .autoClean:
            analyticsData.totalAutoCleanOperations += 1
        case .manual:
            analyticsData.totalManualCleanOperations += 1
        }
        
        // Track which cleaning rules are used
        analyticsData.cleaningRulesUsage[rule, default: 0] += 1
        
        saveAnalytics()
        logger.debug("Cleaning operation tracked: \(rule) via \(method.rawValue)")
    }
    
    func trackUpdateCheck(success: Bool) {
        analyticsData.totalUpdateChecks += 1
        
        if !success {
            analyticsData.totalErrors += 1
            analyticsData.errorTypes["UpdateCheckFailed", default: 0] += 1
        }
        
        saveAnalytics()
        logger.debug("Update check tracked: \(success ? "success" : "failed")")
    }
    
    func trackError(_ error: String, context: String) {
        analyticsData.totalErrors += 1
        analyticsData.errorTypes["\(context):\(error)", default: 0] += 1
        
        saveAnalytics()
        logger.error("Error tracked: \(error) in \(context)")
    }
    
    func trackFeatureUsage(_ feature: String) {
        analyticsData.cleaningRulesUsage[feature, default: 0] += 1
        saveAnalytics()
        logger.debug("Feature usage tracked: \(feature)")
    }
    
    // MARK: - Data Management
    
    private func loadAnalytics() {
        if let data = UserDefaults.standard.data(forKey: analyticsKey),
           let decoded = try? JSONDecoder().decode(AnalyticsData.self, from: data) {
            analyticsData = decoded
            
            // Clean old data
            if let firstLaunch = analyticsData.firstLaunchDate,
               Date().timeIntervalSince(firstLaunch) > maxDataAge {
                resetAnalytics()
            }
        }
    }
    
    private func saveAnalytics() {
        if let data = try? JSONEncoder().encode(analyticsData) {
            UserDefaults.standard.set(data, forKey: analyticsKey)
        }
    }
    
    func resetAnalytics() {
        analyticsData = AnalyticsData()
        analyticsData.sessionCount = 1
        analyticsData.firstLaunchDate = Date()
        analyticsData.lastLaunchDate = Date()
        analyticsData.appVersion = VersionManager.version
        
        UserDefaults.standard.removeObject(forKey: analyticsKey)
        logger.info("Analytics data reset")
    }
    
    // MARK: - Data Export (for debugging/insights)
    
    func getAnalyticsSummary() -> String {
        let daysSinceFirstLaunch = analyticsData.firstLaunchDate?.timeIntervalSinceNow.magnitude ?? 0
        let daysSinceFirstLaunchFormatted = Int(daysSinceFirstLaunch / (24 * 60 * 60))
        
        let summary = """
        Clnbrd Analytics Summary
        =======================
        
        Sessions: \(analyticsData.sessionCount)
        Days since first launch: \(daysSinceFirstLaunchFormatted)
        App version: \(analyticsData.appVersion)
        
        Usage Statistics:
        • Total cleaning operations: \(analyticsData.totalCleaningOperations)
        • Hotkey uses: \(analyticsData.totalHotkeyUses)
        • Auto-clean operations: \(analyticsData.totalAutoCleanOperations)
        • Manual clean operations: \(analyticsData.totalManualCleanOperations)
        • Update checks: \(analyticsData.totalUpdateChecks)
        • Total errors: \(analyticsData.totalErrors)
        
        Most Used Cleaning Rules:
        \(getTopCleaningRules())
        
        Error Summary:
        \(getErrorSummary())
        """
        
        return summary
    }
    
    private func getTopCleaningRules() -> String {
        let sortedRules = analyticsData.cleaningRulesUsage.sorted { $0.value > $1.value }
        let topRules = sortedRules.prefix(5)
        
        return topRules.map { "• \($0.key): \($0.value) times" }.joined(separator: "\n")
    }
    
    private func getErrorSummary() -> String {
        let sortedErrors = analyticsData.errorTypes.sorted { $0.value > $1.value }
        let topErrors = sortedErrors.prefix(3)
        
        if topErrors.isEmpty {
            return "• No errors recorded"
        }
        
        return topErrors.map { "• \($0.key): \($0.value) times" }.joined(separator: "\n")
    }
    
    // MARK: - Privacy Controls
    
    func isAnalyticsEnabled() -> Bool {
        return UserDefaults.standard.object(forKey: "AnalyticsEnabled") as? Bool ?? true
    }
    
    func setAnalyticsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "AnalyticsEnabled")
        
        if !enabled {
            resetAnalytics()
        }
        
        logger.info("Analytics \(enabled ? "enabled" : "disabled")")
    }
}
