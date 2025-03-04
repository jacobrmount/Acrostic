// DataManagement/Entities/SearchFilterEntity+Extensions.swift
import Foundation
import CoreData

extension SearchFilterEntity {
    // Create a SearchFilterEntity from a NotionSearchFilter
    static func create(from filter: NotionSearchFilter, in context: NSManagedObjectContext) -> SearchFilterEntity {
        let entity = SearchFilterEntity(context: context)
        entity.setValue(UUID(), forKey: "id")
        entity.setValue(filter.property, forKey: "property")
        entity.setValue(filter.value, forKey: "value")
        entity.setValue(filter.type, forKey: "type")
        entity.setValue(Date(), forKey: "createdAt")
        
        return entity
    }
    
    // Convert to NotionSearchFilter
    func toNotionSearchFilter() -> NotionSearchFilter {
        let filter = NotionSearchFilter()
        filter.property = self.value(forKey: "property") as? String ?? ""
        filter.value = self.value(forKey: "value") as? String ?? ""
        filter.type = self.value(forKey: "type") as? String
        
        return filter
    }
}
