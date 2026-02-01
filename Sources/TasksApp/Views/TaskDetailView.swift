import SwiftUI
import TasksCore

struct TaskDetailView: View {
    let task: Task
    @ObservedObject var store: Store
    
    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var isDirty = false
    
    @StateObject private var debouncer = CellDebouncer()
    
    init(task: Task, store: Store) {
        self.task = task
        self.store = store
        _editedTitle = State(initialValue: task.title)
        _editedContent = State(initialValue: task.content)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Content").font(.headline).foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
            
            TextEditor(text: $editedContent)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden) // Cleaner
                .frame(maxHeight: .infinity) // Fill space
                .padding(8)
                .onChange(of: editedContent) {
                    // 1. Mark as dirty immediately for UI
                    isDirty = true
                    
                    // 2. Capture specific state for this debounce cycle
                    let capturedTask = task
                    let capturedContent = editedContent
                    
                    // Only save if the content actually changed from the task (avoid recursive save)
                    if capturedContent != capturedTask.content {
                        debouncer.debounce(delay: 0.8) {
                            store.updateTask(capturedTask.with(content: capturedContent))
                            isDirty = false
                        }
                    }
                }
        }
        .navigationTitle(task.title)
        .id(task.id)
        .onDisappear {
            // Flush any pending save for this task when view goes away or task changes
            if isDirty {
                store.updateTask(task.with(content: editedContent))
            }
        }
        .onChange(of: task.id) { oldId, newId in
            // Handle task switch: Flush edits for the OLD task
            if isDirty {
                // IMPORTANT: Use old version if we have it, or just rely on 'task' 
                // but since we're in the new task now, we need to be careful.
                // Actually, the capturedTask in the debouncer already handles this.
            }
            
            // Immediately reset state for the NEW task
            editedContent = task.content
            isDirty = false
        }
        .onChange(of: task.content) {
             // Update local editor ONLY if change came from outside (e.g. file watcher)
             // and doesn't match current local buffer.
             // Also prevent it from firing if we just switched tasks (id onChange handled that)
             if editedContent != task.content && !isDirty {
                 editedContent = task.content
             }
        }
    }
    
    private func saveChanges() {
        let newTask = task.with(title: editedTitle, content: editedContent)
        store.updateTask(newTask)
        isDirty = false
    }
}
