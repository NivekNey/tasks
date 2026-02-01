import SwiftUI
import TasksCore
import AppKit

struct UrlCell: View {
    @ObservedObject var store: Store
    let task: Task
    let key: String
    
    @State private var text: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    init(store: Store, task: Task, key: String) {
        self.store = store
        self.task = task
        self.key = key
        _text = State(initialValue: task.frontmatter[key] ?? "")
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if isEditing {
                TextField("URL", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .focused($isFocused)
                    .onSubmit { saveAndExit() }
                    .onChange(of: isFocused) {
                        if !isFocused { saveAndExit() }
                    }
            } else {
                // URL text - click to edit
                Text(displayText)
                    .font(.system(size: 13))
                    .foregroundColor(isValidUrl ? .blue : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isEditing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isFocused = true
                        }
                    }
                
                Spacer()
                
                // Open URL button - only show if valid URL
                if isValidUrl {
                    Button(action: openUrl) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open in browser")
                }
            }
        }
    }
    
    private var displayText: String {
        text.isEmpty ? "–" : text
    }
    
    private var isValidUrl: Bool {
        guard !text.isEmpty else { return false }
        return URL(string: text) != nil && (text.hasPrefix("http://") || text.hasPrefix("https://"))
    }
    
    private func openUrl() {
        guard let url = URL(string: text), isValidUrl else { return }
        NSWorkspace.shared.open(url)
    }
    
    private func saveAndExit() {
        isEditing = false
        let currentVal = task.frontmatter[key] ?? ""
        guard text != currentVal else { return }
        
        var newFm = task.frontmatter
        newFm[key] = text
        let newTask = Task(
            title: task.title,
            status: task.status,
            created: task.created,
            done: task.done,
            tags: task.tags,
            path: task.path,
            content: task.content,
            frontmatter: newFm
        )
        store.updateTask(newTask)
    }
}

