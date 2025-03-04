// NactionsKit/BusinessLogic/AppGroupConfig.swift
import Foundation
import UIKit

/// Handles configuration and access to shared app group resources
public struct AppGroupConfig {
    /// The shared app group identifier
    public static let appGroupIdentifier = "group.com.nactions"
    
    /// Shared user defaults for the app group
    public static var sharedUserDefaults: UserDefaults? {
        // Create with app group ID - Fix: Don't use any user parameter
        return UserDefaults(suiteName: appGroupIdentifier)
    }
    
    /// Shared container URL for the app group
    public static var sharedContainerURL: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    /// Gets the shared Core Data store URL
    public static var sharedStoreURL: URL? {
        guard let containerURL = sharedContainerURL else { return nil }
        return containerURL.appendingPathComponent("NactionsDataModel.sqlite")
    }
    
    /// Checks if the app group is correctly configured and accessible
    @discardableResult
    public static func verifyAppGroupAccess() -> Bool {
        guard let defaults = sharedUserDefaults else {
            print("❌ Failed to access shared UserDefaults")
            return false
        }
        
        // Use the containerURL variable to avoid the warning
        if sharedContainerURL == nil {
            print("❌ Failed to access shared container URL")
            return false
        }
        
        // Try writing and reading a test value
        let testKey = "appGroupAccessTest"
        let testValue = "test-\(Date().timeIntervalSince1970)"
        
        defaults.set(testValue, forKey: testKey)
        let readValue = defaults.string(forKey: testKey)
        
        let accessSuccessful = (readValue == testValue)
        if !accessSuccessful {
            print("❌ Failed to verify app group access")
        } else {
            print("✅ Successfully verified app group access")
        }
        
        return accessSuccessful
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
    
    /// Cleans up old cache data
    public static func cleanupCacheData() {
        guard let defaults = sharedUserDefaults else { return }
        
        // Get all keys
        let allKeys = defaults.dictionaryRepresentation().keys
        
        // Find cache keys (those with timestamps)
        let cacheKeys = allKeys.filter {
            $0.starts(with: "nactions_tasks_") ||
            $0.starts(with: "nactions_progress_")
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
