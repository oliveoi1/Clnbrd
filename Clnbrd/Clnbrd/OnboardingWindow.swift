import Cocoa
import os.log

/// Modern onboarding window with liquid glass styling
class OnboardingWindow: NSPanel {
    private let logger = Logger(subsystem: "com.allanalomes.Clnbrd", category: "OnboardingWindow")
    
    // UI Components
    private var contentContainer: NSView!
    private var currentScreen: OnboardingScreen = .welcome
    private var canDismiss: Bool
    
    // Page views
    private var welcomeView: NSView!
    private var permissionsView: NSView!
    private var quickStartView: NSView!
    
    // Permission monitoring
    private var permissionCheckTimer: Timer?
    private var hasAutoAdvanced = false  // Prevent multiple auto-advances
    
    // Constants
    private let windowWidth: CGFloat = 600
    private let windowHeight: CGFloat = 450
    
    init(canDismiss: Bool = true) {
        self.canDismiss = canDismiss
        
        let windowFrame = NSRect(
            x: 0,
            y: 0,
            width: windowWidth,
            height: windowHeight
        )
        
        super.init(
            contentRect: windowFrame,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupUI()
        
        logger.info("OnboardingWindow initialized")
    }
    
    deinit {
        // Clean up permission check timer
        stopPermissionMonitoring()
        logger.info("OnboardingWindow deinitialized")
    }
    
    private func setupWindow() {
        self.title = "Welcome to Clnbrd"
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Important: Allow panel to become key window
        self.becomesKeyOnlyIfNeeded = false
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        
        // Add premium liquid glass background
        guard let contentView = self.contentView else { return }
        
        // LAYER 1: Deep backdrop blur
        let backdropBlur = NSVisualEffectView(frame: contentView.bounds)
        backdropBlur.autoresizingMask = [.width, .height]
        backdropBlur.material = .underWindowBackground
        backdropBlur.state = .active
        backdropBlur.blendingMode = .behindWindow
        backdropBlur.wantsLayer = true
        backdropBlur.layer?.cornerRadius = 16
        backdropBlur.layer?.masksToBounds = true
        backdropBlur.alphaValue = 0.8
        
        // LAYER 2: Main frosted material
        let visualEffect = NSVisualEffectView(frame: contentView.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .withinWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = false
        
        // Shadow
        if let backdropLayer = backdropBlur.layer {
            backdropLayer.shadowColor = NSColor.black.cgColor
            backdropLayer.shadowOpacity = 0.3
            backdropLayer.shadowOffset = NSSize(width: 0, height: 10)
            backdropLayer.shadowRadius = 30
        }
        
        contentView.addSubview(backdropBlur, positioned: .below, relativeTo: nil)
        contentView.addSubview(visualEffect, positioned: .below, relativeTo: nil)
    }
    
    private func setupUI() {
        guard let contentView = self.contentView else { return }
        
        // Main content container
        contentContainer = NSView(frame: contentView.bounds.insetBy(dx: 40, dy: 40))
        contentContainer.autoresizingMask = [.width, .height]
        contentView.addSubview(contentContainer)
        
        // Create all page views
        createWelcomeView()
        createPermissionsView()
        createQuickStartView()
        
        // Show welcome screen
        showScreen(.welcome, animated: false)
    }
    
    // MARK: - Screen 1: Welcome
    
    private func createWelcomeView() {
        welcomeView = NSView(frame: contentContainer.bounds)
        welcomeView.autoresizingMask = [.width, .height]
        
        // App icon (shifted left) - with liquid glass enhancement
        let iconView = NSImageView(frame: NSRect(x: (windowWidth - 120) / 2 - 20, y: 240, width: 120, height: 120))
        if let appIcon = NSImage(named: "AppIcon") {
            iconView.image = appIcon
            iconView.imageScaling = .scaleProportionallyUpOrDown
            // Add floating shadow for depth
            iconView.addFloatingShadow(offset: NSSize(width: 0, height: 8), radius: 16, opacity: 0.25)
        } else {
            // Fallback to hero symbol with hierarchical rendering
            iconView.image = NSImage.heroSymbol("doc.on.clipboard.fill", color: .controlAccentColor)
            iconView.imageScaling = .scaleProportionallyUpOrDown
            iconView.applyLiquidGlassStyle(addShadow: true, addGlow: true, glowColor: .controlAccentColor)
        }
        welcomeView.addSubview(iconView)
        
        // Title (shifted left)
        let titleLabel = NSTextField(labelWithString: "Welcome to Clnbrd")
        titleLabel.font = NSFont.systemFont(ofSize: 28, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 60, y: 190, width: windowWidth - 160, height: 36)
        welcomeView.addSubview(titleLabel)
        
        // Subtitle (shifted left, new tagline, taller for wrapping)
        let subtitleLabel = NSTextField(wrappingLabelWithString: "Copy anything. Paste clean on demand. No AI junk. No mess.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 80, y: 145, width: windowWidth - 200, height: 40)
        subtitleLabel.maximumNumberOfLines = 2
        welcomeView.addSubview(subtitleLabel)
        
        // Get Started button (shifted left)
        let getStartedButton = NSButton(frame: NSRect(x: (windowWidth - 160) / 2 - 20, y: 80, width: 160, height: 40))
        getStartedButton.title = "Get Started"
        getStartedButton.bezelStyle = .rounded
        getStartedButton.keyEquivalent = "\r"
        getStartedButton.target = self
        getStartedButton.action = #selector(getStartedClicked)
        welcomeView.addSubview(getStartedButton)
        
        // Skip link (shifted left)
        if canDismiss {
            let skipButton = NSButton(frame: NSRect(x: (windowWidth - 100) / 2 - 20, y: 45, width: 100, height: 24))
            skipButton.title = "Skip Setup"
            skipButton.bezelStyle = .inline
            skipButton.target = self
            skipButton.action = #selector(skipClicked)
            welcomeView.addSubview(skipButton)
        }
    }
    
    // MARK: - Screen 2: Permissions
    
    private func createPermissionsView() {
        permissionsView = NSView(frame: contentContainer.bounds)
        permissionsView.autoresizingMask = [.width, .height]
        
        // Icon - centered (shifted left) with hierarchical rendering
        let iconSize: CGFloat = 80
        let iconView = NSImageView(frame: NSRect(x: (windowWidth - iconSize) / 2 - 20, y: 280, width: iconSize, height: iconSize))
        iconView.image = NSImage.symbol("lock.shield.fill", size: 64, weight: .semibold, scale: .large, color: .controlAccentColor)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.applyLiquidGlassStyle(addShadow: true, addGlow: true, glowColor: .controlAccentColor.withAlphaComponent(0.4))
        permissionsView.addSubview(iconView)
        
        // Title - centered (shifted left)
        let titleLabel = NSTextField(labelWithString: "Required Permissions")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 60, y: 240, width: windowWidth - 160, height: 32)
        permissionsView.addSubview(titleLabel)
        
        // Description - centered (shifted left)
        let descLabel = NSTextField(wrappingLabelWithString: "Clnbrd needs these permissions to work. Click the buttons below to enable them.")
        descLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        descLabel.frame = NSRect(x: 60, y: 200, width: windowWidth - 160, height: 36)
        descLabel.maximumNumberOfLines = 2
        permissionsView.addSubview(descLabel)
        
        // Permission cards container - centered (shifted left)
        let cardsWidth: CGFloat = 460
        let cardsHeight: CGFloat = 110
        let cardsContainer = NSView(frame: NSRect(x: (windowWidth - cardsWidth) / 2 - 20, y: 85, width: cardsWidth, height: cardsHeight))
        
        // Accessibility card
        let accessibilityCard = createPermissionCardWithButton(
            title: "1️⃣ Accessibility",
            description: "Monitor clipboard changes",
            yPosition: 55,
            identifier: "accessibility",
            action: #selector(openAccessibilitySettings)
        )
        cardsContainer.addSubview(accessibilityCard)
        
        // Input Monitoring card
        let inputCard = createPermissionCardWithButton(
            title: "2️⃣ Input Monitoring",
            description: "Capture keyboard shortcuts",
            yPosition: 0,
            identifier: "inputMonitoring",
            action: #selector(openInputMonitoringSettings)
        )
        cardsContainer.addSubview(inputCard)
        
        permissionsView.addSubview(cardsContainer)
        
        // Bottom buttons - centered layout (shifted left)
        let buttonY: CGFloat = 28
        let buttonSpacing: CGFloat = 16
        let backButtonWidth: CGFloat = 100
        let continueButtonWidth: CGFloat = 100
        let totalButtonWidth = backButtonWidth + buttonSpacing + continueButtonWidth
        let buttonsStartX = (windowWidth - totalButtonWidth) / 2 - 20
        
        // Back button (left of center)
        let backButton = NSButton(frame: NSRect(x: buttonsStartX, y: buttonY, width: backButtonWidth, height: 36))
        backButton.title = "← Back"
        backButton.bezelStyle = .rounded
        backButton.target = self
        backButton.action = #selector(backToWelcome)
        permissionsView.addSubview(backButton)
        
        // Continue button (right of center, enabled when both permissions granted)
        let continueButton = NSButton(frame: NSRect(x: buttonsStartX + backButtonWidth + buttonSpacing, y: buttonY, width: continueButtonWidth, height: 36))
        continueButton.title = "Continue"
        continueButton.bezelStyle = .rounded
        continueButton.keyEquivalent = ""
        continueButton.target = self
        continueButton.action = #selector(continueToQuickStart)
        continueButton.identifier = NSUserInterfaceItemIdentifier("continueButton")
        continueButton.isEnabled = false
        permissionsView.addSubview(continueButton)
        
        // Privacy note
        let privacyLabel = NSTextField(labelWithString: "Your data stays private and secure on your Mac")
        privacyLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        privacyLabel.textColor = .tertiaryLabelColor
        privacyLabel.alignment = .center
        privacyLabel.frame = NSRect(x: 40, y: 15, width: windowWidth - 120, height: 16)
        permissionsView.addSubview(privacyLabel)
        
        // Success message (hidden by default, shown when both granted)
        let successLabel = NSTextField(labelWithString: "✅ All permissions granted! Moving to next step...")
        successLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        successLabel.textColor = .systemGreen
        successLabel.alignment = .center
        successLabel.frame = NSRect(x: 40, y: 60, width: windowWidth - 120, height: 20)
        successLabel.identifier = NSUserInterfaceItemIdentifier("successMessage")
        successLabel.isHidden = true
        permissionsView.addSubview(successLabel)
    }
    
    private func createPermissionCardWithButton(title: String, description: String, yPosition: CGFloat, identifier: String, action: Selector) -> NSView {
        let cardWidth: CGFloat = 460
        let cardHeight: CGFloat = 48
        let card = NSView(frame: NSRect(x: 0, y: yPosition, width: cardWidth, height: cardHeight))
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        card.layer?.cornerRadius = 8
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 16, y: 20, width: 180, height: 18)
        titleLabel.drawsBackground = false
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        card.addSubview(titleLabel)
        
        // Description
        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        descLabel.textColor = .secondaryLabelColor
        descLabel.frame = NSRect(x: 16, y: 6, width: 180, height: 14)
        descLabel.drawsBackground = false
        descLabel.isBordered = false
        descLabel.isEditable = false
        card.addSubview(descLabel)
        
        // Status indicator with hierarchical rendering
        let statusView = NSImageView(frame: NSRect(x: 210, y: 14, width: 20, height: 20))
        statusView.identifier = NSUserInterfaceItemIdentifier("\(identifier)Status")
        statusView.image = NSImage.symbol("circle", size: 16, weight: .medium, scale: .medium, color: .secondaryLabelColor)
        statusView.imageScaling = .scaleProportionallyUpOrDown
        card.addSubview(statusView)
        
        // "Open Settings" button
        let openButton = NSButton(frame: NSRect(x: cardWidth - 140, y: 8, width: 128, height: 32))
        openButton.title = "Open Settings"
        openButton.bezelStyle = .rounded
        openButton.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        openButton.target = self
        openButton.action = action
        card.addSubview(openButton)
        
        return card
    }
    
    // MARK: - Screen 3: Quick Start
    
    private func createQuickStartView() {
        quickStartView = NSView(frame: contentContainer.bounds)
        quickStartView.autoresizingMask = [.width, .height]
        
        // Success icon with multicolor rendering and glow
        let iconView = NSImageView(frame: NSRect(x: (windowWidth - 80) / 2 - 40, y: 280, width: 80, height: 80))
        iconView.image = NSImage.symbolMulticolor("checkmark.circle.fill", size: 64, weight: .semibold, scale: .large)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.applyLiquidGlassStyle(addShadow: true, addGlow: true, glowColor: .systemGreen.withAlphaComponent(0.5))
        quickStartView.addSubview(iconView)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "You're All Set!")
        titleLabel.font = NSFont.systemFont(ofSize: 28, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 40, y: 235, width: windowWidth - 120, height: 36)
        quickStartView.addSubview(titleLabel)
        
        // Hotkey instruction
        let hotkeyLabel = NSTextField(labelWithString: "Press this anytime to open your clipboard history:")
        hotkeyLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        hotkeyLabel.textColor = .secondaryLabelColor
        hotkeyLabel.alignment = .center
        hotkeyLabel.frame = NSRect(x: 40, y: 200, width: windowWidth - 120, height: 20)
        quickStartView.addSubview(hotkeyLabel)
        
        // Hotkey visual
        let hotkeyContainer = NSView(frame: NSRect(x: (windowWidth - 240) / 2 - 40, y: 130, width: 240, height: 60))
        hotkeyContainer.wantsLayer = true
        hotkeyContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.8).cgColor
        hotkeyContainer.layer?.cornerRadius = 12
        hotkeyContainer.layer?.borderWidth = 2
        hotkeyContainer.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
        
