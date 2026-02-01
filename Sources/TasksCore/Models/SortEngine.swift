import Foundation

public struct SortEngine {
    public static func sort(_ tasks: [Task], by descriptors: [String]) -> [Task] {
        if descriptors.isEmpty { return tasks }
        
        return tasks.sorted { t1, t2 in
            for desc in descriptors {
                let parts = desc.components(separatedBy: " ")
                let key = parts[0]
                let order = parts.count > 1 ? parts[1] : "asc"
                
                let v1 = getValue(task: t1, key: key)
                let v2 = getValue(task: t2, key: key)
                
                if v1 != v2 {
                    if order == "desc" {
                        return v1 > v2
                    } else {
                        return v1 < v2
                    }
                }
            }
            return false // Equal
        }
    }
    
    // TODO: Support Date comparison and Numbers correctly. Currently String compare.
    private static func getValue(task: Task, key: String) -> String {
        switch key {
        case "created": return ISO8601DateFormatter().string(from: task.created)
        case "status": return task.status
        case "title": return task.title
        default: return task.frontmatter[key] ?? ""
        }
    }

    
    public static func validate(_ tasks: [Task], descriptors: [String]) -> [String] {
        var errors: [String] = []
        // Known keys + keys present in at least ONE task
        let knownKeys = Set(["id", "title", "status", "created", "content", "path", "tags"])
        var availableKeys = knownKeys
        
        // Optimisation: Scan until all descriptors found? Or just scan first 100?
        // Full scan ensures accuracy.
        for task in tasks {
            availableKeys.formUnion(task.frontmatter.keys)
        }
        
        for desc in descriptors {
            let key = desc.components(separatedBy: " ")[0]
            if !availableKeys.contains(key) {
                errors.append("Sort key not found: '\(key)'")
            }
        }
        return errors
    }
}
