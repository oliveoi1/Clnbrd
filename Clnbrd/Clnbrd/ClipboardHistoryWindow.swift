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
    
    // State
    private var searchQuery: String = ""
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private var selectedIndex: Int = 0 // Currently selected card index
    private var cardContainers: [NSView] = [] // Keep references to card containers
    
    // Constants
    private let windowHeight: CGFloat = 220 // Increased to show full cards + timestamps below (120px card + 24px time + header + padding)
    private let cardWidth: CGFloat = 180
    private let cardHeight: CGFloat = 120
    private let padding: CGFloat = 16 // Reduced padding for better fit
    private var optionsButton: NSButton!
    
    init() {
        // Create window at top of screen - with padding for floating appearance
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero // visibleFrame excludes menu bar
        let horizontalPadding: CGFloat = 20 // Inset from screen edges for floating look
        let topPadding: CGFloat = 12 // Space below menu bar
        
        let windowFrame = NSRect(
            x: screenFrame.origin.x + horizontalPadding,
            y: screenFrame.maxY - windowHeight - topPadding, // Just below menu bar with gap
            width: screenFrame.width - (horizontalPadding * 2), // Inset from both sides
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
        // Window properties - like macOS screenshot preview
        self.isFloatingPanel = true
        self.level = .statusBar // Higher level like screenshot preview
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = false // Fixed at top
        self.backgroundColor = .clear // Clear for visual effect view
        self.isOpaque = false
        self.hasShadow = true
        
        // Add visual effect view for proper translucent grey background
        guard let contentView = self.contentView else { return }
        
        let visualEffect = NSVisualEffectView(frame: contentView.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow // Dark grey translucent material
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16 // Rounded on all sides for floating appearance
        visualEffect.layer?.masksToBounds = true
        
        // Insert as bottom-most view
        contentView.addSubview(visualEffect, positioned: .below, relativeTo: nil)
    }
    
    private func setupUI() {
        guard let contentView = self.contentView else { return }
        
        // Main container
        let containerView = NSView(frame: contentView.bounds)
        containerView.autoresizingMask = [.width, .height]
        contentView.addSubview(containerView)
        
        // Header view with title and options button
        let headerHeight: CGFloat = 36
        let headerView = NSView(frame: NSRect(x: 0, y: windowHeight - headerHeight, width: contentView.bounds.width, height: headerHeight))
        headerView.autoresizingMask = [.width, .minYMargin]
        containerView.addSubview(headerView)
        
        // Title label (center-aligned like screenshot preview)
        titleLabel = NSTextField(labelWithString: "Clipboard History")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .white // White text on dark grey HUD
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 0, y: 8, width: contentView.bounds.width, height: 20)
        titleLabel.autoresizingMask = [.width]
        titleLabel.drawsBackground = false
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        headerView.addSubview(titleLabel)
        
        // Settings gear icon in top right
        let settingsButton = NSButton(frame: NSRect(x: contentView.bounds.width - 76, y: 6, width: 28, height: 24))
        settingsButton.bezelStyle = .regularSquare
        settingsButton.isBordered = false
        settingsButton.setButtonType(.momentaryChange)
        settingsButton.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "Settings")
        settingsButton.contentTintColor = .white
        settingsButton.imageScaling = .scaleProportionallyDown
        settingsButton.target = self
        settingsButton.action = #selector(openHistorySettings)
        settingsButton.isEnabled = true
        settingsButton.autoresizingMask = [.minXMargin]
        settingsButton.wantsLayer = true
        
        // Add visible border temporarily for debugging
        settingsButton.layer?.borderColor = NSColor.yellow.cgColor
        settingsButton.layer?.borderWidth = 2
        
        headerView.addSubview(settingsButton)
        
        logger.debug("Settings button created: frame=\(NSStringFromRect(settingsButton.frame)), enabled=\(settingsButton.isEnabled), target=\(String(describing: settingsButton.target)), action=\(String(describing: settingsButton.action))")
        
        // Options button (three dots) in top right - like screenshot preview
        optionsButton = NSButton(frame: NSRect(x: contentView.bounds.width - 44, y: 6, width: 28, height: 24))
        optionsButton.bezelStyle = .rounded
        optionsButton.image = NSImage(systemSymbolName: "ellipsis.circle.fill", accessibilityDescription: "Options")
        optionsButton.contentTintColor = .white
        optionsButton.isBordered = false
        optionsButton.target = self
        optionsButton.action = #selector(showOptionsMenu(_:))
        optionsButton.autoresizingMask = [.minXMargin]
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
        
        // Get items (filtered by search if needed)
        let items = searchQuery.isEmpty ?
            ClipboardHistoryManager.shared.items :
            ClipboardHistoryManager.shared.search(searchQuery)
        
        // Update title with count
        titleLabel.stringValue = "Clipboard History (\(items.count))"
        
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
        let emptyLabel = NSTextField(labelWithString: searchQuery.isEmpty ?
            "No clipboard history yet\nCopy something to get started!" :
            "No results found"
        )
        emptyLabel.font = NSFont.systemFont(ofSize: 12)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.frame = NSRect(x: 0, y: 0, width: 300, height: 40)
        emptyLabel.usesSingleLineMode = false
        emptyLabel.maximumNumberOfLines = 2
        stackView.addArrangedSubview(emptyLabel)
    }
    
    // swiftlint:disable:next function_body_length
    private func createHistoryCard(for item: ClipboardHistoryItem) -> NSView {
        // Container holds both card and timestamp below it
        let timeHeight: CGFloat = 18
        let spacing: CGFloat = 6
        let containerHeight = cardHeight + spacing + timeHeight
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: cardWidth, height: containerHeight))
        container.identifier = NSUserInterfaceItemIdentifier("container-\(item.id.uuidString)")
        container.wantsLayer = true
        container.layer?.masksToBounds = false // Allow icon to overflow the container bounds
        
        // Create the card
        let card = NSView(frame: NSRect(x: 0, y: timeHeight + spacing, width: cardWidth, height: cardHeight))
        card.wantsLayer = true
        // Light card background like screenshot thumbnails
        card.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.95).cgColor
        card.layer?.cornerRadius = 8 // 4 rounded corners (ALL SIDES)
        card.layer?.masksToBounds = true // Ensure corners are clipped
        card.layer?.borderWidth = 4 // Thicker border for better visibility when selected
        card.layer?.borderColor = NSColor.clear.cgColor // Default: no border (will be blue when selected)
        
        // Subtle shadow like screenshot preview
        card.shadow = NSShadow()
        card.layer?.shadowColor = NSColor.black.cgColor
        card.layer?.shadowOpacity = 0.3
        card.layer?.shadowOffset = NSSize(width: 0, height: 2)
        card.layer?.shadowRadius = 8
        
        // Make card clickable
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(cardClicked(_:)))
        card.addGestureRecognizer(clickGesture)
        card.identifier = NSUserInterfaceItemIdentifier("card-\(item.id.uuidString)")
        
        // Add right-click context menu for images
        if item.contentType == .image || item.contentType == .mixed {
            let rightClickGesture = NSClickGestureRecognizer(target: self, action: #selector(cardRightClicked(_:)))
            rightClickGesture.buttonMask = 0x2 // Right mouse button
            card.addGestureRecognizer(rightClickGesture)
        }
        
        // Pin indicator (if pinned) - always in top-right corner
        if item.isPinned {
            let pinIcon = NSImageView(frame: NSRect(x: cardWidth - 26, y: cardHeight - 26, width: 18, height: 18))
            pinIcon.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
            pinIcon.contentTintColor = .systemYellow
            card.addSubview(pinIcon)
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
            card.addSubview(imageView)
            
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
                card.addSubview(textBadge)
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
                textLabel.textColor = .black
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
            card.addSubview(textLabel)
        }
        
        container.addSubview(card)
        
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
        timeLabel.textColor = .white // White text on dark HUD background
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
            
            // Update border color (thicker now - 4px)
            cardView.layer?.borderColor = isSelected ? NSColor.systemBlue.cgColor : NSColor.clear.cgColor
            
            // Update timestamp text and pill visibility
            if isSelected {
                // Show "Copy" in white text on blue pill
                timeLabelView.stringValue = "Copy"
                timeLabelView.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
                timeLabelView.textColor = .white // White text
                pillView.isHidden = false // Show blue pill background
            } else {
                // Show timestamp in white text, no pill
                if index < ClipboardHistoryManager.shared.items.count {
                    let item = ClipboardHistoryManager.shared.items[index]
                    timeLabelView.stringValue = item.displayTime
                    timeLabelView.font = NSFont.systemFont(ofSize: 11, weight: .regular)
                    timeLabelView.textColor = .white // White text on dark HUD
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
        
        // Close the history window first
        closeWindow()
        
        // Open settings to History tab (tab index 2)
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            logger.info("Opening settings to History tab...")
            appDelegate.openSettingsToTab(2)
        } else {
            logger.error("Could not get AppDelegate!")
        }
        
        AnalyticsManager.shared.trackFeatureUsage("history_settings_opened_from_strip")
    }
    
    private func closeWindow() {
        logger.debug("Closing history window")
        
        // Stop monitoring for clicks outside
        stopClickOutsideMonitor()
        
        self.orderOut(nil)
        
        // Track analytics
        AnalyticsManager.shared.trackFeatureUsage("clipboard_history_window_closed")
    }
    
    private func startClickOutsideMonitor() {
        // Monitor for clicks within the app (local monitor)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            
            // Get the click location in screen coordinates
            let clickLocation = NSEvent.mouseLocation
            let windowFrame = self.frame
            
            self.logger.debug("🖱️ Click detected at: \(NSStringFromPoint(clickLocation)), window frame: \(NSStringFromRect(windowFrame))")
            
            // Check if click is outside our window
            if !windowFrame.contains(clickLocation) {
                // Click is outside our window but inside the app, close
                self.logger.info("Click outside window, closing")
                self.closeWindow()
                return event // Don't consume - let it pass through
            }
            
            self.logger.debug("Click inside window, passing through")
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
        let workspace = NSWorkspace.shared
        
        // Try to find running app by name
        if let app = workspace.runningApplications.first(where: { app in
            app.localizedName == appName ||
            app.bundleIdentifier?.contains(appName.lowercased()) == true
        }) {
            return app.icon
        }
        
        // Try to find app by bundle identifier or path
        if let appURL = workspace.urlForApplication(withBundleIdentifier: appName) {
            return workspace.icon(forFile: appURL.path)
        }
        
        // Try common app paths
        let appPaths = [
            "/Applications/\(appName).app",
            "/System/Applications/\(appName).app",
            "/Applications/Utilities/\(appName).app"
        ]
        
        for path in appPaths where FileManager.default.fileExists(atPath: path) {
            return workspace.icon(forFile: path)
        }
        
        return nil
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
        
        self.makeKeyAndOrderFront(nil)
        logger.info("Showing history window with \(ClipboardHistoryManager.shared.items.count) items")
        
        // Start monitoring for clicks outside
        startClickOutsideMonitor()
        
        // Track analytics
        AnalyticsManager.shared.trackFeatureUsage("clipboard_history_window_opened")
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Escape key
            closeWindow()
            
        case 123: // Left arrow
            if selectedIndex > 0 {
                selectedIndex -= 1
                updateSelection()
            }
            
        case 124: // Right arrow
            if selectedIndex < cardContainers.count - 1 {
                selectedIndex += 1
                updateSelection()
            }
            
        case 36, 76: // Return or Enter - copy selected item
            if selectedIndex < ClipboardHistoryManager.shared.items.count {
                let item = ClipboardHistoryManager.shared.items[selectedIndex]
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

// MARK: - NSColor Extension
extension NSColor {
    var highlighted: NSColor {
        return self.blended(withFraction: 0.1, of: .controlAccentColor) ?? self
    }
}