        let hotkeyText = NSTextField(labelWithString: "⌘ ⇧ V")
        hotkeyText.font = NSFont.systemFont(ofSize: 32, weight: .medium)
        hotkeyText.textColor = .labelColor
        hotkeyText.alignment = .center
        hotkeyText.frame = NSRect(x: 0, y: 10, width: 240, height: 40)
        hotkeyContainer.addSubview(hotkeyText)
        quickStartView.addSubview(hotkeyContainer)
        
        // Menu bar note
        let menuBarLabel = NSTextField(labelWithString: "Find settings in the menu bar")
        menuBarLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        menuBarLabel.textColor = .tertiaryLabelColor
        menuBarLabel.alignment = .center
        menuBarLabel.frame = NSRect(x: 40, y: 105, width: windowWidth - 120, height: 18)
        quickStartView.addSubview(menuBarLabel)
        
        // Back button
        let backButton = NSButton(frame: NSRect(x: 40, y: 55, width: 100, height: 36))
        backButton.title = "← Back"
        backButton.bezelStyle = .rounded
        backButton.target = self
        backButton.action = #selector(backToPermissions)
        quickStartView.addSubview(backButton)
        
        // Try It Now button
        let tryButton = NSButton(frame: NSRect(x: (windowWidth - 280) / 2 - 40, y: 55, width: 135, height: 36))
        tryButton.title = "Try It Now"
        tryButton.bezelStyle = .rounded
        tryButton.target = self
        tryButton.action = #selector(tryItNowClicked)
        quickStartView.addSubview(tryButton)
        
