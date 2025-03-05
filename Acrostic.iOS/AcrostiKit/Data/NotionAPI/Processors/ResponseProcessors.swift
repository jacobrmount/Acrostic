// AcrostiKit/Models/ResponseProcessors.swift
import Foundation
import CoreData

// MARK: - Database Processing

/// Processes database query results and stores them in Core Data
public class DatabaseQueryProcessor: NotionPaginatedProcessor {
    public typealias ItemType = NotionPage
    
    private let context: NSManagedObjectContext
    private let databaseID: String
    private let tokenID: UUID
    private var processedCount: Int = 0
    private let maxItems: Int
    private let batchSize: Int
    
    public init(
        context: NSManagedObjectContext,
        databaseID: String,
        tokenID: UUID,
        maxItems: Int = .max,
        batchSize: Int = 50
    ) {
        self.context = context
        self.databaseID = databaseID
        self.tokenID = tokenID
        self.maxItems = maxItems
        self.batchSize = batchSize
    }
    
    public func process(results: [NotionPage]) -> Bool {
        let batch = results.prefix(maxItems - processedCount)
        
        for page in batch {
            // Explicitly convert page to entity
            let pageEntity = NSEntityDescription.insertNewObject(forEntityName: "Page", into: context)
            pageEntity.setValue(page.id, forKey: "id")
            pageEntity.setValue(page.createdTime, forKey: "createdTime")
            pageEntity.setValue(page.lastEditedTime, forKey: "lastEditedTime")
            pageEntity.setValue(page.getTitle(), forKey: "title")
            
            // Create task similarly
            let taskEntity = NSEntityDescription.insertNewObject(forEntityName: "Task", into: context)
            taskEntity.setValue(page.id, forKey: "id")
            taskEntity.setValue(page.getTitle(), forKey: "title")
            taskEntity.setValue(page.getCompletionStatus(), forKey: "isCompleted")
            taskEntity.setValue(page.getDueDate(), forKey: "dueDate")
        }
        
        // Save in batches
        if processedCount % batchSize == 0 {
            do {
                try context.save()
            } catch {
                print("Error saving batch: \(error)")
                return false
            }
        }
        
        processedCount += batch.count
        
        return true
    }
    
    public func shouldContinue() -> Bool {
        return processedCount < maxItems
    }
    
    public func getProcessedCount() -> Int {
        return processedCount
    }
}

// MARK: - Search Processing

/// Processor for database search results
public class DatabaseSearchProcessor: NotionPaginatedProcessor {
    public typealias ItemType = NotionObject
    
    private let context: NSManagedObjectContext
    private let tokenID: UUID
    private var databases: [NotionDatabase] = []
    private let maxItems: Int
    
    public init(
        context: NSManagedObjectContext,
        tokenID: UUID,
        maxItems: Int = .max
    ) {
        self.context = context
        self.tokenID = tokenID
        self.maxItems = maxItems
    }
    
    public func process(results: [NotionObject]) -> Bool {
        // Filter for database objects only
        let databaseResults = results.compactMap { object -> NotionDatabase? in
            guard object.object == "database" else { return nil }
            
            // Try to cast to NotionDatabase
            if let database = object as? NotionDatabase {
                return database
            }
            return nil
        }
        
        // Add to our collection
        databases.append(contentsOf: databaseResults)
        
        // Save to Core Data
        for database in databaseResults {
            // Convert to NSManagedObject
            let entity = database.toEntity(in: context)
            
            // Set the token relationship
            let tokenRequest = NSFetchRequest<NSManagedObject>(entityName: "Token")
            tokenRequest.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
            
            do {
                if let tokenEntity = try context.fetch(tokenRequest).first {
                    entity.setValue(tokenEntity, forKey: "token")
                }
            } catch {
                print("Error finding token: \(error)")
            }
        }
        
        // Save context
        do {
            try context.save()
        } catch {
            print("Error saving databases: \(error)")
            return false
        }
        
        return true
    }
    
    public func shouldContinue() -> Bool {
        return databases.count < maxItems
    }
    
    public func getDatabases() -> [NotionDatabase] {
        return databases
    }
}

// MARK: - Block Processing

/// Processor for block children
public class BlockChildrenProcessor: NotionPaginatedProcessor {
    public typealias ItemType = NotionBlock
    
    private let context: NSManagedObjectContext
    private let parentPageID: String
    private var blocks: [NotionBlock] = []
    private let maxItems: Int

    public init(
        context: NSManagedObjectContext,
        parentPageID: String,
        maxItems: Int = .max
    ) {
        self.context = context
        self.parentPageID = parentPageID
        self.maxItems = maxItems
    }

    public func process(results: [NotionBlock]) -> Bool {
        // Add to our collection
        blocks.append(contentsOf: results)

        // Save to Core Data
        for block in results {
            // Convert to NSManagedObject
            let entity = block.toEntity(in: context)

            // Set the parent page relationship
            let pageRequest = NSFetchRequest<NSManagedObject>(entityName: "Page")
            pageRequest.predicate = NSPredicate(format: "id == %@", parentPageID)

            do {
                if let pageEntity = try context.fetch(pageRequest).first {
                    entity.setValue(pageEntity, forKey: "parentPage")
                }
            } catch {
                print("Error finding parent page: \(error)")
            }
        }

        // Save context
        do {
            try context.save()
        } catch {
            print("Error saving blocks: \(error)")
            return false
        }

        return true
    }

    public func shouldContinue() -> Bool {
        return blocks.count < maxItems
    }

    public func getBlocks() -> [NotionBlock] {
        return blocks
    }
}
