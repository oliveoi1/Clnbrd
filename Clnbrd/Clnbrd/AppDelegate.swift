import Cocoa
import Carbon
import UserNotifications
import ApplicationServices
import os.log
import Sparkle
import ServiceManagement

struct CustomRule: Codable {
    let find: String
    let replace: String
}

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
    var settingsWindowController: SettingsWindow?
    var autoCleanEnabled = false
    private var aboutWindow: NSWindow?
    
    // Legacy properties for compatibility (will be removed in future versions)
    var lastClipboardChangeCount = 0
    var clipboardMonitorTimer: Timer?
    
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
        // Initialize crash reporting first
        SentryManager.shared.initialize()
        SentryManager.shared.trackUserAction("app_launched")
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                logger.info("Notification permissions granted")
            } else {
                logger.warning("Notification permissions denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
        
        // Load preferences
        clipboardManager.cleaningRules = preferencesManager.loadCleaningRules()
        autoCleanEnabled = preferencesManager.loadAutoCleanEnabled()
        
        // Setup managers
        menuBarManager.delegate = self
        
        // Initialize UI
        menuBarManager.setupMenuBar()
        menuBarManager.registerHotKey()
        
        // Debug: Check if everything is working
        logger.info("🔍 App initialized - MenuBarManager delegate: \(self.menuBarManager.delegate != nil)")
        logger.info("🔍 ClipboardManager initialized: true")
        
        // TEST: URL Tracking Cleaner
        testURLCleaning()
        
        // Check permissions and first launch
        checkFirstLaunch()
        checkAccessibilityPermissions()
        checkPostUpdatePermissions()
        
        // Set up notification delegate for handling push notifications
        UNUserNotificationCenter.current().delegate = self
        
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
        print("🔍 Accessibility check: trusted=\(trusted), version=\(currentVersion)")
        print("🔍 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("🔍 App path: \(Bundle.main.bundlePath)")
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
                    self?.showPostUpdateAccessibilityWarning()
                } else {
                    self?.showAccessibilityWarning()
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
                self?.showPostUpdateMessage()
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
                self?.showWelcomeDialog()
            }
        }
    }
    
    func showWelcomeDialog() {
        let alert = NSAlert()
        alert.messageText = "Welcome to Clnbrd!"
        alert.informativeText = """
        Clnbrd cleans your clipboard text by removing:
        • Formatting (bold, italic, colors)
        • AI watermarks (invisible characters)
        • URLs, HTML tags, extra punctuation
        • Emojis (optional)
        • Smart quotes, em-dashes, extra spaces
        • Extra line breaks and whitespace
        
        HOW TO USE:
        • Press ⌘⌥V (Cmd+Option+V) to paste cleaned text
        • Or use the menu bar icon for options
        
        IMPORTANT SETUP:
        For the ⌘⌥V hotkey to work, you need to:
        1. Open System Settings
        2. Go to Privacy & Security → Accessibility
        3. Add Clnbrd and enable it
        
        Would you like to open System Settings now?
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "View Installation Guide")
        alert.addButton(withTitle: "I'll Do It Later")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        case .alertSecondButtonReturn:
            showInstallationGuide()
        default:
            break
        }
    }
    
    @objc func showInstallationGuide() {
        let alert = NSAlert()
        alert.messageText = "Installation & Permissions Guide"
        alert.informativeText = """
        REQUIRED PERMISSIONS FOR HOTKEY (⌘⌥V):
        
        Clnbrd needs TWO permissions to work:
        
        1️⃣ ACCESSIBILITY
           • Required to simulate paste (⌘V) action
           • Click "Open Accessibility" below
        
        2️⃣ INPUT MONITORING  
           • Required to detect ⌘⌥V hotkey
           • Click "Open Input Monitoring" below
        
        After granting both permissions:
        • Quit Clnbrd (⌘Q)
        • Relaunch from Applications folder
        • Test the ⌘⌥V hotkey!
        
        These permissions are required by macOS for ANY app that monitors keyboard shortcuts.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Accessibility")
        alert.addButton(withTitle: "Open Input Monitoring")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            // Open Accessibility Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            // Open Input Monitoring Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }
    
    func openInstallationGuideFile() {
        if let bundlePath = Bundle.main.bundlePath as NSString? {
            let appPath = bundlePath.deletingLastPathComponent
            let guidePath = "\(appPath)/INSTALLATION_GUIDE.txt"
            let guideURL = URL(fileURLWithPath: guidePath)
            
            if FileManager.default.fileExists(atPath: guidePath) {
                NSWorkspace.shared.open(guideURL)
            } else {
                // Fallback: show the guide content in a dialog
                showInstallationGuideContent()
            }
        }
    }
    
    func showInstallationGuideContent() {
        let alert = NSAlert()
        alert.messageText = "Installation Guide"
        alert.informativeText = """
        CLNBRD INSTALLATION GUIDE
        
        IMPORTANT: macOS SECURITY WARNING
        When you first try to open Clnbrd, macOS will show a security warning because the app is not signed by Apple.
        
        WHAT TO EXPECT:
        - "Clnbrd.app cannot be opened because it is not from an identified developer"
        - Or "Clnbrd.app was blocked from use because it is not from an identified developer"
        
        HOW TO FIX THIS:
        1. Go to System Settings → Privacy & Security
        2. Scroll down to find "Clnbrd.app was blocked"
        3. Click "Open Anyway"
        4. Click "Open" in the confirmation dialog
        
        ALTERNATIVE METHOD:
        1. Right-click on Clnbrd.app in Finder
        2. Select "Open" from the context menu
        3. Click "Open" in the security dialog
        
        REQUIRED PERMISSIONS:
        After Clnbrd launches, grant accessibility permissions:
        1. System Settings → Privacy & Security → Accessibility
        2. Find "Clnbrd" in the list
        3. Toggle it ON
        4. Restart Clnbrd
        
        This permission is required for the ⌘⌥V hotkey to work.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func showSamples() {
        let samplesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 250),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        samplesWindow.title = "Clnbrd Cleaning Rules - Before & After Examples"
        samplesWindow.center()
        samplesWindow.setFrameAutosaveName("SamplesWindow")
        
        // Prevent the window from quitting the app when closed
        samplesWindow.isReleasedWhenClosed = false
        
        // Create a styled text view with rich formatting
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.font = NSFont.systemFont(ofSize: 13)
        
        // Create attributed string with rich formatting
        let attributedString = NSMutableAttributedString()
        
        // Title
        let titleFont = NSFont.boldSystemFont(ofSize: 18)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.labelColor
        ]
        attributedString.append(NSAttributedString(string: "Clnbrd Cleaning Rules\n", attributes: titleAttributes))
        
        // Subtitle
        let subtitleFont = NSFont.systemFont(ofSize: 14)
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        attributedString.append(NSAttributedString(string: "Before & After Examples\n\n", attributes: subtitleAttributes))
        
        // Description
        let bodyFont = NSFont.systemFont(ofSize: 13)
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor
        ]
        attributedString.append(NSAttributedString(string: "Here are visual examples of how each cleaning rule transforms your text:\n\n", attributes: bodyAttributes))
        
        // Rule formatting
        let ruleTitleFont = NSFont.boldSystemFont(ofSize: 14)
        let ruleTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: ruleTitleFont,
            .foregroundColor: NSColor.labelColor
        ]
        
        let beforeAfterFont = NSFont.systemFont(ofSize: 12)
        let beforeAfterAttributes: [NSAttributedString.Key: Any] = [
            .font: beforeAfterFont,
            .foregroundColor: NSColor.labelColor
        ]
        
        let separatorAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.separatorColor
        ]
        
        // Add each rule in the exact order shown in settings
        let rules = [
            ("📝 REMOVE ZERO-WIDTH AND INVISIBLE CHARACTERS (AI WATERMARKS)", "Removes invisible zero-width characters that can cause formatting issues", "BEFORE:  Hello[invisible]world[invisible]test\nAFTER:   Helloworldtest"),
            ("📝 REPLACE EM-DASHES (—) WITH COMMA+SPACE", "Converts em dashes (—) to comma and space", "BEFORE:  Hello—world—this is a test—with em dashes\nAFTER:   Hello, world, this is a test, with em dashes"),
            ("📝 NORMALIZE MULTIPLE SPACES TO SINGLE SPACE", "Converts multiple consecutive spaces to single spaces", "BEFORE:  Hello    world   test    with    multiple    spaces\nAFTER:   Hello world test with multiple spaces"),
            ("📝 CONVERT SMART QUOTES TO STRAIGHT QUOTES", "Converts curly quotes to standard straight quotes", "BEFORE:  \"Hello\" and 'world' with smart quotes\nAFTER:   \"Hello\" and 'world' with smart quotes"),
            ("📝 NORMALIZE LINE BREAKS", "Converts all line break types to standard line breaks", "BEFORE:  Line one\\r\\nLine two\\r\\nLine three\nAFTER:   Line one\n         Line two\n         Line three"),
            ("📝 REMOVE TRAILING SPACES FROM LINES", "Removes spaces at the end of each line", "BEFORE:  Line with trailing spaces   \n         Another line with spaces  \nAFTER:   Line with trailing spaces\n         Another line with spaces"),
            ("📝 REMOVE EMOJIS", "Removes all emoji characters from clipboard text", "BEFORE:  Hello 😀 world 🌍 test 🎉\nAFTER:   Hello  world  test "),
            ("📝 REMOVE EXTRA LINE BREAKS (3+ → 2)", "Removes excessive line breaks, keeping maximum of 2 consecutive breaks", "BEFORE:  Line one\n\n\n\nLine two\n\n\n\n\nLine three\nAFTER:   Line one\n\n\nLine two\n\n\nLine three"),
            ("📝 REMOVE LEADING/TRAILING WHITESPACE", "Removes spaces and tabs at the beginning and end of text", "BEFORE:     Text with leading and trailing spaces    \nAFTER:   Text with leading and trailing spaces"),
            ("📝 REMOVE URLs (HTTP, HTTPS, WWW)", "Removes web URLs and links from text", "BEFORE:  Check out https://example.com and www.test.com\nAFTER:   Check out  and "),
            ("📝 REMOVE HTML TAGS AND ENTITIES", "Removes HTML formatting tags like <b>, <i>, &nbsp;, etc.", "BEFORE:  <b>Bold text</b> and <i>italic</i> with &nbsp; entities\nAFTER:   Bold text and italic with  entities"),
            ("📝 REMOVE EXTRA PUNCTUATION MARKS", "Removes excessive punctuation marks like multiple periods or exclamation points", "BEFORE:  Hello!!! How are you??? Great...\nAFTER:   Hello! How are you? Great.")
        ]
        
        for (index, rule) in rules.enumerated() {
            // Rule title
            attributedString.append(NSAttributedString(string: "\(rule.0)\n", attributes: ruleTitleAttributes))
            
            // Rule description
            attributedString.append(NSAttributedString(string: "\(rule.1)\n\n", attributes: bodyAttributes))
            
            // Before/After examples
            attributedString.append(NSAttributedString(string: "\(rule.2)\n\n", attributes: beforeAfterAttributes))
            
            // Separator (except for last rule)
            if index < rules.count - 1 {
                attributedString.append(NSAttributedString(string: "────────────────────────────────────────────────────────────────────────────────\n\n", attributes: separatorAttributes))
            }
        }
        
        // Tip section
        let tipFont = NSFont.systemFont(ofSize: 12)
        let tipAttributes: [NSAttributedString.Key: Any] = [
            .font: tipFont,
            .foregroundColor: NSColor.secondaryLabelColor,
            .obliqueness: 0.2  // Makes text appear italic
        ]
        attributedString.append(NSAttributedString(string: "💡 TIP: You can enable/disable individual rules in Settings → Cleaning Rules\n\n", attributes: tipAttributes))
        attributedString.append(NSAttributedString(string: "These examples show how Clnbrd automatically cleans and normalizes text copied from various sources like web pages, documents, and other applications.", attributes: bodyAttributes))
        
        textView.textStorage?.setAttributedString(attributedString)
        
        // Force the text view to size itself properly
        textView.sizeToFit()
        
        // Configure text view for proper sizing
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 300, height: CGFloat.greatestFiniteMagnitude)
        
        // Debug: Print text view content length
        print("DEBUG: Text view content length: \(attributedString.length) characters")
        
        // Create a scroll view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        
        // Add the text view to the scroll view
        scrollView.documentView = textView
        
        // Set up constraints for the text view with more left margin
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor, constant: 15),
            textView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor, constant: 25),
            textView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor, constant: -15),
            textView.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 2000)
        ])
        
        samplesWindow.contentView = scrollView
        samplesWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showVersionHistory() {
        let versionWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        versionWindow.title = "Clnbrd Version History"
        versionWindow.center()
        versionWindow.setFrameAutosaveName("VersionHistoryWindow")
        
        // Prevent the window from quitting the app when closed
        versionWindow.isReleasedWhenClosed = false
        
        // Create a styled text view with rich formatting
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.font = NSFont.systemFont(ofSize: 13)
        
        // Create attributed string with rich formatting
        let attributedString = NSMutableAttributedString()
        
        // Title
        let titleFont = NSFont.boldSystemFont(ofSize: 18)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.labelColor
        ]
        attributedString.append(NSAttributedString(string: "Clnbrd Version History\n", attributes: titleAttributes))
        
        // Subtitle
        let subtitleFont = NSFont.systemFont(ofSize: 14)
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        attributedString.append(NSAttributedString(string: "Complete changelog of all releases\n\n", attributes: subtitleAttributes))
        
        // Version entries
        let versionFont = NSFont.boldSystemFont(ofSize: 14)
        let versionAttributes: [NSAttributedString.Key: Any] = [
            .font: versionFont,
            .foregroundColor: NSColor.labelColor
        ]
        
        let bodyFont = NSFont.systemFont(ofSize: 12)
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor
        ]
        
        let dateFont = NSFont.systemFont(ofSize: 11)
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        // Current Version (dynamically read)
        attributedString.append(NSAttributedString(string: "\(VersionManager.displayVersion) (Build \(VersionManager.buildNumber))\n", attributes: versionAttributes))
        attributedString.append(NSAttributedString(string: "Released: October 3, 2024\n", attributes: dateAttributes))
        attributedString.append(NSAttributedString(string: "• Added professional crash reporting with Sentry\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Added 'Report Issue' menu for user support\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Fixed notification permissions for update messages\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Improved error handling and user feedback\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Enhanced analytics tracking\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Resolved all build warnings and issues\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Added comprehensive user support system\n\n", attributes: bodyAttributes))
        
        // Version 1.2
        attributedString.append(NSAttributedString(string: "Version 1.2 (Build 2)\n", attributes: versionAttributes))
        attributedString.append(NSAttributedString(string: "Released: September 2024\n", attributes: dateAttributes))
        attributedString.append(NSAttributedString(string: "• Enhanced system information collection\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Improved post-update permission handling\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Professional DMG installer with drag-to-Applications interface\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Push notification system for updates\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Better error handling and user experience\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Organized project structure and proper versioning\n\n", attributes: bodyAttributes))
        
        // Version 1.1
        attributedString.append(NSAttributedString(string: "Version 1.1 (Build 1)\n", attributes: versionAttributes))
        attributedString.append(NSAttributedString(string: "Released: August 2024\n", attributes: dateAttributes))
        attributedString.append(NSAttributedString(string: "• Added 'View Samples' feature to preview cleaning rules\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Improved menu organization and user interface\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Enhanced clipboard management\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Better accessibility permission handling\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Fixed various UI and performance issues\n\n", attributes: bodyAttributes))
        
        // Version 1.0
        attributedString.append(NSAttributedString(string: "Version 1.0 (Initial Release)\n", attributes: versionAttributes))
        attributedString.append(NSAttributedString(string: "Released: July 2024\n", attributes: dateAttributes))
        attributedString.append(NSAttributedString(string: "• Initial release of Clnbrd\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Smart text cleaning with 12 customizable rules\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• ⌘⌥V hotkey for instant text cleaning\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Auto-clean on copy functionality\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Menu bar integration\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Settings window for rule customization\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Update checking system\n", attributes: bodyAttributes))
        attributedString.append(NSAttributedString(string: "• Analytics and usage tracking\n", attributes: bodyAttributes))
        
        // Footer
        attributedString.append(NSAttributedString(string: "\n\n", attributes: bodyAttributes))
        let footerFont = NSFont.systemFont(ofSize: 11)
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        attributedString.append(NSAttributedString(string: "For the latest updates and support, visit our website or contact us at olivedesignstudios@gmail.com", attributes: footerAttributes))
        
        textView.textStorage?.setAttributedString(attributedString)
        textView.sizeToFit()
        
        // Set up scroll view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.documentView = textView
        
        // Set up constraints
        textView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor, constant: 15),
            textView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor, constant: 15),
            textView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor, constant: -15),
            textView.widthAnchor.constraint(greaterThanOrEqualToConstant: 450),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1000)
        ])
        
        versionWindow.contentView = scrollView
        versionWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showTestSampleDialog() {
        let testWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        testWindow.title = "Test Cleaning Rules"
        testWindow.center()
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.spacing = 15
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Test Cleaning Rules on Your Text")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = .labelColor
        stackView.addArrangedSubview(titleLabel)
        
        // Description
        let descriptionLabel = NSTextField(labelWithString: "Enter text below to see how Clnbrd's cleaning rules transform it:")
        descriptionLabel.font = NSFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descriptionLabel)
        
        // Input text field
        let inputLabel = NSTextField(labelWithString: "Input Text:")
        inputLabel.font = NSFont.boldSystemFont(ofSize: 12)
        inputLabel.textColor = .labelColor
        stackView.addArrangedSubview(inputLabel)
        
        let inputTextField = NSTextField()
        inputTextField.font = NSFont.systemFont(ofSize: 12)
        inputTextField.isEditable = true
        inputTextField.isBordered = true
        inputTextField.placeholderString = "Enter text to test cleaning rules..."
        inputTextField.stringValue = "Hello—world    test\u{200B}with\u{00A0}smart\u{201C}quotes\u{201D}"
        stackView.addArrangedSubview(inputTextField)
        
        // Test button
        let testButton = NSButton(title: "Test Cleaning Rules", target: self, action: #selector(testCleaningRules))
        testButton.bezelStyle = .rounded
        testButton.tag = 1 // Store reference to input field
        stackView.addArrangedSubview(testButton)
        
        // Output section
        let outputLabel = NSTextField(labelWithString: "Cleaned Result:")
        outputLabel.font = NSFont.boldSystemFont(ofSize: 12)
        outputLabel.textColor = .labelColor
        stackView.addArrangedSubview(outputLabel)
        
        let outputTextField = NSTextField()
        outputTextField.font = NSFont.systemFont(ofSize: 12)
        outputTextField.isEditable = false
        outputTextField.isBordered = true
        outputTextField.backgroundColor = NSColor.controlBackgroundColor
        outputTextField.tag = 2 // Store reference to output field
        stackView.addArrangedSubview(outputTextField)
        
        // Copy button
        let copyButton = NSButton(title: "Copy Result", target: self, action: #selector(copyTestResult))
        copyButton.bezelStyle = .rounded
        copyButton.tag = 3 // Store reference to output field
        stackView.addArrangedSubview(copyButton)
        
        // Store references for the test function
        testWindow.contentView = stackView
        testWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Store references to the text fields
        objc_setAssociatedObject(testButton, "inputField", inputTextField, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(testButton, "outputField", outputTextField, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(copyButton, "outputField", outputTextField, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    @objc func testCleaningRules(_ sender: NSButton) {
        guard let inputField = objc_getAssociatedObject(sender, "inputField") as? NSTextField,
              let outputField = objc_getAssociatedObject(sender, "outputField") as? NSTextField else {
            return
        }
        
        let inputText = inputField.stringValue
        let cleanedText = clipboardManager.cleaningRules.apply(to: inputText)
        outputField.stringValue = cleanedText
    }
    
    @objc func copyTestResult(_ sender: NSButton) {
        guard let outputField = objc_getAssociatedObject(sender, "outputField") as? NSTextField else {
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputField.stringValue, forType: .string)
        
        showNotification(title: "Copied!", message: "Cleaned text copied to clipboard")
    }
    
    
    @objc func cleanAndPaste() {
        cleanAndPasteClipboard()
    }
    
    @objc func cleanClipboardManually() {
        cleanClipboard()
        showNotification(title: "Clipboard Cleaned", message: "Text has been cleaned and formatting removed")
    }
    
    @objc func toggleAutoClean() {
        autoCleanEnabled.toggle()
        
        // Update the menu bar manager
        menuBarManager.updateAutoCleanState(autoCleanEnabled)
        
        if autoCleanEnabled {
            startClipboardMonitoring()
            showNotification(title: "Auto-clean Enabled", message: "Clipboard will be automatically cleaned when you copy")
        } else {
            stopClipboardMonitoring()
            showNotification(title: "Auto-clean Disabled", message: "Use Cmd+Shift+V or menu to clean clipboard")
        }
    }
    
    func startClipboardMonitoring() {
        lastClipboardChangeCount = NSPasteboard.general.changeCount
        
        clipboardMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let currentChangeCount = NSPasteboard.general.changeCount
            
            if currentChangeCount != self.lastClipboardChangeCount {
                self.lastClipboardChangeCount = currentChangeCount
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.cleanClipboard()
                }
            }
        }
    }
    
    func stopClipboardMonitoring() {
        clipboardMonitorTimer?.invalidate()
        clipboardMonitorTimer = nil
    }
    
    @objc func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindow(cleaningRules: clipboardManager.cleaningRules)
        }
        
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func checkForUpdatesManually() {
        showNotification(title: "Checking for Updates", message: "Looking for the latest version...")
        checkForUpdates()
    }
    
    func cleanClipboard() {
        let pasteboard = NSPasteboard.general
        
        var text: String?
        
        text = pasteboard.string(forType: .string)
        
        if text == nil, let rtfData = pasteboard.data(forType: .rtf) {
            text = NSAttributedString(rtf: rtfData, documentAttributes: nil)?.string
        }
        
        if text == nil, let htmlData = pasteboard.data(forType: .html) {
            text = NSAttributedString(html: htmlData, documentAttributes: nil)?.string
        }
        
        guard let originalText = text else { return }
        
        let cleanedText = clipboardManager.cleaningRules.apply(to: originalText)
        
        pasteboard.clearContents()
        pasteboard.setString(cleanedText, forType: .string)
        pasteboard.setData(Data(), forType: .rtf)
        pasteboard.setData(Data(), forType: .html)
    }
    
    func cleanAndPasteClipboard() {
        let pasteboard = NSPasteboard.general
        
        // Get original text
        var text: String?
        text = pasteboard.string(forType: .string)
        
        if text == nil, let rtfData = pasteboard.data(forType: .rtf) {
            text = NSAttributedString(rtf: rtfData, documentAttributes: nil)?.string
        }
        
        if text == nil, let htmlData = pasteboard.data(forType: .html) {
            text = NSAttributedString(html: htmlData, documentAttributes: nil)?.string
        }
        
        guard let originalText = text else { return }
        
        // Temporarily clean and paste
        let cleanedText = clipboardManager.cleaningRules.apply(to: originalText)
        
        pasteboard.clearContents()
        pasteboard.setString(cleanedText, forType: .string)
        
        // Paste the cleaned text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .combinedSessionState)
            
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            
            vDown?.flags = .maskCommand
            vUp?.flags = .maskCommand
            
            vDown?.post(tap: .cghidEventTap)
            vUp?.post(tap: .cghidEventTap)
            
            // Restore original clipboard after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pasteboard.clearContents()
                pasteboard.setString(originalText, forType: .string)
            }
        }
    }
    
    func showNotification(title: String, message: String) {
        // Check notification authorization status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { [weak self] in
                if settings.authorizationStatus == .authorized {
                    // Show notification
                    let content = UNMutableNotificationContent()
                    content.title = title
                    content.body = message
                    
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request)
                } else {
                    // Fallback to alert dialog
                    self?.showAlert(title: title, message: message)
                }
            }
        }
    }
    
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func checkForUpdates() {
        // Replace this URL with your actual Amazon S3 bucket URL
        guard let url = URL(string: VersionManager.versionCheckURL) else {
            return
        }
        
        // Check if we should skip this update check (rate limiting)
        let lastCheckTime = UserDefaults.standard.double(forKey: "LastUpdateCheck")
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastCheck = currentTime - lastCheckTime
        
        // Only check for updates every 6 hours to avoid spam
        if timeSinceLastCheck < 21600 { // 6 hours in seconds
            print("⏰ Skipping update check - too soon since last check")
            return
        }
        
        // Update last check time
        UserDefaults.standard.set(currentTime, forKey: "LastUpdateCheck")
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    logger.error("Version check failed: \(error.localizedDescription)")
                    print("❌ Version check failed: \(error.localizedDescription)")
                    self.showNotification(title: "Update Check Failed", message: "Could not check for updates. Please try again later.")
                    return
                }
                
                guard let data = data else {
                    logger.error("No version data received")
                    print("❌ No version data received")
                    self.showNotification(title: "Update Check Failed", message: "No version information received.")
                    return
                }
                
                logger.info("Received version data: \(data.count) bytes")
                print("✅ Received data: \(data.count) bytes")
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let latestVersion = json["version"] as? String,
                       let downloadUrl = json["download_url"] as? String,
                       let releaseNotes = json["release_notes"] as? String {
                        
                        let currentVersion = VersionManager.version
                        let skippedVersion = UserDefaults.standard.string(forKey: "SkippedVersion")
                        
                        // Check if this version was skipped
                        if skippedVersion == latestVersion {
                            print("Version \(latestVersion) was skipped by user")
                            return
                        }
                        
                        if VersionManager.isVersionNewer(latestVersion, than: currentVersion) {
                            self.showUpdateAvailableDialog(
                                currentVersion: currentVersion,
                                latestVersion: latestVersion,
                                downloadUrl: downloadUrl,
                                releaseNotes: releaseNotes
                            )
                        } else {
                            self.showNotification(title: "Up to Date", message: "You're running the latest version of Clnbrd!")
                        }
                    }
                } catch {
                    print("Failed to parse version data: \(error.localizedDescription)")
                    self.showNotification(title: "Update Check Failed", message: "Invalid version information received.")
                }
            }
        }
        
        task.resume()
    }
    
    func showUpdateAvailableDialog(currentVersion: String, latestVersion: String, downloadUrl: String, releaseNotes: String) {
        // Show push-style notification first
        showUpdateNotification(currentVersion: currentVersion, latestVersion: latestVersion, releaseNotes: releaseNotes)
        
        // Then show the detailed dialog
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = """
        A new version of Clnbrd is available!
        
        Current Version: \(currentVersion)
        Latest Version: \(latestVersion)
        
        What's New:
        \(releaseNotes)
        
        Would you like to download the update?
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download Update")
        alert.addButton(withTitle: "View Version History")
        alert.addButton(withTitle: "Remind Me Later")
        alert.addButton(withTitle: "Skip This Version")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: downloadUrl) {
                NSWorkspace.shared.open(url)
            }
        } else if response == .alertSecondButtonReturn {
            showVersionHistory()
        } else if response == .alertThirdButtonReturn {
            // Remind me later - do nothing
        } else if response.rawValue == 1003 { // Fourth button (Skip This Version)
            // Skip this version - store it to avoid showing again
            UserDefaults.standard.set(latestVersion, forKey: "SkippedVersion")
        }
    }
    
    func showUpdateNotification(currentVersion: String, latestVersion: String, releaseNotes: String) {
        // Create a modern notification using UserNotifications framework
        let content = UNMutableNotificationContent()
        content.title = "🚀 Clnbrd Update Available!"
        content.subtitle = "Version \(latestVersion) is ready"
        content.body = "Click to download and install the latest version with new features and improvements."
        content.sound = .default
        
        // Store update info in userInfo
        content.userInfo = [
            "type": "update",
            "currentVersion": currentVersion,
            "latestVersion": latestVersion,
            "releaseNotes": releaseNotes
        ]
        
        // Create notification request
        let request = UNNotificationRequest(
            identifier: "clnbrd-update-\(latestVersion)",
            content: content,
            trigger: nil
        )
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
        
        // Also show a menu bar notification
        showMenuBarUpdateNotification(latestVersion: latestVersion)
    }
    
    func showMenuBarUpdateNotification(latestVersion: String) {
        // Update menu bar to show update available
        DispatchQueue.main.async {
            // This will be handled by MenuBarManager
            NotificationCenter.default.post(
                name: NSNotification.Name("UpdateAvailable"),
                object: nil,
                userInfo: ["version": latestVersion]
            )
        }
    }
    
    // Sparkle handles periodic update checking automatically based on Info.plist
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification activation
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String,
           type == "update" {
            
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                // User clicked on the notification
                if let downloadUrl = userInfo["downloadUrl"] as? String,
                   let url = URL(string: downloadUrl) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Always show notifications, even when app is active
        completionHandler([.banner, .sound])
    }
}

