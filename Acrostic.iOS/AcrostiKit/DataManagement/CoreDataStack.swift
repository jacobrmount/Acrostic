// AcrostiKit/DataManagement/CoreDataStack.swift
import Foundation
import CoreData

/// Manages Core Data operations and shared context
public final class CoreDataStack {
    public static let shared = CoreDataStack()
    
    // Core Data stack for the main application
    public let persistentContainer: NSPersistentContainer
    
    // The main context for UI operations
    public var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // Check if the context has access to the model
    public func verifyModelAccess() {
        let entityNames = persistentContainer.managedObjectModel.entities.map { $0.name ?? "unnamed" }
        print("Available entities in model: \(entityNames)")
        
        // Check if Token exists
        if entityNames.contains("Token") {
            print("✅ Token entity found in model")
        } else {
            print("❌ Token entity NOT found in model")
        }
    }
    
    private init() {
        if let modelURL = Bundle(for: CoreDataStack.self).url(forResource: "CoreData", withExtension: "momd") {
            // Log model URL for debugging
            print("Looking for data model at: \(modelURL)")
            
            // Create a managed object model from URL
            let model = NSManagedObjectModel(contentsOf: modelURL)
            if model == nil {
                fatalError("Unable to load model at \(modelURL)")
            }
            
            // Create persistent container with the loaded model
            persistentContainer = NSPersistentContainer(name: "CoreData", managedObjectModel: model!)
        } else {
            // Log model not found
            print("❌ CoreData model not found in bundle paths")
            
            // Print all resource paths for debugging
            let bundles = [Bundle.main, Bundle(for: CoreDataStack.self)]
            for (index, bundle) in bundles.enumerated() {
                print("Bundle \(index): \(bundle)")
                if let resourcePath = bundle.resourcePath {
                    print("Resource path: \(resourcePath)")
                    // List all files in the resource path
                    do {
                        let fileManager = FileManager.default
                        let fileURLs = try fileManager.contentsOfDirectory(atPath: resourcePath)
                        print("Files in resource path: \(fileURLs)")
                    } catch {
                        print("Error listing files: \(error)")
                    }
                }
            }
            
            // Create a temporary empty model as a fallback
            print("⚠️ Using fallback empty model - functionality will be limited")
            let managedObjectModel = NSManagedObjectModel()
            
            // Create persistent container with the fallback model
            persistentContainer = NSPersistentContainer(name: "CoreData", managedObjectModel: managedObjectModel)
        }
        
        // Set the store URL to the shared app group container for widget access
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.acrostic") {
            let storeURL = appGroupURL.appendingPathComponent("CoreData.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
            
            // Enable automatic migration
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            
            persistentContainer.persistentStoreDescriptions = [description]
            
            // Print for debugging
            print("Using Core Data store at: \(storeURL.path)")
        } else {
            print("⚠️ Failed to get app group container URL")
        }
        
        // Load the persistent stores
        persistentContainer.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // Detailed error logging
                print("Failed to load persistent stores: \(error), \(error.userInfo)")
                print("Model URL: \(String(describing: storeDescription.url))")
                print("Model configuration: \(String(describing: storeDescription.configuration))")
                
                // Check if this is a migration error
                if error.domain == NSCocoaErrorDomain && 
                   (error.code == NSPersistentStoreIncompatibleVersionHashError ||
                    error.code == NSMigrationError ||
                    error.code == NSMigrationMissingSourceModelError) {
                    
                    print("⚠️ Migration error detected - will attempt recovery")
                    
                    // Try to recover by removing the old store and creating a new one
                    if let storeURL = storeDescription.url {
                        do {
                            try persistentContainer.persistentStoreCoordinator.destroyPersistentStore(
                                at: storeURL,
                                ofType: NSSQLiteStoreType,
                                options: nil
                            )
                            
                            // Delete any additional files associated with the store
                            let fileManager = FileManager.default
                            let storePath = storeURL.path
                            
                            for suffix in ["-wal", "-shm"] {
                                let extraFilePath = storePath + suffix
                                if fileManager.fileExists(atPath: extraFilePath) {
                                    try fileManager.removeItem(atPath: extraFilePath)
                                }
                            }
                            
                            print("✅ Successfully removed old store files")
                            
                            // Now try to create a new store
                            try persistentContainer.persistentStoreCoordinator.addPersistentStore(
                                ofType: NSSQLiteStoreType,
                                configurationName: nil,
                                at: storeURL,
                                options: [
                                    NSMigratePersistentStoresAutomaticallyOption: true,
                                    NSInferMappingModelAutomaticallyOption: true
                                ]
                            )
                            
                            print("✅ Successfully created new persistent store")
                        } catch {
                            print("❌ Recovery failed: \(error)")
                        }
                    }
                } else {
                    // Log all error userInfo keys to help diagnose
                    for (key, value) in error.userInfo {
                        print("Error info - \(key): \(value)")
                    }
                    
                    // Don't crash in production
                    #if DEBUG
                    print("⚠️ CoreData error encountered, continuing with limited functionality")
                    #endif
                }
            } else {
                print("✅ Successfully loaded persistent store: \(storeDescription.url?.path ?? "unknown")")
            }
        }
        
        // Configure the view context for automatic merging of changes
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    /// Saves changes in the view context if there are any
    public func saveViewContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Error saving view context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    /// Performs a task on a background context and saves when complete
    public func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask { context in
            block(context)
            
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    let nsError = error as NSError
                    print("Error saving background context: \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }
    
    /// Performs a task on a background context and returns a result
    public func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    
                    if context.hasChanges {
                        do {
                            try context.save()
                        } catch {
                            continuation.resume(throwing: error)
                            return
                        }
                    }
                    
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
