// AcrostiKit/Models/NotionRequest.swift
import Foundation

// MARK: - Sort Directions and Sorting

/// Sort direction for query and search requests
public enum NotionSortDirection: String, Codable {
    case ascending
    case descending
}

/// Sort object for query requests
public struct NotionQuerySort: Codable {
    public let property: String?
    public let timestamp: String?
    public let direction: NotionSortDirection
    
    public init(property: String? = nil, timestamp: String? = nil, direction: NotionSortDirection = .ascending) {
        self.property = property
        self.timestamp = timestamp
        self.direction = direction
    }
    
    // Convert to dictionary for API requests
    public var dictionary: [String: Any] {
        var result: [String: Any] = [
            "direction": direction.rawValue
        ]
        
        if let property = property {
            result["property"] = property
        }
        
        if let timestamp = timestamp {
            result["timestamp"] = timestamp
        }
        
        return result
    }
}

/// Sort object for search requests
public struct NotionSearchSort: Codable {
    public let direction: NotionSortDirection
    public let timestamp: String
    
    public init(direction: NotionSortDirection = .descending, timestamp: String = "last_edited_time") {
        self.direction = direction
        self.timestamp = timestamp
    }
}

// MARK: - Database Query Models

/// Search filter for Notion API requests
public struct NotionSearchFilter: Codable {
    public var property: String = ""
    public var value: String = ""
    public var type: String?
    
    public init() {}
    
    // Convert to dictionary for API requests
    public var dictionaryRepresentation: [String: Any] {
        var result: [String: Any] = [
            "property": property,
            "value": value
        ]
        
        if let type = type {
            result["type"] = type
        }
        
        return result
    }
    
    public var dictionary: [String: Any] {
        return dictionaryRepresentation
    }
}

/// Query request for database queries
public struct NotionQueryDatabaseRequest: Codable {
    public var filter: [String: Any]?
    public var sorts: [NotionQuerySort]?
    public var startCursor: String?
    public var pageSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case filter, sorts
        case startCursor = "start_cursor"
        case pageSize = "page_size"
    }
    
    public init(filter: [String: Any]? = nil, sorts: [NotionQuerySort]? = nil, startCursor: String? = nil, pageSize: Int? = nil) {
        self.filter = filter
        self.sorts = sorts
        self.startCursor = startCursor
        self.pageSize = pageSize
    }
    
    // Custom encoding to handle [String: Any] filter
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(sorts, forKey: .sorts)
        try container.encodeIfPresent(startCursor, forKey: .startCursor)
        try container.encodeIfPresent(pageSize, forKey: .pageSize)
        
        // Handle filter encoding
        if let filter = filter {
            // Use JSONSerialization for [String: Any] encoding
            let filterData = try JSONSerialization.data(withJSONObject: filter)
            let filterValue = try JSONDecoder().decode(JSONAny.self, from: filterData)
            try container.encode(filterValue, forKey: .filter)
        }
    }
}

// MARK: - Page Creation Models

/// Property value for page creation
public struct NotionPropertyValueInput: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        guard let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "No value"))
        }
        
        type = key.stringValue
        value = try container.decode(JSONAny.self, forKey: key).value
    }
    
    public var type: String
    public var value: Any
    
    private enum CodingKeys: CodingKey {
        // This is intentionally empty as we'll use custom encoding
    }
    
    public init(type: String, value: Any) {
        self.type = type
        self.value = value
    }
    
    // Convert to dictionary for API requests
    public var dictionary: [String: Any] {
        return [type: value]
    }
    
    // Custom encoding
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        
        if let key = DynamicCodingKeys(stringValue: type) {
            // Use JSONSerialization for handling Any values
            let data = try JSONSerialization.data(withJSONObject: value)
            let jsonValue = try JSONDecoder().decode(JSONAny.self, from: data)
            try container.encode(jsonValue, forKey: key)
        }
    }
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
}

/// Request for creating a new page
public struct NotionCreatePageRequest: Codable {
    public var parent: NotionParent
    public var properties: [String: NotionPropertyValueInput]
    public var children: [NotionBlock]?
    public var icon: NotionIcon?
    public var cover: NotionCover?
    
    public init(parent: NotionParent, properties: [String: NotionPropertyValueInput], children: [NotionBlock]? = nil, icon: NotionIcon? = nil, cover: NotionCover? = nil) {
        self.parent = parent
        self.properties = properties
        self.children = children
        self.icon = icon
        self.cover = cover
    }
    
    // Custom encoding to handle the properties dictionary
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(parent, forKey: .parent)
        try container.encodeIfPresent(children, forKey: .children)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(cover, forKey: .cover)
        
