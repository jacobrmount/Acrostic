// AcrostiKit/DataManagement/NotionTransformers.swift
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

@objc(NotionPropertyTransformer)
public final class NotionPropertyTransformer: ValueTransformer {
    public override class func transformedValueClass() -> AnyClass {
        return NSDictionary.self
    }
    
    public override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    public override func transformedValue(_ value: Any?) -> Any? {
        guard let properties = value as? [String: Any] else { return nil }
        
        do {
            // Use JSONSerialization for better performance than NSKeyedArchiver
            return try JSONSerialization.data(withJSONObject: properties, options: [])
        } catch {
            print("Error transforming property dictionary: \(error)")
            return nil
        }
    }
    
    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            print("Error reverse transforming property data: \(error)")
            return nil
        }
    }
    
    public static func register() {
        ValueTransformer.setValueTransformer(
            NotionPropertyTransformer(),
            forName: NSValueTransformerName(rawValue: "NotionPropertyTransformer")
        )
    }
}
