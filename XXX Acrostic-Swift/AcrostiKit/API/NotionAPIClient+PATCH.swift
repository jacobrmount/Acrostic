// API/NotionAPIClient+PATCH.swift
import Foundation

extension NotionAPIClient {
    
    // MARK: - Update Database
    /// Updates a database's title, description, properties, cover, or icon.
    /// - Parameters:
    ///   - databaseID: The identifier for the database to update.
    ///   - requestBody: A NotionUpdateDatabaseRequest containing the fields to update.
    /// - Returns: The updated NotionDatabase object.
    public func updateDatabase(databaseID: String, requestBody: NotionUpdateDatabaseRequest) async throws -> NotionDatabase {
        guard let url = URL(string: "\(baseURL)/databases/\(databaseID)") else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let updatedDatabase = try decoder.decode(NotionDatabase.self, from: data)
            return updatedDatabase
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
    
    // MARK: - Update Block
    /// Updates a block's content based on the block type.
    /// - Parameters:
    ///   - blockID: The identifier for the block to update.
    ///   - requestBody: A NotionUpdateBlockRequest containing the fields to update.
    /// - Returns: The updated NotionBlock object.
    public func updateBlock(blockID: String, requestBody: NotionUpdateBlockRequest) async throws -> NotionBlock {
        guard let url = URL(string: "\(baseURL)/blocks/\(blockID)") else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let block = try decoder.decode(NotionBlock.self, from: data)
            return block
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
    
    // MARK: - Append Block Children
    /// Appends new children blocks to the parent block specified.
    /// - Parameters:
    ///   - blockID: The identifier for the parent block.
    ///   - requestBody: A NotionAppendBlockChildrenRequest object containing the new children blocks and an optional "after" parameter.
    /// - Returns: A NotionBlockChildrenResponse containing the newly created children blocks.
    public func appendBlockChildren(blockID: String, requestBody: NotionAppendBlockChildrenRequest) async throws -> NotionBlockChildrenResponse {
        guard let url = URL(string: "\(baseURL)/blocks/\(blockID)/children") else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let childrenResponse = try decoder.decode(NotionBlockChildrenResponse.self, from: data)
            return childrenResponse
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
}
