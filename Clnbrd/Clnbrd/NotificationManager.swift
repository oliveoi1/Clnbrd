import Cocoa
import UserNotifications
import os.log

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "notifications")

class NotificationManager: NSObject {
    // MARK: - Properties

    private weak var appDelegate: AppDelegate?

    // MARK: - Initialization

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        setupNotificationCenter()
    }

    // MARK: - Setup

    private func setupNotificationCenter() {
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission Management

    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                logger.info("Notification permissions granted")
            } else {
                logger.warning("Notification permissions denied: \(error?.localizedDescription ?? "Unknown error")")
            }

            // Always update the last known version
            let currentVersion = VersionManager.version
            UserDefaults.standard.set(currentVersion, forKey: "LastKnownVersion")
        }
    }

    // MARK: - Notification Display

    func showNotification(title: String, message: String) {
        // Check notification authorization status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    // Create notification content
                    let content = UNMutableNotificationContent()
                    content.title = title
                    content.body = message
                    content.sound = .default

                    // Create trigger for immediate display
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

                    // Create request
                    let request = UNNotificationRequest(
                        identifier: UUID().uuidString,
                        content: content,
                        trigger: trigger
                    )

                    // Add request
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            logger.error("Failed to show notification: \(error.localizedDescription)")
                        }
                    }
                } else {
                    // Fallback to alert if notifications not authorized
                    self.showAlert(title: title, message: message)
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Update Notifications

    func showUpdateNotification(currentVersion: String, latestVersion: String, releaseNotes: String) {
        // Show push-style notification first
        showNotification(title: "Update Available", message: "Clnbrd \(latestVersion) is available")

        // Then show the detailed dialog
        showUpdateAvailableDialog(currentVersion: currentVersion, latestVersion: latestVersion, downloadUrl: "", releaseNotes: releaseNotes)
    }

    private func showUpdateAvailableDialog(currentVersion: String, latestVersion: String, downloadUrl: String, releaseNotes: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = """
        A new version of Clnbrd is available!

        Current Version: \(currentVersion)
        Latest Version: \(latestVersion)

        What's New:
        \(releaseNotes)

        Would you like to download the update?
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download Update")
        alert.addButton(withTitle: "Skip This Version")
        alert.addButton(withTitle: "Remind Me Later")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // Download update
            if !downloadUrl.isEmpty {
                NSWorkspace.shared.open(URL(string: downloadUrl)!)
            }
        case .alertSecondButtonReturn:
            // Skip this version - store it to avoid showing again
            UserDefaults.standard.set(latestVersion, forKey: "SkippedVersion")
        default:
            // Remind me later - do nothing
            break
        }
    }

    func showMenuBarUpdateNotification(latestVersion: String) {
        // Update menu bar to show update available
        if let statusBarButton = NSApp.mainMenu?.item(withTitle: "Clnbrd")?.submenu?.item(withTitle: "Check for Updates...") {
            statusBarButton.title = "Check for Updates... (Update Available: \(latestVersion))"
        }

        // Also show a notification
        showNotification(title: "Update Available", message: "Clnbrd \(latestVersion) is ready to download")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification activation
        let userInfo = response.notification.request.content.userInfo

        if let type = userInfo["type"] as? String,
           userInfo["version"] is String {
            switch type {
            case "update":
                // Handle update notification activation
                if let url = userInfo["url"] as? String {
                    NSWorkspace.shared.open(URL(string: url)!)
                }
            default:
                break
            }
        }

        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Always show notifications, even when app is active
        completionHandler([.banner, .sound])
    }
}
