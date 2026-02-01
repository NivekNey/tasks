import SwiftUI
import TasksCore

struct FilterPopover: View {
    @Binding var query: String
    @State private var isValid = true
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Filter Query").font(.headline)
            TextEditor(text: $query)
                .font(.monospaced(.body)())
                .frame(width: 300, height: 100)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(isValid ? Color.gray.opacity(0.3) : Color.red, lineWidth: 1))
                .onChange(of: query) {
                    // Primitive smart quote "fix" - replace them on the fly?
                    // User requested "should not be accented".
                    let clean = query.replacingOccurrences(of: "“", with: "\"")
                                     .replacingOccurrences(of: "”", with: "\"")
                                     .replacingOccurrences(of: "‘", with: "'")
                                     .replacingOccurrences(of: "’", with: "'")
                    if clean != query {
                        query = clean
                    }
                    validate()
                }
            
            if !isValid {
                Text("Invalid syntax (quotes?)").font(.caption).foregroundStyle(.red)
            }
            
            Text("Examples:").font(.caption).foregroundStyle(.secondary)
            Text("status == 'doing'").font(.caption2).monospaced()
            Text("priority > 1").font(.caption2).monospaced()
        }
        .padding()
        .onAppear { validate() }
    }
    
    func validate() {
        // Basic check: Balanced quotes?
        // QueryEngine uses simple logic.
        // We just ensure it's not mostly whitespace?
        // Or check for obvious bad characters.
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { isValid = true; return }
        
        let quoteCount = q.filter { $0 == "'" || $0 == "\"" }.count
        isValid = quoteCount % 2 == 0
    }
}

struct SortPopover: View {
    @Binding var sort: [String]
    
    @State private var newSortField: String = ""
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Sort Order").font(.headline)
            
            List {
                ForEach(Array(sort.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text(item)
                        Spacer()
                        Button(action: {
                            var mutable = sort
                            mutable.remove(at: index)
                            sort = mutable
                        }) {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onMove { indices, newOffset in
                    var mutable = sort
                    mutable.move(fromOffsets: indices, toOffset: newOffset)
                    sort = mutable
                }
            }
            .frame(height: 150)
            
            HStack {
                TextField("Field (e.g. created desc)", text: $newSortField)
                Button("Add") {
                    addSort()
                }
                .disabled(newSortField.isEmpty)
            }
            
            if let error = errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding()
        .frame(width: 300)
        .onChange(of: newSortField) { errorMessage = nil }
    }
    
    func addSort() {
        // Validate
        let parts = newSortField.components(separatedBy: .whitespaces)
        guard let field = parts.first, !field.isEmpty else { return }
        
        let validFields = ["status", "title", "created", "done", "elapsed", "priority", "category"] // approximate knowns
        // Allow custom frontmatter keys, so we can't be too strict.
        // But check simple regex?
        
        if parts.count > 2 {
            errorMessage = "Format: field [asc|desc]"
            return
        }
        
        if parts.count == 2 {
            let dir = parts[1].lowercased()
            if dir != "asc" && dir != "desc" {
                errorMessage = "Direction must be asc or desc"
                return
            }
        }
        
        sort.append(newSortField)
        newSortField = ""
        errorMessage = nil
    }
}
