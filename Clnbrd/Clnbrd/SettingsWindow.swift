import Cocoa
import os.log
import ServiceManagement
import UniformTypeIdentifiers

// swiftlint:disable file_length
// swiftlint:disable type_body_length

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "settings")

/// Settings window for configuring cleaning rules and application preferences
class SettingsWindow: NSWindowController {
    var cleaningRules: CleaningRules
    var checkboxes: [NSButton] = []
    var customRulesStackView: NSStackView!
    var profileDropdown: NSPopUpButton!
    var currentProfileId: UUID?
    var scrollView: NSScrollView!
    var mainTabView: NSTabView!
    var appExclusionsTableView: NSTableView!
    var appExclusionsData: [String] = []
    
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
        for item in tabView.tabViewItems where item.identifier as? String == tabIdentifier {
            tabView.selectTabViewItem(item)
            break
        }
        
        showWindow(nil)
    }
    
    /// Select a specific tab by index
    func selectTab(_ tabIndex: Int) {
        logger.info("📑 Selecting tab \(tabIndex) (total tabs: \(self.mainTabView.numberOfTabViewItems))")
        guard tabIndex >= 0 && tabIndex < self.mainTabView.numberOfTabViewItems else {
            logger.error("❌ Invalid tab index: \(tabIndex)")
            return
        }
        self.mainTabView.selectTabViewItem(at: tabIndex)
        logger.info("✅ Tab \(tabIndex) selected")
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
        
        // Add modern vibrancy to window background
        if let contentView = window.contentView {
            let backgroundView = NSVisualEffectView(frame: contentView.bounds)
            backgroundView.autoresizingMask = [.width, .height]
            backgroundView.material = .underWindowBackground  // Apple's standard for settings windows
            backgroundView.state = .followsWindowActiveState
            backgroundView.blendingMode = .behindWindow
            contentView.addSubview(backgroundView, positioned: .below, relativeTo: nil)
        }
        
        // Create tab view
        mainTabView = NSTabView()
        mainTabView.translatesAutoresizingMaskIntoConstraints = false
        mainTabView.delegate = self
        
        // Tab 1: Rules (Cleaning Rules)
        let rulesTab = NSTabViewItem(identifier: "rules")
        rulesTab.label = "Rules"
        rulesTab.view = createGeneralTab()
        mainTabView.addTabViewItem(rulesTab)
        
        // Tab 2: Settings (formerly History)
        let settingsTab = NSTabViewItem(identifier: "settings")
        settingsTab.label = "Settings"
        settingsTab.view = createHistoryTab()
        mainTabView.addTabViewItem(settingsTab)
        
        // Tab 3: About
        let aboutTab = NSTabViewItem(identifier: "about")
        aboutTab.label = "About"
        aboutTab.view = createAboutTab()
        mainTabView.addTabViewItem(aboutTab)
        
        // Add tab view to window
        window.contentView = mainTabView
        
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
        stackView.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)  // Apple standard for settings
        
        // Setup all UI sections
        setupProfileSection(stackView)
        setupBasicTextCleaningSection(stackView)
        setupAdvancedCleaningSection(stackView)
        setupClipboardSafetySection(stackView)
        
        // CUSTOM FIND & REPLACE RULES SECTION
        stackView.addArrangedSubview(createSpacer(height: 12))  // More compact
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
        addButton.bezelStyle = .automatic  // Modern, adaptive style
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
    
    // swiftlint:disable:next function_body_length
    private func createHistoryTab() -> NSView {
        let container = NSView()
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)
        
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12  // More compact, Apple HIG standard
        stackView.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)  // Apple standard for settings
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        scrollView.documentView = contentView
        
        // Header with SF Pro Rounded
        let headerLabel = NSTextField(labelWithString: "Clipboard Settings")
        if let roundedFont = NSFont.systemFont(ofSize: 17, weight: .semibold).rounded() {
            headerLabel.font = roundedFont  // Apple's standard: 17pt semibold for section headers
        } else {
            headerLabel.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        }
        stackView.addArrangedSubview(headerLabel)
        
        let descriptionLabel = NSTextField(labelWithString: "Automatically saves your clipboard history before cleaning.")
        descriptionLabel.font = NSFont.systemFont(ofSize: 11)  // Compact secondary text
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 1
        descriptionLabel.preferredMaxLayoutWidth = 460
        stackView.addArrangedSubview(descriptionLabel)
        
        // Enable/Disable Toggle
        let enableCheckbox = NSButton(checkboxWithTitle: "Enable Clipboard History", target: self, action: #selector(toggleHistoryEnabled))
        enableCheckbox.state = ClipboardHistoryManager.shared.isEnabled ? .on : .off
        stackView.addArrangedSubview(enableCheckbox)
        
        stackView.addArrangedSubview(createSeparatorLine())
        
        // MARK: - Appearance Section
        let appearanceHeader = NSTextField(labelWithString: "Appearance")
        if let roundedFont = NSFont.systemFont(ofSize: 15, weight: .semibold).rounded() {
            appearanceHeader.font = roundedFont
        } else {
            appearanceHeader.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        }
        stackView.addArrangedSubview(appearanceHeader)
        
        let appearanceDesc = NSTextField(labelWithString: "Choose how Clnbrd looks. Auto follows your system appearance.")
        appearanceDesc.font = NSFont.systemFont(ofSize: 11)
        appearanceDesc.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(appearanceDesc)
        
        let appearanceControl = NSSegmentedControl(labels: ["Auto", "Light", "Dark"], trackingMode: .selectOne, target: self, action: #selector(appearanceChanged(_:)))
        appearanceControl.segmentStyle = .rounded
        appearanceControl.translatesAutoresizingMaskIntoConstraints = false
        
        // Set current selection based on saved preference
        let currentAppearance = UserDefaults.standard.string(forKey: "AppearanceMode") ?? "auto"
        switch currentAppearance {
        case "light": appearanceControl.selectedSegment = 1
        case "dark": appearanceControl.selectedSegment = 2
        default: appearanceControl.selectedSegment = 0 // auto
        }
        
        NSLayoutConstraint.activate([
            appearanceControl.widthAnchor.constraint(equalToConstant: 220)  // More compact
        ])
        stackView.addArrangedSubview(appearanceControl)
        
        stackView.addArrangedSubview(createSeparatorLine())
        
        // MARK: - Keyboard Shortcuts Section
        let hotkeysHeader = NSTextField(labelWithString: "Keyboard Shortcuts")
        if let roundedFont = NSFont.systemFont(ofSize: 15, weight: .semibold).rounded() {
            hotkeysHeader.font = roundedFont
        } else {
            hotkeysHeader.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        }
        stackView.addArrangedSubview(hotkeysHeader)
        
        let hotkeysDesc = NSTextField(labelWithString: "Click on a shortcut to change it. Press ⌫ to disable.")
        hotkeysDesc.font = NSFont.systemFont(ofSize: 11)
        hotkeysDesc.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(hotkeysDesc)
        
        // Clean & Paste hotkey
        let cleanPasteRow = createHotkeyRow(
            action: .cleanAndPaste,
            description: "Clean and Paste:",
            config: HotkeyManager.shared.getConfiguration(for: .cleanAndPaste)
        )
        stackView.addArrangedSubview(cleanPasteRow)
        
        // Show History hotkey
        let historyRow = createHotkeyRow(
            action: .showHistory,
            description: "Show Clipboard History:",
            config: HotkeyManager.shared.getConfiguration(for: .showHistory)
        )
        stackView.addArrangedSubview(historyRow)
        
        // Screenshot hotkey
        let screenshotRow = createHotkeyRow(
            action: .captureScreenshot,
            description: "Capture Screenshot:",
            config: HotkeyManager.shared.getConfiguration(for: .captureScreenshot)
        )
        stackView.addArrangedSubview(screenshotRow)
        
        // Buttons container
        let buttonsStack = NSStackView()
        buttonsStack.orientation = .horizontal
        buttonsStack.spacing = 8
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        
        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetHotkeysToDefaults))
        resetButton.bezelStyle = .rounded
        resetButton.font = NSFont.systemFont(ofSize: 11)
        buttonsStack.addArrangedSubview(resetButton)
        
        let systemButton = NSButton(title: "System Keyboard Shortcuts...", target: self, action: #selector(openKeyboardShortcutsSettings))
        systemButton.bezelStyle = .rounded
        systemButton.font = NSFont.systemFont(ofSize: 11)
        buttonsStack.addArrangedSubview(systemButton)
        
        stackView.addArrangedSubview(buttonsStack)
        
        let helpLabel = NSTextField(labelWithString: "💡 Check System Settings if a hotkey conflicts with other apps")
        helpLabel.font = NSFont.systemFont(ofSize: 10)
        helpLabel.textColor = .tertiaryLabelColor
        helpLabel.lineBreakMode = .byWordWrapping
        helpLabel.maximumNumberOfLines = 1
        helpLabel.preferredMaxLayoutWidth = 460
        stackView.addArrangedSubview(helpLabel)
        
        stackView.addArrangedSubview(createSeparatorLine())
        
        // MARK: - App Exclusions Section (at top)
        let exclusionsHeader = NSTextField(labelWithString: "App Exclusions")
        if let roundedFont = NSFont.systemFont(ofSize: 15, weight: .semibold).rounded() {
            exclusionsHeader.font = roundedFont  // SF Pro Rounded for subsection headers
        } else {
            exclusionsHeader.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        }
        stackView.addArrangedSubview(exclusionsHeader)
        
        let exclusionsDesc = NSTextField(labelWithString: "Don't capture clipboard from these apps (e.g., password managers)")
        exclusionsDesc.font = NSFont.systemFont(ofSize: 11)
        exclusionsDesc.textColor = .secondaryLabelColor
        exclusionsDesc.lineBreakMode = .byWordWrapping
        exclusionsDesc.maximumNumberOfLines = 1
        exclusionsDesc.preferredMaxLayoutWidth = 460
        stackView.addArrangedSubview(exclusionsDesc)
        
        // Table View for excluded apps (Modern inset style)
        appExclusionsData = Array(ClipboardHistoryManager.shared.excludedApps).sorted()
        
        let tableScrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: 120))  // More compact
        tableScrollView.hasVerticalScroller = true
        tableScrollView.borderType = .noBorder  // Modern: no border
        tableScrollView.drawsBackground = false
        tableScrollView.autohidesScrollers = true
        tableScrollView.translatesAutoresizingMaskIntoConstraints = false
        
        appExclusionsTableView = NSTableView(frame: tableScrollView.bounds)
        appExclusionsTableView.dataSource = self
        appExclusionsTableView.delegate = self
        appExclusionsTableView.headerView = nil
        appExclusionsTableView.allowsEmptySelection = true
        appExclusionsTableView.allowsMultipleSelection = false
        appExclusionsTableView.style = .inset  // macOS 11+ modern inset style
        appExclusionsTableView.usesAlternatingRowBackgroundColors = false  // Clean look
        appExclusionsTableView.backgroundColor = .clear
        appExclusionsTableView.gridStyleMask = []  // No grid lines
        appExclusionsTableView.rowSizeStyle = .small  // More compact rows
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("appName"))
        column.title = "App Name"
        column.width = 440
        appExclusionsTableView.addTableColumn(column)
        
        tableScrollView.documentView = appExclusionsTableView
        tableScrollView.heightAnchor.constraint(equalToConstant: 120).isActive = true  // More compact
        tableScrollView.widthAnchor.constraint(equalToConstant: 460).isActive = true  // More compact
        
        stackView.addArrangedSubview(tableScrollView)
        
        // Buttons for managing exclusions
        let exclusionsButtonStack = NSStackView()
        exclusionsButtonStack.orientation = .horizontal
        exclusionsButtonStack.spacing = 8
        
        let addExclusionButton = NSButton(title: "Add App...", target: self, action: #selector(addExcludedApp))
        addExclusionButton.bezelStyle = .automatic  // Modern, adaptive style
        exclusionsButtonStack.addArrangedSubview(addExclusionButton)
        
        let removeExclusionButton = NSButton(title: "Remove App", target: self, action: #selector(removeExcludedApp))
        removeExclusionButton.bezelStyle = .automatic  // Modern, adaptive style
        exclusionsButtonStack.addArrangedSubview(removeExclusionButton)
        
        let resetExclusionsButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetExcludedApps))
        resetExclusionsButton.bezelStyle = .automatic  // Modern, adaptive style
        exclusionsButtonStack.addArrangedSubview(resetExclusionsButton)
        
        stackView.addArrangedSubview(exclusionsButtonStack)
        
        stackView.addArrangedSubview(createSeparatorLine())
        
        // MARK: - History Section (all in one row)
        let historySectionLabel = NSTextField(labelWithString: "History")
        if let roundedFont = NSFont.systemFont(ofSize: 15, weight: .semibold).rounded() {
            historySectionLabel.font = roundedFont  // SF Pro Rounded for subsection headers
        } else {
            historySectionLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        }
        stackView.addArrangedSubview(historySectionLabel)
        
        let historyControlStack = NSStackView()
        historyControlStack.orientation = .horizontal
        historyControlStack.spacing = 12
        historyControlStack.alignment = .centerY
        
        // Max Items
        let maxItemsLabel = NSTextField(labelWithString: "Maximum items:")
        maxItemsLabel.font = NSFont.systemFont(ofSize: 13)
        maxItemsLabel.setContentHuggingPriority(.required, for: .horizontal)
        historyControlStack.addArrangedSubview(maxItemsLabel)
        
        let maxItemsPopup = NSPopUpButton()
        maxItemsPopup.autoenablesItems = false
        let maxItemsOptions = [10, 25, 50, 100, 200]
        for option in maxItemsOptions {
            maxItemsPopup.addItem(withTitle: "\(option) items")
        }
        if let currentIndex = maxItemsOptions.firstIndex(of: ClipboardHistoryManager.shared.maxItems) {
            maxItemsPopup.selectItem(at: currentIndex)
        } else {
            maxItemsPopup.selectItem(at: 3) // Default to 100
        }
        maxItemsPopup.target = self
        maxItemsPopup.action = #selector(maxItemsChanged(_:))
        maxItemsPopup.setContentHuggingPriority(.required, for: .horizontal)
        historyControlStack.addArrangedSubview(maxItemsPopup)
        
        // Small spacer
        let spacer1 = NSView()
        spacer1.widthAnchor.constraint(equalToConstant: 8).isActive = true
        spacer1.setContentHuggingPriority(.required, for: .horizontal)
        historyControlStack.addArrangedSubview(spacer1)
        
        // Retention Period
        let retentionLabel = NSTextField(labelWithString: "Delete after:")
        retentionLabel.font = NSFont.systemFont(ofSize: 13)
        retentionLabel.setContentHuggingPriority(.required, for: .horizontal)
        historyControlStack.addArrangedSubview(retentionLabel)
        
        let retentionPopup = NSPopUpButton()
        retentionPopup.autoenablesItems = false
        for period in ClipboardHistoryManager.RetentionPeriod.allCases {
            retentionPopup.addItem(withTitle: period.rawValue)
        }
        retentionPopup.selectItem(withTitle: ClipboardHistoryManager.shared.retentionPeriod.rawValue)
        retentionPopup.target = self
        retentionPopup.action = #selector(retentionPeriodChanged(_:))
        retentionPopup.setContentHuggingPriority(.required, for: .horizontal)
        historyControlStack.addArrangedSubview(retentionPopup)
        
        // Flexible spacer
        let spacer2 = NSView()
        spacer2.setContentHuggingPriority(.defaultLow, for: .horizontal)
        historyControlStack.addArrangedSubview(spacer2)
        
        // Clear Button
        let clearButton = NSButton(title: "Clear All History", target: self, action: #selector(clearHistoryClicked))
        clearButton.bezelStyle = .automatic  // Modern, adaptive style
        clearButton.setContentHuggingPriority(.required, for: .horizontal)
        historyControlStack.addArrangedSubview(clearButton)
        
        stackView.addArrangedSubview(historyControlStack)
        
        stackView.addArrangedSubview(createSeparatorLine())
        
        // MARK: - Image Compression Section
        let compressionHeader = NSTextField(labelWithString: "Image Compression")
        if let roundedFont = NSFont.systemFont(ofSize: 15, weight: .semibold).rounded() {
            compressionHeader.font = roundedFont
        } else {
            compressionHeader.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        }
        stackView.addArrangedSubview(compressionHeader)
        
        let compressionDesc = NSTextField(labelWithString: "Optimize images to save space")
        compressionDesc.font = NSFont.systemFont(ofSize: 11)
        compressionDesc.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(compressionDesc)
        
        // Compress Images Checkbox
        let compressCheckbox = NSButton(
            checkboxWithTitle: "Compress images in history",
            target: self,
            action: #selector(toggleImageCompression)
        )
        compressCheckbox.state = ClipboardHistoryManager.shared.compressImages ? .on : .off
        stackView.addArrangedSubview(compressCheckbox)
        
        // Max Image Size
        let maxSizeStack = NSStackView()
        maxSizeStack.orientation = .horizontal
        maxSizeStack.spacing = 8
        
        let maxSizeLabel = NSTextField(labelWithString: "Maximum image size:")
        maxSizeLabel.alignment = .right
        maxSizeLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        maxSizeStack.addArrangedSubview(maxSizeLabel)
        
        let maxSizePopup = NSPopUpButton()
        maxSizePopup.addItems(withTitles: ["1024px", "2048px", "4096px", "8192px"])
        let currentMaxSize = ClipboardHistoryManager.shared.maxImageSize
        let sizeIndex: Int = {
            switch Int(currentMaxSize) {
            case 1024: return 0
            case 2048: return 1
            case 4096: return 2
            case 8192: return 3
            default: return 1
            }
        }()
        maxSizePopup.selectItem(at: sizeIndex)
        maxSizePopup.target = self
        maxSizePopup.action = #selector(maxImageSizeChanged)
        maxSizeStack.addArrangedSubview(maxSizePopup)
        
        stackView.addArrangedSubview(maxSizeStack)
        
        // Compression Quality Slider
        let qualityStack = NSStackView()
        qualityStack.orientation = .horizontal
        qualityStack.spacing = 8
        
        let qualityLabel = NSTextField(labelWithString: "Compression quality:")
        qualityLabel.alignment = .right
        qualityLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        qualityStack.addArrangedSubview(qualityLabel)
        
        let qualitySlider = NSSlider(value: ClipboardHistoryManager.shared.compressionQuality,
                                     minValue: 0.3,
                                     maxValue: 1.0,
                                     target: self,
                                     action: #selector(compressionQualityChanged))
        qualitySlider.numberOfTickMarks = 0
        qualityStack.addArrangedSubview(qualitySlider)
        
        let qualityValueLabel = NSTextField(labelWithString: "\(Int(ClipboardHistoryManager.shared.compressionQuality * 100))%")
        qualityValueLabel.tag = 999 // Tag to update later
        qualityValueLabel.alignment = .left
        qualityValueLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        qualityStack.addArrangedSubview(qualityValueLabel)
        
        stackView.addArrangedSubview(qualityStack)
        
        stackView.addArrangedSubview(createSeparatorLine())
        
        // Image Export Settings Section
        let exportHeader = NSTextField(labelWithString: "Image Export Settings")
        if let roundedFont = NSFont.systemFont(ofSize: 15, weight: .semibold).rounded() {
            exportHeader.font = roundedFont
        } else {
            exportHeader.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        }
        stackView.addArrangedSubview(exportHeader)
        
        let exportDesc = NSTextField(labelWithString: "Configure how images are exported when saved from history")
        exportDesc.font = NSFont.systemFont(ofSize: 11)
        exportDesc.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(exportDesc)
        
        // File Format
        let formatStack = NSStackView()
        formatStack.orientation = .horizontal
        formatStack.spacing = 8
        
        let formatLabel = NSTextField(labelWithString: "File format:")
        formatLabel.alignment = .right
        formatLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        formatStack.addArrangedSubview(formatLabel)
        
        let formatPopup = NSPopUpButton()
        formatPopup.addItems(withTitles: ["PNG", "JPEG", "TIFF"])
        let currentFormat = ClipboardHistoryManager.shared.imageExportFormat
        switch currentFormat {
        case .png: formatPopup.selectItem(at: 0)
        case .jpeg: formatPopup.selectItem(at: 1)
        case .tiff: formatPopup.selectItem(at: 2)
        }
        formatPopup.target = self
        formatPopup.action = #selector(exportFormatChanged)
        formatStack.addArrangedSubview(formatPopup)
        
        stackView.addArrangedSubview(formatStack)
        
        // Retina Scaling
        let retinaCheckbox = NSButton(
            checkboxWithTitle: "Scale Retina screenshots to 1x",
            target: self,
            action: #selector(toggleScaleRetina)
        )
        retinaCheckbox.state = ClipboardHistoryManager.shared.scaleRetinaTo1x ? .on : .off
        stackView.addArrangedSubview(retinaCheckbox)
        
        // sRGB Conversion
        let srgbCheckbox = NSButton(
            checkboxWithTitle: "Convert to sRGB profile",
            target: self,
            action: #selector(toggleConvertSRGB)
        )
        srgbCheckbox.state = ClipboardHistoryManager.shared.convertToSRGB ? .on : .off
        stackView.addArrangedSubview(srgbCheckbox)
        
        // Border
        let borderCheckbox = NSButton(
            checkboxWithTitle: "Add 1px border to all screenshots",
            target: self,
            action: #selector(toggleAddBorder)
        )
        borderCheckbox.state = ClipboardHistoryManager.shared.addBorderToScreenshots ? .on : .off
        stackView.addArrangedSubview(borderCheckbox)
        
        // JPEG Quality (only visible when JPEG is selected)
        let jpegQualityStack = NSStackView()
        jpegQualityStack.orientation = .horizontal
        jpegQualityStack.spacing = 8
        jpegQualityStack.identifier = NSUserInterfaceItemIdentifier("jpegQualityStack")
        jpegQualityStack.isHidden = currentFormat != .jpeg
        
        let jpegQualityLabel = NSTextField(labelWithString: "JPEG quality:")
        jpegQualityLabel.alignment = .right
        jpegQualityLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        jpegQualityStack.addArrangedSubview(jpegQualityLabel)
        
        let jpegQualitySlider = NSSlider(
            value: ClipboardHistoryManager.shared.jpegExportQuality,
            minValue: 0.5,
            maxValue: 1.0,
            target: self,
            action: #selector(jpegExportQualityChanged)
        )
        jpegQualitySlider.numberOfTickMarks = 0
        jpegQualityStack.addArrangedSubview(jpegQualitySlider)
        
        let jpegQualityValueLabel = NSTextField(
            labelWithString: "\(Int(ClipboardHistoryManager.shared.jpegExportQuality * 100))%"
        )
        jpegQualityValueLabel.identifier = NSUserInterfaceItemIdentifier("jpegQualityValueLabel")
        jpegQualityValueLabel.alignment = .left
        jpegQualityValueLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        jpegQualityStack.addArrangedSubview(jpegQualityValueLabel)
        
        stackView.addArrangedSubview(jpegQualityStack)
        
        stackView.addArrangedSubview(createSeparatorLine())
        
        // MARK: - Statistics Section (at bottom)
        let statsLabel = NSTextField(labelWithString: "Statistics")
        if let roundedFont = NSFont.systemFont(ofSize: 15, weight: .semibold).rounded() {
            statsLabel.font = roundedFont  // SF Pro Rounded for subsection headers
        } else {
            statsLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        }
        stackView.addArrangedSubview(statsLabel)
        
        let statsStack = NSStackView()
        statsStack.orientation = .vertical
        statsStack.alignment = .leading
        statsStack.spacing = 4
        
        let totalItemsLabel = NSTextField(labelWithString: "Total items: \(ClipboardHistoryManager.shared.totalItems)")
        totalItemsLabel.font = NSFont.systemFont(ofSize: 11)
        totalItemsLabel.textColor = .secondaryLabelColor
        statsStack.addArrangedSubview(totalItemsLabel)
        
        if let oldestDate = ClipboardHistoryManager.shared.oldestItemDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let oldestText = formatter.localizedString(for: oldestDate, relativeTo: Date())
            let oldestLabel = NSTextField(labelWithString: "Oldest item: \(oldestText)")
            oldestLabel.font = NSFont.systemFont(ofSize: 11)
            oldestLabel.textColor = .secondaryLabelColor
            statsStack.addArrangedSubview(oldestLabel)
        }
        
        // Storage usage
        let storageText = ClipboardHistoryManager.shared.totalStorageSizeFormatted
        let maxStorageText = ClipboardHistoryManager.shared.formatBytes(ClipboardHistoryManager.shared.maxStorageSize)
        let storageLabel = NSTextField(labelWithString: "Storage: \(storageText) / \(maxStorageText)")
        storageLabel.font = NSFont.systemFont(ofSize: 11)
        storageLabel.textColor = .secondaryLabelColor
        statsStack.addArrangedSubview(storageLabel)
        
        stackView.addArrangedSubview(statsStack)
        
        // Spacer
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 500)  // More compact minimum width
        ])
        
        return container
    }
    
    // MARK: - History Tab Actions
    
    @objc private func toggleHistoryEnabled(_ sender: NSButton) {
        ClipboardHistoryManager.shared.isEnabled = (sender.state == .on)
        logger.info("History enabled: \(sender.state == .on)")
    }
    
    @objc private func appearanceChanged(_ sender: NSSegmentedControl) {
        let appearance: String
        let nsAppearance: NSAppearance?
        
        switch sender.selectedSegment {
        case 1: // Light
            appearance = "light"
            nsAppearance = NSAppearance(named: .aqua)
            logger.info("Appearance changed to: Light")
        case 2: // Dark
            appearance = "dark"
            nsAppearance = NSAppearance(named: .darkAqua)
            logger.info("Appearance changed to: Dark")
        default: // Auto
            appearance = "auto"
            nsAppearance = nil // nil = follow system
            logger.info("Appearance changed to: Auto (System)")
        }
        
        // Save preference
        UserDefaults.standard.set(appearance, forKey: "AppearanceMode")
        
        // Apply to all windows immediately
        NSApp.appearance = nsAppearance
        
        // Track analytics
        AnalyticsManager.shared.trackFeatureUsage("appearance_changed_\(appearance)")
    }
    
    @objc private func retentionPeriodChanged(_ sender: NSPopUpButton) {
        guard let title = sender.selectedItem?.title else { return }
        
        let period: ClipboardHistoryManager.RetentionPeriod = {
            switch title {
            case "1 Day": return .oneDay
            case "3 Days": return .threeDays
            case "1 Week": return .oneWeek
            case "1 Month": return .oneMonth
            case "Forever": return .forever
            default: return .threeDays
            }
        }()
        
        ClipboardHistoryManager.shared.retentionPeriod = period
        logger.info("Retention period changed to: \(period.rawValue)")
    }
    
    @objc private func maxItemsChanged(_ sender: NSPopUpButton) {
        guard let title = sender.selectedItem?.title else { return }
        
        let maxItems = Int(title) ?? 100
        ClipboardHistoryManager.shared.maxItems = maxItems
        logger.info("Max items changed to: \(maxItems)")
    }
    
    @objc private func toggleImageCompression(_ sender: NSButton) {
        ClipboardHistoryManager.shared.compressImages = (sender.state == .on)
        logger.info("Image compression enabled: \(sender.state == .on)")
    }
    
    @objc private func maxImageSizeChanged(_ sender: NSPopUpButton) {
        guard let title = sender.selectedItem?.title else { return }
        
        let sizeValue: CGFloat = {
            switch title {
            case "1024px": return 1024
            case "2048px": return 2048
            case "4096px": return 4096
            case "8192px": return 8192
            default: return 2048
            }
        }()
        
        ClipboardHistoryManager.shared.maxImageSize = sizeValue
        logger.info("Max image size changed to: \(sizeValue)")
    }
    
    @objc private func compressionQualityChanged(_ sender: NSSlider) {
        let quality = sender.doubleValue
        ClipboardHistoryManager.shared.compressionQuality = quality
        
        // Update the quality label
        if let window = sender.window,
           let qualityLabel = window.contentView?.viewWithTag(999) as? NSTextField {
            qualityLabel.stringValue = "\(Int(quality * 100))%"
        }
        
        logger.info("Compression quality changed to: \(quality)")
    }
    
    @objc private func clearHistoryClicked() {
        let alert = NSAlert()
        alert.messageText = "Clear All History?"
        alert.informativeText = "This will delete all non-pinned items from your clipboard history. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            ClipboardHistoryManager.shared.clearHistory()
            logger.info("Clipboard history cleared by user")
        }
    }
    
    @objc private func addExcludedApp() {
        let alert = NSAlert()
        alert.messageText = "Add Excluded App"
        alert.informativeText = "Enter the exact name of the app to exclude from history capture:"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputTextField.placeholderString = "e.g., 1Password"
        alert.accessoryView = inputTextField
        
        alert.window.initialFirstResponder = inputTextField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let appName = inputTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !appName.isEmpty {
                ClipboardHistoryManager.shared.excludedApps.insert(appName)
                logger.info("Added excluded app: \(appName)")
                
                // Refresh table view
                appExclusionsData = Array(ClipboardHistoryManager.shared.excludedApps).sorted()
                appExclusionsTableView.reloadData()
            }
        }
    }
    
    @objc private func removeExcludedApp() {
        let selectedRow = appExclusionsTableView.selectedRow
        
        if appExclusionsData.isEmpty {
            let alert = NSAlert()
            alert.messageText = "No Excluded Apps"
            alert.informativeText = "There are no apps in the exclusion list."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        if selectedRow < 0 {
            let alert = NSAlert()
            alert.messageText = "No App Selected"
            alert.informativeText = "Please select an app from the list to remove."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        let appName = appExclusionsData[selectedRow]
        
        let alert = NSAlert()
        alert.messageText = "Remove App?"
        alert.informativeText = "Remove \"\(appName)\" from the exclusion list?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            ClipboardHistoryManager.shared.excludedApps.remove(appName)
            logger.info("Removed excluded app: \(appName)")
            
            // Refresh table view
            appExclusionsData = Array(ClipboardHistoryManager.shared.excludedApps).sorted()
            appExclusionsTableView.reloadData()
        }
    }
    
    @objc private func resetExcludedApps() {
        let alert = NSAlert()
        alert.messageText = "Reset Exclusion List?"
        alert.informativeText = "This will restore the default list of excluded apps (password managers)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            ClipboardHistoryManager.shared.excludedApps = Set([
                "1Password",
                "Bitwarden",
                "LastPass",
                "Dashlane",
                "Keeper Password Manager",
                "Keychain Access"
            ])
            logger.info("Reset excluded apps to defaults")
            
            // Refresh table view
            appExclusionsData = Array(ClipboardHistoryManager.shared.excludedApps).sorted()
            appExclusionsTableView.reloadData()
        }
    }
    
    @objc private func exportFormatChanged(_ sender: NSPopUpButton) {
        let selectedIndex = sender.indexOfSelectedItem
        let format: ClipboardHistoryManager.ImageExportFormat
        
        switch selectedIndex {
        case 0: format = .png
        case 1: format = .jpeg
        case 2: format = .tiff
        default: format = .png
        }
        
        ClipboardHistoryManager.shared.imageExportFormat = format
        logger.info("Export format changed to: \(format.rawValue)")
        
        // Show/hide JPEG quality slider based on format
        let historyTab = self.mainTabView.tabViewItem(at: 2)
        if let jpegQualityStack = historyTab.view?.subviews.first(where: { 
            $0.identifier?.rawValue == "jpegQualityStack" 
        }) {
            jpegQualityStack.isHidden = (format != .jpeg)
        }
    }
    
    @objc private func toggleScaleRetina(_ sender: NSButton) {
        ClipboardHistoryManager.shared.scaleRetinaTo1x = (sender.state == .on)
        logger.info("Scale retina to 1x: \(sender.state == .on)")
    }
    
    @objc private func toggleConvertSRGB(_ sender: NSButton) {
        ClipboardHistoryManager.shared.convertToSRGB = (sender.state == .on)
        logger.info("Convert to sRGB: \(sender.state == .on)")
    }
    
    @objc private func toggleAddBorder(_ sender: NSButton) {
        ClipboardHistoryManager.shared.addBorderToScreenshots = (sender.state == .on)
        logger.info("Add border to screenshots: \(sender.state == .on)")
    }
    
    @objc private func jpegExportQualityChanged(_ sender: NSSlider) {
        let quality = sender.doubleValue
        ClipboardHistoryManager.shared.jpegExportQuality = quality
        
        // Update the quality label - find it recursively
        let historyTab = self.mainTabView.tabViewItem(at: 2)
        func findQualityLabel(in view: NSView) -> NSTextField? {
            if let textField = view as? NSTextField,
               textField.identifier?.rawValue == "jpegQualityValueLabel" {
                return textField
            }
            for subview in view.subviews {
                if let found = findQualityLabel(in: subview) {
                    return found
                }
            }
            return nil
        }
        
        if let view = historyTab.view, let qualityLabel = findQualityLabel(in: view) {
            qualityLabel.stringValue = "\(Int(quality * 100))%"
        }
        
        logger.info("JPEG export quality changed to: \(Int(quality * 100))%")
    }
    
    // swiftlint:disable:next function_body_length
    private func createAboutTab() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 12
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.edgeInsets = NSEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)  // More compact and consistent
        
        // Top section: Icon + App Info (side by side)
        let topStack = NSStackView()
        topStack.orientation = .horizontal
        topStack.spacing = 16
        topStack.alignment = .top
        
        // App Icon
        let iconView = NSImageView()
        iconView.image = NSImage(named: NSImage.applicationIconName)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 96),  // More compact
            iconView.heightAnchor.constraint(equalToConstant: 96)
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
        
        // Update buttons stack
        let updateButtonsStack = NSStackView()
        updateButtonsStack.orientation = .vertical
        updateButtonsStack.spacing = 8
        updateButtonsStack.alignment = .leading
        
        // Horizontal stack for button + checkbox on same line
        let updateStack = NSStackView()
        updateStack.orientation = .horizontal
        updateStack.spacing = 16
        updateStack.alignment = .centerY
        
        // Check for Updates Button
        let updateButton = NSButton(title: "Check for Updates", target: self, action: #selector(checkForUpdates))
        updateButton.bezelStyle = .automatic  // Modern, adaptive style
        updateStack.addArrangedSubview(updateButton)
        
        // Auto-update checkbox (on same line)
        let autoUpdateCheckbox = NSButton(checkboxWithTitle: "Automatically check for updates", target: self, action: #selector(toggleAutoUpdate))
        autoUpdateCheckbox.state = UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks") ? .on : .off
        updateStack.addArrangedSubview(autoUpdateCheckbox)
        
        updateButtonsStack.addArrangedSubview(updateStack)
        
        // Revert to Stable button (only show if on beta)
        if VersionManager.version.contains("beta") {
            let revertButton = NSButton(title: "Revert to Stable Release", target: self, action: #selector(revertToStable))
            revertButton.bezelStyle = .automatic  // Modern, adaptive style
            updateButtonsStack.addArrangedSubview(revertButton)
        }
        
        rightStack.addArrangedSubview(updateButtonsStack)
        
        // Copyright - matches description text styling
        let copyrightLabel = NSTextField(labelWithString: "© Olive Design Studios 2025 All Rights Reserved.")
        copyrightLabel.font = NSFont.systemFont(ofSize: 11)
        copyrightLabel.textColor = .secondaryLabelColor
        copyrightLabel.alignment = .left
        rightStack.addArrangedSubview(copyrightLabel)
        
        topStack.addArrangedSubview(rightStack)
        
        mainStack.addArrangedSubview(topStack)
        
        // Separator
        mainStack.addArrangedSubview(createSpacer(height: 12))
        let separator1 = createFullWidthSeparator()
        mainStack.addArrangedSubview(separator1)
        mainStack.addArrangedSubview(createSpacer(height: 12))
        
        // Appearance section
        let appearanceLabel = NSTextField(labelWithString: "Appearance")
        if let roundedFont = NSFont.systemFont(ofSize: 15, weight: .semibold).rounded() {  // Consistent with other sections
            appearanceLabel.font = roundedFont
        } else {
            appearanceLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        }
        mainStack.addArrangedSubview(appearanceLabel)
        
        let appearanceControl = NSSegmentedControl(labels: ["Auto", "Light", "Dark"], trackingMode: .selectOne, target: self, action: #selector(appearanceChanged(_:)))
        appearanceControl.segmentStyle = .rounded
        appearanceControl.translatesAutoresizingMaskIntoConstraints = false
        
        // Set current selection based on saved preference
        let currentAppearance = UserDefaults.standard.string(forKey: "AppearanceMode") ?? "auto"
        switch currentAppearance {
        case "light": appearanceControl.selectedSegment = 1
        case "dark": appearanceControl.selectedSegment = 2
        default: appearanceControl.selectedSegment = 0 // auto
        }
        
        NSLayoutConstraint.activate([
            appearanceControl.widthAnchor.constraint(equalToConstant: 220)  // More compact
        ])
        mainStack.addArrangedSubview(appearanceControl)
        
        let appearanceDescription = NSTextField(wrappingLabelWithString: "Choose how Clnbrd looks. Auto follows your system appearance.")
        appearanceDescription.font = NSFont.systemFont(ofSize: 11)
        appearanceDescription.textColor = .secondaryLabelColor
        appearanceDescription.preferredMaxLayoutWidth = 480  // More compact
        appearanceDescription.alignment = .left
        mainStack.addArrangedSubview(appearanceDescription)
        
        mainStack.addArrangedSubview(createSpacer(height: 12))
        
        // Analytics section
        let analyticsCheckbox = NSButton(checkboxWithTitle: "Share my usage statistics", target: self, action: #selector(toggleAnalyticsInSettings))
        analyticsCheckbox.state = AnalyticsManager.shared.isAnalyticsEnabled() ? .on : .off
        mainStack.addArrangedSubview(analyticsCheckbox)
        
        let analyticsDescription = NSTextField(wrappingLabelWithString: "Help us improve Clnbrd by allowing us to collect completely anonymous usage data.")
        analyticsDescription.font = NSFont.systemFont(ofSize: 11)
        analyticsDescription.textColor = .secondaryLabelColor
        analyticsDescription.preferredMaxLayoutWidth = 480  // More compact
        analyticsDescription.alignment = .left
        mainStack.addArrangedSubview(analyticsDescription)
        
        // Launch at Login (removed - not needed in About tab per design)
        
        // Compact spacing
        mainStack.addArrangedSubview(createSpacer(height: 12))
        
        // Bottom section: Acknowledgments on left, buttons on right (same line)
        let bottomStack = NSStackView()
        bottomStack.orientation = .horizontal
        bottomStack.spacing = 12
        bottomStack.alignment = .centerY
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Acknowledgments link on left
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
            bottomSpacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 20)
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
        whatsNewButton.bezelStyle = .automatic  // Modern, adaptive style
        
        let websiteButton = NSButton(title: "Visit Website", target: self, action: #selector(openWebsite))
        websiteButton.bezelStyle = .automatic  // Modern, adaptive style
        
        let contactButton = NSButton(title: "Contact Us", target: self, action: #selector(contactUs))
        contactButton.bezelStyle = .automatic  // Modern, adaptive style
        
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
    
    private func setupHotkeySection(_ stackView: NSStackView) {
        stackView.addArrangedSubview(createSectionHeader("⌨️ Keyboard Shortcuts"))
        stackView.addArrangedSubview(createSpacer(height: 4))
        
        let descriptionLabel = NSTextField(labelWithString: "Click on a shortcut to change it. Press ⌫ to disable.")
        descriptionLabel.font = NSFont.systemFont(ofSize: 11)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.isEditable = false
        descriptionLabel.isBordered = false
        descriptionLabel.backgroundColor = .clear
        stackView.addArrangedSubview(descriptionLabel)
        
        stackView.addArrangedSubview(createSpacer(height: 8))
        
        // Clean & Paste hotkey
        let cleanPasteRow = createHotkeyRow(
            action: .cleanAndPaste,
            description: "Clean and Paste:",
            config: HotkeyManager.shared.getConfiguration(for: .cleanAndPaste)
        )
        stackView.addArrangedSubview(cleanPasteRow)
        
        // Show History hotkey
        let historyRow = createHotkeyRow(
            action: .showHistory,
            description: "Show Clipboard History:",
            config: HotkeyManager.shared.getConfiguration(for: .showHistory)
        )
        stackView.addArrangedSubview(historyRow)
        
        // Screenshot hotkey
        let screenshotRow = createHotkeyRow(
            action: .captureScreenshot,
            description: "Capture Screenshot:",
            config: HotkeyManager.shared.getConfiguration(for: .captureScreenshot)
        )
        stackView.addArrangedSubview(screenshotRow)
        
        stackView.addArrangedSubview(createSpacer(height: 8))
        
        // Reset button
        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetHotkeysToDefaults))
        resetButton.bezelStyle = .automatic
        resetButton.font = NSFont.systemFont(ofSize: 11)
        stackView.addArrangedSubview(resetButton)
        
        stackView.addArrangedSubview(createSpacer(height: 16))
    }
    
    private func setupBasicTextCleaningSection(_ stackView: NSStackView) {
        stackView.addArrangedSubview(createSectionHeaderWithControls("Basic Text Cleaning", selectAllSelector: #selector(selectAllBasic), deselectAllSelector: #selector(deselectAllBasic)))
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
        stackView.addArrangedSubview(createSectionHeaderWithControls("Advanced Cleaning", selectAllSelector: #selector(selectAllAdvanced), deselectAllSelector: #selector(deselectAllAdvanced)))
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
    
    private func setupClipboardSafetySection(_ stackView: NSStackView) {
        stackView.addArrangedSubview(createSpacer(height: 12))  // More compact
        stackView.addArrangedSubview(createSectionHeader("⚡ Performance & Safety"))
        stackView.addArrangedSubview(createSpacer(height: 4))
        
        let descriptionLabel = NSTextField(labelWithString: "Protect against large clipboard items (like InDesign objects) that can cause freezing")
        descriptionLabel.font = NSFont.systemFont(ofSize: 11)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.isEditable = false
        descriptionLabel.isBordered = false
        descriptionLabel.backgroundColor = .clear
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.preferredMaxLayoutWidth = 520
        stackView.addArrangedSubview(descriptionLabel)
        
        stackView.addArrangedSubview(createSpacer(height: 8))
        
        // Skip large items checkbox
        let skipLargeCheckbox = NSButton(checkboxWithTitle: "Skip processing large clipboard items", target: self, action: #selector(skipLargeItemsChanged(_:)))
        skipLargeCheckbox.state = PreferencesManager.shared.loadSkipLargeClipboardItems() ? .on : .off
        skipLargeCheckbox.toolTip = "When enabled, clipboard items larger than the size limit will be skipped to prevent freezing"
        stackView.addArrangedSubview(skipLargeCheckbox)
        
        stackView.addArrangedSubview(createSpacer(height: 12))
        
        // Max clipboard size slider
        let maxSizeContainer = createSliderSetting(
            label: "Max clipboard size:",
            minValue: 1,
            maxValue: 50,
            currentValue: Double(PreferencesManager.shared.loadMaxClipboardSize()),
            formatter: { value in "\(Int(value)) MB" },
            action: #selector(maxClipboardSizeChanged(_:))
        )
        stackView.addArrangedSubview(maxSizeContainer)
        
        stackView.addArrangedSubview(createSpacer(height: 8))
        
        // Timeout slider
        let timeoutContainer = createSliderSetting(
            label: "Processing timeout:",
            minValue: 1,
            maxValue: 10,
            currentValue: PreferencesManager.shared.loadClipboardTimeout(),
            formatter: { value in String(format: "%.1f sec", value) },
            action: #selector(clipboardTimeoutChanged(_:))
        )
        stackView.addArrangedSubview(timeoutContainer)
        
        let timeoutHelpLabel = NSTextField(labelWithString: "How long to wait before aborting slow clipboard operations")
        timeoutHelpLabel.font = NSFont.systemFont(ofSize: 10)
        timeoutHelpLabel.textColor = .tertiaryLabelColor
        timeoutHelpLabel.isEditable = false
        timeoutHelpLabel.isBordered = false
        timeoutHelpLabel.backgroundColor = .clear
        stackView.addArrangedSubview(timeoutHelpLabel)
    }
    
    // MARK: - UI Creation Helpers
    
    func createSectionHeader(_ title: String) -> NSView {
        let container = NSView()
        let label = NSTextField(labelWithString: title)
        // Use SF Pro Rounded for section headers
        if let roundedFont = NSFont.systemFont(ofSize: 14, weight: .semibold).rounded() {
            label.font = roundedFont
        } else {
            label.font = NSFont.boldSystemFont(ofSize: 14)
        }
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
        selectAllButton.bezelStyle = .automatic  // Modern, adaptive style
        selectAllButton.font = NSFont.systemFont(ofSize: 11)
        selectAllButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Deselect All button
        let deselectAllButton = NSButton(title: "Deselect All", target: self, action: deselectAllSelector)
        deselectAllButton.bezelStyle = .automatic  // Modern, adaptive style
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
    
    func createSliderSetting(label: String, minValue: Double, maxValue: Double, currentValue: Double, formatter: @escaping (Double) -> String, action: Selector) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Label
        let labelField = NSTextField(labelWithString: label)
        labelField.font = NSFont.systemFont(ofSize: 12)
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        // Slider
        let slider = NSSlider(value: currentValue, minValue: minValue, maxValue: maxValue, target: self, action: action)
        slider.translatesAutoresizingMaskIntoConstraints = false
        
        // Value label
        let valueLabel = NSTextField(labelWithString: formatter(currentValue))
        valueLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.alignment = .right
        valueLabel.identifier = NSUserInterfaceItemIdentifier("valueLabel_\(label)")
        
        container.addSubview(labelField)
        container.addSubview(slider)
        container.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            labelField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            slider.leadingAnchor.constraint(equalTo: labelField.trailingAnchor, constant: 12),
            slider.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            slider.widthAnchor.constraint(equalToConstant: 200),
            
            valueLabel.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 12),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 60),
            
            container.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        return container
    }
    
    func createHotkeyRow(action: HotkeyAction, description: String, config: HotkeyConfiguration) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Description label
        let labelField = NSTextField(labelWithString: description)
        labelField.font = NSFont.systemFont(ofSize: 12)
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        // Hotkey button (acts as recorder)
        let hotkeyButton = HotkeyRecorderButton()
        hotkeyButton.hotkeyAction = action
        hotkeyButton.configuration = config
        hotkeyButton.delegate = self
        hotkeyButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Enable/Disable checkbox - use tag to identify which action
        let enableCheckbox = NSButton(checkboxWithTitle: "Enabled", target: self, action: #selector(hotkeyEnabledChanged(_:)))
        enableCheckbox.state = config.isEnabled ? .on : .off
        // Use tag to identify: 0 = cleanAndPaste, 1 = showHistory, 2 = captureScreenshot
        switch action {
        case .cleanAndPaste:
            enableCheckbox.tag = 0
        case .showHistory:
            enableCheckbox.tag = 1
        case .captureScreenshot:
            enableCheckbox.tag = 2
        }
        enableCheckbox.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(labelField)
        container.addSubview(hotkeyButton)
        container.addSubview(enableCheckbox)
        
        NSLayoutConstraint.activate([
            labelField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelField.widthAnchor.constraint(equalToConstant: 140),  // Slightly more compact
            
            hotkeyButton.leadingAnchor.constraint(equalTo: labelField.trailingAnchor, constant: 8),  // Tighter spacing
            hotkeyButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            hotkeyButton.widthAnchor.constraint(equalToConstant: 140),  // Slightly more compact
            hotkeyButton.heightAnchor.constraint(equalToConstant: 22),  // Tighter height
            
            enableCheckbox.leadingAnchor.constraint(equalTo: hotkeyButton.trailingAnchor, constant: 8),  // Tighter spacing
            enableCheckbox.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            enableCheckbox.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 28)  // More compact row
        ])
        
        return container
    }
    
    func addCustomRuleRow(find: String, replace: String, index: Int) {
        let container = NSView()
        container.wantsLayer = true
        
        // Use modern material view for "liquid glass" effect
        let materialView = NSVisualEffectView(frame: container.bounds)
        materialView.autoresizingMask = [.width, .height]
        materialView.material = .contentBackground  // Adaptive to light/dark mode
        materialView.state = .active
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = 10  // Apple's 2024 standard
        materialView.layer?.masksToBounds = true
        
        // Add subtle shadow for depth
        materialView.layer?.shadowColor = NSColor.black.cgColor
        materialView.layer?.shadowOpacity = 0.08
        materialView.layer?.shadowOffset = NSSize(width: 0, height: 2)
        materialView.layer?.shadowRadius = 4
        
        container.addSubview(materialView, positioned: .below, relativeTo: nil)
        
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
    
    // MARK: - Clipboard Safety Settings Actions
    
    @objc func skipLargeItemsChanged(_ sender: NSButton) {
        let isEnabled = sender.state == .on
        PreferencesManager.shared.saveSkipLargeClipboardItems(isEnabled)
        
        // Reload clipboard manager settings
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.clipboardManager.reloadSafetySettings()
        }
        
        logger.info("Skip large clipboard items: \(isEnabled)")
    }
    
    @objc func maxClipboardSizeChanged(_ sender: NSSlider) {
        let sizeMB = Int(sender.doubleValue)
        PreferencesManager.shared.saveMaxClipboardSize(sizeMB)
        
        // Update the value label
        if let valueLabel = sender.superview?.subviews.first(where: { 
            $0.identifier?.rawValue == "valueLabel_Max clipboard size:" 
        }) as? NSTextField {
            valueLabel.stringValue = "\(sizeMB) MB"
        }
        
        // Reload clipboard manager settings
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.clipboardManager.reloadSafetySettings()
        }
        
        logger.info("Max clipboard size set to: \(sizeMB) MB")
    }
    
    @objc func clipboardTimeoutChanged(_ sender: NSSlider) {
        let timeout = sender.doubleValue
        PreferencesManager.shared.saveClipboardTimeout(timeout)
        
        // Update the value label
        if let valueLabel = sender.superview?.subviews.first(where: { 
            $0.identifier?.rawValue == "valueLabel_Processing timeout:" 
        }) as? NSTextField {
            valueLabel.stringValue = String(format: "%.1f sec", timeout)
        }
        
        // Reload clipboard manager settings
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.clipboardManager.reloadSafetySettings()
        }
        
        logger.info("Clipboard timeout set to: \(String(format: "%.1f", timeout)) seconds")
    }
    
    // MARK: - Hotkey Settings Actions
    
    @objc func hotkeyEnabledChanged(_ sender: NSButton) {
        // Map tag to action
        let action: HotkeyAction
        switch sender.tag {
        case 0:
            action = .cleanAndPaste
        case 1:
            action = .showHistory
        case 2:
            action = .captureScreenshot
        default:
            return
        }
        
        var config = HotkeyManager.shared.getConfiguration(for: action)
        config.isEnabled = sender.state == .on
        HotkeyManager.shared.updateConfiguration(for: action, config: config)
        
        // Reload hotkeys in menu bar manager
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.menuBarManager.reloadHotkeys()
        }
        
        logger.info("Hotkey \(action.rawValue) \(config.isEnabled ? "enabled" : "disabled")")
    }
    
    @objc func resetHotkeysToDefaults() {
        let alert = NSAlert()
        alert.messageText = "Reset Hotkeys to Defaults?"
        alert.informativeText = "This will reset all keyboard shortcuts to their default values."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            HotkeyManager.shared.resetToDefaults()
            
            // Reload hotkeys in the menu bar
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.menuBarManager.reloadHotkeys()
                
                // Force menu update after a slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    appDelegate.menuBarManager.updateMenuItemHotkeys()
                    logger.info("✅ Menu items updated after reset")
                }
            }
            
            // Update the hotkey buttons in the current view
            DispatchQueue.main.async { [weak self] in
                self?.updateHotkeyButtons()
            }
            
            logger.info("Hotkeys reset to defaults")
            
            // Show success message
            let successAlert = NSAlert()
            successAlert.messageText = "Hotkeys Reset"
            successAlert.informativeText = "All keyboard shortcuts have been reset to their default values:\n\n• Clean & Paste: ⌥⌘V\n• Show History: ⇧⌘H\n• Capture Screenshot: ⌥⌘C"
            successAlert.alertStyle = .informational
            successAlert.addButton(withTitle: "OK")
            successAlert.runModal()
        }
    }
    
    private func updateHotkeyButtons() {
        // Find all HotkeyRecorderButton instances in the view hierarchy and update them
        if let window = window, let contentView = window.contentView {
            updateHotkeyButtonsInView(contentView)
        }
    }
    
    private func updateHotkeyButtonsInView(_ view: NSView) {
        for subview in view.subviews {
            if let hotkeyButton = subview as? HotkeyRecorderButton,
               let action = hotkeyButton.hotkeyAction {
                // Update the button with the current configuration
                let config = HotkeyManager.shared.getConfiguration(for: action)
                hotkeyButton.configuration = config
                logger.debug("Updated hotkey button for \(action.rawValue)")
                
                // Also update the enabled checkbox in the same container
                if let container = hotkeyButton.superview {
                    for sibling in container.subviews {
                        if let checkbox = sibling as? NSButton, checkbox.cell is NSButtonCell {
                            // Map action to tag to update the correct checkbox
                            let expectedTag: Int
                            switch action {
                            case .cleanAndPaste:
                                expectedTag = 0
                            case .showHistory:
                                expectedTag = 1
                            case .captureScreenshot:
                                expectedTag = 2
                            }
                            
                            if checkbox.tag == expectedTag {
                                checkbox.state = config.isEnabled ? .on : .off
                                logger.debug("Updated checkbox state for \(action.rawValue): \(config.isEnabled)")
                            }
                        }
                    }
                }
            }
            // Recursively search subviews
            updateHotkeyButtonsInView(subview)
        }
    }
    
    @objc func openKeyboardShortcutsSettings() {
        // Open System Settings to Keyboard > Keyboard Shortcuts
        // URL scheme for macOS Ventura+ (13.0+)
        if #available(macOS 13.0, *) {
            // New System Settings app URL
            if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
                NSWorkspace.shared.open(url)
                logger.info("Opened System Settings > Keyboard Shortcuts")
            }
        } else {
            // Fallback for older macOS versions (System Preferences)
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts") {
                NSWorkspace.shared.open(url)
                logger.info("Opened System Preferences > Keyboard > Shortcuts")
            }
        }
        
        // Show a helpful message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let info = NSAlert()
            info.messageText = "System Keyboard Shortcuts Opened"
            info.informativeText = """
            Look for shortcuts that might conflict with Clnbrd:
            
            • Services > Screenshots (for screenshot shortcuts)
            • App Shortcuts (for app-specific shortcuts)
            • Mission Control, Spotlight, etc.
            
            You can disable conflicting shortcuts or change them in System Settings.
            """
            info.alertStyle = .informational
            info.addButton(withTitle: "OK")
            info.runModal()
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
        
        logger.info("NSApp.delegate type: \(type(of: NSApp.delegate))")
        
        if let appDelegate = NSApp.delegate as? AppDelegate {
            logger.info("✅ Successfully cast to AppDelegate, calling checkForUpdatesRequested")
            appDelegate.checkForUpdatesRequested()
        } else {
            logger.error("❌ Failed to cast NSApp.delegate to AppDelegate")
            
            // Try using Objective-C runtime as fallback
            if let delegate = NSApp.delegate {
                let selector = #selector(AppDelegate.checkForUpdatesRequested)
                if delegate.responds(to: selector) {
                    logger.info("✅ Delegate responds to checkForUpdatesRequested, calling via performSelector")
                    delegate.perform(selector)
                } else {
                    logger.error("❌ Delegate doesn't respond to checkForUpdatesRequested selector")
                }
            }
        }
    }
    
    @objc func revertToStable() {
        logger.info("Revert to Stable clicked from Settings About tab")
        SentryManager.shared.trackUserAction("settings_revert_to_stable")
        
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
        alert.messageText = "What's New in Clnbrd"
        alert.informativeText = """
        \(VersionManager.fullVersion)
        
        🎉 NEW: Clipboard History Manager
        — Store up to 100 clipboard items (text & images)
        — Quick access strip with ⌘⇧V hotkey
        — Search and filter by app or content
        — Screenshot capture with ⌘⌥C
        — Encrypted local storage for privacy
        — Image export (PNG, JPEG, TIFF)
        — Smart retention policies
        — Usage statistics
        
        ⚙️ Enhanced Settings
        — Redesigned Settings tab with list-based exclusions
        — Consolidated history options
        — New image compression & export settings
        — Improved layout and navigation
        
        🔄 Beta Release Features
        — Check for updates from About window
        — Roll back to stable release option
        — Enhanced update notifications
        
        v1.3 (Build 52)
        
        — Fully notarized for macOS Sequoia
        — Automatic "Move to Applications" prompt
        — Simplified menu bar interface
        — No security warnings on macOS 15.0+
        
        For full changelog, visit our website.
        """
        alert.alertStyle = .informational
        
        // Add checkbox for "Show changelog after each update"
        let checkbox = NSButton(checkboxWithTitle: "Show the changelog after each update", target: nil, action: nil)
        checkbox.state = UserDefaults.standard.bool(forKey: "ShowChangelogAfterUpdate") ? .on : .off
        alert.accessoryView = checkbox
        
        alert.addButton(withTitle: "Close")
        
        _ = alert.runModal()
        
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

// MARK: - NSTableView DataSource & Delegate
extension SettingsWindow: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return appExclusionsData.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("AppNameCell")
        
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier
            
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = .clear
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            cell?.addSubview(textField)
            cell?.textField = textField
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }
        
        cell?.textField?.stringValue = appExclusionsData[row]
        
        return cell
    }
}

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
        
        // Scroll to top when Settings tab is selected
        if tabViewItem.identifier as? String == "settings" {
            // Find the scroll view in the Settings tab
            if let tabView = tabViewItem.view,
               let scrollView = findScrollView(in: tabView) {
                DispatchQueue.main.async {
                    scrollView.documentView?.scroll(NSPoint(x: 0, y: scrollView.documentView?.bounds.height ?? 0))
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
            }
        }
        
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
    
    // Helper to find scroll view in view hierarchy
    private func findScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let scrollView = findScrollView(in: subview) {
                return scrollView
            }
        }
        return nil
    }
    
    // Helper to refresh the entire UI
    func refreshUI() {
        // Close and reopen the window with updated values
        window?.close()
        let newSettingsWindow = SettingsWindow(cleaningRules: cleaningRules)
        newSettingsWindow.showWindow(nil)
        
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.settingsWindowController = newSettingsWindow
        }
    }
}
// swiftlint:enable type_body_length

