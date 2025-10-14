import Cocoa
import os.log
import UserNotifications

/// Floating window that displays clipboard history at the top of the screen
class ClipboardHistoryWindow: NSPanel {
    private let logger = Logger(subsystem: "com.allanalomes.Clnbrd", category: "ClipboardHistoryWindow")
    
    // UI Components
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var titleLabel: NSTextField!
    private var searchField: NSSearchField!
    private var appFilterPopup: NSPopUpButton!
    
    // State
    private var searchQuery: String = ""
    private var selectedAppFilters: Set<String> = [] // Apps to EXCLUDE/HIDE (empty = show all)
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private var selectedIndex: Int = 0 // Currently selected card index
    private var cardContainers: [NSView] = [] // Keep references to card containers
    
    // Performance optimization
    private var appIconCache: [String: NSImage] = [:] // Cache app icons
    private let maxDisplayedItems: Int = 50 // Limit displayed items for performance
    
    // Constants
    private let windowHeight: CGFloat = 220 // Increased to show full cards + timestamps below (120px card + 24px time + header + padding)
    private let cardWidth: CGFloat = 180
    private let cardHeight: CGFloat = 120
    private let padding: CGFloat = 16 // Reduced padding for better fit
    private var optionsButton: NSButton!
    
    init() {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let horizontalPadding: CGFloat = 20
        let topPadding: CGFloat = 12
        
        let windowFrame = NSRect(
            x: screenFrame.origin.x + horizontalPadding,
            y: screenFrame.maxY - windowHeight - topPadding,
            width: screenFrame.width - (horizontalPadding * 2),
            height: windowHeight
        )
        
        super.init(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupUI()
        observeHistoryChanges()
        
        logger.info("ClipboardHistoryWindow initialized")
    }
    
    private func setupWindow() {
        self.isFloatingPanel = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        
        guard let contentView = self.contentView else { return }
        let backdropBlur = NSVisualEffectView(frame: contentView.bounds)
        backdropBlur.autoresizingMask = [.width, .height]
        backdropBlur.material = .underWindowBackground
        backdropBlur.state = .active
        backdropBlur.blendingMode = .behindWindow
        backdropBlur.wantsLayer = true
        backdropBlur.layer?.cornerRadius = 14
        backdropBlur.layer?.masksToBounds = true
        backdropBlur.alphaValue = 0.7
        
        let visualEffect = NSVisualEffectView(frame: contentView.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .withinWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 14
        visualEffect.layer?.masksToBounds = false
        
        if let backdropLayer = backdropBlur.layer {
            backdropLayer.shadowColor = NSColor.black.cgColor
            backdropLayer.shadowOpacity = 0.25
            backdropLayer.shadowOffset = NSSize(width: 0, height: 8)
            backdropLayer.shadowRadius = 24
        }
        
        contentView.addSubview(backdropBlur, positioned: .below, relativeTo: nil)
        contentView.addSubview(visualEffect, positioned: .below, relativeTo: nil)
    }
    
    // swiftlint:disable:next function_body_length
    private func setupUI() {
        guard let contentView = self.contentView else { return }
        
        let containerView = NSView(frame: contentView.bounds)
        containerView.autoresizingMask = [.width, .height]
        contentView.addSubview(containerView)
        
        let headerHeight: CGFloat = 36
        let headerView = NSView(frame: NSRect(x: 0, y: windowHeight - headerHeight, width: contentView.bounds.width, height: headerHeight))
        headerView.autoresizingMask = [.width, .minYMargin]
        containerView.addSubview(headerView)
        
        // Title label (center-aligned like screenshot preview)
        titleLabel = NSTextField(labelWithString: "Clipboard History")
        // Use SF Pro Rounded for modern Apple UI aesthetic
        if let roundedFont = NSFont.systemFont(ofSize: 13, weight: .medium).rounded() {
            titleLabel.font = roundedFont
        } else {
            titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        }
        titleLabel.textColor = .labelColor // Adaptive color for light/dark mode
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 0, y: 8, width: contentView.bounds.width, height: 20)
        titleLabel.autoresizingMask = [.width]
        titleLabel.drawsBackground = false
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        headerView.addSubview(titleLabel)
        
        // Search field (positioned on left side of header)
        let searchFieldWidth: CGFloat = 180
        searchField = NSSearchField(frame: NSRect(x: 12, y: 6, width: searchFieldWidth, height: 24))
        searchField.placeholderString = "Search history..."
        searchField.font = NSFont.systemFont(ofSize: 12)
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)
        searchField.autoresizingMask = []
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        headerView.addSubview(searchField)
        
        // App filter popup (next to search field) - now with checkboxes
        let appFilterWidth: CGFloat = 140
        appFilterPopup = NSPopUpButton(frame: NSRect(x: 12 + searchFieldWidth + 8, y: 6, width: appFilterWidth, height: 24), pullsDown: false)
        appFilterPopup.font = NSFont.systemFont(ofSize: 12)
        appFilterPopup.autoresizingMask = []
        headerView.addSubview(appFilterPopup)
        
        // Populate app filter (will be updated when items load)
        updateAppFilter()
        
        // Settings gear icon in top right
        let settingsButton = NSButton(frame: NSRect(x: contentView.bounds.width - 76, y: 6, width: 28, height: 24))
        settingsButton.bezelStyle = .regularSquare
        settingsButton.isBordered = false
        settingsButton.setButtonType(.momentaryChange)
        settingsButton.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "Settings")
        settingsButton.contentTintColor = .labelColor // Adaptive for light/dark mode
        settingsButton.imageScaling = .scaleProportionallyDown
        settingsButton.target = self
        settingsButton.action = #selector(openHistorySettings)
        settingsButton.isEnabled = true
        settingsButton.autoresizingMask = [.minXMargin]
        settingsButton.toolTip = "Open History Settings"
        headerView.addSubview(settingsButton)
        
        // Options button (three dots) in top right - like screenshot preview
        optionsButton = NSButton(frame: NSRect(x: contentView.bounds.width - 44, y: 6, width: 28, height: 24))
        optionsButton.bezelStyle = .automatic // Modern, adaptive style
        optionsButton.image = NSImage(systemSymbolName: "ellipsis.circle.fill", accessibilityDescription: "Options")
        optionsButton.contentTintColor = .labelColor // Adaptive for light/dark mode
        optionsButton.isBordered = false
        optionsButton.target = self
        optionsButton.action = #selector(showOptionsMenu(_:))
        optionsButton.autoresizingMask = [.minXMargin]
        optionsButton.toolTip = "More Options"
        headerView.addSubview(optionsButton)
        
