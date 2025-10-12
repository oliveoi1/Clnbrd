import Foundation
import CryptoKit
import os.log

/// Handles encrypted persistence of clipboard history to disk
class ClipboardHistoryStorage {
    private let logger = Logger(subsystem: "com.allanalomes.Clnbrd", category: "ClipboardHistoryStorage")
    
    // Storage paths
    private let storageDirectory: URL
    private let historyFileURL: URL
    private let keyFileURL: URL
    
    // Encryption
    private let encryptionKey: SymmetricKey
    
    // Singleton
    static let shared = ClipboardHistoryStorage()
    
    private init() {
        // Get application support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDirectory = appSupport.appendingPathComponent("com.allanalomes.Clnbrd", isDirectory: true)
        historyFileURL = storageDirectory.appendingPathComponent("history.encrypted")
        keyFileURL = storageDirectory.appendingPathComponent(".encryption_key")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        
        // Load or create encryption key (static method to avoid using self)
        if let keyData = try? Data(contentsOf: keyFileURL) {
            encryptionKey = SymmetricKey(data: keyData)
            logger.info("📂 Loaded existing encryption key")
        } else {
            encryptionKey = SymmetricKey(size: .bits256)
            
            // Save the new key
            let keyData = encryptionKey.withUnsafeBytes { Data($0) }
            try? keyData.write(to: keyFileURL, options: .completeFileProtection)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: keyFileURL.path
            )
            
            logger.info("🔐 Generated new encryption key")
        }
    }
    
    // MARK: - Save/Load History
    
    /// Save history items to encrypted file
    func saveHistory(_ items: [ClipboardHistoryItem]) throws {
        logger.info("💾 Saving \(items.count) items to encrypted storage...")
        
        // Encode items to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(items)
        
        // Encrypt the data
        let encryptedData = try encrypt(jsonData)
        
        // Write to disk
        try encryptedData.write(to: historyFileURL, options: .atomic)
        
        logger.info("✅ Saved \(items.count) items (\(jsonData.count) bytes) to disk")
    }
    
    /// Load history items from encrypted file
    func loadHistory() throws -> [ClipboardHistoryItem] {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            logger.info("📂 No existing history file found")
            return []
        }
        
        // Read encrypted data
        let encryptedData = try Data(contentsOf: historyFileURL)
        
        // Decrypt the data
        let decryptedData = try decrypt(encryptedData)
        
        // Decode items from JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let items = try decoder.decode([ClipboardHistoryItem].self, from: decryptedData)
        
        logger.info("✅ Loaded \(items.count) items from disk")
        return items
    }
    
    /// Clear all stored history
    func clearHistory() throws {
        if FileManager.default.fileExists(atPath: historyFileURL.path) {
            try FileManager.default.removeItem(at: historyFileURL)
            logger.info("🗑️ Cleared history from disk")
        }
    }
    
    // MARK: - Encryption
    
    private func encrypt(_ data: Data) throws -> Data {
        // Use AES-GCM for authenticated encryption
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        
        // Combine nonce + ciphertext + tag
        guard let combined = sealedBox.combined else {
            throw StorageError.encryptionFailed
        }
        
        return combined
    }
    
    private func decrypt(_ data: Data) throws -> Data {
        // Create sealed box from combined data
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        
        // Decrypt and verify
        let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
        
        return decryptedData
    }
    
    // MARK: - Storage Info
    
    /// Get the size of stored history file
    func getStorageSize() -> Int {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: historyFileURL.path),
              let fileSize = attributes[.size] as? Int else {
            return 0
        }
        return fileSize
    }
    
    /// Get storage directory URL
    func getStorageDirectory() -> URL {
        return storageDirectory
    }
}

// MARK: - Errors

enum StorageError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt clipboard history"
        case .decryptionFailed:
            return "Failed to decrypt clipboard history"
        case .invalidData:
            return "Invalid clipboard history data"
        }
    }
}