// MARK: - Hotkey Recorder Delegate
extension SettingsWindow: HotkeyRecorderButtonDelegate {
    func hotkeyRecorderDidChange(_ button: HotkeyRecorderButton, newConfig: HotkeyConfiguration) {
        // Check for conflicts with other Clnbrd hotkeys
        if let conflictingAction = HotkeyManager.shared.getConflictingAction(
            keyCode: newConfig.keyCode,
            modifiers: newConfig.modifiers,
            excluding: button.hotkeyAction
        ) {
            // Show conflict alert
            let alert = NSAlert()
            alert.messageText = "Hotkey Conflict"
            alert.informativeText = "This hotkey is already used by '\(conflictingAction)'. Please choose a different combination."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            
            // Reset button to previous config
            button.configuration = HotkeyManager.shared.getConfiguration(for: button.hotkeyAction)
            return
        }
        
        // Check for system shortcut conflicts
        if let systemConflict = HotkeyManager.shared.getSystemConflictWarning(
            keyCode: newConfig.keyCode,
            modifiers: newConfig.modifiers
        ) {
            // Show warning about system shortcut
            let alert = NSAlert()
            alert.messageText = "Possible System Shortcut Conflict"
            alert.informativeText = """
            This hotkey (\(newConfig.displayString)) is used by macOS for '\(systemConflict)'.
            
            It may also conflict with other apps that use this shortcut.
            
            If it doesn't work as expected, you can check all keyboard shortcuts in System Settings.
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Use Anyway")
            alert.addButton(withTitle: "Choose Different")
            alert.addButton(withTitle: "Open Keyboard Shortcuts...")
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                // User chose to pick a different hotkey
                button.configuration = HotkeyManager.shared.getConfiguration(for: button.hotkeyAction)
                return
            } else if response == .alertThirdButtonReturn {
                // Open System Settings to Keyboard Shortcuts
                openKeyboardShortcutsSettings()
                button.configuration = HotkeyManager.shared.getConfiguration(for: button.hotkeyAction)
                return
            }
        }
        
        // Update configuration
        HotkeyManager.shared.updateConfiguration(for: button.hotkeyAction, config: newConfig)
        
        // Reload hotkeys and update menu
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.menuBarManager.reloadHotkeys()
            
            // Force menu update with a slight delay to ensure it applies
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appDelegate.menuBarManager.updateMenuItemHotkeys()
                logger.info("✅ Menu items updated with new hotkey: \(newConfig.displayString)")
            }
        }
        
        logger.info("Hotkey updated for \(button.hotkeyAction.rawValue): \(newConfig.displayString)")
    }
}

// MARK: - Hotkey Recorder Button
protocol HotkeyRecorderButtonDelegate: AnyObject {
    func hotkeyRecorderDidChange(_ button: HotkeyRecorderButton, newConfig: HotkeyConfiguration)
}

class HotkeyRecorderButton: NSButton {
    var hotkeyAction: HotkeyAction!
    var configuration: HotkeyConfiguration! {
        didSet {
            // Update title on main thread to avoid layout issues
            DispatchQueue.main.async { [weak self] in
                self?.updateTitle()
            }
        }
    }
    weak var delegate: HotkeyRecorderButtonDelegate?
    
    private var isRecording = false
    private var eventMonitor: Any?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        bezelStyle = .roundRect
        target = self
        self.action = #selector(startRecording)
        
        // Set initial title without triggering layout
        title = "Click to set"
    }
    
    private func updateTitle() {
        let newTitle: String
        if isRecording {
            newTitle = "Press keys..."
        } else if configuration != nil {
            newTitle = configuration.displayString
        } else {
            newTitle = "Click to set"
        }
        
        // Only update if title actually changed to avoid unnecessary layout
        if title != newTitle {
            title = newTitle
        }
        
        if isRecording {
            highlight(true)
        } else {
            highlight(false)
        }
    }
    
    @objc private func startRecording() {
        isRecording = true
        updateTitle()
        
        // Monitor for key presses
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Delete key disables the hotkey
            if event.keyCode == 51 {  // Delete key
                self.stopRecording()
                var newConfig = self.configuration!
                newConfig.isEnabled = false
                self.configuration = newConfig
                self.delegate?.hotkeyRecorderDidChange(self, newConfig: newConfig)
                return nil
            }
            
            // ESC cancels recording
            if event.keyCode == 53 {  // Escape key
                self.stopRecording()
                return nil
            }
            
            // Require at least one modifier
            let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
            if modifiers.isEmpty {
                NSSound.beep()
                return nil
            }
            
            // Create new configuration
            var newConfig = self.configuration!
            newConfig.keyCode = event.keyCode
            newConfig.modifiers = HotkeyConfiguration.ModifierFlags(from: modifiers)
            newConfig.isEnabled = true
            
            self.configuration = newConfig
            self.stopRecording()
            self.delegate?.hotkeyRecorderDidChange(self, newConfig: newConfig)
            
            return nil
        }
    }
    
    private func stopRecording() {
        isRecording = false
        updateTitle()
        highlight(false)
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - NSFont Extension for SF Pro Rounded
extension NSFont {
    func rounded() -> NSFont? {
        // Try to get the rounded variant of the font
        let descriptor = self.fontDescriptor.withDesign(.rounded)
        return descriptor.flatMap { NSFont(descriptor: $0, size: self.pointSize) }
    }
}
