// NactionsKit/BusinessLogic/WidgetDataSharingService.swift
import Foundation
import WidgetKit

/// Service for sharing data between the main app and widgets
public final class WidgetDataSharingService {
    public static let shared = WidgetDataSharingService()
    
    // MARK: - Widget Operations
    
    /// Refreshes all widgets
    public func refreshAllWidgets() async {
        print("🔄 Refreshing all widgets")
        
        // Make sure we have access to the shared container
        guard let userDefaults = UserDefaults(suiteName: AppGroupConfig.appGroupIdentifier) else {
            print("❌ Failed to access shared UserDefaults for widget refresh")
            return
        }
        
        // Share token data
        shareTokenData(to: userDefaults)
        
        // Share database data for each activated token
        let tokens = TokenDataController.shared.fetchTokens().filter { $0.isActivated }
        print("📲 Sharing data for \(tokens.count) activated tokens")
        
        for token in tokens {
            await shareDatabaseData(for: token.id, to: userDefaults)
            
            // Also share task data for widget-enabled databases
            let databases = DatabaseDataController.shared.fetchDatabases(for: token.id)
            let enabledDatabases = databases.filter { $0.widgetEnabled }
            
            print("📁 Sharing data for \(enabledDatabases.count) enabled databases")
            for database in enabledDatabases {
                if let databaseID = database.id {
                    await shareTaskData(for: token.id, databaseID: databaseID, to: userDefaults)
                }
            }
        }
        
        // Refresh widgets
        print("🔄 Requesting widget timeline reload")
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Data Sharing Methods
    
    /// Shares token data with widgets
    private func shareTokenData(to userDefaults: UserDefaults) {
        print("🔑 Sharing token data")
        let tokens = TokenDataController.shared.fetchTokens()
        
        // Convert to a lightweight representation for widgets
        let widgetTokens = tokens.map { token -> [String: Any] in
            return [
                "id": token.id.uuidString,
                "name": token.name,
                "isConnected": token.isConnected,
                "isActivated": token.isActivated
            ]
        }
        
        // Store in shared UserDefaults
        userDefaults.set(widgetTokens, forKey: "nactions_tokens")
        print("✅ Stored \(tokens.count) tokens in shared UserDefaults")
    }
    
    /// Shares database data with widgets for a specific token
    private func shareDatabaseData(for tokenID: UUID, to userDefaults: UserDefaults) async {
        print("🗃️ Sharing database data for token: \(tokenID)")
        
        do {
            // Get the token
            let tokens = TokenDataController.shared.fetchTokens()
            guard let _ = tokens.first(where: { $0.id == tokenID }),
                  let apiToken = TokenDataController.shared.getSecureToken(for: tokenID.uuidString) else {
                print("❌ Token not found: \(tokenID)")
                return
            }
            
            // Create API client
            let client = NotionAPIClient(token: apiToken)
            
            // First try to get databases from Core Data
            let databaseEntities = DatabaseDataController.shared.fetchDatabases(for: tokenID)
            var databases: [[String: Any]] = []
            
            if !databaseEntities.isEmpty {
                print("📚 Using \(databaseEntities.count) databases from Core Data")
                // Convert Core Data entities to dictionaries
                databases = databaseEntities.compactMap { database -> [String: Any]? in
                    guard let dbID = database.id,
                          let title = database.title else {
                        return nil
                    }
                    
                    return [
                        "id": dbID,
                        "title": title,
                        "widgetEnabled": database.widgetEnabled,
                        "widgetType": database.widgetType ?? "",
                        "url": database.url ?? ""
                    ]
                }
            } else {
                print("🔍 No databases in Core Data, fetching from Notion API")
                // If no data in Core Data, fetch from API
                let filter = NotionSearchFilter()
                filter.property = "object"
                filter.value = "database"
                
                let searchResults = try await client.searchByTitle(filter: filter, pageSize: 100)
                
                // Fetch full database details
                for result in searchResults.results where result.object == "database" {
                    do {
                        let database = try await client.retrieveDatabase(databaseID: result.id)
                        let dbDict: [String: Any] = [
                            "id": database.id,
                            "title": database.title?.first?.plainText ?? "Untitled",
                            "url": database.url ?? "",
                            "widgetEnabled": false,
                            "widgetType": ""
                        ]
                        
                        databases.append(dbDict)
                    } catch {
                        print("⚠️ Error fetching database \(result.id): \(error)")
                    }
                }
            }
            
            // Store in shared UserDefaults
            if !databases.isEmpty {
                userDefaults.set(databases, forKey: "nactions_databases_\(tokenID.uuidString)")
                print("✅ Stored \(databases.count) databases for token \(tokenID)")
            } else {
                print("⚠️ No databases found for token \(tokenID)")
            }
        } catch {
            print("❌ Error sharing database data: \(error)")
        }
    }
    
    /// Shares task data with widgets for a specific database
    private func shareTaskData(for tokenID: UUID, databaseID: String, to userDefaults: UserDefaults) async {
        print("📋 Sharing task data for database: \(databaseID)")
        
        do {
            // First try to get tasks from Core Data
            let taskEntities = TaskDataController.shared.fetchTasks(for: databaseID)
            var tasks: [TaskItem] = []
            
            if !taskEntities.isEmpty {
                print("📝 Using \(taskEntities.count) tasks from Core Data")
                // Convert Core Data entities to TaskItems
                tasks = taskEntities.map { $0.toTaskItem() }
            } else {
                print("🔍 No tasks in Core Data, fetching from Notion API")
                // If no data in Core Data, fetch from API
                
                // Get the token
                let tokens = TokenDataController.shared.fetchTokens()
                guard let _ = tokens.first(where: { $0.id == tokenID }),
                      let apiToken = TokenDataController.shared.getSecureToken(for: tokenID.uuidString) else {
                    print("❌ Token not found: \(tokenID)")
                    return
                }
                
                // Create API client
                let client = NotionAPIClient(token: apiToken)
                
                // Query the database for tasks
                let request = NotionQueryDatabaseRequest(pageSize: 10)
                
                let response = try await client.queryDatabase(databaseID: databaseID, requestBody: request)
                
                // Convert to task items
                for page in response.results {
                    // Extract task data from page properties
                    let taskTitle = extractTitleFromPage(page)
                    let isCompleted = extractCompletionStatusFromPage(page)
                    let dueDate = extractDueDateFromPage(page)
                    
                    let task = TaskItem(
                        id: page.id,
                        title: taskTitle,
                        isCompleted: isCompleted,
                        dueDate: dueDate
                    )
                    
                    tasks.append(task)
                }
            }
            
            // Cache the tasks for widgets
            cacheTasksForWidgets(tasks, tokenID: tokenID.uuidString, databaseID: databaseID, userDefaults: userDefaults)
            print("✅ Cached \(tasks.count) tasks for widgets")
        } catch {
            print("❌ Error sharing task data: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Caches tasks for widget use
    private func cacheTasksForWidgets(
        _ tasks: [TaskItem],
        tokenID: String,
        databaseID: String,
        userDefaults: UserDefaults
    ) {
        // Convert tasks to dictionaries
        let taskDicts = tasks.map { task -> [String: Any] in
            var dict: [String: Any] = [
                "id": task.id,
                "title": task.title,
                "isCompleted": task.isCompleted
            ]
            
            if let dueDate = task.dueDate {
                dict["dueDate"] = dueDate.timeIntervalSince1970
            }
            
            return dict
        }
        
        // Store with timestamp
        let cacheData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "tasks": taskDicts
        ]
        
        userDefaults.set(cacheData, forKey: "nactions_tasks_\(tokenID)_\(databaseID)")
    }
    
    /// Extracts the title from a Notion page
    private func extractTitleFromPage(_ page: NotionPage) -> String {
        if let properties = page.properties,
           let titleProp = properties.first(where: { $0.key.lowercased().contains("title") || $0.key.lowercased().contains("name") }) {
            
            // Use extension method instead of direct casting
            if let titleDict = titleProp.value.value.getValueDictionary(),
               let titleArray = titleDict["title"] as? [[String: Any]] {
                
                // Extract text from title elements
                let texts = titleArray.compactMap { item -> String? in
                    if let textObj = item["text"] as? [String: Any],
                       let content = textObj["content"] as? String {
                        return content
                    }
                    return nil
                }
                
                return texts.joined()
            }
        }
        
        return "Untitled"
    }
    
    /// Extracts the completion status from a Notion page
    private func extractCompletionStatusFromPage(_ page: NotionPage) -> Bool {
        if let properties = page.properties {
            // Look for common status/checkbox property names
            for propName in ["status", "complete", "done", "completed", "checkbox"] {
                if let prop = properties.first(where: { $0.key.lowercased().contains(propName) }) {
                    // Use extension method instead of direct casting
                    if let propDict = prop.value.value.getValueDictionary() {
                        // Try to extract checkbox value
                        if let checkbox = propDict["checkbox"] as? Bool {
                            return checkbox
                        }
                        
                        // Try to extract select value
                        if let select = propDict["select"] as? [String: Any],
                           let name = select["name"] as? String {
                            return ["done", "complete", "completed"].contains(name.lowercased())
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    /// Extracts the due date from a Notion page
    private func extractDueDateFromPage(_ page: NotionPage) -> Date? {
        if let properties = page.properties {
            // Look for date property
            for propName in ["date", "due", "deadline", "due date"] {
                if let prop = properties.first(where: { $0.key.lowercased().contains(propName) }) {
                    // Use extension method instead of direct casting
                    if let propDict = prop.value.value.getValueDictionary(),
                       let dateObj = propDict["date"] as? [String: Any],
                       let dateStr = dateObj["start"] as? String {
                        
                        // Parse ISO 8601 date
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        return formatter.date(from: dateStr)
                    }
                }
            }
        }
        
        return nil
    }
}
