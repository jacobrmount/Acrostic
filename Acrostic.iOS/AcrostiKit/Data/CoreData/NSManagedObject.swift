// AcrostiKit/Data/CoreData/NSManagedObject.swift
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
            let configData = try JSONSerialization.data(withJSONObject: configuration, options: [])
            self.setValue(configData, forKey: "configData")
        } catch {
            print("Error serializing widget configuration: \(error)")
        }
    }
}
