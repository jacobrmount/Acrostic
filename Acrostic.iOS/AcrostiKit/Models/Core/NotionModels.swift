// AcrostiKit/Models/Core/NotionModels.swift
import Foundation

// MARK: - Core Protocols

/// Base protocol for all Notion objects
public protocol NotionObject {
    var id: String { get }
    var object: String { get }
}

/// Protocol for objects that contain rich text content
public protocol RichTextContainer {
    var richText: [NotionRichText]? { get }
    
    /// Returns plain text representation of the rich text content
    func getPlainText() -> String
}

extension RichTextContainer {
    public func getPlainText() -> String {
        return richText?.map { $0.plainText }.joined() ?? ""
    }
}

/// Protocol for parent objects in Notion's hierarchy
public protocol ParentContainer {
    var parent: NotionParent? { get }
    
    /// Returns the parent's database ID if available
    func getParentDatabaseID() -> String?
    
    /// Returns the parent's page ID if available
    func getParentPageID() -> String?
}

extension ParentContainer {
    public func getParentDatabaseID() -> String? {
        guard let parent = parent, parent.type == "database_id" else {
            return nil
        }
        return parent.databaseID
    }
    
    public func getParentPageID() -> String? {
        guard let parent = parent, parent.type == "page_id" else {
            return nil
        }
        return parent.pageID
    }
}

// MARK: - Common Utility Types

/// Represents a Notion parent reference
public struct NotionParent: Codable {
    public let type: String
    public let databaseID: String?
    public let pageID: String?
    public let workspaceID: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case databaseID = "database_id"
        case pageID = "page_id"
        case workspaceID = "workspace_id"
    }
    
    public init(type: String, databaseID: String? = nil, pageID: String? = nil, workspaceID: String? = nil) {
        self.type = type
        self.databaseID = databaseID
        self.pageID = pageID
        self.workspaceID = workspaceID
    }
}

/// Represents rich text content in Notion
public struct NotionRichText: Codable {
    public let plainText: String
    public let href: String?
    public let annotations: NotionAnnotations?
    public let type: String
    public let content: JSONAny?
    
    enum CodingKeys: String, CodingKey {
        case plainText = "plain_text"
        case href, annotations, type
        case content = "text" // This assumes text type, but we'll handle others in init
    }
    
    public init(plainText: String, type: String = "text", href: String? = nil, annotations: NotionAnnotations? = nil, content: JSONAny? = nil) {
        self.plainText = plainText
        self.type = type
        self.href = href
        self.annotations = annotations
        self.content = content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        plainText = try container.decode(String.self, forKey: .plainText)
        href = try container.decodeIfPresent(String.self, forKey: .href)
        annotations = try container.decodeIfPresent(NotionAnnotations.self, forKey: .annotations)
        type = try container.decode(String.self, forKey: .type)
        
        // Handle different content types based on the 'type' field
        switch type {
        case "text":
            content = try container.decodeIfPresent(JSONAny.self, forKey: .content)
        default:
            // For other types, we'll need to add specific handling as needed
            content = nil
        }
    }
}

/// Represents text annotations in Notion
public struct NotionAnnotations: Codable {
    public let bold: Bool
    public let italic: Bool
    public let strikethrough: Bool
    public let underline: Bool
    public let code: Bool
    public let color: String
    
    public init(bold: Bool = false, italic: Bool = false, strikethrough: Bool = false,
                underline: Bool = false, code: Bool = false, color: String = "default") {
        self.bold = bold
        self.italic = italic
        self.strikethrough = strikethrough
        self.underline = underline
        self.code = code
        self.color = color
    }
}

/// Represents a user in Notion
public struct NotionUser: Codable, NotionObject {
    public let id: String
    public let object: String
    public let name: String?
    public let avatarURL: String?
    public let type: String?
    public let person: JSONAny?
    public let bot: JSONAny?
    
    enum CodingKeys: String, CodingKey {
        case id, object, name, type
        case avatarURL = "avatar_url"
        case person, bot
    }
/// Add a custom init(from:) method to handle missing fields
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        id = try container.decode(String.self, forKey: .id)
        object = try container.decode(String.self, forKey: .object)
        
        // Optional fields
        name = try container.decodeIfPresent(String.self, forKey: .name)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        
        // Handle potentially missing type field
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "unknown"
        
        // Optional complex objects
        person = try container.decodeIfPresent(JSONAny.self, forKey: .person)
        bot = try container.decodeIfPresent(JSONAny.self, forKey: .bot)
    }
}

