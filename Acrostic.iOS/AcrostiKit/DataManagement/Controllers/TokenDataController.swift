// AcrostiKit/DataManagement/Controllers/TokenDataController.swift
import Foundation
import CoreData
import Security

/// Manages all token-related data operations including secure storage
public final class TokenDataController {
    /// The shared singleton instance
    public static let shared = TokenDataController()
    
    // Key constants
    public let tokenServiceName = "com.acrostic.tokens"
    
    private init() {}
    
    // MARK: - Fetch Operations
    
    /// Fetches all stored tokens
    public func fetchTokens() -> [NotionToken] {
        do {
            let context = CoreDataStack.shared.viewContext
            
            // Using the new Token entity name
            let request = NSFetchRequest<NSManagedObject>(entityName: "Token")
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            
            let tokenEntities = try context.fetch(request)
            return tokenEntities.compactMap { entity -> NotionToken? in
                guard let id = entity.value(forKey: "id") as? UUID else {
                    return nil
                }
                
                // Get API token from keychain
                let apiToken = getSecureToken(for: id.uuidString) ?? ""
                
                return NotionToken(
                    id: id,
                    name: entity.value(forKey: "name") as? String ?? "",
                    apiToken: apiToken,
                    isConnected: entity.value(forKey: "connectionStatus") as? Bool ?? false,
                    isActivated: entity.value(forKey: "isActivated") as? Bool ?? false,
                    workspaceID: entity.value(forKey: "workspaceID") as? String,
                    workspaceName: entity.value(forKey: "workspaceName") as? String
                )
            }
        } catch {
            print("Error fetching tokens: \(error)")
            // Fallback to keychain-only tokens if Core Data fails
            return fetchTokensFromKeychain()
        }
    }
    
    /// Fallback method to fetch tokens directly from keychain if Core Data fails
    private func fetchTokensFromKeychain() -> [NotionToken] {
        // This is a simplified fallback approach - in a real app you'd
        // want a more robust solution for persistent token metadata
        var tokens: [NotionToken] = []
        
        // Get all keychain items matching our service
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenServiceName,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let items = result as? [[String: Any]] {
            for item in items {
                if let account = item[kSecAttrAccount as String] as? String,
                   let tokenUUID = UUID(uuidString: account),
                   let apiToken = getSecureToken(for: account) {
                    
                    // Create a basic token with the data we have
                    let token = NotionToken(
                        id: tokenUUID,
                        name: "Token \(account.prefix(8))",
                        apiToken: apiToken,
                        isConnected: false,
                        isActivated: false
                    )
                    
                    tokens.append(token)
                }
            }
        } else {
            print("Keychain query failed with status: \(status)")
        }
        
        return tokens
    }
    
    /// Fetches a specific token by ID
    public func fetchToken(id: UUID) -> NSManagedObject? {
        let context = CoreDataStack.shared.viewContext
        
        // First, ensure Token exists in the model
        let entityNames = context.persistentStoreCoordinator?.managedObjectModel.entities.map { $0.name } ?? []
        if !entityNames.contains("Token") {
            print("⚠️ Token not found in model, cannot fetch token")
            return nil
        }
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "Token")
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
    public func saveToken(name: String, apiToken: String) -> NSManagedObject? {
        let context = CoreDataStack.shared.viewContext
        
        // Check if Token exists in model
        let entityNames = context.persistentStoreCoordinator?.managedObjectModel.entities.map { $0.name } ?? []
        if !entityNames.contains("Token") {
            print("⚠️ Token not found in model, cannot save token")
            
            // Fallback: Store in keychain only
            let tokenUUID = UUID()
            storeSecureToken(apiToken, for: tokenUUID.uuidString)
            print("✅ Token stored in keychain only with ID: \(tokenUUID.uuidString)")
            return nil
        }
        
        // Create a new token entity
        guard let entityDescription = NSEntityDescription.entity(forEntityName: "Token", in: context) else {
            print("⚠️ Could not create Token entity description")
            return nil
        }
        
        let tokenEntity = NSManagedObject(entity: entityDescription, insertInto: context)
        tokenEntity.setValue(UUID(), forKey: "id")
        tokenEntity.setValue(name, forKey: "name")
        tokenEntity.setValue(false, forKey: "connectionStatus")
        tokenEntity.setValue(false, forKey: "isActivated")
        tokenEntity.setValue(Date(), forKey: "lastValidated")
        
        // Save the API token securely
        guard let id = tokenEntity.value(forKey: "id") as? UUID else {
            print("⚠️ Failed to get token ID")
            return nil
        }
        
        storeSecureToken(apiToken, for: id.uuidString)
        
        do {
            try context.save()
            return tokenEntity
        } catch {
            print("Error saving token: \(error)")
            
            // Fallback: Store in keychain only
            storeSecureToken(apiToken, for: id.uuidString)
            print("✅ Token stored in keychain only with ID: \(id.uuidString)")
            
            return nil
        }
    }
    
