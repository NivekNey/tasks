import Foundation

public class SchemaEngine {
    private let engineState: EngineState
    
    public init(engineState: EngineState) {
        self.engineState = engineState
    }
    
    public func loadSchema(rootPath: String) -> WorkspaceSchema {
        let url = URL(fileURLWithPath: rootPath).appendingPathComponent("schema.json")
        var schema: WorkspaceSchema
        var needsSave = false
        
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                schema = try JSONDecoder().decode(WorkspaceSchema.self, from: data)
            } catch {
                print("SchemaEngine: Failed to load schema: \(error)")
                schema = WorkspaceSchema()
                needsSave = true
            }
        } else {
            schema = WorkspaceSchema()
            needsSave = true
        }
        
        // Sanitize: remove protected keys if they somehow got in
        for key in Task.protectedKeys {
            if schema.fields.removeValue(forKey: key) != nil {
                needsSave = true
            }
        }
        
        // Ensure status field exists with type categorical
        if schema.fields["status"] == nil {
            schema.fields["status"] = FieldConfig(type: .categorical, options: [
                "pending": OptionStyle(color: "gray"),
                "in-progress": OptionStyle(color: "blue"),
                "done": OptionStyle(color: "green")
            ])
            needsSave = true
        } else {
            // Ensure "done" option exists
            if schema.fields["status"]?.options["done"] == nil {
                schema.fields["status"]?.options["done"] = OptionStyle(color: "green")
                needsSave = true
            }
        }
        
        if needsSave {
            saveSchema(schema, rootPath: rootPath)
        }
        
        return schema
    }
    
    public func saveSchema(_ schema: WorkspaceSchema, rootPath: String) {
        let url = URL(fileURLWithPath: rootPath).appendingPathComponent("schema.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(schema)
            try data.write(to: url, options: .atomic)
        } catch {
            print("SchemaEngine: Failed to save schema: \(error)")
            engineState.setError("Failed to save schema.json")
        }
    }
    
    /// Discover all unique field keys across all tasks
    public func discoverFields(tasks: [Task]) -> Set<String> {
        var keys = Set<String>()
        for task in tasks {
            keys.formUnion(task.frontmatter.keys)
        }
        return keys.subtracting(Task.protectedKeys)
    }
    
    /// Discover all unique values for a specific field key across all tasks
    public func discoverValues(for key: String, in tasks: [Task]) -> Set<String> {
        var values = Set<String>()
        for task in tasks {
            if let val = task.frontmatter[key], !val.isEmpty {
                values.insert(val)
            }
        }
        return values
    }
    
    /// Aggregate all values for all categorical fields defined in the schema
    public func buildCatalogs(schema: WorkspaceSchema, tasks: [Task]) -> [String: Set<String>] {
        var catalogs: [String: Set<String>] = [:]
        for (key, config) in schema.fields where config.type == .categorical {
            var combined = Set(config.options.keys)
            combined.formUnion(discoverValues(for: key, in: tasks))
            catalogs[key] = combined
        }
        return catalogs
    }
}
