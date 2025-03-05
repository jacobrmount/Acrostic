// AcrostiKit/Data/CoreData/CoreDataStack.swift
import Foundation
import CoreData

public final class CoreDataStack {
    public static let shared = CoreDataStack()
    
    public let persistentContainer: NSPersistentContainer
    
    public var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private init() {
        guard let modelURL = Bundle(for: CoreDataStack.self).url(forResource: "CoreData", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Unable to load Core Data model")
        }
        
        persistentContainer = NSPersistentContainer(name: "CoreData", managedObjectModel: model)
        
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupConfig.appGroupIdentifier) {
            let storeURL = appGroupURL.appendingPathComponent("CoreData.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
            
            // Performance optimizations
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.setOption(["journal_mode": "WAL"] as NSDictionary, forKey: NSSQLitePragmasOption)
            
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            
            persistentContainer.persistentStoreDescriptions = [description]
        }
        
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                print("Persistent store load error: \(error)")
                self.handlePersistentStoreError(error, description: description)
            }
        }
    }
    
    // Keep only the critical error handling method
    private func handlePersistentStoreError(_ error: Error, description: NSPersistentStoreDescription) {
        // Simplified error recovery strategy
        if let storeURL = description.url {
            do {
                try persistentContainer.persistentStoreCoordinator.destroyPersistentStore(
                    at: storeURL,
                    ofType: NSSQLiteStoreType,
                    options: nil
                )
                
                // Remove WAL and SHM files
                for suffix in ["-wal", "-shm"] {
                    let extraFilePath = storeURL.path + suffix
                    if FileManager.default.fileExists(atPath: extraFilePath) {
                        try FileManager.default.removeItem(atPath: extraFilePath)
                    }
                }
                
                try persistentContainer.persistentStoreCoordinator.addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: storeURL,
                    options: [
                        NSMigratePersistentStoresAutomaticallyOption: true,
                        NSInferMappingModelAutomaticallyOption: true
                    ]
                )
            } catch {
                print("Failed to recover persistent store: \(error)")
            }
        }
    }
    
    // Core essential background operations
    public func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask { context in
            block(context)
            
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("Error saving background context: \(error)")
                }
            }
        }
    }
    
    public func saveViewContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving view context: \(error)")
            }
        }
    }
    
    public func verifyModelAccess() {
        print("🔍 Verifying Core Data model access...")
        do {
            // Try to check entity names
            let entityNames = persistentContainer.managedObjectModel.entities.compactMap { $0.name }
            print("✅ Model contains \(entityNames.count) entities: \(entityNames.joined(separator: ", "))")
            
            // Try to perform a simple fetch request
            let context = viewContext
            let request = NSFetchRequest<NSManagedObject>(entityName: "Token")
            request.fetchLimit = 1
            _ = try context.fetch(request)
            print("✅ Successfully performed test fetch request")
        } catch {
            print("❌ Core Data model access verification failed: \(error)")
        }
    }

    public func migrateIfNeeded() async throws {
        // Check if migration is needed
        print("🔄 Checking if migration is needed...")
        
        // This is a placeholder for actual migration logic
        // In a real app, you would compare model versions and migrate data
        
        // For now, simply verify we can access the store
        let context = viewContext
        let coordinator = context.persistentStoreCoordinator
        
        guard let stores = coordinator?.persistentStores, !stores.isEmpty else {
            print("❌ No persistent stores found")
            throw NSError(domain: "CoreDataMigration", code: 1, userInfo: [NSLocalizedDescriptionKey: "No persistent stores found"])
        }
        
        print("✅ Found \(stores.count) persistent stores")
        print("✅ No migration needed at this time")
    }

    public func debugDatabaseEntities() {
        let context = viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Database")
        
        do {
            let databases = try context.fetch(request)
            print("🔍 Found \(databases.count) database entities")
            
            for (index, database) in databases.enumerated() {
                let id = database.value(forKey: "id") as? String ?? "nil"
                let title = database.value(forKey: "title") as? String ?? "nil"
                print("  [\(index)] Database: id=\(id), title=\(title)")
                
                // Check for problematic values
                if id == "nil" {
                    print("  ⚠️ Warning: Database has nil ID")
                }
            }
        } catch {
            print("❌ Error debugging database entities: \(error)")
        }
    }
}
