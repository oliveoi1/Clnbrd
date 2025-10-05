import Foundation

/// Centralized version management for Clnbrd
/// Automatically reads version information from Info.plist to ensure consistency
struct VersionManager {
    
    // MARK: - Version Information
    
    /// App version string (e.g., "1.3")
    static let version: String = "1.3"

    /// Build number string (e.g., "3")
    static let buildNumber: String = "29"
    
    /// Full version string (e.g., "1.3 (Build 3)")
    static var fullVersion: String {
        return "\(version) (Build \(buildNumber))"
    }

    /// Get version from Info.plist at runtime (safer than static initialization)
    static func getVersionFromBundle() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3"
    }

    /// Get build number from Info.plist at runtime (safer than static initialization)
    static func getBuildNumberFromBundle() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "3"
    }
    
    /// Display version for UI (e.g., "Version 1.3")
    static var displayVersion: String {
        return "Version \(version)"
    }
    
    // MARK: - Configuration
    
    /// URL for checking updates
    static let versionCheckURL = "https://naturalpod-downloads.s3.us-west-2.amazonaws.com/clnbrd-version.json"
    
    // MARK: - Version Comparison
    
    /// Compare two version strings to determine if the first is newer
    /// - Parameters:
    ///   - version1: First version string (e.g., "1.4")
    ///   - version2: Second version string (e.g., "1.3")
    /// - Returns: True if version1 is newer than version2
    static func isVersionNewer(_ version1: String, than version2: String) -> Bool {
        let components1 = version1.components(separatedBy: ".").compactMap { Int($0) }
        let components2 = version2.components(separatedBy: ".").compactMap { Int($0) }
        
        let maxLength = max(components1.count, components2.count)
        
        for i in 0..<maxLength {
            let v1 = i < components1.count ? components1[i] : 0
            let v2 = i < components2.count ? components2[i] : 0
            
            if v1 > v2 {
                return true
            } else if v1 < v2 {
                return false
            }
        }
        
        return false
    }
    
    // MARK: - Debug Information
    
    /// Get all version-related information for debugging
    static var debugInfo: [String: String] {
        return [
            "Version": version,
            "Build Number": buildNumber,
            "Full Version": fullVersion,
            "Bundle Version": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            "Bundle Short Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        ]
    }
}