        // Handle properties encoding
        var propertiesContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .properties)
        
        for (key, value) in properties {
            if let codingKey = DynamicCodingKeys(stringValue: key) {
                try propertiesContainer.encode(value, forKey: codingKey)
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case parent, properties, children, icon, cover
    }
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
}

// MARK: - Database Creation Models

/// Database property schema for database creation
public struct NotionPropertySchemaInput: Codable {
    public var type: String
    public var configuration: [String: Any]?
    
    public init(type: String, configuration: [String: Any]? = nil) {
        self.type = type
        self.configuration = configuration
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        
        // Decode configuration dynamically
        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
        configuration = try dynamicContainer.decodeIfPresent(JSONAny.self, forKey: DynamicCodingKeys(stringValue: type)!)?.getValueDictionary()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        if let configuration = configuration {
            var dynamicContainer = encoder.container(keyedBy: DynamicCodingKeys.self)
            let jsonValue = try JSONSerialization.data(withJSONObject: configuration)
            let encodableValue = try JSONDecoder().decode(JSONAny.self, from: jsonValue)
            try dynamicContainer.encode(encodableValue, forKey: DynamicCodingKeys(stringValue: type)!)
        }
    }
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    // Convert to dictionary for API requests
    public var dictionary: [String: Any] {
        var result: [String: Any] = ["type": type]
        
        if let configuration = configuration {
            // Add configuration properties based on type
            for (key, value) in configuration {
                result[key] = value
            }
        }
        
        return result
    }
}

/// Request for creating a new database
public struct NotionCreateDatabaseRequest: Codable {
    public var parent: NotionParent
    public var title: [NotionRichText]
    public var properties: [String: NotionPropertySchemaInput]
    public var isInline: Bool?
    
    enum CodingKeys: String, CodingKey {
        case parent, title, properties
        case isInline = "is_inline"
    }
    
    public init(parent: NotionParent, title: [NotionRichText], properties: [String: NotionPropertySchemaInput], isInline: Bool? = nil) {
        self.parent = parent
        self.title = title
        self.properties = properties
        self.isInline = isInline
    }
}

// MARK: - Block Models

/// Request for appending blocks to a parent block
public struct NotionAppendBlockChildrenRequest: Codable {
    public var children: [NotionBlock]
    
    public init(children: [NotionBlock]) {
        self.children = children
    }
}

/// Request for updating a block
public struct NotionUpdateBlockRequest: Codable {
    public var type: String
    public var archived: Bool?
    public var content: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case type, archived
        // Content is dynamic based on type
    }
    
    public init(type: String, archived: Bool? = nil, content: [String: Any]? = nil) {
        self.type = type
        self.archived = archived
        self.content = content
    }
    
    // Custom encoding to handle the dynamic content
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(archived, forKey: .archived)
        
        // Encode the content under the type key
        if let content = content {
            var contentContainer = encoder.container(keyedBy: DynamicCodingKeys.self)
            if let key = DynamicCodingKeys(stringValue: type) {
                // Use JSONSerialization for handling [String: Any]
                let contentData = try JSONSerialization.data(withJSONObject: content)
                let contentValue = try JSONDecoder().decode(JSONAny.self, from: contentData)
                try contentContainer.encode(contentValue, forKey: key)
            }
        }
    }
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
}

// MARK: - OAuth & Token Models

/// Request for creating a token using OAuth
public struct NotionCreateTokenRequest: Codable {
    public var grantType: String
    public var code: String
    public var redirectURI: String?
    
    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case code
        case redirectURI = "redirect_uri"
    }
    
    public init(code: String, grantType: String = "authorization_code", redirectURI: String? = nil) {
        self.code = code
        self.grantType = grantType
        self.redirectURI = redirectURI
    }
}

/// Response for token creation
public struct NotionCreateTokenResponse: Codable {
    public var accessToken: String
    public var tokenType: String
    public var botID: String?
    public var workspaceID: String?
    public var workspaceName: String?
    public var workspaceIcon: String?
    public var owner: JSONAny?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case botID = "bot_id"
        case workspaceID = "workspace_id"
        case workspaceName = "workspace_name"
        case workspaceIcon = "workspace_icon"
        case owner
    }
}

// MARK: - Comment Models

/// Request for creating a comment
public struct NotionCreateCommentRequest: Codable {
    public var parent: NotionParent
    public var richText: [NotionRichText]
    
    enum CodingKeys: String, CodingKey {
        case parent
        case richText = "rich_text"
    }
    
