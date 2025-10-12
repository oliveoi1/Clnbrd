import Cocoa
import os.log

/// Floating window that displays clipboard history at the top of the screen
class ClipboardHistoryWindow: NSPanel {
    private let logger = Logger(subsystem: "com.allanalomes.Clnbrd", category: "ClipboardHistoryWindow")
    
    // UI Components
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var closeButton: NSButton!
    private var titleLabel: NSTextField!
    private var searchField: NSSearchField!
    
    // State
    private var searchQuery: String = ""
    
    // Constants
    private let windowHeight: CGFloat = 150
    private let windowWidth: CGFloat = 900
    private let cardWidth: CGFloat = 220
    private let cardHeight: CGFloat = 100
    private let padding: CGFloat = 16
    
    init() {
        // Create window at top of screen
        let screenFrame = NSScreen.main?.frame ?? .zero
        let windowFrame = NSRect(
            x: (screenFrame.width - windowWidth) / 2,
            y: screenFrame.height - windowHeight - 40, // 40pt from top
            width: windowWidth,
            height: windowHeight
        )
        
        super.init(
            contentRect: windowFrame,
            styleMask: [.titled, .closable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupUI()
        observeHistoryChanges()
        
        logger.info("ClipboardHistoryWindow initialized")
    }
    
    private func setupWindow() {
        // Window properties
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = true
        self.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isOpaque = false
        self.hasShadow = true
        
        // Make window not activate app when shown
        self.styleMask.insert(.nonactivatingPanel)
    }
    
    private func setupUI() {
        guard let contentView = self.contentView else { return }
        
        // Main container
        let containerView = NSView(frame: contentView.bounds)
        containerView.autoresizingMask = [.width, .height]
        contentView.addSubview(containerView)
        
        // Header view with title and close button
        let headerView = NSView(frame: NSRect(x: 0, y: windowHeight - 30, width: windowWidth, height: 30))
        headerView.autoresizingMask = [.width, .minYMargin]
        containerView.addSubview(headerView)
        
        // Title label
        titleLabel = NSTextField(labelWithString: "Clipboard History")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.frame = NSRect(x: padding, y: 6, width: 150, height: 18)
        headerView.addSubview(titleLabel)
        
        // Close button
        closeButton = NSButton(frame: NSRect(x: windowWidth - 30, y: 4, width: 22, height: 22))
        closeButton.bezelStyle = .inline
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(closeWindow)
        closeButton.autoresizingMask = [.minXMargin]
        headerView.addSubview(closeButton)
        
        // Scroll view setup
        let scrollFrame = NSRect(x: padding, y: padding, width: windowWidth - 2 * padding, height: windowHeight - 50)
        scrollView = NSScrollView(frame: scrollFrame)
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]
        scrollView.horizontalScrollElasticity = .allowed
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
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 10
        card.layer?.borderWidth = 1.5
        card.layer?.borderColor = NSColor.separatorColor.cgColor
        
        // Shadow for depth
        card.shadow = NSShadow()
        card.layer?.shadowColor = NSColor.black.cgColor
        card.layer?.shadowOpacity = 0.1
        card.layer?.shadowOffset = NSSize(width: 0, height: -2)
        card.layer?.shadowRadius = 4
        
        // Make card clickable
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(cardClicked(_:)))
        card.addGestureRecognizer(clickGesture)
        card.identifier = NSUserInterfaceItemIdentifier(item.id.uuidString)
        
        // Hover effect
        let trackingArea = NSTrackingArea(
            rect: card.bounds,
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self,
            userInfo: ["cardView": card]
        )
        card.addTrackingArea(trackingArea)
        
        // Pin indicator (if pinned)
        if item.isPinned {
            let pinIcon = NSImageView(frame: NSRect(x: cardWidth - 28, y: cardHeight - 28, width: 18, height: 18))
            pinIcon.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
            pinIcon.contentTintColor = .systemYellow
            card.addSubview(pinIcon)
        }
        
        // Text preview (larger and more visible)
        let textLabel = NSTextField(labelWithString: item.preview)
        textLabel.frame = NSRect(x: 12, y: 32, width: cardWidth - 24, height: 52)
        textLabel.font = NSFont.systemFont(ofSize: 12)
        textLabel.textColor = .labelColor
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
        
        // Bottom info bar background
        let infoBar = NSView(frame: NSRect(x: 0, y: 0, width: cardWidth, height: 28))
        infoBar.wantsLayer = true
        infoBar.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        card.addSubview(infoBar)
        
        // Timestamp
        let timeLabel = NSTextField(labelWithString: item.displayTime)
        timeLabel.frame = NSRect(x: 12, y: 8, width: 100, height: 14)
        timeLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.isEditable = false
        timeLabel.isSelectable = false
        timeLabel.isBordered = false
        timeLabel.drawsBackground = false
        card.addSubview(timeLabel)
        
        // Character count badge
        if item.characterCount > 0 {
            let countLabel = NSTextField(labelWithString: "\(item.characterCount) chars")
            countLabel.frame = NSRect(x: cardWidth - 80, y: 8, width: 68, height: 14)
            countLabel.font = NSFont.systemFont(ofSize: 10)
            countLabel.textColor = .tertiaryLabelColor
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
    
    override func mouseEntered(with event: NSEvent) {
        if let cardView = event.trackingArea?.userInfo?["cardView"] as? NSView {
            cardView.layer?.backgroundColor = NSColor.controlBackgroundColor.highlighted.cgColor
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if let cardView = event.trackingArea?.userInfo?["cardView"] as? NSView {
            cardView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        }
    }
    
    @objc private func closeWindow() {
        logger.debug("Closing history window")
        self.orderOut(nil)
        
        // Track analytics
        AnalyticsManager.shared.trackFeatureUsage("clipboard_history_window_closed")
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
        
        // Position at top center of current screen
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let windowFrame = NSRect(
                x: (screenFrame.width - windowWidth) / 2,
                y: screenFrame.height - windowHeight - 40,
                width: windowWidth,
                height: windowHeight
            )
            self.setFrame(windowFrame, display: true)
        }
        
        self.makeKeyAndOrderFront(nil)
        logger.info("Showing history window with \(ClipboardHistoryManager.shared.items.count) items")
        
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
