import Cocoa
import os.log
import ServiceManagement

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "settings")

/// Settings window for configuring cleaning rules and application preferences
class SettingsWindow: NSWindowController {
    var cleaningRules: CleaningRules
    var checkboxes: [NSButton] = []
    var customRulesStackView: NSStackView!
    
    init(cleaningRules: CleaningRules) {
        self.cleaningRules = cleaningRules
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 550),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clnbrd Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 500, height: 400)
        
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
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8  // Increased from 12 for better breathing room
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        // Add section header for cleaning rules
        stackView.addArrangedSubview(createSectionHeader("📝 Basic Text Cleaning"))
        stackView.addArrangedSubview(createSpacer(height: 4))
        
        stackView.addArrangedSubview(createCheckbox(title: "Remove zero-width and invisible characters (AI watermarks)", tooltip: "Removes invisible AI watermarks and hidden Unicode.\n\nExample:\n  Before: \"Hello\u{200B}World\" (has invisible space)\n  After:  \"HelloWorld\"", isOn: cleaningRules.removeZeroWidthChars, tag: 0))
        stackView.addArrangedSubview(createCheckbox(title: "Replace em-dashes (—) with comma+space", tooltip: "Replaces em-dashes with commas.\n\nExample:\n  Before: \"Hello—world\"\n  After:  \"Hello, world\"", isOn: cleaningRules.removeEmdashes, tag: 1))
        stackView.addArrangedSubview(createCheckbox(title: "Normalize multiple spaces to single space", tooltip: "Converts multiple consecutive spaces to one.\n\nExample:\n  Before: \"Hello    world\"\n  After:  \"Hello world\"", isOn: cleaningRules.normalizeSpaces, tag: 2))
        stackView.addArrangedSubview(createCheckbox(title: "Convert smart quotes to straight quotes", tooltip: "Converts curly quotes to standard quotes.\n\nExample:\n  Before: \"Hello 'world'\"\n  After:  \"Hello 'world'\"", isOn: cleaningRules.convertSmartQuotes, tag: 3))
        stackView.addArrangedSubview(createCheckbox(title: "Normalize line breaks", tooltip: "Converts all line break types to standard.\n\nExample:\n  Before: \"Line1\\r\\nLine2\" (Windows)\n  After:  \"Line1\\nLine2\" (Unix)", isOn: cleaningRules.normalizeLineBreaks, tag: 4))
        stackView.addArrangedSubview(createCheckbox(title: "Remove trailing spaces from lines", tooltip: "Removes spaces at the end of each line.\n\nExample:\n  Before: \"Hello world   \\n\"\n  After:  \"Hello world\\n\"", isOn: cleaningRules.removeTrailingSpaces, tag: 5))
        stackView.addArrangedSubview(createCheckbox(title: "Remove emojis", tooltip: "Removes all emoji characters.\n\nExample:\n  Before: \"Hello 🌎 world! 🎉\"\n  After:  \"Hello  world! \"", isOn: cleaningRules.removeEmojis, tag: 6))
        
        stackView.addArrangedSubview(createSpacer(height: 12))
        stackView.addArrangedSubview(createSectionHeader("🧹 Advanced Cleaning"))
        stackView.addArrangedSubview(createSpacer(height: 4))
        
        stackView.addArrangedSubview(createCheckbox(title: "Remove extra line breaks (3+ → 2)", tooltip: "Limits consecutive line breaks to 2 maximum.\n\nExample:\n  Before: \"Para1\\n\\n\\n\\n\\nPara2\"\n  After:  \"Para1\\n\\nPara2\"", isOn: cleaningRules.removeExtraLineBreaks, tag: 7))
        stackView.addArrangedSubview(createCheckbox(title: "Remove leading/trailing whitespace", tooltip: "Trims spaces/tabs from start and end.\n\nExample:\n  Before: \"   Hello world   \"\n  After:  \"Hello world\"", isOn: cleaningRules.removeLeadingTrailingWhitespace, tag: 8))
        stackView.addArrangedSubview(createCheckbox(title: "Remove URL tracking parameters", tooltip: "Strips tracking from URLs (150+ params!).\n\nExamples:\n  Before: \"youtu.be/VIDEO?si=xyz123\"\n  After:  \"youtu.be/VIDEO\"\n\n  Before: \"amazon.com/product?tag=aff\"\n  After:  \"amazon.com/product\"\n\nRemoves: UTM, fbclid, gclid, igshid, etc.", isOn: cleaningRules.removeUrlTracking, tag: 9))
        stackView.addArrangedSubview(createCheckbox(title: "Remove URL protocols (https://, www.)", tooltip: "Strips protocols but keeps domain visible.\n\nExample:\n  Before: \"https://example.com\"\n  After:  \"example.com\"\n\nPerfect for Excel/Sheets paste values!", isOn: cleaningRules.removeUrls, tag: 10))
        stackView.addArrangedSubview(createCheckbox(title: "Remove HTML tags and entities", tooltip: "Removes HTML markup.\n\nExample:\n  Before: \"<b>Hello</b> &nbsp; world!\"\n  After:  \"Hello  world!\"", isOn: cleaningRules.removeHtmlTags, tag: 11))
        stackView.addArrangedSubview(createCheckbox(title: "Remove extra punctuation marks", tooltip: "Removes excessive punctuation.\n\nExample:\n  Before: \"What!?!?!? Really???\"\n  After:  \"What!? Really?\"", isOn: cleaningRules.removeExtraPunctuation, tag: 12))
        
        let spacer1 = NSView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer1)
        NSLayoutConstraint.activate([spacer1.heightAnchor.constraint(equalToConstant: 10)])
        
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
        
        stackView.addArrangedSubview(createSpacer(height: 20))
        
        // Add section header for custom rules
        stackView.addArrangedSubview(createSectionHeader("🔧 Custom Find & Replace Rules"))
        stackView.addArrangedSubview(createSpacer(height: 4))
        
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
        
        // Configure scroll view
        scrollView.documentView = stackView
        mainContainer.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor),
            
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        
        window.contentView = mainContainer
    }
    
    // MARK: - UI Creation Helpers
    
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
    
    func createSpacer(height: CGFloat) -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spacer.heightAnchor.constraint(equalToConstant: height)
        ])
        return spacer
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
    
    // MARK: - Actions
    
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
        case 9: cleaningRules.removeUrlTracking = (sender.state == .on)
        case 10: cleaningRules.removeUrls = (sender.state == .on)
        case 11: cleaningRules.removeHtmlTags = (sender.state == .on)
        case 12: cleaningRules.removeExtraPunctuation = (sender.state == .on)
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

// MARK: - NSTextFieldDelegate

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

