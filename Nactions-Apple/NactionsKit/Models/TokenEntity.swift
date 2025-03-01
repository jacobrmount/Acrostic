// NactionsKit/Models/TokenEntity.swift
import Foundation
import CoreData

extension TokenEntity {
    @objc(addDatabasesObject:)
    @NSManaged public func addToDatabases(_ value: DatabaseEntity)
    
    @objc(removeDatabasesObject:)
    @NSManaged public func removeFromDatabases(_ value: DatabaseEntity)
    
    @objc(addDatabases:)
    @NSManaged public func addToDatabases(_ values: NSSet)
    
    @objc(removeDatabases:)
    @NSManaged public func removeFromDatabases(_ values: NSSet)
    
    public var apiToken: String? {
        get {
            guard let id = self.id else { return nil }
            return TokenDataController.shared.getSecureToken(for: id.uuidString)
        }
        set {
            guard let id = self.id, let token = newValue else { return }
            TokenDataController.shared.storeSecureToken(token, for: id.uuidString)
        }
    }
}
