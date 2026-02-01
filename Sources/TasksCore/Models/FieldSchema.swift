import Foundation

public enum FieldType: String, Codable, CaseIterable {
    case text
    case categorical
    case url
}

public struct OptionStyle: Codable, Equatable, Hashable {
    public var color: String? // Name or Hex
    
    public init(color: String? = nil) {
        self.color = color
    }
}

public struct FieldConfig: Codable, Equatable {
    public var type: FieldType
    public var options: [String: OptionStyle]
    
    public init(type: FieldType = .text, options: [String: OptionStyle] = [:]) {
        self.type = type
        self.options = options
    }
}

public struct WorkspaceSchema: Codable, Equatable {
    public var fields: [String: FieldConfig]
    public var order: [String]
    
    public init(fields: [String: FieldConfig] = [:], order: [String] = []) {
        self.fields = fields
        self.order = order
    }
    
    enum CodingKeys: String, CodingKey {
        case fields
        case order
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fields = try container.decode([String: FieldConfig].self, forKey: .fields)
        order = try container.decodeIfPresent([String].self, forKey: .order) ?? []
    }
}
