import SwiftUI
import TasksCore

struct ViewSettingsView: View {
    @ObservedObject var store: Store
    @Binding var viewConfig: ViewConfig
    @Environment(\.dismiss) var dismiss
    
    // Local editable state
    @State private var name: String
    @State private var query: String
    @State private var sort: String
    
    @FocusState private var focusedField: Field?
    
    enum Field { case name, query, sort }
    
    init(store: Store, viewConfig: Binding<ViewConfig>) {
        self.store = store
        _viewConfig = viewConfig
        _name = State(initialValue: viewConfig.wrappedValue.name)
        _query = State(initialValue: viewConfig.wrappedValue.query)
        _sort = State(initialValue: viewConfig.wrappedValue.sort.joined(separator: ", "))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit View")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Content
            VStack(alignment: .leading, spacing: 20) {
                // Name field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("View name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .name)
                }
                
                // Query field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Filter")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("e.g. status == 'todo'", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($focusedField, equals: .query)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Examples:")
                            .font(.caption).bold()
                        Text("status == done                    ← equality")
                        Text("status != todo                    ← not equal")
                        Text("pm == \"Justin\" and status == todo ← and")
                        Text("status == done or status == prog  ← or")
                        Text("title contains \"report\"           ← contains")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                // Sort field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sort")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("e.g. created desc, title asc", text: $sort)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($focusedField, equals: .sort)
                    Text("Separate multiple sorts with commas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            
            Spacer()
            
            Divider()
            
            // Footer buttons
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 380, height: 320)
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            focusedField = .name
        }
    }
    
    private func save() {
        // Parse sort: "created desc, title asc" -> ["created desc", "title asc"]
        let sortArr = sort.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let newConfig = ViewConfig(
            id: viewConfig.id,
            name: name.isEmpty ? "Untitled" : name,
            query: query,
            sort: sortArr,
            columns: viewConfig.columns.isEmpty ? ["title", "status", "created"] : viewConfig.columns,
            path: viewConfig.path
        )
        
        store.saveView(newConfig)
        dismiss()
    }
}
