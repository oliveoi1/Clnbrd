import Foundation
import Sentry
import os.log

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "sentry")

class SentryManager {
    static let shared = SentryManager()
    
    private init() {}
    
    func initialize() {
        // Initialize Sentry SDK
        SentrySDK.start { options in
            // Your actual Sentry DSN
            options.dsn = "https://6a8ed4b3ddf836bf196efbb890f5c713@o4510128805249024.ingest.us.sentry.io/4510128808656896"
            options.environment = "production"
            options.releaseName = VersionManager.version
            
            // Enable crash reporting
            options.enableCrashHandler = true
            
            // Set sample rate for performance monitoring (10%)
            options.tracesSampleRate = 0.1
            
            // Enable automatic session tracking
            options.enableAutoSessionTracking = true
            
            // Set debug mode (disable in production)
            options.debug = false
        }
        
        // Configure user context
        SentrySDK.configureScope { scope in
            scope.setContext(value: [
                "app_name": "Clnbrd",
                "app_version": VersionManager.version,
                "build_number": VersionManager.buildNumber,
                "macos_version": ProcessInfo.processInfo.operatingSystemVersionString,
                "hardware_model": self.getHardwareModel(),
                "is_first_launch": !UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
            ], key: "app_info")
            
            // Set user context (anonymous)
            scope.setUser(User(userId: self.generateAnonymousUserId()))
        }
        
        // Add breadcrumb for app launch
        addBreadcrumb(message: "App launched", category: "lifecycle", level: .info)
    }
    
    // MARK: - Error Reporting
    
    func reportError(_ error: Error, context: String, additionalInfo: [String: Any] = [:]) {
        // Log locally
        logger.error("Error in \(context): \(error.localizedDescription)")
        
        // Track in analytics
        AnalyticsManager.shared.trackError(error.localizedDescription, context: context)
        
        // Report to Sentry
        SentrySDK.capture(error: error) { scope in
            scope.setTag(value: context, key: "error_context")
            scope.setLevel(.error)
            
            // Add additional context
            if !additionalInfo.isEmpty {
                scope.setContext(value: additionalInfo, key: "additional_info")
            }
            
            // Add breadcrumb
            let crumb = Breadcrumb()
            crumb.message = "Error occurred in \(context)"
            crumb.category = "error"
            crumb.level = .error
            scope.addBreadcrumb(crumb)
        }
    }
    
    func reportCustomError(_ message: String, context: String, additionalInfo: [String: Any] = [:]) {
        let error = NSError(domain: "com.allanray.Clnbrd", code: -1, userInfo: [
            NSLocalizedDescriptionKey: message
        ])
        
        reportError(error, context: context, additionalInfo: additionalInfo)
    }
    
    // MARK: - Breadcrumb Tracking
    
    func addBreadcrumb(message: String, category: String, level: SentryLevel = .info, data: [String: Any] = [:]) {
        let crumb = Breadcrumb()
        crumb.message = message
        crumb.category = category
        crumb.level = level
        
        for (key, value) in data {
            crumb.data?[key] = value as? String ?? String(describing: value)
        }
        
        SentrySDK.addBreadcrumb(crumb)
    }
    
    // MARK: - Performance Monitoring
    
    func startTransaction(name: String, operation: String) -> Span {
        return SentrySDK.startTransaction(name: name, operation: operation)
    }
    
    // MARK: - User Actions
    
    func trackUserAction(_ action: String, data: [String: Any] = [:]) {
        addBreadcrumb(message: "User action: \(action)", category: "user_action", level: .info, data: data)
    }
    
    // MARK: - Helper Methods
    
    private func getHardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    private func generateAnonymousUserId() -> String {
        let key = "AnonymousUserId"
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        }
        
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
    
    // MARK: - Testing
    
    func testCrashReporting() {
        // This will trigger a test error for Sentry
        reportCustomError("Test error for Sentry integration", context: "testing")
    }
}
