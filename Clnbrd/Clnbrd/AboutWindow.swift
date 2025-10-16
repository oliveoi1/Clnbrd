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
    
    // swiftlint:disable:next function_body_length
    private func setupUI() {
        guard let window = window else { return }
        
        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView
        
        // Add modern vibrancy to window background
        let backgroundView = NSVisualEffectView(frame: contentView.bounds)
        backgroundView.autoresizingMask = [.width, .height]
        backgroundView.material = .underWindowBackground  // Apple's standard for settings/about windows
        backgroundView.state = .followsWindowActiveState
        backgroundView.blendingMode = .behindWindow
        contentView.addSubview(backgroundView, positioned: .below, relativeTo: nil)
        
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
        
        // App Icon with premium liquid glass shadow and subtle glow
        let iconView = NSImageView()
        iconView.image = NSImage(named: NSImage.applicationIconName)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.addFloatingShadow(offset: NSSize(width: 0, height: 6), radius: 16, opacity: 0.25)
        iconView.addGlowEffect(color: .controlAccentColor.withAlphaComponent(0.3), radius: 12, opacity: 0.2)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 128),
            iconView.heightAnchor.constraint(equalToConstant: 128)
        ])
        centeredStack.addArrangedSubview(iconView)
        
        // App Name with SF Pro Rounded
        let appNameLabel = NSTextField(labelWithString: "Clnbrd")
        if let roundedFont = NSFont.systemFont(ofSize: 28, weight: .bold).rounded() {
            appNameLabel.font = roundedFont  // Modern rounded font for app name
        } else {
            appNameLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        }
        appNameLabel.alignment = .center
        centeredStack.addArrangedSubview(appNameLabel)
        
        // Version
        let versionLabel = NSTextField(labelWithString: VersionManager.fullVersion)
        versionLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        centeredStack.addArrangedSubview(versionLabel)
        
        mainStack.addArrangedSubview(centeredStack)
        
        // Update buttons stack
        let updateButtonsStack = NSStackView()
        updateButtonsStack.orientation = .vertical
        updateButtonsStack.spacing = 8
        updateButtonsStack.alignment = .centerX
        
        // Check for Updates Button
        let updateButton = NSButton(title: "Check for Updates", target: self, action: #selector(checkForUpdates))
        updateButton.bezelStyle = .automatic  // Modern, adaptive style
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            updateButton.widthAnchor.constraint(equalToConstant: 200)
        ])
        updateButtonsStack.addArrangedSubview(updateButton)
        
        // Revert to Stable button (only show if on beta)
        logger.info("Current version: \(VersionManager.version)")
        if VersionManager.version.contains("beta") {
            logger.info("Beta detected - showing Revert to Stable button")
            let revertButton = NSButton(title: "Revert to Stable Release", target: self, action: #selector(revertToStable))
            revertButton.bezelStyle = .automatic  // Modern, adaptive style
            revertButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                revertButton.widthAnchor.constraint(equalToConstant: 200)
            ])
            updateButtonsStack.addArrangedSubview(revertButton)
        } else {
            logger.info("Not a beta version - Revert button hidden")
        }
        
        mainStack.addArrangedSubview(updateButtonsStack)
        
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
        
        // Copyright label - matches description text styling
        let copyrightLabel = NSTextField(labelWithString: "© 2025 Olive Design Studios. All Rights Reserved.")
        copyrightLabel.font = NSFont.systemFont(ofSize: 11)
        copyrightLabel.textColor = .secondaryLabelColor
        copyrightLabel.alignment = .center
        mainStack.addArrangedSubview(copyrightLabel)
        
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
        separator.fillColor = .separatorColor  // Ensures proper color in dark mode
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
        whatsNewButton.bezelStyle = .automatic  // Modern, adaptive style
        
        let websiteButton = NSButton(title: "Visit our Website", target: self, action: #selector(openWebsite))
        websiteButton.bezelStyle = .automatic  // Modern, adaptive style
        
        let contactButton = NSButton(title: "Contact Us", target: self, action: #selector(contactUs))
        contactButton.bezelStyle = .automatic  // Modern, adaptive style
        
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
        } else {
            // Fallback using Objective-C runtime (needed when SwiftUI wraps the delegate)
            if let delegate = NSApp.delegate {
                let selector = #selector(AppDelegate.checkForUpdatesRequested)
                if delegate.responds(to: selector) {
                    delegate.perform(selector)
                }
            }
        }
    }
    
    @objc private func revertToStable() {
        logger.info("Revert to Stable clicked from About window")
        SentryManager.shared.trackUserAction("about_revert_to_stable")
        
        let alert = NSAlert()
        alert.messageText = "Revert to Stable Release?"
        alert.informativeText = """
        This will download the latest stable version of Clnbrd (v1.3, Build 52).
        
        The app will quit, and you'll need to manually open the downloaded file to install it.
        
        You can switch back to the beta at any time by checking for updates again.
        
        Would you like to continue?
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download Stable")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            logger.info("User confirmed revert to stable - downloading Build 52")
            
            // Direct download URL for the stable release ZIP (Build 52)
            let stableDownloadURL = "https://github.com/oliveoi1/Clnbrd/releases/download/v1.3.52/Clnbrd-v1.3-Build52-notarized-stapled.zip"
            
            guard let url = URL(string: stableDownloadURL) else {
                logger.error("Invalid stable download URL")
                return
            }
            
            // Show download instructions
            let downloadAlert = NSAlert()
            downloadAlert.messageText = "Downloading Stable Release..."
            downloadAlert.informativeText = """
            The stable version (v1.3, Build 52) will now download.
            
            Once downloaded:
            1. Quit Clnbrd
            2. Unzip the downloaded file
            3. Drag Clnbrd.app to your Applications folder (replace existing)
            4. Launch Clnbrd from Applications
            
            The download will open in your browser.
            """
            downloadAlert.alertStyle = .informational
            downloadAlert.addButton(withTitle: "Download Now")
            downloadAlert.addButton(withTitle: "Cancel")
            
            if downloadAlert.runModal() == .alertFirstButtonReturn {
                // Open the download URL in the default browser
                NSWorkspace.shared.open(url)
                logger.info("Opened stable release download URL")
                
                // Offer to quit the app
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let quitAlert = NSAlert()
                    quitAlert.messageText = "Quit Clnbrd Now?"
                    quitAlert.informativeText = "Would you like to quit Clnbrd now so you can install the stable version?"
                    quitAlert.alertStyle = .informational
                    quitAlert.addButton(withTitle: "Quit Now")
                    quitAlert.addButton(withTitle: "Continue Running")
                    
                    if quitAlert.runModal() == .alertFirstButtonReturn {
                        logger.info("User chose to quit - exiting application")
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
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
        alert.messageText = "New in Clnbrd X"
        alert.informativeText = """
        \(VersionManager.fullVersion)
        
        — Automatic "Move to Applications" prompt
        — Simplified menu bar interface
        — Tabbed Settings window (Rules and About)
        — Improved user experience with streamlined settings
        — Better window resizing and layout
        
        \(VersionManager.version) (Build 50)
        
        — Fully notarized for macOS Sequoia
        — Fixed notarization issues with clean-room build process
        — No security warnings on macOS 15.0+
        — Enhanced auto-update system
        
        For full changelog, visit our website.
        """
        alert.alertStyle = .informational
        
        // Add checkbox for "Show changelog after each update"
        let checkbox = NSButton(checkboxWithTitle: "Show the changelog after each update", target: nil, action: nil)
        checkbox.state = UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks") ? .on : .off
        alert.accessoryView = checkbox
        
        alert.addButton(withTitle: "Close")
        
        _ = alert.runModal()
        
        // Save checkbox state
        let showChangelog = checkbox.state == .on
        UserDefaults.standard.set(showChangelog, forKey: "ShowChangelogAfterUpdate")
    }
    
    @objc private func openWebsite() {
        logger.info("Visit Website clicked")
        SentryManager.shared.trackUserAction("about_visit_website")
        
        if let url = URL(string: "https://olvbrd.com") {
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
