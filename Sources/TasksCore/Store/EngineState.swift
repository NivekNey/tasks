import SwiftUI
import Combine

public enum EngineStatus: String, CaseIterable {
    case idle = "idle"
    case busy = "busy"
    case error = "error"
}

public class EngineState: ObservableObject {
    @Published public var status: EngineStatus = .idle
    @Published public var message: String = "Ready"
    @Published public var elapsedTime: Double = 0
    @Published public var progress: (current: Int, total: Int)? = nil
    
    private var timer: Timer?
    private var operationStartTime: Date?
    
    // Traffic Light Colors
    public var statusColor: Color {
        switch status {
        case .idle: return .green
        case .busy: return .yellow
        case .error: return .red
        }
    }
    
    /// Formatted display string for status bar
    public var displayString: String {
        guard status != .idle else { return "Ready" }
        
        var result = message
        if let p = progress {
            result += " (\(p.current)/\(p.total))"
        }
        if elapsedTime > 0 {
            result += " (\(String(format: "%.1f", elapsedTime))s)"
        }
        return result
    }
    
    public init() {}
    
    /// Start a new operation with progress tracking
    public func startOperation(_ msg: String, total: Int = 0) {
        DispatchQueue.main.async {
            self.status = .busy
            self.message = msg
            self.elapsedTime = 0
            self.progress = total > 0 ? (0, total) : nil
            self.operationStartTime = Date()
            
            // Start elapsed time timer
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let start = self.operationStartTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }
    
    /// Update progress for current operation (resets elapsed time for new item)
    public func updateProgress(_ msg: String, current: Int, total: Int) {
        DispatchQueue.main.async {
            self.message = msg
            self.progress = (current, total)
            // Reset elapsed time for new item
            self.operationStartTime = Date()
            self.elapsedTime = 0
        }
    }
    
    public func setBusy(_ msg: String) {
        startOperation(msg)
    }
    
    public func setIdle(_ msg: String = "Ready") {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
            self.status = .idle
            self.message = msg
            self.elapsedTime = 0
            self.progress = nil
            self.operationStartTime = nil
        }
    }
    
    public func setError(_ msg: String) {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
            self.status = .error
            self.message = msg
            self.progress = nil
        }
    }
}
