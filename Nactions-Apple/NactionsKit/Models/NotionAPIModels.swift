// Models/NotionAPIModels.swift
import Foundation

// MARK: - Common Types

/// A type-erased wrapper for JSON values
public class JSONAny: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([JSONAny].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: JSONAny].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode JSONAny")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self.value {
        case is NSNull:
            try container.encodeNil()
        case let value as Bool:
            try container.encode(value)
        case let value as Int:
            try container.encode(value)
        case let value as Double:
            try container.encode(value)
        case let value as String:
            try container.encode(value)
        case let value as [Any]:
            try container.encode(value.map { JSONAny($0) })
        case let value as [String: Any]:
            try container.encode(value.mapValues { JSONAny($0) })
        default:
            throw EncodingError.invalidValue(self.value, EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Unable to encode JSONAny"
            ))
        }
    }
    
    public var dictionary: [String: Any]? {
        return value as? [String: Any]
    }
}

// MARK: - Rich Text

public class NotionRichText: Codable {
    public let plainText: String
    public let annotations: NotionAnnotations?
    public let href: String?
    
    public init(plainText: String, annotations: NotionAnnotations? = nil, href: String? = nil) {
        self.plainText = plainText
        self.annotations = annotations
        self.href = href
    }
    
    enum CodingKeys: String, CodingKey {
        case plainText = "plain_text"
        case annotations
        case href
    }
}

public class NotionAnnotations: Codable {
    public let bold: Bool?
    public let italic: Bool?
    public let strikethrough: Bool?
    public let underline: Bool?
    public let code: Bool?
    public let color: String?
    
    public init(bold: Bool? = nil, italic: Bool? = nil, strikethrough: Bool? = nil, underline: Bool? = nil, code: Bool? = nil, color: String? = nil) {
        self.bold = bold
        self.italic = italic
        self.strikethrough = strikethrough
        self.underline = underline
        self.code = code
        self.color = color
    }
}

// MARK: - Icon and Cover
public class NotionIcon: Codable {
    public let type: String
    public let emoji: String?
    public let file: NotionFileDetails?
    public let external: NotionExternalFile?
    
    enum CodingKeys: String, CodingKey {
        case type, emoji, file, external
    }
    
    public init(type: String, emoji: String? = nil, file: NotionFileDetails? = nil, external: NotionExternalFile? = nil) {
        self.type = type
        self.emoji = emoji
        self.file = file
        self.external = external
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
        file = try container.decodeIfPresent(NotionFileDetails.self, forKey: .file)
        external = try container.decodeIfPresent(NotionExternalFile.self, forKey: .external)
    }
}

public class NotionCover: Codable {
    public let type: String
    public let file: NotionFileDetails?
    public let external: NotionExternalFile?
    
    enum CodingKeys: String, CodingKey {
        case type, file, external
    }
    
    public init(type: String, file: NotionFileDetails? = nil, external: NotionExternalFile? = nil) {
        self.type = type
        self.file = file
        self.external = external
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        file = try container.decodeIfPresent(NotionFileDetails.self, forKey: .file)
        external = try container.decodeIfPresent(NotionExternalFile.self, forKey: .external)
    }
}

// MARK: - Database

public class NotionDatabase: Codable {
    public let object: String
    public let id: String
    public let createdTime: Date?
    public let lastEditedTime: Date?
    public let title: [NotionRichText]?
    public let description: [NotionRichText]?
    public let properties: [String: NotionPropertySchema]?
    public let url: String?
    public let parent: NotionParent?
    
    enum CodingKeys: String, CodingKey {
        case object, id, url, parent, properties
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case title, description
    }
    
    public init(object: String, id: String, createdTime: Date? = nil, lastEditedTime: Date? = nil, title: [NotionRichText]? = nil, description: [NotionRichText]? = nil, properties: [String: NotionPropertySchema]? = nil, url: String? = nil, parent: NotionParent? = nil) {
        self.object = object
        self.id = id
        self.createdTime = createdTime
        self.lastEditedTime = lastEditedTime
        self.title = title
        self.description = description
        self.properties = properties
        self.url = url
        self.parent = parent
    }
}

// MARK: - Page

