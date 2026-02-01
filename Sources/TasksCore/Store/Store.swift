import Foundation
import SwiftUI

public class Store: ObservableObject {
    @Published public var tasks: [Task] = []
    @Published public var views: [ViewConfig] = []
    @Published public var schema: WorkspaceSchema = WorkspaceSchema()
    @Published public var fieldCatalogs: [String: Set<String>] = [:]
    
    /// Per-view column width settings: [viewId: [columnName: width]]
    /// This is in-memory state only - not persisted to disk
    @Published public var columnWidths: [String: [String: CGFloat]] = [:]
    
    // Engine State
    public let engineState = EngineState()
    
    // Derived: specific tags
    public var tags: [String] {
        let allTags = tasks.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    // Derived: all unique schema field keys (excludes protected internal keys)
    public var allFieldKeys: [String] {
        let allKeys = Set(schema.fields.keys)
        let protected = Set(Task.protectedKeys.map { $0.lowercased() })
        
        // 1. Start with ordered keys that still exist and aren't protected
        var result = schema.order.filter { allKeys.contains($0) && !protected.contains($0.lowercased()) }
        
        // 2. Add remaining keys (sorted)
        let remaining = allKeys.subtracting(result).filter { !protected.contains($0.lowercased()) }.sorted()
        result.append(contentsOf: remaining)
        
        return result
    }
    
    public func discoverFields() -> Set<String> {
        return schemaEngine.discoverFields(tasks: tasks)
    }
    
    // MARK: - Dependencies
    private let dataSource: TaskDataSource
    private let fileWatcher: FileWatcher
    private let taskIndexEngine: TaskIndexEngine
    private let viewProcessingEngine: ViewProcessingEngine
    private let schemaEngine: SchemaEngine
    
    public init(dataSource: TaskDataSource = FileSystemDataSource(), fileWatcher: FileWatcher = FileWatcher()) {
        self.dataSource = dataSource
        self.fileWatcher = fileWatcher
        self.taskIndexEngine = TaskIndexEngine(dataSource: dataSource, engineState: engineState)
        self.viewProcessingEngine = ViewProcessingEngine(dataSource: dataSource, engineState: engineState)
        self.schemaEngine = SchemaEngine(engineState: engineState)
    }
    
    // Old loadAll removed

    
    public func toggleStatus(task: Task) {
        let newStatus = (task.status == "done" || task.status == "completed") ? "todo" : "done"
        let newTask = task.with(status: newStatus)
        updateTask(newTask)
    }
    
    /// Checks if a filename already exists in tasks or views directories
    public func filenameExists(_ filename: String, excludingPath: String? = nil) -> Bool {
        guard let root = currentRootPath else { return false }
        
        let tasksPath = URL(fileURLWithPath: root).appendingPathComponent("tasks").appendingPathComponent(filename).path
        let viewsPath = URL(fileURLWithPath: root).appendingPathComponent("views").appendingPathComponent(filename).path
        
        let fm = FileManager.default
        let tasksExists = fm.fileExists(atPath: tasksPath) && tasksPath != excludingPath
        let viewsExists = fm.fileExists(atPath: viewsPath) && viewsPath != excludingPath
        
        return tasksExists || viewsExists
    }
    
    public func createTask(title: String = "Untitled") {
        guard let root = self.currentRootPath else { return }
        
        // Validate title length
        let validTitle = String(title.prefix(Task.maxTitleLength))
        
        // Generate filename from title
        var filename = Task.filenameFromTitle(validTitle)
        
        // Handle duplicates by appending number
        var counter = 1
        while filenameExists(filename) {
            let baseName = validTitle.isEmpty ? "Untitled" : validTitle
            filename = Task.filenameFromTitle("\(baseName) \(counter)")
            counter += 1
        }
        
        let date = Date()
        let formatter = ISO8601DateFormatter()
        let dateStr = formatter.string(from: date)
        
        let path = URL(fileURLWithPath: root).appendingPathComponent("tasks").appendingPathComponent(filename).path
        
        let newTask = Task(
            title: Task.titleFromFilename(filename), 
            status: "todo",
            created: date,
            done: nil,
            tags: [],
            path: path,
            content: "",
            frontmatter: [
                "status": "todo",
                "created": dateStr
            ]
        )
        
        self.engineState.setBusy("Creating \(filename)...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.dataSource.saveTask(newTask)
            self?.engineState.setIdle()
        }
    }

    public func updateTask(_ task: Task) {
        guard let root = currentRootPath else { return }
        
        // Check if title changed (filename needs to change)
        let newFilename = task.derivedFilename
        let currentFilename = URL(fileURLWithPath: task.path).lastPathComponent
        let titleChanged = newFilename != currentFilename
        
        var updatedTask = task
        var needsRename = false
        
        if titleChanged {
            // Validate new filename doesn't conflict
            if filenameExists(newFilename, excludingPath: task.path) {
                engineState.setError("A file named '\(newFilename)' already exists")
                return
            }
            
            // Update path
            let newPath = URL(fileURLWithPath: root).appendingPathComponent("tasks").appendingPathComponent(newFilename).path
            updatedTask = Task(
                title: task.title,
                status: task.status,
                created: task.created,
                done: task.done,
                tags: task.tags,
                path: newPath,
                content: task.content,
                frontmatter: task.frontmatter
            )
            needsRename = true
        }
        
        // Optimistic Update
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = updatedTask
        }
        self.fieldCatalogs = schemaEngine.buildCatalogs(schema: schema, tasks: tasks)
        
        // Persist
        self.engineState.setBusy("Saving \(newFilename)...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Delete old file if renamed
            if needsRename {
                try? FileManager.default.removeItem(atPath: task.path)
            }
            self?.dataSource.saveTask(updatedTask)
            self?.engineState.setIdle()
        }
    }
    
