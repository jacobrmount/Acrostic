// AcrostiKit/Models//Core/FileMetadata.swift
import Foundation

public enum FileType {
    case page
    case database
}

public struct FileMetadata: Identifiable {
    public let id: String
    public let title: String
    public let type: FileType
    public let tokenID: UUID
    public let isSelected: Bool
    
    public init(id: String, title: String, type: FileType, tokenID: UUID, isSelected: Bool) {
        self.id = id
        self.title = title
        self.type = type
        self.tokenID = tokenID
        self.isSelected = isSelected
    }
}
