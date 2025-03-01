// DataManagement/Controllers/QueryDataController.swift
import Foundation
import CoreData

public final class QueryDataController {
    public static let shared = QueryDataController()
    
    private init() {}
    
    public func saveQuery(databaseID: String, request: NotionQueryDatabaseRequest) -> QueryEntity? {
        let context = CoreDataStack.shared.viewContext
        let query = QueryEntity.create(databaseID: databaseID, request: request, in: context)
        
        do {
            try context.save()
            return query
        } catch {
            print("Error saving query: \(error)")
            return nil
        }
    }
    
    public func fetchQueries(for databaseID: String) -> [QueryEntity] {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<QueryEntity>(entityName: "QueryEntity")
        request.predicate = NSPredicate(format: "databaseID == %@", databaseID)
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching queries: \(error)")
            return []
        }
    }
}
