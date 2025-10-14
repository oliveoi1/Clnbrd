import Cocoa
import os.log
import IOKit.hid
import ServiceManagement

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "menubar")

class MenuBarManager {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var eventMonitor: Any?
    var historyEventMonitor: Any?
    var screenshotEventMonitor: Any?
    var historyWindow: ClipboardHistoryWindow?
    
    weak var delegate: MenuBarManagerDelegate?
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.isVisible = true
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.plaintext", accessibilityDescription: "Clipboard Cleaner")
            button.imagePosition = .imageLeft
            
            // Enhancement #4: Add material effect to menu bar button
            setupMenuBarButtonMaterialEffect(button)
        }
        
        menu = NSMenu()
        // Enhancement #4: Enable menu to use modern appearance
        menu.minimumWidth = 250  // Wider for better visual hierarchy
        
        // Main actions section with enhanced visual hierarchy
        let pasteItem = NSMenuItem(title: "Paste Cleaned", action: #selector(cleanAndPaste), keyEquivalent: "")
        pasteItem.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Paste cleaned text")
        pasteItem.target = self
        pasteItem.tag = 100  // Tag for paste item
        // Enhancement #4: Add emphasis to primary action
        if #available(macOS 11.0, *) {
            pasteItem.image?.isTemplate = true
        }
        menu.addItem(pasteItem)
        
        let cleanItem = NSMenuItem(title: "Clean Clipboard Now", action: #selector(cleanClipboardManually), keyEquivalent: "c")
        cleanItem.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Clean clipboard")
        cleanItem.target = self
        menu.addItem(cleanItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let screenshotItem = NSMenuItem(title: "Capture Screenshot", action: #selector(captureScreenshotToHistory), keyEquivalent: "")
        screenshotItem.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Capture screenshot")
        screenshotItem.target = self
        screenshotItem.tag = 101  // Tag for screenshot item
        menu.addItem(screenshotItem)
        
        let historyItem = NSMenuItem(title: "Show Clipboard History", action: #selector(showClipboardHistory), keyEquivalent: "")
        historyItem.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "Show clipboard history")
        historyItem.target = self
        historyItem.tag = 999  // Tag to find and update later
        menu.addItem(historyItem)
        
        // Update badge immediately
        updateHistoryBadge()
        
        // Add separator between history and clear actions
        menu.addItem(NSMenuItem.separator())
        
        let clearHistoryItem = NSMenuItem(title: "Clear Clipboard History", action: #selector(clearClipboardHistory), keyEquivalent: "")
        clearHistoryItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Clear clipboard history")
        clearHistoryItem.target = self
        menu.addItem(clearHistoryItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let autoCleanItem = NSMenuItem(title: "Auto-clean on Copy", action: #selector(toggleAutoClean), keyEquivalent: "")
        autoCleanItem.image = NSImage(systemSymbolName: "arrow.clockwise.circle", accessibilityDescription: "Auto-clean toggle")
        autoCleanItem.target = self
        autoCleanItem.state = delegate?.isAutoCleanEnabled() ?? false ? .on : .off
        menu.addItem(autoCleanItem)
        
        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.image = NSImage(systemSymbolName: "power.circle", accessibilityDescription: "Launch at login")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Secondary actions
        let updateItem = NSMenuItem(title: "Check for Updates", action: #selector(checkForUpdatesManually), keyEquivalent: "u")
        updateItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Check for updates")
        updateItem.target = self
        menu.addItem(updateItem)
        
        let shareAppItem = NSMenuItem(title: "Share Clnbrd", action: #selector(shareApp), keyEquivalent: "")
        shareAppItem.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share app")
        shareAppItem.target = self
        menu.addItem(shareAppItem)
        
        let aboutItem = NSMenuItem(title: "About Clnbrd", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings and Quit
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // Show Welcome Screen
        let welcomeItem = NSMenuItem(title: "Show Welcome Screen", action: #selector(showWelcomeScreen), keyEquivalent: "")
        welcomeItem.image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: "Welcome")
        welcomeItem.target = self
        menu.addItem(welcomeItem)
        
        #if DEBUG
        // Debug: Reset Onboarding (only in debug builds)
        let resetItem = NSMenuItem(title: "🔄 Reset Onboarding (Debug)", action: #selector(resetOnboarding), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        #endif
        
        // Separator before Quit
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        
        logger.info("Menu bar setup completed")
    }
    
    func registerHotKey() {
        logger.info("🔍 Starting hotkey registration...")
        
        // Check if we have Input Monitoring permission
        let hasInputMonitoring = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        logger.info("🔍 Input Monitoring permission: \(hasInputMonitoring == kIOHIDAccessTypeGranted ? "GRANTED" : "NOT GRANTED")")
        
        // Request Input Monitoring permission if not granted
        if hasInputMonitoring != kIOHIDAccessTypeGranted {
            logger.warning("⚠️ Input Monitoring not granted, requesting...")
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        }
        
        // Register all hotkeys using HotkeyManager
        registerAllHotkeys()
        
        logger.info("🔍 Hotkey registration completed")
    }
    
    func registerAllHotkeys() {
        // Register Clean & Paste hotkey
        HotkeyManager.shared.registerHotkey(for: .cleanAndPaste) { [weak self] in
            self?.delegate?.hotkeyTriggered()
        }
        
        // Register History hotkey
        // Initialize history window if not already done
        if historyWindow == nil {
            historyWindow = ClipboardHistoryWindow()
            
            // Observe history changes to update badge
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(historyDidChange),
                name: NSNotification.Name("ClipboardHistoryDidChange"),
                object: nil
            )
        }
        
        HotkeyManager.shared.registerHotkey(for: .showHistory) { [weak self] in
            self?.historyWindow?.toggle()
        }
        
        // Register Screenshot hotkey
        HotkeyManager.shared.registerHotkey(for: .captureScreenshot) { [weak self] in
            self?.captureScreenshotToHistory()
        }
        
        // Update menu items with current hotkey display strings
        updateMenuItemHotkeys()
        
        logger.info("All hotkeys registered with HotkeyManager")
    }
    
    func updateMenuItemHotkeys() {
        // Update menu item titles to show current hotkey configurations
        let cleanConfig = HotkeyManager.shared.getConfiguration(for: .cleanAndPaste)
        let historyConfig = HotkeyManager.shared.getConfiguration(for: .showHistory)
        let screenshotConfig = HotkeyManager.shared.getConfiguration(for: .captureScreenshot)
        
        // Update paste item (tag 100)
        if let pasteItem = menu.item(withTag: 100) {
            pasteItem.title = "Paste Cleaned (\(cleanConfig.displayString))"
        }
        
        // Update history item (tag 999)
        if let historyItem = menu.item(withTag: 999) {
            // Store current attributed title to preserve badge
            let hadBadge = historyItem.attributedTitle != nil
            historyItem.title = "Show Clipboard History (\(historyConfig.displayString))"
            historyItem.attributedTitle = nil  // Clear to allow updateHistoryBadge to work
            
            if hadBadge {
                updateHistoryBadge()  // Re-apply badge after title change
            }
        }
        
        // Update screenshot item (tag 101)
        if let screenshotItem = menu.item(withTag: 101) {
            screenshotItem.title = "Capture Screenshot (\(screenshotConfig.displayString))"
        }
    }
    
    func reloadHotkeys() {
        // Unregister all existing hotkeys
        HotkeyManager.shared.unregisterAllHotkeys()
        
        // Re-register with updated configurations
        registerAllHotkeys()
        
        logger.info("Hotkeys reloaded with updated configurations")
    }
    
    /// Captures a screenshot using interactive area selection and adds it to history
    @objc private func captureScreenshotToHistory() {
        guard ClipboardHistoryManager.shared.isEnabled else {
            logger.debug("🚫 History disabled, not capturing screenshot")
            return
        }
        
        logger.info("📸 Starting interactive screenshot capture...")
        
        // Create temporary file for screenshot
        let tempDir = FileManager.default.temporaryDirectory
        let screenshotPath = tempDir.appendingPathComponent("clnbrd_screenshot_\(UUID().uuidString).png")
        
        // Use macOS screencapture command with interactive mode (-i)
        // -i: Interactive mode (user selects area)
        // -r: Do not add shadow (cleaner screenshots)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-r", screenshotPath.path]
        
        do {
            try process.run()
            
            // Wait for screenshot capture to complete
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                process.waitUntilExit()
                
                DispatchQueue.main.async {
                    // Check if screenshot was created (user might have cancelled)
                    if FileManager.default.fileExists(atPath: screenshotPath.path) {
                        self?.processScreenshot(at: screenshotPath)
                    } else {
                        logger.info("📸 Screenshot capture cancelled by user")
                    }
                }
            }
        } catch {
            logger.error("❌ Failed to start screenshot capture: \(error.localizedDescription)")
        }
    }
    
    /// Processes a captured screenshot and adds it to history
    private func processScreenshot(at url: URL) {
        do {
            // Read screenshot data
            let imageData = try Data(contentsOf: url)
            
            // Create history item directly
            let historyItem = ClipboardHistoryItem(
                imageData: imageData,
                sourceApp: "Screenshot"
            )
            
            // Add to history
            ClipboardHistoryManager.shared.addItem(historyItem)
            
            logger.info("✅ Screenshot added to history: \(url.lastPathComponent)")
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: url)
            
            // Track analytics
            AnalyticsManager.shared.trackFeatureUsage("screenshot_capture")
        } catch {
            logger.error("❌ Failed to process screenshot: \(error.localizedDescription)")
        }
    }
    
    func updateAutoCleanState(_ enabled: Bool) {
        if let menuItem = menu.item(withTitle: "Auto-clean on Copy") {
            menuItem.state = enabled ? .on : .off
        }
    }
    
    func updateLaunchAtLoginState(_ enabled: Bool) {
        if let menuItem = menu.item(withTitle: "Launch at Login") {
            menuItem.state = enabled ? .on : .off
        }
    }
    
    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // For older macOS versions, check UserDefaults as fallback
            return UserDefaults.standard.bool(forKey: "LaunchAtLogin")
        }
    }
    
    @objc func toggleLaunchAtLogin() {
        SentryManager.shared.trackUserAction("launch_at_login_toggled")
        
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            
            do {
                if service.status == .enabled {
                    // Disable launch at login
                    try service.unregister()
                    updateLaunchAtLoginState(false)
                    logger.info("Launch at login disabled")
                } else {
                    // Enable launch at login
                    try service.register()
                    updateLaunchAtLoginState(true)
                    logger.info("Launch at login enabled")
                }
            } catch {
                logger.error("Failed to toggle launch at login: \(error.localizedDescription)")
                
                // Show alert only if it fails
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Could Not Change Launch Setting"
                    alert.informativeText = "Please try again or change it manually in System Settings > General > Login Items"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        } else {
            // Fallback for older macOS - just toggle the preference
            let currentState = UserDefaults.standard.bool(forKey: "LaunchAtLogin")
            UserDefaults.standard.set(!currentState, forKey: "LaunchAtLogin")
            updateLaunchAtLoginState(!currentState)
            
            // Show message that manual setup is needed
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Launch at Login"
                alert.informativeText = "Please add Clnbrd to Login Items manually in System Settings > General > Login Items"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    /// Sets up material effect for menu bar button (Enhancement #4)
    private func setupMenuBarButtonMaterialEffect(_ button: NSStatusBarButton) {
        button.wantsLayer = true
        
        // Add subtle material background when menu is open
        // The button already has built-in highlight, we enhance it
        button.layer?.cornerRadius = 6
        button.layer?.masksToBounds = true
        
        // Add a subtle background that becomes visible on hover/click
        let backgroundView = NSVisualEffectView(frame: button.bounds)
        backgroundView.material = .menu
        backgroundView.state = .inactive  // Only active when highlighted
        backgroundView.blendingMode = .behindWindow
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 6
        backgroundView.layer?.masksToBounds = true
        backgroundView.alphaValue = 0.0  // Hidden by default
        backgroundView.autoresizingMask = [.width, .height]
        
        // Insert behind button's image
        button.addSubview(backgroundView, positioned: .below, relativeTo: nil)
        
        // Animate on click
        button.sendAction(on: [.leftMouseDown])
        NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: menu,
            queue: .main
        ) { _ in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                backgroundView.animator().alphaValue = 0.3
                backgroundView.state = .active
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: menu,
            queue: .main
        ) { _ in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                backgroundView.animator().alphaValue = 0.0
                backgroundView.state = .inactive
            }
        }
    }
    
    @objc func cleanAndPaste() {
        SentryManager.shared.trackUserAction("hotkey_paste_triggered")
        delegate?.cleanAndPasteRequested()
    }
    
    @objc func cleanClipboardManually() {
        SentryManager.shared.trackUserAction("manual_clean_triggered")
        delegate?.cleanClipboardRequested()
    }
    
    @objc func showClipboardHistory() {
        logger.info("Show clipboard history requested from menu")
        SentryManager.shared.trackUserAction("show_history_menu_clicked")
        updateHistoryBadge()  // Update badge before showing
        historyWindow?.show()
    }
    
    /// Updates the history menu item with a badge showing the number of items
    func updateHistoryBadge() {
        guard let historyItem = menu.item(withTag: 999) else { return }
        
        let itemCount = ClipboardHistoryManager.shared.totalItems
        
        if itemCount > 0 {
            // Create attributed title with badge
            let baseTitle = "Show Clipboard History (⌘⇧H)"
            let badge = " • \(itemCount)"
            
            let attributedTitle = NSMutableAttributedString(string: baseTitle + badge)
            
            // Style the badge with secondary color and monospaced font
            let badgeRange = NSRange(location: baseTitle.count, length: badge.count)
            attributedTitle.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: badgeRange)
            attributedTitle.addAttribute(.font, value: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular), range: badgeRange)
            
            historyItem.attributedTitle = attributedTitle
        } else {
            // No items, show plain title
            historyItem.title = "Show Clipboard History (⌘⇧H)"
            historyItem.attributedTitle = nil
        }
    }
    
    @objc func clearClipboardHistory() {
        logger.info("Clear clipboard history requested from menu")
        SentryManager.shared.trackUserAction("clear_history_menu_clicked")
        
        // Show confirmation alert
        let alert = NSAlert()
        alert.messageText = "Clear Clipboard History?"
        alert.informativeText = "This will permanently delete all clipboard history items. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            ClipboardHistoryManager.shared.clearHistory()
            logger.info("✅ Clipboard history cleared from menu")
            AnalyticsManager.shared.trackFeatureUsage("history_cleared_from_menu")
            updateHistoryBadge()  // Update badge after clearing
        } else {
            logger.info("❌ Clear history cancelled by user")
        }
    }
    
    @objc func toggleAutoClean() {
        SentryManager.shared.trackUserAction("auto_clean_toggled")
        delegate?.toggleAutoCleanRequested()
    }
    
    @objc func openSettings() {
        SentryManager.shared.trackUserAction("settings_opened")
        delegate?.openSettingsRequested()
    }
    
    @objc func showWelcomeScreen() {
        logger.info("🎓 MenuBarManager.showWelcomeScreen() called")
        SentryManager.shared.trackUserAction("welcome_screen_opened")
        delegate?.showWelcomeScreenRequested()
    }
    
    #if DEBUG
    @objc func resetOnboarding() {
        OnboardingManager.shared.resetOnboarding()
        
        let alert = NSAlert()
        alert.messageText = "Onboarding Reset"
        alert.informativeText = "Onboarding has been reset. Relaunch the app to see it again, or click 'Show Welcome Screen' now."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Show Welcome Screen")
        alert.addButton(withTitle: "OK")
        
        if alert.runModal() == .alertFirstButtonReturn {
            showWelcomeScreen()
        }
    }
    #endif
    
    @objc func checkForUpdatesManually() {
        SentryManager.shared.trackUserAction("manual_update_check")
        delegate?.checkForUpdatesRequested()
    }
    
    @objc func openAbout() {
        SentryManager.shared.trackUserAction("about_opened")
        delegate?.openAboutRequested()
    }
    
    // MARK: - Removed Menu Items (Build 51 - Menu Simplification)
    // These methods are kept for reference but are no longer in the menu
    
    /*
    @objc func showInstallationGuide() {
        SentryManager.shared.trackUserAction("installation_guide_opened")
        delegate?.showInstallationGuideRequested()
    }
    
    @objc func reportIssue() {
        SentryManager.shared.trackUserAction("report_issue_opened")
        delegate?.reportIssueRequested()
    }
    
    @objc func testSentry() {
        SentryManager.shared.trackUserAction("sentry_test_triggered")
        delegate?.testSentryRequested()
    }
    
    @objc func showSamples() {
        SentryManager.shared.trackUserAction("samples_opened")
        delegate?.showSamplesRequested()
    }
    
    @objc func showVersionHistory() {
        SentryManager.shared.trackUserAction("version_history_opened")
        delegate?.showVersionHistoryRequested()
    }
    */
    
    @objc func shareApp() {
        SentryManager.shared.trackUserAction("share_app_triggered")
        delegate?.shareAppRequested()
    }
    
    @objc private func historyDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateHistoryBadge()
        }
    }
}

protocol MenuBarManagerDelegate: AnyObject {
    func hotkeyTriggered()
    func cleanAndPasteRequested()
    func cleanClipboardRequested()
    func toggleAutoCleanRequested()
    func openSettingsRequested()
    func checkForUpdatesRequested()
    func reportIssueRequested()
    func testSentryRequested()
    func showInstallationGuideRequested()
    func openAboutRequested()
    func showWelcomeScreenRequested()
    func showSamplesRequested()
    func showVersionHistoryRequested()
    func shareAppRequested()
    func isAutoCleanEnabled() -> Bool
}