        // Done button
        let doneButton = NSButton(frame: NSRect(x: (windowWidth - 280) / 2 + 105, y: 55, width: 135, height: 36))
        doneButton.title = "Done"
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\r"
        doneButton.target = self
        doneButton.action = #selector(doneClicked)
        quickStartView.addSubview(doneButton)
    }
    
    // MARK: - Screen Navigation
    
    private func showScreen(_ screen: OnboardingScreen, animated: Bool = true) {
        currentScreen = screen
        
        // Reset auto-advance flag when navigating to permissions
        if screen == .permissions {
            hasAutoAdvanced = false
        }
        
        // Remove current view
        for subview in contentContainer.subviews {
            if animated {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    subview.animator().alphaValue = 0
                }, completionHandler: {
                    subview.removeFromSuperview()
                })
            } else {
                subview.removeFromSuperview()
            }
        }
        
        // Add new view
        let newView: NSView
        switch screen {
        case .welcome:
            newView = welcomeView
        case .permissions:
            newView = permissionsView
            startPermissionMonitoring()
        case .quickStart:
            newView = quickStartView
            stopPermissionMonitoring()
        }
        
        if animated {
            newView.alphaValue = 0
            contentContainer.addSubview(newView)
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                newView.animator().alphaValue = 1
            })
        } else {
            contentContainer.addSubview(newView)
        }
        
        logger.info("Showing screen: \(screen.rawValue)")
    }
    
    // MARK: - Permission Monitoring
    
    private func startPermissionMonitoring() {
        updatePermissionStatus()
        
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updatePermissionStatus()
        }
    }
    
    private func stopPermissionMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
    
    private func updatePermissionStatus() {
        let hasAccessibility = OnboardingManager.shared.hasGrantedAccessibility
        let hasInputMonitoring = OnboardingManager.shared.hasGrantedInputMonitoring
        
        logger.info("Permission check - Accessibility: \(hasAccessibility), Input Monitoring: \(hasInputMonitoring)")
        
        // Update accessibility status with multicolor symbols
        if let statusView = permissionsView.viewWithTag(1) as? NSImageView {
            if hasAccessibility {
                statusView.image = NSImage.symbolMulticolor("checkmark.circle.fill", size: 16, weight: .semibold, scale: .medium)
            } else {
                statusView.image = NSImage.symbol("circle", size: 16, weight: .medium, scale: .medium, color: .secondaryLabelColor)
            }
        } else if let statusView = findViewByIdentifier("accessibilityStatus", in: permissionsView) as? NSImageView {
            if hasAccessibility {
                statusView.image = NSImage.symbolMulticolor("checkmark.circle.fill", size: 16, weight: .semibold, scale: .medium)
            } else {
                statusView.image = NSImage.symbol("circle", size: 16, weight: .medium, scale: .medium, color: .secondaryLabelColor)
            }
        }
        
        // Update input monitoring status with multicolor symbols
        if let statusView = findViewByIdentifier("inputMonitoringStatus", in: permissionsView) as? NSImageView {
            if hasInputMonitoring {
                statusView.image = NSImage.symbolMulticolor("checkmark.circle.fill", size: 16, weight: .semibold, scale: .medium)
            } else {
                statusView.image = NSImage.symbol("circle", size: 16, weight: .medium, scale: .medium, color: .secondaryLabelColor)
            }
        }
        
        // Enable/disable Continue button
        if let continueButton = findViewByIdentifier("continueButton", in: permissionsView) as? NSButton {
            let bothGranted = hasAccessibility && hasInputMonitoring
            continueButton.isEnabled = bothGranted
            if bothGranted {
                continueButton.keyEquivalent = "\r"
            } else {
                continueButton.keyEquivalent = ""
            }
        }
        
        // Auto-advance if both granted (only once, with longer delay)
        if hasAccessibility && hasInputMonitoring && currentScreen == .permissions && !hasAutoAdvanced {
            logger.info("✅ Both permissions granted, will auto-advance in 3 seconds")
            hasAutoAdvanced = true
            
            // Show success message
            if let successLabel = findViewByIdentifier("successMessage", in: permissionsView) {
                successLabel.isHidden = false
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    successLabel.animator().alphaValue = 1.0
                })
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                if self.currentScreen == .permissions {
                    logger.info("Auto-advancing to Quick Start")
                    self.showScreen(.quickStart, animated: true)
                }
            }
        }
    }
    
    private func findViewByIdentifier(_ identifier: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == identifier {
            return view
        }
        for subview in view.subviews {
            if let found = findViewByIdentifier(identifier, in: subview) {
                return found
            }
        }
        return nil
    }
    
    // MARK: - Actions
    
    @objc private func getStartedClicked() {
        showScreen(.permissions, animated: true)
    }
    
    @objc private func backToWelcome() {
        showScreen(.welcome, animated: true)
    }
    
    @objc private func backToPermissions() {
        showScreen(.permissions, animated: true)
    }
    
    @objc private func continueToQuickStart() {
        logger.info("Continue button clicked, moving to Quick Start")
        showScreen(.quickStart, animated: true)
    }
    
    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        logger.info("Opened Accessibility Settings")
        AnalyticsManager.shared.trackFeatureUsage("onboarding_opened_accessibility_settings")
    }
    
    @objc private func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        logger.info("Opened Input Monitoring Settings")
        AnalyticsManager.shared.trackFeatureUsage("onboarding_opened_input_monitoring_settings")
    }
    
    @objc private func tryItNowClicked() {
        // Test the hotkey by opening history window
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.menuBarManager.showClipboardHistory()
        }
        
        logger.info("Try It Now clicked")
        AnalyticsManager.shared.trackFeatureUsage("onboarding_tried_hotkey")
    }
    
    @objc private func doneClicked() {
        OnboardingManager.shared.completeOnboarding()
        close()
    }
    
    @objc private func skipClicked() {
        logger.info("Onboarding skipped")
        AnalyticsManager.shared.trackFeatureUsage("onboarding_skipped")
        close()
    }
    
    // MARK: - Cleanup
    
    override func close() {
        stopPermissionMonitoring()
        super.close()
    }
}

// MARK: - Onboarding Screens Enum

private enum OnboardingScreen: String {
    case welcome
    case permissions
    case quickStart
}
