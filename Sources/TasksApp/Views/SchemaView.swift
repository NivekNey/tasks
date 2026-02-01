import SwiftUI
import TasksCore

struct SchemaView: View {
    @ObservedObject var store: Store
    @State private var editingField: String?
    @State private var isAddingNewField = false
    @State private var newFieldName = ""
    @State private var selection: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Schema Management")
                    .font(.title2).bold()
                Spacer()
                Button(action: { isAddingNewField = true }) {
                    Label("New Field", systemImage: "plus")
                }
            }
            .padding()
            .alert("Add New Field", isPresented: $isAddingNewField) {
                TextField("Field Key (e.g. priority)", text: $newFieldName)
                Button("Add") {
                     if !newFieldName.isEmpty && !Task.protectedKeys.contains(newFieldName.lowercased()) {
                         var newSchema = store.schema
                         if newSchema.fields[newFieldName] == nil {
                             newSchema.fields[newFieldName] = FieldConfig()
                             newSchema.order.append(newFieldName)
                             store.saveSchema(newSchema)
                         }
                     }
                     newFieldName = ""
                }
                Button("Cancel", role: .cancel) { newFieldName = "" }
            }
            
            List {
                ForEach(fieldRows) { row in
                    HStack {
                        Text(row.key)
                            .fontWeight(.medium)
                            .frame(width: 150, alignment: .leading)
                        
                        Divider()
                        
                        Picker("", selection: Binding(
                            get: { store.schema.fields[row.key]?.type ?? .text },
                            set: { newType in updateFieldType(key: row.key, type: newType) }
                        )) {
                            ForEach(FieldType.allCases, id: \.self) { type in
                                Text(type.rawValue.capitalized).tag(type)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        
                        Spacer()
                        
                        if (store.schema.fields[row.key]?.type ?? .text) == .categorical {
                            Button("Edit Options...") {
                                editingField = row.key
                            }
                            .buttonStyle(.link)
                            .font(.subheadline)
                        }
                        
                        Button(action: { removeFields(keys: [row.key]) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 4)
                }
                .onMove(perform: moveFields)
            }
            .listStyle(.inset)
        }
        .sheet(item: Binding(
            get: { editingField.map { FieldStyleEditItem(key: $0) } },
            set: { editingField = $0?.key }
        )) { item in
            FieldStyleEditor(store: store, fieldKey: item.key)
        }
    }
    
    private var fieldRows: [FieldRow] {
        store.allFieldKeys.map { FieldRow(key: $0) }
    }
    
    private func updateFieldType(key: String, type: FieldType) {
        var newSchema = store.schema
        var config = newSchema.fields[key] ?? FieldConfig()
        config.type = type
        if type == .text {
            config.options = [:]
        }
        newSchema.fields[key] = config
        store.saveSchema(newSchema)
    }
    
    private func removeFields(keys: Set<String>) {
        var newSchema = store.schema
        for key in keys {
            newSchema.fields.removeValue(forKey: key)
            if let index = newSchema.order.firstIndex(of: key) {
                newSchema.order.remove(at: index)
            }
        }
        store.saveSchema(newSchema)
        selection.removeAll()
    }
    
    private func moveFields(from source: IndexSet, to destination: Int) {
        var orderedKeys = fieldRows.map { $0.key }
        orderedKeys.move(fromOffsets: source, toOffset: destination)
        
        var newSchema = store.schema
        newSchema.order = orderedKeys
        store.saveSchema(newSchema)
    }
}

struct FieldRow: Identifiable {
    let key: String
    var id: String { key }
}

struct FieldStyleEditItem: Identifiable {
    let key: String
    var id: String { key }
}

struct FieldStyleEditor: View {
    @ObservedObject var store: Store
    let fieldKey: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Styles for '\(fieldKey)'").font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.return)
            }
            .padding()
            
            Divider()
            
            List {
                ForEach(sortedOptions, id: \.self) { option in
                    HStack {
                        Text(option)
                        Spacer()
                        ColorPickerView(selection: Binding(
                            get: { store.schema.fields[fieldKey]?.options[option]?.color },
                            set: { newColor in updateOptionColor(option: option, color: newColor) }
                        ))
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private var sortedOptions: [String] {
        store.fieldCatalogs[fieldKey]?.sorted() ?? []
    }
    
    private func updateOptionColor(option: String, color: String?) {
        var newSchema = store.schema
        var config = newSchema.fields[fieldKey] ?? FieldConfig(type: .categorical)
        var style = config.options[option] ?? OptionStyle()
        style.color = color
        config.options[option] = style
        newSchema.fields[fieldKey] = config
        store.saveSchema(newSchema)
    }
}

struct ColorPickerView: View {
    @Binding var selection: String?
    
    let colors = [
        ("None", nil),
        ("Gray", "gray"),
        ("Blue", "blue"),
        ("Green", "green"),
        ("Red", "red"),
        ("Orange", "orange"),
        ("Yellow", "yellow"),
        ("Purple", "purple"),
        ("Mint", "mint")
    ]
    
    var body: some View {
        Picker("", selection: $selection) {
            ForEach(colors, id: \.0) { name, value in
                HStack {
                    if let value = value {
                        Circle().fill(colorFromName(value)).frame(width: 8, height: 8)
                    }
                    Text(name)
                }.tag(value)
            }
        }
        .labelsHidden()
        .controlSize(.small)
        .frame(width: 100)
    }
}

