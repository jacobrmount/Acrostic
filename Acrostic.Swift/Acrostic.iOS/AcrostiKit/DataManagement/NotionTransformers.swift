// NactionsKit/DataManagement/NotionTransformers.swift
import Foundation

@objc(RichTextTransformer)
public final class RichTextTransformer: NSSecureUnarchiveFromDataTransformer {
    public static let name = NSValueTransformerName(rawValue: "RichTextTransformer")
    
    override public static var allowedTopLevelClasses: [AnyClass] {
        return [NSArray.self, NSDictionary.self, NSString.self]
    }
    
    public static func register() {
        let transformer = RichTextTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
}

@objc(NotionPropertiesTransformer)
public final class NotionPropertiesTransformer: NSSecureUnarchiveFromDataTransformer {
    public static let name = NSValueTransformerName(rawValue: "NotionPropertiesTransformer")
    
    override public static var allowedTopLevelClasses: [AnyClass] {
        return [NSDictionary.self]
    }
    
    public static func register() {
        let transformer = NotionPropertiesTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
}