    public func deleteTask(id: String) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks.remove(at: index)
        }
        
        self.engineState.setBusy("Deleting \(task.title)...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.dataSource.deleteTask(path: task.path)
            self?.engineState.setIdle()
        }
    }
    
    public func deleteView(id: String) {
        guard id != "all", let config = views.first(where: { $0.id == id }) else { return }
        
        if let index = views.firstIndex(where: { $0.id == id }) {
            views.remove(at: index)
        }
        
        self.engineState.setBusy("Deleting \(config.name)...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.dataSource.deleteView(path: config.path)
            self?.engineState.setIdle()
        }
    }
    
    public func saveView(_ config: ViewConfig) {
        // Prevent saving "all" view if we accidentally tried to (it shouldn't be editable though)
        if config.id == "all" { return }
        guard let root = self.currentRootPath else { return }
        
        // Derive the correct path from the view name
        let viewsDir = URL(fileURLWithPath: root).appendingPathComponent("views")
        let expectedPath = viewsDir.appendingPathComponent(config.derivedFilename).path
        
        // If the path doesn't match (i.e., view was renamed), delete the old file
        let oldPath = config.path
        let needsRename = oldPath != expectedPath && !oldPath.isEmpty && FileManager.default.fileExists(atPath: oldPath)
        
        // Create updated config with correct path
        var updatedConfig = config
        updatedConfig.path = expectedPath
        updatedConfig.id = expectedPath
        
        // Update local state optimistically
        if let index = views.firstIndex(where: { $0.id == config.id }) {
            views[index] = updatedConfig
        } else if let index = views.firstIndex(where: { $0.name == config.name }) {
             // Fallback to name match for new views or renames
             views[index] = updatedConfig
        } else {
             views.append(updatedConfig)
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Delete old file if renamed
            if needsRename {
                try? FileManager.default.removeItem(atPath: oldPath)
            }
            
            // Materialize the view (writes metadata + markdown table to file)
            self.viewProcessingEngine.materialize(view: updatedConfig, tasks: self.tasks, schema: self.schema, rootPath: root)
        }
    }
    
    public func saveSchema(_ schema: WorkspaceSchema) {
        guard let root = currentRootPath else { return }
        self.schema = schema
        schemaEngine.saveSchema(schema, rootPath: root)
        self.fieldCatalogs = schemaEngine.buildCatalogs(schema: schema, tasks: tasks)
    }
    
    public func createView(name: String) {
        guard let root = self.currentRootPath else { return }
        
        // Create a temporary config to get the derived filename
        let tempConfig = ViewConfig(
            id: "", 
            name: name, 
            query: "", 
            sort: ["created desc"], 
            path: ""
        )
        
        let viewsDir = URL(fileURLWithPath: root).appendingPathComponent("views")
        let path = viewsDir.appendingPathComponent(tempConfig.derivedFilename).path
        
        let config = ViewConfig(
            id: path, 
            name: name, 
            query: "", 
            sort: ["created desc"], 
            path: path
        )
        saveView(config)
    }
    
    private var currentRootPath: String?
    
    public func loadAll(rootPath: String) {
        self.currentRootPath = rootPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Step 1: Index all tasks using TaskIndexEngine
            let tasks = self.taskIndexEngine.indexAll(rootPath: rootPath)
            
            // Step 2: Load view configs and schema
            let views = self.dataSource.loadViews(rootPath: rootPath)
            let schema = self.schemaEngine.loadSchema(rootPath: rootPath)
            let catalogs = self.schemaEngine.buildCatalogs(schema: schema, tasks: tasks)
            
            DispatchQueue.main.async {
                self.tasks = tasks
                self.views = views
                self.schema = schema
                self.fieldCatalogs = catalogs
            }
            
            // Step 3: Process all views (materialize tables)
            self.viewProcessingEngine.processAll(views: views, tasks: tasks, schema: schema, rootPath: rootPath)
            
            // Step 4: Start watching for task changes ONLY
            // Note: We do NOT watch views/ because views are OUTPUT files.
            // The ViewProcessingEngine writes to views/, so watching would cause infinite loop.
            // View metadata changes come through UI (ViewSettingsView), not file system.
            let tasksPath = rootPath + "/tasks"
            
            self.fileWatcher.watch(path: tasksPath) { [weak self] in
                guard let self = self else { return }
                // Re-index
                let updatedTasks = self.taskIndexEngine.indexAll(rootPath: rootPath)
                
                // Only update and re-process if something actually changed on disk 
                // compared to our in-memory state.
                if updatedTasks != self.tasks {
                    let catalogs = self.schemaEngine.buildCatalogs(schema: self.schema, tasks: updatedTasks)
                    DispatchQueue.main.async {
                        self.tasks = updatedTasks
                        self.fieldCatalogs = catalogs
                    }
                    self.viewProcessingEngine.processAll(views: self.views, tasks: updatedTasks, schema: self.schema, rootPath: rootPath)
                }
            }
        }
    }
    
    public func stopWatching() {
        fileWatcher.stopAll()
    }

}
