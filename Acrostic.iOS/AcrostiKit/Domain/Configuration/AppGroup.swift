// AcrostiKit/Domain/Configuration/AppGroup.swift
import Foundation
import UIKit
import WidgetKit

/// Handles configuration and access to shared app group resources
public struct AppGroupConfig {
    /// The shared app group identifier
    public static let appGroupIdentifier = "group.com.acrostic"
    
    /// Add document storage related methods
    public static func getDocumentStoragePath() -> URL? {
        let defaults = UserDefaults.standard
        let storageLocation = defaults.string(forKey: "storage_location_preference") ?? "icloud"
        
        print("📂 Storage Location Preference: \(storageLocation)")
        
        if storageLocation == "icloud" {
            guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                print("❌ iCloud container not available")
                return nil
            }
            let documentURL = iCloudURL.appendingPathComponent("Documents")
            print("✅ iCloud Document URL: \(documentURL)")
            return documentURL
        } else {
            let localDocumentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            print("✅ Local Document URL: \(localDocumentURL?.path ?? "Unavailable")")
            return localDocumentURL
        }
    }

    public static func verifyDocumentStorageConfiguration() -> Bool {
        guard let storageURL = getDocumentStoragePath() else {
            print("❌ Document storage path could not be determined")
            return false
        }
        
        do {
            try FileManager.default.createDirectory(
                at: storageURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("✅ Document storage directory verified and created if needed")
            return true
        } catch {
            print("❌ Failed to create document storage directory: \(error)")
            return false
        }
    }
    
    /// Shared user defaults for the app group
    public static var sharedUserDefaults: UserDefaults? {
        return UserDefaults(suiteName: AppGroupConfig.appGroupIdentifier)
    }
    
    /// Checks if the app group is correctly configured and accessible
    @discardableResult
    public static func verifyAppGroupAccess() -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ Failed to access shared UserDefaults")
            return false
        }
        
        // Try writing and reading a test value
        let testKey = "appGroupAccessTest"
        let testValue = "test-\(Date().timeIntervalSince1970)"
        
        defaults.set(testValue, forKey: testKey)
        let readValue = defaults.string(forKey: testKey)
        
        let accessSuccessful = (readValue == testValue)
        if !accessSuccessful {
            print("❌ Failed to verify app group access - value mismatch")
        } else {
            print("✅ Successfully verified app group access")
        }
        
        return accessSuccessful
    }
    
    // Add a diagnostic method:
    public static func logAppGroupDiagnostics() {
        print("🔍 App Group Diagnostics:")
        print("• App Group Identifier: \(appGroupIdentifier)")
        
        // Check if the app group container exists
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            print("• App Group Container URL: \(containerURL.path)")
            print("• Container exists: \(FileManager.default.fileExists(atPath: containerURL.path) ? "Yes" : "No")")
        } else {
            print("• Failed to access app group container URL")
        }
        
        // Check UserDefaults access
        if let defaults = UserDefaults(suiteName: appGroupIdentifier) {
            print("• UserDefaults instance created successfully")
            let testKey = "diagnostic_test_\(Date().timeIntervalSince1970)"
            defaults.set(true, forKey: testKey)
            let success = defaults.bool(forKey: testKey)
            print("• UserDefaults write/read test: \(success ? "Passed" : "Failed")")
        } else {
            print("• Failed to create UserDefaults instance")
        }
    }
    
    /// Configures the app for sharing data with widgets
    public static func configureAppForWidgetSharing() {
        // Check app group access immediately
        if !verifyAppGroupAccess() {
            print("⚠️ WARNING: App group access is not working correctly. Widgets may not function properly.")
        } else {
            print("✅ App group access configured correctly for widget sharing")
        }
        
        // Register for app lifecycle notifications to update widgets
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Refresh widget data when app comes to foreground
            Task {
                await refreshWidgetData()
            }
        }
    }
    
    /// Refreshes all widget data
    public static func refreshWidgetData() async {
        // Ensure we have app group access
        if verifyAppGroupAccess() {
            // Share token and database data with widgets
            await WidgetDataSharingService.shared.refreshAllWidgets()
        } else {
            print("⚠️ Cannot refresh widget data - app group access failed")
        }
    }
    
    /// Refreshes widget configuration data
    public static func refreshWidgetConfigurationData() {
        guard let userDefaults = sharedUserDefaults else { return }
        
        // Trigger a refresh by setting a timestamp
        userDefaults.set(Date().timeIntervalSince1970, forKey: "widget_config_refresh_trigger")
        userDefaults.synchronize()
        
        // Refresh all widget timelines
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Cleans up old cache data
    public static func cleanupCacheData() {
        guard let defaults = sharedUserDefaults else { return }
        
        // Get all keys
        let allKeys = defaults.dictionaryRepresentation().keys
        
        // Find cache keys (those with timestamps)
        let cacheKeys = allKeys.filter {
            $0.starts(with: "acrostic_tasks_") ||
            $0.starts(with: "acrostic_progress_")
        }
        
        let now = Date().timeIntervalSince1970
        let maxAge: TimeInterval = 86400 * 7 // 7 days
        
        for key in cacheKeys {
            if let cacheDict = defaults.dictionary(forKey: key),
               let timestamp = cacheDict["timestamp"] as? TimeInterval,
               now - timestamp > maxAge {
                // Remove old cache entries
                defaults.removeObject(forKey: key)
            }
        }
    }
}
