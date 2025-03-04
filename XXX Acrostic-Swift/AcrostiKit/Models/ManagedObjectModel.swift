// NactionsKit/DataManagement/Models/ManagedObjectModel.swift
import Foundation
import CoreData

// This file contains extension methods for managed objects to replace User+Extensions.swift
// since the User entity seems to be unavailable in the current Core Data model

extension NSManagedObject {
    // Helper method to safely get a string value from a managed object
    func getString(_ key: String) -> String? {
        return self.value(forKey: key) as? String
    }
    
    // Helper method to safely get a date value from a managed object
    func getDate(_ key: String) -> Date? {
        return self.value(forKey: key) as? Date
    }
    
    // Helper method to safely get a boolean value from a managed object
    func getBool(_ key: String) -> Bool {
        return (self.value(forKey: key) as? Bool) ?? false
    }
}

// Extension to add conversion functionality from Core Data to model objects
extension NSManagedObjectContext {
    // Convert query results to model objects
    func convert<T, U>(_ entities: [T], converter: (T) -> U?) -> [U] {
        return entities.compactMap { converter($0) }
    }
    
    // Execute a fetch request and convert results
    func fetchAndConvert<T: NSManagedObject, U>(_ request: NSFetchRequest<T>, converter: (T) -> U?) -> [U] {
        do {
            let results = try self.fetch(request)
            return results.compactMap { converter($0) }
        } catch {
            print("Error fetching: \(error)")
            return []
        }
    }
}
