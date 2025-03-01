// NactionsKit/DataManagement/Controllers/WidgetDataController.swift
import Foundation
import CoreData
import WidgetKit

/// Manages all widget-related Core Data operations
public final class WidgetDataController {
    /// The shared singleton instance
    public static let shared = WidgetDataController()
    
    private init() {}
    
    // MARK: - Fetch Operations
    
    /// Fetches all widget configurations
    public func fetchWidgetConfigurations() -> [WidgetConfigurationEntity] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<WidgetConfigurationEntity>(entityName: "WidgetConfigurationEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching widget configurations: \(error)")
            return []
        }
    }
    
    /// Fetches widgets for a specific token
    public func fetchWidgets(for tokenID: UUID) -> [WidgetConfigurationEntity] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<WidgetConfigurationEntity>(entityName: "WidgetConfigurationEntity")
        request.predicate = NSPredicate(format: "tokenID == %@", tokenID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching widgets for token \(tokenID): \(error)")
            return []
        }
    }
    
    /// Fetches widgets for a specific database
    public func fetchWidgets(for databaseID: String) -> [WidgetConfigurationEntity] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<WidgetConfigurationEntity>(entityName: "WidgetConfigurationEntity")
        request.predicate = NSPredicate(format: "databaseID == %@", databaseID)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching widgets for database \(databaseID): \(error)")
            return []
        }
    }
    
    /// Fetches widgets by widget kind
    public func fetchWidgets(ofKind kind: String) -> [WidgetConfigurationEntity] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<WidgetConfigurationEntity>(entityName: "WidgetConfigurationEntity")
        request.predicate = NSPredicate(format: "widgetKind == %@", kind)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching widgets of kind \(kind): \(error)")
            return []
        }
    }
    
    /// Fetches a specific widget configuration by ID
    public func fetchWidget(id: UUID) -> WidgetConfigurationEntity? {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<WidgetConfigurationEntity>(entityName: "WidgetConfigurationEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching widget with ID \(id): \(error)")
            return nil
        }
    }
    
    // MARK: - Create/Update Operations
    
    /// Creates a new widget configuration
    @discardableResult
    public func createWidget(
        name: String,
        tokenID: UUID,
        databaseID: String?,
        widgetKind: String,
        widgetFamily: String,
        configuration: [String: Any]
    ) -> WidgetConfigurationEntity? {
        let context = CoreDataStack.shared.viewContext
        
        let widget = WidgetConfigurationEntity(context: context)
        widget.id = UUID()
        widget.name = name
        widget.tokenID = tokenID
        widget.databaseID = databaseID
        widget.widgetKind = widgetKind
        widget.widgetFamily = widgetFamily
        widget.lastUpdated = Date()
        
        // Serialize configuration to data
        do {
            let configData = try PropertyListSerialization.data(
                fromPropertyList: configuration,
                format: .binary,
                options: 0
            )
            widget.configData = configData
            try context.save()
            return widget
        } catch {
            print("Error creating widget configuration: \(error)")
            return nil
        }
    }
    
    /// Updates an existing widget configuration
    public func updateWidget(
        id: UUID,
        name: String? = nil,
        configuration: [String: Any]? = nil
    ) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<WidgetConfigurationEntity>(entityName: "WidgetConfigurationEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let widget = try context.fetch(request).first {
                if let name = name {
                    widget.name = name
                }
                
                if let configuration = configuration {
                    let configData = try PropertyListSerialization.data(
                        fromPropertyList: configuration,
                        format: .binary,
                        options: 0
                    )
                    widget.configData = configData
                }
                
                widget.lastUpdated = Date()
                try context.save()
                print("Widget updated successfully")
            } else {
                print("Widget with ID \(id) not found for update")
            }
        } catch {
            print("Error updating widget: \(error)")
        }
    }
    
    // MARK: - Delete Operations
    
    /// Deletes a widget configuration by ID
    public func deleteWidget(id: UUID) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<WidgetConfigurationEntity>(entityName: "WidgetConfigurationEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let widget = try context.fetch(request).first {
                context.delete(widget)
                try context.save()
                print("Widget deleted successfully")
            } else {
                print("Widget with ID \(id) not found for deletion")
            }
        } catch {
            print("Error deleting widget: \(error)")
        }
    }
    
    /// Deletes all widgets for a specific token
    public func deleteWidgets(for tokenID: UUID) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<WidgetConfigurationEntity>(entityName: "WidgetConfigurationEntity")
        request.predicate = NSPredicate(format: "tokenID == %@", tokenID as CVarArg)
        
        do {
            let widgets = try context.fetch(request)
            for widget in widgets {
                context.delete(widget)
            }
            try context.save()
            print("Deleted \(widgets.count) widgets for token \(tokenID)")
        } catch {
            print("Error deleting widgets for token \(tokenID): \(error)")
        }
    }
    
    /// Deletes all widgets for a specific database
    public func deleteWidgets(for databaseID: String) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<WidgetConfigurationEntity>(entityName: "WidgetConfigurationEntity")
        request.predicate = NSPredicate(format: "databaseID == %@", databaseID)
        
        do {
            let widgets = try context.fetch(request)
            for widget in widgets {
                context.delete(widget)
            }
            try context.save()
            print("Deleted \(widgets.count) widgets for database \(databaseID)")
        } catch {
            print("Error deleting widgets for database \(databaseID): \(error)")
        }
    }
    
    // MARK: - Widget Update Operations
    
    /// Refreshes all widgets
    public func refreshAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Refreshes widgets of a specific kind
    public func refreshWidgets(ofKind kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
    
    // Fix for the shareDataWithWidgets method in WidgetDataController

    public func shareDataWithWidgets() {
        guard let userDefaults = UserDefaults(suiteName: "group.com.nactions") else {
            print("Failed to access shared UserDefaults")
            return
        }
        
        // Share token data
        let tokenController = TokenDataController.shared
        let tokens = tokenController.fetchTokens()
        
        let tokensData = tokens.map { token -> [String: Any] in
            return [
                "id": token.id.uuidString,
                "name": token.name,
                "isConnected": token.isConnected
            ]
        }
        
        userDefaults.set(tokensData, forKey: "nactions_tokens")
        
        // Share database data for each token
        let dbController = DatabaseDataController.shared
        for token in tokens {
            let tokenID = token.id
            let databases = dbController.fetchDatabases(for: tokenID)
            let databasesData = databases.map { db -> [String: Any] in
                return [
                    "id": db.id ?? "",
                    "title": db.title ?? "Untitled",
                    "widgetEnabled": db.widgetEnabled,
                    "widgetType": db.widgetType ?? "",
                    "url": db.url ?? ""
                ]
            }
            userDefaults.set(databasesData, forKey: "nactions_databases_\(tokenID.uuidString)")
        }
        
        // Share task data for widget-enabled databases
        let enabledDatabases = dbController.fetchWidgetEnabledDatabases()
        let taskController = TaskDataController.shared
        
        for database in enabledDatabases {
            if let dbID = database.id {
                let tasks = taskController.fetchTaskItems(for: dbID)
                
                if !tasks.isEmpty {
                    let tasksData = tasks.map { task -> [String: Any] in
                        var taskDict: [String: Any] = [
                            "id": task.id,
                            "title": task.title,
                            "isCompleted": task.isCompleted
                        ]
                        
                        if let dueDate = task.dueDate {
                            taskDict["dueDate"] = dueDate.timeIntervalSince1970
                        }
                        
                        return taskDict
                    }
                    
                    let taskCache: [String: Any] = [
                        "timestamp": Date().timeIntervalSince1970,
                        "tasks": tasksData
                    ]
                    
                    if let tokenID = database.token?.id {
                        userDefaults.set(taskCache, forKey: "nactions_tasks_\(tokenID.uuidString)_\(dbID)")
                    }
                }
            }
        }
        
        // Refresh all widgets
        refreshAllWidgets()
    }
}