/// Represents a file or external reference
public struct NotionFile: Codable {
    public let type: String
    public let file: JSONAny?
    public let external: JSONAny?
    
    public init(type: String, file: JSONAny? = nil, external: JSONAny? = nil) {
        self.type = type
        self.file = file
        self.external = external
    }
    
    public func getURL() -> String? {
        switch type {
        case "file":
            return file?.getStringValue(fromKey: "url")
        case "external":
            return external?.getStringValue(fromKey: "url")
        default:
            return nil
        }
    }
    
    public func getExpiryTime() -> Date? {
        guard type == "file" else { return nil }
        return file?.getDateValue(fromKey: "expiry_time")
    }
}

/// Represents an icon (emoji or file)
public struct NotionIcon: Codable {
    public let type: String
    public let emoji: String?
    public let file: NotionFile?
    
    public init(type: String, emoji: String? = nil, file: NotionFile? = nil) {
        self.type = type
        self.emoji = emoji
        self.file = file
    }
}

/// Represents a cover image
public typealias NotionCover = NotionFile

// MARK: - Date/Time Utilities

/// Utility for handling Notion's date formats
public struct NotionDate: Codable {
    public let start: String
    public let end: String?
    public let timeZone: String?
    
    enum CodingKeys: String, CodingKey {
        case start, end
        case timeZone = "time_zone"
    }
    
    public func getStartDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: start)
    }
    
    public func getEndDate() -> Date? {
        guard let end = end else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: end)
    }
}

// MARK: - Error Models

/// Standard error response from Notion API
public struct NotionErrorResponse: Codable {
    public let object: String
    public let status: Int?
    public let code: String?
    public let message: String?
    
    public init(object: String = "error", status: Int? = nil, code: String? = nil, message: String? = nil) {
        self.object = object
        self.status = status
        self.code = code
        self.message = message
    }
}

// MARK: - Database Models

/// Represents a Notion database
public struct NotionDatabase: Codable, NotionObject, ParentContainer {
    public let id: String
    public let object: String
    public let createdTime: Date?
    public let lastEditedTime: Date?
    public let title: [NotionRichText]?
    public let description: [NotionRichText]?
    public let properties: [String: NotionPropertySchema]?
    public let url: String?
    public let parent: NotionParent?
    public let isInline: Bool?
    public let archived: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, object, url, properties, parent, archived
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case title, description
        case isInline = "is_inline"
    }
    
    // Helper accessor for title text
    public func getTitleText() -> String {
        return title?.map { $0.plainText }.joined() ?? "Untitled"
    }
    
    // Helper accessor for description text
    public func getDescriptionText() -> String {
        return description?.map { $0.plainText }.joined() ?? ""
    }
    
    // Helper to check if database has a specific property
    public func hasProperty(named name: String) -> Bool {
        return properties?.keys.contains { $0.lowercased() == name.lowercased() } ?? false
    }
    
    // Helper to get property schema by name (case-insensitive)
    public func getPropertySchema(named name: String) -> NotionPropertySchema? {
        guard let properties = properties else { return nil }
        
        return properties.first { key, _ in
            key.lowercased() == name.lowercased()
        }?.value
    }
    
    // Helper to get property schema by name pattern (contains, case-insensitive)
    public func findPropertySchema(containing pattern: String) -> NotionPropertySchema? {
        guard let properties = properties else { return nil }
        
        return properties.first { key, _ in
            key.lowercased().contains(pattern.lowercased())
        }?.value
    }
}

// MARK: - Page Models

/// Represents a Notion page
public struct NotionPage: Codable, NotionObject, ParentContainer {
    public let id: String
    public let object: String
    public let createdTime: Date?
    public let lastEditedTime: Date?
    public let createdBy: NotionUser?
    public let lastEditedBy: NotionUser?
    public let cover: NotionCover?
    public let icon: NotionIcon?
    public let parent: NotionParent?
    public let archived: Bool?
    public let properties: [String: NotionPropertyValue]?
    public let url: String?
    
    enum CodingKeys: String, CodingKey {
        case id, object, url, parent, archived, properties
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case createdBy = "created_by"
        case lastEditedBy = "last_edited_by"
        case cover, icon
    }
    
    // MARK: - Helper methods for extracting common properties
    
