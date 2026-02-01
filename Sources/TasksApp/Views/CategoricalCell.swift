import SwiftUI
import TasksCore

struct CategoricalCell: View {
    @ObservedObject var store: Store
    let task: Task
    let key: String
    
    @State private var text: String
    @State private var isShowingSuggestions = false
    @FocusState private var isFocused: Bool
    
    init(store: Store, task: Task, key: String) {
        self.store = store
        self.task = task
        self.key = key
        // All fields read from frontmatter (status is synced there)
        _text = State(initialValue: task.frontmatter[key] ?? "")
    }
    
    var body: some View {
        HStack {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(valueColor)
                .focused($isFocused)
                .onChange(of: text) {
                    if isFocused {
                        isShowingSuggestions = true
                    }
                    saveIfChanged()
                }
                .popover(isPresented: $isShowingSuggestions, arrowEdge: .bottom) {
                    suggestionList
                }
        }
    }
    
    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            let filtered = filteredSuggestions
            if filtered.isEmpty {
                Text("No matches").padding().foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filtered, id: \.self) { suggestion in
                            Button {
                                text = suggestion
                                isShowingSuggestions = false
                                saveIfChanged()
                            } label: {
                                HStack {
                                    Circle().fill(colorForValue(suggestion)).frame(width: 8, height: 8)
                                    Text(suggestion)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(text == suggestion ? Color.accentColor.opacity(0.1) : Color.clear)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .frame(minWidth: 150)
    }
    
    private var filteredSuggestions: [String] {
        let catalog = store.fieldCatalogs[key] ?? []
        if text.isEmpty { return catalog.sorted() }
        return catalog.filter { $0.lowercased().contains(text.lowercased()) }.sorted()
    }
    
    private var valueColor: Color {
        colorForValue(text)
    }
    
    private func colorForValue(_ val: String) -> Color {
        if let colorName = store.schema.fields[key]?.options[val]?.color {
            return colorFromName(colorName)
        }
        return .primary
    }
    
    private func saveIfChanged() {
        if key == "status" {
            if text != task.status {
                store.updateTask(task.with(status: text))
            }
        } else {
            let currentVal = task.frontmatter[key] ?? ""
            if text != currentVal {
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
    }
}
