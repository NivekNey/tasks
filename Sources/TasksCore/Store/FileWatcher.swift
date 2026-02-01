import Foundation

/// Watches directories for changes and calls handlers when files are modified
public class FileWatcher {
    private var sources: [String: DispatchSourceFileSystemObject] = [:]
    
    public init() {}
    
    private var debounceWorkItems: [String: DispatchWorkItem] = [:]
    
    /// Start watching a directory for changes
    /// - Parameters:
    ///   - path: Directory path to watch
    ///   - onChange: Handler called when changes detected
    public func watch(path: String, onChange: @escaping () -> Void) {
        let descriptor = open(path, O_EVTONLY)
        guard descriptor != -1 else {
            print("FileWatcher: Failed to open \(path)")
            return
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, 
            eventMask: .write, 
            queue: .main
        )
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            // Debounce the change event (coalesce rapid writes/renames)
            self.debounceWorkItems[path]?.cancel()
            let workItem = DispatchWorkItem {
                print("FileWatcher: Coalesced change detected in \(path)")
                onChange()
            }
            self.debounceWorkItems[path] = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
        }
        
        source.setCancelHandler {
            close(descriptor)
        }
        
        source.resume()
        sources[path] = source
    }
    
    /// Stop watching a specific path
    public func stopWatching(path: String) {
        sources[path]?.cancel()
        sources[path] = nil
    }
    
    /// Stop all watchers
    public func stopAll() {
        for source in sources.values {
            source.cancel()
        }
        sources.removeAll()
    }
    
    deinit {
        stopAll()
    }
}