// Convert this from struct to class to avoid infinite size issues
public class NotionPage: Codable {
    public let object: String
    public let id: String
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
        case object, id, url, parent, archived, properties
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case createdBy = "created_by"
        case lastEditedBy = "last_edited_by"
        case cover, icon
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        object = try container.decode(String.self, forKey: .object)
        id = try container.decode(String.self, forKey: .id)
        createdTime = try container.decodeIfPresent(Date.self, forKey: .createdTime)
        lastEditedTime = try container.decodeIfPresent(Date.self, forKey: .lastEditedTime)
        createdBy = try container.decodeIfPresent(NotionUser.self, forKey: .createdBy)
        lastEditedBy = try container.decodeIfPresent(NotionUser.self, forKey: .lastEditedBy)
        cover = try container.decodeIfPresent(NotionCover.self, forKey: .cover)
        icon = try container.decodeIfPresent(NotionIcon.self, forKey: .icon)
        parent = try container.decodeIfPresent(NotionParent.self, forKey: .parent)
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived)
        properties = try container.decodeIfPresent([String: NotionPropertyValue].self, forKey: .properties)
        url = try container.decodeIfPresent(String.self, forKey: .url)
    }
    
    // Custom initializer
    public init(object: String, id: String, createdTime: Date?, lastEditedTime: Date?, createdBy: NotionUser?, lastEditedBy: NotionUser?, cover: NotionCover?, icon: NotionIcon?, parent: NotionParent?, archived: Bool?, properties: [String: JSONAny], url: String?) {
        self.object = object
        self.id = id
        self.createdTime = createdTime
        self.lastEditedTime = lastEditedTime
        self.createdBy = createdBy
        self.lastEditedBy = lastEditedBy
        self.cover = cover
        self.icon = icon
        self.parent = parent
        self.archived = archived
        self.properties = properties.mapValues { NotionPropertyValue($0) }
        self.url = url
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(object, forKey: .object)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(createdTime, forKey: .createdTime)
        try container.encodeIfPresent(lastEditedTime, forKey: .lastEditedTime)
        try container.encodeIfPresent(createdBy, forKey: .createdBy)
        try container.encodeIfPresent(lastEditedBy, forKey: .lastEditedBy)
        try container.encodeIfPresent(cover, forKey: .cover)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(parent, forKey: .parent)
        try container.encodeIfPresent(archived, forKey: .archived)
        try container.encodeIfPresent(properties, forKey: .properties)
        try container.encodeIfPresent(url, forKey: .url)
    }
}

// MARK: - Parent Reference

public class NotionParent: Codable {
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

// MARK: - Property Schema

public class NotionPropertySchema: Codable {
    public let id: String
    public let name: String
    public let type: String
    public let config: JSONAny?
    
    enum CodingKeys: String, CodingKey {
        case id, name, type
        case config
    }
    
    public init(id: String, name: String, type: String, config: JSONAny? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.config = config
    }
}

// MARK: - Property Value
public class NotionPropertyValue: Codable {
    public let id: String
    public let type: String
    public let value: JSONAny
    
