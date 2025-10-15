#!/usr/bin/env swift

import Cocoa
import CoreGraphics

/// Generates modern macOS app icon following Apple Big Sur+ design standards
class AppIconGenerator {
    
    let masterSize: CGFloat = 1024
    let safeAreaMargin: CGFloat = 0.18 // 18% margin
    
    var contentSize: CGFloat {
        masterSize * (1 - 2 * safeAreaMargin)
    }
    
    func generate() {
        print("🎨 Generating Clnbrd app icon (Apple 2025 standards)...")
        
        // Generate master 1024x1024 icon
        guard let masterIcon = generateMasterIcon() else {
            print("❌ Failed to generate master icon")
            return
        }
        
        // Export all required sizes (FINAL CORRECTION - macOS icon pixel requirements)
        let sizes: [(String, Int)] = [
            ("icon_16x16.png", 16),           // Menu bar: 16x16 pixels
            ("icon_16x16@2x.png", 32),       // Retina menu bar: 32x32 pixels (16@2x)
            ("icon_32x32.png", 32),          // Finder list: 32x32 pixels
            ("icon_32x32@2x.png", 64),       // Retina list: 64x64 pixels (32@2x)
            ("icon_128x128.png", 128),       // Finder icon: 128x128 pixels
            ("icon_128x128@2x.png", 256),    // Retina icon: 256x256 pixels (128@2x)
            ("icon_256x256.png", 256),       // Large icon: 256x256 pixels
            ("icon_256x256@2x.png", 512),    // Retina large: 512x512 pixels (256@2x)
            ("icon_512x512.png", 512),       // Very large: 512x512 pixels
            ("icon_512x512@2x.png", 1024)    // Master: 1024x1024 pixels (512@2x)
        ]
        
        // Get current directory and build absolute path
        let currentDir = FileManager.default.currentDirectoryPath
        let outputDir = "\(currentDir)/Clnbrd/Clnbrd/Assets.xcassets/AppIcon.appiconset"
        
        // Create directory if needed
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        
        for (filename, size) in sizes {
            if let resizedImage = resize(image: masterIcon, to: CGSize(width: size, height: size)) {
                let outputPath = "\(outputDir)/\(filename)"
                if save(image: resizedImage, to: outputPath) {
                    print("✅ Generated: \(filename)")
                } else {
                    print("⚠️  Failed to save: \(filename)")
                }
            }
        }
        
        print("🎉 App icon generation complete!")
    }
    
    func generateMasterIcon() -> NSImage? {
        let size = NSSize(width: masterSize, height: masterSize)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }
        
        // LAYER 1: Gradient Background
        drawBackground(in: context, size: size)
        
        // LAYER 2: Document Shadow
        let documentFrame = getDocumentFrame()
        drawDocumentShadow(in: context, frame: documentFrame)
        
        // LAYER 3: Document Base
        drawDocument(in: context, frame: documentFrame)
        
        // LAYER 4: Content Lines
        drawContentLines(in: context, documentFrame: documentFrame)
        
        // LAYER 5: Sparkle (magic cleaning symbol)
        drawSparkle(in: context, documentFrame: documentFrame)
        
        // LAYER 6: Glass Shine Overlay
        drawGlassShine(in: context, size: size)
        
        image.unlockFocus()
        
