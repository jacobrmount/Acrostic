// AcrostiKit/Data/Controllers/DatabaseController.swift
import Foundation
import CoreData
import Combine

/// Unified controller for all database-related operations
public final class DatabaseController {
    /// The shared singleton instance
    public static let shared = DatabaseController()
    
    // MARK: - Published Properties
    
    @Published public var databaseGroups: [DatabaseGroup] = []
    @Published public var errorMessage: String? = nil
    @Published public var isLoading: Bool = false
    @Published private(set) var isMetadataLoaded = false
    @Published private(set) var databaseMetadata: [DatabaseViewModelInternal] = []
    
    // MARK: - Constants
    
    private let cacheKey = "acrostic_database_metadata_cache"
    private let cacheValidityDuration: TimeInterval = 24 * 60 * 60 // 24 hours
    
    private init() {}
    
    // MARK: - Core Data Fetch Operations
    
    /// Fetches all databases
    public func fetchDatabases() -> [NSManagedObject] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Database")
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching databases: \(error)")
            return []
        }
    }
    
    /// Fetches databases for a specific token
    public func fetchDatabases(for tokenID: UUID) -> [NSManagedObject] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Database")
        request.predicate = NSPredicate(format: "ANY token.id == %@", tokenID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching databases for token \(tokenID): \(error)")
            return []
        }
    }
    
    /// Fetches databases that are enabled for widgets
    public func fetchWidgetEnabledDatabases() -> [NSManagedObject] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Database")
        request.predicate = NSPredicate(format: "widgetEnabled == true")
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching widget-enabled databases: \(error)")
            return []
        }
    }
    
    /// Fetches databases as DatabaseViewModel structs for a specific token
    public func fetchDatabaseViewModels(for tokenID: UUID) -> [DatabaseViewModelInternal] {
        return fetchDatabases(for: tokenID).compactMap { $0.toDatabaseViewModel() }
    }
    
    /// Fetches a specific database by ID
    public func fetchDatabase(id: String) -> NSManagedObject? {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Database")
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching database with ID \(id): \(error)")
            return nil
        }
    }
    
    /// Fetches only essential metadata for databases across multiple tokens
    public func fetchDatabaseMetadata(for tokenIDs: [UUID]) -> [DatabaseViewModelInternal] {
        let context = CoreDataStack.shared.viewContext
        
        // Create a compound predicate for all token IDs
        let predicates = tokenIDs.map { tokenID in
            NSPredicate(format: "ANY token.id == %@", tokenID as CVarArg)
        }
        
        // If no tokens, return empty array
        if predicates.isEmpty {
            return []
        }
        
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        
        // Only fetch the fields we need for metadata
        let request = NSFetchRequest<NSManagedObject>(entityName: "Database")
        request.predicate = compoundPredicate
        request.propertiesToFetch = ["id", "title", "titleString", "widgetEnabled", "lastEditedTime"]
        request.relationshipKeyPathsForPrefetching = ["token"]
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        do {
            let results = try context.fetch(request)
            return results.compactMap { database -> DatabaseViewModelInternal? in
                guard let id = database.value(forKey: "id") as? String,
                      let tokenRelationships = database.value(forKey: "token") as? Set<NSManagedObject>,
                      let tokenObject = tokenRelationships.first,
                      let tokenID = tokenObject.value(forKey: "id") as? UUID else {
                    return nil
                }
                
                // Retrieve title, using titleString as the primary source
                let title: String
                if let titleString = database.value(forKey: "titleString") as? String, !titleString.isEmpty {
                    title = titleString
                } else if let titleArray = database.value(forKey: "title") as? NSArray,
                          let firstItem = titleArray.firstObject as? [String: Any],
                          let textContent = firstItem["text"] as? [String: Any],
                          let content = textContent["content"] as? String {
                    title = content
                } else {
                    title = "Untitled"
                }
                
                let isSelected = database.value(forKey: "widgetEnabled") as? Bool ?? false
                let lastUpdated = database.value(forKey: "lastEditedTime") as? Date ?? Date()
                let tokenName = tokenObject.value(forKey: "workspaceName") as? String ?? "Unknown"
                
                return DatabaseViewModelInternal(
                    id: id,
                    title: title,
                    tokenID: tokenID,
                    tokenName: tokenName,
                    isSelected: isSelected,
                    lastUpdated: lastUpdated
                )
            }
        } catch {
            print("Error fetching database metadata: \(error)")
            return []
        }
    }
    
    // MARK: - Metadata Loading
    
    /// Loads database metadata efficiently
    public func loadDatabaseMetadata() async {
        guard !isMetadataLoaded else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        let activeTokenIDs = TokenService.shared.activatedTokens.compactMap { $0.id }
        
        // Early exit if no activated tokens
        if activeTokenIDs.isEmpty {
            await MainActor.run {
                databaseGroups = []
                isLoading = false
                isMetadataLoaded = true
            }
            return
        }
        
        // Try to load from cache first
        if let cachedMetadata = loadCachedDatabaseMetadata() {
            await applyDatabaseMetadata(cachedMetadata)
            
            // Background refresh if cache is older than 1 hour
            let cacheAge = Date().timeIntervalSince1970 - (cachedMetadata.first?.lastUpdated.timeIntervalSince1970 ?? 0)
            if cacheAge > 3600 {
                Task {
                    await refreshDatabaseMetadata(for: activeTokenIDs)
                }
            }
            return
        }
        
        // Load from data source
        await refreshDatabaseMetadata(for: activeTokenIDs)
    }
    
    // Helper method to refresh metadata
    private func refreshDatabaseMetadata(for tokenIDs: [UUID]) async {
        // Load only the metadata
        let metadata = fetchDatabaseMetadata(for: tokenIDs)
        await applyDatabaseMetadata(metadata)
        
        // Cache the metadata
        cacheDatabaseMetadata(metadata)
    }
    
    // Helper method to apply metadata to UI
    private func applyDatabaseMetadata(_ metadata: [DatabaseViewModelInternal]) async {
        // Group by token
        var groupedDatabases: [UUID: [DatabaseViewModelInternal]] = [:]
        for db in metadata {
            groupedDatabases[db.tokenID, default: []].append(db)
        }
        
        // Create groups
        let newGroups: [DatabaseGroup] = TokenService.shared.activatedTokens.compactMap { token in
            guard let tokenID = token.id,
                  let databases = groupedDatabases[tokenID],
                  !databases.isEmpty else {
                return nil
            }
            
            return DatabaseGroup(
                id: UUID(),
                tokenName: token.workspaceName ?? "Unknown",
                tokenID: tokenID,
                databases: databases
            )
        }
        
        // Using local constants instead of captured vars
        let finalGroups = newGroups
        let finalMetadata = metadata
        
        await MainActor.run {
            databaseGroups = finalGroups
            databaseMetadata = finalMetadata
            isLoading = false
            isMetadataLoaded = true
        }
    }
    
    // MARK: - Create/Update Operations
    
    /// Creates or updates a database from a NotionDatabase model
    public func saveDatabase(from notionDatabase: NotionDatabase, for tokenID: UUID) async -> NSManagedObject? {
        let context = CoreDataStack.shared.viewContext
        
        // Validate database ID
        guard !notionDatabase.id.isEmpty else {
            print("❌ Error: Notion database ID is empty")
            return nil
        }
        
        // Fetch token
        let tokenRequest = NSFetchRequest<NSManagedObject>(entityName: "Token")
        tokenRequest.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
        
        guard let tokenObject = try? context.fetch(tokenRequest).first else {
            print("❌ Token with ID \(tokenID) not found")
            return nil
        }
        
        // Try to find existing database
        let request = NSFetchRequest<NSManagedObject>(entityName: "Database")
        request.predicate = NSPredicate(format: "id == %@", notionDatabase.id)
        
        do {
            let existingDatabases = try context.fetch(request)
            
            if let existingDatabase = existingDatabases.first {
                // Update existing database
                updateExistingDatabase(existingDatabase, from: notionDatabase, with: tokenObject)
                try context.save()
                return existingDatabase
            } else {
                // Create new database
                let newDatabase = createNewDatabase(from: notionDatabase, with: tokenObject, in: context)
                try context.save()
                return newDatabase
            }
        } catch {
            print("❌ Database processing error: \(error)")
            context.rollback()
            return nil
        }
    }
    
    /// Updates multiple databases at once
    public func saveDatabases(from notionDatabases: [NotionDatabase], for tokenID: UUID) async -> [NSManagedObject] {
        let context = CoreDataStack.shared.viewContext
        
        // Find token
        let tokenRequest = NSFetchRequest<NSManagedObject>(entityName: "Token")
        tokenRequest.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
        
        guard let tokenObject = try? context.fetch(tokenRequest).first else {
            print("Token not found for ID: \(tokenID)")
            return []
        }
        
        // Process all databases
        var savedDatabases: [NSManagedObject] = []
        
        for database in notionDatabases {
            // Skip databases with empty IDs
            if database.id.isEmpty {
                continue
            }
            
            if let existingDB = try? fetchOrCreateDatabase(id: database.id, in: context) {
                updateExistingDatabase(existingDB, from: database, with: tokenObject)
                savedDatabases.append(existingDB)
            }
        }
        
        // Save context once
        if !savedDatabases.isEmpty {
            do {
                try context.save()
                return savedDatabases
            } catch {
                print("Error saving databases: \(error)")
                context.rollback()
                return []
            }
        }
        
        return []
    }
    
    // MARK: - Widget Configuration
    
    /// Toggles the widget enabled status for a database
    public func toggleWidgetEnabled(databaseID: String, enabled: Bool) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Database")
        request.predicate = NSPredicate(format: "id == %@", databaseID)
        
        do {
            if let database = try context.fetch(request).first {
                database.setValue(enabled, forKey: "widgetEnabled")
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
        let request = NSFetchRequest<NSManagedObject>(entityName: "Database")
        request.predicate = NSPredicate(format: "id == %@", databaseID)
        
        do {
            if let database = try context.fetch(request).first {
                database.setValue(type, forKey: "widgetType")
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
        let request = NSFetchRequest<NSManagedObject>(entityName: "Database")
        request.predicate = NSPredicate(format: "ANY token.id == %@", tokenID as CVarArg)
        
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
        let request = NSFetchRequest<NSManagedObject>(entityName: "Database")
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
    
    // MARK: - Caching Methods
    
    public func cacheDatabaseMetadata(_ metadata: [DatabaseViewModelInternal]) {
        guard let userDefaults = AppGroupConfig.sharedUserDefaults else { return }
        
        let cacheData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "metadata": metadata.map { db -> [String: Any] in
                return [
                    "id": db.id,
                    "title": db.title,
                    "tokenID": db.tokenID.uuidString,
                    "tokenName": db.tokenName,
                    "isSelected": db.isSelected,
                    "lastUpdatedTimestamp": db.lastUpdated.timeIntervalSince1970
                ]
            }
        ]
        
        userDefaults.set(cacheData, forKey: cacheKey)
        userDefaults.synchronize()
    }
    
    public func loadCachedDatabaseMetadata() -> [DatabaseViewModelInternal]? {
        guard let userDefaults = AppGroupConfig.sharedUserDefaults,
              let cacheData = userDefaults.dictionary(forKey: cacheKey),
              let timestamp = cacheData["timestamp"] as? TimeInterval,
              let metadataArray = cacheData["metadata"] as? [[String: Any]] else {
            return nil
        }
        
        // Check if cache is still valid
        let cacheAge = Date().timeIntervalSince1970 - timestamp
        if cacheAge > cacheValidityDuration {
            return nil
        }
        
        // Convert cached data to view models
        return metadataArray.compactMap { dict -> DatabaseViewModelInternal? in
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String,
                  let tokenIDString = dict["tokenID"] as? String,
                  let tokenID = UUID(uuidString: tokenIDString),
                  let tokenName = dict["tokenName"] as? String,
                  let isSelected = dict["isSelected"] as? Bool else {
                return nil
            }
            
            let lastUpdatedTimestamp = dict["lastUpdatedTimestamp"] as? TimeInterval ?? timestamp
            let lastUpdated = Date(timeIntervalSince1970: lastUpdatedTimestamp)
            
            return DatabaseViewModelInternal(
                id: id,
                title: title,
                tokenID: tokenID,
                tokenName: tokenName,
                isSelected: isSelected,
                lastUpdated: lastUpdated
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchOrCreateDatabase(id: String, in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Database")
        request.predicate = NSPredicate(format: "id == %@", id)
        
        let existingDatabases = try context.fetch(request)
        if let existingDatabase = existingDatabases.first {
            return existingDatabase
        } else {
            let newDatabase = NSEntityDescription.insertNewObject(forEntityName: "Database", into: context)
            newDatabase.setValue(id, forKey: "id")
            return newDatabase
        }
    }
    
    private func updateExistingDatabase(_ existingDatabase: NSManagedObject, from notionDatabase: NotionDatabase, with tokenObject: NSManagedObject) {
        // Update database properties
        existingDatabase.setValue(notionDatabase.createdTime, forKey: "createdTime")
        existingDatabase.setValue(notionDatabase.lastEditedTime, forKey: "lastEditedTime")
        existingDatabase.setValue(notionDatabase.url, forKey: "url")
        existingDatabase.setValue(notionDatabase.archived, forKey: "archived")
        
        // Set title string
        let titleText = notionDatabase.getTitleText()
        existingDatabase.setValue(titleText, forKey: "titleString")
        
        // Convert title to NSArray
        let titleArray: NSArray = [["text": ["content": titleText]]]
        existingDatabase.setValue(titleArray, forKey: "title")
        
        // Set token relationship
        let tokenSet = existingDatabase.mutableSetValue(forKey: "token")
        tokenSet.add(tokenObject)
        
        // Ensure ID is set
        if existingDatabase.value(forKey: "id") == nil {
            existingDatabase.setValue(notionDatabase.id, forKey: "id")
        }
    }
    
    private func createNewDatabase(from notionDatabase: NotionDatabase, with tokenObject: NSManagedObject, in context: NSManagedObjectContext) -> NSManagedObject {
        // Create new database entity
        let newDatabase = NSEntityDescription.insertNewObject(forEntityName: "Database", into: context)
        
        // Set ID and other properties
        newDatabase.setValue(notionDatabase.id, forKey: "id")
        
        // Set title
        let titleText = notionDatabase.getTitleText()
        newDatabase.setValue(titleText, forKey: "titleString")
        
        let titleArray: NSArray = [["text": ["content": titleText]]]
        newDatabase.setValue(titleArray, forKey: "title")
        
        // Set additional properties
        newDatabase.setValue(notionDatabase.createdTime, forKey: "createdTime")
        newDatabase.setValue(notionDatabase.lastEditedTime, forKey: "lastEditedTime")
        newDatabase.setValue(notionDatabase.archived, forKey: "archived")
        newDatabase.setValue(notionDatabase.url, forKey: "url")
        newDatabase.setValue(Date(), forKey: "lastSyncTime")
        newDatabase.setValue(false, forKey: "widgetEnabled")
        
        // Set token relationship
        let tokenSet = newDatabase.mutableSetValue(forKey: "token")
        tokenSet.add(tokenObject)
        
        return newDatabase
    }
}
