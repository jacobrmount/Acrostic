// AcrostiKit/Domain/Services/WidgetDataSharingService.swift
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
        guard let userDefaults = AppGroupConfig.sharedUserDefaults else {
            print("❌ Failed to access shared UserDefaults for widget refresh")
            
            // Verify app group access for better diagnostics
            let accessResult = AppGroupConfig.verifyAppGroupAccess()
            print("🔍 App group access verification result: \(accessResult)")
            return
        }
        
        // Share token data
        shareTokenData(to: userDefaults)
        
        // Share database data for each activated token
        let tokens = TokenService.shared.activatedTokens.filter { $0.isActivated }
        print("📲 Sharing data for \(tokens.count) activated tokens")
        
        for token in tokens {
            guard let tokenID = token.id else { continue }
            await shareDatabaseData(for: tokenID, to: userDefaults)
            
            // Also share task data for widget-enabled databases
            let databases = DatabaseController.shared.fetchDatabases(for: tokenID)
            let enabledDatabases = databases.filter {
                (($0.value(forKey: "widgetEnabled") as? Bool) ?? false)
            }
            
            print("📁 Sharing data for \(enabledDatabases.count) enabled databases")
            for database in enabledDatabases {
                if let databaseID = database.value(forKey: "id") as? String,
                   let tokenID = token.id {
                    await shareTaskData(for: tokenID, databaseID: databaseID, to: userDefaults)
                }
            }
        }
        
        // Clean up expired cache data
        cleanupExpiredCaches(in: userDefaults)
        
        // Prepare widget configuration data
        await prepareWidgetConfigurationData()
        
        // Refresh widgets
        print("🔄 Requesting widget timeline reload")
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Data Sharing Methods
    
    /// Shares token data with widgets
    private func shareTokenData(to userDefaults: UserDefaults) {
        print("🔑 Sharing token data")
        
        // Verify we can write to the container before proceeding
        let testKey = "widget_token_write_test"
        userDefaults.set(true, forKey: testKey)
        userDefaults.synchronize()
        
        if !userDefaults.bool(forKey: testKey) {
            print("⚠️ Warning: Failed to verify UserDefaults write access")
        }
        
        let tokens = TokenService.shared.tokens
        
        // Convert to a lightweight representation for widgets
        let widgetTokens = tokens.compactMap { token -> [String: Any]? in
            guard let tokenID = token.id else { return nil }
            return [
                "id": tokenID.uuidString,
                "name": token.workspaceName ?? "Unknown",
                "isConnected": token.connectionStatus,
                "isActivated": token.isActivated
            ]
        }
        
        // Store in shared UserDefaults
        userDefaults.set(widgetTokens, forKey: "acrostic_tokens")
        userDefaults.synchronize()
        print("✅ Stored \(tokens.count) tokens in shared UserDefaults")
    }
    
    /// Shares database data with widgets for a specific token
    private func shareDatabaseData(for tokenID: UUID, to userDefaults: UserDefaults) async {
        print("🗃️ Sharing database data for token: \(tokenID)")
        
        do {
            // Verify container access first
            let testKey = "widget_database_write_test_\(tokenID.uuidString)"
            userDefaults.set(true, forKey: testKey)
            userDefaults.synchronize()
            
            if !userDefaults.bool(forKey: testKey) {
                print("⚠️ Warning: Failed to verify UserDefaults write access for database data")
            }
            
            // Get the token
            let tokens = TokenService.shared.tokens
            guard tokens.contains(where: { $0.id == tokenID }),
                  let apiToken = TokenService.shared.getSecureToken(for: tokenID.uuidString) else {
                print("❌ Token not found: \(tokenID)")
                return
            }
            
            // First try to get databases from File Selector's selected items
            let fileService = FileService.shared
            let selectedDatabases = fileService.fileGroups.flatMap { group -> [[String: Any]] in
                return group.files.filter { $0.isSelected && $0.tokenID == tokenID }.map { file -> [String: Any] in
                    return [
                        "id": file.id,
                        "title": file.title,
                        "widgetEnabled": true,
                        "widgetType": file.type == .database ? "database" : "page",
                        "url": ""
                    ]
                }
            }
            
            if !selectedDatabases.isEmpty {
                print("📚 Using \(selectedDatabases.count) selected databases from File Selector")
                userDefaults.set(selectedDatabases, forKey: "acrostic_databases_\(tokenID.uuidString)")
                userDefaults.synchronize()
                return
            }
            
            // Create API client
            let client = NotionAPIClient(token: apiToken)
            
            // Query the database to calculate progress
            var databases: [[String: Any]] = []
            
            // First try to get databases from Core Data
            let databaseEntities = DatabaseController.shared.fetchDatabases(for: tokenID)
            
            if !databaseEntities.isEmpty {
                print("📚 Using \(databaseEntities.count) databases from Core Data")
                // Convert Core Data entities to dictionaries
                databases = databaseEntities.compactMap { database -> [String: Any]? in
                    guard let dbID = database.value(forKey: "id") as? String, !dbID.isEmpty else {
                        return nil
                    }
                    
                    let title = (database.value(forKey: "titleString") as? String) ?? "Untitled"
                    
                    return [
                        "id": dbID,
                        "title": title,
                        "widgetEnabled": database.value(forKey: "widgetEnabled") as? Bool ?? false,
                        "widgetType": database.value(forKey: "widgetType") as? String ?? "",
                        "url": database.value(forKey: "url") as? String ?? ""
                    ]
                }
            } else {
                print("🔍 No databases in Core Data, fetching from Notion API")
                // If no data in Core Data, fetch from API
                let searchResults = try await client.search(requestBody: [
                    "filter": ["property": "object", "value": "database"],
                    "page_size": 100
                ])
                
                // Extract databases
                for result in searchResults.results where result.object == "database" {
                    if let database = result as? NotionDatabase {
                        guard !database.id.isEmpty else {
                            continue
                        }
                        
                        let dbDict: [String: Any] = [
                            "id": database.id,
                            "title": database.getTitleText(),
                            "url": database.url ?? "",
                            "widgetEnabled": false,
                            "widgetType": ""
                        ]
                        
                        databases.append(dbDict)
                    }
                }
            }
            
            print("🔍 Database IDs being stored: \(databases.map { $0["id"] as? String ?? "unknown" })")

            // Store in shared UserDefaults
            if !databases.isEmpty {
                userDefaults.set(databases, forKey: "acrostic_databases_\(tokenID.uuidString)")
                userDefaults.synchronize()
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
            // Verify container access first
            let testKey = "widget_task_write_test_\(tokenID.uuidString)_\(databaseID)"
            userDefaults.set(true, forKey: testKey)
            userDefaults.synchronize()
            
            if !userDefaults.bool(forKey: testKey) {
                print("⚠️ Warning: Failed to verify UserDefaults write access for task data")
            }
            
            // Get tasks from Core Data or API
            let taskEntities = TaskDataController.shared.fetchTasks(for: databaseID)
            var tasks: [TaskItem] = []
            
            if !taskEntities.isEmpty {
                print("📝 Using \(taskEntities.count) tasks from Core Data")
                // Convert to TaskItems
                tasks = taskEntities.compactMap { $0.toTaskItem() }
            } else {
                print("🔍 No tasks in Core Data, fetching from Notion API")
                
                // Get API token
                guard let apiToken = TokenService.shared.getSecureToken(for: tokenID.uuidString) else {
                    print("❌ Token not found: \(tokenID)")
                    return
                }
                
                // Create API client
                let client = NotionAPIClient(token: apiToken)
                
                // Query the database
                let request = NotionQueryDatabaseRequest(pageSize: 10)
                let response = try await client.queryDatabase(databaseID: databaseID, requestBody: request)
                
                // Convert to task items
                for page in response.results {
                    tasks.append(TaskItem(
                        id: page.id,
                        title: extractTitleFromPage(page),
                        isCompleted: extractCompletionStatusFromPage(page),
                        dueDate: extractDueDateFromPage(page)
                    ))
                }
            }
            
            // Cache the tasks for widgets
            cacheTasksForWidgets(tasks, tokenID: tokenID.uuidString, databaseID: databaseID, userDefaults: userDefaults)
            print("✅ Cached \(tasks.count) tasks for widgets")
        } catch {
            print("❌ Error sharing task data: \(error)")
        }
    }

    /// Prepares data specifically for widget configuration UI
    public func prepareWidgetConfigurationData() async {
        print("🔄 Preparing widget configuration data")
        
        // Make sure we have access to the shared container
        guard let userDefaults = AppGroupConfig.sharedUserDefaults else {
            print("❌ Failed to access shared UserDefaults for widget configuration")
            return
        }
        
        // Share all databases from all tokens with specific format for widget configuration
        let tokens = TokenService.shared.tokens
        for token in tokens {
            guard let tokenID = token.id else { continue }
            
            // Get all files from FileService, both selected and unselected
            let allFiles = FileService.shared.fileGroups.flatMap { group -> [FileMetadata] in
                return group.files.filter { $0.tokenID == tokenID }
            }
            
            // Convert to the format expected by widget configuration
            let configDatabases = allFiles.map { file -> [String: Any] in
                return [
                    "id": file.id,
                    "title": file.title,
                    "type": file.type == .database ? "database" : "page",
                    "tokenID": file.tokenID.uuidString,
                    "isSelected": file.isSelected
                ]
            }
            
            // Store for widget configuration
            if !configDatabases.isEmpty {
                userDefaults.set(configDatabases, forKey: "widget_config_databases_\(tokenID.uuidString)")
                userDefaults.synchronize()
            }
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
        
        userDefaults.set(cacheData, forKey: "acrostic_tasks_\(tokenID)_\(databaseID)")
        userDefaults.synchronize()
    }
    
    /// Cleans up old cache data
    private func cleanupExpiredCaches(in userDefaults: UserDefaults) {
        // Get all keys
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Find cache keys
        let cacheKeys = allKeys.filter { $0.starts(with: "acrostic_tasks_") || $0.starts(with: "acrostic_progress_") }
        
        let now = Date().timeIntervalSince1970
        let maxAge: TimeInterval = 86400 * 7 // 7 days
        
        for key in cacheKeys {
            if let cacheDict = userDefaults.dictionary(forKey: key),
               let timestamp = cacheDict["timestamp"] as? TimeInterval,
               now - timestamp > maxAge {
                // Remove old cache entries
                userDefaults.removeObject(forKey: key)
            }
        }
        
        userDefaults.synchronize()
    }
    
    /// Extracts the title from a Notion page
    private func extractTitleFromPage(_ page: NotionPage) -> String {
        if let properties = page.properties,
           let titleProp = properties.first(where: { $0.key.lowercased().contains("title") || $0.key.lowercased().contains("name") }) {
            
            if let titleDict = titleProp.value.value.getValueDictionary(),
               let titleArray = titleDict["title"] as? [[String: Any]] {
                
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
            for propName in ["status", "complete", "done", "completed", "checkbox"] {
                if let prop = properties.first(where: { $0.key.lowercased().contains(propName) }) {
                    if let propDict = prop.value.value.getValueDictionary() {
                        // Check for checkbox value
                        if let checkbox = propDict["checkbox"] as? Bool {
                            return checkbox
                        }
                        
                        // Check for select value
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
            for propName in ["date", "due", "deadline", "due date"] {
                if let prop = properties.first(where: { $0.key.lowercased().contains(propName) }) {
                    if let propDict = prop.value.value.getValueDictionary(),
                       let dateObj = propDict["date"] as? [String: Any],
                       let dateStr = dateObj["start"] as? String {
                        
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
