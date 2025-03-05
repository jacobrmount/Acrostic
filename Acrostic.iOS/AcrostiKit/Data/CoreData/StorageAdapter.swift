// AcrostiKit/Data/CoreData/StorageAdapter.swift
import Foundation
import CoreData

class iCloudStorageAdapter: StorageAdapter {  // Renamed from iCloudAdapter to match usage
    private let containerIdentifier = "iCloud.com.acrostic"
    private var persistentContainer: NSPersistentContainer
    
    init() throws {
        // Set up CloudKit container
        guard let containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: containerIdentifier
        )?.appendingPathComponent("CoreData") else {
            throw NSError(domain: "iCloudStorageAdapter", code: 1001,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to get iCloud container URL"])
        }
        
        let storeURL = containerURL.appendingPathComponent("Acrostic.sqlite")
        
        // Create directory if needed
        do {
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        } catch {
            throw NSError(domain: "iCloudStorageAdapter", code: 1002,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create iCloud directory: \(error.localizedDescription)"])
        }
        
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
        
        persistentContainer = NSPersistentContainer(name: "Acrostic")
        persistentContainer.persistentStoreDescriptions = [storeDescription]
        
        // Use a semaphore to make initialization synchronous
        let semaphore = DispatchSemaphore(value: 0)
        var loadError: Error?
        
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                print("Error loading iCloud persistent stores: \(error)")
                loadError = error
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 5) // 5 second timeout
        
        if let loadError = loadError {
            throw loadError
        }
    }
    
    func saveToken(_ token: TokenEntity) throws {
        let context = persistentContainer.viewContext
        let newToken = NSEntityDescription.insertNewObject(forEntityName: "Token", into: context) as! TokenEntity
        
        // Copy properties from the provided token
        newToken.id = token.id
        newToken.apiToken = token.apiToken
        newToken.workspaceName = token.workspaceName
        newToken.connectionStatus = token.connectionStatus
        newToken.isActivated = token.isActivated
        
        try context.save()
    }
    
    func updateToken(_ token: TokenEntity) throws {
        let context = persistentContainer.viewContext
        
        guard let tokenID = token.id else {
            throw NSError(domain: "LocalStorageAdapter", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Token ID is nil"])
        }
        
        let request = NSFetchRequest<TokenEntity>(entityName: "Token")
        request.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
        
        let results = try context.fetch(request)
        if let existingToken = results.first {
            // Update properties of the fetched TokenEntity
            existingToken.apiToken = token.apiToken
            existingToken.workspaceName = token.workspaceName
            existingToken.connectionStatus = token.connectionStatus
            existingToken.isActivated = token.isActivated
            
            try context.save()
        } else {
            try saveToken(token)
        }
    }
    
    func loadTokens() -> [TokenEntity] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<TokenEntity>(entityName: "Token")
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching tokens from iCloud: \(error)")
            return []
        }
    }
    
    func saveDatabase(_ database: DatabaseEntity, forToken tokenID: UUID) throws {
        let context = persistentContainer.viewContext
        
        // First ensure we have the token
        let tokenRequest = NSFetchRequest<TokenEntity>(entityName: "Token")
        tokenRequest.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
        
        let tokens = try context.fetch(tokenRequest)
        guard let token = tokens.first else {
            throw NSError(domain: "iCloudStorageAdapter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Token not found"])
        }
        
        // Now save the database
        let dbRequest = NSFetchRequest<DatabaseEntity>(entityName: "Database")
        dbRequest.predicate = NSPredicate(format: "id == %@", database.id ?? "")
        
        let results = try context.fetch(dbRequest)
        if let existingDB = results.first {
            // Update existing database
            existingDB.title = database.title
            existingDB.url = database.url
            existingDB.widgetEnabled = database.widgetEnabled
            
            // Set token relationship
            existingDB.addToToken(token)
        } else {
            // Create new database
            let newDB = NSEntityDescription.insertNewObject(forEntityName: "Database", into: context) as! DatabaseEntity
            newDB.id = database.id
            newDB.title = database.title
            newDB.url = database.url
            newDB.widgetEnabled = database.widgetEnabled
            
            // Set token relationship
            newDB.addToToken(token)
        }
        
        try context.save()
    }
    
    func loadDatabases(forToken tokenID: UUID) -> [DatabaseEntity] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<DatabaseEntity>(entityName: "Database")
        request.predicate = NSPredicate(format: "ANY token.id == %@", tokenID as CVarArg)
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching databases from iCloud: \(error)")
            return []
        }
    }
    
    func deleteToken(_ tokenID: UUID) throws {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<TokenEntity>(entityName: "Token")
        request.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
        
        let results = try context.fetch(request)
        if let token = results.first {
            context.delete(token)
            try context.save()
        }
    }
    
    func deleteDatabase(_ databaseID: String) throws {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<DatabaseEntity>(entityName: "Database")
        request.predicate = NSPredicate(format: "id == %@", databaseID)
        
        let results = try context.fetch(request)
        if let database = results.first {
            context.delete(database)
            try context.save()
        }
    }
    
    func migrateFrom(adapter: StorageAdapter) throws {
        // Migrate tokens
        let tokens = adapter.loadTokens()
        for token in tokens {
            try saveToken(token)
            
            // Migrate databases for this token
            if let tokenID = token.id {
                let databases = adapter.loadDatabases(forToken: tokenID)
                for database in databases {
                    try saveDatabase(database, forToken: tokenID)
                }
            }
        }
    }
}