class CleaningRules {
    var removeEmdashes = true
    var replaceEmdashWith = ", "
    var normalizeSpaces = true
    var removeZeroWidthChars = true
    var normalizeLineBreaks = true
    var removeTrailingSpaces = true
    var convertSmartQuotes = true
    var removeEmojis = false
    
    // New high-priority cleaning rules
    var removeExtraLineBreaks = true
    var removeLeadingTrailingWhitespace = true
    var removeUrls = true
    var removeHtmlTags = true
    var removeExtraPunctuation = true
    
    var customRules: [CustomRule] = []
    
    func apply(to text: String) -> String {
        var cleaned = text
        
        // Remove emojis FIRST
        if removeEmojis {
            cleaned = cleaned.unicodeScalars.filter { scalar in
                // Keep if it's NOT an emoji
                !(scalar.properties.isEmoji ||
                  scalar.properties.isEmojiPresentation ||
                  scalar.properties.isEmojiModifier ||
                  scalar.properties.isEmojiModifierBase ||
                  (0x1F300...0x1F9FF).contains(scalar.value) || // Emoji blocks
                  (0x2600...0x26FF).contains(scalar.value) ||   // Misc symbols
                  (0x2700...0x27BF).contains(scalar.value))     // Dingbats
            }.map { String($0) }.joined()
        }
        
        // Apply custom find/replace rules
        for rule in customRules {
            if !rule.find.isEmpty {
                cleaned = cleaned.replacingOccurrences(of: rule.find, with: rule.replace)
            }
        }
        
        if removeZeroWidthChars {
            cleaned = cleaned.replacingOccurrences(of: "\u{200B}", with: "")
            cleaned = cleaned.replacingOccurrences(of: "\u{200C}", with: "")
            cleaned = cleaned.replacingOccurrences(of: "\u{200D}", with: "")
            cleaned = cleaned.replacingOccurrences(of: "\u{FEFF}", with: "")
            cleaned = cleaned.replacingOccurrences(of: "\u{2060}", with: "")
            cleaned = cleaned.replacingOccurrences(of: "\u{2061}", with: "")
            cleaned = cleaned.replacingOccurrences(of: "\u{2062}", with: "")
            cleaned = cleaned.replacingOccurrences(of: "\u{2063}", with: "")
            cleaned = cleaned.replacingOccurrences(of: "\u{2064}", with: "")
            
            for i in 0xFE00...0xFE0F {
                if let scalar = Unicode.Scalar(i) {
                    cleaned = cleaned.replacingOccurrences(of: String(scalar), with: "")
                }
            }
            
            cleaned = cleaned.replacingOccurrences(of: "\u{180E}", with: "")
            cleaned = cleaned.replacingOccurrences(of: "\u{034F}", with: "")
            cleaned = cleaned.replacingOccurrences(of: "\u{00AD}", with: "")
        }
        
        if removeEmdashes {
            cleaned = cleaned.replacingOccurrences(of: "—", with: replaceEmdashWith)
            cleaned = cleaned.replacingOccurrences(of: "–", with: replaceEmdashWith)
        }
        
        if convertSmartQuotes {
            cleaned = cleaned.replacingOccurrences(of: "\u{201C}", with: "\"")
            cleaned = cleaned.replacingOccurrences(of: "\u{201D}", with: "\"")
            cleaned = cleaned.replacingOccurrences(of: "\u{2018}", with: "'")
            cleaned = cleaned.replacingOccurrences(of: "\u{2019}", with: "'")
        }
        
        if normalizeSpaces {
            cleaned = cleaned.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        }
        
        if normalizeLineBreaks {
            cleaned = cleaned.replacingOccurrences(of: "\r\n", with: "\n")
            cleaned = cleaned.replacingOccurrences(of: "\r", with: "\n")
        }
        
        if removeTrailingSpaces {
            cleaned = cleaned.replacingOccurrences(of: " +\n", with: "\n", options: .regularExpression)
        }
        
        // New high-priority cleaning rules
        
        if removeExtraLineBreaks {
            // Convert 3+ consecutive line breaks to 2 line breaks
            cleaned = cleaned.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        }
        
        if removeLeadingTrailingWhitespace {
            // Remove leading and trailing whitespace from each line
            let lines = cleaned.components(separatedBy: "\n")
            cleaned = lines.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
        }
        
        if removeUrls {
            // Remove URLs (http, https, ftp, www)
            cleaned = cleaned.replacingOccurrences(of: "https?://[^\\s]+", with: "", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "ftp://[^\\s]+", with: "", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "www\\.[^\\s]+", with: "", options: .regularExpression)
        }
        
        if removeHtmlTags {
            // Remove HTML tags
            cleaned = cleaned.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            // Remove HTML entities
            cleaned = cleaned.replacingOccurrences(of: "&[a-zA-Z0-9#]+;", with: "", options: .regularExpression)
        }
        
        if removeExtraPunctuation {
            // Remove multiple consecutive punctuation marks
            cleaned = cleaned.replacingOccurrences(of: "([.!?]){2,}", with: "$1", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "([,;:]){2,}", with: "$1", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "([-]){3,}", with: "---", options: .regularExpression)
        }
        
        return cleaned
    }
}