    public init(_ jsonAny: JSONAny) {
        self.id = ""
        self.type = ""
        self.value = jsonAny
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        
        // Decode based on property type
        if let title = try? container.decode([NotionRichText].self, forKey: .title) {
            value = JSONAny(["title": title])
        } else if let richText = try? container.decode([NotionRichText].self, forKey: .richText) {
            value = JSONAny(["rich_text": richText])
        } else if let number = try? container.decode(Double.self, forKey: .number) {
            value = JSONAny(["number": number])
        } else if let select = try? container.decode(NotionSelect.self, forKey: .select) {
            value = JSONAny(["select": select])
        } else if let multiSelect = try? container.decode([NotionSelect].self, forKey: .multiSelect) {
            value = JSONAny(["multi_select": multiSelect])
        } else if let date = try? container.decode(NotionDate.self, forKey: .date) {
            value = JSONAny(["date": date])
        } else if let checkbox = try? container.decode(Bool.self, forKey: .checkbox) {
            value = JSONAny(["checkbox": checkbox])
        } else if let url = try? container.decode(String.self, forKey: .url) {
            value = JSONAny(["url": url])
        } else if let email = try? container.decode(String.self, forKey: .email) {
            value = JSONAny(["email": email])
        } else if let phoneNumber = try? container.decode(String.self, forKey: .phoneNumber) {
            value = JSONAny(["phone_number": phoneNumber])
        } else if let formula = try? container.decode(NotionFormula.self, forKey: .formula) {
            value = JSONAny(["formula": formula])
        } else if let relation = try? container.decode([NotionRelation].self, forKey: .relation) {
            value = JSONAny(["relation": relation])
        } else if let rollup = try? container.decode(NotionRollup.self, forKey: .rollup) {
            value = JSONAny(["rollup": rollup])
        } else if let people = try? container.decode([NotionUser].self, forKey: .people) {
            value = JSONAny(["people": people])
        } else if let files = try? container.decode([NotionFile].self, forKey: .files) {
            value = JSONAny(["files": files])
        } else {
            // Default - if we can't match a specific type
            value = JSONAny([:])
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        
        // Handle encoding based on property type
        if let dict = value.value as? [String: Any], let propertyValue = dict[type] {
            switch type {
            case "title":
                if let title = propertyValue as? [NotionRichText] {
                    try container.encode(title, forKey: .title)
                }
            case "rich_text":
                if let richText = propertyValue as? [NotionRichText] {
                    try container.encode(richText, forKey: .richText)
                }
            case "number":
                if let number = propertyValue as? Double {
                    try container.encode(number, forKey: .number)
                }
            case "select":
                if let select = propertyValue as? NotionSelect {
                    try container.encode(select, forKey: .select)
                }
            case "multi_select":
                if let multiSelect = propertyValue as? [NotionSelect] {
                    try container.encode(multiSelect, forKey: .multiSelect)
                }
            case "date":
                if let date = propertyValue as? NotionDate {
                    try container.encode(date, forKey: .date)
                }
            case "checkbox":
                if let checkbox = propertyValue as? Bool {
                    try container.encode(checkbox, forKey: .checkbox)
                }
            case "url":
                if let url = propertyValue as? String {
                    try container.encode(url, forKey: .url)
                }
            case "email":
                if let email = propertyValue as? String {
                    try container.encode(email, forKey: .email)
                }
            case "phone_number":
                if let phoneNumber = propertyValue as? String {
                    try container.encode(phoneNumber, forKey: .phoneNumber)
                }
            case "formula":
                if let formula = propertyValue as? NotionFormula {
                    try container.encode(formula, forKey: .formula)
                }
            case "relation":
                if let relation = propertyValue as? [NotionRelation] {
                    try container.encode(relation, forKey: .relation)
                }
            case "rollup":
                if let rollup = propertyValue as? NotionRollup {
                    try container.encode(rollup, forKey: .rollup)
                }
            case "people":
                if let people = propertyValue as? [NotionUser] {
                    try container.encode(people, forKey: .people)
                }
            case "files":
                if let files = propertyValue as? [NotionFile] {
                    try container.encode(files, forKey: .files)
                }
            default:
                break
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type
        case title
        case richText = "rich_text"
        case number
        case select
        case multiSelect = "multi_select"
        case date
        case checkbox
        case url
        case email
        case phoneNumber = "phone_number"
        case formula
        case relation
        case rollup
        case people
        case files
        case createdBy = "created_by"
        case createdTime = "created_time"
        case lastEditedBy = "last_edited_by"
        case lastEditedTime = "last_edited_time"
    }
}

// MARK: - Property Type Models

public class NotionSelect: Codable {
    public let id: String?
    public let name: String
    public let color: String?
    
    public init(id: String? = nil, name: String, color: String? = nil) {
        self.id = id
        self.name = name
        self.color = color
    }
}

public class NotionDate: Codable {
    public let start: String
    public let end: String?
    public let timeZone: String?
    
    enum CodingKeys: String, CodingKey {
        case start, end
        case timeZone = "time_zone"
    }
    
    public init(start: String, end: String? = nil, timeZone: String? = nil) {
        self.start = start
        self.end = end
        self.timeZone = timeZone
    }
}

public class NotionFormula: Codable {
    public let type: String
    public let value: JSONAny
    
    public init(type: String, value: JSONAny) {
        self.type = type
        self.value = value
    }
}

public class NotionRelation: Codable {
    public let id: String
    
    public init(id: String) {
        self.id = id
    }
}

public class NotionRollup: Codable {
    public let type: String
    public let value: JSONAny
    
    public init(type: String, value: JSONAny) {
        self.type = type
        self.value = value
    }
}

public class NotionFile: Codable {
    public let name: String
    public let type: String
    public let file: NotionFileDetails?
    public let external: NotionExternalFile?
    
    public init(name: String, type: String, file: NotionFileDetails? = nil, external: NotionExternalFile? = nil) {
        self.name = name
        self.type = type
        self.file = file
        self.external = external
    }
}

public class NotionFileDetails: Codable {
    public let url: String
    public let expiryTime: Date?
    
    enum CodingKeys: String, CodingKey {
        case url
        case expiryTime = "expiry_time"
    }
    
    public init(url: String, expiryTime: Date? = nil) {
        self.url = url
        self.expiryTime = expiryTime
    }
}

public class NotionExternalFile: Codable {
    public let url: String
    
    public init(url: String) {
        self.url = url
    }
}

// MARK: - Block

public class NotionBlock: Codable {
    public let object: String
    public let id: String
    public let parent: NotionBlockParent?
    public let createdTime: Date?
    public let lastEditedTime: Date?
    public let createdBy: NotionUser?
    public let lastEditedBy: NotionUser?
    public let hasChildren: Bool
    public let archived: Bool
    public let type: String
    public let blockContent: JSONAny?
    
    enum CodingKeys: String, CodingKey {
        case object, id, parent, hasChildren = "has_children", archived, type
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case createdBy = "created_by"
        case lastEditedBy = "last_edited_by"
        // Dynamic keys for block content types
        case paragraph, heading_1, heading_2, heading_3, callout, quote,
             bulleted_list_item, numbered_list_item, to_do, toggle, code,
             embed, image, video, file, pdf, bookmark, equation, divider,
             table_of_contents, breadcrumb, column_list, column, link_preview,
             synced_block, template, link_to_page, table, table_row, child_page,
             child_database, unsupported
    }
    
    public init(object: String, id: String, parent: NotionBlockParent?, createdTime: Date?, lastEditedTime: Date?, createdBy: NotionUser?, lastEditedBy: NotionUser?, hasChildren: Bool, archived: Bool, type: String, blockContent: JSONAny?) {
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
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        object = try container.decode(String.self, forKey: .object)
        id = try container.decode(String.self, forKey: .id)
        parent = try container.decodeIfPresent(NotionBlockParent.self, forKey: .parent)
        createdTime = try container.decodeIfPresent(Date.self, forKey: .createdTime)
        lastEditedTime = try container.decodeIfPresent(Date.self, forKey: .lastEditedTime)
        createdBy = try container.decodeIfPresent(NotionUser.self, forKey: .createdBy)
        lastEditedBy = try container.decodeIfPresent(NotionUser.self, forKey: .lastEditedBy)
        hasChildren = try container.decode(Bool.self, forKey: .hasChildren)
        archived = try container.decode(Bool.self, forKey: .archived)
        type = try container.decode(String.self, forKey: .type)
        
        // Decode the block content based on the type
        switch type {
        case "paragraph":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .paragraph)
        case "heading_1":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .heading_1)
        case "heading_2":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .heading_2)
        case "heading_3":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .heading_3)
        case "callout":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .callout)
        case "quote":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .quote)
        case "bulleted_list_item":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .bulleted_list_item)
        case "numbered_list_item":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .numbered_list_item)
        case "to_do":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .to_do)
        case "toggle":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .toggle)
        case "code":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .code)
        case "embed":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .embed)
        case "image":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .image)
        case "video":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .video)
        case "file":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .file)
        case "pdf":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .pdf)
        case "bookmark":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .bookmark)
        case "equation":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .equation)
        case "divider":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .divider)
        case "table_of_contents":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .table_of_contents)
        case "breadcrumb":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .breadcrumb)
        case "column_list":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .column_list)
        case "column":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .column)
        case "link_preview":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .link_preview)
        case "synced_block":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .synced_block)
        case "template":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .template)
        case "link_to_page":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .link_to_page)
        case "table":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .table)
        case "table_row":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .table_row)
        case "child_page":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .child_page)
        case "child_database":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .child_database)
        case "unsupported":
            blockContent = try container.decodeIfPresent(JSONAny.self, forKey: .unsupported)
        default:
            blockContent = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(object, forKey: .object)
        try container.encode(id, forKey: .id)
        try container.encode(parent, forKey: .parent)
        try container.encodeIfPresent(createdTime, forKey: .createdTime)
        try container.encodeIfPresent(lastEditedTime, forKey: .lastEditedTime)
        try container.encodeIfPresent(createdBy, forKey: .createdBy)
        try container.encodeIfPresent(lastEditedBy, forKey: .lastEditedBy)
        try container.encode(hasChildren, forKey: .hasChildren)
        try container.encode(archived, forKey: .archived)
        try container.encode(type, forKey: .type)
        
        // Encode the block content based on the type
        switch type {
        case "paragraph":
            try container.encodeIfPresent(blockContent, forKey: .paragraph)
        case "heading_1":
            try container.encodeIfPresent(blockContent, forKey: .heading_1)
        case "heading_2":
            try container.encodeIfPresent(blockContent, forKey: .heading_2)
        case "heading_3":
            try container.encodeIfPresent(blockContent, forKey: .heading_3)
        case "callout":
            try container.encodeIfPresent(blockContent, forKey: .callout)
        case "quote":
            try container.encodeIfPresent(blockContent, forKey: .quote)
        case "bulleted_list_item":
            try container.encodeIfPresent(blockContent, forKey: .bulleted_list_item)
        case "numbered_list_item":
            try container.encodeIfPresent(blockContent, forKey: .numbered_list_item)
        case "to_do":
            try container.encodeIfPresent(blockContent, forKey: .to_do)
        case "toggle":
            try container.encodeIfPresent(blockContent, forKey: .toggle)
        case "code":
            try container.encodeIfPresent(blockContent, forKey: .code)
        case "embed":
            try container.encodeIfPresent(blockContent, forKey: .embed)
        case "image":
            try container.encodeIfPresent(blockContent, forKey: .image)
        case "video":
            try container.encodeIfPresent(blockContent, forKey: .video)
        case "file":
            try container.encodeIfPresent(blockContent, forKey: .file)
        case "pdf":
            try container.encodeIfPresent(blockContent, forKey: .pdf)
        case "bookmark":
            try container.encodeIfPresent(blockContent, forKey: .bookmark)
        case "equation":
            try container.encodeIfPresent(blockContent, forKey: .equation)
        case "divider":
            try container.encodeIfPresent(blockContent, forKey: .divider)
        case "table_of_contents":
            try container.encodeIfPresent(blockContent, forKey: .table_of_contents)
        case "breadcrumb":
            try container.encodeIfPresent(blockContent, forKey: .breadcrumb)
        case "column_list":
            try container.encodeIfPresent(blockContent, forKey: .column_list)
        case "column":
            try container.encodeIfPresent(blockContent, forKey: .column)
        case "link_preview":
            try container.encodeIfPresent(blockContent, forKey: .link_preview)
        case "synced_block":
            try container.encodeIfPresent(blockContent, forKey: .synced_block)
        case "template":
            try container.encodeIfPresent(blockContent, forKey: .template)
        case "link_to_page":
            try container.encodeIfPresent(blockContent, forKey: .link_to_page)
        case "table":
            try container.encodeIfPresent(blockContent, forKey: .table)
        case "table_row":
            try container.encodeIfPresent(blockContent, forKey: .table_row)
        case "child_page":
            try container.encodeIfPresent(blockContent, forKey: .child_page)
        case "child_database":
            try container.encodeIfPresent(blockContent, forKey: .child_database)
        case "unsupported":
            try container.encodeIfPresent(blockContent, forKey: .unsupported)
        default:
            break
        }
    }
}

