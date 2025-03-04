// NactionsKit/BusinessLogic/TokenService.swift
import Foundation
import Combine

public class TokenService: ObservableObject {
    @Published public var tokens: [NotionToken] = []
    @Published public var activatedTokens: [NotionToken] = []
    @Published public var errorMessage: String? = nil
    @Published public var isLoading: Bool = false
    @Published public var invalidTokens: [NotionToken] = []
    
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
            
            // Mark invalid tokens
            self.invalidTokens = self.tokens.filter { invalidTokenIds.contains($0.id) }
            self.isLoading = false
        }
    }
    
    public func loadTokens() {
        let storedTokens = TokenDataController.shared.fetchTokens()
        self.tokens = storedTokens
        self.activatedTokens = storedTokens.filter { $0.isActivated }
        
        // Log for debugging
        print("Loaded \(storedTokens.count) tokens from storage")
        for token in storedTokens {
            print("- Token: \(token.name) (ID: \(token.id))")
        }
    }
    
    public func validateToken(_ token: NotionToken) async {
        // Store the result but use underscore to silence the warning
        _ = await TokenDataController.shared.validateToken(token)
        
        await MainActor.run {
            // Reload tokens to get updated state
            loadTokens()
            self.objectWillChange.send()
        }
    }
    
    public func saveToken(name: String, apiToken: String) {
        let _ = TokenDataController.shared.saveToken(name: name, apiToken: apiToken)
        loadTokens()
        objectWillChange.send()
    }
    
    public func updateTokenCredentials(for token: NotionToken, newApiToken: String) {
        NactionsKit.TokenDataController.shared.updateToken(
            id: token.id,
            name: token.name,
            apiToken: newApiToken
        )
        loadTokens()
        objectWillChange.send()
    }
    
    public func toggleTokenActivation(token: NotionToken) {
        NactionsKit.TokenDataController.shared.updateToken(
            id: token.id,
            name: token.name,
            isActivated: !token.isActivated
        )
        loadTokens()
        objectWillChange.send()
    }
    
    public func deleteToken(_ token: NotionToken) {
        NactionsKit.TokenDataController.shared.deleteToken(id: token.id)
        loadTokens()
        objectWillChange.send()
    }
    
    public func makePreviewManager() -> TokenService {
        let previewManager = TokenService()
        previewManager.tokens = [
            NotionToken(id: UUID(), name: "Work", apiToken: "secret_123", isConnected: true, isActivated: true),
            NotionToken(id: UUID(), name: "Personal", apiToken: "secret_456", isConnected: true, isActivated: false)
        ]
        previewManager.activatedTokens = previewManager.tokens.filter { $0.isActivated }
        return previewManager
    }
}