        return image
    }
    
    // MARK: - Drawing Methods
    
    func drawBackground(in context: CGContext, size: NSSize) {
        // Rich blue gradient (liquid glass theme)
        let colors = [
            NSColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 1.0).cgColor, // #4A90E2
            NSColor(red: 0.21, green: 0.48, blue: 0.74, alpha: 1.0).cgColor, // #357ABD
            NSColor(red: 0.18, green: 0.37, blue: 0.60, alpha: 1.0).cgColor  // #2D5F99
        ]
        
        let locations: [CGFloat] = [0.0, 0.5, 1.0]
        
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: locations
        ) else { return }
        
        // Draw diagonal gradient (135° angle)
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size.height),
            end: CGPoint(x: size.width, y: 0),
            options: []
        )
        
        // Add subtle radial overlay for depth
        let radialColors = [
            NSColor.white.withAlphaComponent(0.08).cgColor,
            NSColor.clear.cgColor
        ]
        
        if let radialGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: radialColors as CFArray,
            locations: [0.0, 1.0]
        ) {
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            context.drawRadialGradient(
                radialGradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: size.width * 0.6,
                options: []
            )
        }
    }
    
    func getDocumentFrame() -> CGRect {
        // Document is 60% of content area width, 75% height
        let width = contentSize * 0.6
        let height = contentSize * 0.75
        let margin = masterSize * safeAreaMargin
        let x = (masterSize - width) / 2
        let y = margin + (contentSize - height) / 2
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    func drawDocumentShadow(in context: CGContext, frame: CGRect) {
        context.saveGState()
        
        // Soft contact shadow
        context.setShadow(
            offset: CGSize(width: 0, height: -8),
            blur: 20,
            color: NSColor.black.withAlphaComponent(0.3).cgColor
        )
        
        let path = CGPath(
            roundedRect: frame,
            cornerWidth: 40,
            cornerHeight: 40,
            transform: nil
        )
        
        context.setFillColor(NSColor.white.cgColor)
        context.addPath(path)
        context.fillPath()
        
        context.restoreGState()
    }
    
    func drawDocument(in context: CGContext, frame: CGRect) {
        // Soft white base with subtle gradient
        let path = CGPath(
            roundedRect: frame,
            cornerWidth: 40,
            cornerHeight: 40,
            transform: nil
        )
        
        context.saveGState()
        context.addPath(path)
        context.clip()
        
        // Very subtle top-to-bottom gradient
        let docColors = [
            NSColor(white: 0.98, alpha: 1.0).cgColor,
            NSColor(white: 0.96, alpha: 1.0).cgColor
        ]
        
        if let docGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: docColors as CFArray,
            locations: [0.0, 1.0]
        ) {
            context.drawLinearGradient(
                docGradient,
                start: CGPoint(x: frame.midX, y: frame.maxY),
                end: CGPoint(x: frame.midX, y: frame.minY),
                options: []
            )
        }
        
        context.restoreGState()
        
        // Inner shadow (top edge)
        context.saveGState()
        context.addPath(path)
        context.clip()
        
        let innerShadowPath = CGMutablePath()
        innerShadowPath.addRect(frame.insetBy(dx: -20, dy: -20))
        
        let innerPath = CGPath(
            roundedRect: frame,
            cornerWidth: 40,
            cornerHeight: 40,
            transform: nil
        )
        innerShadowPath.addPath(innerPath)
        
        context.setFillColor(NSColor.black.withAlphaComponent(0.08).cgColor)
        context.setShadow(
            offset: CGSize(width: 0, height: 2),
            blur: 4,
            color: NSColor.black.withAlphaComponent(0.15).cgColor
        )
        context.addPath(innerShadowPath)
        context.fillPath(using: .evenOdd)
        
        context.restoreGState()
    }
    
    func drawContentLines(in context: CGContext, documentFrame: CGRect) {
        let lineWidth = documentFrame.width * 0.5
        let lineHeight = documentFrame.height * 0.06
        let lineRadius = lineHeight / 2
        
        // Y positions for 3 lines (evenly spaced in center area)
        let startY = documentFrame.minY + documentFrame.height * 0.35
        let spacing = documentFrame.height * 0.12
        
        for i in 0..<3 {
            let y = startY + CGFloat(i) * spacing
            let lineFrame = CGRect(
                x: documentFrame.midX - lineWidth / 2,
                y: y,
                width: lineWidth,
                height: lineHeight
            )
            
            // Line shadow
            context.saveGState()
            context.setShadow(
                offset: CGSize(width: 0, height: -2),
                blur: 4,
                color: NSColor.black.withAlphaComponent(0.1).cgColor
            )
            
            // Line with gradient (matches background colors)
            let linePath = CGPath(
                roundedRect: lineFrame,
                cornerWidth: lineRadius,
                cornerHeight: lineRadius,
                transform: nil
            )
            
            let lineColors = [
                NSColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 1.0).cgColor,
                NSColor(red: 0.21, green: 0.48, blue: 0.74, alpha: 1.0).cgColor
            ]
            
            if let lineGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: lineColors as CFArray,
                locations: [0.0, 1.0]
            ) {
                context.addPath(linePath)
                context.clip()
                
                context.drawLinearGradient(
                    lineGradient,
                    start: CGPoint(x: lineFrame.minX, y: lineFrame.midY),
                    end: CGPoint(x: lineFrame.maxX, y: lineFrame.midY),
                    options: []
                )
            }
            
            context.restoreGState()
        }
    }
    
    func drawSparkle(in context: CGContext, documentFrame: CGRect) {
        // Golden sparkle in top-right area
        let sparkleSize: CGFloat = documentFrame.width * 0.20
        let x = documentFrame.maxX - sparkleSize - 30
        let y = documentFrame.maxY - sparkleSize - 30
        
        // Glow effect
        context.saveGState()
        context.setShadow(
            offset: .zero,
            blur: 15,
            color: NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.6).cgColor
        )
        
        // Draw 4-point star
        drawStar(
            in: context,
            center: CGPoint(x: x + sparkleSize / 2, y: y + sparkleSize / 2),
            size: sparkleSize,
            color: NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        )
        
        context.restoreGState()
    }
    
    func drawStar(in context: CGContext, center: CGPoint, size: CGFloat, color: NSColor) {
        let path = CGMutablePath()
        let points = 4 // 4-point star
        let outerRadius = size / 2
        let innerRadius = size / 5
        
        for i in 0..<(points * 2) {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        
        context.setFillColor(color.cgColor)
        context.addPath(path)
        context.fillPath()
    }
    
    func drawGlassShine(in context: CGContext, size: NSSize) {
        // Diagonal highlight stripe (liquid glass reflection)
        context.saveGState()
        
        let shineWidth: CGFloat = 200
        let shineAngle: CGFloat = 30 * .pi / 180
        
        context.translateBy(x: size.width * 0.3, y: size.height * 0.7)
        context.rotate(by: shineAngle)
        
        let shineRect = CGRect(x: 0, y: 0, width: shineWidth, height: size.height)
        
        let shineColors = [
            NSColor.white.withAlphaComponent(0.2).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ]
        
        if let shineGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: shineColors as CFArray,
            locations: [0.0, 1.0]
        ) {
            context.drawLinearGradient(
                shineGradient,
                start: CGPoint(x: shineRect.minX, y: shineRect.midY),
                end: CGPoint(x: shineRect.maxX, y: shineRect.midY),
                options: []
            )
        }
        
        context.restoreGState()
    }
    
    // MARK: - Helper Methods
    
    func resize(image: NSImage, to newSize: CGSize) -> NSImage? {
        // Use Core Graphics for precise pixel control
        let width = Int(newSize.width)
        let height = Int(newSize.height)
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // Create bitmap context with exact pixel dimensions
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        // Draw the image scaled to exact size
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: newSize))
        
        guard let resizedCGImage = context.makeImage() else {
            return nil
        }
        
        // Create NSImage from the resized CGImage
        let resizedImage = NSImage(cgImage: resizedCGImage, size: newSize)
        
        return resizedImage
    }
    
    func save(image: NSImage, to path: String) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return false
        }
        
        do {
            try pngData.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            print("Error saving to \(path): \(error)")
            return false
        }
    }
}

// MARK: - Main Execution

print("🚀 Clnbrd App Icon Generator")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

let generator = AppIconGenerator()
generator.generate()

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✨ Done! Check Assets.xcassets/AppIcon.appiconset")

