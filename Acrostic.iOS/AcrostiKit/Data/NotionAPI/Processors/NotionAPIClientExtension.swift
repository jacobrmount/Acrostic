// AcrostiKit/BusinessLogic/NotionAPIClientExtension.swift
import Foundation
import CoreData

extension NotionAPIClient {
    /// Retrieves all pages from a database query
    public func queryDatabaseWithPagination(
        databaseID: String,
        request: NotionQueryDatabaseRequest,
        processor: inout some NotionPaginatedProcessor<NotionPage>
    ) async throws {
        try await processPaginatedRequest(
            initialRequest: {
                return try await self.queryDatabase(databaseID: databaseID, requestBody: request)
            },
            nextPageRequest: { nextCursor in
                var nextRequest = request
                nextRequest.startCursor = nextCursor
                return try await self.queryDatabase(databaseID: databaseID, requestBody: nextRequest)
            },
            getResults: { $0.results },
            getNextCursor: { $0.nextCursor },
            hasMore: { $0.hasMore },
            processor: &processor
        )
    }
    
    public func searchWithPagination(
        query: String? = nil,
        filter: NotionSearchFilter? = nil,
        sort: NotionSearchSort? = nil,
        pageSize: Int = 100,
        processor: inout some NotionPaginatedProcessor<NotionObject>
    ) async throws {
        var requestBody: [String: Any] = [:]
        
        if let query = query {
            requestBody["query"] = query
        }
        
        if let sort = sort {
            requestBody["sort"] = [
                "direction": sort.direction.rawValue,
                "timestamp": sort.timestamp
            ]
        }
        
        if pageSize > 0 {
            requestBody["page_size"] = pageSize
        }
        
        try await processPaginatedRequest(
            initialRequest: {
                return try await self.search(requestBody: requestBody)
            },
            nextPageRequest: { nextCursor in
                var newRequestBody = requestBody
                newRequestBody["start_cursor"] = nextCursor
                return try await self.search(requestBody: newRequestBody)
            },
            getResults: { $0.results },
            getNextCursor: { $0.nextCursor },
            hasMore: { $0.hasMore },
            processor: &processor
        )
    }
}
