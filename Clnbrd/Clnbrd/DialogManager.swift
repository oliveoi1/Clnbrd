import Cocoa
import os.log

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "DialogManager")

class DialogManager {
    // MARK: - Properties

    private weak var appDelegate: AppDelegate?

    // MARK: - Initialization

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    // MARK: - Welcome Dialog

    func showWelcomeDialog() {
        let alert = NSAlert()
        alert.messageText = "Welcome to Clnbrd!"
        alert.informativeText = """
        Clnbrd is now ready to help you clean your clipboard content.

        Key Features:
        • Automatically clean clipboard when copying
        • Manual cleaning with ⌘⇧V
        • Customizable cleaning rules
        • Settings accessible from menu bar

        To get started:
        1. Enable Accessibility permissions in System Settings > Privacy & Security > Accessibility
        2. Configure your cleaning rules in Settings
        3. Start using ⌘⇧V to clean clipboard content

        For more help, check the Installation Guide in the menu.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Get Started")
        alert.addButton(withTitle: "Show Installation Guide")

        let response = alert.runModal()

        if response == .alertSecondButtonReturn {
            showInstallationGuide()
        }
    }

    // MARK: - Installation Guide

    func showInstallationGuide() {
        let alert = NSAlert()
        alert.messageText = "Installation Guide"
        alert.informativeText = """
        CLNBRD INSTALLATION GUIDE

        IMPORTANT: macOS SECURITY WARNING
        When you first try to open Clnbrd, macOS will show a security warning because the app is not signed by Apple.

        WHAT TO EXPECT:
        • macOS will show: "Clnbrd.app cannot be opened because the developer cannot be verified"
        • This is normal for apps not distributed through the App Store

        HOW TO PROCEED:
        1. In the security warning dialog, click "Cancel"
        2. Go to System Settings > Privacy & Security
        3. Scroll down to "Security" section
        4. Click "Open Anyway" next to the Clnbrd warning
        5. Confirm by clicking "Open" in the next dialog

        ALTERNATIVE METHOD:
        1. Right-click (Control-click) on Clnbrd.app in Finder
        2. Select "Open" from the context menu
        3. Click "Open" in the confirmation dialog

        WHY THIS HAPPENS:
        • Apple requires code signing for security
        • Unsigned apps trigger security warnings
        • This is a limitation of the current development setup

        TROUBLESHOOTING:
        • If you can't find the "Open Anyway" button, restart your Mac
        • The warning will reappear after each update until the app is properly signed

        For more help, visit: https://github.com/oliveoi1/Clnbrd
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Got It!")
        alert.runModal()
    }

