import Foundation
import AppKit
import Combine
import os.log

/// Manages clipboard history storage, retention, and cleanup
class ClipboardHistoryManager: ObservableObject {
    static let shared = ClipboardHistoryManager()
    
    private let logger = Logger(subsystem: "com.allanalomes.Clnbrd", category: "ClipboardHistory")
    
    // MARK: - Published Properties
    @Published private(set) var items: [ClipboardHistoryItem] = []
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "ClipboardHistory.Enabled")
            if !isEnabled {
                clearAllHistory()
            }
        }
    }
    
    // MARK: - Settings
    enum RetentionPeriod: String, CaseIterable, Codable {
        case never = "Never"
        case oneDay = "1 Day"
        case threeDays = "3 Days"
        case oneWeek = "1 Week"
        case oneMonth = "1 Month"
        case forever = "Forever"
        
        var timeInterval: TimeInterval? {
            switch self {
            case .never:
                return 0
            case .oneDay:
                return 24 * 60 * 60
            case .threeDays:
                return 3 * 24 * 60 * 60
            case .oneWeek:
                return 7 * 24 * 60 * 60
            case .oneMonth:
                return 30 * 24 * 60 * 60
            case .forever:
                return nil
            }
        }
    }
    
    var retentionPeriod: RetentionPeriod {
        didSet {
            UserDefaults.standard.set(retentionPeriod.rawValue, forKey: "ClipboardHistory.RetentionPeriod")
            cleanupExpiredItems()
        }
    }
    
    var maxItems: Int {
        didSet {
            UserDefaults.standard.set(maxItems, forKey: "ClipboardHistory.MaxItems")
            enforceMaxItems()
        }
    }
    
    // MARK: - Private Properties
    private var cleanupTimer: Timer?
    private let maxItemsDefault = 100
    
    // MARK: - Initialization
    private init() {
        // Load settings from UserDefaults (default to enabled if not set)
        let enabledKey = "ClipboardHistory.Enabled"
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            // First time - enable by default
            self.isEnabled = true
            UserDefaults.standard.set(true, forKey: enabledKey)
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }
        
        let savedPeriodKey = "ClipboardHistory.RetentionPeriod"
        if let savedPeriod = UserDefaults.standard.string(forKey: savedPeriodKey),
           let period = RetentionPeriod(rawValue: savedPeriod) {
            self.retentionPeriod = period
        } else {
            self.retentionPeriod = .oneDay // Default to 1 day
            UserDefaults.standard.set(RetentionPeriod.oneDay.rawValue, forKey: "ClipboardHistory.RetentionPeriod")
        }
        
        let savedMaxItems = UserDefaults.standard.integer(forKey: "ClipboardHistory.MaxItems")
        self.maxItems = savedMaxItems > 0 ? savedMaxItems : maxItemsDefault
        
        if savedMaxItems == 0 {
            UserDefaults.standard.set(maxItemsDefault, forKey: "ClipboardHistory.MaxItems")
        }
        
        // Start cleanup timer (runs every hour)
        startCleanupTimer()
        
        // Load persisted history from disk
        loadHistoryFromDisk()
        
        logger.info("""
            ClipboardHistoryManager initialized - \
            Enabled: \(self.isEnabled), \
            Retention: \(self.retentionPeriod.rawValue), \
            Max: \(self.maxItems), \
            Loaded items: \(self.items.count)
            """)
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Adds a new item to clipboard history
    func addItem(_ item: ClipboardHistoryItem) {
        guard isEnabled else {
            logger.debug("History disabled, not adding item")
            return
        }
        
        // Don't add empty items
        guard item.hasContent else {
            logger.debug("Skipping empty clipboard item")
            return
        }
        
        // Don't add duplicates (check if identical to most recent item)
        if let lastItem = items.first,
           lastItem.plainText == item.plainText,
           lastItem.rtfData == item.rtfData,
           lastItem.htmlData == item.htmlData {
            logger.debug("Skipping duplicate clipboard item")
            return
        }
        
        // Add to beginning of array (newest first)
        items.insert(item, at: 0)
        
        logger.info("✅ Added clipboard history item: \(item.preview)")
        logger.info("📊 Total history items: \(self.items.count)")
        
        // Enforce limits
        enforceMaxItems()
        
        // Save to disk
        saveHistoryToDisk()
        
        // Notify observers that history changed
        NotificationCenter.default.post(name: NSNotification.Name("ClipboardHistoryDidChange"), object: nil)
        
        // Track analytics
        trackHistoryEvent("item_added")
    }
    
    /// Captures current clipboard content and adds to history
    func captureCurrentClipboard() {
        guard isEnabled else { return }
        
        let pasteboard = NSPasteboard.general
        
        // Extract all formats
        let plainText = pasteboard.string(forType: .string)
        let rtfData = pasteboard.data(forType: .rtf)
        let htmlData = pasteboard.data(forType: .html)
        
        // Get source app if possible
        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
        
        let item = ClipboardHistoryItem(
            plainText: plainText,
            rtfData: rtfData,
            htmlData: htmlData,
            sourceApp: sourceApp
        )
        
        addItem(item)
    }
    
    /// Removes an item from history
    func removeItem(_ item: ClipboardHistoryItem) {
        items.removeAll { $0.id == item.id }
        logger.info("Removed clipboard history item: \(item.id)")
        trackHistoryEvent("item_removed")
    }
    
    /// Toggles pin status for an item
    func togglePin(_ item: ClipboardHistoryItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        let pinnedItem = ClipboardHistoryItem(
            plainText: item.plainText,
            rtfData: item.rtfData,
            htmlData: item.htmlData,
            sourceApp: item.sourceApp,
            isPinned: !item.isPinned
        )
        
        items[index] = pinnedItem
        items.sort() // Re-sort to move pinned items to top
        
        logger.info("Toggled pin for item: \(item.id) - Now pinned: \(!item.isPinned)")
        trackHistoryEvent(item.isPinned ? "item_unpinned" : "item_pinned")
    }
    
    /// Clears all non-pinned history items
    func clearHistory() {
        let beforeCount = items.count
        items.removeAll { !$0.isPinned }
        let removedCount = beforeCount - items.count
        
        // Save to disk
        saveHistoryToDisk()
        
        logger.info("Cleared \(removedCount) non-pinned history items")
        trackHistoryEvent("history_cleared", metadata: ["count": "\(removedCount)"])
    }
    
    /// Clears ALL history items (including pinned)
    func clearAllHistory() {
        let count = items.count
        items.removeAll()
        
        // Save to disk (empty array)
        saveHistoryToDisk()
        
        logger.info("Cleared all \(count) history items")
        trackHistoryEvent("history_all_cleared", metadata: ["count": "\(count)"])
    }
    
    /// Searches history items by text content
    func search(_ query: String) -> [ClipboardHistoryItem] {
        guard !query.isEmpty else { return items }
        
        let lowercaseQuery = query.lowercased()
        return items.filter { item in
            item.bestText.lowercased().contains(lowercaseQuery)
        }
    }
    
    // MARK: - Private Methods
    
    private func startCleanupTimer() {
        // Run cleanup every hour
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.cleanupExpiredItems()
        }
    }
    
    private func cleanupExpiredItems() {
        enforceRetentionPolicy()
    }
    
    private func enforceRetentionPolicy() {
        guard isEnabled else { return }
        guard let maxAge = retentionPeriod.timeInterval else { return } // Forever = no cleanup
        guard maxAge > 0 else {
            // "Never" = clear all immediately
            clearAllHistory()
            return
        }
        
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        let beforeCount = items.count
        
        // Remove expired items (but keep pinned items)
        items.removeAll { item in
            !item.isPinned && item.timestamp < cutoffDate
        }
        
        let removedCount = beforeCount - items.count
        if removedCount > 0 {
            // Save to disk after cleanup
            saveHistoryToDisk()
            
            logger.info("Cleaned up \(removedCount) expired history items")
            trackHistoryEvent("items_expired", metadata: ["count": "\(removedCount)"])
        }
    }
    
    private func enforceMaxItems() {
        guard items.count > maxItems else { return }
        
        // Keep pinned items + newest items up to maxItems
        let pinnedItems = items.filter { $0.isPinned }
        let unpinnedItems = items.filter { !$0.isPinned }
        
        let allowedUnpinned = max(0, maxItems - pinnedItems.count)
        let trimmedUnpinned = Array(unpinnedItems.prefix(allowedUnpinned))
        
        let removedCount = items.count - (pinnedItems.count + trimmedUnpinned.count)
        items = (pinnedItems + trimmedUnpinned).sorted()
        
        if removedCount > 0 {
            // Save to disk after trimming
            saveHistoryToDisk()
            
            logger.info("Enforced max items limit: removed \(removedCount) oldest items")
            trackHistoryEvent("items_trimmed", metadata: ["count": "\(removedCount)"])
        }
    }
    
    private func trackHistoryEvent(_ eventName: String, metadata: [String: String] = [:]) {
        // Track history feature usage
        AnalyticsManager.shared.trackFeatureUsage("clipboard_history_\(eventName)")
    }
    
    // MARK: - Stats
    
    var totalItems: Int {
        return items.count
    }
    
    var pinnedItemsCount: Int {
        return items.filter { $0.isPinned }.count
    }
    
    var unpinnedItemsCount: Int {
        return items.filter { !$0.isPinned }.count
    }
    
    var oldestItemDate: Date? {
        return items.last?.timestamp
    }
    
    // MARK: - Persistence
    
    /// Load history from encrypted disk storage
    private func loadHistoryFromDisk() {
        do {
            let loadedItems = try ClipboardHistoryStorage.shared.loadHistory()
            self.items = loadedItems
            
            // Apply retention policy and limits to loaded data
            enforceRetentionPolicy()
            enforceMaxItems()
            
            logger.info("✅ Loaded \(loadedItems.count) items from disk")
        } catch {
            logger.error("❌ Failed to load history from disk: \(error.localizedDescription)")
            // Start with empty history if load fails
            self.items = []
        }
    }
    
    /// Save history to encrypted disk storage
    private func saveHistoryToDisk() {
        do {
            try ClipboardHistoryStorage.shared.saveHistory(items)
            logger.debug("💾 Saved \(items.count) items to disk")
        } catch {
            logger.error("❌ Failed to save history to disk: \(error.localizedDescription)")
        }
    }
}
