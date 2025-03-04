// API/NotionAPIClient+POST.swift
import Foundation

extension NotionAPIClient {
    
    // MARK: - Search by Title
    public func searchByTitle(query: String? = nil,
                              sort: NotionSearchSort? = nil,
                              filter: NotionSearchFilter? = nil,
                              startCursor: String? = nil,
                              pageSize: Int? = nil) async throws -> NotionSearchResponse {
        guard let url = URL(string: "\(baseURL)/search") else {
            throw NotionAPIError.invalidURL
        }
        
        var bodyDict: [String: Any] = [:]
        if let query = query { bodyDict["query"] = query }
        if let sort = sort { bodyDict["sort"] = sort.dictionary }
        if let filter = filter { bodyDict["filter"] = filter.dictionaryRepresentation }
        if let startCursor = startCursor { bodyDict["start_cursor"] = startCursor }
        if let pageSize = pageSize { bodyDict["page_size"] = pageSize }
        
        let jsonData = try JSONSerialization.data(withJSONObject: bodyDict)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let searchResponse = try decoder.decode(NotionSearchResponse.self, from: data)
            return searchResponse
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
    
    // MARK: - Query a Database
    public func queryDatabase(databaseID: String, requestBody: NotionQueryDatabaseRequest) async throws -> NotionQueryDatabaseResponse {
        guard let url = URL(string: "\(baseURL)/databases/\(databaseID)/query") else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let queryResponse = try decoder.decode(NotionQueryDatabaseResponse.self, from: data)
            return queryResponse
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
    
    // MARK: - Create a Page
    public func createPage(requestBody: NotionCreatePageRequest) async throws -> NotionPage {
        guard let url = URL(string: "\(baseURL)/pages") else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let page = try decoder.decode(NotionPage.self, from: data)
            return page
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
    
    // MARK: - Create a Database
    public func createDatabase(requestBody: NotionCreateDatabaseRequest) async throws -> NotionDatabase {
        guard let url = URL(string: "\(baseURL)/databases") else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let database = try decoder.decode(NotionDatabase.self, from: data)
            return database
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
    
    // MARK: - Create a Comment
    public func createComment(requestBody: NotionCreateCommentRequest) async throws -> NotionComment {
        guard let url = URL(string: "\(baseURL)/comments") else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let comment = try decoder.decode(NotionComment.self, from: data)
            return comment
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
    
    // MARK: - Create a Token
    /// Creates an OAuth token for authenticating with Notion.
    /// - Parameter requestBody: A NotionCreateTokenRequest containing the OAuth code, grant type, and redirect URI.
    /// - Returns: A NotionCreateTokenResponse containing the access token and related info.
    public func createToken(requestBody: NotionCreateTokenRequest) async throws -> NotionCreateTokenResponse {
        guard let url = URL(string: "\(baseURL)/oauth/token") else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Use Basic authentication for OAuth token creation.
        request.addValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let tokenResponse = try decoder.decode(NotionCreateTokenResponse.self, from: data)
            return tokenResponse
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
}