    /// Updates an existing token
    public func updateToken(id: UUID, name: String? = nil, isConnected: Bool? = nil,
                           isActivated: Bool? = nil, workspaceID: String? = nil,
                           workspaceName: String? = nil, apiToken: String? = nil) {
        let context = CoreDataStack.shared.viewContext
        
        // Check if Token exists in model
        let entityNames = context.persistentStoreCoordinator?.managedObjectModel.entities.map { $0.name } ?? []
        if !entityNames.contains("Token") {
            print("⚠️ Token not found in model, cannot update token")
            
            // Update keychain token if needed
            if let apiToken = apiToken {
                storeSecureToken(apiToken, for: id.uuidString)
                print("✅ Token updated in keychain only with ID: \(id.uuidString)")
            }
            return
        }
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "Token")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let token = try context.fetch(request).first {
                if let name = name {
                    token.setValue(name, forKey: "name")
                }
                
                if let isConnected = isConnected {
                    token.setValue(isConnected, forKey: "connectionStatus")
                }
                
                if let isActivated = isActivated {
                    token.setValue(isActivated, forKey: "isActivated")
                }
                
                if let workspaceID = workspaceID {
                    token.setValue(workspaceID, forKey: "workspaceID")
                }
                
                if let workspaceName = workspaceName {
                    token.setValue(workspaceName, forKey: "workspaceName")
                }
                
                token.setValue(Date(), forKey: "lastValidated")
                
                // Update API token if provided
                if let apiToken = apiToken {
                    storeSecureToken(apiToken, for: id.uuidString)
                }
                
                try context.save()
            } else {
                print("Token with ID \(id) not found for update")
                
                // If token not found in Core Data but apiToken provided, update keychain
                if let apiToken = apiToken {
                    storeSecureToken(apiToken, for: id.uuidString)
                    print("✅ Token updated in keychain only with ID: \(id.uuidString)")
                }
            }
        } catch {
            print("Error updating token: \(error)")
            
            // Fallback: Update keychain token if needed
            if let apiToken = apiToken {
                storeSecureToken(apiToken, for: id.uuidString)
                print("✅ Token updated in keychain only with ID: \(id.uuidString)")
            }
        }
    }
    
    /// Deletes a token
    public func deleteToken(id: UUID) {
        let context = CoreDataStack.shared.viewContext
        
        // Check if Token exists in model
        let entityNames = context.persistentStoreCoordinator?.managedObjectModel.entities.map { $0.name } ?? []
        if !entityNames.contains("Token") {
            print("⚠️ Token not found in model, deleting token from keychain only")
            removeSecureToken(for: id.uuidString)
            return
        }
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "Token")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let token = try context.fetch(request).first {
                // Remove the API token from keychain
                removeSecureToken(for: id.uuidString)
                
                // Delete the entity
                context.delete(token)
                try context.save()
            } else {
                print("Token with ID \(id) not found for deletion")
                // Still try to remove from keychain
                removeSecureToken(for: id.uuidString)
            }
        } catch {
            print("Error deleting token: \(error)")
            // Still try to remove from keychain
            removeSecureToken(for: id.uuidString)
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
