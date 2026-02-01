import Foundation

/// Engine responsible for processing views: filtering, sorting, and materializing to files
/// Reacts to task index changes and view metadata changes
public class ViewProcessingEngine {
    private let dataSource: TaskDataSource
    private let engineState: EngineState
    
    public init(dataSource: TaskDataSource, engineState: EngineState) {
        self.dataSource = dataSource
        self.engineState = engineState
    }
    
    /// Process all views with given tasks
    public func processAll(views: [ViewConfig], tasks: [Task], rootPath: String) {
        let affectedViews = views.filter { $0.id != "all" }
        guard !affectedViews.isEmpty else {
            engineState.setIdle()
            return
        }
        
        for view in affectedViews {
            engineState.setBusy("Updating \(view.name)")
            materialize(view: view, tasks: tasks, rootPath: rootPath)
        }
        
        engineState.setIdle()
    }
    
    /// Check if view is affected by changed tasks
    public func shouldProcess(view: ViewConfig, changedTasks: [Task], allTasks: [Task]) -> Bool {
        // Always process if query is empty (shows all)
        if view.query.isEmpty { return true }
        
        // Check if any changed task matches or previously matched the query
        for task in changedTasks {
            if matchesQuery(task: task, query: view.query) {
                return true
            }
        }
        
        // Check if any changed task was previously in this view
        // (would need to track previous state - for now, always process)
        return true
    }
    
    /// Process only views affected by changed tasks
    public func processAffected(views: [ViewConfig], changedTasks: [Task], allTasks: [Task], rootPath: String) {
        let affectedViews = views.filter { view in
            view.id != "all" && shouldProcess(view: view, changedTasks: changedTasks, allTasks: allTasks)
        }
        
        guard !affectedViews.isEmpty else {
            engineState.setIdle()
            return
        }
        
        for view in affectedViews {
            engineState.setBusy("Updating \(view.name)")
            materialize(view: view, tasks: allTasks, rootPath: rootPath)
        }
        
        engineState.setIdle()
    }
    
    /// Filter and sort tasks for a view
    public func filterAndSort(view: ViewConfig, tasks: [Task]) -> [Task] {
        var filtered = tasks
        
        // Apply query filter (case-insensitive)
        if !view.query.isEmpty {
            filtered = filtered.filter { matchesQuery(task: $0, query: view.query) }
        }
        
        // Apply sort (case-insensitive)
        filtered = applySort(tasks: filtered, sort: view.sort)
        
        return filtered
    }
    
    /// Generate markdown table content
    public func generateTable(tasks: [Task], columns: [String]) -> String {
        guard !columns.isEmpty else { return "" }
        
        // Header row
        let headers = columns.map { $0.capitalized }
        var table = "| " + headers.joined(separator: " | ") + " |\n"
        table += "|" + columns.map { _ in "---" }.joined(separator: "|") + "|\n"
        
        // Data rows
        for task in tasks {
            let values = columns.map { col -> String in
                switch col.lowercased() {
                case "title": return task.title
                case "status": return task.statusLabel
                case "created": return formatDate(task.created)
                case "tags": return task.tags.joined(separator: ", ")
                case "phase": return task.phase
                default: return task.frontmatter[col] ?? ""
                }
            }
            table += "| " + values.joined(separator: " | ") + " |\n"
        }
        
        return table
    }
    
    /// Materialize a view to its file
    public func materialize(view: ViewConfig, tasks: [Task], rootPath: String) {
        let filtered = filterAndSort(view: view, tasks: tasks)
        let table = generateTable(tasks: filtered, columns: view.columns)
        
        // Build file content
        // Note: name is NOT saved in frontmatter - it's derived from filename
        var output = "---\n"
        output += "type: \"view\"\n"
        
        // Escape query for storage
        let escapedQuery = view.query.replacingOccurrences(of: "\"", with: "\\\"")
        output += "query: \"\(escapedQuery)\"\n"
        
        if !view.sort.isEmpty {
            output += "sort: [\"\(view.sort.joined(separator: "\", \""))\"]\n"
        }
        
        let cleanCols = view.columns.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !cleanCols.isEmpty {
            let colsStr = cleanCols.map { "\"\($0)\"" }.joined(separator: ", ")
            output += "columns: [\(colsStr)]\n"
        }
        
        output += "---\n"
        output += "# \(view.name)\n\n"
        output += table
        
        // Write to file
        let fileURL = URL(fileURLWithPath: view.path)
        try? output.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Private Helpers
    
    private func matchesQuery(task: Task, query: String) -> Bool {
        // Simple query parsing: "field == 'value'" or "field contains 'value'"
        // All comparisons are case-insensitive
        
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.isEmpty { return true }
        
        // Parse "priority == 'high'" style queries
        if let match = parseComparison(query) {
            let fieldValue = getFieldValue(task: task, field: match.field).lowercased()
            let compareValue = match.value.lowercased()
            
            switch match.op {
            case "==", "=":
                return fieldValue == compareValue
            case "!=":
                return fieldValue != compareValue
            case "contains":
                return fieldValue.contains(compareValue)
            default:
                return false
            }
        }
        
        // Fallback: simple text search across all fields
        let searchText = trimmed
        return task.title.lowercased().contains(searchText) ||
               task.status.lowercased().contains(searchText) ||
               task.tags.joined(separator: " ").lowercased().contains(searchText)
    }
    
    private func parseComparison(_ query: String) -> (field: String, op: String, value: String)? {
        // Match patterns like: priority == 'high' or status != 'done'
        let operators = ["==", "!=", "=", "contains"]
        
        for op in operators {
            if query.contains(op) {
                let parts = query.components(separatedBy: op)
                if parts.count == 2 {
                    let field = parts[0].trimmingCharacters(in: .whitespaces)
                    var value = parts[1].trimmingCharacters(in: .whitespaces)
                    // Remove quotes
                    value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    return (field, op, value)
                }
            }
        }
        
        return nil
    }
    
    private func getFieldValue(task: Task, field: String) -> String {
        switch field.lowercased() {
        case "title": return task.title
        case "status": return task.status
        case "phase": return task.phase
        case "priority": return task.frontmatter["priority"] ?? ""
        default: return task.frontmatter[field] ?? ""
        }
    }
    
    private func applySort(tasks: [Task], sort: [String]) -> [Task] {
        guard !sort.isEmpty else { return tasks }
        
        return tasks.sorted { a, b in
            for sortSpec in sort {
                let parts = sortSpec.split(separator: " ")
                let field = String(parts.first ?? "").lowercased()
                let descending = parts.count > 1 && parts[1].lowercased() == "desc"
                
                let aVal = getSortValue(task: a, field: field)
                let bVal = getSortValue(task: b, field: field)
                
                if aVal != bVal {
                    return descending ? aVal > bVal : aVal < bVal
                }
            }
            return false
        }
    }
    
    private func getSortValue(task: Task, field: String) -> String {
        switch field {
        case "title": return task.title.lowercased()
        case "status": return task.status.lowercased()
        case "created": return ISO8601DateFormatter().string(from: task.created)
        case "phase": return task.phase
        default: return (task.frontmatter[field] ?? "").lowercased()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
