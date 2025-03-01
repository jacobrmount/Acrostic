// DataManagement/Controllers/PageDataController.swift
import Foundation
import CoreData

/// Manages all page-related Core Data operations
public final class PageDataController {
    /// The shared singleton instance
    public static let shared = PageDataController()
    
    private init() {}
    
    // MARK: - Fetch Operations
    
    /// Fetches all pages for a specific database
    public func fetchPages(for databaseID: String) -> [PageEntity] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<PageEntity>(entityName: "PageEntity")
        request.predicate = NSPredicate(format: "parentDatabaseID == %@", databaseID)
        request.sortDescriptors = [NSSortDescriptor(key: "lastEditedTime", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching pages for database \(databaseID): \(error)")
            return []
        }
    }
    
    /// Fetches a specific page by ID
    public func fetchPage(id: String) -> PageEntity? {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<PageEntity>(entityName: "PageEntity")
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
            // Make sure we have a valid ID
            guard let pageId = page.id else {
                return nil
            }
            
            // We don't need these values directly, just get the properties
            // and let the PageEntity.extractCompletionStatus() and extractDueDate() methods do the work
            let isCompleted = page.extractCompletionStatus()
            let dueDate = page.extractDueDate()
            
            return TaskItem(
                id: pageId,
                title: page.title ?? "Untitled",
                isCompleted: isCompleted,
                dueDate: dueDate
            )
        }
    }
    
    // MARK: - Create/Update Operations
    
    /// Creates or updates a page from a NotionPage model
    public func savePage(from notionPage: NotionPage, in databaseID: String? = nil) async -> PageEntity? {
        let context = CoreDataStack.shared.viewContext
        
        // Check if the page already exists
        let request = NSFetchRequest<PageEntity>(entityName: "PageEntity")
        request.predicate = NSPredicate(format: "id == %@", notionPage.id)
        
        do {
            let existingPages = try context.fetch(request)
            
            if let existingPage = existingPages.first {
                // Update existing page
                updatePage(existingPage, from: notionPage, context: context)
                try context.save()
                return existingPage
            } else {
                // Create new page
                let newPage = PageEntity(context: context)
                newPage.id = notionPage.id
                newPage.createdTime = notionPage.createdTime
                newPage.lastEditedTime = notionPage.lastEditedTime
                newPage.archived = notionPage.archived ?? false
                newPage.url = notionPage.url
                newPage.lastSyncTime = Date()
                
                // Set title from properties
                if let titleProperty = notionPage.properties?.first(where: { $0.key.lowercased().contains("title") }) {
                    // Use extension method instead of direct casting
                    if let titleDict = titleProperty.value.value.getValueDictionary(),
                       let titleArray = titleDict["title"] as? [[String: Any]],
                       !titleArray.isEmpty,
                       let firstTitle = titleArray.first,
                       let text = firstTitle["text"] as? [String: Any],
                       let content = text["content"] as? String {
                        newPage.title = content
                    } else {
                        newPage.title = "Untitled"
                    }
                } else {
                    newPage.title = "Untitled"
                }
                
                // Set parent references
                if let parent = notionPage.parent {
                    if parent.type == "database_id" {
                        newPage.parentDatabaseID = parent.databaseID
                        
                        // If we have a database ID, try to find and link the database
                        if let databaseID = parent.databaseID {
                            let fetchRequest = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
                            fetchRequest.predicate = NSPredicate(format: "id == %@", databaseID)
                            do {
                                if let database = try context.fetch(fetchRequest).first {
                                    newPage.database = database
                                }
                            } catch {
                                print("Error linking page to database: \(error)")
                            }
                        }
                    } else if parent.type == "page_id" {
                        newPage.parentPageID = parent.databaseID // Using databaseID for pageID (model mismatch)
                    }
                }
                
                // If databaseID is provided explicitly, link to database
                if let databaseID = databaseID, newPage.parentDatabaseID == nil {
                    newPage.parentDatabaseID = databaseID
                    
                    let dbRequest = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
                    dbRequest.predicate = NSPredicate(format: "id == %@", databaseID)
                    if let database = try context.fetch(dbRequest).first {
                        newPage.database = database
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
    private func updatePage(_ page: PageEntity, from notionPage: NotionPage, context: NSManagedObjectContext) {
        page.createdTime = notionPage.createdTime
        page.lastEditedTime = notionPage.lastEditedTime
        page.archived = notionPage.archived ?? false
        page.url = notionPage.url
        page.lastSyncTime = Date()
        
        // Update title from properties
        if let titleProperty = notionPage.properties?.first(where: { $0.key.lowercased().contains("title") }) {
            // Use extension method instead of direct casting
            if let titleDict = titleProperty.value.value.getValueDictionary(),
               let titleArray = titleDict["title"] as? [[String: Any]],
               !titleArray.isEmpty,
               let firstTitle = titleArray.first,
               let text = firstTitle["text"] as? [String: Any],
               let content = text["content"] as? String {
                page.title = content
            }
        }
        
        // Update parent references
        if let parent = notionPage.parent {
            if parent.type == "database_id" {
                page.parentDatabaseID = parent.databaseID
                page.parentPageID = nil
                
                // If we have a database ID, try to find and link the database
                if let databaseID = parent.databaseID {
                    let dbRequest = NSFetchRequest<DatabaseEntity>(entityName: "DatabaseEntity")
                    dbRequest.predicate = NSPredicate(format: "id == %@", databaseID)
                    do {
                        if let database = try context.fetch(dbRequest).first {
                            page.database = database
                        }
                    } catch {
                        print("Error linking page to database: \(error)")
                    }
                }
            } else if parent.type == "page_id" {
                page.parentDatabaseID = nil
                page.parentPageID = parent.databaseID // Using databaseID for pageID (model mismatch)
            }
        }
    }
    
    /// Saves multiple pages from an API response
    public func savePages(from notionPages: [NotionPage], in databaseID: String) async -> [PageEntity] {
        var savedPages: [PageEntity] = []
        
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
        let request = NSFetchRequest<PageEntity>(entityName: "PageEntity")
        request.predicate = NSPredicate(format: "parentDatabaseID == %@", databaseID)
        
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
        let request = NSFetchRequest<PageEntity>(entityName: "PageEntity")
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
