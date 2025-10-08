    private func showShareAppDialog() {
        let shareText = """
        🎉 Check out Clnbrd - The Ultimate Clipboard Cleaner for Mac!
        
        ✨ Features:
        • 🧹 Automatically strips formatting from copied text
        • ⚡ Instant paste with ⌘⌥V hotkey
        • 🤖 Auto-clean on copy (optional)
        • 📋 Menu bar integration
        • 🔐 Fully notarized by Apple
        • 🚀 Lightweight and privacy-focused
        
        Perfect for writers, developers, and anyone who copies text from websites, PDFs, or documents!
        
        Download: https://github.com/oliveoi1/Clnbrd/releases/latest
        
        #Clnbrd #MacApp #Productivity #ClipboardCleaner
        """
        
        // Create a sharing picker with all available services
        let sharingPicker = NSSharingServicePicker(items: [shareText])
        
        // Show the picker relative to the menu bar button
        if let statusItem = menuBarManager.statusItem,
           let button = statusItem.button {
            sharingPicker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        } else {
            // Fallback: show in center of screen
            sharingPicker.show(relativeTo: NSRect(x: 0, y: 0, width: 1, height: 1), of: NSApp.keyWindow?.contentView ?? NSView(), preferredEdge: .minY)
        }
    }
