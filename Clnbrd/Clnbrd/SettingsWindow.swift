import Cocoa
import os.log
import ServiceManagement
import UniformTypeIdentifiers

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "settings")

/// Settings window for configuring cleaning rules and application preferences
class SettingsWindow: NSWindowController {
    var cleaningRules: CleaningRules
    var checkboxes: [NSButton] = []
    var customRulesStackView: NSStackView!
    var profileDropdown: NSPopUpButton!
    var currentProfileId: UUID?
    var scrollView: NSScrollView!
    
    init(cleaningRules: CleaningRules) {
        // Load active profile
        let activeProfile = ProfileManager.shared.getActiveProfile()
        self.cleaningRules = activeProfile.rules
        self.currentProfileId = activeProfile.id
        
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
        window.maxSize = NSSize(width: 800, height: 1200)  // Allow vertical resizing
        
        super.init(window: window)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        
        // Set up window delegate to catch window becoming key
        window?.delegate = self
        
        scrollToTop()
    }
    
    /// Show the window with a specific tab selected
    func showWindow(withTab tabIdentifier: String) {
        guard let window = window,
              let tabView = window.contentView as? NSTabView else { return }
        
        // Find and select the tab
        for item in tabView.tabViewItems {
            if item.identifier as? String == tabIdentifier {
                tabView.selectTabViewItem(item)
                break
            }
        }
        
        showWindow(nil)
    }
    
    private func scrollToTop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self, let scrollView = self.scrollView else { return }
            guard let documentView = scrollView.documentView else { return }
            
            // Calculate the Y position for the TOP of the content
            // In flipped coordinates: Y = documentHeight - visibleHeight
            let documentHeight = documentView.frame.height
            let visibleHeight = scrollView.contentView.bounds.height
            let topY = max(0, documentHeight - visibleHeight)
            
            // Set bounds to show the top
            let topPoint = NSPoint(x: 0, y: topY)
            scrollView.contentView.setBoundsOrigin(topPoint)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
    
    func setupUI() {
        guard let window = window else { return }
        
        // Create tab view
        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.delegate = self
        
        // Tab 1: Rules (Cleaning Rules)
        let rulesTab = NSTabViewItem(identifier: "rules")
        rulesTab.label = "Rules"
        rulesTab.view = createGeneralTab()
        tabView.addTabViewItem(rulesTab)
        
        // Tab 2: About
        let aboutTab = NSTabViewItem(identifier: "about")
        aboutTab.label = "About"
        aboutTab.view = createAboutTab()
        tabView.addTabViewItem(aboutTab)
        
        // Add tab view to window
        window.contentView = tabView
        
        // Set initial window title
        window.title = "Rules"
    }
    
    private func createGeneralTab() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        // Setup all UI sections
        setupProfileSection(stackView)
        setupBasicTextCleaningSection(stackView)
        setupAdvancedCleaningSection(stackView)
        
