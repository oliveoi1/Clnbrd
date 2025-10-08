import Foundation
import os.log

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "profile")

/// Represents a named collection of cleaning rules
struct CleaningProfile: Codable {
    var id: UUID
    var name: String
    var rules: CleaningRules
    
    init(name: String, rules: CleaningRules) {
        self.id = UUID()
        self.name = name
        self.rules = rules
    }
    
    init(id: UUID, name: String, rules: CleaningRules) {
        self.id = id
        self.name = name
        self.rules = rules
    }
}

/// Manages cleaning profiles - creation, deletion, persistence
class ProfileManager {
    static let shared = ProfileManager()
    
    private var profiles: [CleaningProfile] = []
    private var activeProfileId: UUID?
    
    private init() {
        loadProfiles()
    }
    
    /// Get all profiles
    func getAllProfiles() -> [CleaningProfile] {
        return profiles
    }
    
    /// Get the active profile (returns a copy with deep-copied rules)
    func getActiveProfile() -> CleaningProfile {
        if let activeId = activeProfileId,
           let profile = profiles.first(where: { $0.id == activeId }) {
            // Return a copy with deep-copied rules to avoid shared references
            return CleaningProfile(id: profile.id, name: profile.name, rules: copyRules(from: profile.rules))
        }
        
        // Fallback: return first profile or create default
        if let firstProfile = profiles.first {
            activeProfileId = firstProfile.id
            return CleaningProfile(id: firstProfile.id, name: firstProfile.name, rules: copyRules(from: firstProfile.rules))
        }
        
        // Create default profile
        let defaultProfile = createDefaultProfile()
        profiles.append(defaultProfile)
        activeProfileId = defaultProfile.id
        saveProfiles()
        return defaultProfile
    }
    
    /// Set the active profile by ID
    func setActiveProfile(id: UUID) {
        if profiles.contains(where: { $0.id == id }) {
            activeProfileId = id
            saveProfiles()
        }
    }
    
    /// Create a new profile by duplicating an existing one
    func createProfile(basedOn profile: CleaningProfile, name: String) -> CleaningProfile {
        let copiedRules = copyRules(from: profile.rules)
        let newProfile = CleaningProfile(name: name, rules: copiedRules)
        profiles.append(newProfile)
        saveProfiles()
        return newProfile
    }
    
    /// Rename a profile
    func renameProfile(id: UUID, newName: String) {
        if let index = profiles.firstIndex(where: { $0.id == id }) {
            profiles[index].name = newName
            saveProfiles()
        }
    }
    
    /// Delete a profile (can't delete if it's the last one)
    func deleteProfile(id: UUID) -> Bool {
        guard profiles.count > 1 else {
            return false // Can't delete the last profile
        }
        
        if let index = profiles.firstIndex(where: { $0.id == id }) {
            profiles.remove(at: index)
            
            // If we deleted the active profile, switch to the first one
            if activeProfileId == id {
                activeProfileId = profiles.first?.id
            }
            
            saveProfiles()
            return true
        }
        
        return false
    }
    
    /// Update the rules for a specific profile
    func updateProfile(id: UUID, rules: CleaningRules) {
        if let index = profiles.firstIndex(where: { $0.id == id }) {
            // Create a deep copy to avoid shared references
            profiles[index].rules = copyRules(from: rules)
            saveProfiles()
        }
    }
    
    /// Deep copy cleaning rules to avoid shared references
    private func copyRules(from rules: CleaningRules) -> CleaningRules {
        let newRules = CleaningRules()
        newRules.removeEmdashes = rules.removeEmdashes
        newRules.replaceEmdashWith = rules.replaceEmdashWith
        newRules.normalizeSpaces = rules.normalizeSpaces
        newRules.removeZeroWidthChars = rules.removeZeroWidthChars
        newRules.normalizeLineBreaks = rules.normalizeLineBreaks
        newRules.removeTrailingSpaces = rules.removeTrailingSpaces
        newRules.convertSmartQuotes = rules.convertSmartQuotes
        newRules.removeEmojis = rules.removeEmojis
        newRules.removeExtraLineBreaks = rules.removeExtraLineBreaks
        newRules.removeLeadingTrailingWhitespace = rules.removeLeadingTrailingWhitespace
        newRules.removeUrlTracking = rules.removeUrlTracking
        newRules.removeUrls = rules.removeUrls
        newRules.removeHtmlTags = rules.removeHtmlTags
        newRules.removeExtraPunctuation = rules.removeExtraPunctuation
        newRules.customRules = rules.customRules
        return newRules
    }
    
    // MARK: - Persistence
    
    private func saveProfiles() {
        do {
            let encoder = JSONEncoder()
            let profilesData = try encoder.encode(profiles)
            UserDefaults.standard.set(profilesData, forKey: "CleaningProfiles")
            
            if let activeId = activeProfileId {
                UserDefaults.standard.set(activeId.uuidString, forKey: "ActiveProfileId")
            }
        } catch {
            logger.error("Failed to save profiles: \(error.localizedDescription)")
        }
    }
    
    private func loadProfiles() {
        // Load profiles
        if let profilesData = UserDefaults.standard.data(forKey: "CleaningProfiles"),
           let loadedProfiles = try? JSONDecoder().decode([CleaningProfile].self, from: profilesData) {
            profiles = loadedProfiles
        } else {
            // Create default profile on first launch
            let defaultProfile = createDefaultProfile()
            profiles = [defaultProfile]
        }
        
        // Load active profile ID
        if let activeIdString = UserDefaults.standard.string(forKey: "ActiveProfileId"),
           let activeId = UUID(uuidString: activeIdString) {
            activeProfileId = activeId
        } else {
            activeProfileId = profiles.first?.id
        }
    }
    
    private func createDefaultProfile() -> CleaningProfile {
        let defaultRules = CleaningRules()
        // Use default values (all true except removeEmojis)
        return CleaningProfile(name: "Default", rules: defaultRules)
    }
}
