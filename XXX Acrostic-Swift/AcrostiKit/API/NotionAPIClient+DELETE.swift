// API/NotionAPIClient+DELETE.swift
import Foundation

extension NotionAPIClient {
    /// Deletes (archives) a block by setting its `archived` property to true.
    /// - Parameter blockID: The identifier for the block to delete.
    /// - Returns: A NotionBlock representing the deleted (archived) block.
    public func deleteBlock(blockID: String) async throws -> NotionBlock {
        guard let url = URL(string: "\(baseURL)/blocks/\(blockID)") else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let deletedBlock = try decoder.decode(NotionBlock.self, from: data)
            return deletedBlock
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
}
