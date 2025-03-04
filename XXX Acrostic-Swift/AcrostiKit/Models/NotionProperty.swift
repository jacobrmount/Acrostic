// Models/NotionProperty.swift
import Foundation

// Define NotionProperty class to support NotionPropertyItemResponse
public class NotionProperty: Codable {
    public let id: String
    public let type: String
    public let name: String?
    public let value: JSONAny
    
    enum CodingKeys: String, CodingKey {
        case id, type, name, value
    }
    
    public init(id: String, type: String, name: String? = nil, value: JSONAny) {
        self.id = id
        self.type = type
        self.name = name
        self.value = value
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        value = try container.decode(JSONAny.self, forKey: .value)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(value, forKey: .value)
    }
}
