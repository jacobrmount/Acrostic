// Models/NotionRequestModels.swift
import Foundation

// MARK: - Search Models

public struct NotionSearchSort: Codable {
    public let property: String
    public let direction: String
    
    public init(property: String, direction: String = "ascending") {
        self.property = property
        self.direction = direction
    }
    
    public var dictionary: [String: Any] {
        return [
            "property": property,
            "direction": direction
        ]
    }
}

// MARK: - Query Models

public struct NotionQueryDatabaseRequest: Codable {
    public let sorts: [NotionQuerySort]?
    public let filter: [String: Any]?
    public let pageSize: Int?
    public let startCursor: String?
    
    public init(sorts: [NotionQuerySort]? = nil, filter: [String: Any]? = nil, pageSize: Int? = nil, startCursor: String? = nil) {
        self.sorts = sorts
        self.filter = filter
        self.pageSize = pageSize
        self.startCursor = startCursor
    }
    
    private enum CodingKeys: String, CodingKey {
        case sorts, filter
        case pageSize = "page_size"
        case startCursor = "start_cursor"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(sorts, forKey: .sorts)
        
        // We need special handling for the filter since it's a dynamic dictionary
        if let filter = filter, !filter.isEmpty {
            let filterData = try JSONSerialization.data(withJSONObject: filter)
            let decoder = JSONDecoder()
            if let jsonAny = try? decoder.decode(JSONAny.self, from: filterData) {
                try container.encode(jsonAny, forKey: .filter)
            }
        }
        
        try container.encodeIfPresent(pageSize, forKey: .pageSize)
        try container.encodeIfPresent(startCursor, forKey: .startCursor)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sorts = try container.decodeIfPresent([NotionQuerySort].self, forKey: .sorts)
        
        // Handle the filter
        if let filterJSONAny = try? container.decodeIfPresent(JSONAny.self, forKey: .filter),
           let filterDict = filterJSONAny.value as? [String: Any] {
            filter = filterDict
        } else {
            filter = nil
        }
        
        pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize)
        startCursor = try container.decodeIfPresent(String.self, forKey: .startCursor)
    }
}

public struct NotionQuerySort: Codable {
    public let property: String
    public let direction: String
    
    public init(property: String, direction: String = "ascending") {
        self.property = property
        self.direction = direction
    }
}

// MARK: - Create/Update Models

public struct NotionCreatePageRequest: Codable {
    public let parent: NotionParent
    public let properties: [String: JSONAny]
    public let children: [NotionBlock]?
    
    enum CodingKeys: String, CodingKey {
        case parent, properties, children
    }
}

public struct NotionCreateDatabaseRequest: Codable {
    public let parent: NotionParent
    public let title: [NotionRichText]?
    public let description: [NotionRichText]?
    public let properties: [String: JSONAny]
    
    enum CodingKeys: String, CodingKey {
        case parent, title, description, properties
    }
}

public struct NotionUpdateDatabaseRequest: Codable {
    public let title: [NotionRichText]?
    public let description: [NotionRichText]?
    public let properties: [String: JSONAny]?
    
    enum CodingKeys: String, CodingKey {
        case title, description, properties
    }
}

// This is the updated version of NotionUpdateBlockRequest that should conform to Decodable

public struct NotionUpdateBlockRequest: Codable {
    public let type: String?
    public let content: JSONAny?
    public let archived: Bool?
    
    public init(type: String? = nil, content: JSONAny? = nil, archived: Bool? = nil) {
        self.type = type
        self.content = content
        self.archived = archived
    }
    
    enum CodingKeys: String, CodingKey {
        case type, archived
        // Dynamic keys for block content
        case paragraph, heading_1, heading_2, heading_3, callout, quote,
             bulleted_list_item, numbered_list_item, to_do, toggle, code,
             embed, image, video, file, pdf, bookmark, equation, divider,
             table_of_contents, breadcrumb, column_list, column, link_preview,
             synced_block, template, link_to_page, table, table_row, child_page,
             child_database, unsupported
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(archived, forKey: .archived)
        
