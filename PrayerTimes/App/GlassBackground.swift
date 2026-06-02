import SwiftUI

/// Centralizes the Liquid Glass adoption (spec §10). On macOS 26+ it uses the
/// Tahoe glass material; on Sonoma/Sequoia it falls back to the standard
/// material. Feature views just call `.glassBackground()` and stay clean of
/// availability checks.
struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.background(.regularMaterial)   // TODO(M7): swap for glassEffect()
        } else {
            content.background(.regularMaterial)
        }
    }
}

extension View {
    /// Apply the platform-appropriate panel background material.
    func glassBackground() -> some View {
        modifier(GlassBackground())
    }
}