    public init(parent: NotionParent, richText: [NotionRichText]) {
        self.parent = parent
        self.richText = richText
    }
}

/// Model for a Notion comment
public struct NotionComment: Codable, NotionObject {
    public var id: String
    public var object: String
    public var parent: NotionParent
    public var discussionID: String
    public var createdTime: Date
    public var lastEditedTime: Date
    public var createdBy: NotionUser
    public var richText: [NotionRichText]
    
    enum CodingKeys: String, CodingKey {
        case id, object, parent
        case discussionID = "discussion_id"
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case createdBy = "created_by"
        case richText = "rich_text"
    }
}

/// Response for comment list operation
public struct NotionCommentListResponse: Codable {
    public var object: String
    public var results: [NotionComment]
    public var nextCursor: String?
    public var hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

/// Response for property items
public struct NotionPropertyItemResponse: Codable {
    public var object: String
    public var results: [JSONAny]
    public var nextCursor: String?
    public var hasMore: Bool
    public var type: String
    public var id: String
    
    enum CodingKeys: String, CodingKey {
        case object, results, type, id
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

// MARK: - Request Convenience Methods

extension NotionQueryDatabaseRequest {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sorts = try container.decodeIfPresent([NotionQuerySort].self, forKey: .sorts)
        startCursor = try container.decodeIfPresent(String.self, forKey: .startCursor)
        pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize)
        
        // Handle filter decoding
        if let filterValue = try container.decodeIfPresent(JSONAny.self, forKey: .filter) {
            filter = filterValue.getValueDictionary()
        } else {
            filter = nil
        }
    }
    
    /// Creates a request to query a database with common parameters
    public static func create(
        filter: [String: Any]? = nil,
        sorts: [NotionQuerySort]? = nil,
        pageSize: Int = 100
    ) -> NotionQueryDatabaseRequest {
        return NotionQueryDatabaseRequest(
            filter: filter,
            sorts: sorts,
            startCursor: nil,
            pageSize: pageSize
        )
    }
    
    /// Creates a request with a simple property filter
    public static func withPropertyFilter(
        property: String,
        value: Any,
        filterType: String = "equals",
        pageSize: Int = 100
    ) -> NotionQueryDatabaseRequest {
        let filter: [String: Any] = [
            "property": property,
            filterType: value
        ]
        return create(filter: ["filter": filter], pageSize: pageSize)
    }
    
    /// Creates a request with date filter
    public static func withDateFilter(
        property: String,
        dateFilterType: String, // "equals", "before", "after", "on_or_before", "on_or_after", etc.
        date: Date,
        pageSize: Int = 100
    ) -> NotionQueryDatabaseRequest {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = formatter.string(from: date)
        
        let filter: [String: Any] = [
            "property": property,
            "date": [
                dateFilterType: dateString
            ]
        ]
        return create(filter: ["filter": filter], pageSize: pageSize)
    }
    
    /// Creates a request with compound filter (AND)
    public static func withAndFilter(
        filters: [[String: Any]],
        pageSize: Int = 100
    ) -> NotionQueryDatabaseRequest {
        return create(filter: ["and": filters], pageSize: pageSize)
    }
    
    /// Creates a request with compound filter (OR)
    public static func withOrFilter(
        filters: [[String: Any]],
        pageSize: Int = 100
    ) -> NotionQueryDatabaseRequest {
        return create(filter: ["or": filters], pageSize: pageSize)
    }
}

// MARK: - Page Creation Helpers

extension NotionCreatePageRequest {
    /// Creates a simple page with a title in a database
    public static func createInDatabase(
        databaseID: String,
        title: String,
        properties: [String: NotionPropertyValueInput] = [:]
    ) -> NotionCreatePageRequest {
        // Create the parent reference
        let parent = NotionParent(type: "database_id", databaseID: databaseID)
        
        // Create or update the title property
        var allProperties = properties
        if !title.isEmpty {
            let titleInput = NotionPropertyValueInput(
                type: "title",
                value: [
                    [
                        "type": "text",
                        "text": ["content": title]
                    ]
                ]
            )
            
            // Find the title property name (it might not be "title" exactly)
            allProperties["title"] = titleInput
        }
        
        return NotionCreatePageRequest(parent: parent, properties: allProperties)
    }
    
