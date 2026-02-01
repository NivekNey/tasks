import Foundation
@testable import TasksCore

struct MockDataSource: TaskDataSource {
    let mockTasks: [Task]
    let mockViews: [ViewConfig]
    
    func loadTasks(rootPath: String) -> [Task] {
        return mockTasks
    }
    
    func loadViews(rootPath: String) -> [ViewConfig] {
        return mockViews
    }
    
    func saveTask(_ task: Task) {
        // Mock save - do nothing or update internal array if needed for advanced tests
    }
    
    func saveView(_ view: ViewConfig) {}
    
    func deleteTask(path: String) {}
    func deleteView(path: String) {}
}

