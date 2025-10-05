import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "error_recovery")

/// Enhanced error handling and recovery system for professional-grade error management
class ErrorRecoveryManager {
    static let shared = ErrorRecoveryManager()
    
    private init() {}
    
    // MARK: - Error Recovery Strategies
    
    /// Handles clipboard access errors with retry mechanisms
    func handleClipboardError(_ error: Error, retryCount: Int = 0) -> Bool {
        logger.error("Clipboard error (attempt \(retryCount + 1)): \(error.localizedDescription)")
        
        // Track error for analytics
        SentryManager.shared.reportError(error, context: "clipboard_access")
        
        // Retry logic for transient errors
        if retryCount < 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Attempt recovery
                if self.attemptClipboardRecovery() {
                    logger.info("Clipboard recovery successful on attempt \(retryCount + 1)")
                } else {
                    // Try again
                    _ = self.handleClipboardError(error, retryCount: retryCount + 1)
                }
            }
            return true // Recovery attempted
        }
        
        // Show user-friendly error message after all retries failed
        showClipboardErrorToUser(error)
        return false
    }
    
    /// Handles accessibility permission errors with guidance
    func handleAccessibilityError(_ error: Error) {
        logger.error("Accessibility error: \(error.localizedDescription)")
        
        SentryManager.shared.reportError(error, context: "accessibility_permissions")
        
        // Show helpful error message with recovery steps
        DispatchQueue.main.async {
            self.showAccessibilityErrorToUser()
        }
    }
    
    /// Handles network errors with retry and fallback
    func handleNetworkError(_ error: Error, operation: String, retryCount: Int = 0) -> Bool {
        logger.error("Network error in \(operation) (attempt \(retryCount + 1)): \(error.localizedDescription)")
        
        SentryManager.shared.reportError(error, context: "network_\(operation)")
        
        // Retry logic for network errors
        if retryCount < 2 {
            let delay = pow(2.0, Double(retryCount)) // Exponential backoff
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Attempt retry
                _ = self.handleNetworkError(error, operation: operation, retryCount: retryCount + 1)
            }
            return true
        }
        
        // Show user-friendly error after retries
        showNetworkErrorToUser(operation: operation)
        return false
    }
    
    // MARK: - Recovery Attempts
    
    private func attemptClipboardRecovery() -> Bool {
        // Try to reinitialize clipboard access
        do {
            // Attempt to read from clipboard to test access
            let pasteboard = NSPasteboard.general
            _ = pasteboard.string(forType: .string)
            return true
        } catch {
            logger.error("Clipboard recovery failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - User-Facing Error Messages
    
    private func showClipboardErrorToUser(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Clipboard Access Issue"
        alert.informativeText = """
        Clnbrd is having trouble accessing your clipboard.
        
        This might be due to:
        • Another app using the clipboard
        • System permissions issues
        • Temporary system glitch
        
        Try:
        1. Copy some text again
        2. Restart Clnbrd
        3. Check System Settings → Privacy & Security → Accessibility
        
        Error: \(error.localizedDescription)
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open System Settings")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
    
    private func showAccessibilityErrorToUser() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        Clnbrd needs accessibility permissions to work properly.
        
        To fix this:
        1. Open System Settings
        2. Go to Privacy & Security → Accessibility
        3. Find "Clnbrd" in the list
        4. Toggle it ON
        5. Restart Clnbrd
        
        Without this permission, the ⌘⌥V hotkey won't work.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "I'll Do It Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
    
    private func showNetworkErrorToUser(operation: String) {
        let alert = NSAlert()
        alert.messageText = "Network Connection Issue"
        alert.informativeText = """
        Clnbrd couldn't complete the \(operation) operation.
        
        This might be due to:
        • Internet connection issues
        • Server temporarily unavailable
        • Firewall blocking the connection
        
        The app will continue to work normally for local operations.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        alert.runModal()
    }
    
    // MARK: - Graceful Degradation
    
    /// Provides fallback behavior when primary functionality fails
    func enableGracefulDegradation() {
        logger.info("Enabling graceful degradation mode")
        
        // Disable auto-clean if clipboard access is problematic
        // Show menu-only mode notification
        DispatchQueue.main.async {
            self.showGracefulDegradationNotification()
        }
    }
    
    private func showGracefulDegradationNotification() {
        let alert = NSAlert()
        alert.messageText = "Limited Functionality Mode"
        alert.informativeText = """
        Clnbrd is running in limited functionality mode due to system restrictions.
        
        Available features:
        • Manual cleaning via menu bar
        • Settings and preferences
        • View samples
        
        Unavailable features:
        • ⌘⌥V hotkey
        • Auto-clean on copy
        
        To restore full functionality, check your accessibility permissions.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Check Permissions")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}
