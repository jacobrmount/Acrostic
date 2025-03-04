// NactionsKit/DataManagement/Entities/DatabaseEntity+Extensions.swift
import Foundation
import CoreData

// Forward declare to resolve ambiguity
public struct DatabaseViewModelInternal: Identifiable {
    public let id: String
    public let title: String
    public let tokenID: UUID
    public let tokenName: String
    public let isSelected: Bool
    public let lastUpdated: Date
    
    public init(id: String, title: String, tokenID: UUID, tokenName: String, isSelected: Bool, lastUpdated: Date) {
        self.id = id
        self.title = title
        self.tokenID = tokenID
        self.tokenName = tokenName
        self.isSelected = isSelected
        self.lastUpdated = lastUpdated
    }
}

public extension DatabaseEntity {
    /// Converts this entity to a DatabaseViewModel for UI display
    func toDatabaseViewModel() -> DatabaseViewModelInternal {
        return DatabaseViewModelInternal(
            id: self.id ?? "",
            title: self.title ?? "Untitled",
            tokenID: self.token?.id ?? UUID(),
            tokenName: self.token?.name ?? "Unknown",
            isSelected: self.widgetEnabled,
            lastUpdated: self.lastSyncTiime ?? Date()  // Changed from lastSyncTime to lastSyncTiime
        )
    }
    
    /// Updates this entity from a NotionDatabase model
    func update(from database: NotionDatabase) {
        self.id = database.id
        self.title = database.title?.first?.plainText ?? "Untitled"
        self.databaseDescription = database.description?.first?.plainText
        self.createdTime = database.createdTime
        self.lastEditedTime = database.lastEditedTime
        self.url = database.url
        self.lastSyncTiime = Date()  // Changed from lastSyncTime to lastSyncTiime
    }
}

// To avoid the redeclaration error: use DatabaseViewModelInternal directly
// instead of redefining DatabaseViewModel