        // Scroll view setup - full width minus padding
        let scrollFrame = NSRect(x: padding, y: padding, width: contentView.bounds.width - 2 * padding, height: windowHeight - headerHeight - padding * 2)
        scrollView = NSScrollView(frame: scrollFrame)
        scrollView.hasHorizontalScroller = false // Hide scrollbar like screenshot preview
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.usesPredominantAxisScrolling = true
        containerView.addSubview(scrollView)
        
        // Stack view for history items
        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 24 // Increased spacing to prevent icon overlap (icon is 36px, half extends)
        stackView.alignment = .centerY
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create a container for the stack view
        let stackContainer = NSView()
        stackContainer.addSubview(stackView)
        scrollView.documentView = stackContainer
        
        // Pin stack view to container with height constraint
        // Height includes card + spacing + timestamp (120 + 6 + 18 = 144)
        let containerHeight: CGFloat = cardHeight + 6 + 18
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: stackContainer.leadingAnchor),
            stackView.topAnchor.constraint(equalTo: stackContainer.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: stackContainer.bottomAnchor),
            stackView.heightAnchor.constraint(equalToConstant: containerHeight)
        ])
        
        // Initial load
        reloadHistoryItems()
    }
    
    private func observeHistoryChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(historyDidChange),
            name: NSNotification.Name("ClipboardHistoryDidChange"),
            object: nil
        )
    }
    
    @objc private func historyDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.reloadHistoryItems()
        }
    }
    
    private func reloadHistoryItems() {
        // Remove all existing views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        cardContainers.removeAll()
        
        // Update app filter dropdown
        updateAppFilter()
        
        // Get items (filtered by app and search)
        let allItems = ClipboardHistoryManager.shared.items
        let filteredItems = filterItems(allItems)
        
        // Limit displayed items for performance (show most recent)
        let items = Array(filteredItems.prefix(maxDisplayedItems))
        
        // Update title with count
        if !searchQuery.isEmpty || !selectedAppFilters.isEmpty {
            if filteredItems.count > maxDisplayedItems {
                titleLabel.stringValue = "Results: \(items.count) of \(filteredItems.count) (showing \(maxDisplayedItems))"
            } else {
                titleLabel.stringValue = "Results: \(items.count) of \(allItems.count)"
            }
        } else {
            if filteredItems.count > maxDisplayedItems {
                titleLabel.stringValue = "Clipboard History (\(items.count) of \(filteredItems.count))"
            } else {
                titleLabel.stringValue = "Clipboard History (\(items.count))"
            }
        }
        
        if items.isEmpty {
            addEmptyStateView()
            return
        }
        
        // Container height includes card + spacing + timestamp
        let containerHeight: CGFloat = cardHeight + 6 + 18
        
        // Add card for each item
        for item in items {
            let cardContainer = createHistoryCard(for: item)
            // Ensure container has fixed width and height
            cardContainer.translatesAutoresizingMaskIntoConstraints = false
            cardContainer.widthAnchor.constraint(equalToConstant: cardWidth).isActive = true
            cardContainer.heightAnchor.constraint(equalToConstant: containerHeight).isActive = true
            stackView.addArrangedSubview(cardContainer)
            cardContainers.append(cardContainer)
        }
        
        // Update container frame to fit all cards horizontally
        if let container = scrollView.documentView {
            let contentWidth = CGFloat(items.count) * (cardWidth + 24) + 24 // Updated to match new spacing
            container.frame = NSRect(x: 0, y: 0, width: max(contentWidth, scrollView.bounds.width), height: containerHeight)
        }
        
        // Set initial selection to first card
        selectedIndex = 0
        updateSelection()
        
        logger.debug("Reloaded history with \(items.count) items")
    }
    
    private func addEmptyStateView() {
        // Create a container for the empty state
        let emptyContainer = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        
        // Add icon
        let iconView = NSImageView(frame: NSRect(x: 130, y: 50, width: 40, height: 40))
        let iconName: String
        if searchQuery.isEmpty && selectedAppFilters.isEmpty {
            iconName = "tray"
        } else {
            iconName = "magnifyingglass"
        }
        iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        iconView.contentTintColor = .tertiaryLabelColor
        iconView.imageScaling = .scaleProportionallyUpOrDown
        emptyContainer.addSubview(iconView)
        
        // Add message
        let message: String
        if searchQuery.isEmpty && selectedAppFilters.isEmpty {
            message = "No clipboard history yet\nCopy something to get started!"
        } else {
            message = "No results found\nTry adjusting your search or filters"
        }
        
        let emptyLabel = NSTextField(labelWithString: message)
        emptyLabel.font = NSFont.systemFont(ofSize: 12)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.frame = NSRect(x: 0, y: 10, width: 300, height: 40)
        emptyLabel.usesSingleLineMode = false
        emptyLabel.maximumNumberOfLines = 2
        emptyContainer.addSubview(emptyLabel)
        
        stackView.addArrangedSubview(emptyContainer)
    }
    
    // MARK: - Liquid Glass Card System
    
    /// Container for card visual effect layers
    private struct CardLayers {
        let backdropBlur: NSVisualEffectView
        let materialView: NSVisualEffectView
        let colorOverlay: CALayer
        let gradientLayer: CAGradientLayer
        let innerGlow: CAGradientLayer
    }
    
    /// Container for card shadow layers
    private struct CardShadows {
        let contactShadow: CALayer
        let accentShadow: CALayer
    }
    
    /// Container for card border layers
    private struct CardBorders {
        let borderLayer: CALayer
        let innerShadowLayer: CALayer
    }
    
    /// Creates all visual effect layers for a history card
    private func createCardLayers(cornerRadius: CGFloat, cardWidth: CGFloat, cardHeight: CGFloat) -> CardLayers {
        // Use bounds (0,0) for frames since these will be subviews
        let bounds = NSRect(x: 0, y: 0, width: cardWidth, height: cardHeight)
        
        let backdropBlur = NSVisualEffectView(frame: bounds)
        backdropBlur.material = .underWindowBackground
        backdropBlur.state = .active
        backdropBlur.blendingMode = .behindWindow
        backdropBlur.wantsLayer = true
        backdropBlur.layer?.cornerRadius = cornerRadius
        backdropBlur.layer?.masksToBounds = true
        backdropBlur.alphaValue = 0.5  // Lighter for performance
        // No autoresizingMask - fixed size cards
        
        let materialView = NSVisualEffectView(frame: bounds)
        materialView.material = .contentBackground
        materialView.state = .active
        materialView.blendingMode = .withinWindow
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = cornerRadius
        materialView.layer?.masksToBounds = true  // Clip for rounded corners
        // No autoresizingMask - fixed size cards
        
        let colorOverlay = CALayer()
        colorOverlay.frame = bounds
        colorOverlay.cornerRadius = cornerRadius
        colorOverlay.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.04).cgColor
        colorOverlay.opacity = 0
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        gradientLayer.colors = [
            NSColor.controlAccentColor.withAlphaComponent(0.06).cgColor,
            NSColor.controlAccentColor.withAlphaComponent(0.01).cgColor,
            NSColor.clear.cgColor
        ]
        gradientLayer.locations = [0.0, 0.2, 0.5]
        gradientLayer.cornerRadius = cornerRadius
        gradientLayer.opacity = 0
        
        let innerGlow = CAGradientLayer()
        innerGlow.frame = CGRect(x: 0, y: cardHeight - 2, width: cardWidth, height: 2)
        innerGlow.colors = [
            NSColor.white.withAlphaComponent(0.3).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ]
        innerGlow.locations = [0.0, 1.0]
        innerGlow.cornerRadius = cornerRadius
        innerGlow.opacity = 0
        
        return CardLayers(
            backdropBlur: backdropBlur,
            materialView: materialView,
            colorOverlay: colorOverlay,
            gradientLayer: gradientLayer,
            innerGlow: innerGlow
        )
    }
    
    /// Creates shadow layers for a history card
    private func createCardShadows(cardWidth: CGFloat, cardHeight: CGFloat, cornerRadius: CGFloat) -> CardShadows {
        let bounds = NSRect(x: 0, y: 0, width: cardWidth, height: cardHeight)
        
        let contactShadow = CALayer()
        contactShadow.frame = bounds
        contactShadow.cornerRadius = cornerRadius
        contactShadow.shadowColor = NSColor.black.cgColor
        contactShadow.shadowOpacity = 0.1
        contactShadow.shadowOffset = NSSize(width: 0, height: 2)
        contactShadow.shadowRadius = 4
        
        let accentShadow = CALayer()
        accentShadow.frame = bounds
        accentShadow.cornerRadius = cornerRadius
        accentShadow.shadowColor = NSColor.controlAccentColor.cgColor
        accentShadow.shadowOpacity = 0
        accentShadow.shadowOffset = .zero
        accentShadow.shadowRadius = 12
        
        return CardShadows(contactShadow: contactShadow, accentShadow: accentShadow)
    }
    
    /// Creates border layers for a history card
    private func createCardBorders(cardWidth: CGFloat, cardHeight: CGFloat, cornerRadius: CGFloat) -> CardBorders {
        let bounds = NSRect(x: 0, y: 0, width: cardWidth, height: cardHeight)
        
        let borderLayer = CALayer()
        borderLayer.frame = bounds
        borderLayer.cornerRadius = cornerRadius
        borderLayer.borderWidth = 0.5
        borderLayer.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        
        let innerShadowLayer = CALayer()
        innerShadowLayer.frame = bounds.insetBy(dx: 1, dy: 1)
        innerShadowLayer.cornerRadius = cornerRadius - 1
        innerShadowLayer.borderWidth = 0.5
        innerShadowLayer.borderColor = NSColor.black.withAlphaComponent(0.03).cgColor
        
        return CardBorders(borderLayer: borderLayer, innerShadowLayer: innerShadowLayer)
    }
    
    // swiftlint:disable:next function_body_length
    private func createHistoryCard(for item: ClipboardHistoryItem) -> NSView {
        // Container holds both card and timestamp below it
        let timeHeight: CGFloat = 18
        let spacing: CGFloat = 6
        let containerHeight = cardHeight + spacing + timeHeight
        let cornerRadius: CGFloat = 10
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: cardWidth, height: containerHeight))
        container.identifier = NSUserInterfaceItemIdentifier("container-\(item.id.uuidString)")
        container.wantsLayer = true
        container.layer?.masksToBounds = false // Allow icon to overflow the container bounds
        
        // Create premium liquid glass card with all layers
        let cardFrame = NSRect(x: 0, y: timeHeight + spacing, width: cardWidth, height: cardHeight)
        let cardContainer = NSView(frame: cardFrame)
        cardContainer.wantsLayer = true
        cardContainer.identifier = NSUserInterfaceItemIdentifier("card-\(item.id.uuidString)")
        
        // Create all liquid glass layers
        let layers = createCardLayers(cornerRadius: cornerRadius, cardWidth: cardWidth, cardHeight: cardHeight)
        let shadows = createCardShadows(cardWidth: cardWidth, cardHeight: cardHeight, cornerRadius: cornerRadius)
        let borders = createCardBorders(cardWidth: cardWidth, cardHeight: cardHeight, cornerRadius: cornerRadius)
        
        // Assemble the card with advanced shadow system
        cardContainer.shadow = NSShadow()
        cardContainer.layer?.shadowColor = NSColor.black.cgColor
        cardContainer.layer?.shadowOpacity = 0.08
        cardContainer.layer?.shadowOffset = NSSize(width: 0, height: 3)
        cardContainer.layer?.shadowRadius = 10
        
        // Add layers in order (back to front)
        cardContainer.addSubview(layers.backdropBlur)
        cardContainer.addSubview(layers.materialView)
        
        // Add overlay layers to material view
        if let materialLayer = layers.materialView.layer {
            materialLayer.insertSublayer(layers.colorOverlay, at: 0)
            materialLayer.insertSublayer(layers.gradientLayer, at: 1)
            materialLayer.addSublayer(layers.innerGlow)
            materialLayer.addSublayer(borders.borderLayer)
            materialLayer.addSublayer(borders.innerShadowLayer)
        }
        
        // Add shadow layers to container
        if let containerLayer = cardContainer.layer {
            containerLayer.insertSublayer(shadows.contactShadow, at: 0)
            containerLayer.insertSublayer(shadows.accentShadow, at: 0)
            
            // Add SEPARATE selection ring layer (won't conflict with hover)
            let selectionRing = CALayer()
            selectionRing.frame = NSRect(x: 0, y: 0, width: cardWidth, height: cardHeight)
            selectionRing.cornerRadius = cornerRadius
            selectionRing.borderWidth = 2.5
            selectionRing.borderColor = NSColor.clear.cgColor
            selectionRing.name = "selectionRing"  // Tag for finding later
            containerLayer.addSublayer(selectionRing)
        }
        
        // Make card clickable
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(cardClicked(_:)))
        cardContainer.addGestureRecognizer(clickGesture)
        
        // Create hover tracking view for premium effects (no autoresizing to avoid layout recursion)
        let hoverView = HistoryGlassCardView(frame: NSRect(x: 0, y: 0, width: cardWidth, height: cardHeight))
        hoverView.backdropBlur = layers.backdropBlur
        hoverView.materialView = layers.materialView
        hoverView.colorOverlay = layers.colorOverlay
        hoverView.gradientLayer = layers.gradientLayer
        hoverView.innerGlow = layers.innerGlow
        hoverView.borderLayer = borders.borderLayer
        hoverView.innerShadowLayer = borders.innerShadowLayer
        hoverView.containerLayer = cardContainer.layer
        hoverView.contactShadow = shadows.contactShadow
        hoverView.accentShadow = shadows.accentShadow
        hoverView.itemId = item.id.uuidString
        // No autoresizingMask - fixed size to prevent layout issues
        cardContainer.addSubview(hoverView, positioned: .below, relativeTo: layers.backdropBlur)
        
        // Add right-click context menu for images
        if item.contentType == .image || item.contentType == .mixed {
            let rightClickGesture = NSClickGestureRecognizer(target: self, action: #selector(cardRightClicked(_:)))
            rightClickGesture.buttonMask = 0x2 // Right mouse button
            cardContainer.addGestureRecognizer(rightClickGesture)
        }
        
        // Content area - show image or text based on content type
        if let thumbnail = item.thumbnail {
            // IMAGE CONTENT - Show thumbnail
            let imageView = NSImageView(frame: NSRect(x: 12, y: 12, width: cardWidth - 24, height: cardHeight - 24))
            imageView.image = thumbnail
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.imageAlignment = .alignCenter
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 4
            imageView.layer?.masksToBounds = true
            layers.materialView.addSubview(imageView)
            
            // If mixed content (text + image), show small text badge
            if item.contentType == .mixed, let plainText = item.plainText {
                let textBadge = NSTextField(labelWithString: plainText.prefix(30) + "...")
                textBadge.frame = NSRect(x: 8, y: 8, width: cardWidth - 16, height: 20)
                textBadge.font = NSFont.systemFont(ofSize: 9)
                textBadge.textColor = .white
                textBadge.alignment = .center
                textBadge.backgroundColor = NSColor.black.withAlphaComponent(0.6)
                textBadge.wantsLayer = true
                textBadge.layer?.cornerRadius = 4
                textBadge.layer?.masksToBounds = true
                layers.materialView.addSubview(textBadge)
            }
        } else {
            // TEXT CONTENT - Show formatted text
            let textLabel = NSTextField(frame: NSRect(x: 12, y: 12, width: cardWidth - 24, height: cardHeight - 24))
            
            // Try to load formatted text (RTF or HTML), fallback to plain text
            if let rtfData = item.rtfData,
               let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                // Use RTF formatted text (preserves ALL formatting)
                let mutableAttr = NSMutableAttributedString(attributedString: attributedString)
                
                // Scale down font slightly for preview if needed
                let range = NSRange(location: 0, length: mutableAttr.length)
                mutableAttr.enumerateAttribute(.font, in: range) { value, attrRange, _ in
                    if let font = value as? NSFont {
                        let scaledFont = NSFont(descriptor: font.fontDescriptor, size: max(font.pointSize * 0.85, 9))
                        mutableAttr.addAttribute(.font, value: scaledFont ?? font, range: attrRange)
                    }
                }
                
                textLabel.attributedStringValue = mutableAttr
            } else if let htmlData = item.htmlData,
                      let attributedString = NSAttributedString(html: htmlData, documentAttributes: nil) {
                // Use HTML formatted text
                textLabel.attributedStringValue = attributedString
            } else {
                // Fallback to plain text
                textLabel.stringValue = item.preview
                textLabel.font = NSFont.systemFont(ofSize: 11)
                textLabel.textColor = .labelColor
            }
            
            textLabel.lineBreakMode = .byWordWrapping
            textLabel.usesSingleLineMode = false
            textLabel.maximumNumberOfLines = 5 // More lines since we have more space
            textLabel.isEditable = false
            textLabel.isSelectable = false
            textLabel.isBordered = false
            textLabel.drawsBackground = false
            textLabel.cell?.wraps = true
            textLabel.cell?.isScrollable = false
            layers.materialView.addSubview(textLabel)
        }
        
        container.addSubview(cardContainer)
        
        // App icon badge (shows which app it was copied from)
        // Positioned to float over the bottom-right corner of the card
        if let sourceApp = item.sourceApp, !sourceApp.isEmpty {
            let appIconView = createAppIconBadge(for: sourceApp, cardYPosition: timeHeight + spacing)
            container.addSubview(appIconView)
        }
        
        // Timestamp BELOW the card (will change to "Copy" pill when selected)
        let timeLabel = NSTextField(labelWithString: item.displayTime)
        timeLabel.frame = NSRect(x: 0, y: 0, width: cardWidth, height: timeHeight)
        timeLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = .secondaryLabelColor // Adaptive color for light/dark mode
        timeLabel.alignment = .center
        timeLabel.isEditable = false
        timeLabel.isSelectable = false
        timeLabel.isBordered = false
        timeLabel.drawsBackground = false
        timeLabel.identifier = NSUserInterfaceItemIdentifier("time-\(item.id.uuidString)")
        container.addSubview(timeLabel)
        
        // "Copy" pill background (initially hidden)
        let pillWidth: CGFloat = 60
        let pillHeight: CGFloat = 20
        let pillBackground = NSView(frame: NSRect(
            x: (cardWidth - pillWidth) / 2,
            y: (timeHeight - pillHeight) / 2,
            width: pillWidth,
            height: pillHeight
        ))
        pillBackground.wantsLayer = true
        pillBackground.layer?.backgroundColor = NSColor.systemBlue.cgColor
        pillBackground.layer?.cornerRadius = pillHeight / 2 // Fully rounded ends (lozenge)
        pillBackground.isHidden = true // Hidden by default, shown when selected
        pillBackground.identifier = NSUserInterfaceItemIdentifier("pill-\(item.id.uuidString)")
        container.addSubview(pillBackground, positioned: .below, relativeTo: timeLabel)
        
        return container
    }
    
    @objc private func cardClicked(_ gesture: NSClickGestureRecognizer) {
        guard let card = gesture.view else { return }
        guard let idString = card.identifier?.rawValue else { return }
        
        // Extract UUID from "card-{uuid}" format
        let cardIdPrefix = "card-"
        guard idString.hasPrefix(cardIdPrefix) else { return }
        let uuidString = String(idString.dropFirst(cardIdPrefix.count))
        guard let itemId = UUID(uuidString: uuidString) else { return }
        
        // Find which index was clicked
        if let clickedIndex = cardContainers.firstIndex(where: { container in
            // Find card view by checking subviews
            return container.subviews.contains(where: { $0.identifier?.rawValue == idString })
        }) {
            selectedIndex = clickedIndex
            updateSelection()
        }
        
        // Find the item
        guard let item = ClipboardHistoryManager.shared.items.first(where: { $0.id == itemId }) else { return }
        
        // Restore to clipboard
        item.restoreToClipboard()
        
        logger.info("Restored clipboard item: \(item.preview)")
        
        // Track analytics
        AnalyticsManager.shared.trackFeatureUsage("clipboard_history_item_restored")
        
        // Show brief visual feedback
        animateCardSelection(card)
        
        // Close window after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.closeWindow()
        }
    }
    
    @objc private func cardRightClicked(_ gesture: NSClickGestureRecognizer) {
        guard let card = gesture.view else { return }
        guard let idString = card.identifier?.rawValue else { return }
        
        // Extract UUID from "card-{uuid}" format
        let cardIdPrefix = "card-"
        guard idString.hasPrefix(cardIdPrefix) else { return }
        let uuidString = String(idString.dropFirst(cardIdPrefix.count))
        guard let itemId = UUID(uuidString: uuidString) else { return }
        
        // Find the item
        guard let item = ClipboardHistoryManager.shared.items.first(where: { $0.id == itemId }) else { return }
        
        // Only show menu for images
        guard item.contentType == .image || item.contentType == .mixed else { return }
        
        // Show context menu
        showImageContextMenu(for: item, at: card)
    }
    
    private func showImageContextMenu(for item: ClipboardHistoryItem, at view: NSView) {
        let menu = NSMenu()
        
        // Save to Desktop
        let desktopItem = NSMenuItem(
            title: "Save to Desktop",
            action: #selector(saveImageToDesktop(_:)),
            keyEquivalent: ""
        )
        desktopItem.representedObject = item
        menu.addItem(desktopItem)
        
        // Save to Downloads
        let downloadsItem = NSMenuItem(
            title: "Save to Downloads",
            action: #selector(saveImageToDownloads(_:)),
            keyEquivalent: ""
        )
        downloadsItem.representedObject = item
        menu.addItem(downloadsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Save As...
        let saveAsItem = NSMenuItem(
            title: "Save As...",
            action: #selector(saveImageAs(_:)),
            keyEquivalent: ""
        )
        saveAsItem.representedObject = item
        menu.addItem(saveAsItem)
        
        // Show the menu
        menu.popUp(positioning: nil, at: view.bounds.origin, in: view)
    }
    
    @objc private func saveImageToDesktop(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardHistoryItem,
              let image = item.image else { return }
        
        do {
            let fileURL = try ImageExportUtility.saveToDesktop(image)
            logger.info("✅ Saved image to Desktop: \(fileURL.lastPathComponent)")
            
            // Show notification
            showNotification(title: "Image Saved", message: "Saved to Desktop: \(fileURL.lastPathComponent)")
            
            AnalyticsManager.shared.trackFeatureUsage("clipboard_history_save_desktop")
        } catch {
            logger.error("❌ Failed to save image to Desktop: \(error.localizedDescription)")
            showErrorAlert("Failed to save image to Desktop", message: error.localizedDescription)
        }
    }
    
    @objc private func saveImageToDownloads(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardHistoryItem,
              let image = item.image else { return }
        
        do {
            let fileURL = try ImageExportUtility.saveToDownloads(image)
            logger.info("✅ Saved image to Downloads: \(fileURL.lastPathComponent)")
            
            // Show notification
            showNotification(title: "Image Saved", message: "Saved to Downloads: \(fileURL.lastPathComponent)")
            
            AnalyticsManager.shared.trackFeatureUsage("clipboard_history_save_downloads")
        } catch {
            logger.error("❌ Failed to save image to Downloads: \(error.localizedDescription)")
            showErrorAlert("Failed to save image to Downloads", message: error.localizedDescription)
        }
    }
    
    @objc private func saveImageAs(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardHistoryItem,
              let image = item.image else { return }
        
        ImageExportUtility.showSavePanel(suggestedName: "Screenshot") { [weak self] url in
            guard let url = url else { return }
            
            do {
                try ImageExportUtility.exportImage(image, to: url)
                self?.logger.info("✅ Saved image to: \(url.lastPathComponent)")
                
                // Show notification
                self?.showNotification(title: "Image Saved", message: "Saved to: \(url.lastPathComponent)")
                
                AnalyticsManager.shared.trackFeatureUsage("clipboard_history_save_as")
            } catch {
                self?.logger.error("❌ Failed to save image: \(error.localizedDescription)")
                self?.showErrorAlert("Failed to save image", message: error.localizedDescription)
            }
        }
    }
    
    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = nil
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to show notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func showErrorAlert(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func updateSelection() {
        guard !cardContainers.isEmpty else { return }
        guard selectedIndex >= 0 && selectedIndex < cardContainers.count else { return }
        
        // Update all cards
        for (index, container) in cardContainers.enumerated() {
            // Find card, timeLabel, and pill by checking subviews
            var card: NSView?
            var timeLabel: NSTextField?
            var pill: NSView?
            
            for subview in container.subviews {
                if subview.identifier?.rawValue.hasPrefix("card-") == true {
                    card = subview
                } else if subview.identifier?.rawValue.hasPrefix("time-") == true {
                    timeLabel = subview as? NSTextField
                } else if subview.identifier?.rawValue.hasPrefix("pill-") == true {
                    pill = subview
                }
            }
            
            guard let cardView = card, let timeLabelView = timeLabel, let pillView = pill else { continue }
            
            let isSelected = (index == selectedIndex)
            
            // Find the dedicated selection ring layer
            var selectionRing: CALayer?
            if let containerLayer = cardView.layer, let sublayers = containerLayer.sublayers {
                for sublayer in sublayers where sublayer.name == "selectionRing" {
                    selectionRing = sublayer
                    break
                }
            }
            
            // Animate selection state with premium liquid glass effects
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                
                if isSelected {
                    // Premium selection state: glowing ring
                    selectionRing?.borderColor = NSColor.controlAccentColor.cgColor
                    selectionRing?.opacity = 1.0
                    
                    // Add subtle selection glow via shadow on the ring
                    selectionRing?.shadowColor = NSColor.controlAccentColor.cgColor
                    selectionRing?.shadowOpacity = 0.5
                    selectionRing?.shadowRadius = 8
                    selectionRing?.shadowOffset = .zero
                } else {
                    // Hide selection ring
                    selectionRing?.borderColor = NSColor.clear.cgColor
                    selectionRing?.opacity = 0
                    selectionRing?.shadowOpacity = 0
                }
                
                // Update pill visibility with animation
                pillView.animator().alphaValue = isSelected ? 1.0 : 0.0
            })
            
            // Update timestamp text and pill visibility
            if isSelected {
                // Show "Copy" in white text on blue pill
                timeLabelView.stringValue = "Copy"
                timeLabelView.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
                timeLabelView.textColor = .white // White text on blue pill
                pillView.isHidden = false // Show blue pill background
            } else {
                // Show timestamp with adaptive color, no pill
                if index < ClipboardHistoryManager.shared.items.count {
                    let item = ClipboardHistoryManager.shared.items[index]
                    timeLabelView.stringValue = item.displayTime
                    timeLabelView.font = NSFont.systemFont(ofSize: 11, weight: .regular)
                    timeLabelView.textColor = .secondaryLabelColor // Adaptive for light/dark mode
                    pillView.isHidden = true // Hide pill
                }
            }
        }
        
        // Scroll selected card into view
        if selectedIndex < cardContainers.count {
            let container = cardContainers[selectedIndex]
            scrollView.contentView.scrollToVisible(container.frame)
        }
    }
    
    private func animateCardSelection(_ card: NSView) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            card.layer?.borderColor = NSColor.controlAccentColor.cgColor
            card.layer?.borderWidth = 2
        }, completionHandler: nil)
    }
    
    @objc private func showOptionsMenu(_ sender: NSButton) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // Retention period options
        menu.addItem(NSMenuItem(title: "Delete History After:", action: nil, keyEquivalent: ""))
        menu.items.last?.isEnabled = false
        
        menu.addItem(NSMenuItem.separator())
        
        for period in ClipboardHistoryManager.RetentionPeriod.allCases {
            let item = NSMenuItem(title: period.rawValue, action: #selector(setRetentionPeriod(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = period
            item.state = (ClipboardHistoryManager.shared.retentionPeriod == period) ? .on : .off
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Clear history option
        let clearItem = NSMenuItem(title: "Clear All History...", action: #selector(clearHistoryFromMenu), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        
        // Show menu below the button
        let location = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: location, in: sender)
    }
    
    @objc private func setRetentionPeriod(_ sender: NSMenuItem) {
        guard let period = sender.representedObject as? ClipboardHistoryManager.RetentionPeriod else { return }
        ClipboardHistoryManager.shared.retentionPeriod = period
        logger.info("Retention period changed to: \(period.rawValue)")
    }
    
    @objc private func clearHistoryFromMenu() {
        ClipboardHistoryManager.shared.clearHistory()
        reloadHistoryItems()
        logger.info("History cleared from menu")
    }
    
    @objc private func openHistorySettings() {
        logger.info("⚙️ Settings button clicked!")
        
        // Get AppDelegate reference using runtime lookup
        guard let delegate = NSApp.delegate else {
            logger.error("❌ No app delegate found!")
            closeWindow()
            return
        }
        
        logger.info("📋 Delegate type: \(type(of: delegate))")
        logger.info("📋 Delegate class: \(String(describing: object_getClass(delegate)))")
        
        // Try to call openSettingsToTab using performSelector
        let selector = #selector(AppDelegate.openSettingsToTab(_:))
        if delegate.responds(to: selector) {
            logger.info("✅ Delegate responds to openSettingsToTab, calling it...")
            closeWindow()
            _ = delegate.perform(selector, with: NSNumber(value: 1))  // Tab 1 = History tab (wrapped in NSNumber)
            AnalyticsManager.shared.trackFeatureUsage("history_settings_opened_from_strip")
        } else {
            logger.error("❌ Delegate does not respond to openSettingsToTab")
            closeWindow()
        }
    }
    
    // MARK: - Search & Filter
    
    @objc private func searchFieldChanged() {
        let query = searchField.stringValue
        searchQuery = query
        logger.debug("🔍 Search query: '\(query)'")
        reloadHistoryItems()
        AnalyticsManager.shared.trackFeatureUsage("clipboard_history_search")
    }
    
    @objc private func appFilterChanged(_ sender: NSMenuItem) {
        let appName = sender.title
        
        // selectedAppFilters contains apps to EXCLUDE/HIDE
        // Empty = show all apps
        // Toggle the app's visibility
        
        if selectedAppFilters.contains(appName) {
            // Currently hidden (unchecked), so show it (check it)
            selectedAppFilters.remove(appName)
        } else {
            // Currently shown (checked), so hide it (uncheck it)
            selectedAppFilters.insert(appName)
        }
        
        // Update popup title to show selection count
        updateAppFilterTitle()
        updateAppFilter() // Refresh checkmarks
        
        let allItems = ClipboardHistoryManager.shared.items
        let totalApps = Set(allItems.compactMap { $0.sourceApp }).count
        let visibleApps = totalApps - selectedAppFilters.count
        logger.debug("🎯 Visible apps: \(visibleApps) / \(totalApps)")
        reloadHistoryItems()
        AnalyticsManager.shared.trackFeatureUsage("clipboard_history_app_filter")
    }
    
    private func updateAppFilterTitle() {
        let allItems = ClipboardHistoryManager.shared.items
        let totalApps = Set(allItems.compactMap { $0.sourceApp }).count
        let visibleApps = totalApps - selectedAppFilters.count
        
        if selectedAppFilters.isEmpty {
            // No apps hidden, showing all
            appFilterPopup.setTitle("All Apps")
        } else if visibleApps == 1 {
            // Only one app visible, show its name
            let allApps = Set(allItems.compactMap { $0.sourceApp })
            let visibleApp = allApps.subtracting(selectedAppFilters).first!
            appFilterPopup.setTitle(visibleApp)
        } else {
            // Show count of visible apps
            appFilterPopup.setTitle("\(visibleApps) Apps")
        }
    }
    
    private func updateAppFilter() {
        // Create menu
        let menu = NSMenu()
        
        // Get unique apps from history
        let allItems = ClipboardHistoryManager.shared.items
        let uniqueApps = Set(allItems.compactMap { $0.sourceApp }).sorted()
        
        // Add "All Apps" option with checkmark when all selected
        let allAppsItem = NSMenuItem(title: "All Apps", action: #selector(selectAllApps), keyEquivalent: "")
        allAppsItem.target = self
        let allAppsIcon = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "All Apps")
        allAppsIcon?.isTemplate = true
        allAppsItem.image = allAppsIcon
        // Check "All Apps" if no specific filters are selected (showing all)
        allAppsItem.state = selectedAppFilters.isEmpty ? .on : .off
        menu.addItem(allAppsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        if !uniqueApps.isEmpty {
            for appName in uniqueApps {
                let menuItem = NSMenuItem(title: appName, action: #selector(appFilterChanged(_:)), keyEquivalent: "")
                menuItem.target = self
                
                // Set checkbox state
                // selectedAppFilters contains apps to HIDE
                // Checked = app is visible, Unchecked = app is hidden
                let isVisible = !selectedAppFilters.contains(appName)
                
                // Always show a checkbox - either checked or unchecked
                if isVisible {
                    // Show filled checkbox with checkmark
                    let checkedBox = NSImage(systemSymbolName: "checkmark.square.fill", accessibilityDescription: "Visible")
                    checkedBox?.isTemplate = true
                    menuItem.image = checkedBox
                } else {
                    // Show empty square box
                    let uncheckedBox = NSImage(systemSymbolName: "square", accessibilityDescription: "Hidden")
                    uncheckedBox?.isTemplate = true
                    menuItem.image = uncheckedBox
                }
                
                // Don't use the built-in state indicator
                menuItem.state = .off
                
                menu.addItem(menuItem)
            }
        }
        
        appFilterPopup.menu = menu
        updateAppFilterTitle()
    }
    
    @objc private func selectAllApps() {
        // Clear all filters to show all apps
        selectedAppFilters.removeAll()
        updateAppFilter()
        reloadHistoryItems()
        logger.debug("🎯 Selected all apps (cleared filters)")
        AnalyticsManager.shared.trackFeatureUsage("clipboard_history_select_all_apps")
    }
    
    @objc private func clearAppFilters() {
        selectedAppFilters.removeAll()
        updateAppFilter()
        reloadHistoryItems()
    }
    
    private func filterItems(_ items: [ClipboardHistoryItem]) -> [ClipboardHistoryItem] {
        var filteredItems = items
        
        // Apply app filters - selectedAppFilters contains apps to HIDE/EXCLUDE
        // Empty = show all, Otherwise = hide those in the set
        if !selectedAppFilters.isEmpty {
            filteredItems = filteredItems.filter { item in
                guard let sourceApp = item.sourceApp else { return true }
                // Show item only if its app is NOT in the excluded set
                return !selectedAppFilters.contains(sourceApp)
            }
        }
        
        // Apply search query
        guard !searchQuery.isEmpty else {
            return filteredItems
        }
        
        let lowercasedQuery = searchQuery.lowercased()
        return filteredItems.filter { item in
            // Search in plain text
            if let plainText = item.plainText,
               plainText.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            // Search in RTF text (extract plain text first)
            if let rtfData = item.rtfData,
               let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                if attributedString.string.lowercased().contains(lowercasedQuery) {
                    return true
                }
            }
            
            // Search in HTML text (extract plain text first)
            if let htmlData = item.htmlData,
               let attributedString = try? NSAttributedString(
                data: htmlData,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil
               ) {
                if attributedString.string.lowercased().contains(lowercasedQuery) {
                    return true
                }
            }
            
            // Search in source app name
            if let sourceApp = item.sourceApp,
               sourceApp.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            return false
        }
    }
    
    private func clearSearch() {
        searchField.stringValue = ""
        searchQuery = ""
        reloadHistoryItems()
        logger.debug("🔍 Search cleared")
    }
    
    private func clearFilters() {
        searchField.stringValue = ""
        searchQuery = ""
        selectedAppFilters.removeAll()
        updateAppFilter() // Refresh menu and title
        reloadHistoryItems()
        logger.debug("🔍 All filters cleared")
    }
    
    private func closeWindow() {
        logger.debug("Closing history window")
        
        // Stop monitoring for clicks outside
        stopClickOutsideMonitor()
        
        // Animate window disappearance
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1.0 // Reset for next show
        })
        
        // Track analytics
        AnalyticsManager.shared.trackFeatureUsage("clipboard_history_window_closed")
    }
    
    private func startClickOutsideMonitor() {
        // Monitor for clicks within the app (local monitor)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            
            // Check if the click is on a UI control (button, etc.) inside our window
            if let clickedView = event.window?.contentView?.hitTest(event.locationInWindow) {
                // If it's a control (button, text field, etc.), don't close - let it handle the click
                if clickedView is NSControl {
                    return event // Let the control handle it, don't close
                }
            }
            
            // Get the click location in screen coordinates
            let clickLocation = NSEvent.mouseLocation
            let windowFrame = self.frame
            
            // Check if click is outside our window
            if !windowFrame.contains(clickLocation) {
                // Click is outside our window but inside the app, close
                self.closeWindow()
                return event // Don't consume - let it pass through
            }
            
            return event
        }
        
        // Monitor for clicks outside the app (global monitor)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            
            // Any click outside the app should close the window
            self.closeWindow()
        }
    }
    
    private func stopClickOutsideMonitor() {
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
        
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
    
    private func createAppIconBadge(for appName: String, cardYPosition: CGFloat) -> NSImageView {
        let iconSize: CGFloat = 36 // Size for the badge
        
        // Create image view - CENTERED on bottom-right corner of the card
        // Half inside card, half outside (floating over the corner)
        let imageView = NSImageView(frame: NSRect(
            x: cardWidth - (iconSize / 2),        // Centered on right edge (half outside)
            y: cardYPosition - (iconSize / 2),    // Centered on bottom edge (half below)
            width: iconSize,
            height: iconSize
        ))
        
        // Get app icon from NSWorkspace
        if let appIcon = getAppIcon(for: appName) {
            imageView.image = appIcon
        } else {
            // Fallback to generic document icon
            imageView.image = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: "Document")
            imageView.contentTintColor = .systemGray
        }
        
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        
        // NO background - just the icon itself like macOS screenshot badges
        // Add subtle shadow for depth so icon stands out
        imageView.layer?.shadowColor = NSColor.black.cgColor
        imageView.layer?.shadowOpacity = 0.5
        imageView.layer?.shadowOffset = NSSize(width: 0, height: 1)
        imageView.layer?.shadowRadius = 4
        
        return imageView
    }
    
    private func getAppIcon(for appName: String) -> NSImage? {
        // Check cache first
        if let cachedIcon = appIconCache[appName] {
            return cachedIcon
        }
        
        let workspace = NSWorkspace.shared
        var icon: NSImage?
        
        // Try to find running app by name
        if let app = workspace.runningApplications.first(where: { app in
            app.localizedName == appName ||
            app.bundleIdentifier?.contains(appName.lowercased()) == true
        }) {
            icon = app.icon
        }
        
        // Try to find app by bundle identifier or path
        if icon == nil, let appURL = workspace.urlForApplication(withBundleIdentifier: appName) {
            icon = workspace.icon(forFile: appURL.path)
        }
        
        // Try common app paths
        if icon == nil {
            let appPaths = [
                "/Applications/\(appName).app",
                "/System/Applications/\(appName).app",
                "/Applications/Utilities/\(appName).app"
            ]
        
            for path in appPaths where FileManager.default.fileExists(atPath: path) {
                icon = workspace.icon(forFile: path)
                break
            }
        }
        
        // Cache the icon if found
        if let icon = icon {
            appIconCache[appName] = icon
        }
        
        return icon
    }
    
    func toggle() {
        if self.isVisible {
            closeWindow()
        } else {
            show()
        }
    }
    
    override var canBecomeKey: Bool {
        return true // Allow window to receive keyboard events
    }
    
    func show() {
        // Reload items before showing
        reloadHistoryItems()
        
        // Position at top of current screen - with padding for floating appearance
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame // visibleFrame excludes menu bar
            let horizontalPadding: CGFloat = 20 // Inset from screen edges for floating look
            let topPadding: CGFloat = 12 // Space below menu bar
            
            let windowFrame = NSRect(
                x: screenFrame.origin.x + horizontalPadding,
                y: screenFrame.maxY - windowHeight - topPadding, // Just below menu bar with gap
                width: screenFrame.width - (horizontalPadding * 2), // Inset from both sides
                height: windowHeight
            )
            self.setFrame(windowFrame, display: true)
        }
        
        // Animate window appearance
        self.alphaValue = 0
        self.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        })
        
        logger.info("Showing history window with \(ClipboardHistoryManager.shared.items.count) items")
        
        // Start monitoring for clicks outside
        startClickOutsideMonitor()
        
        // Track analytics
        AnalyticsManager.shared.trackFeatureUsage("clipboard_history_window_opened")
    }
    
    override func keyDown(with event: NSEvent) {
        // Check for ⌘F to focus search
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "f" {
            self.makeFirstResponder(searchField)
            return
        }
        
        switch event.keyCode {
        case 53: // Escape key
            // If any filters are active, clear them first, otherwise close window
            if !searchQuery.isEmpty || !selectedAppFilters.isEmpty {
                clearFilters()
            } else {
                closeWindow()
            }
            
        case 123: // Left arrow
            if selectedIndex > 0 {
                selectedIndex -= 1
                updateSelection()
            }
            
        case 124: // Right arrow
            let allItems = ClipboardHistoryManager.shared.items
            let filteredItems = filterItems(allItems)
            if selectedIndex < filteredItems.count - 1 {
                selectedIndex += 1
                updateSelection()
            }
            
        case 36, 76: // Return or Enter - copy selected item
            let allItems = ClipboardHistoryManager.shared.items
            let filteredItems = filterItems(allItems)
            if selectedIndex < filteredItems.count {
                let item = filteredItems[selectedIndex]
                item.restoreToClipboard()
                logger.info("Restored clipboard item via keyboard: \(item.preview)")
                AnalyticsManager.shared.trackFeatureUsage("clipboard_history_item_restored_keyboard")
                closeWindow()
            }
            
        default:
            super.keyDown(with: event)
        }
    }
}