public struct NotionBlockParent: Codable {
    public let type: String
    public let pageID: String?
    public let databaseID: String?
    public let workspaceID: String?
    public let blockID: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case pageID = "page_id"
        case databaseID = "database_id"
        case workspaceID = "workspace_id"
        case blockID = "block_id"
    }
    
    public init(type: String, pageID: String? = nil, databaseID: String? = nil, workspaceID: String? = nil, blockID: String? = nil) {
        self.type = type
        self.pageID = pageID
        self.databaseID = databaseID
        self.workspaceID = workspaceID
        self.blockID = blockID
    }
}

// MARK: - User

public class NotionUser: Codable {
    public let object: String
    public let id: String
    public let name: String?
    public let email: String?
    public let type: String?
    public let avatarURL: String?
    public let bot: NotionBot?
    public let person: NotionPerson?
    
    enum CodingKeys: String, CodingKey {
        case object, id, name, type, email, bot, person
        case avatarURL = "avatar_url"
    }
    
    public init(object: String, id: String, name: String? = nil, email: String? = nil, type: String? = nil, avatarURL: String? = nil, bot: NotionBot? = nil, person: NotionPerson? = nil) {
        self.object = object
        self.id = id
        self.name = name
        self.email = email
        self.type = type
        self.avatarURL = avatarURL
        self.bot = bot
        self.person = person
    }
}

