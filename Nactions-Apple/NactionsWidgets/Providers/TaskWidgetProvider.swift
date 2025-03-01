// NactionsWidgets/Providers/TaskWidgetProvider.swift
import WidgetKit
import SwiftUI
import Foundation
import NactionsKit

struct TaskWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = TaskEntry
    typealias Intent = TaskWidgetConfigurationIntent
    
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(
            date: Date(),
            configuration: TaskWidgetConfigurationIntent(),
            tasks: NactionsKit.TaskItem.samples,
            error: nil
        )
    }
    
    func snapshot(for configuration: TaskWidgetConfigurationIntent, in context: Context) async -> TaskEntry {
        // Return sample data for the widget gallery
        TaskEntry(
            date: Date(),
            configuration: configuration,
            tasks: NactionsKit.TaskItem.samples,
            error: nil
        )
    }
    
    func timeline(for configuration: TaskWidgetConfigurationIntent, in context: Context) async -> Timeline<TaskEntry> {
        var entries: [TaskEntry] = []
        let currentDate = Date()
        
        // Check if we have the required database selection
        guard let database = configuration.databaseID else {
            print("❌ No database selected for widget")
            return Timeline(entries: [
                TaskEntry(
                    date: Date(),
                    configuration: configuration,
                    tasks: [],
                    error: "Please select a database for this widget"
                )
            ], policy: .after(Date().addingTimeInterval(300)))
        }
        
        print("✅ Using database: \(database.name) with ID: \(database.id)")
        
        do {
            // Use tokenID from the database entity and databaseID
            let tokenID = database.tokenID.uuidString
            let databaseID = database.id
            
            // Set a reasonable default task count
            let taskCount = 8
            
            // Fetch tasks from Notion using the shared data layer
            let tasks = try await fetchTasks(
                tokenID: tokenID,
                databaseID: databaseID,
                count: taskCount,
                showCompleted: configuration.showCompleted
            )
            
            // Create an entry with the fetched tasks
            let entry = TaskEntry(
                date: currentDate,
                configuration: configuration,
                tasks: tasks,
                error: nil
            )
            entries.append(entry)
            
            // Refresh every hour (or when Notion data might change)
            let nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            
            return Timeline(entries: entries, policy: .after(nextUpdateDate))
        } catch {
            print("❌ Error fetching tasks: \(error.localizedDescription)")
            let entry = TaskEntry(
                date: currentDate,
                configuration: configuration,
                tasks: [],
                error: "Failed to fetch tasks: \(error.localizedDescription)"
            )
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
        }
    }
    
    // MARK: - API Methods
    
    private func fetchTasks(tokenID: String, databaseID: String, count: Int, showCompleted: Bool) async throws -> [NactionsKit.TaskItem] {
        print("🔍 Fetching tasks for token: \(tokenID), database: \(databaseID)")
        
        // Try to get from shared UserDefaults cache first
        if let userDefaults = UserDefaults(suiteName: "group.com.nactions"),
           let cachedTasks = getCachedTasks(userDefaults: userDefaults, tokenID: tokenID, databaseID: databaseID) {
            print("✅ Using cached tasks: \(cachedTasks.count) tasks found")
            
            // Log some details about the cached tasks
            for (index, task) in cachedTasks.prefix(3).enumerated() {
                print("📝 Cached task \(index + 1): title=\"\(task.title)\", completed=\(task.isCompleted), dueDate=\(task.dueDate?.description ?? "none")")
            }
            
            // Filter by completion status if needed
            let filteredTasks = !showCompleted ? cachedTasks.filter { !$0.isCompleted } : cachedTasks
            return Array(filteredTasks.prefix(count))
        }
        
        print("⚠️ No cached tasks found, fetching from API")
        
        // If we get here, we need to fetch data from Notion API
        // First, get the token
        guard let tokenUUID = UUID(uuidString: tokenID) else {
            print("❌ Invalid token UUID: \(tokenID)")
            throw WidgetError.tokenNotFound
        }
        
        // Get token data
        let tokenDataController = NactionsKit.TokenDataController.shared
        let token = tokenDataController.fetchToken(id: tokenUUID)
        
        // If we can't find the token, throw an error
        guard let token = token,
              let apiToken = tokenDataController.getSecureToken(for: tokenUUID.uuidString) else {
            print("❌ Token not found for UUID: \(tokenUUID)")
            throw WidgetError.tokenNotFound
        }
        
        // Create NotionToken
        let notionToken = NotionToken(
            id: tokenUUID,
            name: token.name ?? "Unknown",
            apiToken: apiToken
        )
        
        // Create API client
        let client = NotionAPIClient(token: notionToken.apiToken)

        // Query the database without filters for simplicity
        let request = NotionQueryDatabaseRequest(pageSize: count)
        
        // Query the database
        print("📊 Querying Notion database: \(databaseID)")
        let response = try await client.queryDatabase(databaseID: databaseID, requestBody: request)
        print("✅ Received \(response.results.count) results from Notion API")
        
        // Debug the first page to understand its structure
        if let firstPage = response.results.first {
            print("🔍 Analyzing first page structure:")
            analyzePageProperties(firstPage)
        }
        
        // Convert response to TaskItems
        var tasks: [TaskItem] = []
        
        for (index, page) in response.results.enumerated() {
            print("📄 Processing page \(index + 1): \(page.id)")
            
            // Extract task data from page properties
            let taskTitle = extractTitleFromPage(page)
            let isCompleted = extractCompletionStatusFromPage(page)
            let dueDate = extractDueDateFromPage(page)
            
            print("📝 Extracted task: title=\"\(taskTitle)\", completed=\(isCompleted), dueDate=\(dueDate?.description ?? "none")")
            
            let task = TaskItem(
                id: page.id,
                title: taskTitle,
                isCompleted: isCompleted,
                dueDate: dueDate
            )
            
            if showCompleted || !isCompleted {
                tasks.append(task)
            }
        }
        
        // Cache results for future widget updates
        if let userDefaults = UserDefaults(suiteName: "group.com.nactions") {
            cacheTasksInUserDefaults(tasks, tokenID: tokenID, databaseID: databaseID, userDefaults: userDefaults)
            print("✅ Cached \(tasks.count) tasks for future widget updates")
        }
        
        return tasks
    }
    
    // MARK: - Improved Property Extraction Methods
    
    // Improved title extraction function
    private func extractTitleFromPage(_ page: NotionPage) -> String {
        // Add debug logging
        print("🔍 Extracting title from page: \(page.id)")
        
        // First, check if properties exist
        guard let properties = page.properties else {
            print("❌ No properties found in page")
            return "Untitled Task"
        }
        
        // Look for title or name properties
        let titleKeys = properties.keys.filter { key in
            key.lowercased().contains("title") || key.lowercased().contains("name")
        }
        
        if titleKeys.isEmpty {
            print("❌ No title or name properties found")
            print("📚 Available properties: \(properties.keys.joined(separator: ", "))")
            return "Untitled Task"
        }
        
        // Try each title key
        for titleKey in titleKeys {
            guard let titleProp = properties[titleKey] else { continue }
            
            // Print the property structure for debugging
            print("🔍 Examining property: \(titleKey)")
            
            // Try to extract title using different approaches
            
            // Approach 1: Direct title array access via value
            if let titleDict = valueAsDictionary(titleProp.value.value),
               let titleArray = titleDict["title"] as? [[String: Any]] {
                
                let texts = titleArray.compactMap { item -> String? in
                    if let textObj = item["text"] as? [String: Any],
                       let content = textObj["content"] as? String {
                        return content
                    }
                    return nil
                }
                
                if !texts.isEmpty {
                    let title = texts.joined()
                    print("✅ Found title: \"\(title)\"")
                    return title
                }
            }
            
            // Approach 2: Try to extract plain text directly
            if let dict = valueAsDictionary(titleProp.value.value),
               let plainText = dict["plain_text"] as? String {
                print("✅ Found plain text title: \"\(plainText)\"")
                return plainText
            }
            
            // Approach 3: Try to extract rich text array
            if let dict = valueAsDictionary(titleProp.value.value),
               let richTextArray = dict["rich_text"] as? [[String: Any]] {
                
                let texts = richTextArray.compactMap { item -> String? in
                    if let textObj = item["text"] as? [String: Any],
                       let content = textObj["content"] as? String {
                        return content
                    } else if let plainText = item["plain_text"] as? String {
                        return plainText
                    }
                    return nil
                }
                
                if !texts.isEmpty {
                    let title = texts.joined()
                    print("✅ Found rich text title: \"\(title)\"")
                    return title
                }
            }
        }
        
        // Last resort: see if we can find any name/title-like property values
        for (key, prop) in properties where key.lowercased().contains("title") || key.lowercased().contains("name") {
            if prop.type == "title" || prop.type == "rich_text" {
                // Special log for potential title properties we couldn't extract
                print("⚠️ Found potential title property but couldn't extract: \(key) (type: \(prop.type))")
            }
        }

        
        print("⚠️ Could not extract title - returning default")
        return "Untitled Task"
    }
    
    // Improved due date extraction function
    private func extractDueDateFromPage(_ page: NotionPage) -> Date? {
        // Add debug logging
        print("🔍 Extracting due date from page: \(page.id)")
        
        // First, check if properties exist
        guard let properties = page.properties else {
            print("❌ No properties found in page")
            return nil
        }
        
        // Look for date properties with common names
        let datePropertyNames = ["date", "due", "deadline", "due date"]
        
        for propName in datePropertyNames {
            // Find properties containing our date-related keywords
            let matchingProps = properties.filter { $0.key.lowercased().contains(propName) }
            
            for (key, prop) in matchingProps {
                print("🔍 Examining property: \(key)")
                
                // Try different approaches to extract the date
                
                // Approach 1: Standard date property structure
                if let propDict = valueAsDictionary(prop.value.value),
                   let dateObj = propDict["date"] as? [String: Any],
                   let dateStr = dateObj["start"] as? String {
                    
                    print("📅 Found date string: \"\(dateStr)\"")
                    
                    // Try parsing with different formatters
                    let formatters = [
                        // Standard ISO8601 with fractional seconds
                        { () -> ISO8601DateFormatter in
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            return formatter
                        }(),
                        // ISO8601 without fractional seconds
                        { () -> ISO8601DateFormatter in
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime]
                            return formatter
                        }(),
                        // Date-only ISO formatter
                        { () -> ISO8601DateFormatter in
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withFullDate]
                            return formatter
                        }()
                    ]
                    
                    for formatter in formatters {
                        if let date = formatter.date(from: dateStr) {
                            print("✅ Successfully parsed date: \(date)")
                            return date
                        }
                    }
                    
                    // Try a flexible date formatter as last resort
                    let flexFormatter = DateFormatter()
                    flexFormatter.dateFormat = "yyyy-MM-dd"
                    if let date = flexFormatter.date(from: dateStr) {
                        print("✅ Parsed date with flexible formatter: \(date)")
                        return date
                    }
                    
                    print("❌ Failed to parse date string: \"\(dateStr)\"")
                }
                
                // Approach 2: Try direct date access if property is a date
                if prop.type == "date" {
                    if let dateValue = prop.value.value as? String {
                        print("📅 Found direct date string: \"\(dateValue)\"")
                        
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        if let date = formatter.date(from: dateValue) {
                            print("✅ Parsed direct date: \(date)")
                            return date
                        }
                    }
                }
            }
        }
        
        print("⚠️ No due date found")
        return nil
    }
    
    // Helper for completion status extraction
    private func extractCompletionStatusFromPage(_ page: NotionPage) -> Bool {
        print("🔍 Extracting completion status from page: \(page.id)")
        
        guard let properties = page.properties else {
            print("❌ No properties found in page")
            return false
        }
        
        // Look for common status/checkbox property names
        let statusPropertyNames = ["status", "complete", "done", "completed", "checkbox"]
        
        for propName in statusPropertyNames {
            let matchingProps = properties.filter { $0.key.lowercased().contains(propName) }
            
            for (key, prop) in matchingProps {
                print("🔍 Examining property: \(key)")
                
                // Approach 1: Check for checkbox property
                if prop.type == "checkbox" {
                    if let propDict = valueAsDictionary(prop.value.value),
                       let checkbox = propDict["checkbox"] as? Bool {
                        print("✅ Found checkbox status: \(checkbox)")
                        return checkbox
                    }
                }
                
                // Approach 2: Check for select property with status values
                if prop.type == "select" {
                    if let propDict = valueAsDictionary(prop.value.value),
                       let select = propDict["select"] as? [String: Any],
                       let name = select["name"] as? String {
                        
                        let completedValues = ["done", "complete", "completed", "finished", "yes"]
                        let isCompleted = completedValues.contains(name.lowercased())
                        print("✅ Found select status: \(name) (isCompleted: \(isCompleted))")
                        return isCompleted
                    }
                }
                
                // Approach 3: Check for status property with nested values
                if let propDict = valueAsDictionary(prop.value.value) {
                    if let checkbox = propDict["checkbox"] as? Bool {
                        print("✅ Found direct checkbox value: \(checkbox)")
                        return checkbox
                    }
                    
                    if let select = propDict["select"] as? [String: Any],
                       let name = select["name"] as? String {
                        let completedValues = ["done", "complete", "completed", "finished", "yes"]
                        let isCompleted = completedValues.contains(name.lowercased())
                        print("✅ Found indirect select value: \(name) (isCompleted: \(isCompleted))")
                        return isCompleted
                    }
                }
            }
        }
        
        print("⚠️ No completion status found - assuming incomplete")
        return false
    }
    
    // MARK: - Helper Methods
    
    /// Helper to safely extract a dictionary from any value
    private func valueAsDictionary(_ value: Any) -> [String: Any]? {
        return value as? [String: Any]
    }
    
    // MARK: - Cache Methods
    
    // Cache tasks in UserDefaults for widget access
    private func cacheTasksInUserDefaults(_ tasks: [TaskItem], tokenID: String, databaseID: String, userDefaults: UserDefaults) {
        // Convert tasks to dictionary representation for storage
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
        
        // Store tasks with a timestamp
        let cacheData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "tasks": taskDicts
        ]
        
        userDefaults.set(cacheData, forKey: "nactions_tasks_\(tokenID)_\(databaseID)")
    }
    
    // Get cached tasks from UserDefaults
    private func getCachedTasks(userDefaults: UserDefaults, tokenID: String, databaseID: String) -> [TaskItem]? {
        let key = "nactions_tasks_\(tokenID)_\(databaseID)"
        
        guard let cacheData = userDefaults.dictionary(forKey: key) else {
            print("⚠️ No cached data found for key: \(key)")
            return nil
        }
        
        // Check if cache has expired (1 hour)
        guard let timestamp = cacheData["timestamp"] as? TimeInterval,
              Date().timeIntervalSince1970 - timestamp <= 3600 else {
            print("⚠️ Cache has expired for key: \(key)")
            return nil
        }
        
        guard let taskDicts = cacheData["tasks"] as? [[String: Any]] else {
            print("⚠️ Invalid task data format in cache")
            return nil
        }
        
        return taskDicts.compactMap { dict -> TaskItem? in
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String,
                  let isCompleted = dict["isCompleted"] as? Bool else {
                return nil
            }
            
            let dueDate: Date?
            if let timestamp = dict["dueDate"] as? TimeInterval {
                dueDate = Date(timeIntervalSince1970: timestamp)
            } else {
                dueDate = nil
            }
            
            return TaskItem(id: id, title: title, isCompleted: isCompleted, dueDate: dueDate)
        }
    }
    
    // MARK: - Debug Methods
    
    /// Debug helper function to analyze and log Notion page properties
    func analyzePageProperties(_ page: NotionPage) {
        print("📄 Analyzing page: \(page.id)")
        
        guard let properties = page.properties else {
            print("❌ No properties found in the page")
            return
        }
        
        print("📚 Found \(properties.count) properties")
        
        // List all properties and their types
        print("📋 Property list:")
        for (key, prop) in properties {
            print("  - \"\(key)\" (type: \(prop.type))")
        }
        
        // Look for title property
        print("🔍 Searching for title property...")
        if let titleProp = properties.first(where: { $0.key.lowercased().contains("title") || $0.key.lowercased().contains("name") }) {
            print("✅ Found title property with key: \(titleProp.key)")
            print("Title property type: \(titleProp.value.type)")
            
            if let dict = valueAsDictionary(titleProp.value.value) {
                print("Title dictionary keys: \(dict.keys.joined(separator: ", "))")
                
                if let titleArray = dict["title"] as? [[String: Any]] {
                    print("Title array has \(titleArray.count) elements")
                    
                    for (index, item) in titleArray.enumerated() {
                        print("Item \(index) keys: \(item.keys.joined(separator: ", "))")
                        
                        if let textObj = item["text"] as? [String: Any] {
                            print("Text object keys: \(textObj.keys.joined(separator: ", "))")
                            
                            if let content = textObj["content"] as? String {
                                print("Found content: \"\(content)\"")
                            }
                        }
                    }
                }
            }
        } else {
            print("❌ No title property found")
        }
        
        // Look for date property
        print("🔍 Searching for date property...")
        let datePropertyNames = ["date", "due", "deadline", "due date"]
        var foundDateProperty = false
        
        for propName in datePropertyNames {
            if let dateProp = properties.first(where: { $0.key.lowercased().contains(propName) }) {
                print("✅ Found date property with key: \(dateProp.key)")
                print("Date property type: \(dateProp.value.type)")
                
                if let dict = valueAsDictionary(dateProp.value.value) {
                    print("Date dictionary keys: \(dict.keys.joined(separator: ", "))")
                    
                    if let dateObj = dict["date"] as? [String: Any] {
                        print("Date object keys: \(dateObj.keys.joined(separator: ", "))")
                        
                        if let dateStr = dateObj["start"] as? String {
                            print("Found date string: \"\(dateStr)\"")
                        }
                    }
                }
                
                foundDateProperty = true
                break
            }
        }
        
        if !foundDateProperty {
            print("❌ No date property found")
        }
        
        // Look for status/completion property
        print("🔍 Searching for status/completion property...")
        let statusPropertyNames = ["status", "complete", "done", "completed", "checkbox"]
        var foundStatusProperty = false
        
        for propName in statusPropertyNames {
            if let statusProp = properties.first(where: { $0.key.lowercased().contains(propName) }) {
                print("✅ Found status property with key: \(statusProp.key)")
                print("Status property type: \(statusProp.value.type)")
                
                if let dict = valueAsDictionary(statusProp.value.value) {
                    print("Status dictionary keys: \(dict.keys.joined(separator: ", "))")
                }
                
                foundStatusProperty = true
                break
            }
        }
        
        if !foundStatusProperty {
            print("❌ No status property found")
        }
    }
}
