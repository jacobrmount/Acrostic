// AcrostiKit/Domain/Managers/DocStorageManager.swift
import Foundation

enum StorageLocation {
    case iCloud
    case local
}

protocol StorageAdapter {
    func saveToken(_ token: TokenEntity) throws
    func updateToken(_ token: TokenEntity) throws
    func loadTokens() -> [TokenEntity]
    func saveDatabase(_ database: DatabaseEntity, forToken tokenID: UUID) throws
    func loadDatabases(forToken tokenID: UUID) -> [DatabaseEntity]
    func deleteToken(_ tokenID: UUID) throws
    func deleteDatabase(_ databaseID: String) throws
    func migrateFrom(adapter: StorageAdapter) throws
}

class DocumentStorageManager {
    static let shared = DocumentStorageManager()
    
    private var currentAdapter: StorageAdapter
    private let iCloudAdapter: StorageAdapter
    private let localAdapter: StorageAdapter
    
    private init() {
        // Initialize local adapter first
        localAdapter = LocalStorageAdapter()
        
        // Variable to track if iCloud initialization succeeded
        var iCloudInitialized = false
        
        // Try to initialize iCloud adapter with error handling
        do {
            iCloudAdapter = try iCloudStorageAdapter()
            iCloudInitialized = true
        } catch {
            print("Error initializing iCloud adapter: \(error)")
            // Use local adapter as fallback
            iCloudAdapter = localAdapter
        }
        
        // Initialize based on user settings
        let defaults = UserDefaults.standard
        let preferredLocation = defaults.string(forKey: "storage_location_preference") ?? "icloud"
        
        // Default to local if iCloud initialization failed
        if preferredLocation == "icloud" && iCloudInitialized {
            currentAdapter = iCloudAdapter
        } else {
            currentAdapter = localAdapter
            // Update preference to match reality if needed
            if preferredLocation == "icloud" && !iCloudInitialized {
                defaults.set("local", forKey: "storage_location_preference")
            }
        }
        
        // Observe for settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleSettingsChanged() {
        let defaults = UserDefaults.standard
        let newPreference = defaults.string(forKey: "storage_location_preference") ?? "icloud"
        let newAdapter = newPreference == "icloud" ? iCloudAdapter : localAdapter
        
        if (currentAdapter is iCloudStorageAdapter && newAdapter is LocalStorageAdapter) ||
           (currentAdapter is LocalStorageAdapter && newAdapter is iCloudStorageAdapter) {
            do {
                try newAdapter.migrateFrom(adapter: currentAdapter)
                currentAdapter = newAdapter
            } catch {
                print("Failed to migrate storage: \(error)")
                // Revert setting if migration fails
                defaults.set(currentAdapter is iCloudStorageAdapter ? "icloud" : "local",
                             forKey: "storage_location_preference")
            }
        }
    }
    
    // Public interface methods that delegate to the current adapter
    func saveToken(_ token: TokenEntity) throws {
        try currentAdapter.saveToken(token)
    }
    
    public func updateToken(_ token: TokenEntity) throws {
        // Validate token ID exists and is meaningful
        guard let tokenId = token.id, !tokenId.uuidString.isEmpty else {
            let error = NSError(
                domain: "DocumentStorageManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid or nil token ID"]
            )
            print("🚨 Update Token Error: \(error.localizedDescription)")
            throw error
        }
        
        // Log the migration strategy
        let migrationStrategy = UserDefaults.standard.string(forKey: "storage_location_preference") ?? "icloud"
        print("🔍 Current Storage Migration Strategy: \(migrationStrategy) for token \(tokenId)")
        
        do {
            // Try iCloud adapter first
            if migrationStrategy == "icloud" {
                try iCloudStorageAdapter().updateToken(token)
                print("✅ Token updated in iCloud storage")
            } else {
                // Fallback to local storage
                try LocalStorageAdapter().updateToken(token)
                print("✅ Token updated in local storage")
            }
        } catch {
            print("❌ Token update failed in preferred storage: \(error)")
            
            // Additional fallback: attempt update in alternate storage
            do {
                if migrationStrategy == "icloud" {
                    try LocalStorageAdapter().updateToken(token)
                    print("🔄 Fallback: Updated token in local storage")
                } else {
                    try iCloudStorageAdapter().updateToken(token)
                    print("🔄 Fallback: Updated token in iCloud storage")
                }
            } catch let fallbackError {
                print("🚨 Complete storage update failure: \(fallbackError)")
                throw fallbackError
            }
        }
    }
    
    func loadTokens() -> [TokenEntity] {
        return currentAdapter.loadTokens()
    }
    
    func saveDatabase(_ database: DatabaseEntity, forToken tokenID: UUID) throws {
        try currentAdapter.saveDatabase(database, forToken: tokenID)
    }
    
    func loadDatabases(forToken tokenID: UUID) -> [DatabaseEntity] {
        return currentAdapter.loadDatabases(forToken: tokenID)
    }
    
    func deleteToken(_ tokenID: UUID) throws {
        try currentAdapter.deleteToken(tokenID)
    }
    
    func deleteDatabase(_ databaseID: String) throws {
        try currentAdapter.deleteDatabase(databaseID)
    }
    
    // Added migration methods
    func migrateToiCloud() throws {
        if !(currentAdapter is iCloudStorageAdapter) {
            try iCloudAdapter.migrateFrom(adapter: currentAdapter)
            currentAdapter = iCloudAdapter
        }
    }
    
    func migrateToLocal() throws {
        if !(currentAdapter is LocalStorageAdapter) {
            try localAdapter.migrateFrom(adapter: currentAdapter)
            currentAdapter = localAdapter
        }
    }
}