public class NotionBot: Codable {
    public let owner: NotionBotOwner?
    public let workspaceID: String?
    
    enum CodingKeys: String, CodingKey {
        case owner
        case workspaceID = "workspace_id"
    }
    
    public init(owner: NotionBotOwner? = nil, workspaceID: String? = nil) {
        self.owner = owner
        self.workspaceID = workspaceID
    }
}

public class NotionBotOwner: Codable {
    public let type: String
    public let user: NotionUser?
    public let workspace: Bool?
    
    public init(type: String, user: NotionUser? = nil, workspace: Bool? = nil) {
        self.type = type
        self.user = user
        self.workspace = workspace
    }
}

public class NotionPerson: Codable {
    public let email: String?
    
    public init(email: String? = nil) {
        self.email = email
    }
}

// MARK: - Comment

public class NotionComment: Codable {
    public let object: String
    public let id: String
    public let parentType: String?
    public let parentID: String?
    public let discussionID: String?
    public let richText: [NotionRichText]
    public let createdTime: Date
    public let lastEditedTime: Date?
    public let createdBy: NotionUser
    
    enum CodingKeys: String, CodingKey {
        case object, id, discussionID = "discussion_id"
        case parentType = "parent_type"
        case parentID = "parent_id"
        case richText = "rich_text"
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case createdBy = "created_by"
    }
    
