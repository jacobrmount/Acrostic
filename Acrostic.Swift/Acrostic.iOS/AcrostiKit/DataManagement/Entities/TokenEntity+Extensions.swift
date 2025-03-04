// NactionsKit/DataManagement/Entities/TokenEntity+UserExtensions.swift
import Foundation
import CoreData

// Replace the User+Extensions.swift functionality with TokenEntity extensions
// This extends the existing TokenEntity+Extensions.swift file with more methods
extension TokenEntity {
    // Convert TokenEntity to NotionToken with workspace info
    func toWorkspaceToken() -> NotionToken? {
        guard let id = self.id,
              let apiToken = TokenDataController.shared.getSecureToken(for: id.uuidString) else {
            return nil
        }
        
        return NotionToken(
            id: id,
            name: self.name ?? "Unknown",
            apiToken: apiToken,
            isConnected: self.connectionStatus,
            isActivated: self.isActivated,
            workspaceID: self.workspaceID,
            workspaceName: self.workspaceName
        )
    }
    
    // Create a TokenEntity from NotionToken - this can be used by UserDataController
    static func create(from token: NotionToken, in context: NSManagedObjectContext) -> TokenEntity {
        let tokenEntity = TokenEntity(context: context)
        tokenEntity.id = token.id
        tokenEntity.name = token.name
        tokenEntity.connectionStatus = token.isConnected
        tokenEntity.isActivated = token.isActivated
        tokenEntity.workspaceID = token.workspaceID
        tokenEntity.workspaceName = token.workspaceName
        tokenEntity.lastValidated = Date()
        
        // Store the API token in the keychain
        TokenDataController.shared.storeSecureToken(token.apiToken, for: token.id.uuidString)
        
        return tokenEntity
    }
    
    // Alternative method name for backward compatibility
    static func createFromWorkspaceToken(_ token: NotionToken, in context: NSManagedObjectContext) -> TokenEntity {
        return create(from: token, in: context)
    }
}
