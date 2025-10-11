import Cocoa
import Carbon
import UserNotifications
import ApplicationServices
import os.log
import Sparkle
import ServiceManagement

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "main")

class SystemInfoUtility {
    static func getSystemInformation() -> [String: String] {
        let processInfo = ProcessInfo.processInfo
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        
        var systemInfo: [String: String] = [:]
        
        // Date and Time
        systemInfo["Current Date/Time"] = dateFormatter.string(from: Date())
        systemInfo["Time Zone"] = TimeZone.current.identifier
        systemInfo["Time Zone Abbreviation"] = TimeZone.current.abbreviation() ?? "Unknown"
        
        // App Information
        systemInfo["App Version"] = VersionManager.version
        systemInfo["Build Number"] = VersionManager.buildNumber
        if let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            systemInfo["Bundle Version"] = bundleVersion
        }
        
        // macOS Information
        systemInfo["macOS Version"] = processInfo.operatingSystemVersionString
        systemInfo["macOS Build"] = getMacOSBuildNumber()
        
        // Hardware Information
        systemInfo["Mac Model"] = getMacModel()
        
        // Get processor information
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        systemInfo["Hardware Machine"] = String(cString: machine)
        
        // Get CPU information
        var cpuCount = 0
        var cpuCountSize = MemoryLayout<Int>.size
        sysctlbyname("hw.ncpu", &cpuCount, &cpuCountSize, nil, 0)
        systemInfo["CPU Count"] = String(cpuCount)
        
        // Get memory information
        var memSize = 0
        var memSizeSize = MemoryLayout<Int>.size
        sysctlbyname("hw.memsize", &memSize, &memSizeSize, nil, 0)
        let memoryGB = Double(memSize) / (1024 * 1024 * 1024)
        systemInfo["Total Memory"] = String(format: "%.1f GB", memoryGB)
        
        // Get architecture
        var archSize = 0
        sysctlbyname("hw.target", nil, &archSize, nil, 0)
        var arch = [CChar](repeating: 0, count: archSize)
        sysctlbyname("hw.target", &arch, &archSize, nil, 0)
        systemInfo["Architecture"] = String(cString: arch)
        
        // System uptime
        let uptime = processInfo.systemUptime
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        systemInfo["System Uptime"] = "\(days) days, \(hours) hours"
        
        // User information
        systemInfo["Username"] = NSUserName()
        systemInfo["Full Username"] = NSFullUserName()
        
        // Locale information
        systemInfo["Language"] = Locale.current.language.languageCode?.identifier ?? "Unknown"
        systemInfo["Region"] = Locale.current.region?.identifier ?? "Unknown"
        systemInfo["Locale"] = Locale.current.identifier
        
        // Screen information
        if let screen = NSScreen.main {
            systemInfo["Screen Resolution"] = "\(Int(screen.frame.width))x\(Int(screen.frame.height))"
            systemInfo["Screen Scale"] = String(format: "%.1fx", screen.backingScaleFactor)
        }
        
        // Accessibility permissions
        systemInfo["Accessibility Permissions"] = AXIsProcessTrusted() ? "Granted" : "Not Granted"
        
        // App launch information
        systemInfo["App Launch Time"] = dateFormatter.string(from: Date(timeIntervalSinceNow: -processInfo.systemUptime))
        