    public init(object: String, id: String, parentType: String? = nil, parentID: String? = nil, discussionID: String? = nil, richText: [NotionRichText], createdTime: Date, lastEditedTime: Date? = nil, createdBy: NotionUser) {
        self.object = object
        self.id = id
        self.parentType = parentType
        self.parentID = parentID
        self.discussionID = discussionID
        self.richText = richText
        self.createdTime = createdTime
        self.lastEditedTime = lastEditedTime
        self.createdBy = createdBy
    }
}

// MARK: - Response Objects

public class NotionSearchResponse: Codable {
    public let object: String
    public let results: [NotionObject]
    public let nextCursor: String?
    public let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
    
    public init(object: String, results: [NotionObject], nextCursor: String? = nil, hasMore: Bool) {
        self.object = object
        self.results = results
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

public class NotionObject: Codable {
    public let object: String
    public let id: String
    
    public init(object: String, id: String) {
        self.object = object
        self.id = id
    }
}

public class NotionQueryDatabaseResponse: Codable {
    public let object: String
    public let results: [NotionPage]
    public let nextCursor: String?
    public let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
    
    public init(object: String, results: [NotionPage], nextCursor: String? = nil, hasMore: Bool) {
        self.object = object
        self.results = results
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

public class NotionPropertyItemResponse: Codable {
    public let object: String
    public let results: [NotionProperty]
    public let nextCursor: String?
    public let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
    
    public init(object: String, results: [NotionProperty], nextCursor: String? = nil, hasMore: Bool) {
        self.object = object
        self.results = results
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

public class NotionBlockChildrenResponse: Codable {
    public let object: String
    public let results: [NotionBlock]
    public let nextCursor: String?
    public let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
    
    public init(object: String, results: [NotionBlock], nextCursor: String? = nil, hasMore: Bool) {
        self.object = object
        self.results = results
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

public class NotionCommentListResponse: Codable {
    public let object: String
    public let results: [NotionComment]
    public let nextCursor: String?
    public let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
    
    public init(object: String, results: [NotionComment], nextCursor: String? = nil, hasMore: Bool) {
        self.object = object
        self.results = results
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

public class NotionUserListResponse: Codable {
    public let object: String
    public let results: [NotionUser]
    public let nextCursor: String?
    public let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
    
    public init(object: String, results: [NotionUser], nextCursor: String? = nil, hasMore: Bool) {
        self.object = object
        self.results = results
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

// MARK: - Request Objects

public class NotionSearchFilter: Codable {
    public var property: String
    public var value: String
    public var type: String?
    
    // Default initializer
    public init() {
        self.property = ""
        self.value = ""
        self.type = nil
    }
    
    // Required decoder initializer for Codable
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        property = try container.decode(String.self, forKey: .property)
        value = try container.decode(String.self, forKey: .value)
        type = try container.decodeIfPresent(String.self, forKey: .type)
    }
    
    // Dictionary representation for API calls
    public var dictionaryRepresentation: [String: Any] {
        var result: [String: Any] = [:]
        result["property"] = property
        result["value"] = value
        if let type = type {
            result["type"] = type
        }
        return result
    }
    
    // CodingKeys for Codable
    private enum CodingKeys: String, CodingKey {
        case property, value, type
    }
}
