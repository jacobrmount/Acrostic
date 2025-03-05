// AcrostiKit/Models/DTOs/DatabaseDTO.swift
import Foundation

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
