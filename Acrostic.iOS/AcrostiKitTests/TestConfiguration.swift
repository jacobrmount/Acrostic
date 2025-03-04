// AcrostiKitTests/TestConfiguration.swift
import Foundation
import CoreData

enum TestEnvironment {
    case local
    case staging
}

class TestConfiguration {
    static let shared = TestConfiguration()
    
    var currentEnvironment: TestEnvironment = .local
    
    // Core Data container for testing
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AcrosticDataModel")
        
        switch currentEnvironment {
        case .local:
            // Use in-memory store for local testing
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        case .staging:
            // Use actual file for staging, but in a test directory
            let storeURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("AcrosticTestStore.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [description]
        }
        
        container.loadPersistentStores { (description, error) in
            if let error = error as NSError? {
                fatalError("Failed to load test persistent stores: \(error)")
            }
        }
        
        return container
    }()
    
    func resetStore() {
        if currentEnvironment == .local {
            // For in-memory store, we need to recreate it
            let coordinator = persistentContainer.persistentStoreCoordinator
            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }
            
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            persistentContainer.persistentStoreDescriptions = [description]
            persistentContainer.loadPersistentStores { _, error in
                if let error = error {
                    print("Error reloading store: \(error)")
                }
            }
        } else {
            // For staging, delete all entities
            let entities = persistentContainer.managedObjectModel.entities
            
            for entity in entities {
                if let entityName = entity.name {
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    
                    do {
                        try persistentContainer.persistentStoreCoordinator.execute(deleteRequest, with: persistentContainer.viewContext)
                    } catch {
                        print("Error clearing entity \(entityName): \(error)")
                    }
                }
            }
        }
    }
}
