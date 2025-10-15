import Cocoa
import os.log

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "clipboard")

class ClipboardManager {
    var cleaningRules = CleaningRules()
    var lastClipboardChangeCount = 0
    var clipboardMonitorTimer: Timer?
    private var historyMonitorTimer: DispatchSourceTimer?
    
    // Threshold for background processing (50,000 characters)
    private let largeTextThreshold = 50_000
    
    // Safety settings
    private var maxClipboardSizeMB: Int = 10
    private var clipboardTimeoutSeconds: Double = 5.0
    private var skipLargeClipboardItems: Bool = true
    
    init() {
        loadSafetySettings()
    }
    
    private func loadSafetySettings() {
        maxClipboardSizeMB = PreferencesManager.shared.loadMaxClipboardSize()
        clipboardTimeoutSeconds = PreferencesManager.shared.loadClipboardTimeout()
        skipLargeClipboardItems = PreferencesManager.shared.loadSkipLargeClipboardItems()
        
        logger.info("""
            📋 Clipboard safety settings loaded - \
            Max size: \(self.maxClipboardSizeMB) MB, \
            Timeout: \(self.clipboardTimeoutSeconds)s, \
            Skip large: \(self.skipLargeClipboardItems)
            """)
    }
    
    /// Reload safety settings (call this after user changes settings)
    func reloadSafetySettings() {
        loadSafetySettings()
    }
    
