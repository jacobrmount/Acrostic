// Models/NotionToken.swift
import Foundation

/// A lightweight struct for representing a Notion token
/// Used for API operations and passing data between components
public struct NotionToken: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var apiToken: String
    public var isConnected: Bool
    public var isActivated: Bool
    public var workspaceID: String?
    public var workspaceName: String?
    
    public init(id: UUID, name: String, apiToken: String, isConnected: Bool, isActivated: Bool = false, workspaceID: String? = nil, workspaceName: String? = nil) {
        self.id = id
        self.name = name
        self.apiToken = apiToken
        self.isConnected = isConnected
        self.isActivated = isActivated
        self.workspaceID = workspaceID
        self.workspaceName = workspaceName
    }
    
    /// Creates a NotionAPIClient using this token
    public func createAPIClient() -> NotionAPIClient {
        return NotionAPIClient(token: self.apiToken)
    }
}

// MARK: - Factory methods for token-related operations
extension NotionToken {
    /// Fetches available databases for this token
    public func fetchDatabases() async throws -> [NotionDatabase] {
        let client = self.createAPIClient()
        
        // Create a search filter for databases
        let filter = NotionSearchFilter()
        filter.property = "object"
        filter.value = "database"
        
        // Search for databases
        let searchResults = try await client.searchByTitle(
            filter: filter,
            pageSize: 100
        )
        
        // Fetch full database details for each result
        var databases: [NotionDatabase] = []
        
        for result in searchResults.results where result.object == "database" {
            do {
                // Using the correct parameter name
                let database = try await client.retrieveDatabase(databaseID: result.id)
                databases.append(database)
            } catch {
                print("Error fetching database \(result.id): \(error)")
                // Continue with other databases even if one fails
            }
        }
        
        return databases
    }
    
    /// Fetches pages from a specific database
    public func fetchPages(from databaseID: String) async throws -> [NotionPage] {
        let client = self.createAPIClient()
        
        // Create a query request
        let request = NotionQueryDatabaseRequest(pageSize: 100)
        
        // Query the database
        let response = try await client.queryDatabase(databaseID: databaseID, requestBody: request)
        
        // Fetch full page details for each result
        var pages: [NotionPage] = []
        
        for result in response.results where result.object == "page" {
            do {
                // Using the correct parameter name
                let page = try await client.retrievePage(pageID: result.id)
                pages.append(page)
            } catch {
                print("Error fetching page \(result.id): \(error)")
                // Continue with other pages even if one fails
            }
        }
        
        return pages
    }
    
    /// Fetches the current bot user info
    public func fetchBotUser() async throws -> NotionUser {
        let client = self.createAPIClient()
        return try await client.retrieveBotUser()
    }
}
