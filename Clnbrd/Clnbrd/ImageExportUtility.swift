import Foundation
import AppKit
import os.log

/// Utility class for exporting images with various format and processing options
class ImageExportUtility {
    private static let logger = Logger(subsystem: "com.allanalomes.Clnbrd", category: "ImageExport")
    
    // MARK: - Export Methods
    
    /// Export an image to a file with the configured settings
    static func exportImage(
        _ image: NSImage,
        to url: URL,
        format: ClipboardHistoryManager.ImageExportFormat? = nil,
        scaleRetinaTo1x: Bool? = nil,
        convertToSRGB: Bool? = nil,
        addBorder: Bool? = nil,
        jpegQuality: Double? = nil
    ) throws {
        // Use provided settings or fall back to manager defaults
        let exportFormat = format ?? ClipboardHistoryManager.shared.imageExportFormat
        let shouldScaleRetina = scaleRetinaTo1x ?? ClipboardHistoryManager.shared.scaleRetinaTo1x
        let shouldConvertSRGB = convertToSRGB ?? ClipboardHistoryManager.shared.convertToSRGB
        let shouldAddBorder = addBorder ?? ClipboardHistoryManager.shared.addBorderToScreenshots
        let quality = jpegQuality ?? ClipboardHistoryManager.shared.jpegExportQuality
        
        // Process the image
        var processedImage = image
        
        // 1. Scale retina to 1x if requested
        if shouldScaleRetina {
            processedImage = scaleRetinaImageTo1x(processedImage)
        }
        
        // 2. Add border if requested
        if shouldAddBorder {
            processedImage = addBorderToImage(processedImage)
        }
        
        // 3. Convert to appropriate format and save
        let imageData = try convertImageToData(
            processedImage,
            format: exportFormat,
            quality: quality,
            convertToSRGB: shouldConvertSRGB
        )
        
        try imageData.write(to: url, options: .atomic)
        
        logger.info("✅ Exported image to: \(url.lastPathComponent) (\(exportFormat.rawValue), \(imageData.count) bytes)")
    }
    
    /// Quick save to Desktop
    static func saveToDesktop(_ image: NSImage, suggestedName: String = "Screenshot") throws -> URL {
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let format = ClipboardHistoryManager.shared.imageExportFormat
        let filename = generateUniqueFilename(baseName: suggestedName, directory: desktopURL, format: format)
        let fileURL = desktopURL.appendingPathComponent(filename)
        
        try exportImage(image, to: fileURL)
        return fileURL
    }
    
    /// Quick save to Downloads
    static func saveToDownloads(_ image: NSImage, suggestedName: String = "Screenshot") throws -> URL {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let format = ClipboardHistoryManager.shared.imageExportFormat
        let filename = generateUniqueFilename(baseName: suggestedName, directory: downloadsURL, format: format)
        let fileURL = downloadsURL.appendingPathComponent(filename)
        
        try exportImage(image, to: fileURL)
        return fileURL
    }
    
    // MARK: - Image Processing
    
    /// Scale a retina image to 1x resolution
    private static func scaleRetinaImageTo1x(_ image: NSImage) -> NSImage {
        let size = image.size
        
        // Check if it's likely a retina image (has representations with 2x or 3x scale)
        let hasRetinaRep = image.representations.contains { rep in
            rep.pixelsWide > Int(size.width) || rep.pixelsHigh > Int(size.height)
        }
        
        guard hasRetinaRep else {
            return image // Not a retina image, return as-is
        }
        
        // Get the pixel dimensions (actual size)
        guard let rep = image.representations.first else {
            return image
        }
        
        let pixelWidth = rep.pixelsWide
        let pixelHeight = rep.pixelsHigh
        
        // Create a new image at 1x scale
        let scaledSize = NSSize(width: pixelWidth, height: pixelHeight)
        let scaledImage = NSImage(size: scaledSize)
        
        scaledImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: scaledSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        scaledImage.unlockFocus()
        
        logger.info("📏 Scaled retina image from \(size) to \(scaledSize)")
        return scaledImage
    }
    
