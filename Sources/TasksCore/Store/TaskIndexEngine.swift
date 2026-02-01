import Foundation

/// Engine responsible for indexing task files into in-memory store
/// Reacts to file changes and provides incremental updates
public class TaskIndexEngine {
    private let dataSource: TaskDataSource
    private let engineState: EngineState
    private var indexedTasks: [String: Task] = [:] // path -> Task
    
    public init(dataSource: TaskDataSource, engineState: EngineState) {
        self.dataSource = dataSource
        self.engineState = engineState
    }
    
    /// Full index of all tasks in a directory (on app start)
    public func indexAll(rootPath: String) -> [Task] {
        let tasksDir = URL(fileURLWithPath: rootPath).appendingPathComponent("tasks")
        let fm = FileManager.default
        
        var paths: [URL] = []
        if let enumerator = fm.enumerator(at: tasksDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "md" {
                    paths.append(fileURL)
                }
            }
        }
        
        guard !paths.isEmpty else {
            engineState.setIdle()
            return []
        }
        
        let total = paths.count
        engineState.startOperation("Indexing", total: total)
        
        var results: [Task] = []
        for (index, fileURL) in paths.enumerated() {
            let filename = fileURL.lastPathComponent
            engineState.updateProgress("Indexing \(filename)", current: index + 1, total: total)
            
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                // Optimization: If content hasn't changed, reuse the existing task object
                if let existing = indexedTasks[fileURL.path], existing.content == content {
                    // Check frontmatter keys too? Task(path:fileContent:) parses everything.
                    // If content is same, task is effectively same (since ID/Title etc are in content/filename)
                    results.append(existing)
                } else {
                    let task = Task(path: fileURL.path, fileContent: content)
                    results.append(task)
                    indexedTasks[fileURL.path] = task
                }
            }
        }
        
        engineState.setIdle()
        return results
    }
    
    /// Incremental index for changed files only
    /// Returns (updatedTasks, deletedPaths)
    public func indexChanged(rootPath: String, changedPaths: [String]) -> (updated: [Task], deleted: [String]) {
        guard !changedPaths.isEmpty else { return ([], []) }
        
        let total = changedPaths.count
        engineState.startOperation("Indexing", total: total)
        
        var updated: [Task] = []
        var deleted: [String] = []
        let fm = FileManager.default
        
        for (index, path) in changedPaths.enumerated() {
            let filename = URL(fileURLWithPath: path).lastPathComponent
            engineState.updateProgress("Indexing \(filename)", current: index + 1, total: total)
            
            if fm.fileExists(atPath: path) {
                // File exists - update or add
                if let content = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8) {
                    let task = Task(path: path, fileContent: content)
                    updated.append(task)
                    indexedTasks[path] = task
                }
            } else {
                // File deleted
                deleted.append(path)
                indexedTasks.removeValue(forKey: path)
            }
        }
        
        engineState.setIdle()
        return (updated, deleted)
    }
    
    /// Get currently indexed task by path
    public func getTask(path: String) -> Task? {
        return indexedTasks[path]
    }
    
    /// Get all indexed tasks
    public var allTasks: [Task] {
        return Array(indexedTasks.values)
    }
}
