import Cocoa
import os.log

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
    
    // Constants
    private let windowHeight: CGFloat = 180 // Increased to show full cards (120px + header + padding)
    private let cardWidth: CGFloat = 180
    private let cardHeight: CGFloat = 120
    private let padding: CGFloat = 16 // Reduced padding for better fit
    private var optionsButton: NSButton!
    
    init() {
        // Create window at top of screen - FULL WIDTH, below menu bar
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero // visibleFrame excludes menu bar
        let windowFrame = NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.maxY - windowHeight, // Just below menu bar
            width: screenFrame.width, // FULL screen width
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
        self.backgroundColor = NSColor.black.withAlphaComponent(0.85) // Dark translucent like screenshot preview
        self.isOpaque = false
        self.hasShadow = true
        
        // Rounded corners at bottom
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.cornerRadius = 12
        self.contentView?.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner] // Bottom corners only
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
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 0, y: 8, width: contentView.bounds.width, height: 20)
        titleLabel.autoresizingMask = [.width]
        titleLabel.drawsBackground = false
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        headerView.addSubview(titleLabel)
        
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
        stackView.spacing = 10
        stackView.alignment = .centerY
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create a container for the stack view
        let stackContainer = NSView()
        stackContainer.addSubview(stackView)
        scrollView.documentView = stackContainer
        
        // Pin stack view to container with height constraint
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: stackContainer.leadingAnchor),
            stackView.topAnchor.constraint(equalTo: stackContainer.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: stackContainer.bottomAnchor),
            stackView.heightAnchor.constraint(equalToConstant: cardHeight)
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
        
        // Add card for each item
        for item in items {
            let card = createHistoryCard(for: item)
            // Ensure card has fixed width and height
            card.translatesAutoresizingMaskIntoConstraints = false
            card.widthAnchor.constraint(equalToConstant: cardWidth).isActive = true
            card.heightAnchor.constraint(equalToConstant: cardHeight).isActive = true
            stackView.addArrangedSubview(card)
        }
        
        // Update container frame to fit all cards horizontally
        if let container = scrollView.documentView {
            let contentWidth = CGFloat(items.count) * (cardWidth + 10) + 10
            container.frame = NSRect(x: 0, y: 0, width: max(contentWidth, scrollView.bounds.width), height: cardHeight)
        }
        
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
    
    private func createHistoryCard(for item: ClipboardHistoryItem) -> NSView {
        let card = NSView(frame: NSRect(x: 0, y: 0, width: cardWidth, height: cardHeight))
        card.wantsLayer = true
        // Light card background like screenshot thumbnails
        card.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.95).cgColor
        card.layer?.cornerRadius = 8
        card.layer?.masksToBounds = true // Ensure corners are clipped
        card.layer?.borderWidth = 0.5
        card.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        
        // Subtle shadow like screenshot preview
        card.shadow = NSShadow()
        card.layer?.shadowColor = NSColor.black.cgColor
        card.layer?.shadowOpacity = 0.3
        card.layer?.shadowOffset = NSSize(width: 0, height: 2)
        card.layer?.shadowRadius = 8
        
        // Make card clickable
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(cardClicked(_:)))
        card.addGestureRecognizer(clickGesture)
        card.identifier = NSUserInterfaceItemIdentifier(item.id.uuidString)
        
        // Pin indicator (if pinned)
        if item.isPinned {
            let pinIcon = NSImageView(frame: NSRect(x: cardWidth - 28, y: cardHeight - 28, width: 18, height: 18))
            pinIcon.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
            pinIcon.contentTintColor = .systemYellow
            card.addSubview(pinIcon)
        }
        
        // Text preview (dark text on white card)
        let textLabel = NSTextField(labelWithString: item.preview)
        textLabel.frame = NSRect(x: 12, y: 32, width: cardWidth - 24, height: 52)
        textLabel.font = NSFont.systemFont(ofSize: 11)
        textLabel.textColor = .black // Dark text on white card
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.usesSingleLineMode = false
        textLabel.maximumNumberOfLines = 3
        textLabel.isEditable = false
        textLabel.isSelectable = false
        textLabel.isBordered = false
        textLabel.drawsBackground = false
        textLabel.cell?.wraps = true
        textLabel.cell?.isScrollable = false
        card.addSubview(textLabel)
        
        // Bottom info bar background (light gray like screenshot preview)
        let infoBar = NSView(frame: NSRect(x: 0, y: 0, width: cardWidth, height: 26))
        infoBar.wantsLayer = true
        infoBar.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.05).cgColor
        infoBar.layer?.cornerRadius = 8
        infoBar.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner] // Bottom corners only
        card.addSubview(infoBar)
        
        // Timestamp
        let timeLabel = NSTextField(labelWithString: item.displayTime)
        timeLabel.frame = NSRect(x: 12, y: 7, width: 100, height: 14)
        timeLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        timeLabel.textColor = .darkGray
        timeLabel.isEditable = false
        timeLabel.isSelectable = false
        timeLabel.isBordered = false
        timeLabel.drawsBackground = false
        card.addSubview(timeLabel)
        
        // Character count badge
        if item.characterCount > 0 {
            let countLabel = NSTextField(labelWithString: "\(item.characterCount) chars")
            countLabel.frame = NSRect(x: cardWidth - 80, y: 7, width: 68, height: 14)
            countLabel.font = NSFont.systemFont(ofSize: 10)
            countLabel.textColor = .gray
            countLabel.alignment = .right
            countLabel.isEditable = false
            countLabel.isSelectable = false
            countLabel.isBordered = false
            countLabel.drawsBackground = false
            card.addSubview(countLabel)
        }
        
        return card
    }
    
    @objc private func cardClicked(_ gesture: NSClickGestureRecognizer) {
        guard let card = gesture.view else { return }
        guard let idString = card.identifier?.rawValue,
              let itemId = UUID(uuidString: idString) else { return }
        
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
    
    func toggle() {
        if self.isVisible {
            closeWindow()
        } else {
            show()
        }
    }
    
    func show() {
        // Reload items before showing
        reloadHistoryItems()
        
        // Position at top of current screen - FULL WIDTH, below menu bar
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame // visibleFrame excludes menu bar
            let windowFrame = NSRect(
                x: screenFrame.origin.x,
                y: screenFrame.maxY - windowHeight, // Just below menu bar
                width: screenFrame.width, // FULL screen width
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
        // Close on Escape key
        if event.keyCode == 53 { // Escape key
            closeWindow()
        } else {
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
