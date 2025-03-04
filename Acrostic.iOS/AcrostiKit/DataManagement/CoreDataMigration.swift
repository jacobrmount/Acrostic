// AcrostiKit/DataManagement/CoreDataMigration.swift
import Foundation
import CoreData

/// Handles migration from legacy data models to the new consolidated model
public class CoreDataMigration {
    private let coreDataStack: CoreDataStack
    
    public init(coreDataStack: CoreDataStack = CoreDataStack.shared) {
        self.coreDataStack = coreDataStack
    }
    
    /// Checks if data needs to be migrated from a legacy model and performs migration if needed
    public func migrateIfNeeded() async throws {
        // First check if migration has already been performed
        if UserDefaults.standard.bool(forKey: "CoreDataModelMigrationCompleted") {
            print("✅ Core Data migration already completed")
            return
        }
        
        // Check if we have any data to migrate by looking for records in legacy models
        let legacyDataExists = await checkForLegacyData()
        
        if legacyDataExists {
            print("ℹ️ Legacy data detected - starting migration")
            try await performMigration()
            
            // Mark migration as completed
            UserDefaults.standard.set(true, forKey: "CoreDataModelMigrationCompleted")
            print("✅ Core Data migration completed successfully")
        } else {
            print("ℹ️ No legacy data detected - skipping migration")
            UserDefaults.standard.set(true, forKey: "CoreDataModelMigrationCompleted")
        }
    }
    