        return systemInfo
    }
    
    static func formatSystemInformation(_ systemInfo: [String: String]) -> String {
        var formatted = "System Information:\n"
        formatted += "==================\n\n"
        
        // Essential information first (most important for debugging)
        let essentialInfo = [
            "Current Date/Time", "App Version", "macOS Version", "Mac Model", 
            "Architecture", "Accessibility Permissions"
        ]
        
        formatted += "Essential Info:\n"
        for key in essentialInfo {
            if let value = systemInfo[key] {
                formatted += "• \(key): \(value)\n"
            }
        }
        formatted += "\n"
        
        // Additional details (condensed)
        formatted += "Additional Details:\n"
        if let cpuCount = systemInfo["CPU Count"], let memory = systemInfo["Total Memory"] {
            formatted += "• Hardware: \(cpuCount) CPU cores, \(memory)\n"
        }
        if let screen = systemInfo["Screen Resolution"], let scale = systemInfo["Screen Scale"] {
            formatted += "• Display: \(screen) @ \(scale)\n"
        }
        if let uptime = systemInfo["System Uptime"] {
            formatted += "• System Uptime: \(uptime)\n"
        }
        if let language = systemInfo["Language"], let region = systemInfo["Region"] {
            formatted += "• Locale: \(language)-\(region)\n"
        }
        
        return formatted
    }
    
    private static func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    private static func getMacOSBuildNumber() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Managers

    private var notificationManager: NotificationManager!
    private var dialogManager: DialogManager!
    var settingsWindowController: SettingsWindow?
    var autoCleanEnabled = false
    
    // Managers
    private let clipboardManager = ClipboardManager()
    let menuBarManager = MenuBarManager()  // Internal access for SettingsWindow
    private let preferencesManager = PreferencesManager.shared
    
    // Sparkle updater
    private let updaterController: SPUStandardUpdaterController
    
    override init() {
        // Initialize Sparkle updater
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prompt to move to Applications folder if needed (must be first!)
        #if !DEBUG
        PFMoveToApplicationsFolderIfNecessary()
        #endif
        
        // Initialize crash reporting first
        SentryManager.shared.initialize()
        SentryManager.shared.trackUserAction("app_launched")
        
        // Initialize managers
        notificationManager = NotificationManager(appDelegate: self)
        dialogManager = DialogManager(appDelegate: self)
        
        // Load preferences
        let activeProfile = ProfileManager.shared.getActiveProfile()
        clipboardManager.cleaningRules = activeProfile.rules
        autoCleanEnabled = preferencesManager.loadAutoCleanEnabled()
        
        // Setup managers
        menuBarManager.delegate = self
        
        // Initialize UI
        menuBarManager.setupMenuBar()
        menuBarManager.registerHotKey()
        
        // Debug: Check if everything is working
        logger.info("🔍 App initialized - MenuBarManager delegate: \(self.menuBarManager.delegate != nil)")
        logger.info("🔍 ClipboardManager initialized: true")
        
        // Check permissions and first launch
        checkFirstLaunch()
        checkAccessibilityPermissions()
        checkPostUpdatePermissions()
        
        // Notification manager handles delegate setup
        
        // Start auto-clean if enabled
        if autoCleanEnabled {
            clipboardManager.startClipboardMonitoring()
        }
        
        // Sparkle will handle update checking automatically based on Info.plist settings
        logger.info("Sparkle updater initialized - automatic updates enabled")
    }
    
    func checkAccessibilityPermissions() {
        // First, try to REQUEST accessibility permission (this triggers the system prompt)
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        let currentVersion = VersionManager.version
        
        // Debug logging
        logger.info("🔍 Accessibility check: trusted=\(trusted), version=\(currentVersion)")
        logger.info("🔍 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        logger.info("🔍 App path: \(Bundle.main.bundlePath)")
        logger.info("🔍 Accessibility permission status: \(trusted ? "GRANTED" : "NOT GRANTED")")
        
        // Check if we've already shown the permission dialog in this session
        let hasShownPermissionDialog = UserDefaults.standard.bool(forKey: "HasShownPermissionDialogThisSession")
        
        if !trusted && !hasShownPermissionDialog {
            // Mark that we've shown the dialog this session
            UserDefaults.standard.set(true, forKey: "HasShownPermissionDialogThisSession")
            
            // Check if this is a post-update scenario
            let lastKnownVersion = UserDefaults.standard.string(forKey: "LastKnownVersion")
            let isPostUpdate = lastKnownVersion != nil && lastKnownVersion != currentVersion
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if isPostUpdate {
                    self?.dialogManager.showPostUpdateAccessibilityWarning()
                } else {
                    self?.dialogManager.showAccessibilityWarning()
                }
            }
        } else if trusted {
            // Reset the session flag when permissions are granted
            UserDefaults.standard.set(false, forKey: "HasShownPermissionDialogThisSession")
        }
        
        // Update the last known version
        UserDefaults.standard.set(currentVersion, forKey: "LastKnownVersion")
    }
    
    func showPostUpdateAccessibilityWarning() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required After Update"
        alert.informativeText = """
        After updating Clnbrd, accessibility permissions may need to be re-granted.
        
        This is normal and happens when:
        • macOS security updates occur
        • App bundle signatures change
        • System preferences reset
        
        To re-enable:
        1. Open System Settings
        2. Go to Privacy & Security → Accessibility
        3. Find "Clnbrd" in the list
        4. Toggle it ON
        5. Restart Clnbrd
        
        Your settings and preferences are preserved - only permissions need to be re-granted.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "I'll Do It Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        
        // Update the last known version
        UserDefaults.standard.set(VersionManager.version, forKey: "LastKnownVersion")
    }
    
    func checkPostUpdatePermissions() {
        let lastKnownVersion = UserDefaults.standard.string(forKey: "LastKnownVersion")
        let currentVersion = VersionManager.version
        let isPostUpdate = lastKnownVersion != nil && lastKnownVersion != currentVersion
        
        if isPostUpdate {
            // Check notification permissions
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async { [weak self] in
                    if settings.authorizationStatus == .notDetermined {
                        // Re-request notification permissions after update
                        self?.requestNotificationPermissions()
                    }
                }
            }
            
            // Show a brief post-update message
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.dialogManager.showPostUpdateMessage()
            }
        }
        
        // Always update the last known version
        UserDefaults.standard.set(currentVersion, forKey: "LastKnownVersion")
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                logger.info("Notification permissions re-granted after update")
            } else {
                logger.warning("Notification permissions denied after update: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    func showPostUpdateMessage() {
        let alert = NSAlert()
        alert.messageText = "Clnbrd Updated Successfully!"
        alert.informativeText = """
        Welcome to Clnbrd \(VersionManager.version)!
        
        Your settings and preferences have been preserved.
        
        If you notice any issues with permissions (like hotkeys not working), 
        you may need to re-grant accessibility permissions in System Settings.
        
        Thank you for keeping Clnbrd updated! 🎉
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Got It!")
        
        alert.runModal()
    }
    
    func showAccessibilityWarning() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        Clnbrd needs accessibility permissions to use the ⌘⌥V hotkey.
        
        To enable:
        1. Open System Settings
        2. Go to Privacy & Security → Accessibility
        3. Find "Clnbrd" in the list
        4. Toggle it ON
        5. Restart Clnbrd
        
        Without this permission, the hotkey won't work, but you can still use the menu bar options.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "I'll Do It Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
    
    func checkFirstLaunch() {
        let hasLaunchedBefore = preferencesManager.loadFirstLaunchCompleted()
        
        if !hasLaunchedBefore {
            preferencesManager.saveFirstLaunchCompleted()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.dialogManager.showWelcomeDialog()
            }
        }
    }
    func isAutoCleanEnabled() -> Bool {
        return autoCleanEnabled
    }
    func showVersionHistoryRequested() {
        dialogManager.showVersionHistory()
    }
    
    func shareAppRequested() {
        showShareAppDialog()
    }
    func showSamplesRequested() {
        dialogManager.showSamples()
    }
    func showInstallationGuideRequested() {
        dialogManager.showInstallationGuide()
    }
    func reportIssueRequested() {
        let supportInfo = gatherSupportInfo()
        showIssueReportDialog(with: supportInfo)
    }
    func testSentryRequested() {
        // Trigger test error for Sentry
        SentryManager.shared.testCrashReporting()
        
        // Show confirmation to user
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Test Error Sent"
            alert.informativeText = "A test error has been sent to Sentry.\n\nCheck your Sentry dashboard at:\nsentry.io/organizations/clnbrd/issues/\n\nIt should appear within a few seconds."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open Sentry Dashboard")
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                if let url = URL(string: "https://sentry.io/organizations/clnbrd/issues/") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    func checkForUpdatesRequested() {
        // Use Sparkle's updater to check for updates
        updaterController.updater.checkForUpdates()
    }
    func openSettingsRequested() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindow(cleaningRules: clipboardManager.cleaningRules)
        }
        
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func toggleAutoCleanRequested() {
        autoCleanEnabled.toggle()
        preferencesManager.saveAutoCleanEnabled(autoCleanEnabled)
        
        menuBarManager.updateAutoCleanState(autoCleanEnabled)
        
        if autoCleanEnabled {
            clipboardManager.startClipboardMonitoring()
            notificationManager.showNotification(title: "Auto-clean Enabled", message: "Clipboard will be automatically cleaned when you copy")
        } else {
            clipboardManager.stopClipboardMonitoring()
            notificationManager.showNotification(title: "Auto-clean Disabled", message: "Use ⌘⌥V or menu to clean clipboard")
        }
    }
    func cleanClipboardRequested() {
        clipboardManager.cleanClipboard()
        notificationManager.showNotification(title: "Clipboard Cleaned", message: "Text has been cleaned and formatting removed")
    }
    func cleanAndPasteRequested() {
        clipboardManager.cleanAndPasteClipboard()
    }
    func hotkeyTriggered() {
        clipboardManager.cleanAndPasteClipboard()
    }
    
    private func gatherSupportInfo() -> String {
        let analyticsData = AnalyticsManager.shared.getAnalyticsSummary()
        let systemInfo = SystemInfoUtility.getSystemInformation()
        let formattedSystemInfo = SystemInfoUtility.formatSystemInformation(systemInfo)

        return """
        App Version: \(VersionManager.version) (Build \(VersionManager.buildNumber))

        Analytics Data:
        \(analyticsData)

        \(formattedSystemInfo)
        """
    }

    private func showIssueReportDialog(with supportInfo: String) {
        let alert = NSAlert()
        alert.messageText = "Report an Issue"
        alert.informativeText = "Choose how you'd like to report this issue:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy Info & Open Email")
        alert.addButton(withTitle: "Copy Info Only")
        // alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        handleIssueReportResponse(response, supportInfo: supportInfo)
    }

    private func handleIssueReportResponse(_ response: NSApplication.ModalResponse, supportInfo: String) {
        switch response {
        case .alertFirstButtonReturn:
            copySupportInfoToClipboard(supportInfo)
            handleEmailOption(supportInfo)
            
        case .alertSecondButtonReturn:
            handleCopyOnlyOption(supportInfo)
            
        default:
            // Cancelled
            break
        }
    }

    private func copySupportInfoToClipboard(_ supportInfo: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(supportInfo, forType: .string)
    }

    private func handleEmailOption(_ supportInfo: String) {
        let subject = "Clnbrd Support Request - v\(VersionManager.version) Build \(VersionManager.buildNumber)"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject

        let mailtoURLs = [
            "mailto:olivedesignstudios@gmail.com?subject=\(encodedSubject)",
            "mailto:olivedesignstudios@gmail.com"
        ]

        var emailOpened = false
        for mailtoString in mailtoURLs {
            if let url = URL(string: mailtoString) {
                logger.info("Attempting to open email with URL: \(mailtoString)")

                if NSWorkspace.shared.open(url) {
                    logger.info("Email client opened successfully with URL: \(mailtoString)")
                    emailOpened = true
                    showEmailInstructions(subject)
                    break
                } else {
                    logger.warning("Failed to open with URL: \(mailtoString)")
                }
            }
        }

        if !emailOpened {
            logger.error("All email opening attempts failed")
            showEmailError(subject)
        }
    }

    private func handleCopyOnlyOption(_ supportInfo: String) {
        copySupportInfoToClipboard(supportInfo)

        let copyAlert = NSAlert()
        copyAlert.messageText = "Info Copied"
        copyAlert.informativeText = "System diagnostic information has been copied to your clipboard. Please email it to: olivedesignstudios@gmail.com"
        copyAlert.alertStyle = .informational
        copyAlert.addButton(withTitle: "OK")
        copyAlert.runModal()
    }

    private func showEmailInstructions(_ subject: String) {
        let instructionAlert = NSAlert()
        instructionAlert.messageText = "System Info Copied!"
        instructionAlert.informativeText = """
        Your email client should now be open.

        The system diagnostic information has been copied to your clipboard.

        Please:
        1. Set recipient to: olivedesignstudios@gmail.com
        2. Subject: \(subject)
        3. Describe your issue
        4. Paste (⌘V) the diagnostic info
        5. Send
        """
        instructionAlert.alertStyle = .informational
        instructionAlert.addButton(withTitle: "Got It")
        instructionAlert.runModal()
    }

    private func showEmailError(_ subject: String) {
        let errorAlert = NSAlert()
        errorAlert.messageText = "Email Client Not Available"
        errorAlert.informativeText = """
        Could not open your email client automatically.

        The system diagnostic information has been copied to your clipboard.

        Please manually email it to:
        olivedesignstudios@gmail.com

        Subject: \(subject)
        """
        errorAlert.alertStyle = .warning
        errorAlert.addButton(withTitle: "OK")
        errorAlert.runModal()
    }
    
    @objc func openAboutRequested() {
        // Open Settings window on About tab
        openSettingsRequested()
        settingsWindowController?.showWindow(withTab: "about")
    }
    
    @objc func openWebsite() {
        if let url = URL(string: "https://github.com/oliveoi1/Clnbrd") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func openSupport() {
        reportIssueRequested()
    }
    
    private func showShareAppDialog() {
        let shareText = """
        Clnbrd - Professional Clipboard Cleaner for macOS
        
        A lightweight menu bar utility that automatically removes formatting from clipboard text, including hidden AI watermarks and tracking codes.
        
        Key Features:
        • Instant paste with Command+Option+V hotkey
        • Automatic format stripping on copy
        • Removes AI watermarks (ChatGPT, Claude)
        • Menu bar integration
        • Fully notarized by Apple
        • Privacy-focused - all processing happens locally
        
        Perfect for content writers, developers, and professionals who work with text from multiple sources.
        
        Learn more: http://olvbrd.x10.network/wp/
        
        #Clnbrd #MacApp #Productivity
        """
        
        // Create a sharing picker with all available services
        let sharingPicker = NSSharingServicePicker(items: [shareText])
        
        // Show the picker relative to the menu bar button
        if let statusItem = menuBarManager.statusItem,
           let button = statusItem.button {
            sharingPicker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        } else {
            // Fallback: show in center of screen
            sharingPicker.show(relativeTo: NSRect(x: 0, y: 0, width: 1, height: 1), of: NSApp.keyWindow?.contentView ?? NSView(), preferredEdge: .minY)
        }
    }
}

extension AppDelegate: MenuBarManagerDelegate {
    // Delegate methods are already implemented in the main class
}

// Sparkle handles update checking and notifications automatically
