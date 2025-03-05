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
}
