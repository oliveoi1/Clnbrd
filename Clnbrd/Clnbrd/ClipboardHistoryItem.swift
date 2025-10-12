import Foundation
import AppKit

/// Represents a single item in the clipboard history
struct ClipboardHistoryItem: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    
    // Text content (all formats preserved)
    let plainText: String?
    let rtfData: Data?
    let htmlData: Data?
    
    // Metadata
    let sourceApp: String?
    let characterCount: Int
    let isPinned: Bool
    
    // For future image support (Phase 2)
    // let imageData: Data?
    // let thumbnailData: Data?
    
    init(
        plainText: String? = nil,
        rtfData: Data? = nil,
        htmlData: Data? = nil,
        sourceApp: String? = nil,
        isPinned: Bool = false
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.plainText = plainText
        self.rtfData = rtfData
        self.htmlData = htmlData
        self.sourceApp = sourceApp
        self.characterCount = plainText?.count ?? 0
        self.isPinned = isPinned
    }
    
    /// Returns a truncated preview of the text content (first 100 characters)
    var preview: String {
        guard let text = plainText, !text.isEmpty else {
            return "[Empty]"
        }
        
        // Clean up whitespace for preview
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        
        if cleaned.count <= 100 {
            return cleaned
        }
        
        return String(cleaned.prefix(100)) + "..."
    }
    
    /// Returns formatted timestamp for display (e.g., "2 min ago", "Yesterday")
    var displayTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    /// Returns true if this item has any content
    var hasContent: Bool {
        return plainText != nil || rtfData != nil || htmlData != nil
    }
    
    /// Returns the best available text representation
    var bestText: String {
        if let plain = plainText, !plain.isEmpty {
            return plain
        }
        
        // Try to extract text from RTF
        if let rtf = rtfData,
           let attributedString = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            return attributedString.string
        }
        
        // Try to extract text from HTML
        if let html = htmlData,
           let attributedString = try? NSAttributedString(
            data: html,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
           ) {
            return attributedString.string
        }
        
        return ""
    }
    
    /// Returns attributed string with formatting (RTF or HTML)
    var attributedString: NSAttributedString? {
        // Prefer RTF for formatting
        if let rtf = rtfData,
           let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            return attributed
        }
        
        // Fall back to HTML
        if let html = htmlData,
           let attributed = try? NSAttributedString(
            data: html,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
           ) {
            return attributed
        }
        
        // Plain text as last resort
        if let plain = plainText {
            return NSAttributedString(string: plain)
        }
        
        return nil
    }
    
    /// Restores this item's content to the clipboard
    func restoreToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        var items: [NSPasteboardItem] = []
        let item = NSPasteboardItem()
        
        // Add all available formats
        if let plain = plainText {
            item.setString(plain, forType: .string)
        }
        
        if let rtf = rtfData {
            item.setData(rtf, forType: .rtf)
        }
        
        if let html = htmlData {
            item.setData(html, forType: .html)
        }
        
        items.append(item)
        pasteboard.writeObjects(items)
    }
}

// MARK: - Comparable for sorting
extension ClipboardHistoryItem: Comparable {
    static func < (lhs: ClipboardHistoryItem, rhs: ClipboardHistoryItem) -> Bool {
        // Pinned items always come first
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned
        }
        
        // Otherwise sort by timestamp (newest first)
        return lhs.timestamp > rhs.timestamp
    }
}

// MARK: - Equatable
extension ClipboardHistoryItem: Equatable {
    static func == (lhs: ClipboardHistoryItem, rhs: ClipboardHistoryItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable
extension ClipboardHistoryItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

