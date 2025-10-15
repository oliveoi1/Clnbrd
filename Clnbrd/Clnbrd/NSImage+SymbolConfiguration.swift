import Cocoa

/// Modern SF Symbol utilities for Apple 2025 design standards
extension NSImage {
    // MARK: - Symbol Configuration Presets
    
    /// Creates a symbol with hierarchical rendering (single color with opacity variations)
    static func symbol(
        _ name: String,
        size: CGFloat = 16,
        weight: NSFont.Weight = .medium,
        scale: NSImage.SymbolScale = .medium,
        color: NSColor = .controlAccentColor
    ) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight, scale: scale)
            .applying(NSImage.SymbolConfiguration(hierarchicalColor: color))
        
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }
    
    /// Creates a symbol with multicolor rendering (uses symbol's built-in colors)
    static func symbolMulticolor(
        _ name: String,
        size: CGFloat = 16,
        weight: NSFont.Weight = .medium,
        scale: NSImage.SymbolScale = .medium
    ) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight, scale: scale)
            .applying(NSImage.SymbolConfiguration.preferringMulticolor())
        
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }
    
    /// Creates a symbol with palette rendering (custom multi-color)
    static func symbolPalette(
        _ name: String,
        size: CGFloat = 16,
        weight: NSFont.Weight = .medium,
        scale: NSImage.SymbolScale = .medium,
        colors: [NSColor]
    ) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight, scale: scale)
            .applying(NSImage.SymbolConfiguration(paletteColors: colors))
        
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }
    
    /// Creates a monochrome symbol (single flat color, no hierarchy)
    static func symbolMono(
        _ name: String,
        size: CGFloat = 16,
        weight: NSFont.Weight = .medium,
        scale: NSImage.SymbolScale = .medium,
        color: NSColor = .labelColor
    ) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight, scale: scale)
        
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        
        // Apply tint by creating a new image with the color
        guard let image = image else { return nil }
        
        let tinted = NSImage(size: image.size)
        tinted.lockFocus()
        color.set()
        image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
        tinted.unlockFocus()
        
        return tinted
    }
    
    // MARK: - Semantic Presets (for common use cases)
    
    /// Menu bar icon style: medium weight, compact
    static func menuBarSymbol(_ name: String, color: NSColor = .labelColor) -> NSImage? {
        return symbol(name, size: 14, weight: .medium, scale: .medium, color: color)
    }
    
    /// Large hero icon for onboarding/empty states
    static func heroSymbol(_ name: String, color: NSColor = .controlAccentColor) -> NSImage? {
        return symbol(name, size: 64, weight: .semibold, scale: .large, color: color)
    }
    
    /// Card header icon for settings sections
    static func cardSymbol(_ name: String, color: NSColor = .secondaryLabelColor) -> NSImage? {
        return symbol(name, size: 18, weight: .medium, scale: .medium, color: color)
    }
    
    /// Status indicator icon (checkmarks, warnings, etc.)
    static func statusSymbol(_ name: String, useMulticolor: Bool = true) -> NSImage? {
        if useMulticolor {
            return symbolMulticolor(name, size: 16, weight: .semibold, scale: .medium)
        } else {
            return symbol(name, size: 16, weight: .semibold, scale: .medium)
        }
    }
}
