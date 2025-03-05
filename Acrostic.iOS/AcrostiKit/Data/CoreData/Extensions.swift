// AcrostiKit/Data/CoreData/Extensions.swift
import Foundation
import CoreData

extension NSManagedObject {
    func toDatabaseViewModel() -> DatabaseViewModelInternal? {
        guard let id = value(forKey: "id") as? String,
              let tokenRelationships = value(forKey: "token") as? Set<NSManagedObject>,
              let tokenObject = tokenRelationships.first,
              let tokenID = tokenObject.value(forKey: "id") as? UUID else {
            return nil
        }
        
        // Get title from titleString or title array
        let title: String
        if let titleString = value(forKey: "titleString") as? String, !titleString.isEmpty {
            title = titleString
        } else if let titleArray = value(forKey: "title") as? NSArray,
                  let firstItem = titleArray.firstObject as? [String: Any],
                  let textContent = firstItem["text"] as? [String: Any],
                  let content = textContent["content"] as? String {
            title = content
        } else {
            title = "Untitled"
        }
        
        let isSelected = value(forKey: "widgetEnabled") as? Bool ?? false
        let lastUpdated = value(forKey: "lastEditedTime") as? Date ?? Date()
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
    
    func toTaskItem() -> TaskItem? {
        guard let id = value(forKey: "id") as? String,
              let title = value(forKey: "title") as? String else {
            return nil
        }
        
        let isCompleted = value(forKey: "isCompleted") as? Bool ?? false
        let dueDate = value(forKey: "dueDate") as? Date
        
        return TaskItem(
            id: id,
            title: title,
            isCompleted: isCompleted,
            dueDate: dueDate
        )
    }
    
    // Call this when setting ID
    func debugSetValue(_ value: Any?, forKey key: String) {
        self.setValue(value, forKey: key)
        
        // Add special debugging for ID key
        if key == "id" {
            print("🔍 DEBUG: Setting \(key) = \(value ?? "nil") on \(self)")
            
            // Verify it was set
            let verifyValue = self.value(forKey: key)
            print("🔍 DEBUG: Verify \(key) = \(verifyValue ?? "nil") after setting")
            
            // Print stack trace
            let symbols = Thread.callStackSymbols
            print("🔍 DEBUG: Stack trace for ID setting:")
            for symbol in symbols.prefix(10) {
                print("   \(symbol)")
            }
        }
    }
    
    static func createToken(from token: TokenEntity, in context: NSManagedObjectContext) -> NSManagedObject {
        let tokenEntity = NSEntityDescription.insertNewObject(forEntityName: "Token", into: context)
        
        tokenEntity.setValue(token.id, forKey: "id")
        tokenEntity.setValue(token.apiToken, forKey: "apiToken")
        tokenEntity.setValue(token.workspaceID, forKey: "workspaceID")
        tokenEntity.setValue(token.workspaceName, forKey: "workspaceName")
        tokenEntity.setValue(token.connectionStatus, forKey: "connectionStatus")
        tokenEntity.setValue(token.isActivated, forKey: "isActivated")
        tokenEntity.setValue(Date(), forKey: "lastValidated")
        
        return tokenEntity
    }
    
    func setWidgetConfiguration(_ configuration: [String: Any]) {
        do {
            // Convert Data to NSDictionary explicitly
            let configData = try JSONSerialization.data(withJSONObject: configuration, options: [])
            let configDict = try JSONSerialization.jsonObject(with: configData, options: []) as? NSDictionary
            self.setValue(configDict, forKey: "configData")
        } catch {
            print("Error serializing widget configuration: \(error)")
        }
    }
    
    // Add create methods for different entities
    static func create(from task: TaskItem, databaseID: String, pageID: String, tokenID: UUID, in context: NSManagedObjectContext) -> NSManagedObject {
        let taskEntity = NSEntityDescription.insertNewObject(forEntityName: "Task", into: context)
        
        taskEntity.setValue(task.id, forKey: "id")
        taskEntity.setValue(task.title, forKey: "title")
        taskEntity.setValue(task.isCompleted, forKey: "isCompleted")
        taskEntity.setValue(task.dueDate, forKey: "dueDate")
        taskEntity.setValue(databaseID, forKey: "databaseID")
        taskEntity.setValue(Date(), forKey: "lastSyncTime")
        
        return taskEntity
    }
    
    // Update method for tasks
    func update(from task: TaskItem) {
        setValue(task.title, forKey: "title")
        setValue(task.isCompleted, forKey: "isCompleted")
        setValue(task.dueDate, forKey: "dueDate")
    }
    
    // Create method for search filters
    static func createSearchFilter(from filter: NotionSearchFilter, in context: NSManagedObjectContext) -> NSManagedObject {
        let filterEntity = NSEntityDescription.insertNewObject(forEntityName: "SearchFilter", into: context)
        
        filterEntity.setValue(filter.property, forKey: "property")
        filterEntity.setValue(filter.value, forKey: "value")
        
        return filterEntity
    }
}

extension QueryEntity {
    static func create(databaseID: String, request: NotionQueryDatabaseRequest, in context: NSManagedObjectContext) -> QueryEntity {
        let queryEntity = NSEntityDescription.insertNewObject(forEntityName: "QueryEntity", into: context) as! QueryEntity
        
        queryEntity.id = UUID()
        queryEntity.databaseID = databaseID
        queryEntity.createdAt = Date()
        
        // Convert request to dictionary for storage
        do {
            let encoder = JSONEncoder()
            let requestData = try encoder.encode(request)
            
            // Convert Data to NSDictionary
            if let jsonObject = try JSONSerialization.jsonObject(with: requestData) as? NSDictionary {
                queryEntity.queryData = jsonObject
            }
        } catch {
            print("Error encoding query request: \(error)")
        }
        
        return queryEntity
    }
}

extension NotionPage {
    func toEntity(in context: NSManagedObjectContext) -> NSManagedObject {
        let pageEntity = NSEntityDescription.insertNewObject(forEntityName: "Page", into: context)
        
        pageEntity.setValue(id, forKey: "id")
        pageEntity.setValue(createdTime, forKey: "createdTime")
        pageEntity.setValue(lastEditedTime, forKey: "lastEditedTime")
        pageEntity.setValue(url, forKey: "url")
        pageEntity.setValue(archived, forKey: "archived")
        pageEntity.setValue(getTitle(), forKey: "title")
        
        return pageEntity
    }
}

extension NotionDatabase {
    func toEntity(in context: NSManagedObjectContext) -> NSManagedObject {
        let databaseEntity = NSEntityDescription.insertNewObject(forEntityName: "Database", into: context)
        
        databaseEntity.setValue(id, forKey: "id")
        databaseEntity.setValue(createdTime, forKey: "createdTime")
        databaseEntity.setValue(lastEditedTime, forKey: "lastEditedTime")
        databaseEntity.setValue(url, forKey: "url")
        databaseEntity.setValue(archived, forKey: "archived")
        databaseEntity.setValue(getTitleText(), forKey: "titleString")
        
        return databaseEntity
    }
}

extension NotionBlock {
    func toEntity(in context: NSManagedObjectContext) -> NSManagedObject {
        let blockEntity = NSEntityDescription.insertNewObject(forEntityName: "Block", into: context)
        
        blockEntity.setValue(id, forKey: "id")
        blockEntity.setValue(createdTime, forKey: "createdTime")
        blockEntity.setValue(lastEditedTime, forKey: "lastEditedTime")
        blockEntity.setValue(type, forKey: "type")
        blockEntity.setValue(archived, forKey: "archived")
        
        // Store block content if available
        do {
            let encoder = JSONEncoder()
            if let blockContent = blockContent?.value as? Encodable {
                let contentData = try encoder.encode(blockContent)
                blockEntity.setValue(contentData, forKey: "data")
            }
        } catch {
            print("Error encoding block content: \(error)")
        }
        
        return blockEntity
    }
}
