import Foundation

public struct Task: Identifiable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let status: String
    public let created: Date
    public let done: Date?
    public let tags: [String]
    public let path: String
    public let content: String
    public let frontmatter: [String: String]
    
    /// Keys that represent internal task properties and have dedicated UI columns.
    /// Note: "status" is NOT protected—it's managed via schema.json and user-customizable.
    public static let protectedKeys = Set(["id", "title", "created", "done", "completed", "elapsed", "tags", "completed_at", "due"])
    
    // MARK: - Title ↔ Filename Conversion
    
    /// Maximum title length (enforced on input)
    public static let maxTitleLength = 50
    
    /// Converts a title to a filename (e.g., "Buy Milk" → "Buy-Milk.md")
    /// Literal dashes in title become double dashes: "High-Priority" → "High--Priority.md"
    public static func filenameFromTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "Untitled.md" }
        
        // Step 1: Escape literal dashes with double dash
        let escapedDashes = trimmed.replacingOccurrences(of: "-", with: "--")
        // Step 2: Replace spaces with single dash
        let slugified = escapedDashes.replacingOccurrences(of: " ", with: "-")
        // Step 3: Remove special characters except dashes
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let cleaned = slugified.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(cleaned))
        
        return (result.isEmpty ? "Untitled" : result) + ".md"
    }
    
    /// Converts a filename to a title (e.g., "Buy-Milk.md" → "Buy Milk")
    /// Double dashes become literal dash: "High--Priority.md" → "High-Priority"
    public static func titleFromFilename(_ filename: String) -> String {
        // Remove .md extension
        var name = filename
        if name.hasSuffix(".md") {
            name = String(name.dropLast(3))
        }
        
        // Step 1: Replace double dashes with placeholder
        let placeholder = "\u{FFFF}"
        let withPlaceholder = name.replacingOccurrences(of: "--", with: placeholder)
        // Step 2: Replace single dashes with spaces
        let withSpaces = withPlaceholder.replacingOccurrences(of: "-", with: " ")
        // Step 3: Restore literal dashes from placeholder
        let result = withSpaces.replacingOccurrences(of: placeholder, with: "-")
        
        return result.isEmpty ? "Untitled" : result
    }
    
    /// Derives filename from this task's title
    public var derivedFilename: String {
        Task.filenameFromTitle(title)
    }
    
    // MARK: - Phase Mapping
    
    /// Extracts the core phase from status (e.g., "prog:review" → "prog")
    /// Core phases: todo, prog, done
    public var phase: String {
        let parts = status.split(separator: ":", maxSplits: 1)
        let rawPhase = String(parts.first ?? "todo").lowercased()
        
        // Normalize common aliases
        switch rawPhase {
        case "done", "completed": return "done"
        case "prog", "in-progress", "doing", "progress": return "prog"
        default: return "todo"
        }
    }
    
    /// Extracts the display label from status (e.g., "prog:review" → "Review")
    /// Falls back to the raw status if no label present
    public var statusLabel: String {
        let parts = status.split(separator: ":", maxSplits: 1)
        if parts.count == 2 {
            // Has label: "prog:review" → "Review"
            return String(parts[1])
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        } else {
            // No label: use status as-is
            return status.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }
    
    // MARK: - Initialization
    
    public init(path: String, fileContent: String) {
        self.path = path
        let parsed = Task.parseFrontmatter(fileContent)
        self.frontmatter = parsed.frontmatter
        self.content = parsed.content
        
        self.id = frontmatter["id"] ?? UUID().uuidString
        
        // Title is derived from filename, NOT from frontmatter
        let filename = URL(fileURLWithPath: path).lastPathComponent
        self.title = Task.titleFromFilename(filename)
        
        self.status = frontmatter["status"] ?? "todo"
        
        if let createdStr = frontmatter["created"] {
            // ISO8601 is default for most
            if let date = ISO8601DateFormatter().date(from: createdStr) {
                 self.created = date
            } else {
                 self.created = Date() // Fallback
            }
        } else {
            self.created = Date()
        }
        
        if let doneStr = frontmatter["done"] ?? frontmatter["completed"] {
            self.done = ISO8601DateFormatter().date(from: doneStr)
        } else {
            self.done = nil
        }
        
        if let tagsStr = frontmatter["tags"] {
             // Simple parsing for ["a", "b"]
             let cleaned = tagsStr.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
             self.tags = cleaned.split(separator: ",").map { 
                 $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
             }
        } else {
            self.tags = []
        }
    }
    
    // Helper to create modified copy
    public func with(status: String? = nil, title: String? = nil, content: String? = nil) -> Task {
        // We need to initialize a new Task, but Task init parses from string.
        // It might be better to have a private memberwise init or just reconstruct content?
        // Let's rely on internal properties for now, but since "frontmatter" is source of truth, 
        // we should probably update frontmatter dictionary.
        
        var newFm = self.frontmatter
        var newStatus = self.status
        var newDone = self.done
        
        if let s = status { 
            newStatus = s
            newFm["status"] = s 
            
            // Automatic done date tracking
            let oldPhase = self.phase
            let parts = s.split(separator: ":", maxSplits: 1)
            let rawPhase = String(parts.first ?? "todo").lowercased()
            let newPhase: String
            switch rawPhase {
            case "done", "completed": newPhase = "done"
            case "prog", "in-progress", "doing", "progress": newPhase = "prog"
            default: newPhase = "todo"
            }
            
            if newPhase == "done" && oldPhase != "done" {
                // Just completed
                let now = Date()
                newDone = now
                newFm["done"] = ISO8601DateFormatter().string(from: now)
            } else if newPhase != "done" && oldPhase == "done" {
                // Moved out of done
                newDone = nil
                newFm.removeValue(forKey: "done")
                newFm.removeValue(forKey: "completed")
            }
        }
        if let t = title { newFm["title"] = t }
        
        return Task(
            id: self.id,
            title: title ?? self.title,
            status: newStatus,
            created: self.created,
            done: newDone,
            tags: self.tags,
            path: self.path,
            content: content ?? self.content,
            frontmatter: newFm
        )
    }
    
    // Memberwise init for internal/copy use
    private init(id: String, title: String, status: String, created: Date, done: Date?, tags: [String], path: String, content: String, frontmatter: [String: String]) {
        self.id = id
        self.title = title
        self.status = status
        self.created = created
        self.done = done
        self.tags = tags
        self.path = path
        self.content = content
        self.frontmatter = frontmatter
    }
    
    // Public memberwise init for creation
    public init(id: String, title: String, status: String, created: Date, done: Date?, tags: [String], path: String, content: String, frontmatter: [String: String], publicInit: Bool = true) {
        self.id = id
        self.title = title
        self.status = status
        self.created = created
        self.done = done
        self.tags = tags
        self.path = path
        self.content = content
        self.frontmatter = frontmatter
    }
    
    static func parseFrontmatter(_ content: String) -> (frontmatter: [String: String], content: String) {
        let lines = content.components(separatedBy: .newlines)
        var frontmatter: [String: String] = [:]
        var bodyLines: [String] = []
        var inFrontmatter = false
        var foundStart = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                if !foundStart {
                    foundStart = true
                    inFrontmatter = true
                    continue
                } else if inFrontmatter {
                    inFrontmatter = false
                    continue
                }
            }
            
            if inFrontmatter {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    var rawValue = parts[1].trimmingCharacters(in: .whitespaces)
                    
                    // Only strip matching outer quotes (not all quotes)
                    if rawValue.hasPrefix("\"") && rawValue.hasSuffix("\"") && rawValue.count >= 2 {
                        rawValue = String(rawValue.dropFirst().dropLast())
                    }
                    
                    // Unescape internal escaped quotes
                    let value = rawValue.replacingOccurrences(of: "\\\"", with: "\"")
                    frontmatter[key] = value
                }
            } else {
                bodyLines.append(line)
            }
        }
        
        return (frontmatter, bodyLines.joined(separator: "\n"))
    }
}
