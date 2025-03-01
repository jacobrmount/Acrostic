// NactionsKit/DataManagement/CoreDataStack.swift
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
        
        // Check if TokenEntity exists
        if entityNames.contains("TokenEntity") {
            print("✅ TokenEntity found in model")
        } else {
            print("❌ TokenEntity NOT found in model")
        }
    }
    
    private init() {
        // Add debugging info to identify the model URLs
        let modelURL = Bundle.main.url(forResource: "NactionsDataModel", withExtension: "momd")
        print("Looking for data model at: \(String(describing: modelURL))")
        
        // Initialize the persistent container with our data model
        persistentContainer = NSPersistentContainer(name: "NactionsDataModel")
        
        // Set the store URL to the shared app group container for widget access
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.nactions") {
            let storeURL = appGroupURL.appendingPathComponent("NactionsDataModel.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
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
                
                // Log all error userInfo keys to help diagnose
                for (key, value) in error.userInfo {
                    print("Error info - \(key): \(value)")
                }
                
                // Don't crash in production
                #if DEBUG
                fatalError("Failed to load persistent stores: \(error)")
                #endif
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
