import Foundation

public struct FileSystemDataSource: TaskDataSource {
    public init() {}
    
    public func loadTasks(rootPath: String) -> [Task] {
        let tasksDir = URL(fileURLWithPath: rootPath).appendingPathComponent("tasks")
        var results: [Task] = []
        let fm = FileManager.default
        
        if let enumerator = fm.enumerator(at: tasksDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "md" {
                    if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                        let task = Task(path: fileURL.path, fileContent: content)
                         results.append(task)
                    }
                }
            }
        }
        return results
    }
    
    public func loadViews(rootPath: String) -> [ViewConfig] {
        let viewsDir = URL(fileURLWithPath: rootPath).appendingPathComponent("views")
        var results: [ViewConfig] = []
        let fm = FileManager.default
        
        if let enumerator = fm.enumerator(at: viewsDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
               if fileURL.pathExtension == "md" {
                    if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                        let view = ViewConfig(path: fileURL.path, fileContent: content)
                         results.append(view)
                    }
                }
            }
        }
        return results
    }
    
    public func saveTask(_ task: Task) {
        // Construct file content
        // Note: title is NOT saved in frontmatter - it's derived from filename
        var output = "---\n"
        output += "id: \"\(task.id)\"\n"
        output += "status: \"\(task.status)\"\n"
        output += "created: \"\(ISO8601DateFormatter().string(from: task.created))\"\n"
        
        if !task.tags.isEmpty {
            let tagsStr = task.tags.map { "\"\($0)\"" }.joined(separator: ", ")
            output += "tags: [\(tagsStr)]\n"
        }
        
        // Add other frontmatter (excluding title which is in filename)
        for (key, value) in task.frontmatter {
             if !["id", "title", "status", "created", "tags"].contains(key) {
                 output += "\(key): \"\(value)\"\n"
             }
        }
        
        output += "---\n"
        output += task.content
        
        let fileURL = URL(fileURLWithPath: task.path)
        try? output.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    public func saveView(_ view: ViewConfig) {
        var output = "---\n"
        output += "type: \"view\"\n"
        output += "name: \"\(view.name)\"\n"
        // Escape internal quotes so YAML parses correctly
        let escapedQuery = view.query.replacingOccurrences(of: "\"", with: "\\\"")
        output += "query: \"\(escapedQuery)\"\n"
        if !view.sort.isEmpty {
             output += "sort: [\"\(view.sort.joined(separator: "\", \""))\"]\n"
        }
        
        // Sanitize columns: remove empties
        let cleanCols = view.columns.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !cleanCols.isEmpty {
            let colsStr = cleanCols.map { "\"\($0)\"" }.joined(separator: ", ")
            output += "columns: [\(colsStr)]\n"
        }
        
        output += "---\n"
        output += "# \(view.name)\n"
        
        let fileURL = URL(fileURLWithPath: view.path)
        try? output.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    public func deleteTask(path: String) {
        let fileURL = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    public func deleteView(path: String) {
        let fileURL = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