    public func getTitle() -> String {
        if let properties = properties {
            // First look for a property literally named "title"
            if let titleProp = properties.first(where: { $0.key.lowercased() == "title" }) {
                if let richTexts = titleProp.value.extractTitle() {
                    return richTexts.map { $0.plainText }.joined()
                }
            }
            
            // Then look for properties containing "name" or "title"
            for propName in ["name", "title"] {
                if let prop = properties.first(where: { $0.key.lowercased().contains(propName) }) {
                    if prop.value.type == "title" {
                        if let richTexts = prop.value.extractTitle() {
                            return richTexts.map { $0.plainText }.joined()
                        }
                    } else if let richTexts = prop.value.extractRichText() {
                        return richTexts.map { $0.plainText }.joined()
                    }
                }
            }
        }
        return "Untitled"
    }
    
    public func getCompletionStatus() -> Bool {
        if let properties = properties {
            // Look for common status/checkbox property names
            for propName in ["status", "complete", "done", "completed", "checkbox"] {
                if let prop = properties.first(where: { $0.key.lowercased().contains(propName) }) {
                    // Try checkbox first
                    if let isCompleted = prop.value.extractCheckbox() {
                        return isCompleted
                    }
                    
                    // Then try select
                    if let select = prop.value.extractSelect(),
                       let name = select.name?.lowercased() {
                        return ["done", "complete", "completed", "yes", "true"].contains(name)
                    }
                    
                    // Try formula that resolves to boolean
                    if prop.value.type == "formula" {
                        if let formulaResult = prop.value.extractFormula() as? Bool {
                            return formulaResult
                        }
                    }
                }
            }
        }
        return false
    }
    
    public func getDueDate() -> Date? {
        if let properties = properties {
            // Look for date property
            for propName in ["date", "due", "deadline", "due date", "duedate"] {
                if let prop = properties.first(where: { $0.key.lowercased().contains(propName) }) {
                    // First try direct date extraction
                    if let date = prop.value.extractDate() {
                        return date
                    }
                    
                    // Try formula that resolves to date
                    if prop.value.type == "formula" {
                        if let formulaDate = prop.value.extractFormula() as? Date {
                            return formulaDate
                        }
                    }
                }
            }
        }
        return nil
    }
    
    // Get a property value by name (case-insensitive)
    public func getProperty(named name: String) -> NotionPropertyValue? {
        guard let properties = properties else { return nil }
        
        return properties.first { key, _ in
            key.lowercased() == name.lowercased()
        }?.value
    }
    
    // Find a property by name pattern (contains, case-insensitive)
    public func findProperty(containing pattern: String) -> NotionPropertyValue? {
        guard let properties = properties else { return nil }
        
        return properties.first { key, _ in
            key.lowercased().contains(pattern.lowercased())
        }?.value
    }
    
    // Create a TaskItem from this page
    public func toTaskItem() -> TaskItem {
        return TaskItem(
            id: id,
            title: getTitle(),
            isCompleted: getCompletionStatus(),
            dueDate: getDueDate()
        )
    }
}

// MARK: - Block Models

/// Represents a Notion block type enum
public enum NotionBlockType: String, Codable {
    case paragraph
    case heading1 = "heading_1"
    case heading2 = "heading_2"
    case heading3 = "heading_3"
    case bulletedListItem = "bulleted_list_item"
    case numberedListItem = "numbered_list_item"
    case toDo = "to_do"
    case toggle
    case code
    case childPage = "child_page"
    case childDatabase = "child_database"
    case embed
    case image
    case video
    case file
    case pdf
    case bookmark
    case callout
    case quote
    case divider
    case tableOfContents = "table_of_contents"
    case column
    case columnList = "column_list"
    case linkPreview = "link_preview"
    case synced_block = "synced_block"
    case template
    case linkToPage = "link_to_page"
    case table
    case tableRow = "table_row"
    case unsupported
}

/// Represents a Notion block
public struct NotionBlock: Codable, NotionObject, ParentContainer {
    public let id: String
    public let object: String
    public let parent: NotionParent?
    public let createdTime: Date?
    public let lastEditedTime: Date?
    public let createdBy: NotionUser?
    public let lastEditedBy: NotionUser?
    public let hasChildren: Bool?
    public let archived: Bool?
    public let type: String
    public let blockContent: JSONAny?
    
    enum CodingKeys: String, CodingKey {
        case id, object, parent, type
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case createdBy = "created_by"
        case lastEditedBy = "last_edited_by"
        case hasChildren = "has_children"
        case archived
        // Block content is coded dynamically based on type
    }
    
