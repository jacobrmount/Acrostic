// NactionsKit/DataManagement/Entities/PageEntity+Extensions.swift
import Foundation
import CoreData

public extension PageEntity {
    /// Converts this entity to a TaskItem for widget display
    func toTaskItem() -> TaskItem {
        // Extract data from properties
        let isCompleted = self.extractCompletionStatus()
        let dueDate = self.extractDueDate()
        
        return TaskItem(
            id: self.id ?? "",
            title: self.title ?? "Untitled Task",
            isCompleted: isCompleted,
            dueDate: dueDate
        )
    }
    
    /// Updates this entity from a NotionPage model
    func update(from page: NotionPage) {
        self.id = page.id
        self.title = getPageTitle(from: page)
        self.createdTime = page.createdTime
        self.lastEditedTime = page.lastEditedTime
        self.archived = page.archived ?? false
        self.url = page.url
        self.lastSyncTime = Date()
        
        // Extract parent references
        if let parent = page.parent {
            if parent.type == "database_id" {
                self.parentDatabaseID = parent.databaseID
            } else if parent.type == "page_id" {
                self.parentPageID = parent.pageID
            }
        }
        
        // Store properties as serialized data
        if let properties = page.properties {
            do {
                // Safely transform JSONAny values to serializable objects
                let propertyDict = properties.compactMapValues { propertyValue -> Any? in
                    // Handle different value types
                    if let valueDict = propertyValue.value.getValueDictionary() {
                        return valueDict
                    } else if let valueArray = propertyValue.value.getArray() {
                        return valueArray
                    } else if let primitive = propertyValue.value.value as? NSObject {
                        return primitive
                    }
                    return nil
                }
                
                let data = try NSKeyedArchiver.archivedData(withRootObject: propertyDict, requiringSecureCoding: false)
                self.properties = data
            } catch {
                print("Error serializing page properties: \(error)")
            }
        }
    }
    
    /// Helper method to extract title from a page
    private func getPageTitle(from page: NotionPage) -> String {
        if let properties = page.properties,
           let titleProp = properties.first(where: { $0.key.lowercased().contains("title") || $0.key.lowercased().contains("name") }) {
            
            // Use the helper method to avoid direct casting
            if let titleDict = titleProp.value.value.getValueDictionary(),
               let titleArray = titleDict["title"] as? [[String: Any]] {
                
                // Extract text from title elements
                let texts = titleArray.compactMap { item -> String? in
                    if let textObj = item["text"] as? [String: Any],
                       let content = textObj["content"] as? String {
                        return content
                    }
                    return nil
                }
                
                return texts.joined()
            }
        }
        
        return "Untitled"
    }
    
    /// Extract properties from serialized data
    private func getProperties() -> [String: Any]? {
        guard let propertiesData = self.properties else { return nil }
        
        do {
            // Use the non-deprecated API
            if let properties = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: propertiesData) as? [String: Any] {
                return properties
            }
        } catch {
            print("Error deserializing page properties: \(error)")
            
            // Use newer API instead of deprecated method
            do {
                let unarchiver = try NSKeyedUnarchiver(forReadingFrom: propertiesData)
                unarchiver.requiresSecureCoding = false
                if let properties = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? [String: Any] {
                    return properties
                }
            } catch {
                print("Fallback deserialization also failed: \(error)")
            }
        }
        
        return nil
    }
    
    /// Extracts completion status from properties
    func extractCompletionStatus() -> Bool {
        guard let properties = getProperties() else { return false }
        
        // Look for common status/checkbox property names
        for propName in ["status", "complete", "done", "completed", "checkbox"] {
            if let prop = properties.first(where: { $0.key.lowercased().contains(propName) }) {
                let propValue = prop.value
                // Try to extract checkbox value
                if let propDict = propValue as? [String: Any],
                   let checkbox = propDict["checkbox"] as? Bool {
                    return checkbox
                }
                
                // Try to extract select value
                if let propDict = propValue as? [String: Any],
                   let select = propDict["select"] as? [String: Any],
                   let name = select["name"] as? String {
                    return ["done", "complete", "completed"].contains(name.lowercased())
                }
            }
        }
        
        return false
    }
    
    /// Extracts due date from properties
    func extractDueDate() -> Date? {
        guard let properties = getProperties() else { return nil }
        
        // Look for date property
        for propName in ["date", "due", "deadline", "due date"] {
            if let prop = properties.first(where: { $0.key.lowercased().contains(propName) }) {
                let propValue = prop.value
                if let propDict = propValue as? [String: Any],
                   let dateObj = propDict["date"] as? [String: Any],
                   let dateStr = dateObj["start"] as? String {
                    
                    // Parse ISO 8601 date
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return formatter.date(from: dateStr)
                }
            }
        }
        
        return nil
    }
    
    /// Helper method to get a specific property by name
    func getProperty(whereNameContains searchStrings: [String]) -> [String: Any]? {
        guard let properties = getProperties() else { return nil }
        
        for searchString in searchStrings {
            if let prop = properties.first(where: { $0.key.lowercased().contains(searchString.lowercased()) }) {
                let propValue = prop.value
                if let propDict = propValue as? [String: Any] {
                    return propDict
                }
            }
        }
        
        return nil
    }
}
