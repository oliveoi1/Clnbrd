import Cocoa
import os.log

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "hotkey")

/// Represents a hotkey action that can be configured
enum HotkeyAction: String, CaseIterable {
    case cleanAndPaste = "Clean & Paste"
    case showHistory = "Show History"
    case captureScreenshot = "Capture Screenshot"
    
    var defaultKeyCode: UInt16 {
        switch self {
        case .cleanAndPaste: return 9  // V
        case .showHistory: return 4     // H
        case .captureScreenshot: return 8  // C
        }
    }
    
    var defaultModifiers: NSEvent.ModifierFlags {
        switch self {
        case .cleanAndPaste: return [.command, .option]
        case .showHistory: return [.command, .shift]
        case .captureScreenshot: return [.command, .option]
        }
    }
}

/// Represents a configured hotkey
struct HotkeyConfiguration: Codable, Equatable {
    let action: String  // HotkeyAction.rawValue
    var keyCode: UInt16
    var modifiers: ModifierFlags
    var isEnabled: Bool
    
    struct ModifierFlags: Codable, Equatable {
        var command: Bool
        var option: Bool
        var shift: Bool
        var control: Bool
        
        init(command: Bool = false, option: Bool = false, shift: Bool = false, control: Bool = false) {
            self.command = command
            self.option = option
            self.shift = shift
            self.control = control
        }
        
        init(from nsModifiers: NSEvent.ModifierFlags) {
            self.command = nsModifiers.contains(.command)
            self.option = nsModifiers.contains(.option)
            self.shift = nsModifiers.contains(.shift)
            self.control = nsModifiers.contains(.control)
        }
        
        func toNSModifierFlags() -> NSEvent.ModifierFlags {
            var flags: NSEvent.ModifierFlags = []
            if command { flags.insert(.command) }
            if option { flags.insert(.option) }
            if shift { flags.insert(.shift) }
            if control { flags.insert(.control) }
            return flags
        }
        
        var displayString: String {
            var parts: [String] = []
            if control { parts.append("⌃") }
            if option { parts.append("⌥") }
            if shift { parts.append("⇧") }
            if command { parts.append("⌘") }
            return parts.joined()
        }
    }
    
    var displayString: String {
        guard isEnabled else { return "Disabled" }
        let keyName = KeyCodeMapper.keyCodeToString(keyCode)
        return "\(modifiers.displayString)\(keyName)"
    }
}

/// Maps macOS key codes to readable strings
struct KeyCodeMapper {
    static func keyCodeToString(_ keyCode: UInt16) -> String {
        // Common key mappings
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        case 36: return "↩"  // Return
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "⌫"  // Delete
        case 53: return "Esc"  // Escape
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "Key \(keyCode)"
        }
    }
    
    static func stringToKeyCode(_ string: String) -> UInt16? {
        let uppercased = string.uppercased()
        switch uppercased {
        case "A": return 0
        case "S": return 1
        case "D": return 2
        case "F": return 3
        case "H": return 4
        case "G": return 5
        case "Z": return 6
        case "X": return 7
        case "C": return 8
        case "V": return 9
        case "B": return 11
        case "Q": return 12
        case "W": return 13
        case "E": return 14
        case "R": return 15
        case "Y": return 16
        case "T": return 17
        case "O": return 31
        case "U": return 32
        case "I": return 34
        case "P": return 35
        case "L": return 37
        case "J": return 38
        case "K": return 40
        case "N": return 45
        case "M": return 46
        case "RETURN", "↩": return 36
        case "TAB", "⇥": return 48
        case "SPACE": return 49
        case "DELETE", "⌫": return 51
        case "ESCAPE", "⎋", "ESC": return 53
        default: return nil
        }
    }
}

