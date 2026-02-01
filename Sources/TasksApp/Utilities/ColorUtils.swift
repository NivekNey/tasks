import SwiftUI

/// Converts a color name string to a SwiftUI Color
/// Used by schema-based field styling
func colorFromName(_ name: String) -> Color {
    switch name.lowercased() {
    case "gray", "grey": return .gray
    case "blue": return .blue
    case "green": return .green
    case "red": return .red
    case "orange": return .orange
    case "yellow": return .yellow
    case "purple": return .purple
    case "mint": return .mint
    case "pink": return .pink
    case "teal": return .teal
    case "cyan": return .cyan
    case "indigo": return .indigo
    case "brown": return .brown
    default: return .primary
    }
}
