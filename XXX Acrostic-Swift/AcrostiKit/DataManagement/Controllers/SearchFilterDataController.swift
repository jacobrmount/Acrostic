// DataManagement/Controllers/SearchFilterDataController.swift
import Foundation
import CoreData

public final class SearchFilterDataController {
    public static let shared = SearchFilterDataController()
    
    private init() {}
    
    public func saveSearchFilter(_ filter: NotionSearchFilter) -> SearchFilterEntity? {
        let context = CoreDataStack.shared.viewContext
        let entity = SearchFilterEntity.create(from: filter, in: context)
        
        do {
            try context.save()
            return entity
        } catch {
            print("Error saving search filter: \(error)")
            return nil
        }
    }
    
    public func fetchSearchFilter(property: String, value: String) -> SearchFilterEntity? {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<SearchFilterEntity>(entityName: "SearchFilterEntity")
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
