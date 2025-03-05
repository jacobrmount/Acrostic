// AcrostiKit/Data/Controllers/FilterController.swift
import Foundation
import CoreData

public final class SearchFilterDataController {
    public static let shared = SearchFilterDataController()
    
    private init() {}
    
    public func saveSearchFilter(_ filter: NotionSearchFilter) -> NSManagedObject? {
        let context = CoreDataStack.shared.viewContext
        
        // Use the NSManagedObject extension method to create a search filter entity
        let entity = NSManagedObject.createSearchFilter(from: filter, in: context)
        
        do {
            try context.save()
            return entity
        } catch {
            print("Error saving search filter: \(error)")
            return nil
        }
    }
    
    public func fetchSearchFilter(property: String, value: String) -> NSManagedObject? {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "SearchFilter")
        request.predicate = NSPredicate(format: "property == %@ AND value == %@", property, value)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching search filter: \(error)")
            return nil
        }
    }
}
