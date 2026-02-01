import SwiftUI
import TasksCore

struct SidebarView: View {
    @ObservedObject var store: Store
    @Binding var selectedViewId: String?
    @Binding var selectedTag: String?
    
    @State private var editingViewConfig: ViewConfig?
    
    var body: some View {
        List(selection: $selectedViewId) {
            Section("System") {
                 NavigationLink(value: "all") {
                     Label("All Tasks", systemImage: "tray")
                 }
            }
            
            Section("Settings") {
                 NavigationLink(value: "schema") {
                     Label("Schema", systemImage: "aqi.medium")
                 }
            }
            
            Section("Views") {
                ForEach(store.views) { view in
                    HStack {
                        NavigationLink(value: view.id) {
                            Label(view.name, systemImage: "list.bullet.rectangle")
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button {
                                editingViewConfig = view
                            } label: {
                                Label("Edit View", systemImage: "slider.horizontal.3")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                store.deleteView(id: view.id)
                            } label: {
                                Label("Delete View", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .menuIndicator(.hidden)
                        .buttonStyle(.plain)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                    }
                    .tag(view.id)
                }
                
                Button(action: {
                    createNewView()
                }) {
                    Label("New View", systemImage: "plus")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Tasks")
        .sheet(item: $editingViewConfig) { config in
             ViewSettingsView(store: store, viewConfig: Binding(
                 get: { config },
                 set: { _ in } // Save handles update via Store
             ))
        }
    }
    
    private func createNewView() {
        store.createView(name: "New View \(Int.random(in: 100...999))")
    }
}
