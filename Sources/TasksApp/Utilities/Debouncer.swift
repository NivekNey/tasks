import Foundation

/// A simple debouncer that cancels previous actions if a new one is triggered within the delay
class Debouncer: ObservableObject {
    private var workItem: DispatchWorkItem?
    
    func debounce(delay: TimeInterval = 0.5, action: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem(block: action)
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
    
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}

/// Alias for backward compatibility
typealias CellDebouncer = Debouncer