        // CUSTOM FIND & REPLACE RULES SECTION
        stackView.addArrangedSubview(createSpacer(height: 20))
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
        container.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        
        return container
    }
    
    private func createAboutTab() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 12
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.edgeInsets = NSEdgeInsets(top: 20, left: 30, bottom: 15, right: 30)
        
        // Top section: Icon + App Info (side by side)
        let topStack = NSStackView()
        topStack.orientation = .horizontal
        topStack.spacing = 16
        topStack.alignment = .top
        
        // App Icon (bigger)
        let iconView = NSImageView()
        iconView.image = NSImage(named: NSImage.applicationIconName)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 110),
            iconView.heightAnchor.constraint(equalToConstant: 110)
        ])
        topStack.addArrangedSubview(iconView)
        
        // Right side: Name, version, button
        let rightStack = NSStackView()
        rightStack.orientation = .vertical
        rightStack.spacing = 4
        rightStack.alignment = .leading
        
        // App Name
        let appNameLabel = NSTextField(labelWithString: "Clnbrd")
        appNameLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        appNameLabel.alignment = .left
        rightStack.addArrangedSubview(appNameLabel)
        
        // Version
        let versionLabel = NSTextField(labelWithString: VersionManager.fullVersion)
        versionLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        versionLabel.textColor = .labelColor
        versionLabel.alignment = .left
        rightStack.addArrangedSubview(versionLabel)
        
        rightStack.addArrangedSubview(createSpacer(height: 8))
        
        // Check for Updates Button
        let updateButton = NSButton(title: "Check for Updates", target: self, action: #selector(checkForUpdates))
        updateButton.bezelStyle = .rounded
        rightStack.addArrangedSubview(updateButton)
        
        topStack.addArrangedSubview(rightStack)
        
        mainStack.addArrangedSubview(topStack)
        
        mainStack.addArrangedSubview(createSpacer(height: 4))
        
        // Auto-update checkbox (left-aligned)
        let autoUpdateCheckbox = NSButton(checkboxWithTitle: "Automatically check for updates", target: self, action: #selector(toggleAutoUpdate))
        autoUpdateCheckbox.state = UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks") ? .on : .off
        autoUpdateCheckbox.alignment = .left
        mainStack.addArrangedSubview(autoUpdateCheckbox)
        
        // Copyright (very light grey)
        let copyrightLabel = NSTextField(labelWithString: "© Olive Design Studios 2020 All Rights Reserved.")
        copyrightLabel.font = NSFont.systemFont(ofSize: 10)
        copyrightLabel.textColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.6)
        copyrightLabel.alignment = .left
        mainStack.addArrangedSubview(copyrightLabel)
        
        // Separator
        mainStack.addArrangedSubview(createSpacer(height: 12))
        let separator1 = createFullWidthSeparator()
        mainStack.addArrangedSubview(separator1)
        mainStack.addArrangedSubview(createSpacer(height: 12))
        
        // Analytics section
        let analyticsCheckbox = NSButton(checkboxWithTitle: "Share my usage statistics", target: self, action: #selector(toggleAnalyticsInSettings))
        analyticsCheckbox.state = AnalyticsManager.shared.isAnalyticsEnabled() ? .on : .off
        mainStack.addArrangedSubview(analyticsCheckbox)
        
        let analyticsDescription = NSTextField(wrappingLabelWithString: "Help us improve Clnbrd by allowing us to collect completely anonymous usage data.")
        analyticsDescription.font = NSFont.systemFont(ofSize: 11)
        analyticsDescription.textColor = .secondaryLabelColor
        analyticsDescription.preferredMaxLayoutWidth = 540
        analyticsDescription.alignment = .left
        mainStack.addArrangedSubview(analyticsDescription)
        
        // Launch at Login (removed - not needed in About tab per design)
        
        // Flexible spacer to push bottom content down
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        mainStack.addArrangedSubview(spacer)
        
        // Bottom section: Acknowledgments on left, buttons on right
        let bottomStack = NSStackView()
        bottomStack.orientation = .horizontal
        bottomStack.spacing = 12
        bottomStack.alignment = .centerY
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        
        let acknowledgementsLabel = createClickableLink(text: "Acknowledgments", action: #selector(showAcknowledgments))
        acknowledgementsLabel.alignment = .left
        bottomStack.addArrangedSubview(acknowledgementsLabel)
        
        // Spacer to push buttons to right
        let bottomSpacer = NSView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomStack.addArrangedSubview(bottomSpacer)
        
        // Right-aligned buttons
        let buttonStack = createAboutButtons()
        bottomStack.addArrangedSubview(buttonStack)
        
        mainStack.addArrangedSubview(bottomStack)
        
        container.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: container.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            separator1.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            
            bottomStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            bottomSpacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            
            // Spacer grows/shrinks with window height (minimal spacing for compact layout)
            spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 8)
        ])
        
        return container
    }
    
    private func createFullWidthSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
        return separator
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
        
        return textField
    }
    
    private func createAboutButtons() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let whatsNewButton = NSButton(title: "What's New", target: self, action: #selector(showWhatsNew))
        whatsNewButton.bezelStyle = .rounded
        
        let websiteButton = NSButton(title: "Visit Website", target: self, action: #selector(openWebsite))
        websiteButton.bezelStyle = .rounded
        
        let contactButton = NSButton(title: "Contact Us", target: self, action: #selector(contactUs))
        contactButton.bezelStyle = .rounded
        
        stack.addArrangedSubview(whatsNewButton)
        stack.addArrangedSubview(websiteButton)
        stack.addArrangedSubview(contactButton)
        
        return stack
    }
    
    // MARK: - UI Section Setup Helpers
    
    private func setupProfileSection(_ stackView: NSStackView) {
        let profileSection = createProfileManagementSection()
        stackView.addArrangedSubview(profileSection)
        stackView.addArrangedSubview(createSpacer(height: 16))
    }
    
    private func setupBasicTextCleaningSection(_ stackView: NSStackView) {
        stackView.addArrangedSubview(createSectionHeaderWithControls("📝 Basic Text Cleaning", selectAllSelector: #selector(selectAllBasic), deselectAllSelector: #selector(deselectAllBasic)))
        stackView.addArrangedSubview(createSpacer(height: 4))
        
        stackView.addArrangedSubview(createCheckbox(
            title: "Remove zero-width and invisible characters (AI watermarks)",
            tooltip: CleaningRuleTooltips.removeZeroWidthChars,
            isOn: cleaningRules.removeZeroWidthChars,
            tag: 0
        ))
        stackView.addArrangedSubview(createCheckbox(title: "Replace em-dashes (—) with comma+space", tooltip: CleaningRuleTooltips.removeEmdashes, isOn: cleaningRules.removeEmdashes, tag: 1))
        stackView.addArrangedSubview(createCheckbox(title: "Normalize multiple spaces to single space", tooltip: CleaningRuleTooltips.normalizeSpaces, isOn: cleaningRules.normalizeSpaces, tag: 2))
        stackView.addArrangedSubview(createCheckbox(title: "Convert smart quotes to straight quotes", tooltip: CleaningRuleTooltips.convertSmartQuotes, isOn: cleaningRules.convertSmartQuotes, tag: 3))
        stackView.addArrangedSubview(createCheckbox(title: "Normalize line breaks", tooltip: CleaningRuleTooltips.normalizeLineBreaks, isOn: cleaningRules.normalizeLineBreaks, tag: 4))
        stackView.addArrangedSubview(createCheckbox(title: "Remove trailing spaces from lines", tooltip: CleaningRuleTooltips.removeTrailingSpaces, isOn: cleaningRules.removeTrailingSpaces, tag: 5))
        stackView.addArrangedSubview(createCheckbox(title: "Remove emojis", tooltip: CleaningRuleTooltips.removeEmojis, isOn: cleaningRules.removeEmojis, tag: 6))
    }
    
    private func setupAdvancedCleaningSection(_ stackView: NSStackView) {
        stackView.addArrangedSubview(createSpacer(height: 12))
        stackView.addArrangedSubview(createSectionHeaderWithControls("🧹 Advanced Cleaning", selectAllSelector: #selector(selectAllAdvanced), deselectAllSelector: #selector(deselectAllAdvanced)))
        stackView.addArrangedSubview(createSpacer(height: 4))
        
        stackView.addArrangedSubview(createCheckbox(title: "Remove extra line breaks (3+ → 2)", tooltip: CleaningRuleTooltips.removeExtraLineBreaks, isOn: cleaningRules.removeExtraLineBreaks, tag: 7))
        stackView.addArrangedSubview(createCheckbox(
            title: "Remove leading/trailing whitespace",
            tooltip: CleaningRuleTooltips.removeLeadingTrailingWhitespace,
            isOn: cleaningRules.removeLeadingTrailingWhitespace,
            tag: 8
        ))
        stackView.addArrangedSubview(createCheckbox(title: "Remove URL tracking parameters", tooltip: CleaningRuleTooltips.removeUrlTracking, isOn: cleaningRules.removeUrlTracking, tag: 9))
        stackView.addArrangedSubview(createCheckbox(title: "Remove URL protocols (https://, www.)", tooltip: CleaningRuleTooltips.removeUrls, isOn: cleaningRules.removeUrls, tag: 10))
        stackView.addArrangedSubview(createCheckbox(title: "Remove HTML tags and entities", tooltip: CleaningRuleTooltips.removeHtmlTags, isOn: cleaningRules.removeHtmlTags, tag: 11))
        stackView.addArrangedSubview(createCheckbox(title: "Remove extra punctuation marks", tooltip: CleaningRuleTooltips.removeExtraPunctuation, isOn: cleaningRules.removeExtraPunctuation, tag: 12))
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
    
    func createSectionHeaderWithControls(_ title: String, selectAllSelector: Selector, deselectAllSelector: Selector) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Section title
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 14)
        label.textColor = .controlTextColor
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Select All button
        let selectAllButton = NSButton(title: "Select All", target: self, action: selectAllSelector)
        selectAllButton.bezelStyle = .rounded
        selectAllButton.font = NSFont.systemFont(ofSize: 11)
        selectAllButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Deselect All button
        let deselectAllButton = NSButton(title: "Deselect All", target: self, action: deselectAllSelector)
        deselectAllButton.bezelStyle = .rounded
        deselectAllButton.font = NSFont.systemFont(ofSize: 11)
        deselectAllButton.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(label)
        container.addSubview(selectAllButton)
        container.addSubview(deselectAllButton)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            deselectAllButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            deselectAllButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            selectAllButton.trailingAnchor.constraint(equalTo: deselectAllButton.leadingAnchor, constant: -8),
            selectAllButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        return container
    }
    
    func createProfileManagementSection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Profile label
        let profileLabel = NSTextField(labelWithString: "Profile:")
        profileLabel.font = NSFont.boldSystemFont(ofSize: 13)
        profileLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Profile dropdown with all management options
        profileDropdown = NSPopUpButton(frame: .zero, pullsDown: false)
        profileDropdown.translatesAutoresizingMaskIntoConstraints = false
        profileDropdown.target = self
        profileDropdown.action = #selector(profileChanged(_:))
        
        // Set up the profile dropdown menu with all options
        setupProfileDropdownMenu()
        
        // Add all subviews
        container.addSubview(profileLabel)
        container.addSubview(profileDropdown)
        
        // Layout
        NSLayoutConstraint.activate([
            profileLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            profileLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            profileDropdown.leadingAnchor.constraint(equalTo: profileLabel.trailingAnchor, constant: 8),
            profileDropdown.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            profileDropdown.widthAnchor.constraint(equalToConstant: 200),
            profileDropdown.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        return container
    }
    
    private func setupProfileDropdownMenu() {
        // Clear existing items
        profileDropdown.removeAllItems()
        
        // Add profile names
        let profiles = ProfileManager.shared.getAllProfiles()
        let activeProfile = ProfileManager.shared.getActiveProfile()
        currentProfileId = activeProfile.id
        
        for profile in profiles {
            profileDropdown.addItem(withTitle: profile.name)
            if let item = profileDropdown.item(withTitle: profile.name) {
                item.representedObject = profile.id
            }
        }
        
        // Add separator
        profileDropdown.menu?.addItem(NSMenuItem.separator())
        
        // Add management options
        let renameItem = NSMenuItem(title: "Rename Profile...", action: #selector(renameProfile), keyEquivalent: "")
        renameItem.target = self
        profileDropdown.menu?.addItem(renameItem)
        
        let createItem = NSMenuItem(title: "Create New Profile...", action: #selector(createNewProfile), keyEquivalent: "")
        createItem.target = self
        profileDropdown.menu?.addItem(createItem)
        
        let removeItem = NSMenuItem(title: "Remove Profile...", action: #selector(deleteCurrentProfile), keyEquivalent: "")
        removeItem.target = self
        profileDropdown.menu?.addItem(removeItem)
        
        // Add another separator
        profileDropdown.menu?.addItem(NSMenuItem.separator())
        
        // Add export/import options
        let exportItem = NSMenuItem(title: "Export Profile...", action: #selector(exportProfile), keyEquivalent: "")
        exportItem.target = self
        profileDropdown.menu?.addItem(exportItem)
        
        let shareItem = NSMenuItem(title: "Share Profile...", action: #selector(shareProfile), keyEquivalent: "")
        shareItem.target = self
        profileDropdown.menu?.addItem(shareItem)
        
        let importItem = NSMenuItem(title: "Import Profile...", action: #selector(importProfile), keyEquivalent: "")
        importItem.target = self
        profileDropdown.menu?.addItem(importItem)
        
        // Select the active profile
        if let index = profiles.firstIndex(where: { $0.id == activeProfile.id }) {
            profileDropdown.selectItem(at: index)
        }
        
        logger.info("🔧 Set up profile dropdown with \(self.profileDropdown.numberOfItems) total items")
    }
    
    func createSpacer(height: CGFloat) -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spacer.heightAnchor.constraint(equalToConstant: height)
        ])
        return spacer
    }
    
    func createSeparatorLine() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        separator.widthAnchor.constraint(equalToConstant: 540).isActive = true
        
        return separator
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
        
        // Save to current profile
        if let profileId = currentProfileId {
            ProfileManager.shared.updateProfile(id: profileId, rules: cleaningRules)
        }
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
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
            }
            
            sender.state = .off
        }
    }
    
    // MARK: - Removed Functions (Build 51 - UI Simplification)
    // showSetupInstructions: LetsMove automatically handles app installation
    // showSecurityHelp: App is now properly notarized, no security warnings
    // showAnalytics, toggleAnalytics, shareApp: Moved to About tab
    // emailDeveloper, testSystemInformation, emailSupportWithAnalytics: Unused helper functions
    
    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return UserDefaults.standard.bool(forKey: "LaunchAtLogin")
        }
    }
    
    // MARK: - About Tab Actions
    
    @objc func checkForUpdates() {
        logger.info("Check for updates clicked from Settings About tab")
        SentryManager.shared.trackUserAction("settings_check_updates")
        
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.checkForUpdatesRequested()
        }
    }
    
    @objc func toggleAutoUpdate(_ sender: NSButton) {
        let enabled = sender.state == .on
        UserDefaults.standard.set(enabled, forKey: "SUEnableAutomaticChecks")
        logger.info("Auto-update toggled: \(enabled)")
        SentryManager.shared.trackUserAction("settings_toggle_auto_update", data: ["enabled": enabled])
    }
    
    @objc func toggleAnalyticsInSettings(_ sender: NSButton) {
        let enabled = sender.state == .on
        AnalyticsManager.shared.setAnalyticsEnabled(enabled)
        logger.info("Analytics toggled: \(enabled)")
        SentryManager.shared.trackUserAction("settings_toggle_analytics", data: ["enabled": enabled])
    }
    
    @objc func showAcknowledgments() {
        logger.info("Acknowledgments clicked")
        SentryManager.shared.trackUserAction("settings_acknowledgments")
        
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
    
    @objc func showWhatsNew() {
        logger.info("What's New clicked")
        SentryManager.shared.trackUserAction("settings_whats_new")
        
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
        
        let response = alert.runModal()
        
        // Save checkbox state
        let showChangelog = checkbox.state == .on
        UserDefaults.standard.set(showChangelog, forKey: "ShowChangelogAfterUpdate")
    }
    
    @objc func openWebsite() {
        logger.info("Visit Website clicked")
        SentryManager.shared.trackUserAction("settings_visit_website")
        
        if let url = URL(string: "http://olvbrd.x10.network/wp/") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func contactUs() {
        logger.info("Contact Us clicked")
        SentryManager.shared.trackUserAction("settings_contact_us")
        
        // Create mailto link
        let email = "olivedesignstudios@gmail.com"
        let subject = "Clnbrd Feedback - v\(VersionManager.fullVersion)"
        let body = """
        
        
        ---
        App Version: \(VersionManager.fullVersion)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Profile Management
    
    func refreshProfileDropdown() {
        setupProfileDropdownMenu()
    }
    
    @objc func profileChanged(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem else { return }
        
        // Check if a management option was selected (no representedObject)
        if selectedItem.representedObject == nil {
            // This is a management option, execute its action
            if let action = selectedItem.action {
                NSApp.sendAction(action, to: selectedItem.target, from: selectedItem)
            }
            // Reset selection to current profile
            refreshProfileDropdown()
            return
        }
        
        // This is a profile selection
        guard let profileId = selectedItem.representedObject as? UUID else { return }
        
        // Save current profile's rules first
        if let currentId = currentProfileId {
            ProfileManager.shared.updateProfile(id: currentId, rules: cleaningRules)
        }
        
        // Switch to new profile
        ProfileManager.shared.setActiveProfile(id: profileId)
        currentProfileId = profileId
        
        // Load new profile's rules
        let newProfile = ProfileManager.shared.getActiveProfile()
        cleaningRules = newProfile.rules
        
        // Update all checkboxes to reflect new profile's rules
        updateCheckboxesFromRules()
        
        // Update custom rules UI
        refreshCustomRulesUI()
    }
    
    func updateCheckboxesFromRules() {
        // Update all checkboxes to match current cleaningRules
        for checkbox in checkboxes {
            switch checkbox.tag {
            case 0: checkbox.state = cleaningRules.removeZeroWidthChars ? .on : .off
            case 1: checkbox.state = cleaningRules.removeEmdashes ? .on : .off
            case 2: checkbox.state = cleaningRules.normalizeSpaces ? .on : .off
            case 3: checkbox.state = cleaningRules.convertSmartQuotes ? .on : .off
            case 4: checkbox.state = cleaningRules.normalizeLineBreaks ? .on : .off
            case 5: checkbox.state = cleaningRules.removeTrailingSpaces ? .on : .off
            case 6: checkbox.state = cleaningRules.removeEmojis ? .on : .off
            case 7: checkbox.state = cleaningRules.removeExtraLineBreaks ? .on : .off
            case 8: checkbox.state = cleaningRules.removeLeadingTrailingWhitespace ? .on : .off
            case 9: checkbox.state = cleaningRules.removeUrlTracking ? .on : .off
            case 10: checkbox.state = cleaningRules.removeUrls ? .on : .off
            case 11: checkbox.state = cleaningRules.removeHtmlTags ? .on : .off
            case 12: checkbox.state = cleaningRules.removeExtraPunctuation ? .on : .off
            default: break
            }
        }
    }
    
    func refreshCustomRulesUI() {
        // Remove all existing custom rule rows
        for view in customRulesStackView.arrangedSubviews {
            customRulesStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        // Re-add custom rules from current profile
        for (index, rule) in cleaningRules.customRules.enumerated() {
            addCustomRuleRow(find: rule.find, replace: rule.replace, index: index)
        }
    }
    
    @objc func renameProfile() {
        guard let profileId = currentProfileId else { return }
        
        let alert = NSAlert()
        alert.messageText = "Rename Profile"
        alert.informativeText = "Enter a new name for this profile:"
        alert.alertStyle = .informational
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputField.stringValue = ProfileManager.shared.getActiveProfile().name
        alert.accessoryView = inputField
        alert.addButton(withTitle: "Rename")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newName = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty {
                ProfileManager.shared.renameProfile(id: profileId, newName: newName)
                refreshProfileDropdown()
            }
        }
    }
    
    @objc func createNewProfile() {
        let alert = NSAlert()
        alert.messageText = "Create New Profile"
        alert.informativeText = "Enter a name for the new profile:"
        alert.alertStyle = .informational
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputField.placeholderString = "Profile name"
        alert.accessoryView = inputField
        alert.addButton(withTitle: "Create")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newName = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty {
                // Save current profile first
                if let currentId = currentProfileId {
                    ProfileManager.shared.updateProfile(id: currentId, rules: cleaningRules)
                }
                
                // Create new profile based on current
                let currentProfile = ProfileManager.shared.getActiveProfile()
                let newProfile = ProfileManager.shared.createProfile(basedOn: currentProfile, name: newName)
                
                // Switch to new profile
                ProfileManager.shared.setActiveProfile(id: newProfile.id)
                currentProfileId = newProfile.id
                
                refreshProfileDropdown()
            }
        }
    }
    
    @objc func deleteCurrentProfile() {
        guard let profileId = currentProfileId else { return }
        
        let alert = NSAlert()
        alert.messageText = "Delete Profile"
        alert.informativeText = "Are you sure you want to delete this profile? This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let success = ProfileManager.shared.deleteProfile(id: profileId)
            if success {
                // Load the new active profile
                let newActiveProfile = ProfileManager.shared.getActiveProfile()
                currentProfileId = newActiveProfile.id
                cleaningRules = newActiveProfile.rules
                
                refreshProfileDropdown()
                
                // Update UI to reflect new profile
                updateCheckboxesFromRules()
                refreshCustomRulesUI()
            } else {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Cannot Delete"
                errorAlert.informativeText = "You cannot delete the last profile."
                errorAlert.alertStyle = .warning
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
            }
        }
    }
    
    @objc func exportProfile() {
        guard let profileId = currentProfileId else { return }
        
        // Save current changes first
        ProfileManager.shared.updateProfile(id: profileId, rules: cleaningRules)
        
        // Get the current profile
        let profile = ProfileManager.shared.getActiveProfile()
        
        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Export Profile"
        savePanel.message = "Choose where to save your profile"
        savePanel.nameFieldStringValue = "\(profile.name).clnbrd-profile"
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        
        // Set allowed file type
        if #available(macOS 11.0, *) {
            savePanel.allowedContentTypes = [
                UTType(exportedAs: "com.allanray.clnbrd.profile", conformingTo: .json)
            ]
        } else {
            savePanel.allowedFileTypes = ["clnbrd-profile"]
        }
        
        savePanel.begin { response in
            guard response == .OK, let fileURL = savePanel.url else { return }
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(profile)
                try jsonData.write(to: fileURL)
                
                // Show success message
                let alert = NSAlert()
                alert.messageText = "Profile Exported"
                alert.informativeText = "Successfully saved to:\n\(fileURL.path)"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = "Could not save profile: \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    @objc func shareProfile(_ sender: Any) {
        guard let profileId = currentProfileId else { return }
        
        // Save current changes first
        ProfileManager.shared.updateProfile(id: profileId, rules: cleaningRules)
        
        // Get the current profile
        let profile = ProfileManager.shared.getActiveProfile()
        
        // Export to JSON
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(profile)
            
            // Create temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "\(profile.name).clnbrd-profile"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            try jsonData.write(to: fileURL)
            
            // Show native macOS share sheet
            let sharingPicker = NSSharingServicePicker(items: [fileURL])
            
            // Handle different sender types
            if let button = sender as? NSButton {
                sharingPicker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            } else if sender is NSMenuItem {
                // For menu items, show relative to the profile dropdown
                sharingPicker.show(relativeTo: profileDropdown.bounds, of: profileDropdown, preferredEdge: .minY)
            } else {
                // Fallback: show relative to the window
                if let window = self.window {
                    sharingPicker.show(relativeTo: NSRect(x: 0, y: 0, width: 100, height: 100), of: window.contentView!, preferredEdge: .minY)
                }
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Share Failed"
            alert.informativeText = "Could not share profile: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    @objc func importProfile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Profile"
        openPanel.message = "Choose a Clnbrd profile file to import"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        
        // Use UTType for our custom file type
        if #available(macOS 11.0, *) {
            openPanel.allowedContentTypes = [
                UTType(exportedAs: "com.allanray.clnbrd.profile", conformingTo: .json)
            ]
        } else {
            openPanel.allowedFileTypes = ["clnbrd-profile"]
        }
        
        openPanel.begin { response in
            guard response == .OK, let fileURL = openPanel.url else { return }
            
            do {
                let jsonData = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                let importedProfile = try decoder.decode(CleaningProfile.self, from: jsonData)
                
                // Check if a profile with this name already exists
                let existingProfiles = ProfileManager.shared.getAllProfiles()
                var finalName = importedProfile.name
                var counter = 1
                
                while existingProfiles.contains(where: { $0.name == finalName }) {
                    finalName = "\(importedProfile.name) (\(counter))"
                    counter += 1
                }
                
                // Create new profile with potentially modified name
                let newProfile = ProfileManager.shared.createProfile(
                    basedOn: importedProfile,
                    name: finalName
                )
                
                // Switch to the newly imported profile
                ProfileManager.shared.setActiveProfile(id: newProfile.id)
                self.currentProfileId = newProfile.id
                self.cleaningRules = newProfile.rules
                
                // Update UI
                self.refreshProfileDropdown()
                self.updateCheckboxesFromRules()
                self.refreshCustomRulesUI()
                
                // Show success message
                let alert = NSAlert()
                alert.messageText = "Profile Imported"
                alert.informativeText = "Successfully imported profile: \(finalName)"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Import Failed"
                alert.informativeText = "Could not import profile: \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    // MARK: - Section Select All/Deselect All
    
    @objc func selectAllBasic() {
        // Basic Text Cleaning: tags 0-6
        for tag in 0...6 {
            if let checkbox = checkboxes.first(where: { $0.tag == tag }) {
                checkbox.state = .on
            }
        }
        // Update rules
        cleaningRules.removeZeroWidthChars = true
        cleaningRules.removeEmdashes = true
        cleaningRules.normalizeSpaces = true
        cleaningRules.convertSmartQuotes = true
        cleaningRules.normalizeLineBreaks = true
        cleaningRules.removeTrailingSpaces = true
        cleaningRules.removeEmojis = true
        
        // Save to profile
        if let profileId = currentProfileId {
            ProfileManager.shared.updateProfile(id: profileId, rules: cleaningRules)
        }
    }
    
    @objc func deselectAllBasic() {
        // Basic Text Cleaning: tags 0-6
        for tag in 0...6 {
            if let checkbox = checkboxes.first(where: { $0.tag == tag }) {
                checkbox.state = .off
            }
        }
        // Update rules
        cleaningRules.removeZeroWidthChars = false
        cleaningRules.removeEmdashes = false
        cleaningRules.normalizeSpaces = false
        cleaningRules.convertSmartQuotes = false
        cleaningRules.normalizeLineBreaks = false
        cleaningRules.removeTrailingSpaces = false
        cleaningRules.removeEmojis = false
        
        // Save to profile
        if let profileId = currentProfileId {
            ProfileManager.shared.updateProfile(id: profileId, rules: cleaningRules)
        }
    }
    
    @objc func selectAllAdvanced() {
        // Advanced Cleaning: tags 7-12
        for tag in 7...12 {
            if let checkbox = checkboxes.first(where: { $0.tag == tag }) {
                checkbox.state = .on
            }
        }
        // Update rules
        cleaningRules.removeExtraLineBreaks = true
        cleaningRules.removeLeadingTrailingWhitespace = true
        cleaningRules.removeUrlTracking = true
        cleaningRules.removeUrls = true
        cleaningRules.removeHtmlTags = true
        cleaningRules.removeExtraPunctuation = true
        
        // Save to profile
        if let profileId = currentProfileId {
            ProfileManager.shared.updateProfile(id: profileId, rules: cleaningRules)
        }
    }
    
    @objc func deselectAllAdvanced() {
        // Advanced Cleaning: tags 7-12
        for tag in 7...12 {
            if let checkbox = checkboxes.first(where: { $0.tag == tag }) {
                checkbox.state = .off
            }
        }
        // Update rules
        cleaningRules.removeExtraLineBreaks = false
        cleaningRules.removeLeadingTrailingWhitespace = false
        cleaningRules.removeUrlTracking = false
        cleaningRules.removeUrls = false
        cleaningRules.removeHtmlTags = false
        cleaningRules.removeExtraPunctuation = false
        
        // Save to profile
        if let profileId = currentProfileId {
            ProfileManager.shared.updateProfile(id: profileId, rules: cleaningRules)
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
            
            // Save to current profile when custom rules change
            if let profileId = currentProfileId {
                ProfileManager.shared.updateProfile(id: profileId, rules: cleaningRules)
            }
        }
    }
}

// MARK: - NSWindowDelegate

extension SettingsWindow: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        // Window became active, scroll to top
        scrollToTop()
    }
}

// MARK: - NSTabViewDelegate
extension SettingsWindow: NSTabViewDelegate {
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        // Update window title based on selected tab
        guard let tabViewItem = tabViewItem, let window = window else { return }
        window.title = tabViewItem.label
        
        // Adjust window size based on tab
        let currentFrame = window.frame
        let newHeight: CGFloat
        
        if tabViewItem.identifier as? String == "about" {
            // About tab should be shorter
            newHeight = 400
        } else {
            // Rules tab can be taller
            newHeight = 550
        }
        
        // Animate to new size if different
        if abs(currentFrame.height - newHeight) > 10 {
            var newFrame = currentFrame
            newFrame.size.height = newHeight
            // Keep the top-left corner in the same position
            newFrame.origin.y = currentFrame.origin.y + (currentFrame.height - newHeight)
            
            window.setFrame(newFrame, display: true, animate: true)
        }
    }
}