    func cleanClipboard() {
        let pasteboard = NSPasteboard.general
        
        // Check clipboard size first
        if skipLargeClipboardItems && isClipboardTooLarge(pasteboard) {
            let sizeBytes = getClipboardSize(pasteboard)
            let sizeMB = Double(sizeBytes) / (1024 * 1024)
            
            logger.warning("🚫 Skipping large clipboard item (\(String(format: "%.2f", sizeMB)) MB)")
            
            SentryManager.shared.trackUserAction("clipboard_clean_skipped", data: [
                "reason": "too_large",
                "size_mb": String(format: "%.2f", sizeMB),
                "max_size_mb": "\(maxClipboardSizeMB)"
            ])
            
            // Still capture to history if it's not too large for that
            captureToHistory(pasteboard)
            return
        }
        
        // Capture original clipboard to history BEFORE cleaning
        captureToHistory(pasteboard)
        
        // Extract text with timeout protection
        guard let originalText = extractTextSafely(from: pasteboard) else {
            SentryManager.shared.trackUserAction("clipboard_clean_failed", data: [
                "reason": "extraction_failed_or_timeout"
            ])
            return
        }
        
        // Check if text is large enough to warrant background processing
        if originalText.count > largeTextThreshold {
            logger.info("🔄 Large text detected (\(originalText.count) chars) - processing on background thread")
            let startTime = Date()
            
            // Process on background thread to avoid UI freeze
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                let cleanedText = self.cleaningRules.apply(to: originalText)
                let processingTime = Date().timeIntervalSince(startTime)
                
                // Update clipboard on main thread
                DispatchQueue.main.async {
                    pasteboard.clearContents()
                    pasteboard.setString(cleanedText, forType: .string)
                    pasteboard.setData(Data(), forType: .rtf)
                    pasteboard.setData(Data(), forType: .html)
                    
                    // Track analytics
                    if AnalyticsManager.shared.isAnalyticsEnabled() {
                        AnalyticsManager.shared.trackCleaningOperation(rule: "manual_clean", method: .manual)
                    }
                    
                    SentryManager.shared.trackUserAction("clipboard_cleaned_successfully", data: [
                        "original_length": originalText.count,
                        "cleaned_length": cleanedText.count,
                        "processing_time_ms": Int(processingTime * 1000),
                        "background_processed": true
                    ])
                    
                    logger.info("✅ Large text cleaned successfully in \(Int(processingTime * 1000))ms (background)")
                }
            }
        } else {
            // Small text - process synchronously (fast enough)
            let cleanedText = cleaningRules.apply(to: originalText)
            
            pasteboard.clearContents()
            pasteboard.setString(cleanedText, forType: .string)
            pasteboard.setData(Data(), forType: .rtf)
            pasteboard.setData(Data(), forType: .html)
            
            // Track analytics
            if AnalyticsManager.shared.isAnalyticsEnabled() {
                AnalyticsManager.shared.trackCleaningOperation(rule: "manual_clean", method: .manual)
            }
            
            SentryManager.shared.trackUserAction("clipboard_cleaned_successfully", data: [
                "original_length": originalText.count,
                "cleaned_length": cleanedText.count,
                "background_processed": false
            ])
            
            logger.info("Clipboard cleaned successfully")
        }
    }
    
    // swiftlint:disable:next function_body_length
    func cleanAndPasteClipboard() {
        logger.info("🔍 cleanAndPasteClipboard() called!")
        let pasteboard = NSPasteboard.general
        
        // Check clipboard size first
        if skipLargeClipboardItems && isClipboardTooLarge(pasteboard) {
            let sizeBytes = getClipboardSize(pasteboard)
            let sizeMB = Double(sizeBytes) / (1024 * 1024)
            
            logger.warning("🚫 Skipping large clipboard item (\(String(format: "%.2f", sizeMB)) MB)")
            
            SentryManager.shared.trackUserAction("clipboard_paste_skipped", data: [
                "reason": "too_large",
                "size_mb": String(format: "%.2f", sizeMB),
                "max_size_mb": "\(maxClipboardSizeMB)"
            ])
            
            // Show notification to user
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowClipboardWarning"),
                object: nil,
                userInfo: [
                    "title": "Clipboard Too Large",
                    "message": "Clipboard data is \(String(format: "%.1f", sizeMB)) MB (max: \(maxClipboardSizeMB) MB). Skipped processing."
                ]
            )
            
            return
        }
        
        // Capture original clipboard to history BEFORE cleaning
        captureToHistory(pasteboard)
        
        // Store original clipboard data
        let originalData = preserveClipboardData(pasteboard)
        
        // Extract text from clipboard with timeout protection
        guard let originalText = extractTextSafely(from: pasteboard) else {
            logger.error("❌ No text found in clipboard or extraction timed out!")
            
            // Show notification to user
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowClipboardWarning"),
                object: nil,
                userInfo: [
                    "title": "Clipboard Processing Failed",
                    "message": "Unable to extract text from clipboard (may have timed out)"
                ]
            )
            
            return
        }
        
        logger.info("🔍 Original text length: \(originalText.count)")
        
        // Helper function to execute paste sequence
        let executePasteSequence = { (cleanedText: String) in
            pasteboard.clearContents()
            pasteboard.setString(cleanedText, forType: .string)
            logger.info("🔍 Clipboard updated with cleaned text")
            
            // Track analytics
            if AnalyticsManager.shared.isAnalyticsEnabled() {
                AnalyticsManager.shared.trackCleaningOperation(rule: "hotkey_paste", method: .hotkey)
            }
            
            // Check if we have accessibility permission
            let isTrusted = AXIsProcessTrusted()
            logger.info("🔍 Process trusted (Accessibility): \(isTrusted)")
            
            // Paste the cleaned text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                logger.info("🔍 Attempting to paste...")
                
                // Try CGEvent with session event tap (more permissive than HID tap)
                let source = CGEventSource(stateID: .combinedSessionState)
                logger.info("🔍 CGEventSource created: \(source != nil)")
                
                // Create Cmd+V event
                let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
                let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
                
                vDown?.flags = .maskCommand
                vUp?.flags = .maskCommand
                
                // Post to session event tap instead of HID tap
                vDown?.post(tap: .cgSessionEventTap)
                vUp?.post(tap: .cgSessionEventTap)
                logger.info("✅ CGEvent paste posted to session tap")
            }
            
            // Restore original clipboard after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                pasteboard.clearContents()
                
                // Restore all original data types
                for (type, data) in originalData {
                    pasteboard.setData(data, forType: type)
                }
                
                logger.info("🔍 Original clipboard fully restored (all \(originalData.count) types)")
                logger.info("🔍 Restored text preview: \(originalText.prefix(50))...")
            }
            
            logger.info("✅ Clipboard cleaned and paste sequence initiated")
        }
        
        // Check if text is large enough to warrant background processing
        if originalText.count > largeTextThreshold {
            logger.info("🔄 Large text detected (\(originalText.count) chars) - processing on background thread")
            let startTime = Date()
            
            // Process on background thread to avoid UI freeze
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                let cleanedText = self.cleaningRules.apply(to: originalText)
                let processingTime = Date().timeIntervalSince(startTime)
                
                logger.info("🔍 Cleaned text length: \(cleanedText.count)")
                logger.info("✅ Large text cleaned in \(Int(processingTime * 1000))ms (background)")
                
                // Execute paste on main thread
                DispatchQueue.main.async {
                    SentryManager.shared.trackUserAction("hotkey_paste_large_text", data: [
                        "original_length": originalText.count,
                        "cleaned_length": cleanedText.count,
                        "processing_time_ms": Int(processingTime * 1000),
                        "background_processed": true
                    ])
                    
                    executePasteSequence(cleanedText)
                }
            }
        } else {
            // Small text - process synchronously (fast enough)
            let cleanedText = cleaningRules.apply(to: originalText)
            logger.info("🔍 Cleaned text length: \(cleanedText.count)")
            
            SentryManager.shared.trackUserAction("hotkey_paste", data: [
                "original_length": originalText.count,
                "cleaned_length": cleanedText.count,
                "background_processed": false
            ])
            
            executePasteSequence(cleanedText)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculate total size of clipboard data in bytes
    private func getClipboardSize(_ pasteboard: NSPasteboard) -> Int64 {
        guard let types = pasteboard.types else { return 0 }
        
        var totalSize: Int64 = 0
        for type in types {
            if let data = pasteboard.data(forType: type) {
                totalSize += Int64(data.count)
            }
        }
        
        return totalSize
    }
    
    /// Check if clipboard data exceeds size limit
    private func isClipboardTooLarge(_ pasteboard: NSPasteboard) -> Bool {
        let sizeBytes = getClipboardSize(pasteboard)
        let sizeMB = Double(sizeBytes) / (1024 * 1024)
        let maxSizeMB = Double(maxClipboardSizeMB)
        
        if sizeMB > maxSizeMB {
            logger.warning("""
                ⚠️ Clipboard data too large: \(String(format: "%.2f", sizeMB)) MB \
                (max: \(maxSizeMB) MB)
                """)
            return true
        }
        
        return false
    }
    
    /// Extract text from clipboard with timeout protection
    private func extractTextSafely(from pasteboard: NSPasteboard) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var extractedText: String?
        var didTimeout = false
        
        // Perform extraction on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            extractedText = self.extractTextFromClipboard(pasteboard)
            semaphore.signal()
        }
        
        // Wait with timeout
        let timeout = DispatchTime.now() + clipboardTimeoutSeconds
        if semaphore.wait(timeout: timeout) == .timedOut {
            didTimeout = true
            logger.error("⏱️ Clipboard text extraction timed out after \(self.clipboardTimeoutSeconds)s")
            
            SentryManager.shared.trackUserAction("clipboard_extraction_timeout", data: [
                "timeout_seconds": "\(self.clipboardTimeoutSeconds)"
            ])
        }
        
        return didTimeout ? nil : extractedText
    }
    
    private func preserveClipboardData(_ pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType: Data] {
        let originalTypes = pasteboard.types ?? []
        var originalData: [NSPasteboard.PasteboardType: Data] = [:]
        
        // Preserve all data types
        for type in originalTypes {
            if let data = pasteboard.data(forType: type) {
                originalData[type] = data
            }
        }
        
        return originalData
    }
    
    private func extractTextFromClipboard(_ pasteboard: NSPasteboard) -> String? {
        var text: String?
        text = pasteboard.string(forType: .string)
        logger.info("🔍 Plain text from clipboard: \(text != nil ? "YES" : "NO")")
        
        if text == nil, let rtfData = pasteboard.data(forType: .rtf) {
            text = NSAttributedString(rtf: rtfData, documentAttributes: nil)?.string
            logger.info("🔍 RTF text from clipboard: \(text != nil ? "YES" : "NO")")
        }
        
        if text == nil, let htmlData = pasteboard.data(forType: .html) {
            text = NSAttributedString(html: htmlData, documentAttributes: nil)?.string
            logger.info("🔍 HTML text from clipboard: \(text != nil ? "YES" : "NO")")
        }
        
        return text
    }
    
    func startClipboardMonitoring() {
        lastClipboardChangeCount = NSPasteboard.general.changeCount
        
        clipboardMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let currentChangeCount = NSPasteboard.general.changeCount
            
            if currentChangeCount != self.lastClipboardChangeCount {
                self.lastClipboardChangeCount = currentChangeCount
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.cleanClipboard()
                    
                    // Track auto-clean analytics
                    if AnalyticsManager.shared.isAnalyticsEnabled() {
                        AnalyticsManager.shared.trackCleaningOperation(rule: "auto_clean", method: .autoClean)
                    }
                }
            }
        }
        
        logger.info("Clipboard monitoring started")
    }
    
    func stopClipboardMonitoring() {
        clipboardMonitorTimer?.invalidate()
        clipboardMonitorTimer = nil
        logger.info("Clipboard monitoring stopped")
    }
    
    // MARK: - Clipboard History Integration
    
    private func captureToHistory(_ pasteboard: NSPasteboard) {
        // Only capture if history is enabled
        guard ClipboardHistoryManager.shared.isEnabled else {
            logger.debug("🚫 History disabled, not capturing")
            return
        }
        
        // Check if current app is excluded
        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
        if ClipboardHistoryManager.shared.isAppExcluded(sourceApp) {
            logger.debug("🚫 App '\(sourceApp ?? "")' is excluded from history capture")
            return
        }
        
        // Check clipboard size for history capture
        let sizeBytes = getClipboardSize(pasteboard)
        let sizeMB = Double(sizeBytes) / (1024 * 1024)
        
        // Use a larger limit for history (allow up to 2x the normal limit for history only)
        let historyMaxSizeMB = Double(maxClipboardSizeMB) * 2.0
        if sizeMB > historyMaxSizeMB {
            logger.warning("🚫 Clipboard too large for history capture: \(String(format: "%.2f", sizeMB)) MB")
            
            SentryManager.shared.trackUserAction("history_capture_skipped", data: [
                "reason": "too_large",
                "size_mb": String(format: "%.2f", sizeMB)
            ])
            return
        }
        
        // Extract all available formats
        let plainText = pasteboard.string(forType: .string)
        let rtfData = pasteboard.data(forType: .rtf)
        let htmlData = pasteboard.data(forType: .html)
        
        // Check for images (with size limits)
        var imageData: Data?
        if let types = pasteboard.types, types.contains(.tiff) || types.contains(.png) {
            // Try TIFF first (most common for screenshots/copied images)
            if let tiffData = pasteboard.data(forType: .tiff) {
                let imageSizeMB = Double(tiffData.count) / (1024 * 1024)
                
                // Only capture images under the size limit
                if imageSizeMB <= historyMaxSizeMB {
                    imageData = tiffData
                    logger.debug("📸 Found TIFF image on clipboard (\(String(format: "%.2f", imageSizeMB)) MB)")
                } else {
                    logger.warning("📸 TIFF image too large for capture: \(String(format: "%.2f", imageSizeMB)) MB")
                }
            } else if let pngData = pasteboard.data(forType: .png) {
                let imageSizeMB = Double(pngData.count) / (1024 * 1024)
                
                if imageSizeMB <= historyMaxSizeMB {
                    imageData = pngData
                    logger.debug("📸 Found PNG image on clipboard (\(String(format: "%.2f", imageSizeMB)) MB)")
                } else {
                    logger.warning("📸 PNG image too large for capture: \(String(format: "%.2f", imageSizeMB)) MB")
                }
            }
        }
        
        logger.info("""
            📋 Capturing clipboard - \
            Text: \(plainText != nil), \
            RTF: \(rtfData != nil), \
            HTML: \(htmlData != nil), \
            Image: \(imageData != nil)
            """)
        
        // Create history item (sourceApp already retrieved above)
        let historyItem = ClipboardHistoryItem(
            plainText: plainText,
            rtfData: rtfData,
            htmlData: htmlData,
            imageData: imageData,
            sourceApp: sourceApp
        )
        
        // Add to history
        ClipboardHistoryManager.shared.addItem(historyItem)
        
        logger.info("✅ Captured clipboard to history: \(historyItem.preview)")
    }
    
    // MARK: - Clipboard History Monitoring
    
    /// Start monitoring clipboard changes for history capture
    func startHistoryMonitoring() {
        // Stop any existing timer
        stopHistoryMonitoring()
        
        // Create a DispatchSourceTimer for better power efficiency
        let queue = DispatchQueue(label: "com.allanray.Clnbrd.historyMonitor", qos: .utility)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        
        // Monitor clipboard changes every 1.5 seconds (reduced from 0.5s for better battery life)
        timer.schedule(deadline: .now(), repeating: 1.5, leeway: .milliseconds(100))
        
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            guard ClipboardHistoryManager.shared.isEnabled else { return }
            
            let currentChangeCount = NSPasteboard.general.changeCount
            if currentChangeCount != self.lastClipboardChangeCount {
                self.lastClipboardChangeCount = currentChangeCount
                
                // Capture to history on ANY clipboard change (coalesced on main queue)
                DispatchQueue.main.async {
                    self.captureToHistory(NSPasteboard.general)
                }
            }
        }
        
        timer.resume()
        historyMonitorTimer = timer
        
        logger.info("📋 Clipboard history monitoring started (1.5s interval)")
    }
    
    /// Stop monitoring clipboard changes for history
    func stopHistoryMonitoring() {
        historyMonitorTimer?.cancel()
        historyMonitorTimer = nil
        logger.info("📋 Clipboard history monitoring stopped")
    }
    
    deinit {
        clipboardMonitorTimer?.invalidate()
        stopHistoryMonitoring()
    }
}
