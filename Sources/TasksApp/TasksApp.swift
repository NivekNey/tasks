import SwiftUI
import TasksCore

@main
struct TasksApp: App {
    @StateObject private var store = Store()
    
    // Dynamic path relative to user's home directory
    let rootPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("my-tasks").path 
    
    init() {
        print("TasksApp: Initializing...")
        // Ensure the app is a regular app (with Dock icon)
        NSApplication.shared.setActivationPolicy(.regular)
        // Bring to front
        NSApplication.shared.activate(ignoringOtherApps: true)
        print("TasksApp: Activated")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 600, minHeight: 400)
                .onAppear {
                    // Create directories if needed
                    let fm = FileManager.default
                    let rootURL = URL(fileURLWithPath: rootPath)
                    let tasksURL = rootURL.appendingPathComponent("tasks")
                    let viewsURL = rootURL.appendingPathComponent("views")
                    
                    try? fm.createDirectory(at: tasksURL, withIntermediateDirectories: true)
                    try? fm.createDirectory(at: viewsURL, withIntermediateDirectories: true)
                    
                    store.loadAll(rootPath: rootPath)
                }
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: Store
    @State private var selectedViewId: String? = "all"
    @State private var selectedTag: String? // Unused directly, mapped via viewId
    @State private var selectedTaskId: String?
    
    // Computed with side-effects (not ideal but quick) or validation hook
    // Let's separate derivation and validation.
    
    func validateCurrentView(tasks: [Task]) {
        guard let id = selectedViewId, id != "all", !id.hasPrefix("tag:") else { 
            // "all" or valid tag
            return 
        }
        
        guard let config = store.views.first(where: { $0.id == id }) else { return }
        
        // 1. Validate Query
        if let error = QueryEngine.validate(config.query) {
             store.engineState.setError("Error: \(error)")
             return
        }
        
        // 2. Validate Sort
        let sortErrors = SortEngine.validate(tasks, descriptors: config.sort)
        if let first = sortErrors.first {
             store.engineState.setError("Error: \(first)")
             return
        }
        
        // Success
        store.engineState.setIdle()
    }

    var filteredTasks: [Task] {
        guard let id = selectedViewId else { return store.tasks }
        var result = store.tasks
        
        if id == "all" { 
            // potentially default sort?
        } else if id.hasPrefix("tag:") {
            let tag = String(id.dropFirst(4))
            result = result.filter { $0.tags.contains(tag) }
        } else if let config = store.views.first(where: { $0.id == id }) {
            // Use Query Engine
            result = QueryEngine.filter(result, query: config.query)
            // Use Sort Engine
            result = SortEngine.sort(result, by: config.sort)
            
            // Side-effect: Validate?
            // This causes "Modifying state during view update" warning.
            // Dispatch async?
            DispatchQueue.main.async {
                validateCurrentView(tasks: store.tasks)
            }
            
            return result
        }
        
        return SortEngine.sort(result, by: ["created desc"])
    }

    
    @State private var isInspectorPresented = false
    @State private var isFilterPresented = false
    @State private var isSortPresented = false
    
    // Binding helper to find current view index
    // Note: This only updates in-memory state, NOT disk. 
    // View changes are saved via ViewSettingsView's explicit Save button.
    private func bindingForView(_ id: String) -> Binding<ViewConfig>? {
        guard let index = store.views.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { store.views[index] },
            set: { newValue in 
                store.views[index] = newValue
                // Don't auto-save here - wait for explicit save action
            }
        )
    }
    
    var currentViewName: String {
        if let id = selectedViewId, let config = store.views.first(where: { $0.id == id }) {
            return config.name
        }
        return "Tasks"
    }
    
    var currentViewColumns: [String] {
        let fixed = ["status", "title", "created", "done", "elapsed"]
        let dynamic = store.allFieldKeys
        return fixed + dynamic
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, selectedViewId: $selectedViewId, selectedTag: $selectedTag)
        } detail: {
            VStack(spacing: 0) {
                if selectedViewId == "schema" {
                    SchemaView(store: store)
                } else {
                    TaskTableView(store: store, tasks: filteredTasks, selection: $selectedTaskId, columns: currentViewColumns)
                        .id("\(selectedViewId ?? "none")-\(currentViewColumns.count)")
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if let id = selectedViewId, let binding = bindingForView(id) {
                        TextField("View Name", text: binding.name)
                            .font(.headline)
                            .frame(maxWidth: 200)
                            .multilineTextAlignment(.center)
                    } else {
                        Text(currentViewName)
                            .font(.headline)
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isInspectorPresented.toggle() }) {
                        Label("Toggle Inspector", systemImage: "sidebar.right")
                    }
                }
            }
            .inspector(isPresented: $isInspectorPresented) {
                  if let taskId = selectedTaskId, let task = store.tasks.first(where: { $0.id == taskId }) {
                      TaskDetailView(task: task, store: store)
                          .id(task.id)
                          .inspectorColumnWidth(min: 300, ideal: 400, max: 600)
                } else {
                    ContentUnavailableView("No Selection", systemImage: "doc.text")
                        .inspectorColumnWidth(min: 300, ideal: 400, max: 600)
                }
            }
        }
        .transaction { transaction in
             if transaction.animation != nil {
                 transaction.animation = .spring(duration: 0.2)
             }
        }
        .safeAreaInset(edge: .bottom) {
            StatusBarView(engineState: store.engineState)
        }
        .onChange(of: selectedTaskId) {
            // Request: "maybe don't auto open/close task view"
            // So we do nothing here, or only OPEN if explicit?
            // "make it explicit, to show when task view side is open"
            // If user clicks a row, likely they want to see details IF the inspector is open.
            // But if it's closed, maybe don't auto open?
            // Previous behavior: `if selected != nil { isInspectorPresented = true }`
            // Current Request: "make it explicit".
            // So we remove the auto-open.
        }
    }
    
    func iconForStatus(_ status: String) -> String {
        switch status {
        case "done", "completed": return "checkmark.circle.fill"
        case "in-progress", "doing": return "circle.dotted"
        default: return "circle"
        }
    }
    
    func colorForStatus(_ status: String) -> Color {
        switch status {
        case "done", "completed": return .green
        case "in-progress", "doing": return .blue
        default: return .gray
        }
    }
}

