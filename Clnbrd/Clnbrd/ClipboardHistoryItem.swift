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
    
    // Image content (Phase 2)
    let imageData: Data?
    let thumbnailData: Data?
    
    // Metadata
    let sourceApp: String?
    let characterCount: Int
    let isPinned: Bool
    
    // Content type
    enum ContentType: String, Codable {
        case text
        case image
        case mixed // Both text and image
    }
    let contentType: ContentType
    
    init(
        plainText: String? = nil,
        rtfData: Data? = nil,
        htmlData: Data? = nil,
        imageData: Data? = nil,
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
        
        // Process image if present
        if let imageData = imageData, let image = NSImage(data: imageData) {
            // Check if compression is enabled
            let shouldCompress = ClipboardHistoryManager.shared.compressImages
            let maxSize = ClipboardHistoryManager.shared.maxImageSize
            let quality = ClipboardHistoryManager.shared.compressionQuality
            
            if shouldCompress {
                // Compress the image if it exceeds max size
                let compressedImage = Self.compressImageIfNeeded(image, maxSize: maxSize, quality: quality)
                self.imageData = compressedImage
            } else {
                self.imageData = imageData
            }
            
            self.thumbnailData = Self.generateThumbnail(from: image)
        } else {
            self.imageData = nil
            self.thumbnailData = nil
        }
        
        // Determine content type
        let hasText = plainText != nil || rtfData != nil || htmlData != nil
        let hasImage = self.imageData != nil
        
        if hasText && hasImage {
            self.contentType = .mixed
        } else if hasImage {
            self.contentType = .image
        } else {
            self.contentType = .text
        }
    }
    
    /// Returns a truncated preview of the content
    var preview: String {
        // For images, return a description
        if contentType == .image {
            return "[Image]"
        }
        
        if contentType == .mixed {
            if let text = plainText, !text.isEmpty {
                let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\t", with: " ")
                let truncated = cleaned.count <= 50 ? cleaned : String(cleaned.prefix(50)) + "..."
                return "\(truncated) [+ Image]"
            }
            return "[Image]"
        }
        
        // Text only
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
        return plainText != nil || rtfData != nil || htmlData != nil || imageData != nil
    }
    
    /// Get thumbnail image if available
    var thumbnail: NSImage? {
        guard let data = thumbnailData else { return nil }
        return NSImage(data: data)
    }
    
    /// Get full-size image if available
    var image: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
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
        
        var pasteboardItems: [NSPasteboardWriting] = []
        
        // Add text content if available
        if let plain = plainText {
            let item = NSPasteboardItem()
            item.setString(plain, forType: .string)
            
            if let rtf = rtfData {
                item.setData(rtf, forType: .rtf)
            }
            
            if let html = htmlData {
                item.setData(html, forType: .html)
            }
            
            pasteboardItems.append(item)
        }
        
        // Add image if available
        if let imageData = imageData, let image = NSImage(data: imageData) {
            pasteboardItems.append(image)
        }
        
        pasteboard.writeObjects(pasteboardItems)
    }
    
    // MARK: - Thumbnail Generation
    
    /// Generates a thumbnail from an image (max 200x200)
    private static func generateThumbnail(from image: NSImage, maxSize: CGFloat = 200) -> Data? {
        let imageSize = image.size
        
        // Calculate thumbnail size maintaining aspect ratio
        var thumbnailSize: NSSize
        if imageSize.width > imageSize.height {
            let ratio = maxSize / imageSize.width
            thumbnailSize = NSSize(width: maxSize, height: imageSize.height * ratio)
        } else {
            let ratio = maxSize / imageSize.height
            thumbnailSize = NSSize(width: imageSize.width * ratio, height: maxSize)
        }
        
        // Create thumbnail
        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()
        
        image.draw(
            in: NSRect(origin: .zero, size: thumbnailSize),
            from: NSRect(origin: .zero, size: imageSize),
            operation: .copy,
            fraction: 1.0
        )
        
        thumbnail.unlockFocus()
        
        // Convert to PNG data
        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        return pngData
    }
    
    /// Compresses an image if it exceeds maxSize, returns PNG data
    private static func compressImageIfNeeded(
        _ image: NSImage,
        maxSize: CGFloat,
        quality: Double
    ) -> Data? {
        let imageSize = image.size
        
        // Check if resizing is needed
        let needsResize = imageSize.width > maxSize || imageSize.height > maxSize
        
        var finalImage = image
        
        if needsResize {
            // Calculate new size maintaining aspect ratio
            var newSize: NSSize
            if imageSize.width > imageSize.height {
                let ratio = maxSize / imageSize.width
                newSize = NSSize(width: maxSize, height: imageSize.height * ratio)
            } else {
                let ratio = maxSize / imageSize.height
                newSize = NSSize(width: imageSize.width * ratio, height: maxSize)
            }
            
            // Resize the image
            let resized = NSImage(size: newSize)
            resized.lockFocus()
            
            image.draw(
                in: NSRect(origin: .zero, size: newSize),
                from: NSRect(origin: .zero, size: imageSize),
                operation: .copy,
                fraction: 1.0
            )
            
            resized.unlockFocus()
            finalImage = resized
        }
        
        // Convert to PNG with compression
        guard let tiffData = finalImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let compressedData = bitmapRep.representation(
                using: .png,
                properties: [.compressionFactor: NSNumber(value: quality)]
              ) else {
            return nil
        }
        
        return compressedData
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
