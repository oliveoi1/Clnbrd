import Cocoa

/// Liquid glass visual effects for NSImageView
extension NSImageView {
    // MARK: - Vibrancy (for glass contexts)
    
    /// Wraps the image view in a vibrancy effect view for liquid glass contexts
    func wrapInVibrancy(material: NSVisualEffectView.Material = .hudWindow) -> NSVisualEffectView {
        let vibrancyView = NSVisualEffectView(frame: self.frame)
        vibrancyView.material = material
        vibrancyView.state = .active
        vibrancyView.blendingMode = .withinWindow
        vibrancyView.wantsLayer = true
        vibrancyView.autoresizingMask = self.autoresizingMask
        
        // Move image view inside vibrancy
        self.removeFromSuperview()
        self.frame = vibrancyView.bounds
        self.autoresizingMask = [.width, .height]
        vibrancyView.addSubview(self)
        
        return vibrancyView
    }
    
    // MARK: - Depth & Shadows
    
    /// Adds subtle floating shadow for depth
    func addFloatingShadow(offset: CGSize = NSSize(width: 0, height: 2), radius: CGFloat = 4, opacity: CGFloat = 0.15) {
        self.wantsLayer = true
        self.shadow = NSShadow()
        self.shadow?.shadowColor = NSColor.black.withAlphaComponent(opacity)
        self.shadow?.shadowOffset = offset
        self.shadow?.shadowBlurRadius = radius
    }
    
    /// Adds glow effect beneath icon
    func addGlowEffect(color: NSColor = .controlAccentColor, radius: CGFloat = 8, opacity: CGFloat = 0.3) {
        self.wantsLayer = true
        
        guard let layer = self.layer else { return }
        
        // Create glow layer
        let glowLayer = CALayer()
        glowLayer.frame = layer.bounds
        glowLayer.backgroundColor = color.cgColor
        glowLayer.shadowColor = color.cgColor
        glowLayer.shadowOffset = .zero
        glowLayer.shadowRadius = radius
        glowLayer.shadowOpacity = Float(opacity)
        glowLayer.cornerRadius = layer.bounds.width / 2
        
        layer.insertSublayer(glowLayer, at: 0)
    }
    
    // MARK: - Hover Effects
    
    /// Animates scale up with glow (for interactive icons)
    func animateHoverIn(scale: CGFloat = 1.1, duration: TimeInterval = 0.2) {
        self.wantsLayer = true
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            self.layer?.transform = CATransform3DMakeScale(scale, scale, 1.0)
            
            // Enhance shadow on hover
            if let shadow = self.shadow {
                shadow.shadowBlurRadius *= 1.5
                shadow.shadowOffset = NSSize(width: 0, height: shadow.shadowOffset.height * 1.5)
            }
        }
    }
    
    /// Animates scale down (hover out)
    func animateHoverOut(duration: TimeInterval = 0.2) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            self.layer?.transform = CATransform3DIdentity
            
            // Restore shadow
            if let shadow = self.shadow {
                shadow.shadowBlurRadius /= 1.5
                shadow.shadowOffset = NSSize(width: 0, height: shadow.shadowOffset.height / 1.5)
            }
        }
    }
    
    // MARK: - Combined Presets
    
    /// Applies full liquid glass treatment: vibrancy + shadow + proper sizing
    func applyLiquidGlassStyle(addShadow: Bool = true, addGlow: Bool = false, glowColor: NSColor? = nil) {
        self.wantsLayer = true
        
        // Enable template rendering for symbols to work with vibrancy
        if let image = self.image {
            image.isTemplate = true
        }
        
        if addShadow {
            addFloatingShadow()
        }
        
        if addGlow, let color = glowColor {
            addGlowEffect(color: color)
        }
    }
}

/// Interactive icon view with hover effects
class InteractiveIconView: NSImageView {
    private var trackingArea: NSTrackingArea?
    var hoverEnabled: Bool = true
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        
        guard hoverEnabled else { return }
        animateHoverIn()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        guard hoverEnabled else { return }
        animateHoverOut()
    }
}