class SettingsWindow: NSWindowController {
    var cleaningRules: CleaningRules
    var checkboxes: [NSButton] = []
    var customRulesStackView: NSStackView!
    
    init(cleaningRules: CleaningRules) {
        self.cleaningRules = cleaningRules
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clnbrd Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 600, height: 600)
        
        super.init(window: window)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        guard let window = window else { return }
        
        let mainContainer = NSView()
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add section header for cleaning rules
        stackView.addArrangedSubview(createSectionHeader("Text Cleaning Rules"))
        
        stackView.addArrangedSubview(createCheckbox(title: "Remove zero-width and invisible characters (AI watermarks)", tooltip: "Removes invisible characters that can cause formatting issues and AI watermarks", isOn: cleaningRules.removeZeroWidthChars, tag: 0))
        stackView.addArrangedSubview(createCheckbox(title: "Replace em-dashes (—) with comma+space", tooltip: "Replaces em-dashes with commas for better compatibility across applications", isOn: cleaningRules.removeEmdashes, tag: 1))
        stackView.addArrangedSubview(createCheckbox(title: "Normalize multiple spaces to single space", tooltip: "Converts multiple consecutive spaces to single spaces", isOn: cleaningRules.normalizeSpaces, tag: 2))
        stackView.addArrangedSubview(createCheckbox(title: "Convert smart quotes to straight quotes", tooltip: "Converts curly quotes to standard straight quotes", isOn: cleaningRules.convertSmartQuotes, tag: 3))
        stackView.addArrangedSubview(createCheckbox(title: "Normalize line breaks", tooltip: "Converts all line break types to standard line breaks", isOn: cleaningRules.normalizeLineBreaks, tag: 4))
        stackView.addArrangedSubview(createCheckbox(title: "Remove trailing spaces from lines", tooltip: "Removes spaces at the end of each line", isOn: cleaningRules.removeTrailingSpaces, tag: 5))
        stackView.addArrangedSubview(createCheckbox(title: "Remove emojis", tooltip: "Removes all emoji characters from clipboard text", isOn: cleaningRules.removeEmojis, tag: 6))
        
