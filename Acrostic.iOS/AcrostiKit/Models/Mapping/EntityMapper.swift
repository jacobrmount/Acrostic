// AcrostiKit/Models/Mapping/EntityMapper.swift
import Foundation
import CoreData

public class EntityMapper {
    
    // MARK: - NotionDatabase Mapping
    
    public static func toEntity(database: NotionDatabase, in context: NSManagedObjectContext) -> NSManagedObject {
        let entity = fetchOrCreateEntity(id: database.id, entityName: "Database", in: context)
        
        // Set basic properties
        entity.setValue(database.id, forKey: "id")
        entity.setValue(database.createdTime, forKey: "createdTime")
        entity.setValue(database.lastEditedTime, forKey: "lastEditedTime")
        entity.setValue(database.url, forKey: "url")
        entity.setValue(database.archived, forKey: "archived")
        entity.setValue(Date(), forKey: "lastSyncTime")
        
        // Set title string
        let titleText = database.getTitleText()
        entity.setValue(titleText, forKey: "titleString")
        
        // Convert title to NSArray
        let titleArray: NSArray = [["text": ["content": titleText]]]
        entity.setValue(titleArray, forKey: "title")
        
        return entity
    }
    
    // MARK: - NotionPage Mapping
    
    public static func toEntity(page: NotionPage, in context: NSManagedObjectContext) -> NSManagedObject {
        let entity = fetchOrCreateEntity(id: page.id, entityName: "Page", in: context)
        
        // Set basic properties
        entity.setValue(page.id, forKey: "id")
        entity.setValue(page.createdTime, forKey: "createdTime")
        entity.setValue(page.lastEditedTime, forKey: "lastEditedTime")
        entity.setValue(page.url, forKey: "url")
        entity.setValue(page.archived, forKey: "archived")
        entity.setValue(Date(), forKey: "lastSyncTime")
        
        // Set title
        let titleText = page.getTitle()
        entity.setValue(titleText, forKey: "title")
        
        // Set parent references
        if let parent = page.parent {
            if parent.type == "database_id", let databaseID = parent.databaseID {
                entity.setValue(databaseID, forKey: "databaseID")
                
                // Try to set the database relationship
                let dbRequest = NSFetchRequest<NSManagedObject>(entityName: "Database")
                dbRequest.predicate = NSPredicate(format: "id == %@", databaseID)
                
                if let database = try? context.fetch(dbRequest).first {
                    entity.setValue(database, forKey: "parentDatabase")
                }
            }
        }
        
        return entity
    }
    
    // MARK: - TaskItem Mapping
    
    public static func toEntity(task: TaskItem, databaseID: String, pageID: String, tokenID: UUID, in context: NSManagedObjectContext) -> NSManagedObject {
        let taskEntity = NSEntityDescription.insertNewObject(forEntityName: "Task", into: context)
        
        taskEntity.setValue(task.id, forKey: "id")
        taskEntity.setValue(task.title, forKey: "title")
        taskEntity.setValue(task.isCompleted, forKey: "isCompleted")
        taskEntity.setValue(task.dueDate, forKey: "dueDate")
        taskEntity.setValue(databaseID, forKey: "databaseID")
        taskEntity.setValue(Date(), forKey: "lastSyncTime")
        
        // Set relationships
        let databaseRequest = NSFetchRequest<NSManagedObject>(entityName: "Database")
        databaseRequest.predicate = NSPredicate(format: "id == %@", databaseID)
        
        let tokenRequest = NSFetchRequest<NSManagedObject>(entityName: "Token")
        tokenRequest.predicate = NSPredicate(format: "id == %@", tokenID as CVarArg)
        
        do {
            if let database = try context.fetch(databaseRequest).first {
                taskEntity.setValue(database, forKey: "database")
            }
            
            if let token = try context.fetch(tokenRequest).first {
                taskEntity.setValue(token, forKey: "token")
            }
        } catch {
            print("Error setting relationships: \(error)")
        }
        
        return taskEntity
    }
    
    // MARK: - Helper Methods
    
    private static func fetchOrCreateEntity(id: String, entityName: String, in context: NSManagedObjectContext) -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let results = try context.fetch(request)
            if let existing = results.first {
                return existing
            }
        } catch {
            print("Error fetching entity: \(error)")
        }
        
        return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
    }
}
