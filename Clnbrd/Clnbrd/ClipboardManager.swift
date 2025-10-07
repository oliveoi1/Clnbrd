import Cocoa
import os.log

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "clipboard")

class ClipboardManager {
    var cleaningRules = CleaningRules()
    var lastClipboardChangeCount = 0
    var clipboardMonitorTimer: Timer?
    
    // Threshold for background processing (50,000 characters)
    private let largeTextThreshold = 50_000
    
    func cleanClipboard() {
        let pasteboard = NSPasteboard.general
        
        var text: String?
        
        text = pasteboard.string(forType: .string)
        
        if text == nil, let rtfData = pasteboard.data(forType: .rtf) {
            text = NSAttributedString(rtf: rtfData, documentAttributes: nil)?.string
        }
        
        if text == nil, let htmlData = pasteboard.data(forType: .html) {
            text = NSAttributedString(html: htmlData, documentAttributes: nil)?.string
        }
        
        guard let originalText = text else { 
            SentryManager.shared.trackUserAction("clipboard_clean_failed", data: ["reason": "no_text_found"])
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
    
    func cleanAndPasteClipboard() {
        logger.info("🔍 cleanAndPasteClipboard() called!")
        let pasteboard = NSPasteboard.general
        
        // Store original clipboard data (all types, not just text)
        let originalTypes = pasteboard.types ?? []
        var originalData: [NSPasteboard.PasteboardType: Data] = [:]
        
        // Preserve all data types
        for type in originalTypes {
            if let data = pasteboard.data(forType: type) {
                originalData[type] = data
            }
        }
        
        // Get original text for cleaning
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
        
        guard let originalText = text else {
            logger.error("❌ No text found in clipboard!")
            return
        }
        
        logger.info("🔍 Original text length: \(originalText.count)")
        
        // Helper function to execute paste sequence
        let executePasteSequence = { [weak self] (cleanedText: String) in
            guard let self = self else { return }
            
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
}
