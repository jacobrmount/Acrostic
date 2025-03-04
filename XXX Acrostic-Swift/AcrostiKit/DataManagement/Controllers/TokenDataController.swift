// NactionsKit/DataManagement/Controllers/TokenDataController.swift
import Foundation
import CoreData
import Security

/// Manages all token-related data operations including secure storage
public final class TokenDataController {
    /// The shared singleton instance
    public static let shared = TokenDataController()
    
    // Key constants
    public let tokenServiceName = "com.nactions.tokens"
    
    private init() {}
    
    // MARK: - Fetch Operations
    
    /// Fetches all stored tokens
    public func fetchTokens() -> [NotionToken] {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<TokenEntity> = TokenEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            let tokenEntities = try context.fetch(request)
            return tokenEntities.compactMap { entity -> NotionToken? in
                guard let id = entity.id else {
                    return nil
                }
                
                // Get API token from keychain
                let apiToken = getSecureToken(for: id.uuidString) ?? ""
                
                return NotionToken(
                    id: id,
                    name: entity.name ?? "",  // Unwrap optional
                    apiToken: apiToken,
                    isConnected: entity.connectionStatus,
                    isActivated: entity.isActivated,
                    workspaceID: entity.workspaceID,
                    workspaceName: entity.workspaceName
                )
            }
        } catch {
            print("Error fetching tokens: \(error)")
            return []
        }
    }
    
    /// Fetches a specific token by ID
    public func fetchToken(id: UUID) -> TokenEntity? {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<TokenEntity> = TokenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let token = try context.fetch(request).first
            return token
        } catch {
            print("Error fetching token with ID \(id): \(error)")
            return nil
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Saves a new token or updates an existing one
    @discardableResult
    public func saveToken(name: String, apiToken: String) -> TokenEntity? {
        let context = CoreDataStack.shared.viewContext
        
        // Create a new token entity
        let tokenEntity = TokenEntity(context: context)
        tokenEntity.id = UUID()
        tokenEntity.name = name
        tokenEntity.connectionStatus = false
        tokenEntity.isActivated = false
        tokenEntity.lastValidated = Date()
        
        // Save the API token securely
        storeSecureToken(apiToken, for: tokenEntity.id!.uuidString)
        
        do {
            try context.save()
            return tokenEntity
        } catch {
            print("Error saving token: \(error)")
            return nil
        }
    }
    
    /// Updates an existing token
    public func updateToken(id: UUID, name: String? = nil, isConnected: Bool? = nil,
                           isActivated: Bool? = nil, workspaceID: String? = nil,
                           workspaceName: String? = nil, apiToken: String? = nil) {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<TokenEntity> = TokenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let token = try context.fetch(request).first {
                if let name = name {
                    token.name = name
                }
                
                if let isConnected = isConnected {
                    token.connectionStatus = isConnected
                }
                
                if let isActivated = isActivated {
                    token.isActivated = isActivated
                }
                
                if let workspaceID = workspaceID {
                    token.workspaceID = workspaceID
                }
                
                if let workspaceName = workspaceName {
                    token.workspaceName = workspaceName
                }
                
                token.lastValidated = Date()
                
                // Update API token if provided
                if let apiToken = apiToken {
                    storeSecureToken(apiToken, for: id.uuidString)
                }
                
                try context.save()
            }
        } catch {
            print("Error updating token: \(error)")
        }
    }
    
    /// Deletes a token
    public func deleteToken(id: UUID) {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<TokenEntity> = TokenEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let token = try context.fetch(request).first {
                // Remove the API token from keychain
                removeSecureToken(for: id.uuidString)
                
                // Delete the entity
                context.delete(token)
                try context.save()
            }
        } catch {
            print("Error deleting token: \(error)")
        }
    }
    
    // MARK: - Token Validation
    
    /// Validates a token with the Notion API
    public func validateToken(_ token: NotionToken) async -> Bool {
        do {
            let client = token.createAPIClient()
            let _ = try await client.retrieveBotUser()
            
            // Update token status
            updateToken(
                id: token.id,
                name: token.name,  // Added name parameter
                isConnected: true,
                isActivated: token.isActivated
            )
            
            return true
        } catch {
            // Update token status
            updateToken(
                id: token.id,
                name: token.name,  // Added name parameter
                isConnected: false,
                isActivated: false
            )
            
            print("Token validation failed: \(error)")
            return false
        }
    }
    
    /// Validates all stored tokens
    public func validateAllTokens() async -> [UUID] {
        let tokens = fetchTokens()
        var invalidTokenIDs: [UUID] = []
        
        for token in tokens {
            let isValid = await validateToken(token)
            if !isValid {
                invalidTokenIDs.append(token.id)
            }
        }
        
        return invalidTokenIDs
    }
    
    // MARK: - Keychain Operations
    
    /// Stores a token securely in the keychain
    public func storeSecureToken(_ token: String, for identifier: String) {
        let keychainItem = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenServiceName,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: token.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ] as [String: Any]
        
        // First, delete any existing item
        SecItemDelete(keychainItem as CFDictionary)
        
        // Then add the new item
        let status = SecItemAdd(keychainItem as CFDictionary, nil)
        if status != errSecSuccess {
            print("Error storing token in keychain: \(status)")
        }
    }
    
    /// Retrieves a token from the keychain
    public func getSecureToken(for identifier: String) -> String? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenServiceName,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    /// Removes a token from the keychain
    public func removeSecureToken(for identifier: String) {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenServiceName,
            kSecAttrAccount as String: identifier
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Export/Import
    
    /// Exports tokens to a secure format (for backup)
    public func exportTokens() -> Data? {
        let tokens = fetchTokens()
        
        // Create a secure representation for export
        let tokenExports = tokens.map { token -> [String: Any] in
            return [
                "id": token.id.uuidString,
                "name": token.name,
                "apiToken": token.apiToken,
                "workspaceID": token.workspaceID ?? "",
                "workspaceName": token.workspaceName ?? ""
            ]
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: tokenExports, options: [.prettyPrinted])
            return data
        } catch {
            print("Error exporting tokens: \(error)")
            return nil
        }
    }
    
    /// Imports tokens from a backup
    public func importTokens(from data: Data) -> Bool {
        do {
            guard let tokenImports = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return false
            }
            
            for tokenData in tokenImports {
                guard let idString = tokenData["id"] as? String,
                      let name = tokenData["name"] as? String,
                      let apiToken = tokenData["apiToken"] as? String else {
                    continue
                }
                
                let workspaceID = tokenData["workspaceID"] as? String
                let workspaceName = tokenData["workspaceName"] as? String
                
                // Create a new token or update existing one
                if let id = UUID(uuidString: idString),
                   fetchToken(id: id) != nil {
                    // Update existing token
                    updateToken(
                        id: id,
                        name: name,
                        workspaceID: workspaceID,
                        workspaceName: workspaceName,
                        apiToken: apiToken
                    )
                } else {
                    // Create new token
                    let _ = saveToken(name: name, apiToken: apiToken)
                }
            }
            
            return true
        } catch {
            print("Error importing tokens: \(error)")
            return false
        }
    }
}