// MARK: - History Glass Card View (Performance-Optimized)

/// Performance-optimized liquid glass card view for history items
class HistoryGlassCardView: NSView {
    weak var backdropBlur: NSVisualEffectView?
    weak var materialView: NSVisualEffectView?
    weak var colorOverlay: CALayer?
    weak var gradientLayer: CAGradientLayer?
    weak var innerGlow: CAGradientLayer?
    weak var borderLayer: CALayer?
    weak var innerShadowLayer: CALayer?
    weak var containerLayer: CALayer?
    weak var contactShadow: CALayer?
    weak var accentShadow: CALayer?
    
    var itemId: String = ""
    private var trackingArea: NSTrackingArea?
    private var hasSetupTracking = false
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Setup tracking when added to window (avoids layout recursion)
        if window != nil && !hasSetupTracking {
            setupTrackingArea()
            hasSetupTracking = true
        }
    }
    
    private func setupTrackingArea() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["itemId": itemId]
        )
        
        if let area = trackingArea {
            addTrackingArea(area)
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // Only update if already setup (avoids recursion during initial layout)
        if hasSetupTracking {
            setupTrackingArea()
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        animateGlassHoverIn()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        animateGlassHoverOut()
    }
    
    /// Premium hover-in animation (optimized for performance)
    private func animateGlassHoverIn() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            
            // Subtle lift and scale - only transform the container, not borders
            self.containerLayer?.transform = CATransform3DMakeScale(1.03, 1.03, 1.0)
            
            // Intensify blur
            self.backdropBlur?.animator().alphaValue = 0.7
            
            // Reveal overlays
            self.colorOverlay?.opacity = 1.0
            self.gradientLayer?.opacity = 1.0
            self.innerGlow?.opacity = 0.8
            
            // Enhance shadows
            self.containerLayer?.shadowOpacity = 0.15
            self.containerLayer?.shadowRadius = 16
            self.containerLayer?.shadowOffset = NSSize(width: 0, height: 6)
            
            self.contactShadow?.shadowOpacity = 0.15
            self.contactShadow?.shadowRadius = 6
            
            // Subtle accent glow on hover (not too much)
            self.accentShadow?.shadowOpacity = 0.08
        })
    }
    
    /// Smooth hover-out animation
    private func animateGlassHoverOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            
            // Return to normal
            self.containerLayer?.transform = CATransform3DIdentity
            
            // Restore blur
            self.backdropBlur?.animator().alphaValue = 0.5
            
            // Hide overlays
            self.colorOverlay?.opacity = 0
            self.gradientLayer?.opacity = 0
            self.innerGlow?.opacity = 0
            
            // Restore shadows
            self.containerLayer?.shadowOpacity = 0.08
            self.containerLayer?.shadowRadius = 10
            self.containerLayer?.shadowOffset = NSSize(width: 0, height: 3)
            
            self.contactShadow?.shadowOpacity = 0.1
            self.contactShadow?.shadowRadius = 4
            
            self.accentShadow?.shadowOpacity = 0
        })
    }
}

// MARK: - NSColor Extension
extension NSColor {
    var highlighted: NSColor {
        return self.blended(withFraction: 0.1, of: .controlAccentColor) ?? self
    }
}
