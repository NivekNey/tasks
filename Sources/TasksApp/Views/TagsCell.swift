import SwiftUI
import TasksCore

struct TagsCell: View {
    @ObservedObject var store: Store
    let task: Task
    
    @State private var text: String
    @FocusState private var isFocused: Bool
    
    init(store: Store, task: Task) {
        self.store = store
        self.task = task
        _text = State(initialValue: task.tags.joined(separator: ", "))
    }
    
    var body: some View {
        TextField("Tags", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($isFocused)
            .onSubmit { save() }
            .onChange(of: isFocused) {
                if !isFocused { save() }
            }
    }
    
    private func save() {
        let currentTags = task.tags.joined(separator: ", ")
        guard text != currentTags else { return }
        
        let newTags = text.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Use store.updateTask but we need a way to update specifically tags
        // The Task struct is immutable, we create a new one
        let newTask = Task(
            id: task.id,
            title: task.title,
            status: task.status,
            created: task.created,
            done: task.done,
            tags: newTags,
            path: task.path,
            content: task.content,
            frontmatter: task.frontmatter
        )
        store.updateTask(newTask)
    }
}