    /// Add a 1px border to the image
    private static func addBorderToImage(_ image: NSImage) -> NSImage {
        let borderWidth: CGFloat = 1.0
        let borderColor = NSColor(white: 0.8, alpha: 1.0) // Light gray border
        
        let originalSize = image.size
        let borderedSize = NSSize(
            width: originalSize.width + borderWidth * 2,
            height: originalSize.height + borderWidth * 2
        )
        
        let borderedImage = NSImage(size: borderedSize)
        borderedImage.lockFocus()
        
        // Draw border (background)
        borderColor.setFill()
        NSRect(origin: .zero, size: borderedSize).fill()
        
        // Draw original image inset by border width
        image.draw(
            in: NSRect(
                x: borderWidth,
                y: borderWidth,
                width: originalSize.width,
                height: originalSize.height
            ),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        
        borderedImage.unlockFocus()
        
        return borderedImage
    }
    
    /// Convert image to data in specified format
    private static func convertImageToData(
        _ image: NSImage,
        format: ClipboardHistoryManager.ImageExportFormat,
        quality: Double,
        convertToSRGB: Bool
    ) throws -> Data {
        guard let tiffData = image.tiffRepresentation,
              var bitmapRep = NSBitmapImageRep(data: tiffData) else {
            throw ExportError.imageConversionFailed
        }
        
        // Convert color space to sRGB if requested
        if convertToSRGB {
            if let srgbColorSpace = NSColorSpace.sRGB {
                bitmapRep = bitmapRep.converting(to: srgbColorSpace, renderingIntent: .default) ?? bitmapRep
            }
        }
        
        // Convert to requested format
        let imageData: Data?
        
        switch format {
        case .png:
            imageData = bitmapRep.representation(using: .png, properties: [:])
            
        case .jpeg:
            imageData = bitmapRep.representation(
                using: .jpeg,
                properties: [.compressionFactor: NSNumber(value: quality)]
            )
            
        case .tiff:
            imageData = bitmapRep.representation(
                using: .tiff,
                properties: [.compressionMethod: NSNumber(value: NSTIFFCompression.lzw.rawValue)]
            )
        }
        
        guard let data = imageData else {
            throw ExportError.imageConversionFailed
        }
        
        return data
    }
    
    // MARK: - Helper Methods
    
    /// Generate a unique filename by appending numbers if file exists
    private static func generateUniqueFilename(
        baseName: String,
        directory: URL,
        format: ClipboardHistoryManager.ImageExportFormat
    ) -> String {
        let fileExtension = format.fileExtension
        var filename = "\(baseName).\(fileExtension)"
        var counter = 1
        
        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(filename).path) {
            filename = "\(baseName) \(counter).\(fileExtension)"
            counter += 1
        }
        
        return filename
    }
    
    /// Show save panel for image export
    static func showSavePanel(
        suggestedName: String = "Screenshot",
        completion: @escaping (URL?) -> Void
    ) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = true
        savePanel.nameFieldStringValue = suggestedName
        savePanel.allowedContentTypes = [.png, .jpeg, .tiff]
        
        let format = ClipboardHistoryManager.shared.imageExportFormat
        savePanel.allowedContentTypes = [format.contentType]
        
        savePanel.begin { response in
            if response == .OK {
                completion(savePanel.url)
            } else {
                completion(nil)
            }
        }
    }
}

// MARK: - Extensions

extension ClipboardHistoryManager.ImageExportFormat {
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .tiff: return "tiff"
        }
    }
    
    var contentType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        }
    }
}

// MARK: - Errors

enum ExportError: Error, LocalizedError {
    case imageConversionFailed
    case fileWriteFailed
    case invalidImage
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to export format"
        case .fileWriteFailed:
            return "Failed to write image file to disk"
        case .invalidImage:
            return "Invalid image data"
        }
    }
}

