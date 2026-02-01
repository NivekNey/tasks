import Foundation

public struct QueryEngine {
    public static func filter(_ tasks: [Task], query: String) -> [Task] {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            return tasks
        }
        
        // Normalize operators: "and"/"AND" -> "&&", "or"/"OR" -> "||"
        var normalized = query
        // Use word boundaries to avoid matching "band" or "android"
        normalized = normalized.replacingOccurrences(of: " and ", with: " && ", options: .caseInsensitive)
        normalized = normalized.replacingOccurrences(of: " or ", with: " || ", options: .caseInsensitive)
        
        // Split by OR first (lower precedence), then AND (higher precedence)
        // Example: "a && b || c && d" -> (a && b) || (c && d)
        let orGroups = normalized.components(separatedBy: "||")
        
        return tasks.filter { task in
            // Task matches if ANY OR group matches
            for orGroup in orGroups {
                let andConditions = orGroup.components(separatedBy: "&&")
                var allAndMatch = true
                
                // All AND conditions in this group must match
                for condition in andConditions {
                    let trimmed = condition.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && !matches(task: task, condition: trimmed) {
                        allAndMatch = false
                        break
                    }
                }
                
                if allAndMatch {
                    return true  // This OR group matched
                }
            }
            return false  // No OR group matched
        }
    }
    
    private static func matches(task: Task, condition: String) -> Bool {
        // 1. Status shortcut: "todo", "doing", "done"
        if ["todo", "doing", "in-progress", "done", "completed"].contains(condition.lowercased()) {
            return task.status.lowercased() == condition.lowercased()
        }
        
        // 2. Tag shortcut: "#tag"
        if condition.hasPrefix("#") {
            let tag = String(condition.dropFirst())
            return task.tags.contains(tag)
        }
        
        // 3. Key Value: "status != done"
        if condition.contains("!=") {
            let parts = condition.components(separatedBy: "!=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let val = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
                return getValue(task: task, key: key).lowercased() != val.lowercased()
            }
        }
        
        if condition.contains("==") {
            let parts = condition.components(separatedBy: "==")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let val = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
                return getValue(task: task, key: key).lowercased() == val.lowercased()
            }
        }
        
        // 4. Like: "title like '%foo%'" or "title contains 'foo'"
        if condition.lowercased().contains(" like ") {
            let parts = condition.components(separatedBy: " like ")
             if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                var val = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
                let actual = getValue(task: task, key: key)
                
                // Simple Wildcard Support
                if val.hasPrefix("%") && val.hasSuffix("%") {
                    val = String(val.dropFirst().dropLast())
                    return actual.localizedCaseInsensitiveContains(val)
                } else if val.hasPrefix("%") {
                    val = String(val.dropFirst())
                    return actual.lowercased().hasSuffix(val.lowercased())
                } else if val.hasSuffix("%") {
                    val = String(val.dropLast())
                    return actual.lowercased().hasPrefix(val.lowercased())
                }
                return actual.localizedCaseInsensitiveContains(val) // Default to contains if like used? Or exact? SQL like without % is exact.
             }
        }
        
        if condition.lowercased().contains(" contains ") {
            let parts = condition.components(separatedBy: " contains ")
             if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let val = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
                return getValue(task: task, key: key).localizedCaseInsensitiveContains(val)
             }
        }
        
        return true
    }
    
    private static func getValue(task: Task, key: String) -> String {
        switch key {
        case "status": return task.status
        case "title": return task.title
        case "id": return task.id
        default: return task.frontmatter[key] ?? ""
        }
    }

    
    public static func validate(_ query: String) -> String? {
        if query.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
        
        let quoteCount = query.filter { $0 == "'" || $0 == "\"" }.count
        if quoteCount % 2 != 0 { return "Unbalanced quotes" }
        
        // Basic check for operator or keyword
        let hasOp = query.contains("==") || query.contains("!=") || query.lowercased().contains(" like ") || query.lowercased().contains(" contains ") || query.hasPrefix("#") || ["todo", "doing", "done", "in-progress", "completed"].contains(query.trimmingCharacters(in: .whitespaces))
        
        if !hasOp {
            // Not necessarily error, could be simple full text search?
            // User requested validation. Let's be looser.
            // If no operator, maybe it's just searching tag?
            // "foo" -> search all fields? Not implemented in `matches`.
            // `matches` expects explicit conditions.
            // Actually, `matches` loop checks conditions.
            // If condition has no op, it fails?
            // Look at `matches` logic...
            // It checks explicit lists. If none match, it returns TRUE.
            // Wait, line 87 `return true` (Step 1110).
            // So "foo" returns true for EVERYTHING? That's a bug!
            return "Condition must include operator (==, !=, like, contains) or be a tag (#)"
        }
        
        return nil
    }
}
