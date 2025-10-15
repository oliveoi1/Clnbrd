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
    
    // Update notification state
    private var updateAvailable = false
    private var updateBadgeView: NSView?
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.isVisible = true
        
        if let button = statusItem?.button {
            button.image = NSImage.menuBarSymbol("doc.plaintext", color: .labelColor)
            button.imagePosition = .imageLeft
            
            // Enhancement #4: Add material effect to menu bar button
            setupMenuBarButtonMaterialEffect(button)
        }
        
        menu = NSMenu()
        // Enhancement #4: Enable menu to use modern appearance
        menu.minimumWidth = 250  // Wider for better visual hierarchy
        
        // Main actions section with enhanced visual hierarchy
        let pasteItem = NSMenuItem(title: "Paste Cleaned", action: #selector(cleanAndPaste), keyEquivalent: "")
        pasteItem.image = NSImage.symbol("doc.on.clipboard", size: 14, weight: .semibold, scale: .medium, color: .controlAccentColor)
        pasteItem.target = self
        pasteItem.tag = 100  // Tag for paste item
        menu.addItem(pasteItem)
        
        let cleanItem = NSMenuItem(title: "Clean Clipboard Now", action: #selector(cleanClipboardManually), keyEquivalent: "c")
        cleanItem.image = NSImage.symbol("wand.and.stars", size: 14, weight: .medium, scale: .medium, color: .controlAccentColor)
        cleanItem.target = self
        menu.addItem(cleanItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let screenshotItem = NSMenuItem(title: "Capture Screenshot", action: #selector(captureScreenshotToHistory), keyEquivalent: "")
        screenshotItem.image = NSImage.menuBarSymbol("camera.viewfinder", color: .labelColor)
        screenshotItem.target = self
        screenshotItem.tag = 101  // Tag for screenshot item
        menu.addItem(screenshotItem)
        
        let historyItem = NSMenuItem(title: "Show Clipboard History", action: #selector(showClipboardHistory), keyEquivalent: "")
        historyItem.image = NSImage.menuBarSymbol("clock.arrow.circlepath", color: .labelColor)
        historyItem.target = self
        historyItem.tag = 999  // Tag to find and update later
        menu.addItem(historyItem)
        
        // Update badge immediately
        updateHistoryBadge()
        
        // Add separator between history and clear actions
        menu.addItem(NSMenuItem.separator())
        
        let clearHistoryItem = NSMenuItem(title: "Clear Clipboard History", action: #selector(clearClipboardHistory), keyEquivalent: "")
        clearHistoryItem.image = NSImage.symbol("trash", size: 14, weight: .medium, scale: .medium, color: .systemRed)
        clearHistoryItem.target = self
        menu.addItem(clearHistoryItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let autoCleanItem = NSMenuItem(title: "Auto-clean on Copy", action: #selector(toggleAutoClean), keyEquivalent: "")
        autoCleanItem.image = NSImage.menuBarSymbol("arrow.clockwise.circle", color: .labelColor)
        autoCleanItem.target = self
        autoCleanItem.state = delegate?.isAutoCleanEnabled() ?? false ? .on : .off
        menu.addItem(autoCleanItem)
        
        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.image = NSImage.menuBarSymbol("power.circle", color: .labelColor)
        launchAtLoginItem.target = self
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Secondary actions
        let updateItem = NSMenuItem(title: "Check for Updates", action: #selector(checkForUpdatesManually), keyEquivalent: "u")
        updateItem.image = NSImage.menuBarSymbol("arrow.clockwise", color: .labelColor)
        updateItem.target = self
        menu.addItem(updateItem)
        
        let shareAppItem = NSMenuItem(title: "Share Clnbrd", action: #selector(shareApp), keyEquivalent: "")
        shareAppItem.image = NSImage.menuBarSymbol("square.and.arrow.up", color: .labelColor)
        shareAppItem.target = self
        menu.addItem(shareAppItem)
        
        let aboutItem = NSMenuItem(title: "About Clnbrd", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.image = NSImage.menuBarSymbol("info.circle", color: .labelColor)
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings and Quit
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.image = NSImage.menuBarSymbol("gear", color: .labelColor)
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // Show Welcome Screen
        let welcomeItem = NSMenuItem(title: "Show Welcome Screen", action: #selector(showWelcomeScreen), keyEquivalent: "")
        welcomeItem.image = NSImage.menuBarSymbol("questionmark.circle", color: .labelColor)
        welcomeItem.target = self
        menu.addItem(welcomeItem)
        
        #if DEBUG
        // Debug: Reset Onboarding (only in debug builds)
        let resetItem = NSMenuItem(title: "🔄 Reset Onboarding (Debug)", action: #selector(resetOnboarding), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        
        // Debug: Test Update Notification
        let testUpdateItem = NSMenuItem(title: "🟡 Test Update Notification (Debug)", action: #selector(testUpdateNotification), keyEquivalent: "")
        testUpdateItem.target = self
        menu.addItem(testUpdateItem)
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
        
        // Update paste item (tag 100) - show shortcut on right
        if let pasteItem = menu.item(withTag: 100) {
            pasteItem.title = "Paste Cleaned"
            let key = KeyCodeMapper.keyCodeToString(cleanConfig.keyCode).lowercased()
            pasteItem.keyEquivalent = key
            pasteItem.keyEquivalentModifierMask = cleanConfig.modifiers.toNSModifierFlags()
        }
        
        // Update history item (tag 999) - show shortcut on right
        if let historyItem = menu.item(withTag: 999) {
            historyItem.title = "Show Clipboard History"
            let key = KeyCodeMapper.keyCodeToString(historyConfig.keyCode).lowercased()
            historyItem.keyEquivalent = key
            historyItem.keyEquivalentModifierMask = historyConfig.modifiers.toNSModifierFlags()
            historyItem.attributedTitle = nil  // Clear to allow updateHistoryBadge to work
            updateHistoryBadge()  // Re-apply badge
        }
        
        // Update screenshot item (tag 101) - show shortcut on right
        if let screenshotItem = menu.item(withTag: 101) {
            screenshotItem.title = "Capture Screenshot"
            let key = KeyCodeMapper.keyCodeToString(screenshotConfig.keyCode).lowercased()
            screenshotItem.keyEquivalent = key
            screenshotItem.keyEquivalentModifierMask = screenshotConfig.modifiers.toNSModifierFlags()
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
        // -x: Do not play camera sound (silent capture)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-r", "-x", screenshotPath.path]
        
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
            let baseTitle = "Show Clipboard History"
            let badge = " • \(itemCount)"
            
            let attributedTitle = NSMutableAttributedString(string: baseTitle + badge)
            
            // Style the badge with secondary color and monospaced font
            let badgeRange = NSRange(location: baseTitle.count, length: badge.count)
            attributedTitle.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: badgeRange)
            attributedTitle.addAttribute(.font, value: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular), range: badgeRange)
            
            historyItem.attributedTitle = attributedTitle
        } else {
            // No items, show plain title
            historyItem.title = "Show Clipboard History"
            historyItem.attributedTitle = nil
        }
    }
    
    /// Show update notification in menu bar
    func showUpdateAvailable(version: String) {
        updateAvailable = true
        
        // Add yellow dot badge to menu bar icon
        addUpdateBadge()
        
        // Add/update the update notification menu item at the top
        if let existingItem = menu.item(withTag: 1000) {
            // Update existing item
            let title = "🟡 A new update is available..."
            existingItem.title = title
        } else {
            // Create new notification item at the top
            let updateNotificationItem = NSMenuItem(title: "🟡 A new update is available...", action: #selector(checkForUpdatesManually), keyEquivalent: "")
            updateNotificationItem.tag = 1000
            updateNotificationItem.target = self
            updateNotificationItem.image = NSImage.symbol("arrow.down.circle.fill", size: 14, weight: .medium, scale: .medium, color: .systemOrange)
            
            // Add it at the very top
            menu.insertItem(updateNotificationItem, at: 0)
            menu.insertItem(NSMenuItem.separator(), at: 1)
        }
        
        logger.info("✅ Update notification displayed for version \(version)")
    }
    
    /// Hide update notification
    func hideUpdateNotification() {
        updateAvailable = false
        
        // Remove yellow dot badge
        removeUpdateBadge()
        
        // Remove notification menu item
        if let item = menu.item(withTag: 1000) {
            if let separatorIndex = menu.items.firstIndex(where: { $0 == item }) {
                // Remove the separator after it too
                if separatorIndex + 1 < menu.items.count && menu.items[separatorIndex + 1].isSeparatorItem {
                    menu.removeItem(at: separatorIndex + 1)
                }
            }
            menu.removeItem(item)
        }
        
        logger.info("✅ Update notification hidden")
    }
    
    /// Add yellow dot badge to menu bar icon
    private func addUpdateBadge() {
        guard let button = statusItem?.button else { return }
        
        // Remove existing badge if any
        removeUpdateBadge()
        
        // Create a yellow dot badge
        let badgeSize: CGFloat = 8
        let badge = NSView(frame: NSRect(x: button.bounds.width - badgeSize - 2,
                                          y: button.bounds.height - badgeSize - 2,
                                          width: badgeSize,
                                          height: badgeSize))
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.systemOrange.cgColor
        badge.layer?.cornerRadius = badgeSize / 2
        
        // Add subtle shadow for depth
        badge.layer?.shadowColor = NSColor.black.cgColor
        badge.layer?.shadowOpacity = 0.3
        badge.layer?.shadowOffset = NSSize(width: 0, height: -1)
        badge.layer?.shadowRadius = 2
        
        button.addSubview(badge)
        updateBadgeView = badge
        
        logger.debug("🟡 Update badge added to menu bar icon")
    }
    
    /// Remove yellow dot badge from menu bar icon
    private func removeUpdateBadge() {
        updateBadgeView?.removeFromSuperview()
        updateBadgeView = nil
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
    
    @objc func testUpdateNotification() {
        // Toggle the update notification on/off for testing
        if updateAvailable {
            hideUpdateNotification()
            logger.info("🔧 Test: Hidden update notification")
        } else {
            showUpdateAvailable(version: "2.0.0")
            logger.info("🔧 Test: Shown update notification")
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