    public init(object: String, id: String, parent: NotionParent? = nil, createdTime: Date? = nil,
                lastEditedTime: Date? = nil, createdBy: NotionUser? = nil, lastEditedBy: NotionUser? = nil,
                hasChildren: Bool? = nil, archived: Bool? = nil, type: String, blockContent: JSONAny? = nil) {
        self.object = object
        self.id = id
        self.parent = parent
        self.createdTime = createdTime
        self.lastEditedTime = lastEditedTime
        self.createdBy = createdBy
        self.lastEditedBy = lastEditedBy
        self.hasChildren = hasChildren
        self.archived = archived
        self.type = type
        self.blockContent = blockContent
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        object = try container.decode(String.self, forKey: .object)
        parent = try container.decodeIfPresent(NotionParent.self, forKey: .parent)
        createdTime = try container.decodeIfPresent(Date.self, forKey: .createdTime)
        lastEditedTime = try container.decodeIfPresent(Date.self, forKey: .lastEditedTime)
        createdBy = try container.decodeIfPresent(NotionUser.self, forKey: .createdBy)
        lastEditedBy = try container.decodeIfPresent(NotionUser.self, forKey: .lastEditedBy)
        hasChildren = try container.decodeIfPresent(Bool.self, forKey: .hasChildren)
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived)
        type = try container.decode(String.self, forKey: .type)
        
        // Decode block content based on type
        let contentContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
        if let key = DynamicCodingKeys(stringValue: type) {
            blockContent = try contentContainer.decodeIfPresent(JSONAny.self, forKey: key)
        } else {
            blockContent = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(object, forKey: .object)
        try container.encodeIfPresent(parent, forKey: .parent)
        try container.encodeIfPresent(createdTime, forKey: .createdTime)
        try container.encodeIfPresent(lastEditedTime, forKey: .lastEditedTime)
        try container.encodeIfPresent(createdBy, forKey: .createdBy)
        try container.encodeIfPresent(lastEditedBy, forKey: .lastEditedBy)
        try container.encodeIfPresent(hasChildren, forKey: .hasChildren)
        try container.encodeIfPresent(archived, forKey: .archived)
        try container.encode(type, forKey: .type)

        if let blockContent = blockContent {
            var contentContainer = encoder.container(keyedBy: DynamicCodingKeys.self)
            if let key = DynamicCodingKeys(stringValue: type) {
                try contentContainer.encode(blockContent, forKey: key)
            }
        }
    }
    
    // Helper struct for dynamic property types in JSON
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
    
    // Extract text content from various block types
    public func getTextContent() -> String? {
        guard let content = blockContent?.getValueDictionary() else { return nil }
        
        switch type {
        case "paragraph", "heading_1", "heading_2", "heading_3",
             "bulleted_list_item", "numbered_list_item", "to_do", "toggle", "callout", "quote":
            if let richText = content["rich_text"] as? [[String: Any]] {
                return richText.compactMap { item in
                    item["plain_text"] as? String
                }.joined()
            }
            
        case "code":
            if let richText = content["rich_text"] as? [[String: Any]] {
                let code = richText.compactMap { item in
                    item["plain_text"] as? String
                }.joined()
                
                if let language = content["language"] as? String {
                    return "```\(language)\n\(code)\n```"
                } else {
                    return "```\n\(code)\n```"
                }
            }
            
        case "child_page":
            return content["title"] as? String
            
        case "child_database":
            return content["title"] as? String
            
        default:
            return nil
        }
        
        return nil
    }
    
    // Get paragraph text content
    public func getParagraphText() -> String? {
        guard type == "paragraph" else { return nil }
        
        if let content = blockContent?.getValueDictionary(),
           let richTextArray = content["rich_text"] as? [[String: Any]] {
            return richTextArray.compactMap { item in
                item["plain_text"] as? String
            }.joined()
        }
        return nil
    }
    
    // Get heading text content with level
    public func getHeadingText() -> (text: String, level: Int)? {
        guard type.starts(with: "heading_"),
              let levelString = type.split(separator: "_").last,
              let level = Int(levelString) else { return nil }
        
        if let content = blockContent?.getValueDictionary(),
           let richTextArray = content["rich_text"] as? [[String: Any]] {
            let text = richTextArray.compactMap { item in
                item["plain_text"] as? String
            }.joined()
            
            return (text, level)
        }
        return nil
    }
    
