import SwiftUI
import TasksCore

struct StatusBarView: View {
    @ObservedObject var engineState: EngineState
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(engineState.statusColor)
                .frame(width: 8, height: 8)
            
            Text(engineState.displayString)
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
            
            Spacer()
            
            if engineState.status == .busy {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.5)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(nsColor: .separatorColor)), alignment: .top)
    }
}