    /// Checks if there is any data in the legacy models that needs to be migrated
    private func checkForLegacyData() async -> Bool {
        // Here we check for the existence of any entities from the old model
        let result = await withCheckedContinuation { continuation in
            coreDataStack.performBackgroundTask { context in
                do {
                    // Check for TokenEntity from the old model (different from Token in new model)
                    let tokenEntityRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TokenEntity")
                    tokenEntityRequest.fetchLimit = 1
                    
                    let count = try context.count(for: tokenEntityRequest)
                    continuation.resume(returning: count > 0)
                } catch {
                    print("Error checking for legacy data: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
        
        return result
    }
    
    /// Performs the actual migration from legacy models to the new consolidated model
    private func performMigration() async throws {
        try await coreDataStack.performBackgroundTask { context in
            // 1. Migrate TokenEntity to Token
            try self.migrateTokens(in: context)
            
            // 2. Migrate DatabaseEntity to Database
            try self.migrateDatabases(in: context)
            
            // 3. Migrate PageEntity to Page
            try self.migratePages(in: context)
            
            // 4. Migrate TaskEntity to Task
            try self.migrateTasks(in: context)
            
            // 5. Migrate WidgetConfigurationEntity to WidgetConfiguration
            try self.migrateWidgetConfigurations(in: context)
            
            // 6. Migrate QueryEntity to Query
            try self.migrateQueries(in: context)
            
            // 7. Migrate SearchFilterEntity to SearchFilter
            try self.migrateSearchFilters(in: context)
            
            try context.save()
        }
    }
    
    /// Migrates legacy TokenEntity objects to Token
    private func migrateTokens(in context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "TokenEntity")
        let legacyTokens = try context.fetch(request) as! [NSManagedObject]
        
        print("Migrating \(legacyTokens.count) tokens...")
        
        for legacyToken in legacyTokens {
            // Create new Token entity
            guard let newToken = NSEntityDescription.insertNewObject(forEntityName: "Token", into: context) as? NSManagedObject else {
                throw NSError(domain: "CoreDataMigration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create Token entity"])
            }
            
            // Transfer properties
            if let id = legacyToken.value(forKey: "id") as? UUID {
                newToken.setValue(id, forKey: "id")
            } else {
                newToken.setValue(UUID(), forKey: "id")
            }
            
            newToken.setValue(legacyToken.value(forKey: "apiToken"), forKey: "apiToken")
            newToken.setValue(legacyToken.value(forKey: "name"), forKey: "name")
            newToken.setValue(legacyToken.value(forKey: "connectionStatus"), forKey: "connectionStatus")
            newToken.setValue(legacyToken.value(forKey: "isActivated"), forKey: "isActivated")
            newToken.setValue(legacyToken.value(forKey: "lastValidated"), forKey: "lastValidated")
            newToken.setValue(legacyToken.value(forKey: "workspaceID"), forKey: "workspaceID")
            newToken.setValue(legacyToken.value(forKey: "workspaceName"), forKey: "workspaceName")
            
            // Map relationships later after all entities are created
        }
    }
    
    /// Migrates legacy DatabaseEntity objects to Database
    private func migrateDatabases(in context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "DatabaseEntity")
        let legacyDatabases = try context.fetch(request) as! [NSManagedObject]
        
        print("Migrating \(legacyDatabases.count) databases...")
        
        for legacyDB in legacyDatabases {
            // Create new Database entity
            guard let newDB = NSEntityDescription.insertNewObject(forEntityName: "Database", into: context) as? NSManagedObject else {
                throw NSError(domain: "CoreDataMigration", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create Database entity"])
            }
            
            // Transfer properties
            if let id = legacyDB.value(forKey: "id") as? String {
                newDB.setValue(id, forKey: "id")
            }
            
            // Map string title to transformable title array for compatibility
            if let titleString = legacyDB.value(forKey: "title") as? String {
                newDB.setValue(titleString, forKey: "titleString") // Store as plain string too
                
                // Create an array representation for compatibility with Notion model
                let titleArray: [[String: Any]] = [
                    ["type": "text", "text": ["content": titleString]]
                ]
                newDB.setValue(titleArray, forKey: "title")
            }
            
            // Map string description to transformable description array for compatibility
            if let descString = legacyDB.value(forKey: "databaseDescription") as? String {
                let descArray: [[String: Any]] = [
                    ["type": "text", "text": ["content": descString]]
                ]
                newDB.setValue(descArray, forKey: "databaseDescription")
            }
            
            newDB.setValue(legacyDB.value(forKey: "createdTime"), forKey: "createdTime")
            newDB.setValue(legacyDB.value(forKey: "lastEditedTime"), forKey: "lastEditedTime")
            
            // Fix typo in lastSyncTime field
            if let lastSyncTime = legacyDB.value(forKey: "lastSyncTiime") as? Date {
                newDB.setValue(lastSyncTime, forKey: "lastSyncTime")
            }
            
            newDB.setValue(legacyDB.value(forKey: "url"), forKey: "url")
            newDB.setValue(legacyDB.value(forKey: "widgetEnabled"), forKey: "widgetEnabled")
            newDB.setValue(legacyDB.value(forKey: "widgetType"), forKey: "widgetType")
            
            // Map relationships later after all entities are created
            
            // Store mapping for relationship setup
            let mapping = ["oldID": legacyDB.objectID, "newID": newDB.objectID]
            UserDefaults.standard.set(mapping, forKey: "DB_Migration_\(legacyDB.value(forKey: "id") ?? "unknown")")
        }
    }
    
    /// Migrates legacy PageEntity objects to Page
    private func migratePages(in context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "PageEntity")
        let legacyPages = try context.fetch(request) as! [NSManagedObject]
        
        print("Migrating \(legacyPages.count) pages...")
        
        for legacyPage in legacyPages {
            // Create new Page entity
            guard let newPage = NSEntityDescription.insertNewObject(forEntityName: "Page", into: context) as? NSManagedObject else {
                throw NSError(domain: "CoreDataMigration", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create Page entity"])
            }
            
            // Transfer properties
            if let id = legacyPage.value(forKey: "id") as? String {
                newPage.setValue(id, forKey: "id")
            }
            
            newPage.setValue(legacyPage.value(forKey: "title"), forKey: "title")
            newPage.setValue(legacyPage.value(forKey: "archived"), forKey: "archived")
            newPage.setValue(legacyPage.value(forKey: "createdTime"), forKey: "createdTime")
            newPage.setValue(legacyPage.value(forKey: "lastEditedTime"), forKey: "lastEditedTime")
            newPage.setValue(legacyPage.value(forKey: "lastSyncTime"), forKey: "lastSyncTime")
            newPage.setValue(legacyPage.value(forKey: "url"), forKey: "url")
            
            // Convert binary properties to transformable dictionary
            if let binaryData = legacyPage.value(forKey: "properties") as? Data {
                do {
                    let propertyDict = try PropertyListSerialization.propertyList(
                        from: binaryData,
                        options: [],
                        format: nil
                    ) as? [String: Any]
                    
                    newPage.setValue(propertyDict, forKey: "properties")
                } catch {
                    print("Warning: Could not convert page properties: \(error)")
                }
            }
            
            // Map relationships later
            
            // Store mapping for relationship setup
            let mapping = ["oldID": legacyPage.objectID, "newID": newPage.objectID]
            UserDefaults.standard.set(mapping, forKey: "Page_Migration_\(legacyPage.value(forKey: "id") ?? "unknown")")
        }
    }
    
    /// Migrates legacy TaskEntity objects to Task
    private func migrateTasks(in context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "TaskEntity")
        let legacyTasks = try context.fetch(request) as! [NSManagedObject]
        
        print("Migrating \(legacyTasks.count) tasks...")
        
        for legacyTask in legacyTasks {
            // Create new Task entity
            guard let newTask = NSEntityDescription.insertNewObject(forEntityName: "Task", into: context) as? NSManagedObject else {
                throw NSError(domain: "CoreDataMigration", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create Task entity"])
            }
            
            // Transfer properties
            if let id = legacyTask.value(forKey: "id") as? String {
                newTask.setValue(id, forKey: "id")
            }
            
            newTask.setValue(legacyTask.value(forKey: "title"), forKey: "title")
            newTask.setValue(legacyTask.value(forKey: "isCompleted"), forKey: "isCompleted")
            newTask.setValue(legacyTask.value(forKey: "dueDate"), forKey: "dueDate")
            newTask.setValue(legacyTask.value(forKey: "lastSyncTime"), forKey: "lastSyncTime")
            
            // Map relationships based on IDs
            if let pageID = legacyTask.value(forKey: "pageID") as? String {
                // Find the corresponding Page entity
                let pageRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Page")
                pageRequest.predicate = NSPredicate(format: "id == %@", pageID)
                
                if let pages = try? context.fetch(pageRequest) as? [NSManagedObject], let page = pages.first {
                    newTask.setValue(page, forKey: "page")
                }
            }
            
            if let databaseID = legacyTask.value(forKey: "databaseID") as? String {
                // Find the corresponding Database entity
                let dbRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Database")
                dbRequest.predicate = NSPredicate(format: "id == %@", databaseID)
                
                if let databases = try? context.fetch(dbRequest) as? [NSManagedObject], let database = databases.first {
                    newTask.setValue(database, forKey: "database")
                }
            }
            
            if let tokenID = legacyTask.value(forKey: "tokenID") as? UUID {
                // Find the corresponding Token entity
                let tokenRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Token")
                tokenRequest.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
                
                if let tokens = try? context.fetch(tokenRequest) as? [NSManagedObject], let token = tokens.first {
                    newTask.setValue(token, forKey: "token")
                }
            }
        }
    }
    
    /// Migrates legacy WidgetConfigurationEntity objects to WidgetConfiguration
    private func migrateWidgetConfigurations(in context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "WidgetConfigurationEntity")
        let legacyWidgets = try context.fetch(request) as! [NSManagedObject]
        
        print("Migrating \(legacyWidgets.count) widget configurations...")
        
        for legacyWidget in legacyWidgets {
            // Create new WidgetConfiguration entity
            guard let newWidget = NSEntityDescription.insertNewObject(forEntityName: "WidgetConfiguration", into: context) as? NSManagedObject else {
                throw NSError(domain: "CoreDataMigration", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to create WidgetConfiguration entity"])
            }
            
            // Transfer properties
            if let id = legacyWidget.value(forKey: "id") as? UUID {
                newWidget.setValue(id, forKey: "id")
            } else {
                newWidget.setValue(UUID(), forKey: "id")
            }
            
            newWidget.setValue(legacyWidget.value(forKey: "name"), forKey: "name")
            newWidget.setValue(legacyWidget.value(forKey: "widgetFamily"), forKey: "widgetFamily")
            newWidget.setValue(legacyWidget.value(forKey: "widgetKind"), forKey: "widgetKind")
            newWidget.setValue(legacyWidget.value(forKey: "lastUpdated"), forKey: "lastUpdated")
            
            // Convert binary config data to transformable dictionary
            if let binaryData = legacyWidget.value(forKey: "configData") as? Data {
                do {
                    let configDict = try PropertyListSerialization.propertyList(
                        from: binaryData,
                        options: [],
                        format: nil
                    ) as? [String: Any]
                    
                    newWidget.setValue(configDict, forKey: "configData")
                } catch {
                    print("Warning: Could not convert widget config data: \(error)")
                }
            }
            
            // Map relationships
            if let databaseID = legacyWidget.value(forKey: "databaseID") as? String {
                // Find the corresponding Database entity
                let dbRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Database")
                dbRequest.predicate = NSPredicate(format: "id == %@", databaseID)
                
                if let databases = try? context.fetch(dbRequest) as? [NSManagedObject], let database = databases.first {
                    newWidget.setValue(database, forKey: "database")
                }
            }
            
            if let tokenID = legacyWidget.value(forKey: "tokenID") as? UUID {
                // Find the corresponding Token entity
                let tokenRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Token")
                tokenRequest.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
                
                if let tokens = try? context.fetch(tokenRequest) as? [NSManagedObject], let token = tokens.first {
                    newWidget.setValue(token, forKey: "token")
                }
            }
        }
    }
    
    /// Migrates legacy QueryEntity objects to Query
    private func migrateQueries(in context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "QueryEntity")
        let legacyQueries = try context.fetch(request) as! [NSManagedObject]
        
        print("Migrating \(legacyQueries.count) queries...")
        
        for legacyQuery in legacyQueries {
            // Create new Query entity
            guard let newQuery = NSEntityDescription.insertNewObject(forEntityName: "Query", into: context) as? NSManagedObject else {
                throw NSError(domain: "CoreDataMigration", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to create Query entity"])
            }
            
            // Transfer properties
            if let id = legacyQuery.value(forKey: "id") as? UUID {
                newQuery.setValue(id, forKey: "id")
            } else {
                newQuery.setValue(UUID(), forKey: "id")
            }
            
            newQuery.setValue(legacyQuery.value(forKey: "createdAt"), forKey: "createdAt")
            newQuery.setValue(legacyQuery.value(forKey: "databaseID"), forKey: "databaseID")
            
            // Convert binary query data to transformable dictionary
            if let binaryData = legacyQuery.value(forKey: "queryData") as? Data {
                do {
                    let queryDict = try PropertyListSerialization.propertyList(
                        from: binaryData,
                        options: [],
                        format: nil
                    ) as? [String: Any]
                    
                    newQuery.setValue(queryDict, forKey: "queryData")
                } catch {
                    print("Warning: Could not convert query data: \(error)")
                }
            }
            
            // Map relationships
            if let databaseID = legacyQuery.value(forKey: "databaseID") as? String {
                // Find the corresponding Database entity
                let dbRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Database")
                dbRequest.predicate = NSPredicate(format: "id == %@", databaseID)
                
                if let databases = try? context.fetch(dbRequest) as? [NSManagedObject], let database = databases.first {
                    newQuery.setValue(database, forKey: "database")
                }
            }
        }
    }
    
    /// Migrates legacy SearchFilterEntity objects to SearchFilter
    private func migrateSearchFilters(in context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "SearchFilterEntity")
        let legacyFilters = try context.fetch(request) as! [NSManagedObject]
        
        print("Migrating \(legacyFilters.count) search filters...")
        
        for legacyFilter in legacyFilters {
            // Create new SearchFilter entity
            guard let newFilter = NSEntityDescription.insertNewObject(forEntityName: "SearchFilter", into: context) as? NSManagedObject else {
                throw NSError(domain: "CoreDataMigration", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to create SearchFilter entity"])
            }
            
            // Transfer properties
            if let id = legacyFilter.value(forKey: "id") as? UUID {
                newFilter.setValue(id, forKey: "id")
            } else {
                newFilter.setValue(UUID(), forKey: "id")
            }
            
            newFilter.setValue(legacyFilter.value(forKey: "createdAt"), forKey: "createdAt")
            newFilter.setValue(legacyFilter.value(forKey: "property"), forKey: "property")
            newFilter.setValue(legacyFilter.value(forKey: "type"), forKey: "type")
            newFilter.setValue(legacyFilter.value(forKey: "value"), forKey: "value")
        }
    }
    
    /// Establishes relationships between migrated entities
    private func setupRelationships(in context: NSManagedObjectContext) throws {
        // Skip for now - relationships are set up during individual migrations
    }
}