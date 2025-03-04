// NactionsWidgets/Services/WidgetService.swift
import Foundation
import WidgetKit
import NactionsKit  // Use types from shared framework

/// Service class for handling widget-related data fetching and caching
class WidgetService {
    static let shared = WidgetService()
    
    private let userDefaults = UserDefaults(suiteName: "group.com.nactions")
    
    private init() {}
    
    // MARK: - Token Handling
    
    /// Retrieves all available tokens for widget configuration
    func getAvailableTokens() -> [NactionsKit.TokenEntity] {
        // In a real implementation, you would fetch tokens from CoreData
        // or your TokenDataController using the shared app group
        return []
    }
    
    /// Retrieves a specific token by ID
    func getToken(id: String) throws -> NotionToken {
        // We need to implement a way to access the shared token data
        // This is a placeholder that throws an error
        throw NactionsKit.WidgetError.tokenNotFound
    }
    
    // MARK: - Cache Handling
    
    /// Saves task data to cache for quick widget rendering
    func cacheTaskData(for tokenID: String, databaseID: String, tasks: [NactionsKit.TaskItem]) {
        guard let userDefaults = userDefaults else { return }
        
        let cacheKey = "tasks_\(tokenID)_\(databaseID)"
        let encoder = JSONEncoder()
        
        // Create a simple struct to hold the data and timestamp
        let cachedData = NactionsKit.CachedData(
            timestamp: Date(),
            data: tasks
        )
        
        if let encoded = try? encoder.encode(cachedData) {
            userDefaults.set(encoded, forKey: cacheKey)
        }
    }
    
    /// Retrieves cached task data if available and not expired
    func getCachedTaskData(for tokenID: String, databaseID: String, maxAge: TimeInterval = 3600) -> [NactionsKit.TaskItem]? {
        guard let userDefaults = userDefaults,
              let cached = userDefaults.data(forKey: "tasks_\(tokenID)_\(databaseID)") else {
            return nil
        }
        
        let decoder = JSONDecoder()
        if let cachedData = try? decoder.decode(NactionsKit.CachedData<[NactionsKit.TaskItem]>.self, from: cached) {
            // Check if the cache is still valid
            if Date().timeIntervalSince(cachedData.timestamp) <= maxAge {
                return cachedData.data
            }
        }
        
        return nil
    }
    
    /// Saves progress data to cache for quick widget rendering
    func cacheProgressData(for tokenID: String, databaseID: String, progress: NactionsKit.ProgressData) {
        guard let userDefaults = userDefaults else { return }
        
        let cacheKey = "progress_\(tokenID)_\(databaseID)"
        let encoder = JSONEncoder()
        
        let cachedData = NactionsKit.CachedData(
            timestamp: Date(),
            data: progress
        )
        
        if let encoded = try? encoder.encode(cachedData) {
            userDefaults.set(encoded, forKey: cacheKey)
        }
    }
    
    /// Retrieves cached progress data if available and not expired
    func getCachedProgressData(for tokenID: String, databaseID: String, maxAge: TimeInterval = 3600) -> NactionsKit.ProgressData? {
        guard let userDefaults = userDefaults,
              let cached = userDefaults.data(forKey: "progress_\(tokenID)_\(databaseID)") else {
            return nil
        }
        
        let decoder = JSONDecoder()
        if let cachedData = try? decoder.decode(NactionsKit.CachedData<NactionsKit.ProgressData>.self, from: cached) {
            if Date().timeIntervalSince(cachedData.timestamp) <= maxAge {
                return cachedData.data
            }
        }
        
        return nil
    }
    
    // MARK: - Widget Refresh
    
    /// Triggers a refresh of all widgets
    func refreshAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Triggers a refresh of a specific widget kind
    func refreshWidget(kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}

// Define NotionToken for this file context (a simplified version)
struct NotionToken {
    let id: UUID
    let name: String
    let apiToken: String
}