/// Manages hotkey registration and configuration
class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var eventMonitors: [String: Any] = [:]
    private var configurations: [String: HotkeyConfiguration] = [:]
    
    private init() {
        loadConfigurations()
    }
    
    // MARK: - Configuration Management
    
    func getConfiguration(for action: HotkeyAction) -> HotkeyConfiguration {
        if let config = configurations[action.rawValue] {
            logger.debug("Found config for \(action.rawValue): \(config.displayString), enabled: \(config.isEnabled)")
            return config
        }
        
        // Return default configuration
        logger.info("Creating default config for \(action.rawValue)")
        let defaultConfig = HotkeyConfiguration(
            action: action.rawValue,
            keyCode: action.defaultKeyCode,
            modifiers: HotkeyConfiguration.ModifierFlags(from: action.defaultModifiers),
            isEnabled: true
        )
        configurations[action.rawValue] = defaultConfig
        saveConfigurations()
        return defaultConfig
    }
    
    func updateConfiguration(for action: HotkeyAction, config: HotkeyConfiguration) {
        configurations[action.rawValue] = config
        saveConfigurations()
        logger.info("Updated hotkey configuration for \(action.rawValue): \(config.displayString)")
    }
    
    func resetToDefaults() {
        configurations.removeAll()
        for action in HotkeyAction.allCases {
            let defaultConfig = HotkeyConfiguration(
                action: action.rawValue,
                keyCode: action.defaultKeyCode,
                modifiers: HotkeyConfiguration.ModifierFlags(from: action.defaultModifiers),
                isEnabled: true
            )
            configurations[action.rawValue] = defaultConfig
        }
        saveConfigurations()
        logger.info("Reset all hotkey configurations to defaults")
    }
    
    // MARK: - Persistence
    
    private func loadConfigurations() {
        if let data = UserDefaults.standard.data(forKey: "HotkeyConfigurations"),
           let decoded = try? JSONDecoder().decode([String: HotkeyConfiguration].self, from: data) {
            configurations = decoded
            logger.info("Loaded \(self.configurations.count) hotkey configurations")
        } else {
            // Initialize with defaults
            resetToDefaults()
        }
    }
    
    private func saveConfigurations() {
        if let encoded = try? JSONEncoder().encode(configurations) {
            UserDefaults.standard.set(encoded, forKey: "HotkeyConfigurations")
            logger.info("Saved hotkey configurations")
        }
    }
    
    // MARK: - Registration
    
    func registerHotkey(for action: HotkeyAction, handler: @escaping () -> Void) {
        let config = getConfiguration(for: action)
        
        guard config.isEnabled else {
            logger.info("Hotkey disabled for \(action.rawValue)")
            return
        }
        
        // Unregister existing monitor if any
        unregisterHotkey(for: action)
        
        // Register new monitor
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let configModifiers = config.modifiers.toNSModifierFlags()
            
            if event.modifierFlags.intersection([.command, .option, .shift, .control]) == configModifiers &&
               event.keyCode == config.keyCode {
                logger.info("🎯 Hotkey triggered: \(action.rawValue) (\(config.displayString))")
                DispatchQueue.main.async {
                    handler()
                }
            }
        }
        
        eventMonitors[action.rawValue] = monitor
        logger.info("Registered hotkey: \(action.rawValue) = \(config.displayString)")
    }
    
    func unregisterHotkey(for action: HotkeyAction) {
        if let monitor = eventMonitors[action.rawValue] {
            NSEvent.removeMonitor(monitor)
            eventMonitors.removeValue(forKey: action.rawValue)
            logger.info("Unregistered hotkey: \(action.rawValue)")
        }
    }
    
    func unregisterAllHotkeys() {
        for (_, monitor) in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
        logger.info("Unregistered all hotkeys")
    }
    
    // MARK: - Validation
    
    func isHotkeyAvailable(keyCode: UInt16, modifiers: HotkeyConfiguration.ModifierFlags, excluding: HotkeyAction? = nil) -> Bool {
        // Check if this combination is already used by another action
        for (actionName, config) in self.configurations {
            if let excluding = excluding, actionName == excluding.rawValue {
                continue
            }
            
            if config.isEnabled && config.keyCode == keyCode && config.modifiers == modifiers {
                return false
            }
        }
        
        return true
    }
    
    func getConflictingAction(keyCode: UInt16, modifiers: HotkeyConfiguration.ModifierFlags, excluding: HotkeyAction? = nil) -> String? {
        for (actionName, config) in self.configurations {
            if let excluding = excluding, actionName == excluding.rawValue {
                continue
            }
            
            if config.isEnabled && config.keyCode == keyCode && config.modifiers == modifiers {
                return actionName
            }
        }
        
        return nil
    }
    
    /// Check if a hotkey might conflict with common system shortcuts
    func getSystemConflictWarning(keyCode: UInt16, modifiers: HotkeyConfiguration.ModifierFlags) -> String? {
        let keyString = KeyCodeMapper.keyCodeToString(keyCode)
        let modString = modifiers.displayString
        
        // Common system shortcuts that might conflict
        let systemShortcuts: [(String, String, String)] = [
            // (modifiers, key, description)
            ("⌘", "H", "Hide Application"),
            ("⌘⇧", "H", "Go to Home Folder / Hide Others"),
            ("⌘", "M", "Minimize Window"),
            ("⌘", "Q", "Quit Application"),
            ("⌘", "W", "Close Window"),
            ("⌘", "T", "New Tab"),
            ("⌘", "N", "New Window"),
            ("⌘", "S", "Save"),
            ("⌘", "P", "Print"),
            ("⌘", "F", "Find"),
            ("⌘", "C", "Copy"),
            ("⌘", "V", "Paste"),
            ("⌘", "X", "Cut"),
            ("⌘", "Z", "Undo"),
            ("⌘⇧", "Z", "Redo"),
            ("⌘", "A", "Select All"),
            ("⌘", "Tab", "Switch Applications"),
            ("⌘", "Space", "Spotlight"),
            ("⌃", "Space", "Input Source Switching"),
            ("⌘⌃", "Space", "Character Viewer"),
            ("⌘⌥", "Esc", "Force Quit"),
            ("⇧⌘", "3", "Screenshot (Full Screen)"),
            ("⇧⌘", "4", "Screenshot (Selection)"),
            ("⇧⌘", "5", "Screenshot & Recording Options")
        ]
        
        for (sysModString, sysKey, description) in systemShortcuts {
            if modString == sysModString && keyString.uppercased() == sysKey.uppercased() {
                return description
            }
        }
        
        return nil
    }
}
