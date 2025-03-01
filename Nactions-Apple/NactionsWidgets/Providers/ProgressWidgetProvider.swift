// NactionsWidgets/Providers/ProgressWidgetProvider.swift
import WidgetKit
import SwiftUI
import Foundation
import NactionsKit

struct ProgressWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = ProgressEntry
    typealias Intent = ProgressWidgetConfigurationIntent
    
    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(
            date: Date(),
            configuration: ProgressWidgetConfigurationIntent(),
            progress: NactionsKit.ProgressData.sample,
            error: nil
        )
    }
    
    func snapshot(for configuration: ProgressWidgetConfigurationIntent, in context: Context) async -> ProgressEntry {
        // Return sample data for the widget gallery
        ProgressEntry(
            date: Date(),
            configuration: configuration,
            progress: NactionsKit.ProgressData.sample,
            error: nil
        )
    }
    
    func timeline(for configuration: ProgressWidgetConfigurationIntent, in context: Context) async -> Timeline<ProgressEntry> {
        var entries: [ProgressEntry] = []
        let currentDate = Date()
        
        // Check if we have the required configuration
        guard let tokenID = configuration.tokenID, !tokenID.isEmpty,
              let databaseID = configuration.databaseID, !databaseID.isEmpty,
              let currentValueProperty = configuration.currentValueProperty, !currentValueProperty.isEmpty,
              let targetValueProperty = configuration.targetValueProperty, !targetValueProperty.isEmpty else {
            let entry = ProgressEntry(
                date: currentDate,
                configuration: configuration,
                progress: NactionsKit.ProgressData(title: configuration.title, currentValue: 0, targetValue: 0),
                error: "Please configure the widget with valid Notion settings."
            )
            return Timeline(entries: [entry], policy: .never)
        }
        
        do {
            // Fetch progress data from Notion
            let progress = try await fetchProgressData(
                tokenID: tokenID,
                databaseID: databaseID,
                title: configuration.title,
                currentValueProperty: currentValueProperty,
                targetValueProperty: targetValueProperty
            )
            
            // Create an entry with the fetched progress data
            let entry = ProgressEntry(
                date: currentDate,
                configuration: configuration,
                progress: progress,
                error: nil
            )
            entries.append(entry)
            
            // Refresh every hour or when Notion data might change
            let nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            
            return Timeline(entries: entries, policy: .after(nextUpdateDate))
        } catch {
            let entry = ProgressEntry(
                date: currentDate,
                configuration: configuration,
                progress: NactionsKit.ProgressData(title: configuration.title, currentValue: 0, targetValue: 0),
                error: "Failed to fetch progress data: \(error.localizedDescription)"
            )
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
        }
    }
    
    // MARK: - API Methods
    
    private func fetchProgressData(
        tokenID: String,
        databaseID: String,
        title: String,
        currentValueProperty: String,
        targetValueProperty: String
    ) async throws -> NactionsKit.ProgressData {
        // Try to get from shared UserDefaults cache first
        if let userDefaults = UserDefaults(suiteName: "group.com.nactions"),
           let cachedProgress = getCachedProgress(userDefaults: userDefaults, tokenID: tokenID, databaseID: databaseID) {
            return cachedProgress
        }
        
        // If we get here, we need to fetch data from Notion API
        // First, get the token
        guard let tokenUUID = UUID(uuidString: tokenID) else {
            throw WidgetError.tokenNotFound
        }
        
        // Get token data
        let tokenDataController = NactionsKit.TokenDataController.shared
        let token = tokenDataController.fetchToken(id: tokenUUID)
        
        // If we can't find the token, throw an error
        guard let token = token,
              let apiToken = NactionsKit.TokenDataController.shared.getSecureToken(for: tokenUUID.uuidString) else {
            throw WidgetError.tokenNotFound
        }
        
        // Create NotionToken
        let notionToken = NotionToken(
            id: tokenUUID,
            name: token.name ?? "Unknown",
            apiToken: apiToken
        )
        
        // Create API client using token
        let client = NotionAPIClient(token: notionToken.apiToken)
        
        // Query the database to calculate progress
        let request = NotionQueryDatabaseRequest(pageSize: 100)
        let response = try await client.queryDatabase(databaseID: databaseID, requestBody: request)
        
        // Calculate current and target values
        var currentValue: Double = 0
        var targetValue: Double = 0
        
        for page in response.results {
            // Extract property values
            if let properties = page.properties {
                // Current value property
                if let prop = properties.first(where: { $0.key.lowercased() == currentValueProperty.lowercased() }) {
                    // Use the value property of JSONAny, following TaskWidgetProvider's pattern
                    if let propDict = prop.value.value.getValueDictionary(),
                       let number = propDict["number"] as? Double {
                        currentValue += number
                    }
                }
                
                // Target value property
                if let prop = properties.first(where: { $0.key.lowercased() == targetValueProperty.lowercased() }) {
                    // Use the value property of JSONAny, following TaskWidgetProvider's pattern
                    if let propDict = prop.value.value.getValueDictionary(),
                       let number = propDict["number"] as? Double {
                        targetValue += number
                    }
                }
            }
        }
        
        // Create progress data
        let progress = ProgressData(title: title, currentValue: currentValue, targetValue: targetValue)
        
        // Cache the result
        if let userDefaults = UserDefaults(suiteName: "group.com.nactions") {
            cacheProgress(userDefaults: userDefaults, progress: progress, tokenID: tokenID, databaseID: databaseID)
        }
        
        return progress
    }
    
    // MARK: - Caching Helpers
    
    private func getCachedProgress(userDefaults: UserDefaults, tokenID: String, databaseID: String) -> ProgressData? {
        let key = "nactions_progress_\(tokenID)_\(databaseID)"
        
        guard let dict = userDefaults.dictionary(forKey: key),
              let timestamp = dict["timestamp"] as? TimeInterval,
              let title = dict["title"] as? String,
              let currentValue = dict["currentValue"] as? Double,
              let targetValue = dict["targetValue"] as? Double else {
            return nil
        }
        
        // Check if cache has expired (1 hour)
        guard Date().timeIntervalSince1970 - timestamp <= 3600 else {
            return nil
        }
        
        return ProgressData(title: title, currentValue: currentValue, targetValue: targetValue)
    }
    
    private func cacheProgress(userDefaults: UserDefaults, progress: ProgressData, tokenID: String, databaseID: String) {
        let key = "nactions_progress_\(tokenID)_\(databaseID)"
        
        let progressDict: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "title": progress.title,
            "currentValue": progress.currentValue,
            "targetValue": progress.targetValue
        ]
        
        userDefaults.set(progressDict, forKey: key)
    }
}
