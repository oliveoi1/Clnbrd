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
                clearHistory()
            }
        }
    }
    
    // MARK: - Settings
    enum RetentionPeriod: String, CaseIterable, Codable {
        case oneDay = "1 Day"
        case threeDays = "3 Days"
        case oneWeek = "1 Week"
        case oneMonth = "1 Month"
        case forever = "Forever"
        
        var timeInterval: TimeInterval? {
            switch self {
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
    
    // Image compression settings
    var compressImages: Bool {
        didSet {
            UserDefaults.standard.set(compressImages, forKey: "ClipboardHistory.CompressImages")
        }
    }
    
    var maxImageSize: CGFloat {
        didSet {
            UserDefaults.standard.set(maxImageSize, forKey: "ClipboardHistory.MaxImageSize")
        }
    }
    
    var compressionQuality: Double {
        didSet {
            UserDefaults.standard.set(compressionQuality, forKey: "ClipboardHistory.CompressionQuality")
        }
    }
    
    // App exclusions for privacy
    var excludedApps: Set<String> {
        didSet {
            let array = Array(excludedApps)
            UserDefaults.standard.set(array, forKey: "ClipboardHistory.ExcludedApps")
        }
    }
    
    // Storage management
    var maxStorageSize: Int64 {
        didSet {
            UserDefaults.standard.set(maxStorageSize, forKey: "ClipboardHistory.MaxStorageSize")
            enforceStorageLimit()
        }
    }
    
    // Image export settings
    enum ImageExportFormat: String, Codable, CaseIterable {
        case png = "PNG"
        case jpeg = "JPEG"
        case tiff = "TIFF"
    }
    
    var imageExportFormat: ImageExportFormat {
        didSet {
            UserDefaults.standard.set(imageExportFormat.rawValue, forKey: "ClipboardHistory.ImageExportFormat")
        }
    }
    
    var scaleRetinaTo1x: Bool {
        didSet {
            UserDefaults.standard.set(scaleRetinaTo1x, forKey: "ClipboardHistory.ScaleRetinaTo1x")
        }
    }
    
    var convertToSRGB: Bool {
        didSet {
            UserDefaults.standard.set(convertToSRGB, forKey: "ClipboardHistory.ConvertToSRGB")
        }
    }
    
    var addBorderToScreenshots: Bool {
        didSet {
            UserDefaults.standard.set(addBorderToScreenshots, forKey: "ClipboardHistory.AddBorderToScreenshots")
        }
    }
    
    var jpegExportQuality: Double {
        didSet {
            UserDefaults.standard.set(jpegExportQuality, forKey: "ClipboardHistory.JPEGExportQuality")
        }
    }
    
    // MARK: - Private Properties
    private var cleanupTimer: Timer?
    private let maxItemsDefault = 100
    private let maxStorageSizeDefault: Int64 = 100 * 1024 * 1024 // 100 MB default
    
    // MARK: - Initialization
    // swiftlint:disable:next function_body_length
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
        
        // Load image compression settings
        let compressKey = "ClipboardHistory.CompressImages"
        if UserDefaults.standard.object(forKey: compressKey) == nil {
            // Default to enabled
            self.compressImages = true
            UserDefaults.standard.set(true, forKey: compressKey)
        } else {
            self.compressImages = UserDefaults.standard.bool(forKey: compressKey)
        }
        
        let maxImageSizeKey = "ClipboardHistory.MaxImageSize"
        let savedMaxImageSize = UserDefaults.standard.double(forKey: maxImageSizeKey)
        self.maxImageSize = savedMaxImageSize > 0 ? CGFloat(savedMaxImageSize) : 2048 // Default 2048px
        if savedMaxImageSize == 0 {
            UserDefaults.standard.set(2048, forKey: maxImageSizeKey)
        }
        
        let compressionQualityKey = "ClipboardHistory.CompressionQuality"
        let savedQuality = UserDefaults.standard.double(forKey: compressionQualityKey)
        self.compressionQuality = savedQuality > 0 ? savedQuality : 0.8 // Default 80% quality
        if savedQuality == 0 {
            UserDefaults.standard.set(0.8, forKey: compressionQualityKey)
        }
        
        // Load excluded apps
        let excludedAppsKey = "ClipboardHistory.ExcludedApps"
        if let savedApps = UserDefaults.standard.array(forKey: excludedAppsKey) as? [String] {
            self.excludedApps = Set(savedApps)
        } else {
            // Default exclusions for common sensitive apps
            self.excludedApps = Set([
                "1Password",
                "Bitwarden",
                "LastPass",
                "Dashlane",
                "Keeper Password Manager",
                "Keychain Access"
            ])
            UserDefaults.standard.set(Array(self.excludedApps), forKey: excludedAppsKey)
        }
        
        // Load storage limit
        let maxStorageSizeKey = "ClipboardHistory.MaxStorageSize"
        let savedStorageSize = UserDefaults.standard.object(forKey: maxStorageSizeKey) as? Int64
        self.maxStorageSize = savedStorageSize ?? maxStorageSizeDefault
        if savedStorageSize == nil {
            UserDefaults.standard.set(maxStorageSizeDefault, forKey: maxStorageSizeKey)
        }
        
        // Load image export settings
        let exportFormatKey = "ClipboardHistory.ImageExportFormat"
        if let savedFormat = UserDefaults.standard.string(forKey: exportFormatKey),
           let format = ImageExportFormat(rawValue: savedFormat) {
            self.imageExportFormat = format
        } else {
            self.imageExportFormat = .png // Default to PNG
            UserDefaults.standard.set(ImageExportFormat.png.rawValue, forKey: exportFormatKey)
        }
        
        let scaleRetinaKey = "ClipboardHistory.ScaleRetinaTo1x"
        if UserDefaults.standard.object(forKey: scaleRetinaKey) == nil {
            self.scaleRetinaTo1x = false // Default: keep retina resolution
            UserDefaults.standard.set(false, forKey: scaleRetinaKey)
        } else {
            self.scaleRetinaTo1x = UserDefaults.standard.bool(forKey: scaleRetinaKey)
        }
        
        let convertSRGBKey = "ClipboardHistory.ConvertToSRGB"
        if UserDefaults.standard.object(forKey: convertSRGBKey) == nil {
            self.convertToSRGB = true // Default: convert to sRGB
            UserDefaults.standard.set(true, forKey: convertSRGBKey)
        } else {
            self.convertToSRGB = UserDefaults.standard.bool(forKey: convertSRGBKey)
        }
        
        let addBorderKey = "ClipboardHistory.AddBorderToScreenshots"
        if UserDefaults.standard.object(forKey: addBorderKey) == nil {
            self.addBorderToScreenshots = false // Default: no border
            UserDefaults.standard.set(false, forKey: addBorderKey)
        } else {
            self.addBorderToScreenshots = UserDefaults.standard.bool(forKey: addBorderKey)
        }
        
        let jpegQualityKey = "ClipboardHistory.JPEGExportQuality"
        let savedJPEGQuality = UserDefaults.standard.double(forKey: jpegQualityKey)
        self.jpegExportQuality = savedJPEGQuality > 0 ? savedJPEGQuality : 0.9 // Default 90%
        if savedJPEGQuality == 0 {
            UserDefaults.standard.set(0.9, forKey: jpegQualityKey)
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
    
    /// Check if an app is excluded from history capture
    func isAppExcluded(_ appName: String?) -> Bool {
        guard let appName = appName else { return false }
        return excludedApps.contains(appName)
    }
    
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
        enforceStorageLimit()
        
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
    
    /// Clears all history items
    func clearHistory() {
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
        
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        let beforeCount = items.count
        
        // Remove expired items
        items.removeAll { item in
            item.timestamp < cutoffDate
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
        
        // Keep only the newest items up to maxItems
        let removedCount = items.count - maxItems
        items = Array(items.prefix(maxItems))
        
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
    
    // MARK: - Storage Management
    
    /// Calculate total storage size of all history items
    var totalStorageSize: Int64 {
        return items.reduce(0) { $0 + $1.storageSize }
    }
    
    /// Human-readable total storage size
    var totalStorageSizeFormatted: String {
        let bytes = Double(totalStorageSize)
        
        if bytes < 1024 {
            return "\(Int(bytes)) bytes"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", bytes / (1024 * 1024 * 1024))
        }
    }
    
    /// Enforce storage limit by removing oldest items
    private func enforceStorageLimit() {
        let currentSize = totalStorageSize
        guard currentSize > maxStorageSize else {
            logger.debug("Storage within limits: \(self.totalStorageSizeFormatted) / \(self.formatBytes(self.maxStorageSize))")
            return
        }
        
        logger.info("Storage limit exceeded: \(self.totalStorageSizeFormatted) > \(self.formatBytes(self.maxStorageSize))")
        
        // Sort items by timestamp (oldest first for removal)
        var sortedItems = items.sorted { $0.timestamp < $1.timestamp }
        
        // Remove oldest items until we're under the limit
        var currentTotalSize = currentSize
        var removedCount = 0
        
        while currentTotalSize > maxStorageSize && !sortedItems.isEmpty {
            let removed = sortedItems.removeFirst()
            currentTotalSize -= removed.storageSize
            removedCount += 1
        }
        
        // Update items array (sorted by newest first)
        items = sortedItems.sorted()
        
        if removedCount > 0 {
            // Save to disk after cleanup
            saveHistoryToDisk()
            
            logger.info("Enforced storage limit: removed \(removedCount) items, now \(self.totalStorageSizeFormatted)")
            trackHistoryEvent("storage_limit_enforced", metadata: [
                "removed_count": "\(removedCount)",
                "final_size": "\(self.totalStorageSize)"
            ])
        }
    }
    
    /// Format bytes to human-readable string
    func formatBytes(_ bytes: Int64) -> String {
        let size = Double(bytes)
        
        if size < 1024 {
            return "\(Int(size)) bytes"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", size / 1024)
        } else if size < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", size / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", size / (1024 * 1024 * 1024))
        }
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
            logger.debug("💾 Saved \(self.items.count) items to disk")
        } catch {
            logger.error("❌ Failed to save history to disk: \(error.localizedDescription)")
        }
    }
}
