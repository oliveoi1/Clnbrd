import Cocoa
import os.log
import IOKit.hid

/// Manages onboarding state and window presentation
class OnboardingManager {
    static let shared = OnboardingManager()
    
    private let logger = Logger(subsystem: "com.allanalomes.Clnbrd", category: "OnboardingManager")
    private var onboardingWindow: OnboardingWindow?
    
    private init() {}
    
    // MARK: - State
    
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }
    
    var onboardingVersion: Int {
        get { UserDefaults.standard.integer(forKey: "onboardingVersion") }
        set { UserDefaults.standard.set(newValue, forKey: "onboardingVersion") }
    }
    
    var hasGrantedAccessibility: Bool {
        return AXIsProcessTrusted()
    }
    
    var hasGrantedInputMonitoring: Bool {
        // Check Input Monitoring permission via IOKit
        let accessGranted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        
        // kIOHIDAccessTypeGranted = 0, kIOHIDAccessTypeDenied = 1, kIOHIDAccessTypeUnknown = 2
        let isGranted = accessGranted == kIOHIDAccessTypeGranted
        logger.info("Input Monitoring access: \(isGranted ? "granted" : "not granted")")
        return isGranted
    }
    
    // MARK: - Presentation
    
    /// Show onboarding if needed (first launch)
    func showOnboardingIfNeeded() {
        guard !hasCompletedOnboarding else {
            logger.info("Onboarding already completed, skipping")
            return
        }
        
        logger.info("First launch detected, showing onboarding")
        showOnboarding(canDismiss: true)
    }
    
    /// Show onboarding window (can be triggered manually from Help menu)
    func showOnboarding(canDismiss: Bool = true) {
        logger.info("🎓 Showing onboarding window (canDismiss: \(canDismiss))")
        
        // Close existing window if any
        if let existingWindow = onboardingWindow {
            logger.info("Closing existing onboarding window")
            existingWindow.close()
            onboardingWindow = nil
        }
        
        // Create new window FIRST (before activating app)
        logger.info("Creating new OnboardingWindow...")
        let newWindow = OnboardingWindow(canDismiss: canDismiss)
        onboardingWindow = newWindow
        
        logger.info("Window created, frame: \(NSStringFromRect(newWindow.frame))")
        logger.info("Window level: \(newWindow.level.rawValue)")
        logger.info("Window isVisible: \(newWindow.isVisible)")
        
        // Center the window
        newWindow.center()
        logger.info("Window centered at: \(NSStringFromPoint(newWindow.frame.origin))")
        
        // Bring app to front
        NSApp.activate(ignoringOtherApps: true)
        
        // Make window key and visible
        newWindow.makeKeyAndOrderFront(nil)
        logger.info("After makeKeyAndOrderFront - isVisible: \(newWindow.isVisible), isKeyWindow: \(newWindow.isKeyWindow)")
        
        // Force to front
        newWindow.orderFrontRegardless()
        logger.info("After orderFrontRegardless - isVisible: \(newWindow.isVisible)")
        
        // Double-check visibility
        if !newWindow.isVisible {
            logger.error("⚠️ Window still not visible, trying again...")
            newWindow.orderFront(nil)
            newWindow.makeKey()
        }
        
        logger.info("✅ Onboarding window shown. Final state - isVisible: \(newWindow.isVisible), isKey: \(newWindow.isKeyWindow)")
    }
    
    /// Mark onboarding as completed
    func completeOnboarding() {
        hasCompletedOnboarding = true
        onboardingVersion = 1
        
        logger.info("✅ Onboarding completed")
        
        // Track analytics
        AnalyticsManager.shared.trackFeatureUsage("onboarding_completed")
    }
    
    /// Reset onboarding state (for testing)
    func resetOnboarding() {
        hasCompletedOnboarding = false
        onboardingVersion = 0
        logger.info("🔄 Onboarding state reset")
    }
}
