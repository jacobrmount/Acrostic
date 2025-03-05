// AcrostiKit/Domain/Services/TokenService.swift
import Foundation
import Combine

public class TokenService: ObservableObject {
    @Published public var tokens: [TokenEntity] = []
    @Published public var activatedTokens: [TokenEntity] = []
    @Published public var errorMessage: String? = nil
    @Published public var isLoading: Bool = false
    @Published public var invalidTokens: [TokenEntity] = []
    
    public static let shared = TokenService()
    
    private init() {
        loadTokens()
    }
    
    public func refreshAllTokens() async {
        await MainActor.run {
            isLoading = true
            invalidTokens = []
        }
        
        let invalidTokenIds = await TokenDataController.shared.validateAllTokens()
        
        await MainActor.run {
            // Reload tokens from storage
            loadTokens()
            
            // Mark invalid tokens by unwrapping token.id
            self.invalidTokens = self.tokens.filter {
                if let id = $0.id {
                    return invalidTokenIds.contains(id)
                }
                return false
            }
            self.isLoading = false
        }
    }
    
    public func loadTokens() {
        var storedTokens: [TokenEntity] = []
        
        // Get tokens from DocumentStorageManager
        storedTokens = DocumentStorageManager.shared.loadTokens()
        
        // If empty, fall back to legacy method
        if storedTokens.isEmpty {
            print("Falling back to legacy token loading method")
            let legacyTokens = TokenDataController.shared.fetchTokens()
            // Migrate if needed
            if !legacyTokens.isEmpty {
                self.tokens = legacyTokens
                self.activatedTokens = self.tokens.filter { $0.isActivated }
                return
            }
        } else {
            self.tokens = storedTokens
            self.activatedTokens = self.tokens.filter { $0.isActivated }
            return
        }
        
        // If we got here, both methods failed - start with empty arrays
        self.tokens = []
        self.activatedTokens = []
        
        // Log for debugging
        print("Loaded \(tokens.count) tokens from storage")
        for token in tokens {
            let tokenName = token.workspaceName ?? "Unknown"
            let tokenIdString = token.id?.uuidString ?? "nil"
            print("- Token: \(tokenName) (ID: \(tokenIdString))")
        }
    }
    
    public func saveToken(name: String, apiToken: String) {
        let token = TokenEntity()
        token.id = UUID()
        token.workspaceName = name
        token.apiToken = apiToken
        token.connectionStatus = false
        token.isActivated = false
        
        do {
            try DocumentStorageManager.shared.saveToken(token)
            loadTokens()
            objectWillChange.send()
        } catch {
            print("Error saving token: \(error)")
            // Fallback to legacy method if the new storage manager fails
            let _ = TokenDataController.shared.saveToken(name: name, apiToken: apiToken)
            loadTokens()
            objectWillChange.send()
        }
    }
    
    public func updateTokenCredentials(for token: TokenEntity, newApiToken: String) {
        guard let id = token.id else {
            print("Token id is nil, cannot update credentials")
            return
        }
        
        // Try the storage manager first
        do {
            let updatedToken = token
            updatedToken.apiToken = newApiToken
            try DocumentStorageManager.shared.updateToken(updatedToken)
            loadTokens()
            objectWillChange.send()
        } catch {
            print("Error updating token with storage manager: \(error)")
            // Fallback to legacy method
            TokenDataController.shared.updateToken(
                id: id,
                name: token.workspaceName ?? "",
                apiToken: newApiToken
            )
            loadTokens()
            objectWillChange.send()
        }
    }
    
