// AcrostiKit/Data/Controllers/PageController.swift
import Foundation
import CoreData

/// Manages all page-related Core Data operations
public final class PageDataController {
    /// The shared singleton instance
    public static let shared = PageDataController()
    
    private init() {}
    
    // MARK: - Fetch Operations
    
    /// Fetches all pages for a specific database
    public func fetchPages(for databaseID: String) -> [NSManagedObject] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Page")
        request.predicate = NSPredicate(format: "parentDatabase.id == %@", databaseID)
        request.sortDescriptors = [NSSortDescriptor(key: "lastEditedTime", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching pages for database \(databaseID): \(error)")
            return []
        }
    }
    
    /// Fetches a specific page by ID
    public func fetchPage(id: String) -> NSManagedObject? {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Page")
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching page with ID \(id): \(error)")
            return nil
        }
    }
    
    /// Fetches task items for a database
    public func fetchTaskItems(for databaseID: String) -> [TaskItem] {
        let pages = fetchPages(for: databaseID)
        
        return pages.compactMap { page -> TaskItem? in
            guard let pageId = page.value(forKey: "id") as? String else {
                return nil
            }
            
            // Get these values using extension methods on NSManagedObject
            let isCompleted = extractCompletionStatus(page)
            let dueDate = extractDueDate(page)
            
            return TaskItem(
                id: pageId,
                title: page.value(forKey: "title") as? String ?? "Untitled",
                isCompleted: isCompleted,
                dueDate: dueDate
            )
        }
    }
    
    // Helper method for extracting completion status
    private func extractCompletionStatus(_ page: NSManagedObject) -> Bool {
        // Implement the logic that was previously in Page extension
        // For now returning a default value
        return false
    }
    
    // Helper method for extracting due date
    private func extractDueDate(_ page: NSManagedObject) -> Date? {
        // Implement the logic that was previously in Page extension
        // For now returning nil
        return nil
    }
    
    // MARK: - Create/Update Operations
    
    /// Creates or updates a page from a NotionPage model
    public func savePage(from notionPage: NotionPage, in databaseID: String? = nil) async -> NSManagedObject? {
        let context = CoreDataStack.shared.viewContext
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "Page")
        request.predicate = NSPredicate(format: "id == %@", notionPage.id)
        
        do {
            let existingPages = try context.fetch(request)
            
            if let existingPage = existingPages.first {
                updatePage(existingPage, from: notionPage, context: context)
                try context.save()
                return existingPage
            } else {
                let newPage = NSEntityDescription.insertNewObject(forEntityName: "Page", into: context)
                newPage.setValue(notionPage.id, forKey: "id")
                newPage.setValue(notionPage.createdTime, forKey: "createdTime")
                newPage.setValue(notionPage.lastEditedTime, forKey: "lastEditedTime")
                newPage.setValue(notionPage.archived ?? false, forKey: "archived")
                newPage.setValue(notionPage.url, forKey: "url")
                newPage.setValue(Date(), forKey: "lastSyncTime")
                
                if let titleProperty = notionPage.properties?.first(where: { $0.key.lowercased().contains("title") }) {
                    if let titleDict = titleProperty.value.value.getValueDictionary(),
                       let titleArray = titleDict["title"] as? [[String: Any]],
                       !titleArray.isEmpty,
                       let firstTitle = titleArray.first,
                       let text = firstTitle["text"] as? [String: Any],
                       let content = text["content"] as? String {
                        newPage.setValue(content, forKey: "title")
                    } else {
                        newPage.setValue("Untitled", forKey: "title")
                    }
                } else {
                    newPage.setValue("Untitled", forKey: "title")
                }
                
                if let parent = notionPage.parent {
                    if parent.type == "database_id",
                       let databaseID = parent.databaseID {
                        let dbRequest = NSFetchRequest<NSManagedObject>(entityName: "Database")
                        dbRequest.predicate = NSPredicate(format: "id == %@", databaseID)
                        
                        if let database = try context.fetch(dbRequest).first {
                            newPage.setValue(database, forKey: "parentDatabase")
                        }
                    }
                }
                
                if let databaseID = databaseID,
                   newPage.value(forKey: "parentDatabase") == nil {
                    let dbRequest = NSFetchRequest<NSManagedObject>(entityName: "Database")
                    dbRequest.predicate = NSPredicate(format: "id == %@", databaseID)
                    
                    if let database = try context.fetch(dbRequest).first {
                        newPage.setValue(database, forKey: "parentDatabase")
                    }
                }
                
                try context.save()
                return newPage
            }
        } catch {
            print("Error saving page: \(error)")
            return nil
        }
    }
    
    /// Helper function to update a page from a Notion API model
    private func updatePage(_ page: NSManagedObject, from notionPage: NotionPage, context: NSManagedObjectContext) {
        page.setValue(notionPage.createdTime, forKey: "createdTime")
        page.setValue(notionPage.lastEditedTime, forKey: "lastEditedTime")
        page.setValue(notionPage.archived ?? false, forKey: "archived")
        page.setValue(notionPage.url, forKey: "url")
        page.setValue(Date(), forKey: "lastSyncTime")
        
        if let titleProperty = notionPage.properties?.first(where: { $0.key.lowercased().contains("title") }) {
            if let titleDict = titleProperty.value.value.getValueDictionary(),
               let titleArray = titleDict["title"] as? [[String: Any]],
               !titleArray.isEmpty,
               let firstTitle = titleArray.first,
               let text = firstTitle["text"] as? [String: Any],
               let content = text["content"] as? String {
                page.setValue(content, forKey: "title")
            }
        }
        
        if let parent = notionPage.parent {
            if parent.type == "database_id",
               let databaseID = parent.databaseID {
                let dbRequest = NSFetchRequest<NSManagedObject>(entityName: "Database")
                dbRequest.predicate = NSPredicate(format: "id == %@", databaseID)
                
                if let database = try? context.fetch(dbRequest).first {
                    page.setValue(database, forKey: "parentDatabase")
                }
            }
        }
    }
    
    /// Saves multiple pages from an API response
    public func savePages(from notionPages: [NotionPage], in databaseID: String) async -> [NSManagedObject] {
        var savedPages: [NSManagedObject] = []
        
        for page in notionPages {
            if let saved = await savePage(from: page, in: databaseID) {
                savedPages.append(saved)
            }
        }
        
        return savedPages
    }
    
    // MARK: - Delete Operations
    
    /// Deletes all pages for a specific database
    public func deletePages(for databaseID: String) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Page")
        request.predicate = NSPredicate(format: "parentDatabase.id == %@", databaseID)
        
        do {
            let pages = try context.fetch(request)
            for page in pages {
                context.delete(page)
            }
            try context.save()
            print("Deleted \(pages.count) pages for database \(databaseID)")
        } catch {
            print("Error deleting pages for database \(databaseID): \(error)")
        }
    }
    
    /// Deletes a specific page
    public func deletePage(id: String) {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Page")
        request.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            if let page = try context.fetch(request).first {
                context.delete(page)
                try context.save()
                print("Page deleted successfully")
            } else {
                print("Page with ID \(id) not found for deletion")
            }
        } catch {
            print("Error deleting page: \(error)")
        }
    }
}
