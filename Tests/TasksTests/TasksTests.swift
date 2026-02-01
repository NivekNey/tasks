import XCTest
@testable import TasksCore

final class TasksTests: XCTestCase {
    
    var tempDir: URL!
    
    func testStoreWithMock() {
        // Given
        let task1 = Task(path: "/t1", fileContent: "---\ntitle: Task 1\nstatus: todo\n---\n")
        let task2 = Task(path: "/t2", fileContent: "---\ntitle: Task 2\nstatus: done\n---\n")
        let mockRepo = MockDataSource(mockTasks: [task1, task2], mockViews: [])
        
        // When
        let store = Store(dataSource: mockRepo)
        store.loadAll(rootPath: "/dummy")
        
        // Then
        XCTAssertEqual(store.tasks.count, 2)
        XCTAssertEqual(store.tasks.first?.title, "Task 1")
    }

    
    func testQueryEngine() {
        let task1 = Task(path: "t1", fileContent: "---\ntitle: A\nstatus: done\n---\n")
        let task2 = Task(path: "t2", fileContent: "---\ntitle: B\nstatus: todo\n---\n")
        
        let results = QueryEngine.filter([task1, task2], query: "status == done")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "A")
    }
    
    func testSortEngine() {
        let task1 = Task(path: "t1", fileContent: "---\ntitle: Z\ncreated: 2023-01-01T00:00:00Z\n---\n")
        let task2 = Task(path: "t2", fileContent: "---\ntitle: A\ncreated: 2023-01-02T00:00:00Z\n---\n")
        
        // Sort by title asc
        let sortedTitle = SortEngine.sort([task1, task2], by: ["title asc"])
        XCTAssertEqual(sortedTitle.first?.title, "A")
        
        // Sort by created desc (Task 2 is newer/larger date)
        // Note: String comparison of ISO dates works for sorting
        let sortedDate = SortEngine.sort([task1, task2], by: ["created desc"])
        XCTAssertEqual(sortedDate.first?.title, "A")
    }
}
