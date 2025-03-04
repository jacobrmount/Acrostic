// TokenEntity.swift
import Foundation
import CoreData

// MARK: - Convenience
extension TokenEntity {
    // Create a TokenEntity with essential values
    static func create(
        id: UUID = UUID(),
        name: String,
        connectionStatus: Bool = false,
        isActivated: Bool = false,
        in context: NSManagedObjectContext
    ) -> TokenEntity {
        let entity = TokenEntity(context: context)
        entity.id = id
        entity.name = name
        entity.connectionStatus = connectionStatus
        entity.isActivated = isActivated
        entity.lastValidated = Date()
        return entity
    }
}
