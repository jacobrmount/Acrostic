// DataManagement/Controllers/DatabaseDataController.swift
import Foundation
import CoreData
import Combine

/// Manages all database-related Core Data operations
public final class DatabaseDataController {
    /// The shared singleton instance
    public static let shared = DatabaseDataController()
    
    private init() {}
    
    // MARK: - Fetch Operations
    
    /// Fetches all databases
    public func fetchDatabases() -> [DatabaseEntity] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching databases: \(error)")
            return []
        }
    }
    
    /// Fetches databases for a specific token
    public func fetchDatabases(for tokenID: UUID) -> [DatabaseEntity] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
        request.predicate = NSPredicate(format: "token.id == %@", tokenID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching databases for token \(tokenID): \(error)")
            return []
        }
    }
    
    /// Fetches databases as DatabaseViewModel structs for a specific token
    public func fetchDatabaseViewModels(for tokenID: UUID) -> [DatabaseViewModelInternal] {
        return fetchDatabases(for: tokenID).map { $0.toDatabaseViewModel() }
    }
    
    /// Fetches databases that are enabled for widgets
    public func fetchWidgetEnabledDatabases() -> [DatabaseEntity] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
        request.predicate = NSPredicate(format: "widgetEnabled == true")
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching widget-enabled databases: \(error)")
            return []
        }
    }
    
    /// Fetches a specific database by ID
    public func fetchDatabase(id: String) -> DatabaseEntity? {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching database with ID \(id): \(error)")
            return nil
        }
    }
    
    // MARK: - Create/Update Operations
    
    /// Creates or updates a database from a NotionDatabase model
    public func saveDatabase(from notionDatabase: NotionDatabase, for tokenID: UUID) async -> DatabaseEntity? {
        let context = CoreDataStack.shared.viewContext
        
        // Check if the database already exists
        let request = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
        request.predicate = NSPredicate(format: "id == %@", notionDatabase.id)
        
        // Find the token
        let tokenRequest = NSFetchRequest<NSManagedObject>(entityName: "TokenEntity")
        tokenRequest.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
        
        do {
            let tokenObjects = try context.fetch(tokenRequest)
            guard let tokenObject = tokenObjects.first,
                  let token = tokenObject as? TokenEntity else {
                print("Token with ID \(tokenID) not found")
                return nil
            }
            
            let existingDatabases = try context.fetch(request)
            
            if let existingDatabase = existingDatabases.first {
                // Update existing database
                existingDatabase.update(from: notionDatabase)
                existingDatabase.token = token
                try context.save()
                return existingDatabase
            } else {
                // Create new database
                let newDatabase = DatabaseEntity(context: context)
                newDatabase.id = notionDatabase.id
                newDatabase.createdTime = notionDatabase.createdTime
                newDatabase.lastEditedTime = notionDatabase.lastEditedTime
                newDatabase.title = notionDatabase.title?.first?.plainText ?? "Untitled"
                newDatabase.databaseDescription = notionDatabase.description?.first?.plainText
                newDatabase.url = notionDatabase.url
                newDatabase.lastSyncTiime = Date()  // Using lastSyncTiime instead of lastSyncTime
                newDatabase.widgetEnabled = false
                newDatabase.token = token
                
                try context.save()
                return newDatabase
            }
        } catch {
            print("Error saving database: \(error)")
            return nil
        }
    }
    
    /// Saves multiple databases from an API response
    public func saveDatabases(from notionDatabases: [NotionDatabase], for tokenID: UUID) async -> [DatabaseEntity] {
        var savedDatabases: [DatabaseEntity] = []
        
        for database in notionDatabases {
            if let saved = await saveDatabase(from: database, for: tokenID) {
                savedDatabases.append(saved)
            }
        }
        
        return savedDatabases
    }
    
    /// Toggles the widget enabled status for a database
    public func toggleWidgetEnabled(databaseID: String, enabled: Bool) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
        request.predicate = NSPredicate(format: "id == %@", databaseID)
        
        do {
            if let database = try context.fetch(request).first {
                database.widgetEnabled = enabled
                try context.save()
                print("Database widget status updated to: \(enabled)")
            } else {
                print("Database with ID \(databaseID) not found")
            }
        } catch {
            print("Error updating database widget status: \(error)")
        }
    }
    
    /// Sets the widget type for a database
    public func setWidgetType(databaseID: String, type: String) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
        request.predicate = NSPredicate(format: "id == %@", databaseID)
        
        do {
            if let database = try context.fetch(request).first {
                database.widgetType = type
                try context.save()
                print("Database widget type updated to: \(type)")
            } else {
                print("Database with ID \(databaseID) not found")
            }
        } catch {
            print("Error updating database widget type: \(error)")
        }
    }
    
    // MARK: - Delete Operations
    
    /// Deletes all databases for a specific token
    public func deleteDatabases(for tokenID: UUID) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
        request.predicate = NSPredicate(format: "token.id == %@", tokenID as CVarArg)
        
        do {
            let databases = try context.fetch(request)
            for database in databases {
                context.delete(database)
            }
            try context.save()
            print("Deleted \(databases.count) databases for token \(tokenID)")
        } catch {
            print("Error deleting databases for token \(tokenID): \(error)")
        }
    }
    
    /// Deletes a specific database
    public func deleteDatabase(id: String) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
        request.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            if let database = try context.fetch(request).first {
                context.delete(database)
                try context.save()
                print("Database deleted successfully")
            } else {
                print("Database with ID \(id) not found for deletion")
            }
        } catch {
            print("Error deleting database: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates a task mapping from a database's pages
    public func createTasksFromPages(_ pages: [PageEntity], databaseID: String, tokenID: UUID) -> [TaskEntity] {
        let context = CoreDataStack.shared.viewContext
        var tasks: [TaskEntity] = []
        
        for page in pages {
            // Create task
            let task = TaskEntity(context: context)
            task.id = page.id
            task.title = page.title
            task.isCompleted = false // Default
            task.dueDate = nil // Default
            task.pageID = page.id
            task.databaseID = databaseID
            task.tokenID = tokenID
            task.lastSyncTime = Date()
            
            tasks.append(task)
        }
        
        do {
            try context.save()
        } catch {
            print("Error saving tasks: \(error)")
        }
        
        return tasks
    }
}
