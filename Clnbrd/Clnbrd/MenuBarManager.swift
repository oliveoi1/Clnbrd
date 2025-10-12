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
        }
        
        menu = NSMenu()
        
        // Main actions
        let pasteItem = NSMenuItem(title: "Paste Cleaned (⌘⌥V)", action: #selector(cleanAndPaste), keyEquivalent: "")
        pasteItem.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Paste cleaned text")
        pasteItem.target = self
        menu.addItem(pasteItem)
        
        let cleanItem = NSMenuItem(title: "Clean Clipboard Now", action: #selector(cleanClipboardManually), keyEquivalent: "c")
        cleanItem.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Clean clipboard")
        cleanItem.target = self
        menu.addItem(cleanItem)
        
        let historyItem = NSMenuItem(title: "Show Clipboard History (⌘⇧H)", action: #selector(showClipboardHistory), keyEquivalent: "")
        historyItem.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "Show clipboard history")
        historyItem.target = self
        menu.addItem(historyItem)
        
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
        
        // Use Cmd+Option+V to avoid conflicts with Chrome's Cmd+Shift+V
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .option]) && event.keyCode == 9 {
                logger.info("🎯 ⌘⌥V detected! Triggering hotkey...")
                DispatchQueue.main.async {
                    self?.delegate?.hotkeyTriggered()
                }
            }
        }
        
        logger.info("Hotkey registered: ⌘⌥V")
        logger.info("🔍 Hotkey registration completed - eventMonitor: \(self.eventMonitor != nil)")
        
        // Register history hotkey (⌘⇧H)
        registerHistoryHotKey()
        
        // Register screenshot capture hotkey (⌘⌥C)
        registerScreenshotHotKey()
    }
    
    func registerHistoryHotKey() {
        logger.info("🔍 Registering clipboard history hotkey (⌘⇧H)...")
        
        // Initialize history window
        historyWindow = ClipboardHistoryWindow()
        
        // Register ⌘⇧H hotkey (Command+Shift+H, keyCode 4 is 'H')
        historyEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for ⌘⇧H (Command+Shift+H)
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 4 {
                logger.info("🎯 ⌘⇧H detected! Toggling clipboard history...")
                DispatchQueue.main.async {
                    self?.historyWindow?.toggle()
                }
            }
        }
        
        logger.info("History hotkey registered: ⌘⇧H")
    }
    
    func registerScreenshotHotKey() {
        logger.info("🔍 Registering screenshot capture hotkey (⌘⌥C)...")
        
        // Register ⌘⌥C hotkey (Command+Option+C, keyCode 8 is 'C')
        screenshotEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for ⌘⌥C (Command+Option+C)
            if event.modifierFlags.contains([.command, .option]) && event.keyCode == 8 {
                logger.info("🎯 ⌘⌥C detected! Starting screenshot capture...")
                DispatchQueue.main.async {
                    self?.captureScreenshotToHistory()
                }
            }
        }
        
        logger.info("Screenshot hotkey registered: ⌘⌥C")
    }
    
    /// Captures a screenshot using interactive area selection and adds it to history
    private func captureScreenshotToHistory() {
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
        historyWindow?.show()
    }
    
    @objc func toggleAutoClean() {
        SentryManager.shared.trackUserAction("auto_clean_toggled")
        delegate?.toggleAutoCleanRequested()
    }
    
    @objc func openSettings() {
        SentryManager.shared.trackUserAction("settings_opened")
        delegate?.openSettingsRequested()
    }
    
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
    func showSamplesRequested()
    func showVersionHistoryRequested()
    func shareAppRequested()
    func isAutoCleanEnabled() -> Bool
}
