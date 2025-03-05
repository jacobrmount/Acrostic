// AcrostiKit/Data/Controllers/TokenController.swift
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
    public func fetchTokens() -> [TokenEntity] {
        let context = CoreDataStack.shared.viewContext
        
        // Diagnostic logging to understand the Core Data model
        let entityNames = context.persistentStoreCoordinator?.managedObjectModel.entities.map { $0.name ?? "unnamed" } ?? []
        print("📋 Available entities in Core Data model: \(entityNames)")
        
        // Check if any token-related entity exists
        let tokenEntityNames = entityNames.filter { $0.lowercased().contains("token") }
        print("🔍 Token-related entities found: \(tokenEntityNames)")
        
        // If no token entities found, fallback to keychain
        if tokenEntityNames.isEmpty {
            print("❌ No token entities found in the model")
            return fetchTokensFromKeychain()
        }
        
        // Try each potential token entity name
        for entityName in tokenEntityNames {
            do {
                let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                request.sortDescriptors = [NSSortDescriptor(key: "workspaceName", ascending: true)]
                
                let tokenEntities = try context.fetch(request)
                print("✅ Successfully fetched \(tokenEntities.count) tokens from entity: \(entityName)")
                
                // Convert fetched NSManagedObjects to TokenEntity instances
                return tokenEntities.compactMap { entity -> TokenEntity? in
                    guard let id = entity.value(forKey: "id") as? UUID else {
                        return nil
                    }
                    
                    // Get API token from keychain
                    let apiToken = self.getSecureToken(for: id.uuidString) ?? ""
                    
                    if let tokenObject = entity as? TokenEntity {
                        tokenObject.apiToken = apiToken
                        return tokenObject
                    }
                    return nil
                }
            } catch {
                print("❌ Error fetching from entity \(entityName): \(error)")
            }
        }
        
        // If all attempts fail, fallback to keychain
        print("❌ Could not fetch tokens from any known entity")
        return fetchTokensFromKeychain()
    }
    
    /// Fallback method to fetch tokens directly from keychain if Core Data fails
    private func fetchTokensFromKeychain() -> [TokenEntity] {
        var tokens: [TokenEntity] = []
        
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
                    
                    // Create a basic token with the data we have using the shared context
                    let token = TokenEntity(context: CoreDataStack.shared.viewContext)
                    token.id = tokenUUID
                    token.workspaceName = "Unknown"
                    token.apiToken = apiToken
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
        
        // Add diagnostic logging
        print("🔍 Checking Core Data Stack Configuration")
        print("Persistent Container: \(CoreDataStack.shared.persistentContainer)")
        print("Persistent Store Descriptions: \(CoreDataStack.shared.persistentContainer.persistentStoreDescriptions)")
        
        // Check if persistent stores are loaded
        let stores = CoreDataStack.shared.persistentContainer.persistentStoreCoordinator.persistentStores
        if stores.isEmpty {
            print("❌ NO PERSISTENT STORES LOADED")
            
            // Attempt to diagnose and recover
            do {
                // Try to add a store programmatically
                let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("AcrosticDataModel.sqlite")
                
                try CoreDataStack.shared.persistentContainer.persistentStoreCoordinator.addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: storeURL,
                    options: [
                        NSMigratePersistentStoresAutomaticallyOption: true,
                        NSInferMappingModelAutomaticallyOption: true
                    ]
                )
            } catch {
                print("❌ Failed to add persistent store: \(error)")
                return nil
            }
        }
        
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
        tokenEntity.setValue(name, forKey: "workspaceName")
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
                if let workspaceName = workspaceName {
                    token.setValue(workspaceName, forKey: "workspaceName")
                } else if let name = name {
                    token.setValue(name, forKey: "workspaceName")
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
        
        // Check if Token exists in the model
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
                removeSecureToken(for: id.uuidString)
            }
        } catch {
            print("Error deleting token: \(error)")
            removeSecureToken(for: id.uuidString)
        }
    }
    
    // MARK: - Token Validation
    
    /// Validates a token with the Notion API
    public func validateToken(_ token: TokenEntity) async -> Bool {
        guard let id = token.id else {
            print("Token id is nil")
            return false
        }
        
        do {
            // Instead of token.createAPIClient(), use NotionAPIClient initializer with token.apiToken.
            // Revert to retrieveBotUser() since NotionAPIClient has that member.
            let client = NotionAPIClient(token: token.apiToken ?? "")
            _ = try await client.search(requestBody: [:])
            
            // Update token status using workspaceName instead of name
            updateToken(
                id: id,
                name: token.workspaceName ?? "Unknown",
                isConnected: true,
                isActivated: token.isActivated
            )
            
            return true
        } catch {
            updateToken(
                id: id,
                name: token.workspaceName ?? "Unknown",
                isConnected: false,
                isActivated: false
            )
            
            print("Token validation failed: \(error)")
            return false
        }
    }
    
    public func validateAllTokens() async -> [UUID] {
        let tokens = fetchTokens()
        var invalidTokenIDs: [UUID] = []
        
        for token in tokens {
            guard let tokenId = token.id else {
                print("Token ID is nil, skipping...")
                continue
            }
            
            let isValid = await validateToken(token)
            if !isValid {
                invalidTokenIDs.append(tokenId)
            }
        }
        
        return invalidTokenIDs
    }
    
    public func updateTokenWithErrorHandling(
        id: UUID,
        name: String? = nil,
        isConnected: Bool? = nil,
        isActivated: Bool? = nil,
        workspaceID: String? = nil,
        workspaceName: String? = nil,
        apiToken: String? = nil
    ) throws {
        let context = CoreDataStack.shared.viewContext
        let request = NSFetchRequest<TokenEntity>(entityName: "Token")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            // Fetch the token, throwing an error if not found
            guard let token = try context.fetch(request).first else {
                let error = NSError(
                    domain: "TokenDataController",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Token not found with ID: \(id)"]
                )
                throw error
            }
            
            // Update token properties with provided values
            if let isActivated = isActivated {
                token.isActivated = isActivated
            }
            
            if let name = name {
                token.workspaceName = name
            }
            
            if let isConnected = isConnected {
                token.connectionStatus = isConnected
            }
            
            if let workspaceID = workspaceID {
                token.workspaceID = workspaceID
            }
            
            if let workspaceName = workspaceName {
                token.workspaceName = workspaceName
            }
            
            if let apiToken = apiToken {
                // Note: In a real-world scenario, you might want to use a secure method to store API tokens
                token.apiToken = apiToken
            }
            
            // Attempt to save changes
            try context.save()
            
            print("✅ Token updated successfully: \(id)")
        } catch {
            // Log the specific error and re-throw
            print("🚨 Error updating token: \(error)")
            throw error
        }
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
                "id": token.id?.uuidString ?? "unknown",
                "name": token.workspaceName ?? "Unknown",
                "apiToken": token.apiToken ?? "",
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
