import SwiftUI

/// Centralizes Liquid Glass adoption (spec §10). On macOS 26 (Tahoe) it uses the
/// real `glassEffect` material; on Sonoma/Sequoia it falls back to the standard
/// material. Feature views just call `.glassBackground()`.
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(.regularMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    /// Apply the platform-appropriate panel background (Liquid Glass on Tahoe).
    func glassBackground(cornerRadius: CGFloat = 14) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}