    /// Creates a task page with standard task properties
    public static func createTask(
        databaseID: String,
        title: String,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        additionalProperties: [String: NotionPropertyValueInput] = [:]
    ) -> NotionCreatePageRequest {
        var properties = additionalProperties
        
        // Add checkbox for completion status
        properties["Completed"] = NotionPropertyValueInput(
            type: "checkbox",
            value: isCompleted
        )
        
        // Add due date if provided
        if let dueDate = dueDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            properties["Due Date"] = NotionPropertyValueInput(
                type: "date",
                value: ["start": formatter.string(from: dueDate)]
            )
        }
        
        return createInDatabase(databaseID: databaseID, title: title, properties: properties)
    }
}

// MARK: - Block Creation Helpers

extension NotionBlock {
    /// Creates a paragraph block
    public static func paragraph(_ text: String) -> NotionBlock {
        return NotionBlock(
            object: "block",
            id: "",
            type: "paragraph",
            blockContent: JSONAny(
                [
                    "rich_text": [
                        [
                            "type": "text",
                            "text": ["content": text]
                        ]
                    ]
                ]
            )
        )
    }
    
    /// Creates a heading block
    public static func heading(_ text: String, level: Int) -> NotionBlock {
        assert(level >= 1 && level <= 3, "Heading level must be between 1 and 3")
        
        return NotionBlock(
            object: "block",
            id: "",
            type: "heading_\(level)",
            blockContent: JSONAny(
                [
                    "rich_text": [
                        [
                            "type": "text",
                            "text": ["content": text]
                        ]
                    ]
                ]
            )
        )
    }
    
    /// Creates a to-do block
    public static func todo(_ text: String, checked: Bool = false) -> NotionBlock {
        return NotionBlock(
            object: "block",
            id: "",
            type: "to_do",
            blockContent: JSONAny(
                [
                    "rich_text": [
                        [
                            "type": "text",
                            "text": ["content": text]
                        ]
                    ],
                    "checked": checked
                ]
            )
        )
    }
    
    /// Creates a bulleted list item
    public static func bulletedListItem(_ text: String) -> NotionBlock {
        return NotionBlock(
            object: "block",
            id: "",
            type: "bulleted_list_item",
            blockContent: JSONAny(
                [
                    "rich_text": [
                        [
                            "type": "text",
                            "text": ["content": text]
                        ]
                    ]
                ]
            )
        )
    }
    
    /// Creates a code block
    public static func code(_ code: String, language: String = "swift") -> NotionBlock {
        return NotionBlock(
            object: "block",
            id: "",
            type: "code",
            blockContent: JSONAny(
                [
                    "rich_text": [
                        [
                            "type": "text",
                            "text": ["content": code]
                        ]
                    ],
                    "language": language
                ]
            )
        )
    }
}

// MARK: - Response Processing

/// Protocol for handling paginated responses
public protocol NotionPaginatedProcessor<ItemType> {
    associatedtype ItemType
    /// Process a batch of results
    func process(results: [ItemType]) -> Bool
    
    /// Indicate if more results should be fetched
    func shouldContinue() -> Bool
}

/// Default implementation of paginated processor
public class DefaultPaginatedProcessor<T>: NotionPaginatedProcessor {
    public typealias ItemType = T
    
    private var items: [T] = []
    private var maxItems: Int
    private var processingBlock: (([T]) -> Void)?
    
    public init(maxItems: Int = .max, processingBlock: (([T]) -> Void)? = nil) {
        self.maxItems = maxItems
        self.processingBlock = processingBlock
    }
    
    public func process(results: [T]) -> Bool {
        items.append(contentsOf: results)
        processingBlock?(results)
        return true
    }
    
    public func shouldContinue() -> Bool {
        return items.count < maxItems
    }
    
    public func getItems() -> [T] {
        return items
    }
}

/// Extension for response handling on the APIClient
extension NotionAPIClient {
    /// Processes all pages of a paginated API request
    public func processPaginatedRequest<T, U>(
        initialRequest: @escaping () async throws -> T,
        nextPageRequest: @escaping (String) async throws -> T,
        getResults: @escaping (T) -> [U],
        getNextCursor: @escaping (T) -> String?,
        hasMore: @escaping (T) -> Bool,
        processor: inout some NotionPaginatedProcessor<U>
    ) async throws {
        // Get first page
        var response = try await initialRequest()
        var results = getResults(response)
        
        // Process first page
        let shouldContinue = processor.process(results: results)
        if !shouldContinue || !hasMore(response) || !processor.shouldContinue() {
            return
        }
        
        // Process remaining pages
        while let nextCursor = getNextCursor(response),
              hasMore(response),
              processor.shouldContinue() {
            
            response = try await nextPageRequest(nextCursor)
            results = getResults(response)
            
            if !processor.process(results: results) {
                break
            }
        }
    }
}
