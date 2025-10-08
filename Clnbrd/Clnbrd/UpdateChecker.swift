import Cocoa
import os.log

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "updates")

class UpdateChecker {
    weak var delegate: UpdateCheckerDelegate?
    
    func checkForUpdates() {
        logger.info("Starting version check...")
        
        guard let url = URL(string: VersionManager.versionCheckURL) else {
            logger.error("Invalid version check URL")
            return
        }
        
        logger.info("Fetching from URL: \(url)")
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    logger.error("Version check failed: \(error.localizedDescription)")
                    AnalyticsManager.shared.trackUpdateCheck(success: false)
                    
                    // Report to Sentry
                    SentryManager.shared.reportError(error, context: "update_check", additionalInfo: [
                        "url": url.absoluteString,
                        "network_error": true
                    ])
                    
                    self.delegate?.updateCheckFailed(message: "Could not check for updates. Please try again later.")
                    return
                }
                
                guard let data = data else {
                    logger.error("No version data received")
                    AnalyticsManager.shared.trackUpdateCheck(success: false)
                    self.delegate?.updateCheckFailed(message: "No version information received.")
                    return
                }
                
                logger.info("Received version data: \(data.count) bytes")
                AnalyticsManager.shared.trackUpdateCheck(success: true)
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let tagName = json["tag_name"] as? String,
                       let releaseNotes = json["body"] as? String,
                       let assets = json["assets"] as? [[String: Any]],
                       let firstAsset = assets.first,
                       let downloadUrl = firstAsset["browser_download_url"] as? String {
                        // Strip "v" prefix from tag name (v1.3 -> 1.3)
                        let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                        let currentVersion = VersionManager.version
                        let skippedVersion = UserDefaults.standard.string(forKey: "SkippedVersion")
                        
                        logger.info("Current: \(currentVersion), Latest: \(latestVersion), Skipped: \(skippedVersion ?? "none")")
                        
                        // Check if this version was skipped
                        if skippedVersion == latestVersion {
                            logger.info("Version \(latestVersion) was skipped by user")
                            return
                        }
                        
                        if VersionManager.isVersionNewer(latestVersion, than: currentVersion) {
                            logger.info("New version available!")
                            self.delegate?.updateAvailable(currentVersion: currentVersion, latestVersion: latestVersion, downloadUrl: downloadUrl, releaseNotes: releaseNotes)
                        } else {
                            logger.info("Up to date")
                            self.delegate?.updateCheckCompleted(isUpToDate: true)
                        }
                    } else {
                        logger.error("Missing required fields in GitHub API response")
                        self.delegate?.updateCheckFailed(message: "Invalid version information received.")
                    }
                    } catch {
                        logger.error("Failed to parse version data: \(error.localizedDescription)")
                        
                        // Report to Sentry
                        SentryManager.shared.reportError(error, context: "json_parsing", additionalInfo: [
                            "url": url.absoluteString,
                            "data_size": data.count,
                            "json_parsing_error": true
                        ])
                        
                        self.delegate?.updateCheckFailed(message: "Invalid version information received.")
                    }
            }
        }
        
        task.resume()
    }
}

protocol UpdateCheckerDelegate: AnyObject {
    func updateAvailable(currentVersion: String, latestVersion: String, downloadUrl: String, releaseNotes: String)
    func updateCheckCompleted(isUpToDate: Bool)
    func updateCheckFailed(message: String)
}
