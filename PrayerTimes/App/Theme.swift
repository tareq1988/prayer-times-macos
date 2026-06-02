import SwiftUI

extension Color {
    /// The app's brand green. Used explicitly (rather than `Color.accentColor`)
    /// because on macOS `accentColor` follows the user's *system* accent, which
    /// would override our branding.
    static let brand = Color(red: 0.18, green: 0.58, blue: 0.247)
}
