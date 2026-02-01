import Foundation

public struct ViewConfig: Identifiable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var query: String
    public var sort: [String]
    public var columns: [String]
    public var path: String
    
    // MARK: - Name ↔ Filename Conversion (same as Task)
    
    /// Maximum name length (enforced on input)
    public static let maxNameLength = 50
    
    /// Converts a name to a filename (e.g., "High Priority" → "High-Priority.md")
    public static func filenameFromName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "Untitled.md" }
        
        // Escape literal dashes with double dash
        let escapedDashes = trimmed.replacingOccurrences(of: "-", with: "--")
        // Replace spaces with single dash
        let slugified = escapedDashes.replacingOccurrences(of: " ", with: "-")
        // Remove special characters except dashes
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let cleaned = slugified.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(cleaned))
        
        return (result.isEmpty ? "Untitled" : result) + ".md"
    }
    
    /// Converts a filename to a name (e.g., "High-Priority.md" → "High Priority")
    public static func nameFromFilename(_ filename: String) -> String {
        var name = filename
        if name.hasSuffix(".md") {
            name = String(name.dropLast(3))
        }
        
        // Double dashes → placeholder → restore as literal dash
        let placeholder = "\u{FFFF}"
        let withPlaceholder = name.replacingOccurrences(of: "--", with: placeholder)
        let withSpaces = withPlaceholder.replacingOccurrences(of: "-", with: " ")
        let result = withSpaces.replacingOccurrences(of: placeholder, with: "-")
        
        return result.isEmpty ? "Untitled" : result
    }
    
    /// Derives filename from this view's name
    public var derivedFilename: String {
        ViewConfig.filenameFromName(name)
    }
    
    // MARK: - Initialization
    
    // Init from file content - name derived from filename
    public init(path: String, fileContent: String) {
        self.path = path
        let parsed = Task.parseFrontmatter(fileContent)
        let fm = parsed.frontmatter
        
        self.id = path
        
        // Name is derived from filename, NOT from frontmatter
        let filename = URL(fileURLWithPath: path).lastPathComponent
        self.name = ViewConfig.nameFromFilename(filename)
        
        self.query = fm["query"] ?? ""
        
        // Parse Sort ["field desc"]
        if let sortStr = fm["sort"] {
             let cleaned = sortStr.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
             self.sort = cleaned.split(separator: ",").map { 
                 $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
             }
        } else {
            self.sort = []
        }
        
        // Parse Columns
        if let colStr = fm["columns"] {
             let cleaned = colStr.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
             self.columns = cleaned.split(separator: ",").map { 
                 $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
             }
        } else {
             self.columns = ["title", "status"]
        }
    }
    
    // Memberwise init
    public init(id: String, name: String, query: String, sort: [String], columns: [String], path: String) {
        self.id = id
        self.name = name
        self.query = query
        self.sort = sort
        self.columns = columns
        self.path = path
    }
}
