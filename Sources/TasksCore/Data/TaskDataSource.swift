public protocol TaskDataSource {
    func loadTasks(rootPath: String) -> [Task]
    func loadViews(rootPath: String) -> [ViewConfig]
    func saveTask(_ task: Task)
    func saveView(_ view: ViewConfig)
    func deleteTask(path: String)
    func deleteView(path: String)
}