        // New high-priority cleaning rules
        stackView.addArrangedSubview(createCheckbox(title: "Remove extra line breaks (3+ → 2)", tooltip: "Removes excessive line breaks, keeping maximum of 2 consecutive breaks", isOn: cleaningRules.removeExtraLineBreaks, tag: 7))
        stackView.addArrangedSubview(createCheckbox(title: "Remove leading/trailing whitespace", tooltip: "Removes spaces and tabs at the beginning and end of text", isOn: cleaningRules.removeLeadingTrailingWhitespace, tag: 8))
        stackView.addArrangedSubview(createCheckbox(title: "Remove URLs (http, https, www)", tooltip: "Removes web URLs and links from text", isOn: cleaningRules.removeUrls, tag: 9))
        stackView.addArrangedSubview(createCheckbox(title: "Remove HTML tags and entities", tooltip: "Removes HTML formatting tags like <b>, <i>, &nbsp;, etc.", isOn: cleaningRules.removeHtmlTags, tag: 10))
        stackView.addArrangedSubview(createCheckbox(title: "Remove extra punctuation marks", tooltip: "Removes excessive punctuation marks like multiple periods or exclamation points", isOn: cleaningRules.removeExtraPunctuation, tag: 11))
        
        let spacer1 = NSView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer1)
        NSLayoutConstraint.activate([spacer1.heightAnchor.constraint(equalToConstant: 10)])
        
        // NEW: Granular Rule Configuration Section
        setupGranularRulesSection(in: stackView)
        
        let spacer1b = NSView()
        spacer1b.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer1b)
        NSLayoutConstraint.activate([spacer1b.heightAnchor.constraint(equalToConstant: 10)])
        
        let launchCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: self, action: #selector(toggleLaunchAtLogin(_:)))
        launchCheckbox.state = isLaunchAtLoginEnabled() ? .on : .off
        stackView.addArrangedSubview(launchCheckbox)
        
        let setupButton = NSButton(title: "Setup Instructions", target: self, action: #selector(showSetupInstructions))
        setupButton.bezelStyle = .rounded
        stackView.addArrangedSubview(setupButton)
        
        let securityButton = NSButton(title: "Security Warning Help", target: self, action: #selector(showSecurityHelp))
        securityButton.bezelStyle = .rounded
        stackView.addArrangedSubview(securityButton)
        
        let analyticsButton = NSButton(title: "View Analytics", target: self, action: #selector(showAnalytics))
        analyticsButton.bezelStyle = .rounded
        stackView.addArrangedSubview(analyticsButton)
        
        let analyticsToggle = NSButton(checkboxWithTitle: "Enable Analytics", target: self, action: #selector(toggleAnalytics(_:)))
        analyticsToggle.state = AnalyticsManager.shared.isAnalyticsEnabled() ? .on : .off
        stackView.addArrangedSubview(analyticsToggle)
        
        let testSystemInfoButton = NSButton(title: "Test System Info", target: self, action: #selector(testSystemInformation))
        testSystemInfoButton.bezelStyle = .rounded
        stackView.addArrangedSubview(testSystemInfoButton)
        
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer)
        NSLayoutConstraint.activate([spacer.heightAnchor.constraint(equalToConstant: 20)])
        
        // Add section header for custom rules
        stackView.addArrangedSubview(createSectionHeader("Custom Find & Replace Rules"))
        
        let helpLabel = NSTextField(labelWithString: "Add your own text replacements (applied before built-in rules):")
        helpLabel.font = NSFont.systemFont(ofSize: 11)
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.isEditable = false
        helpLabel.isBordered = false
        helpLabel.backgroundColor = .clear
        stackView.addArrangedSubview(helpLabel)
        
        customRulesStackView = NSStackView()
        customRulesStackView.orientation = .vertical
        customRulesStackView.alignment = .leading
        customRulesStackView.spacing = 8
        customRulesStackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(customRulesStackView)
        
        for (index, rule) in cleaningRules.customRules.enumerated() {
            addCustomRuleRow(find: rule.find, replace: rule.replace, index: index)
        }
        
        let addButton = NSButton(title: "+ Add Rule", target: self, action: #selector(addNewRule))
        addButton.bezelStyle = .rounded
        stackView.addArrangedSubview(addButton)
        
        mainContainer.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: mainContainer.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: mainContainer.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: mainContainer.bottomAnchor, constant: -20)
        ])
        
        window.contentView = mainContainer
    }
    
    func createSectionHeader(_ title: String) -> NSView {
        let container = NSView()
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 14)
        label.textColor = .controlTextColor
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        return container
    }
    
    func createCheckbox(title: String, tooltip: String, isOn: Bool, tag: Int) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(checkboxToggled(_:)))
        checkbox.state = isOn ? .on : .off
        checkbox.tag = tag
        checkbox.toolTip = tooltip
        checkboxes.append(checkbox)
        return checkbox
    }
    
    func addCustomRuleRow(find: String, replace: String, index: Int) {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        container.layer?.cornerRadius = 8
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.separatorColor.cgColor
        
        let rowStack = NSStackView()
        rowStack.orientation = .horizontal
        rowStack.spacing = 12
        rowStack.alignment = .centerY
        rowStack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        
        // Add rule number
        let ruleNumber = NSTextField(labelWithString: "\(index + 1).")
        ruleNumber.font = NSFont.boldSystemFont(ofSize: 12)
        ruleNumber.textColor = .secondaryLabelColor
        ruleNumber.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        ruleNumber.widthAnchor.constraint(equalToConstant: 20).isActive = true
        
        let findLabel = NSTextField(labelWithString: "Find:")
        findLabel.font = NSFont.systemFont(ofSize: 11)
        findLabel.textColor = .secondaryLabelColor
        findLabel.alignment = .right
        findLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        findLabel.widthAnchor.constraint(equalToConstant: 40).isActive = true
        
        let findField = NSTextField(string: find)
        findField.placeholderString = "Text to find"
        findField.tag = index
        findField.delegate = self
        findField.font = NSFont.systemFont(ofSize: 11)
        findField.widthAnchor.constraint(equalToConstant: 180).isActive = true
        
        let replaceLabel = NSTextField(labelWithString: "Replace:")
        replaceLabel.font = NSFont.systemFont(ofSize: 11)
        replaceLabel.textColor = .secondaryLabelColor
        replaceLabel.alignment = .right
        replaceLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        replaceLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        
        let replaceField = NSTextField(string: replace)
        replaceField.placeholderString = "Replacement text"
        replaceField.tag = index + 1000
        replaceField.delegate = self
        replaceField.font = NSFont.systemFont(ofSize: 11)
        replaceField.widthAnchor.constraint(equalToConstant: 180).isActive = true
        
        let deleteButton = NSButton(title: "✕", target: self, action: #selector(deleteRule(_:)))
        deleteButton.bezelStyle = .roundedDisclosure
        deleteButton.tag = index
        deleteButton.setButtonType(.momentaryPushIn)
        deleteButton.font = NSFont.systemFont(ofSize: 12)
        deleteButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        
        rowStack.addArrangedSubview(ruleNumber)
        rowStack.addArrangedSubview(findLabel)
        rowStack.addArrangedSubview(findField)
        rowStack.addArrangedSubview(replaceLabel)
        rowStack.addArrangedSubview(replaceField)
        rowStack.addArrangedSubview(deleteButton)
        
        container.addSubview(rowStack)
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: container.topAnchor),
            rowStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        customRulesStackView.addArrangedSubview(container)
    }
    
    @objc func addNewRule() {
        let index = cleaningRules.customRules.count
        cleaningRules.customRules.append(CustomRule(find: "", replace: ""))
        addCustomRuleRow(find: "", replace: "", index: index)
    }
    
    @objc func deleteRule(_ sender: NSButton) {
        let index = sender.tag
        if index < cleaningRules.customRules.count {
            cleaningRules.customRules.remove(at: index)
            
            for view in customRulesStackView.arrangedSubviews {
                customRulesStackView.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            
            for (idx, rule) in cleaningRules.customRules.enumerated() {
                addCustomRuleRow(find: rule.find, replace: rule.replace, index: idx)
            }
        }
    }
    
    @objc func checkboxToggled(_ sender: NSButton) {
        switch sender.tag {
        case 0: cleaningRules.removeZeroWidthChars = (sender.state == .on)
        case 1: cleaningRules.removeEmdashes = (sender.state == .on)
        case 2: cleaningRules.normalizeSpaces = (sender.state == .on)
        case 3: cleaningRules.convertSmartQuotes = (sender.state == .on)
        case 4: cleaningRules.normalizeLineBreaks = (sender.state == .on)
        case 5: cleaningRules.removeTrailingSpaces = (sender.state == .on)
        case 6: cleaningRules.removeEmojis = (sender.state == .on)
        case 7: cleaningRules.removeExtraLineBreaks = (sender.state == .on)
        case 8: cleaningRules.removeLeadingTrailingWhitespace = (sender.state == .on)
        case 9: cleaningRules.removeUrls = (sender.state == .on)
        case 10: cleaningRules.removeHtmlTags = (sender.state == .on)
        case 11: cleaningRules.removeExtraPunctuation = (sender.state == .on)
        default: break
        }
        
        // Save preferences when settings change
        PreferencesManager.shared.saveCleaningRules(cleaningRules)
    }
    
    @objc func toggleLaunchAtLogin(_ sender: NSButton) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            
            do {
                if service.status == .enabled {
                    // Disable launch at login
                    try service.unregister()
                    sender.state = .off
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.menuBarManager.updateLaunchAtLoginState(false)
                    }
                    logger.info("Launch at login disabled")
                } else {
                    // Enable launch at login
                    try service.register()
                    sender.state = .on
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.menuBarManager.updateLaunchAtLoginState(true)
                    }
                    logger.info("Launch at login enabled")
                }
            } catch {
                logger.error("Failed to toggle launch at login: \(error.localizedDescription)")
                
                // Show alert only if it fails
                let alert = NSAlert()
                alert.messageText = "Could Not Change Launch Setting"
                alert.informativeText = "Please try again or change it manually in System Settings > General > Login Items"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                
                // Reset to actual state
                sender.state = service.status == .enabled ? .on : .off
            }
        } else {
            // Fallback for older macOS
            let alert = NSAlert()
            alert.messageText = "Launch at Login"
            alert.informativeText = """
            To enable Launch at Login:
            
            1. Open System Settings
            2. Go to General → Login Items
            3. Click the '+' button
            4. Add Clnbrd
            
            Would you like to open System Settings now?
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
            }
            
            sender.state = .off
        }
    }
    
    @objc func showSetupInstructions() {
        let alert = NSAlert()
        alert.messageText = "Clnbrd Setup Instructions"
        alert.informativeText = """
        HOW TO USE CLNBRD:
        • Press ⌘⌥V (Cmd+Option+V) to paste cleaned text
        • Use menu bar icon → "Clean Clipboard Now" for permanent cleaning
        • Enable "Auto-clean on Copy" to automatically clean when copying
        
        REQUIRED PERMISSIONS FOR HOTKEY (⌘⌥V):
        
        Clnbrd needs TWO permissions to work:
        
        1️⃣ ACCESSIBILITY
           • Required to simulate paste (⌘V) action
           • Click "Open Accessibility" below
        
        2️⃣ INPUT MONITORING  
           • Required to detect ⌘⌥V hotkey
           • Click "Open Input Monitoring" below
        
        After granting both permissions:
        • Quit Clnbrd (⌘Q)
        • Relaunch from Applications folder
        • Test the ⌘⌥V hotkey!
        
        FEATURES:
        • Removes formatting (bold, italic, colors)
        • Removes AI watermarks (invisible characters)
        • Removes URLs, HTML tags, extra punctuation
        • Removes emojis (when enabled)
        • Removes extra line breaks and whitespace
        • Custom find & replace rules
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Accessibility")
        alert.addButton(withTitle: "Open Input Monitoring")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            // Open Accessibility Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            // Open Input Monitoring Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }
    
    @objc func showSecurityHelp() {
        let alert = NSAlert()
        alert.messageText = "Security Warning Help"
        alert.informativeText = """
        If you see "Clnbrd.app cannot be opened because it is not from an identified developer":
        
        METHOD 1 (Recommended):
        1. Go to System Settings → Privacy & Security
        2. Scroll down to find "Clnbrd.app was blocked"
        3. Click "Open Anyway"
        4. Click "Open" in the confirmation dialog
        
        METHOD 2 (Alternative):
        1. Right-click Clnbrd.app in Finder
        2. Select "Open" from the context menu
        3. Click "Open" in the security dialog
        
        WHY THIS HAPPENS:
        This is normal for apps not distributed through the App Store. macOS protects you by blocking unsigned apps, but you can safely allow Clnbrd to run.
        
        Would you like to open System Settings now?
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!)
        }
    }
    
    @objc func emailDeveloper() {
        // Gather comprehensive system information
        let systemInfo = SystemInfoUtility.getSystemInformation()
        let formattedSystemInfo = SystemInfoUtility.formatSystemInformation(systemInfo)
        
        // Get current settings
        let settings = """
        Remove Zero-Width Chars: \(cleaningRules.removeZeroWidthChars)
        Remove Em-dashes: \(cleaningRules.removeEmdashes)
        Normalize Spaces: \(cleaningRules.normalizeSpaces)
        Convert Smart Quotes: \(cleaningRules.convertSmartQuotes)
        Normalize Line Breaks: \(cleaningRules.normalizeLineBreaks)
        Remove Trailing Spaces: \(cleaningRules.removeTrailingSpaces)
        Remove Emojis: \(cleaningRules.removeEmojis)
        Remove Extra Line Breaks: \(cleaningRules.removeExtraLineBreaks)
        Remove Leading/Trailing Whitespace: \(cleaningRules.removeLeadingTrailingWhitespace)
        Remove URLs: \(cleaningRules.removeUrls)
        Remove HTML Tags: \(cleaningRules.removeHtmlTags)
        Remove Extra Punctuation: \(cleaningRules.removeExtraPunctuation)
        Custom Rules: \(cleaningRules.customRules.count)
        """
        
        let emailBody = """
        Hi Allan,
        
        [Please describe your issue or feedback here]
        
        
        
        Current Settings:
        \(settings)
        
        \(formattedSystemInfo)
        """
        
        let encodedBody = emailBody.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let emailURL = "mailto:olivedesignstudios@gmail.com?subject=Clnbrd%20Support&body=\(encodedBody)"
        
        if let url = URL(string: emailURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // Test function to verify system information collection
    @objc func testSystemInformation() {
        let systemInfo = SystemInfoUtility.getSystemInformation()
        let formatted = SystemInfoUtility.formatSystemInformation(systemInfo)
        
        print("=== SYSTEM INFORMATION TEST ===")
        print(formatted)
        print("=== END TEST ===")
        
        // Also show in a dialog for manual verification
        let alert = NSAlert()
        alert.messageText = "System Information Test"
        alert.informativeText = "App Version: \(VersionManager.version) (Build \(VersionManager.buildNumber))\n\n\(formatted)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy to Clipboard")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString("App Version: \(VersionManager.version) (Build \(VersionManager.buildNumber))\n\n\(formatted)", forType: .string)
        }
    }
    
    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return UserDefaults.standard.bool(forKey: "LaunchAtLogin")
        }
    }
    
    @objc func showAnalytics() {
        let analyticsSummary = AnalyticsManager.shared.getAnalyticsSummary()
        let systemInfo = SystemInfoUtility.getSystemInformation()
        let formattedSystemInfo = SystemInfoUtility.formatSystemInformation(systemInfo)
        
        let fullSummary = analyticsSummary + "\n\n" + formattedSystemInfo
        
        let alert = NSAlert()
        alert.messageText = "Clnbrd Analytics"
        alert.informativeText = fullSummary
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy to Clipboard")
        alert.addButton(withTitle: "Email Support")
        alert.addButton(withTitle: "Reset Analytics")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            // Copy to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(fullSummary, forType: .string)
        case .alertSecondButtonReturn:
            // Reset analytics
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Reset Analytics"
            confirmAlert.informativeText = "This will permanently delete all analytics data. Are you sure?"
            confirmAlert.alertStyle = .warning
            confirmAlert.addButton(withTitle: "Reset")
            confirmAlert.addButton(withTitle: "Cancel")
            
            if confirmAlert.runModal() == .alertFirstButtonReturn {
                AnalyticsManager.shared.resetAnalytics()
            }
        case .alertThirdButtonReturn:
            // Email support
            emailSupportWithAnalytics(fullSummary)
        default:
            break
        }
    }
    
    @objc func toggleAnalytics(_ sender: NSButton) {
        let enabled = sender.state == .on
        AnalyticsManager.shared.setAnalyticsEnabled(enabled)
        
        let message = enabled ? "Analytics enabled. Usage data will be collected to help improve Clnbrd." : "Analytics disabled. No usage data will be collected."
        
        let alert = NSAlert()
        alert.messageText = "Analytics \(enabled ? "Enabled" : "Disabled")"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func emailSupportWithAnalytics(_ analyticsData: String) {
        let subject = "Clnbrd Support Request - Version \(VersionManager.version)"
        let systemInfo = SystemInfoUtility.getSystemInformation()
        let formattedSystemInfo = SystemInfoUtility.formatSystemInformation(systemInfo)
        
        let body = """
        Hi Allan,
        
        I'm experiencing an issue with Clnbrd and would like to report it.
        
        Issue Description:
        [Please describe your issue here]
        
        Steps to Reproduce:
        1. 
        2. 
        3. 
        
        Expected Behavior:
        [What should happen]
        
        Actual Behavior:
        [What actually happens]
        
        Analytics Data:
        \(analyticsData)
        
        \(formattedSystemInfo)
        
        Thank you for your help!
        
        Best regards,
        [Your name]
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        
        let mailtoURL = "mailto:olivedesignstudios@gmail.com?subject=\(encodedSubject)&body=\(encodedBody)"
        
        // Check if URL is too long
        if mailtoURL.count > 2000 {
            // Fallback: copy to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(body, forType: .string)
            
            let fallbackAlert = NSAlert()
            fallbackAlert.messageText = "Email Support"
            fallbackAlert.informativeText = "The support information is too long for email. It has been copied to your clipboard. Please paste it into an email to olivedesignstudios@gmail.com"
            fallbackAlert.alertStyle = .informational
            fallbackAlert.addButton(withTitle: "OK")
            fallbackAlert.runModal()
            return
        }
        
        if let url = URL(string: mailtoURL) {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback: copy to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(body, forType: .string)
            
            let fallbackAlert = NSAlert()
            fallbackAlert.messageText = "Email Support"
            fallbackAlert.informativeText = "Could not open email client. Support information has been copied to your clipboard. Please paste it into an email to olivedesignstudios@gmail.com"
            fallbackAlert.alertStyle = .informational
            fallbackAlert.addButton(withTitle: "OK")
            fallbackAlert.runModal()
        }
    }
}