    public func toggleTokenActivation(token: TokenEntity) {
        // Robust guard against nil token ID
        guard let id = token.id else {
            print("🚨 Critical Error: Token ID is nil, cannot toggle activation")
            errorMessage = "Invalid token: Unable to toggle activation"
            return
        }
        
        // Create a copy to prevent direct mutation of the original
        let updatedToken = token
        updatedToken.isActivated = !token.isActivated
        
        // Comprehensive error handling with multiple fallback strategies
        do {
            // First, attempt to save via DocumentStorageManager
            try DocumentStorageManager.shared.updateToken(updatedToken)
            
            // If successful, reload and update UI state immediately
            loadTokens()
            activatedTokens = tokens.filter { $0.isActivated }
            objectWillChange.send()
            
            print("✅ Token activation successfully updated via storage manager")
        } catch {
            print("❌ Storage manager update failed: \(error)")
            
            // Fallback Strategy 1: Core Data Update
            // Modify TokenDataController to throw errors
            do {
                // Modify updateToken method to throw errors if update fails
                try TokenDataController.shared.updateTokenWithErrorHandling(
                    id: id,
                    isActivated: updatedToken.isActivated
                )
                
                loadTokens()
                activatedTokens = tokens.filter { $0.isActivated }
                objectWillChange.send()
                
                print("🔄 Fallback: Token updated via Core Data")
            } catch {
                print("🚨 Core Data fallback failed: \(error)")
                
                // Fallback Strategy 2: In-memory update with error logging
                if let index = tokens.firstIndex(where: { $0.id == id }) {
                    tokens[index].isActivated = updatedToken.isActivated
                    activatedTokens = tokens.filter { $0.isActivated }
                    objectWillChange.send()
                    
                    errorMessage = "Partial update: Token activated in-memory due to storage failure"
                }
            }
        }
    }
    
    public func deleteToken(_ token: TokenEntity) {
        guard let id = token.id else {
            print("Token id is nil, cannot delete token")
            return
        }
        
        // Try the storage manager first
        do {
            try DocumentStorageManager.shared.deleteToken(id)
            loadTokens()
            objectWillChange.send()
        } catch {
            print("Error deleting token with storage manager: \(error)")
            // Fallback to legacy method
            TokenDataController.shared.deleteToken(id: id)
            loadTokens()
            objectWillChange.send()
        }
    }
    
    public func makePreviewManager() -> TokenService {
        let previewManager = TokenService()
        
        let token1 = TokenEntity()
        token1.id = UUID()
        token1.workspaceName = "Work"
        token1.apiToken = "secret_123"
        token1.isActivated = true
        
        let token2 = TokenEntity()
        token2.id = UUID()
        token2.workspaceName = "Personal"
        token2.apiToken = "secret_456"
        token2.isActivated = false
        
        previewManager.tokens = [token1, token2]
        previewManager.activatedTokens = previewManager.tokens.filter { $0.isActivated }
        return previewManager
    }
    
    /// Synchronizes storage between different locations
    public func syncStorage() {
        // Get user's preferred storage location
        let defaults = UserDefaults.standard
        let preferredLocation = defaults.string(forKey: "storage_location_preference") ?? "icloud"
        
        // Perform sync based on preference
        if preferredLocation == "icloud" {
            migrateToiCloud()
        } else {
            migrateToLocal()
        }
    }
    
    /// Migrates data from local storage to iCloud
    private func migrateToiCloud() {
        do {
            try DocumentStorageManager.shared.migrateToiCloud()
            loadTokens() // Reload from the new location
            objectWillChange.send()
        } catch {
            print("Error migrating to iCloud: \(error)")
            errorMessage = "Failed to migrate data to iCloud: \(error.localizedDescription)"
        }
    }
    
    /// Migrates data from iCloud to local storage
    private func migrateToLocal() {
        do {
            try DocumentStorageManager.shared.migrateToLocal()
            loadTokens() // Reload from the new location
            objectWillChange.send()
        } catch {
            print("Error migrating to local storage: \(error)")
            errorMessage = "Failed to migrate data to local storage: \(error.localizedDescription)"
        }
    }
    
    // Add this method to TokenService.swift
    public func validateToken(_ token: TokenEntity) async {
        _ = await TokenDataController.shared.validateToken(token)
        
        await MainActor.run {
            loadTokens()
            self.objectWillChange.send()
        }
    }
    
    struct TokenViewModel: Identifiable {
        let id: UUID
        let objectID: NSObject
        let workspaceName: String
        let isConnected: Bool
        let isActivated: Bool
        
        init(from entity: TokenEntity) {
            self.id = entity.id ?? UUID()
            self.objectID = entity.objectID
            self.workspaceName = entity.workspaceName ?? "Unknown"
            self.isConnected = entity.connectionStatus
            self.isActivated = entity.isActivated
        }
    }
}

extension TokenService {
    public func getSecureToken(for identifier: String) -> String? {
        return TokenDataController.shared.getSecureToken(for: identifier)
    }
}
