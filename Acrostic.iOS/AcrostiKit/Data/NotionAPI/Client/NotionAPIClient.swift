// AcrostiKit/BusinessLogic/NotionAPIClient.swift
import Foundation
import CoreData

public class NotionAPIClient {
    internal let baseURL = "https://api.notion.com/v1"
    internal let token: String
    internal let session: URLSession

    public init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }
    
    /// Query a Notion database
    public func queryDatabase(databaseID: String, requestBody: NotionQueryDatabaseRequest) async throws -> NotionQueryDatabaseResponse {
        let url = URL(string: "\(baseURL)/databases/\(databaseID)/query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode request body
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        
        return try decoder.decode(NotionQueryDatabaseResponse.self, from: data)
    }
    
    /// Search Notion content
    public func search(requestBody: [String: Any]) async throws -> NotionSearchResponse {
        let url = URL(string: "\(baseURL)/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"  // Ensure this is POST, not GET
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert dictionary to JSON data
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        
        // Add debug logging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Notion API Response: \(jsonString)")
        }
        
        return try decoder.decode(NotionSearchResponse.self, from: data)
    }
    
    /// Validates an HTTP response.
    internal func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NotionAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if let errorResponse: NotionErrorResponse = try? decoder.decode(NotionErrorResponse.self, from: data) {
                throw NotionAPIError.httpError(statusCode: http.statusCode,
                                               message: errorResponse.message ?? "Unknown error",
                                               code: errorResponse.code)
            }
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NotionAPIError.httpError(statusCode: http.statusCode,
                                           message: message,
                                           code: nil as String?)
        }
    }
        
    internal var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Expected date string to be ISO8601-formatted.")
        }
        return decoder
    }
    
    /// Retrieves block children from Notion API
    public func retrieveBlockChildren(blockID: String, startCursor: String? = nil, pageSize: Int? = nil) async throws -> NotionBlockChildrenResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/blocks/\(blockID)/children")!
        
        var queryItems: [URLQueryItem] = []
        if let startCursor = startCursor {
            queryItems.append(URLQueryItem(name: "start_cursor", value: startCursor))
        }
        if let pageSize = pageSize {
            queryItems.append(URLQueryItem(name: "page_size", value: "\(pageSize)"))
        }
        urlComponents.queryItems = queryItems
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        
        return try decoder.decode(NotionBlockChildrenResponse.self, from: data)
    }
    
    /// Fetches and stores all pages from a database
    public func fetchAndStoreDatabasePages(
        databaseID: String,
        tokenID: UUID,
        context: NSManagedObjectContext,
        maxItems: Int = .max
    ) async throws -> Int {
        var processor = DefaultPaginatedProcessor<NotionPage>(maxItems: maxItems) { pages in
            let queryProcessor = DatabaseQueryProcessor(
                context: context,
                databaseID: databaseID,
                tokenID: tokenID,
                maxItems: maxItems
            )
            _ = queryProcessor.process(results: pages)
        }
        
        let request = NotionQueryDatabaseRequest.create(pageSize: 100)
        
        try await queryDatabaseWithPagination(
            databaseID: databaseID,
            request: request,
            processor: &processor
        )
        
        return processor.getItems().count
    }

    /// Searches for and stores all databases
    public func fetchAndStoreDatabases(
        tokenID: UUID,
        context: NSManagedObjectContext,
        maxItems: Int = .max
    ) async throws -> [NotionDatabase] {
        var processor = DefaultPaginatedProcessor<NotionObject>(maxItems: maxItems) { objects in
            let searchProcessor = DatabaseSearchProcessor(
                context: context,
                tokenID: tokenID,
                maxItems: maxItems
            )
            _ = searchProcessor.process(results: objects)
        }
        
        try await searchWithPagination(
            filter: nil,
            pageSize: 100,
            processor: &processor
        )
        
        return processor.getItems().compactMap { $0 as? NotionDatabase }
    }
    
    /// Fetches and stores all blocks for a page
    public func fetchAndStorePageBlocks(
        pageID: String,
        context: NSManagedObjectContext,
        maxItems: Int = .max
    ) async throws -> [NotionBlock] {
        var processor = BlockChildrenProcessor(
            context: context,
            parentPageID: pageID,
            maxItems: maxItems
        )
        
        try await processPaginatedRequest(
            initialRequest: {
                try await self.retrieveBlockChildren(blockID: pageID)
            },
            nextPageRequest: { nextCursor in
                try await self.retrieveBlockChildren(blockID: pageID, startCursor: nextCursor)
            },
            getResults: { $0.results },
            getNextCursor: { $0.nextCursor },
            hasMore: { $0.hasMore },
            processor: &processor
        )
        
        return processor.getBlocks()
    }
}

extension NotionAPIClient {
    /// Fetches only the minimal file metadata needed for display
    public func fetchFileMetadata(forTokenID tokenID: UUID) async throws -> [FileMetadata] {
        // Create a search request for both databases and pages
        let requestBody: [String: Any] = [
            // No filters - get both pages and databases
            "page_size": 100
        ]
        
        // Call the search method to get all objects
        let searchResults = try await search(requestBody: requestBody)
        
        // Extract only what we need: ID, title, and type
        var metadata: [FileMetadata] = []
        
        for result in searchResults.results {
            if let database = result as? NotionDatabase {
                let title = database.title?.first?.plainText ?? "Untitled Database"
                metadata.append(FileMetadata(
                    id: database.id,
                    title: title,
                    type: .database,
                    tokenID: tokenID,
                    isSelected: false
                ))
            }
            else if let page = result as? NotionPage {
                let title = page.getTitle() // Use your existing method to extract title
                metadata.append(FileMetadata(
                    id: page.id,
                    title: title,
                    type: .page,
                    tokenID: tokenID,
                    isSelected: false
                ))
            }
        }
        
        return metadata
    }
}