// MARK: - MenuBarManagerDelegate

extension AppDelegate: MenuBarManagerDelegate {
    func hotkeyTriggered() {
        clipboardManager.cleanAndPasteClipboard()
    }
    
    func cleanAndPasteRequested() {
        clipboardManager.cleanAndPasteClipboard()
    }
    
    func cleanClipboardRequested() {
        clipboardManager.cleanClipboard()
        showNotification(title: "Clipboard Cleaned", message: "Text has been cleaned and formatting removed")
    }
    
    func toggleAutoCleanRequested() {
        autoCleanEnabled.toggle()
        preferencesManager.saveAutoCleanEnabled(autoCleanEnabled)
        
        menuBarManager.updateAutoCleanState(autoCleanEnabled)
        
        if autoCleanEnabled {
            clipboardManager.startClipboardMonitoring()
            showNotification(title: "Auto-clean Enabled", message: "Clipboard will be automatically cleaned when you copy")
        } else {
            clipboardManager.stopClipboardMonitoring()
            showNotification(title: "Auto-clean Disabled", message: "Use ⌘⌥V or menu to clean clipboard")
        }
    }
    
    func openSettingsRequested() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindow(cleaningRules: clipboardManager.cleaningRules)
        }
        
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func checkForUpdatesRequested() {
        // Use Sparkle's updater to check for updates
        updaterController.updater.checkForUpdates()
    }
    
    func reportIssueRequested() {
        // Get analytics data for the support email
        let analyticsData = AnalyticsManager.shared.getAnalyticsSummary()
        let systemInfo = SystemInfoUtility.getSystemInformation()
        let formattedSystemInfo = SystemInfoUtility.formatSystemInformation(systemInfo)
        
        // Create support email with analytics and system info
        let subject = "Clnbrd Support Request - v\(VersionManager.version) Build \(VersionManager.buildNumber)"
        let body = """
        Hi Allan,
        
        Please describe the issue you're experiencing:
        
        [Your description here]
        
        Steps to Reproduce:
        1. 
        2. 
        3. 
        
        Expected Behavior:
        [What should happen]
        
        Actual Behavior:
        [What actually happens]
        
        App Version: \(VersionManager.version) (Build \(VersionManager.buildNumber))
        
        Analytics Data:
        \(analyticsData)
        
        \(formattedSystemInfo)
        
        Thank you for your help!
        
        Best regards,
        [Your name]
        """
        
        // Encode the email components properly
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? body
        
        // Create mailto URL
        let mailtoURL = "mailto:olivedesignstudios@gmail.com?subject=\(encodedSubject)&body=\(encodedBody)"
        
        logger.info("Opening support email with version \(VersionManager.version) build \(VersionManager.buildNumber)")
        
        // Check if URL is too long (mailto URLs have length limits)
        if mailtoURL.count > 2000 {
            logger.warning("Email URL too long (\(mailtoURL.count) chars), falling back to clipboard")
            // Fallback: copy to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(body, forType: .string)
            
            let fallbackAlert = NSAlert()
            fallbackAlert.messageText = "Email Support"
            fallbackAlert.informativeText = "The support information is too long for email. It has been copied to your clipboard. Please paste it into an email to olivedesignstudios@gmail.com"
            fallbackAlert.alertStyle = .informational
            fallbackAlert.addButton(withTitle: "OK")
            fallbackAlert.runModal()
            return
        }
        
        // Open email client
        if let url = URL(string: mailtoURL) {
            let success = NSWorkspace.shared.open(url)
            if success {
                logger.info("Email client opened successfully")
                showNotification(title: "Email Opened", message: "Your email client should now be open with a pre-filled support request.")
            } else {
                logger.error("Failed to open email client")
                showAlert(title: "Email Error", message: "Could not open your email client. Please email olivedesignstudios@gmail.com directly.")
            }
        } else {
            logger.error("Invalid mailto URL")
            showAlert(title: "Email Error", message: "Could not create email. Please contact olivedesignstudios@gmail.com directly.")
        }
    }
    
    func showInstallationGuideRequested() {
        showInstallationGuide()
    }
    
    @objc func openAboutRequested() {
        let aboutWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        aboutWindow.title = "About Clnbrd"
        aboutWindow.center()
        aboutWindow.isReleasedWhenClosed = false
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 12
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        // App icon
        let iconView = NSImageView()
        if let appIcon = NSImage(named: "AppIcon") {
            iconView.image = appIcon
        } else {
            iconView.image = NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: "Clnbrd app icon")
        }
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.frame = NSRect(x: 0, y: 0, width: 80, height: 80)
        stackView.addArrangedSubview(iconView)
        
        // App name
        let nameLabel = NSTextField(labelWithString: "Clnbrd")
        nameLabel.font = NSFont.boldSystemFont(ofSize: 28)
        nameLabel.textColor = .controlTextColor
        nameLabel.alignment = .center
        stackView.addArrangedSubview(nameLabel)
        
        // Tagline
        let taglineLabel = NSTextField(labelWithString: "Professional Clipboard Cleaning for macOS")
        taglineLabel.font = NSFont.systemFont(ofSize: 14)
        taglineLabel.textColor = .secondaryLabelColor
        taglineLabel.alignment = .center
        stackView.addArrangedSubview(taglineLabel)
        
        // Version info
        let versionLabel = NSTextField(labelWithString: VersionManager.fullVersion)
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.textColor = .tertiaryLabelColor
        versionLabel.alignment = .center
        stackView.addArrangedSubview(versionLabel)
        
        // Features section - split into two lines
        let featuresLabel1 = NSTextField(labelWithString: "✨ Smart Text Cleaning • ⌘⌥V Hotkey • Auto-clean")
        featuresLabel1.font = NSFont.systemFont(ofSize: 11)
        featuresLabel1.textColor = .secondaryLabelColor
        featuresLabel1.alignment = .center
        stackView.addArrangedSubview(featuresLabel1)
        
        let featuresLabel2 = NSTextField(labelWithString: "Custom Rules • Privacy Analytics • Crash Reporting")
        featuresLabel2.font = NSFont.systemFont(ofSize: 11)
        featuresLabel2.textColor = .secondaryLabelColor
        featuresLabel2.alignment = .center
        stackView.addArrangedSubview(featuresLabel2)
        
        // Copyright
        let copyrightLabel = NSTextField(labelWithString: "© 2025 Allan Alomes • All rights reserved")
        copyrightLabel.font = NSFont.systemFont(ofSize: 10)
        copyrightLabel.textColor = .tertiaryLabelColor
        copyrightLabel.alignment = .center
        stackView.addArrangedSubview(copyrightLabel)
        
        // Buttons container
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        
        // Website button
        let websiteButton = NSButton(title: "Website", target: self, action: #selector(openWebsite))
        websiteButton.bezelStyle = .rounded
        buttonStack.addArrangedSubview(websiteButton)
        
        // Support button
        let supportButton = NSButton(title: "Support", target: self, action: #selector(openSupport))
        supportButton.bezelStyle = .rounded
        buttonStack.addArrangedSubview(supportButton)
        
        stackView.addArrangedSubview(buttonStack)
        
        aboutWindow.contentView = stackView
        aboutWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Store reference to prevent deallocation
        self.aboutWindow = aboutWindow
    }
    
    @objc func openWebsite() {
        if let url = URL(string: "https://github.com/oliveoi1/Clnbrd") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func openSupport() {
        reportIssueRequested()
    }
    
    func showSamplesRequested() {
        showSamples()
    }
    
    // MARK: - URL Tracking Cleaner Test
    
    func testURLCleaning() {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 URL TRACKING CLEANER TEST")
        print(String(repeating: "=", count: 60) + "\n")
        
        let tests = [
            (
                name: "YouTube",
                url: "https://youtu.be/dQw4w9WgXcQ?si=ABC123tracking",
                expected: "https://youtu.be/dQw4w9WgXcQ"
            ),
            (
                name: "Amazon",
                url: "https://www.amazon.com/product/B08N5WRWNW/ref=sr_1_1?crid=ABC&sr=8-1",
                expected: "https://www.amazon.com/product/B08N5WRWNW"
            ),
            (
                name: "Spotify",
                url: "https://open.spotify.com/track/3n3Ppam7vgaVa1iaRUc9Lp?si=abc123",
                expected: "https://open.spotify.com/track/3n3Ppam7vgaVa1iaRUc9Lp"
            ),
            (
                name: "Google",
                url: "https://www.google.com/search?q=test&gs_lcrp=abc&ved=123",
                expected: "https://www.google.com/search?q=test"
            ),
            (
                name: "Instagram",
                url: "https://www.instagram.com/p/ABC123/?igsh=xyz789",
                expected: "https://www.instagram.com/p/ABC123/"
            ),
            (
                name: "Twitter",
                url: "https://x.com/user/status/123?s=20&t=abc123",
                expected: "https://x.com/user/status/123"
            ),
            (
                name: "UTM Tracking",
                url: "https://example.com/?utm_source=twitter&utm_campaign=spring&fbclid=123",
                expected: "https://example.com/"
            )
        ]
        
        var passed = 0
        var failed = 0
        
        for test in tests {
            let result = URLTrackingCleaner.cleanURL(test.url)
            let success = result == test.expected
            
            if success {
                print("✅ \(test.name)")
                print("   Input:  \(test.url)")
                print("   Output: \(result)")
                passed += 1
            } else {
                print("❌ \(test.name) FAILED")
                print("   Input:    \(test.url)")
                print("   Expected: \(test.expected)")
                print("   Got:      \(result)")
                failed += 1
            }
            print("")
        }
        
        // Test cleaning multiple URLs in text
        let textWithURLs = """
        Check out: https://youtu.be/dQw4w9WgXcQ?si=tracking
        And buy: https://www.amazon.com/product/B08N5WRWNW/ref=sr_1_1?crid=ABC
        """
        
        let cleanedText = URLTrackingCleaner.cleanURLsInText(textWithURLs)
        let hasTracking = cleanedText.contains("?si=") || cleanedText.contains("/ref=")
        
        if !hasTracking {
            print("✅ Multiple URLs in Text")
            print("   Cleaned successfully!")
            passed += 1
        } else {
            print("❌ Multiple URLs in Text FAILED")
            print("   Still contains tracking")
            failed += 1
        }
        
        print("\n" + String(repeating: "=", count: 60))
        print("RESULTS: \(passed) passed, \(failed) failed")
        print(String(repeating: "=", count: 60) + "\n")
        
        logger.info("URL Tracking Cleaner tests completed: \(passed) passed, \(failed) failed")
    }
    
    func showVersionHistoryRequested() {
        showVersionHistory()
    }
    
    func isAutoCleanEnabled() -> Bool {
        return autoCleanEnabled
    }
}

// Sparkle handles update checking and notifications automatically

extension SettingsWindow: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        
        let index = textField.tag % 1000
        
        if index < cleaningRules.customRules.count {
            let currentRule = cleaningRules.customRules[index]
            let newRule: CustomRule
            
            if textField.tag < 1000 {
                newRule = CustomRule(find: textField.stringValue, replace: currentRule.replace)
            } else {
                newRule = CustomRule(find: currentRule.find, replace: textField.stringValue)
            }
            
            cleaningRules.customRules[index] = newRule
            
            // Save preferences when custom rules change
            PreferencesManager.shared.saveCleaningRules(cleaningRules)
        }
    }
}
