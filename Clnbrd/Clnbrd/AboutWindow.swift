//
//  AboutWindow.swift
//  Clnbrd
//
//  About window with version info, updates, and settings
//

import Cocoa
import os.log

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "about")

class AboutWindow: NSWindowController {
    
    // MARK: - Properties
    private var autoUpdateCheckbox: NSButton!
    private var analyticsCheckbox: NSButton!
    
    // MARK: - Initialization
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "About Clnbrd"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        
        self.init(window: window)
        setupUI()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        guard let window = window else { return }
        
        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView
        
        // Main stack view
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 20
        mainStack.alignment = .centerX
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)
        
        // Container for centered content
        let centeredStack = NSStackView()
        centeredStack.orientation = .vertical
        centeredStack.spacing = 16
        centeredStack.alignment = .centerX
        
        // App Icon
        let iconView = NSImageView()
        iconView.image = NSImage(named: NSImage.applicationIconName)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 128),
            iconView.heightAnchor.constraint(equalToConstant: 128)
        ])
        centeredStack.addArrangedSubview(iconView)
        
        // App Name
        let appNameLabel = NSTextField(labelWithString: "Clnbrd")
        appNameLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        appNameLabel.alignment = .center
        centeredStack.addArrangedSubview(appNameLabel)
        
        // Version
        let versionLabel = NSTextField(labelWithString: VersionManager.fullVersion)
        versionLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        centeredStack.addArrangedSubview(versionLabel)
        
        mainStack.addArrangedSubview(centeredStack)
        
        // Check for Updates Button
        let updateButton = NSButton(title: "Check for Updates", target: self, action: #selector(checkForUpdates))
        updateButton.bezelStyle = .rounded
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            updateButton.widthAnchor.constraint(equalToConstant: 200)
        ])
        mainStack.addArrangedSubview(updateButton)
        
        // Separator
        let separator1 = createSeparator()
        mainStack.addArrangedSubview(separator1)
        
        // Auto-update checkbox
        autoUpdateCheckbox = NSButton(checkboxWithTitle: "Automatically check for updates", target: self, action: #selector(toggleAutoUpdate))
        autoUpdateCheckbox.state = UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks") ? .on : .off
        autoUpdateCheckbox.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(autoUpdateCheckbox)
        
        // Analytics section
        let analyticsStack = createAnalyticsSection()
        mainStack.addArrangedSubview(analyticsStack)
        
        // Separator
        let separator2 = createSeparator()
        mainStack.addArrangedSubview(separator2)
        
        // Acknowledgments
        let acknowledgementsLabel = createClickableLink(
            text: "Acknowledgments",
            action: #selector(showAcknowledgments)
        )
        mainStack.addArrangedSubview(acknowledgementsLabel)
        
        // Spacer
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(spacer)
        
        // Bottom buttons
        let buttonStack = createBottomButtons()
        mainStack.addArrangedSubview(buttonStack)
        
        // Constraints for main stack
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            separator1.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            separator2.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            
            spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        ])
    }
    
    private func createSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
        return separator
    }
    
    private func createAnalyticsSection() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        // Analytics checkbox
        analyticsCheckbox = NSButton(checkboxWithTitle: "Share my usage statistics", target: self, action: #selector(toggleAnalytics))
        analyticsCheckbox.state = AnalyticsManager.shared.isAnalyticsEnabled() ? .on : .off
        stack.addArrangedSubview(analyticsCheckbox)
        
        // Description
        let description = NSTextField(wrappingLabelWithString: "Help us improve Clnbrd by allowing us to collect completely anonymous usage data.")
        description.font = NSFont.systemFont(ofSize: 11)
        description.textColor = .secondaryLabelColor
        description.preferredMaxLayoutWidth = 420
        stack.addArrangedSubview(description)
        
        return stack
    }
    
    private func createClickableLink(text: String, action: Selector) -> NSTextField {
        let textField = NSTextField(labelWithString: text)
        textField.font = NSFont.systemFont(ofSize: 12)
        textField.textColor = .linkColor
        textField.isBordered = false
        textField.isEditable = false
        textField.isSelectable = false
        textField.alignment = .center
        
        // Add click gesture
        let clickGesture = NSClickGestureRecognizer(target: self, action: action)
        textField.addGestureRecognizer(clickGesture)
        
        // Change cursor to pointing hand
        let trackingArea = NSTrackingArea(
            rect: textField.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: textField,
            userInfo: nil
        )
        textField.addTrackingArea(trackingArea)
        
        return textField
    }
    
    private func createBottomButtons() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let whatsNewButton = NSButton(title: "What's New", target: self, action: #selector(showWhatsNew))
        whatsNewButton.bezelStyle = .rounded
        
        let websiteButton = NSButton(title: "Visit our Website", target: self, action: #selector(openWebsite))
        websiteButton.bezelStyle = .rounded
        
        let contactButton = NSButton(title: "Contact Us", target: self, action: #selector(contactUs))
        contactButton.bezelStyle = .rounded
        
        stack.addArrangedSubview(whatsNewButton)
        stack.addArrangedSubview(websiteButton)
        stack.addArrangedSubview(contactButton)
        
        return stack
    }
    
    // MARK: - Actions
    
    @objc private func checkForUpdates() {
        logger.info("Check for updates clicked from About window")
        SentryManager.shared.trackUserAction("about_check_updates")
        
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.checkForUpdatesRequested()
        }
    }
    
    @objc private func toggleAutoUpdate(_ sender: NSButton) {
        let enabled = sender.state == .on
        UserDefaults.standard.set(enabled, forKey: "SUEnableAutomaticChecks")
        logger.info("Auto-update toggled: \(enabled)")
        SentryManager.shared.trackUserAction("about_toggle_auto_update", data: ["enabled": enabled])
    }
    
    @objc private func toggleAnalytics(_ sender: NSButton) {
        let enabled = sender.state == .on
        AnalyticsManager.shared.setAnalyticsEnabled(enabled)
        logger.info("Analytics toggled: \(enabled)")
        SentryManager.shared.trackUserAction("about_toggle_analytics", data: ["enabled": enabled])
    }
    
    @objc private func showAcknowledgments() {
        logger.info("Acknowledgments clicked")
        SentryManager.shared.trackUserAction("about_acknowledgments")
        
        let alert = NSAlert()
        alert.messageText = "Acknowledgments"
        alert.informativeText = """
        Clnbrd uses the following open-source libraries:
        
        • Sparkle - Software update framework
          by Andy Matuschak and contributors
          
        • Sentry - Crash reporting and monitoring
          by Sentry Team
          
        • LetsMove - Application mover
          by Potion Factory
        
        Thank you to all contributors and the open-source community!
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func showWhatsNew() {
        logger.info("What's New clicked")
        SentryManager.shared.trackUserAction("about_whats_new")
        
        let alert = NSAlert()
        alert.messageText = "What's New in Clnbrd \(VersionManager.version)"
        alert.informativeText = """
        New in Build 51:
        
        ✨ Automatic "Move to Applications" prompt
           • App automatically offers to move to Applications folder
           • Ensures Launch at Login and updates work reliably
        
        🎨 Simplified menu bar interface
           • Cleaner, more focused menu
           • Better organized actions
        
        🔧 Improved user experience
           • Fewer prompts and dialogs
           • Streamlined settings
        
        For full changelog, visit our GitHub releases page.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "View on GitHub")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/oliveoi1/Clnbrd/releases") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc private func openWebsite() {
        logger.info("Visit Website clicked")
        SentryManager.shared.trackUserAction("about_visit_website")
        
        if let url = URL(string: "http://olvbrd.x10.network/wp/") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func contactUs() {
        logger.info("Contact Us clicked")
        SentryManager.shared.trackUserAction("about_contact_us")
        
        // Create mailto link
        let email = "olivedesignstudios@gmail.com"
        let subject = "Clnbrd Feedback - v\(VersionManager.version)"
        let body = """
        
        
        ---
        App Version: \(VersionManager.version)
        Build: \(VersionManager.buildNumber)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }
    }
}