        // Encode content based on block type
        if let type = type, let content = content {
            switch type {
            case "paragraph":
                try container.encode(content, forKey: .paragraph)
            case "heading_1":
                try container.encode(content, forKey: .heading_1)
            case "heading_2":
                try container.encode(content, forKey: .heading_2)
            case "heading_3":
                try container.encode(content, forKey: .heading_3)
            case "callout":
                try container.encode(content, forKey: .callout)
            case "quote":
                try container.encode(content, forKey: .quote)
            case "bulleted_list_item":
                try container.encode(content, forKey: .bulleted_list_item)
            case "numbered_list_item":
                try container.encode(content, forKey: .numbered_list_item)
            case "to_do":
                try container.encode(content, forKey: .to_do)
            case "toggle":
                try container.encode(content, forKey: .toggle)
            case "code":
                try container.encode(content, forKey: .code)
            case "embed":
                try container.encode(content, forKey: .embed)
            case "image":
                try container.encode(content, forKey: .image)
            case "video":
                try container.encode(content, forKey: .video)
            case "file":
                try container.encode(content, forKey: .file)
            case "pdf":
                try container.encode(content, forKey: .pdf)
            case "bookmark":
                try container.encode(content, forKey: .bookmark)
            case "equation":
                try container.encode(content, forKey: .equation)
            case "divider":
                try container.encode(content, forKey: .divider)
            case "table_of_contents":
                try container.encode(content, forKey: .table_of_contents)
            case "breadcrumb":
                try container.encode(content, forKey: .breadcrumb)
            case "column_list":
                try container.encode(content, forKey: .column_list)
            case "column":
                try container.encode(content, forKey: .column)
            case "link_preview":
                try container.encode(content, forKey: .link_preview)
            case "synced_block":
                try container.encode(content, forKey: .synced_block)
            case "template":
                try container.encode(content, forKey: .template)
            case "link_to_page":
                try container.encode(content, forKey: .link_to_page)
            case "table":
                try container.encode(content, forKey: .table)
            case "table_row":
                try container.encode(content, forKey: .table_row)
            case "child_page":
                try container.encode(content, forKey: .child_page)
            case "child_database":
                try container.encode(content, forKey: .child_database)
            default:
                break
            }
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        type = try container.decodeIfPresent(String.self, forKey: .type)
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived)
        
        // Try to determine content type from available containers
        if let type = type {
            switch type {
            case "paragraph":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .paragraph)
            case "heading_1":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .heading_1)
            case "heading_2":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .heading_2)
            case "heading_3":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .heading_3)
            case "callout":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .callout)
            case "quote":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .quote)
            case "bulleted_list_item":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .bulleted_list_item)
            case "numbered_list_item":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .numbered_list_item)
            case "to_do":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .to_do)
            case "toggle":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .toggle)
            case "code":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .code)
            case "embed":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .embed)
            case "image":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .image)
            case "video":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .video)
            case "file":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .file)
            case "pdf":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .pdf)
            case "bookmark":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .bookmark)
            case "equation":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .equation)
            case "divider":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .divider)
            case "table_of_contents":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .table_of_contents)
            case "breadcrumb":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .breadcrumb)
            case "column_list":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .column_list)
            case "column":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .column)
            case "link_preview":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .link_preview)
            case "synced_block":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .synced_block)
            case "template":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .template)
            case "link_to_page":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .link_to_page)
            case "table":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .table)
            case "table_row":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .table_row)
            case "child_page":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .child_page)
            case "child_database":
                content = try container.decodeIfPresent(JSONAny.self, forKey: .child_database)
            default:
                content = nil
            }
        } else {
            content = nil
        }
    }
}
public struct NotionAppendBlockChildrenRequest: Codable {
    public let children: [NotionBlock]
    public let after: String?
    
    public init(children: [NotionBlock], after: String? = nil) {
        self.children = children
        self.after = after
    }
}

public struct NotionCreateCommentRequest: Codable {
    public let parent: NotionCommentParent?
    public let discussionID: String?
    public let richText: [NotionRichText]
    
    enum CodingKeys: String, CodingKey {
        case parent
        case discussionID = "discussion_id"
        case richText = "rich_text"
    }
}

public struct NotionCommentParent: Codable {
    public let type: String
    public let pageID: String?
    public let blockID: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case pageID = "page_id"
        case blockID = "block_id"
    }
}

public struct NotionCreateTokenRequest: Codable {
    public let grantType: String
    public let code: String
    public let redirectURI: String?
    
    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case code
        case redirectURI = "redirect_uri"
    }
}

public struct NotionCreateTokenResponse: Codable {
    public let accessToken: String
    public let tokenType: String
    public let botID: String
    public let workspaceID: String
    public let workspaceName: String
    public let workspaceIcon: String?
    public let ownerID: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case botID = "bot_id"
        case workspaceID = "workspace_id"
        case workspaceName = "workspace_name"
        case workspaceIcon = "workspace_icon"
        case ownerID = "owner_id"
    }
}

// MARK: - View Models

public struct DatabaseViewModel: Identifiable {
    public let id: String
    public let title: String
    public let tokenID: UUID
    public let tokenName: String
    public let isSelected: Bool
    public let lastUpdated: Date
    
    public init(id: String, title: String, tokenID: UUID, tokenName: String, isSelected: Bool, lastUpdated: Date) {
        self.id = id
        self.title = title
        self.tokenID = tokenID
        self.tokenName = tokenName
        self.isSelected = isSelected
        self.lastUpdated = lastUpdated
    }
}
