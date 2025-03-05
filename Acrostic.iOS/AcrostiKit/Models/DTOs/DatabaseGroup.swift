// AcrostiKit/Models/DTOs/DatabaseGroup.swift
import Foundation

public struct DatabaseGroup: Identifiable {
    public let id: UUID
    public let tokenName: String
    public let tokenID: UUID
    public let databases: [DatabaseViewModelInternal]
    
    public init(id: UUID, tokenName: String, tokenID: UUID, databases: [DatabaseViewModelInternal]) {
        self.id = id
        self.tokenName = tokenName
        self.tokenID = tokenID
        self.databases = databases
    }
}
