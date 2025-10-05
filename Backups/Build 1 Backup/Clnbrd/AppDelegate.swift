import Cocoa
import Carbon
import UserNotifications


class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var eventMonitor: Any?
    var settingsWindowController: SettingsWindow?
    var clipboardMonitorTimer: Timer?
    var lastClipboardChangeCount = 0
    var autoCleanEnabled = false
    
    var cleaningRules = CleaningRules()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        registerHotKey()
        checkFirstLaunch()
    }
    
    func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        
        if !hasLaunchedBefore {
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let alert = NSAlert()
                alert.messageText = "Welcome to Clnbrd!"
                alert.informativeText = """
                Clnbrd cleans your clipboard text by removing:
                • Formatting (bold, italic, colors)
                • AI watermarks (invisible characters)
                • Emojis (optional)
                • Smart quotes, em-dashes, extra spaces
                
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
                alert.addButton(withTitle: "I'll Do It Later")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        }
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.plaintext", accessibilityDescription: "Clipboard Cleaner")
            button.imagePosition = .imageLeft
        }
        
        menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Paste Cleaned (⌘⌥V)", action: #selector(cleanAndPaste), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Clean Clipboard Now", action: #selector(cleanClipboardManually), keyEquivalent: "c"))
        menu.addItem(NSMenuItem.separator())
        
        let autoCleanItem = NSMenuItem(title: "Auto-clean on Copy", action: #selector(toggleAutoClean), keyEquivalent: "")
        autoCleanItem.state = autoCleanEnabled ? .on : .off
        menu.addItem(autoCleanItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "About Clnbrd", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    func registerHotKey() {
        // Use Cmd+Option+V to avoid conflicts with Chrome's Cmd+Shift+V
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .option]) && event.keyCode == 9 {
                DispatchQueue.main.async {
                    self?.cleanAndPasteClipboard()
                }
            }
        }
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
        
        if let menuItem = menu.item(withTitle: "Auto-clean on Copy") {
            menuItem.state = autoCleanEnabled ? .on : .off
        }
        
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
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.cleanClipboard()
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
            settingsWindowController = SettingsWindow(cleaningRules: cleaningRules)
        }
        
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func openAbout() {
        let alert = NSAlert()
        alert.messageText = "Clnbrd"
        alert.informativeText = """
        Version 1.0
        
        Brought to you by Allan Alomes
        
        Contact: olivedesignstudios@gmail.com
        for support
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
        
        let cleanedText = cleaningRules.apply(to: originalText)
        
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
        let cleanedText = cleaningRules.apply(to: originalText)
        
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
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
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
    
    var customRules: [(find: String, replace: String)] = []
    
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
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Built-in Cleaning Rules:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        stackView.addArrangedSubview(titleLabel)
        
        stackView.addArrangedSubview(createCheckbox(title: "Remove zero-width and invisible characters (AI watermarks)", isOn: cleaningRules.removeZeroWidthChars, tag: 0))
        stackView.addArrangedSubview(createCheckbox(title: "Replace em-dashes (—) with comma+space", isOn: cleaningRules.removeEmdashes, tag: 1))
        stackView.addArrangedSubview(createCheckbox(title: "Normalize multiple spaces to single space", isOn: cleaningRules.normalizeSpaces, tag: 2))
        stackView.addArrangedSubview(createCheckbox(title: "Convert smart quotes to straight quotes", isOn: cleaningRules.convertSmartQuotes, tag: 3))
        stackView.addArrangedSubview(createCheckbox(title: "Normalize line breaks", isOn: cleaningRules.normalizeLineBreaks, tag: 4))
        stackView.addArrangedSubview(createCheckbox(title: "Remove trailing spaces from lines", isOn: cleaningRules.removeTrailingSpaces, tag: 5))
        stackView.addArrangedSubview(createCheckbox(title: "Remove emojis", isOn: cleaningRules.removeEmojis, tag: 6))
        
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
        
        let emailButton = NSButton(title: "Email Developer", target: self, action: #selector(emailDeveloper))
        emailButton.bezelStyle = .rounded
        stackView.addArrangedSubview(emailButton)
        
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer)
        NSLayoutConstraint.activate([spacer.heightAnchor.constraint(equalToConstant: 20)])
        
        let customRulesTitle = NSTextField(labelWithString: "Custom Find & Replace Rules:")
        customRulesTitle.font = NSFont.boldSystemFont(ofSize: 13)
        customRulesTitle.isEditable = false
        customRulesTitle.isBordered = false
        customRulesTitle.backgroundColor = .clear
        stackView.addArrangedSubview(customRulesTitle)
        
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
    
    func createCheckbox(title: String, isOn: Bool, tag: Int) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(checkboxToggled(_:)))
        checkbox.state = isOn ? .on : .off
        checkbox.tag = tag
        checkboxes.append(checkbox)
        return checkbox
    }
    
    func addCustomRuleRow(find: String, replace: String, index: Int) {
        let rowStack = NSStackView()
        rowStack.orientation = .horizontal
        rowStack.spacing = 8
        rowStack.alignment = .centerY
        
        let findLabel = NSTextField(labelWithString: "Find:")
        findLabel.alignment = .right
        findLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        let findField = NSTextField(string: find)
        findField.placeholderString = "Text to find"
        findField.tag = index
        findField.delegate = self
        findField.widthAnchor.constraint(equalToConstant: 180).isActive = true
        
        let replaceLabel = NSTextField(labelWithString: "Replace:")
        replaceLabel.alignment = .right
        replaceLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        let replaceField = NSTextField(string: replace)
        replaceField.placeholderString = "Replacement text"
        replaceField.tag = index + 1000
        replaceField.delegate = self
        replaceField.widthAnchor.constraint(equalToConstant: 180).isActive = true
        
        let deleteButton = NSButton(title: "✕", target: self, action: #selector(deleteRule(_:)))
        deleteButton.bezelStyle = .roundedDisclosure
        deleteButton.tag = index
        deleteButton.setButtonType(.momentaryPushIn)
        
        rowStack.addArrangedSubview(findLabel)
        rowStack.addArrangedSubview(findField)
        rowStack.addArrangedSubview(replaceLabel)
        rowStack.addArrangedSubview(replaceField)
        rowStack.addArrangedSubview(deleteButton)
        
        customRulesStackView.addArrangedSubview(rowStack)
    }
    
    @objc func addNewRule() {
        let index = cleaningRules.customRules.count
        cleaningRules.customRules.append((find: "", replace: ""))
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
        default: break
        }
    }
    
    @objc func toggleLaunchAtLogin(_ sender: NSButton) {
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
        
        // Reset checkbox since we can't programmatically enable it
        sender.state = .off
    }
    
    @objc func showSetupInstructions() {
        let alert = NSAlert()
        alert.messageText = "Clnbrd Setup Instructions"
        alert.informativeText = """
        HOW TO USE CLNBRD:
        • Press ⌘⌥V (Cmd+Option+V) to paste cleaned text
        • Use menu bar icon → "Clean Clipboard Now" for permanent cleaning
        • Enable "Auto-clean on Copy" to automatically clean when copying
        
        ENABLE HOTKEY (Required for ⌘⌥V):
        1. Open System Settings
        2. Go to Privacy & Security → Accessibility
        3. Find Clnbrd in the list and toggle it ON
        4. Restart Clnbrd
        
        FEATURES:
        • Removes formatting (bold, italic, colors)
        • Removes AI watermarks (invisible characters)
        • Removes emojis (when enabled)
        • Custom find & replace rules
        
        Would you like to open System Settings now?
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
    
    @objc func emailDeveloper() {
        // Gather system information
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let macModel = getMacModel()
        
        // Get current date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        let currentDateTime = dateFormatter.string(from: Date())
        let timeZoneName = TimeZone.current.abbreviation() ?? "Unknown"
        
        // Get current settings
        let settings = """
        Remove Zero-Width Chars: \(cleaningRules.removeZeroWidthChars)
        Remove Em-dashes: \(cleaningRules.removeEmdashes)
        Normalize Spaces: \(cleaningRules.normalizeSpaces)
        Convert Smart Quotes: \(cleaningRules.convertSmartQuotes)
        Normalize Line Breaks: \(cleaningRules.normalizeLineBreaks)
        Remove Trailing Spaces: \(cleaningRules.removeTrailingSpaces)
        Remove Emojis: \(cleaningRules.removeEmojis)
        Custom Rules: \(cleaningRules.customRules.count)
        """
        
        let emailBody = """
        Hi Allan,
        
        [Please describe your issue or feedback here]
        
        
        
        ---
        Debug Information:
        Date/Time: \(currentDateTime) \(timeZoneName)
        App Version: \(appVersion)
        macOS Version: \(osVersion)
        Mac Model: \(macModel)
        
        Current Settings:
        \(settings)
        """
        
        let encodedBody = emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let emailURL = "mailto:olivedesignstudios@gmail.com?subject=Clnbrd%20Support&body=\(encodedBody)"
        
        if let url = URL(string: emailURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    func isLaunchAtLoginEnabled() -> Bool {
        return false
    }
}

extension SettingsWindow: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        
        let index = textField.tag % 1000
        
        if index < cleaningRules.customRules.count {
            if textField.tag < 1000 {
                cleaningRules.customRules[index].find = textField.stringValue
            } else {
                cleaningRules.customRules[index].replace = textField.stringValue
            }
        }
    }
}
