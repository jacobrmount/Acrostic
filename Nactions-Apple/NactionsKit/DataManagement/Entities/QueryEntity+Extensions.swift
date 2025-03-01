// DataManagement/Entities/QueryEntity+Extensions.swift
import Foundation
import CoreData

extension QueryEntity {
    // Create a QueryEntity from a database ID and query request
    static func create(databaseID: String, request: NotionQueryDatabaseRequest, in context: NSManagedObjectContext) -> QueryEntity {
        let entity = QueryEntity(context: context)
        entity.setValue(UUID(), forKey: "id")
        entity.setValue(databaseID, forKey: "databaseID")
        entity.setValue(Date(), forKey: "createdAt")
        
        // Serialize query data to binary
        do {
            let data = try JSONEncoder().encode(request)
            entity.setValue(data, forKey: "queryData")
        } catch {
            print("Error serializing query data: \(error)")
        }
        
        return entity
    }
    
    // Get the deserialized query request
    func getQueryRequest() -> NotionQueryDatabaseRequest? {
        guard let queryData = self.value(forKey: "queryData") as? Data else {
            return nil
        }
        
        do {
            let request = try JSONDecoder().decode(NotionQueryDatabaseRequest.self, from: queryData)
            return request
        } catch {
            print("Error deserializing query data: \(error)")
            return nil
        }
    }
}