class LocalStorageAdapter: StorageAdapter {
    private var persistentContainer: NSPersistentContainer
    
    init() {
        persistentContainer = NSPersistentContainer(name: "Acrostic")
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                print("Error loading local persistent stores: \(error)")
            }
        }
    }
    
    func saveToken(_ token: TokenEntity) throws {
        let context = persistentContainer.viewContext
        let newToken = NSEntityDescription.insertNewObject(forEntityName: "Token", into: context) as! TokenEntity
        
        // Copy properties from the provided token
        newToken.id = token.id
        newToken.apiToken = token.apiToken
        newToken.workspaceName = token.workspaceName
        newToken.connectionStatus = token.connectionStatus
        newToken.isActivated = token.isActivated
        
        try context.save()
    }
    
    func updateToken(_ token: TokenEntity) throws {
        let context = persistentContainer.viewContext
        
        guard let tokenID = token.id else {
            throw NSError(domain: "LocalStorageAdapter", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Token ID is nil"])
        }
        
        let request = NSFetchRequest<TokenEntity>(entityName: "Token")
        request.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
        
        let results = try context.fetch(request)
        if let existingToken = results.first {
            // Update properties of the fetched TokenEntity
            existingToken.apiToken = token.apiToken
            existingToken.workspaceName = token.workspaceName
            existingToken.connectionStatus = token.connectionStatus
            existingToken.isActivated = token.isActivated
            
            try context.save()
        } else {
            try saveToken(token)
        }
    }
    
    func loadTokens() -> [TokenEntity] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<TokenEntity>(entityName: "Token")
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching tokens from local storage: \(error)")
            return []
        }
    }
    
    func saveDatabase(_ database: DatabaseEntity, forToken tokenID: UUID) throws {
        let context = persistentContainer.viewContext
        
        // First ensure we have the token
        let tokenRequest = NSFetchRequest<TokenEntity>(entityName: "Token")
        tokenRequest.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
        
        let tokens = try context.fetch(tokenRequest)
        guard let token = tokens.first else {
            throw NSError(domain: "LocalStorageAdapter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Token not found"])
        }
        
        // Now save the database
        let dbRequest = NSFetchRequest<DatabaseEntity>(entityName: "Database")
        dbRequest.predicate = NSPredicate(format: "id == %@", database.id ?? "")
        
        let results = try context.fetch(dbRequest)
        if let existingDB = results.first {
            // Update existing database
            existingDB.title = database.title
            existingDB.url = database.url
            existingDB.widgetEnabled = database.widgetEnabled
            
            // Set token relationship
            existingDB.addToToken(token)
        } else {
            // Create new database
            let newDB = NSEntityDescription.insertNewObject(forEntityName: "Database", into: context) as! DatabaseEntity
            newDB.id = database.id
            newDB.title = database.title
            newDB.url = database.url
            newDB.widgetEnabled = database.widgetEnabled
            
            // Set token relationship
            newDB.addToToken(token)
        }
        
        try context.save()
    }
    
    func loadDatabases(forToken tokenID: UUID) -> [DatabaseEntity] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<DatabaseEntity>(entityName: "Database")
        request.predicate = NSPredicate(format: "ANY token.id == %@", tokenID as CVarArg)
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching databases from local storage: \(error)")
            return []
        }
    }
    
    func deleteToken(_ tokenID: UUID) throws {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<TokenEntity>(entityName: "Token")
        request.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
        
        let results = try context.fetch(request)
        if let token = results.first {
            context.delete(token)
            try context.save()
        }
    }
    
    func deleteDatabase(_ databaseID: String) throws {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<DatabaseEntity>(entityName: "Database")
        request.predicate = NSPredicate(format: "id == %@", databaseID)
        
        let results = try context.fetch(request)
        if let database = results.first {
            context.delete(database)
            try context.save()
        }
    }
    
    func migrateFrom(adapter: StorageAdapter) throws {
        // Migrate tokens
        let tokens = adapter.loadTokens()
        for token in tokens {
            try saveToken(token)
            
            // Migrate databases for this token
            if let tokenID = token.id {
                let databases = adapter.loadDatabases(forToken: tokenID)
                for database in databases {
                    try saveDatabase(database, forToken: tokenID)
                }
            }
        }
    }
}