    // Get to-do item details
    public func getTodoDetails() -> (text: String, checked: Bool)? {
        guard type == "to_do" else { return nil }
        
        if let content = blockContent?.getValueDictionary(),
           let richTextArray = content["rich_text"] as? [[String: Any]] {
            let text = richTextArray.compactMap { item in
                item["plain_text"] as? String
            }.joined()
            
            let checked = content["checked"] as? Bool ?? false
            
            return (text, checked)
        }
        return nil
    }
    
    // Get list item text (bulleted or numbered)
    public func getListItemText() -> String? {
        guard type == "bulleted_list_item" || type == "numbered_list_item" else { return nil }
        
        if let content = blockContent?.getValueDictionary(),
           let richTextArray = content["rich_text"] as? [[String: Any]] {
            return richTextArray.compactMap { item in
                item["plain_text"] as? String
            }.joined()
        }
        return nil
    }
    
    // Get code block details
    public func getCodeDetails() -> (code: String, language: String)? {
        guard type == "code" else { return nil }
        
        if let content = blockContent?.getValueDictionary(),
           let richTextArray = content["rich_text"] as? [[String: Any]] {
            let code = richTextArray.compactMap { item in
                item["plain_text"] as? String
            }.joined()
            
            let language = content["language"] as? String ?? "plain text"
            
            return (code, language)
        }
        return nil
    }
    
    // Get whether a to_do block is checked
    public func isChecked() -> Bool? {
        guard type == "to_do",
              let content = blockContent?.getValueDictionary() else { return nil }
        
        return content["checked"] as? Bool
    }
}

// MARK: - Response Models

/// Base response structure for list-based API responses
public struct NotionPaginatedResponse: Codable {
    public let object: String
    public let nextCursor: String?
    public let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case object
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

/// Response for database query operations
public struct NotionQueryDatabaseResponse: Codable {
    public let object: String
    public let results: [NotionPage]
    public let nextCursor: String?
    public let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

/// Response for search operations
public struct NotionSearchResponse: Codable {
    public let object: String
    public let results: [NotionObject]
    public let nextCursor: String?
    public let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        object = try container.decode(String.self, forKey: .object)
        nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
        hasMore = try container.decode(Bool.self, forKey: .hasMore)
        
        // Handle decoding of heterogeneous results
        var resultsArray: [NotionObject] = []
        var resultsContainer = try container.nestedUnkeyedContainer(forKey: .results)
        
        // Track remaining items for better error handling
        let itemCount = resultsContainer.count ?? 0
        print("Found \(itemCount) items in search results")
        
        // Use an index to track position
        var currentIndex = 0
        
        while !resultsContainer.isAtEnd {
            do {
                let itemDecoder = try resultsContainer.superDecoder()
                let resultContainer = try itemDecoder.container(keyedBy: TypeCodingKeys.self)
                let objectType = try resultContainer.decode(String.self, forKey: .object)
                
                print("Processing item \(currentIndex) of type: \(objectType)")
                
                // Decode based on object type using the same decoder
                switch objectType {
                case "database":
                    let database = try NotionDatabase(from: itemDecoder)
                    print("Successfully decoded database: \(database.id)")
                    resultsArray.append(database)
                case "page":
                    let page = try NotionPage(from: itemDecoder)
                    resultsArray.append(page)
                case "block":
                    let block = try NotionBlock(from: itemDecoder)
                    resultsArray.append(block)
                default:
                    print("Skipping unknown object type: \(objectType)")
                }
            } catch {
                print("Error decoding search result item at index \(currentIndex): \(error)")
            }
            
            currentIndex += 1
        }
        
        results = resultsArray
        print("Successfully decoded \(results.count) objects")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(object, forKey: .object)
        try container.encodeIfPresent(nextCursor, forKey: .nextCursor)
        try container.encode(hasMore, forKey: .hasMore)
        
        var resultsContainer = container.nestedUnkeyedContainer(forKey: .results)
        try results.forEach { result in
            switch result {
            case let database as NotionDatabase:
                try resultsContainer.encode(database)
            case let page as NotionPage:
                try resultsContainer.encode(page)
            case let block as NotionBlock:
                try resultsContainer.encode(block)
            default:
                break
            }
        }
    }
    
    private enum TypeCodingKeys: String, CodingKey {
        case object
    }
}

/// Response for block children operations
public struct NotionBlockChildrenResponse: Codable {
    public let object: String
    public let results: [NotionBlock]
    public let nextCursor: String?
    public let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

/// Response for user list operations
public struct NotionUserListResponse: Codable {
    public let object: String
    public let results: [NotionUser]
    public let nextCursor: String?
    public let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}
