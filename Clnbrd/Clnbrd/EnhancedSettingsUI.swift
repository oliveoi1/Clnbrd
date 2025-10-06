//
//  EnhancedSettingsUI.swift
//  Clnbrd
//
//  Enhanced settings UI with granular rule control
//  Created by Allan Alomes on 10/6/2025.
//

import Cocoa

extension SettingsWindow {
    
    /// Create a rule row with checkbox + radio buttons for application mode
    func createRuleRow(for ruleID: CleaningRuleConfigurations.RuleID, yPosition: inout CGFloat) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 30))
        
        let config = CleaningRuleConfigurations.shared.getConfig(for: ruleID)
        
        // Master enable/disable checkbox (left side)
        let checkbox = NSButton(checkboxWithTitle: ruleID.displayName, target: self, action: #selector(ruleCheckboxChanged(_:)))
        checkbox.frame = NSRect(x: 20, y: 5, width: 280, height: 20)
        checkbox.state = config.enabled ? .on : .off
        checkbox.tag = ruleID.hashValue // Use hash for identification
        checkbox.toolTip = ruleID.description
        container.addSubview(checkbox)
        
        // Radio button group for application mode
        let hotkeyRadio = NSButton(radioButtonWithTitle: "On Hotkey", target: self, action: #selector(ruleApplicationModeChanged(_:)))
        hotkeyRadio.frame = NSRect(x: 310, y: 5, width: 110, height: 20)
        hotkeyRadio.state = (config.mode == .onHotkeyOnly) ? .on : .off
        hotkeyRadio.tag = ruleID.hashValue * 100 // Unique tag for hotkey option
        hotkeyRadio.isEnabled = config.enabled
        container.addSubview(hotkeyRadio)
        
        let autoRadio = NSButton(radioButtonWithTitle: "Auto-Clean", target: self, action: #selector(ruleApplicationModeChanged(_:)))
        autoRadio.frame = NSRect(x: 430, y: 5, width: 110, height: 20)
        autoRadio.state = (config.mode == .autoClean) ? .on : .off
        autoRadio.tag = ruleID.hashValue * 100 + 1 // Unique tag for auto option
        autoRadio.isEnabled = config.enabled
        container.addSubview(autoRadio)
        
        return container
    }
    
    /// Setup the granular rules section
    func setupGranularRulesSection(in stackView: NSStackView) {
        // Add section header
        let header = NSTextField(labelWithString: "🎯 Granular Rule Configuration")
        header.font = NSFont.boldSystemFont(ofSize: 16)
        header.textColor = .controlTextColor
        header.isEditable = false
        header.isBordered = false
        header.backgroundColor = .clear
        stackView.addArrangedSubview(header)
        
        // Add description
        let desc = NSTextField(labelWithString: "Choose when each rule applies:")
        desc.font = NSFont.systemFont(ofSize: 11)
        desc.textColor = .secondaryLabelColor
        desc.isEditable = false
        desc.isBordered = false
        desc.backgroundColor = .clear
        stackView.addArrangedSubview(desc)
        
        // Add column headers
        let headerRow = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 25))
        
        let ruleLabel = NSTextField(labelWithString: "Rule")
        ruleLabel.frame = NSRect(x: 45, y: 5, width: 250, height: 18)
        ruleLabel.font = NSFont.boldSystemFont(ofSize: 11)
        ruleLabel.textColor = .secondaryLabelColor
        ruleLabel.isEditable = false
        ruleLabel.isBordered = false
        ruleLabel.backgroundColor = .clear
        headerRow.addSubview(ruleLabel)
        
        let hotkeyLabel = NSTextField(labelWithString: "⌘⌥V Hotkey")
        hotkeyLabel.frame = NSRect(x: 310, y: 5, width: 110, height: 18)
        hotkeyLabel.font = NSFont.boldSystemFont(ofSize: 11)
        hotkeyLabel.textColor = .secondaryLabelColor
        hotkeyLabel.alignment = .center
        hotkeyLabel.isEditable = false
        hotkeyLabel.isBordered = false
        hotkeyLabel.backgroundColor = .clear
        headerRow.addSubview(hotkeyLabel)
        
        let autoLabel = NSTextField(labelWithString: "Auto-Copy")
        autoLabel.frame = NSRect(x: 430, y: 5, width: 110, height: 18)
        autoLabel.font = NSFont.boldSystemFont(ofSize: 11)
        autoLabel.textColor = .secondaryLabelColor
        autoLabel.alignment = .center
        autoLabel.isEditable = false
        autoLabel.isBordered = false
        autoLabel.backgroundColor = .clear
        headerRow.addSubview(autoLabel)
        
        stackView.addArrangedSubview(headerRow)
        
        // Add separator
        let separator1 = NSBox()
        separator1.boxType = .separator
        separator1.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(separator1)
        NSLayoutConstraint.activate([
            separator1.widthAnchor.constraint(equalToConstant: 560),
            separator1.heightAnchor.constraint(equalToConstant: 1)
        ])
        
        // Text Formatting Rules Section
        let textHeader = NSTextField(labelWithString: "📝 Text Formatting")
        textHeader.font = NSFont.boldSystemFont(ofSize: 13)
        textHeader.textColor = .controlTextColor
        textHeader.isEditable = false
        textHeader.isBordered = false
        textHeader.backgroundColor = .clear
        stackView.addArrangedSubview(textHeader)
        
        // Add text formatting rules
        var yPos: CGFloat = 0
        for rule in CleaningRuleConfigurations.RuleID.allCases where rule.category == .textFormatting {
            stackView.addArrangedSubview(createRuleRow(for: rule, yPosition: &yPos))
        }
        
        // Add spacer
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer)
        NSLayoutConstraint.activate([spacer.heightAnchor.constraint(equalToConstant: 15)])
        
        // URL Cleaning Rules Section
        let urlHeader = NSTextField(labelWithString: "🔗 URL Cleaning")
        urlHeader.font = NSFont.boldSystemFont(ofSize: 13)
        urlHeader.textColor = .controlTextColor
        urlHeader.isEditable = false
        urlHeader.isBordered = false
        urlHeader.backgroundColor = .clear
        stackView.addArrangedSubview(urlHeader)
        
        // Add URL cleaning rules
        for rule in CleaningRuleConfigurations.RuleID.allCases where rule.category == .urlCleaning {
            stackView.addArrangedSubview(createRuleRow(for: rule, yPosition: &yPos))
        }
        
        // Add help text
        let helpText = NSTextField(wrappingLabelWithString: """
        ℹ️ On Hotkey: Rules apply only when you press ⌘⌥V
        ℹ️ Auto-Clean: Rules apply automatically whenever you copy
        """)
        helpText.font = NSFont.systemFont(ofSize: 10)
        helpText.textColor = .tertiaryLabelColor
        helpText.isEditable = false
        helpText.isBordered = false
        helpText.backgroundColor = .clear
        helpText.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(helpText)
        
        // Add separator
        let separator2 = NSBox()
        separator2.boxType = .separator
        separator2.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(separator2)
        NSLayoutConstraint.activate([
            separator2.widthAnchor.constraint(equalToConstant: 560),
            separator2.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
    
    // MARK: - Actions
    
    @objc func ruleCheckboxChanged(_ sender: NSButton) {
        let ruleHash = sender.tag
        
        // Find the rule by hash (this is a simplified approach)
        for rule in CleaningRuleConfigurations.RuleID.allCases {
            if rule.hashValue == ruleHash {
                CleaningRuleConfigurations.shared.setEnabled(sender.state == .on, for: rule)
                
                // Update the corresponding radio buttons
                if let container = sender.superview {
                    for view in container.subviews {
                        if let radio = view as? NSButton, radio.tag / 100 == ruleHash {
                            radio.isEnabled = sender.state == .on
                        }
                    }
                }
                break
            }
        }
    }
    
    @objc func ruleApplicationModeChanged(_ sender: NSButton) {
        let ruleHash = sender.tag / 100
        let isAutoClean = (sender.tag % 100) == 1
        
        // Find the rule and update mode
        for rule in CleaningRuleConfigurations.RuleID.allCases {
            if rule.hashValue == ruleHash {
                let newMode: RuleApplicationMode = isAutoClean ? .autoClean : .onHotkeyOnly
                CleaningRuleConfigurations.shared.setMode(newMode, for: rule)
                
                // Update the other radio button in the group
                if let container = sender.superview {
                    for view in container.subviews {
                        if let radio = view as? NSButton, radio.tag / 100 == ruleHash, radio != sender {
                            radio.state = .off
                        }
                    }
                }
                sender.state = .on
                break
            }
        }
    }
}

