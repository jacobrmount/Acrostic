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
        
        // Check if TokenEntity exists
        if entityNames.contains("TokenEntity") {
            print("✅ TokenEntity found in model")
        } else {
            print("❌ TokenEntity NOT found in model")
        }
    }
    
    private init() {
        if let modelURL = Bundle(for: CoreDataStack.self).url(forResource: "AcrosticDataModel", withExtension: "momd") {
            // Log model URL for debugging
            print("Looking for data model at: \(modelURL)")
            
            // Create a managed object model from URL
            let model = NSManagedObjectModel(contentsOf: modelURL)
            if model == nil {
                fatalError("Unable to load model at \(modelURL)")
            }
            
            // Create persistent container with the loaded model
            persistentContainer = NSPersistentContainer(name: "AcrosticDataModel", managedObjectModel: model!)
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
            
            // Create an in-memory model as a fallback
            print("⚠️ Using fallback model description")
            
            // Create a managed object model programmatically
            let managedObjectModel = NSManagedObjectModel()
            
            // Create Token entity
            let tokenEntity = NSEntityDescription()
            tokenEntity.name = "TokenEntity"
            tokenEntity.managedObjectClassName = "TokenEntity"
            
            // Create Token attributes
            let idAttribute = NSAttributeDescription()
            idAttribute.name = "id"
            idAttribute.attributeType = .UUIDAttributeType
            idAttribute.isOptional = true
            
            let nameAttribute = NSAttributeDescription()
            nameAttribute.name = "name"
            nameAttribute.attributeType = .stringAttributeType
            nameAttribute.isOptional = true
            
            let connectionStatusAttribute = NSAttributeDescription()
            connectionStatusAttribute.name = "connectionStatus"
            connectionStatusAttribute.attributeType = .booleanAttributeType
            connectionStatusAttribute.isOptional = false
            
            let isActivatedAttribute = NSAttributeDescription()
            isActivatedAttribute.name = "isActivated"
            isActivatedAttribute.attributeType = .booleanAttributeType
            isActivatedAttribute.isOptional = false
            
            let workspaceIDAttribute = NSAttributeDescription()
            workspaceIDAttribute.name = "workspaceID"
            workspaceIDAttribute.attributeType = .stringAttributeType
            workspaceIDAttribute.isOptional = true
            
            let workspaceNameAttribute = NSAttributeDescription()
            workspaceNameAttribute.name = "workspaceName"
            workspaceNameAttribute.attributeType = .stringAttributeType
            workspaceNameAttribute.isOptional = true
            
            let lastValidatedAttribute = NSAttributeDescription()
            lastValidatedAttribute.name = "lastValidated"
            lastValidatedAttribute.attributeType = .dateAttributeType
            lastValidatedAttribute.isOptional = true
            
            // Add attributes to entity
            tokenEntity.properties = [
                idAttribute,
                nameAttribute,
                connectionStatusAttribute,
                isActivatedAttribute,
                workspaceIDAttribute,
                workspaceNameAttribute,
                lastValidatedAttribute
            ]
            
            // Create a relationship to DatabaseEntity
            let databasesRelationship = NSRelationshipDescription()
            databasesRelationship.name = "databases"
            databasesRelationship.destinationEntity = nil // Will be set after creating DatabaseEntity
            databasesRelationship.maxCount = 0
            databasesRelationship.deleteRule = .nullifyDeleteRule
            databasesRelationship.isOptional = true
            
            // Create Database entity
            let dbEntity = NSEntityDescription()
            dbEntity.name = "DatabaseEntity"
            dbEntity.managedObjectClassName = "DatabaseEntity"
            
            // Create database attributes
            let dbIdAttribute = NSAttributeDescription()
            dbIdAttribute.name = "id"
            dbIdAttribute.attributeType = .stringAttributeType
            dbIdAttribute.isOptional = true
            
            let titleAttribute = NSAttributeDescription()
            titleAttribute.name = "title"
            titleAttribute.attributeType = .stringAttributeType
            titleAttribute.isOptional = true
            
            let descAttribute = NSAttributeDescription()
            descAttribute.name = "databaseDescription"
            descAttribute.attributeType = .stringAttributeType
            descAttribute.isOptional = true
            
            let createdTimeAttribute = NSAttributeDescription()
            createdTimeAttribute.name = "createdTime"
            createdTimeAttribute.attributeType = .dateAttributeType
            createdTimeAttribute.isOptional = true
            
            let lastEditedTimeAttribute = NSAttributeDescription()
            lastEditedTimeAttribute.name = "lastEditedTime"
            lastEditedTimeAttribute.attributeType = .dateAttributeType
            lastEditedTimeAttribute.isOptional = true
            
            let lastSyncTimeAttribute = NSAttributeDescription()
            lastSyncTimeAttribute.name = "lastSyncTiime" // Match the typo in your code
            lastSyncTimeAttribute.attributeType = .dateAttributeType
            lastSyncTimeAttribute.isOptional = true
            
            let urlAttribute = NSAttributeDescription()
            urlAttribute.name = "url"
            urlAttribute.attributeType = .stringAttributeType
            urlAttribute.isOptional = true
            
            let widgetEnabledAttribute = NSAttributeDescription()
            widgetEnabledAttribute.name = "widgetEnabled"
            widgetEnabledAttribute.attributeType = .booleanAttributeType
            widgetEnabledAttribute.isOptional = false
            
            let widgetTypeAttribute = NSAttributeDescription()
            widgetTypeAttribute.name = "widgetType"
            widgetTypeAttribute.attributeType = .stringAttributeType
            widgetTypeAttribute.isOptional = true
            
            // Create database-token relationship
            let tokenRelationship = NSRelationshipDescription()
            tokenRelationship.name = "token"
            tokenRelationship.destinationEntity = tokenEntity
            tokenRelationship.maxCount = 1
            tokenRelationship.deleteRule = .nullifyDeleteRule
            tokenRelationship.isOptional = true
            
            // Set up inverse relationships
            databasesRelationship.destinationEntity = dbEntity
            databasesRelationship.inverseRelationship = tokenRelationship
            tokenRelationship.inverseRelationship = databasesRelationship
            
            // Add attributes to database entity
            dbEntity.properties = [
                dbIdAttribute,
                titleAttribute,
                descAttribute,
                createdTimeAttribute,
                lastEditedTimeAttribute,
                lastSyncTimeAttribute,
                urlAttribute,
                widgetEnabledAttribute,
                widgetTypeAttribute,
                tokenRelationship
            ]
            
            // Add the relationships to token entity
            tokenEntity.properties = tokenEntity.properties + [databasesRelationship]
            
            // Set entities on the model
            managedObjectModel.entities = [tokenEntity, dbEntity]
            
            // Create persistent container with the fallback model
            persistentContainer = NSPersistentContainer(name: "AcrosticDataModel", managedObjectModel: managedObjectModel)
        }
        
        // Set the store URL to the shared app group container for widget access
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.acrostic") {
            let storeURL = appGroupURL.appendingPathComponent("AcrosticDataModel.sqlite")
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
                print("⚠️ CoreData error encountered, continuing with limited functionality")
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
