// AcrostiKit/Data/Controllers/WidgetController.swift
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
    public func fetchWidgetConfigurations() -> [NSManagedObject] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "WidgetConfiguration")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching widget configurations: \(error)")
            return []
        }
    }
    
    /// Fetches widgets for a specific token
    public func fetchWidgets(for tokenID: UUID) -> [NSManagedObject] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "WidgetConfiguration")
        request.predicate = NSPredicate(format: "token.id == %@", tokenID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching widgets for token \(tokenID): \(error)")
            return []
        }
    }
    
    /// Fetches widgets for a specific database
    public func fetchWidgets(for databaseID: String) -> [NSManagedObject] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "WidgetConfiguration")
        request.predicate = NSPredicate(format: "database.id == %@", databaseID)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching widgets for database \(databaseID): \(error)")
            return []
        }
    }
    
    /// Fetches widgets by widget kind
    public func fetchWidgets(ofKind kind: String) -> [NSManagedObject] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "WidgetConfiguration")
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
    public func fetchWidget(id: UUID) -> NSManagedObject? {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "WidgetConfiguration")
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
    ) -> NSManagedObject? {
        let context = CoreDataStack.shared.viewContext
        
        let widget = NSEntityDescription.insertNewObject(forEntityName: "WidgetConfiguration", into: context)
        widget.setValue(UUID(), forKey: "id")
        widget.setValue(name, forKey: "name")
        widget.setValue(widgetKind, forKey: "widgetKind")
        widget.setValue(widgetFamily, forKey: "widgetFamily")
        widget.setValue(Date(), forKey: "lastUpdated")
        
        // Set up token relationship
        let tokenRequest = NSFetchRequest<NSManagedObject>(entityName: "Token")
        tokenRequest.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
        
        // Set up database relationship if provided
        if let dbID = databaseID {
            let dbRequest = NSFetchRequest<NSManagedObject>(entityName: "Database")
            dbRequest.predicate = NSPredicate(format: "id == %@", dbID)
            
            do {
                if let db = try context.fetch(dbRequest).first {
                    widget.setValue(db, forKey: "database")
                }
            } catch {
                print("Error finding database: \(error)")
            }
        }
        
        do {
            if let token = try context.fetch(tokenRequest).first {
                widget.setValue(token, forKey: "token")
            }
        } catch {
            print("Error finding token: \(error)")
        }
        
        // Save the configuration using the helper method
        widget.setWidgetConfiguration(configuration)
        
        do {
            try context.save()
            return widget
        } catch {
            print("Error creating widget configuration: \(error)")
            return nil
        }
    }
    
    public func updateWidget(
        id: UUID,
        name: String? = nil,
        configuration: [String: Any]? = nil
    ) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "WidgetConfiguration")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let widget = try context.fetch(request).first {
                if let name = name {
                    widget.setValue(name, forKey: "name")
                }
                
                if let configuration = configuration {
                    widget.setWidgetConfiguration(configuration)
                }
                
                widget.setValue(Date(), forKey: "lastUpdated")
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
        let request = NSFetchRequest<NSManagedObject>(entityName: "WidgetConfiguration")
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
        let request = NSFetchRequest<NSManagedObject>(entityName: "WidgetConfiguration")
        request.predicate = NSPredicate(format: "token.id == %@", tokenID as CVarArg)
        
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
        let request = NSFetchRequest<NSManagedObject>(entityName: "WidgetConfiguration")
        request.predicate = NSPredicate(format: "database.id == %@", databaseID)
        
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
        guard let userDefaults = UserDefaults(suiteName: "group.com.acrostic") else {
            print("Failed to access shared UserDefaults")
            return
        }
        
        // Share token data
        let tokenController = TokenDataController.shared
        let tokens = tokenController.fetchTokens()
        
        let tokensData = tokens.map { token -> [String: Any] in
            return [
                "id": token.id?.uuidString ?? "",
                "name": token.workspaceName ?? "Unknown",
                "isConnected": token.connectionStatus
            ]
        }
        
        userDefaults.set(tokensData, forKey: "acrostic_tokens")
        
        // Share database data for each token
        let dbController = DatabaseController.shared
        for token in tokens {
            guard let tokenID = token.id else { continue }
            let databases = dbController.fetchDatabases(for: tokenID)
            let databasesData = databases.compactMap { db -> [String: Any]? in
                guard let dbID = db.value(forKey: "id") as? String,
                      let title = db.value(forKey: "title") as? String,
                      let widgetEnabled = db.value(forKey: "widgetEnabled") as? Bool,
                      let widgetType = db.value(forKey: "widgetType") as? String,
                      let url = db.value(forKey: "url") as? String else {
                    return nil
                }
                
                return [
                    "id": dbID,
                    "title": title,
                    "widgetEnabled": widgetEnabled,
                    "widgetType": widgetType,
                    "url": url
                ]
            }
            if let tokenID = token.id {
                userDefaults.set(databasesData, forKey: "acrostic_databases_\(tokenID.uuidString)")
            }
            
            // Share task data for widget-enabled databases
            let enabledDatabases = dbController.fetchWidgetEnabledDatabases()
            let taskController = TaskDataController.shared
            
            for database in enabledDatabases {
                if let dbID = database.value(forKey: "id") as? String {
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
                        
                        if let tokenID = database.value(forKey: "token") as? NSManagedObject,
                           let tokenUUID = tokenID.value(forKey: "id") as? UUID {
                            userDefaults.set(taskCache, forKey: "acrostic_tasks_\(tokenUUID.uuidString)_\(dbID)")
                        }
                    }
                }
            }
            
            // Refresh all widgets
            refreshAllWidgets()
        }
    }
}