    func showInstallationGuideContent() {
        let alert = NSAlert()
        alert.messageText = "Installation Guide"
        alert.informativeText = """
        CLNBRD INSTALLATION GUIDE

        IMPORTANT: macOS SECURITY WARNING
        When you first try to open Clnbrd, macOS will show a security warning because the app is not signed by Apple.

        WHAT TO EXPECT:
        • macOS will show: "Clnbrd.app cannot be opened because the developer cannot be verified"
        • This is normal for apps not distributed through the App Store

        HOW TO PROCEED:
        1. In the security warning dialog, click "Cancel"
        2. Go to System Settings > Privacy & Security
        3. Scroll down to "Security" section
        4. Click "Open Anyway" next to the Clnbrd warning
        5. Confirm by clicking "Open" in the next dialog

        ALTERNATIVE METHOD:
        1. Right-click (Control-click) on Clnbrd.app in Finder
        2. Select "Open" from the context menu
        3. Click "Open" in the confirmation dialog

        WHY THIS HAPPENS:
        • Apple requires code signing for security
        • Unsigned apps trigger security warnings
        • This is a limitation of the current development setup

        TROUBLESHOOTING:
        • If you can't find the "Open Anyway" button, restart your Mac
        • The warning will reappear after each update until the app is properly signed

        For more help, visit: https://github.com/oliveoi1/Clnbrd
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Got It!")
        alert.runModal()
    }

    // MARK: - Version History

    func showVersionHistory() {
        let versionWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        versionWindow.title = "Clnbrd Version History"
        versionWindow.center()
        versionWindow.setFrameAutosaveName("VersionWindow")
        versionWindow.isReleasedWhenClosed = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.font = NSFont.systemFont(ofSize: 13)

        let attributedString = NSMutableAttributedString()

        // Title
        let titleFont = NSFont.boldSystemFont(ofSize: 18)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.labelColor
        ]
        attributedString.append(NSAttributedString(string: "Clnbrd Version History\n\n", attributes: titleAttributes))

        // Version entries
        let versions = getVersionHistory()
        for version in versions {
            attributedString.append(version)
            attributedString.append(NSAttributedString(string: "\n\n"))
        }

        textView.textStorage?.setAttributedString(attributedString)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false

        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor, constant: 15),
            textView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor, constant: -15),
            textView.widthAnchor.constraint(greaterThanOrEqualToConstant: 400),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 2000)
        ])

        versionWindow.contentView = scrollView
        versionWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func getVersionHistory() -> [NSMutableAttributedString] {
        let bodyFont = NSFont.systemFont(ofSize: 13)
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor
        ]

        let dateFont = NSFont.systemFont(ofSize: 12)
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let featureFont = NSFont.systemFont(ofSize: 13)
        let featureAttributes: [NSAttributedString.Key: Any] = [
            .font: featureFont,
            .foregroundColor: NSColor.systemBlue
        ]

        return [
            createVersionEntry("Version 1.3 (Build 34) - October 2025",
                             date: "October 2025",
                             features: ["Major code refactoring and architecture improvements",
                                       "Profile Management System for saving rule configurations",
                                       "Custom Cleaning Rules for user-defined find/replace operations",
                                       "SwiftLint integration for code quality enforcement",
                                       "Performance optimizations and memory management improvements"],
                             attributes: (bodyAttributes, dateAttributes, featureAttributes)),

            createVersionEntry("Version 1.2 (Build 33) - September 2025",
                             date: "September 2025",
                             features: ["Enhanced cleaning rule customization",
                                       "Improved user interface and settings management",
                                       "Bug fixes and stability improvements"],
                             attributes: (bodyAttributes, dateAttributes, featureAttributes)),

            createVersionEntry("Version 1.1 (Build 32) - August 2025",
                             date: "August 2025",
                             features: ["Initial release with core clipboard cleaning functionality",
                                       "Basic cleaning rules and settings interface",
                                       "Menu bar integration and hotkey support"],
                             attributes: (bodyAttributes, dateAttributes, featureAttributes)),

            createVersionEntry("Version 1.0 (Build 31) - July 2025",
                             date: "July 2025",
                             features: ["Proof of concept and initial development",
                                       "Basic clipboard monitoring and cleaning"],
                             attributes: (bodyAttributes, dateAttributes, featureAttributes))
        ]
    }

    private func createVersionEntry(_ title: String, date: String, features: [String], attributes: ([NSAttributedString.Key: Any], [NSAttributedString.Key: Any], [NSAttributedString.Key: Any])) -> NSMutableAttributedString {
        let (_, dateAttributes, featureAttributes) = attributes
        let entry = NSMutableAttributedString()

        // Version title
        let titleFont = NSFont.boldSystemFont(ofSize: 16)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.labelColor
        ]
        entry.append(NSAttributedString(string: "\(title)\n", attributes: titleAttributes))

        // Release date
        entry.append(NSAttributedString(string: "Released: \(date)\n", attributes: dateAttributes))

        // Features
        for feature in features {
            entry.append(NSAttributedString(string: "• \(feature)\n", attributes: featureAttributes))
        }

        return entry
    }

    // MARK: - Accessibility Warnings

    func showAccessibilityWarning() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = """
        Clnbrd needs Accessibility permissions to monitor clipboard changes and provide hotkey functionality.

        To enable:
        1. Open System Settings
        2. Go to Privacy & Security > Accessibility
        3. Enable Clnbrd in the list of allowed apps

        Without these permissions, Clnbrd will only work with manual cleaning (⌘⇧V).
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    func showPostUpdateAccessibilityWarning() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Check"
        alert.informativeText = """
        After updating Clnbrd, please verify that Accessibility permissions are still enabled.

        If clipboard monitoring or hotkeys aren't working:
        1. Open System Settings > Privacy & Security > Accessibility
        2. Make sure Clnbrd is still checked in the list
        3. If needed, uncheck and recheck Clnbrd to refresh permissions

        This is sometimes required after app updates due to macOS security policies.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Check Permissions")
        alert.addButton(withTitle: "Skip")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    func showPostUpdateMessage() {
        let alert = NSAlert()
        alert.messageText = "Clnbrd Updated Successfully!"
        alert.informativeText = """
        Clnbrd has been updated to the latest version.

        What's New:
        • Improved performance and stability
        • Enhanced cleaning capabilities
        • Better user interface

        If you experience any issues:
        • Check that Accessibility permissions are still enabled in System Settings
        • Restart Clnbrd if needed
        • Check the Installation Guide in the menu for troubleshooting

        Thank you for using Clnbrd!
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Got It!")
        alert.runModal()
    }
    
    func showSamples() {
        let alert = NSAlert()
        alert.messageText = "Clnbrd Cleaning Samples"
        alert.informativeText = """
        Here are some examples of what Clnbrd can clean:
        
        ✓ Removes formatting (bold, italic, colors)
        ✓ Strips tracking URLs and parameters
        ✓ Cleans zero-width characters
        ✓ Removes extra spaces and line breaks
        ✓ Applies custom cleaning rules
        
        Try it out:
        1. Copy some formatted text
        2. Use ⌘⌥V to clean and paste
        3. See the difference!
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
