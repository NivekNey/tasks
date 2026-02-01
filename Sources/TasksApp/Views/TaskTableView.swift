import SwiftUI
import TasksCore

struct TaskTableView: View {
    @ObservedObject var store: Store
    let tasks: [Task]
    @Binding var selection: String?
    var columns: [String]
    
    private var rows: [TableRow] {
        tasks.map { .task($0) } + [.addNew]
    }
    
    private var dynamicFields: [String] {
        // Exclude protected keys, id, and status (which has a dedicated fixed column)
        columns.filter { !Task.protectedKeys.contains($0.lowercased()) && !["id", "status"].contains($0.lowercased()) }
    }
    
    var body: some View {
        Group {
            switch dynamicFields.count {
            case 0: table0
            case 1: table1
            case 2: table2
            case 3: table3
            case 4: table4
            default: table5
            }
        }
        .contextMenu(forSelectionType: String.self) { selectedIds in
             Button("Delete Task") {
                 for id in selectedIds { store.deleteTask(id: id) }
             }
        }
    }
    
    // Core columns used in all tables
    @TableColumnBuilder<TableRow, Never>
    private var coreColumns: some TableColumnContent<TableRow, Never> {
        TableColumn("Status") { (row: TableRow) in
            switch row {
            case .task(let task): StatusCell(store: store, task: task)
            case .addNew: 
                Button(action: { store.createTask() }) {
                    Label("New Task", systemImage: "plus.circle")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .width(min: 80, ideal: 120)
        
        TableColumn("Title") { (row: TableRow) in
            if case .task(let task) = row {
                TitleCell(store: store, task: task)
            }
        }
        .width(min: 200, ideal: 400)
        
        TableColumn("Created") { (row: TableRow) in
            if case .task(let task) = row {
                DateCell(date: task.created)
            }
        }
        .width(min: 120, ideal: 160)
        
        TableColumn("Done") { (row: TableRow) in
            if case .task(let task) = row, let done = task.done {
                DateCell(date: done)
            }
        }
        .width(min: columns.contains("done") ? 120 : 0, ideal: columns.contains("done") ? 160 : 0, max: columns.contains("done") ? nil : 0)
        
        TableColumn("Elapsed") { (row: TableRow) in
            if case .task(let task) = row {
                ElapsedCell(task: task)
            }
        }
        .width(min: columns.contains("elapsed") ? 80 : 0, ideal: columns.contains("elapsed") ? 100 : 0, max: columns.contains("elapsed") ? nil : 0)
    }
    
    // Specialized tables for different column counts
    
    private var table0: some View {
        Table(rows, selection: $selection) {
            coreColumns
        }
    }
    
    private var table1: some View {
        Table(rows, selection: $selection) {
            coreColumns
            dynamicColumn(0)
        }
    }
    
    private var table2: some View {
        Table(rows, selection: $selection) {
            coreColumns
            dynamicColumn(0)
            dynamicColumn(1)
        }
    }
    
    private var table3: some View {
        Table(rows, selection: $selection) {
            coreColumns
            dynamicColumn(0)
            dynamicColumn(1)
            dynamicColumn(2)
        }
    }
    
    private var table4: some View {
        Table(rows, selection: $selection) {
            coreColumns
            dynamicColumn(0)
            dynamicColumn(1)
            dynamicColumn(2)
            dynamicColumn(3)
        }
    }
    
    private var table5: some View {
        Table(rows, selection: $selection) {
            coreColumns
            dynamicColumn(0)
            dynamicColumn(1)
            dynamicColumn(2)
            dynamicColumn(3)
            dynamicColumn(4)
        }
    }
    
    @TableColumnBuilder<TableRow, Never>
    private func dynamicColumn(_ index: Int) -> some TableColumnContent<TableRow, Never> {
        let field = dynamicFields[index]
        TableColumn(field.capitalized) { (row: TableRow) in
            if case .task(let task) = row {
                RowDynamicContent(task: task, key: field, store: store)
            }
        }
        .width(min: 100, ideal: 150)
    }
}

// Helper components

struct RowDynamicContent: View {
    let task: Task
    let key: String
    @ObservedObject var store: Store
    
    var body: some View {
        let fieldType = store.schema.fields[key]?.type ?? .text
        switch fieldType {
        case .categorical:
            CategoricalCell(store: store, task: task, key: key)
        case .url:
            UrlCell(store: store, task: task, key: key)
        case .text:
            GenericTextCell(store: store, task: task, key: key)
        }
    }
}

enum TableRow: Identifiable {
    case task(Task)
    case addNew
    
    var id: String {
        switch self {
        case .task(let t): return t.id
        case .addNew: return "addNew"
        }
    }
}

struct DateCell: View {
    let date: Date
    var body: some View {
        Text(date, format: .dateTime.month().day().hour().minute())
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .lineLimit(1)
    }
}

struct ElapsedCell: View {
    let task: Task
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(durationString(now: context.date))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
        }
    }
    
    private func durationString(now: Date) -> String {
        let end = task.done ?? now
        let diff = Int(end.timeIntervalSince(task.created))
        let days = diff / 86400
        let hours = (diff % 86400) / 3600
        let minutes = (diff % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

struct GenericTextCell: View {
    @ObservedObject var store: Store
    let task: Task
    let key: String
    @State private var localText: String
    @FocusState private var isFocused: Bool
    
    init(store: Store, task: Task, key: String) {
        self.store = store
        self.task = task
        self.key = key
        _localText = State(initialValue: task.frontmatter[key] ?? "")
    }
    
    var body: some View {
        TextField("", text: $localText)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($isFocused)
            .onSubmit { saveIfChanged() }
            .onChange(of: isFocused) {
                if !isFocused { saveIfChanged() }
            }
            .onChange(of: task.frontmatter[key]) {
                if !isFocused, let newVal = task.frontmatter[key], newVal != localText {
                    localText = newVal
                }
            }
    }
    
    private func saveIfChanged() {
        guard localText != (task.frontmatter[key] ?? "") else { return }
        var newFm = task.frontmatter
        newFm[key] = localText
        let newTask = Task(id: task.id, title: task.title, status: task.status, created: task.created, done: task.done, tags: task.tags, path: task.path, content: task.content, frontmatter: newFm)
        store.updateTask(newTask)
    }
}

struct StatusCell: View {
    @ObservedObject var store: Store
    let task: Task
    
    var body: some View {
        CategoricalCell(store: store, task: task, key: "status")
    }
}

struct TitleCell: View {
    @ObservedObject var store: Store
    let task: Task
    @State private var localTitle: String
    @FocusState private var isFocused: Bool
    
    init(store: Store, task: Task) {
        self.store = store
        self.task = task
        _localTitle = State(initialValue: task.title)
    }
    
    var body: some View {
        TextField("Title", text: $localTitle)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundColor(task.phase == "done" ? .secondary : .primary)
            .strikethrough(task.phase == "done")
            .focused($isFocused)
            .onSubmit { saveIfChanged() }
            .onChange(of: isFocused) {
                if !isFocused { saveIfChanged() }
            }
            .onChange(of: task.title) {
                if !isFocused && localTitle != task.title {
                    localTitle = task.title
                }
            }
    }
    
    private func saveIfChanged() {
        guard localTitle != task.title else { return }
        store.updateTask(task.with(title: localTitle))
    }
}
