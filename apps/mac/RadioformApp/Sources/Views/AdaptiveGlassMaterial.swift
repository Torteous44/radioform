import SwiftUI
import AppKit

/// Glass effect variant for different UI contexts
enum GlassVariant {
    case regular      // Standard glass for backgrounds
    case interactive  // More prominent glass for interactive elements
    case prominent    // Highly visible glass for emphasis

    var fallbackMaterial: NSVisualEffectView.Material {
        switch self {
        case .regular: return .popover
        case .interactive: return .hudWindow
        case .prominent: return .menu
        }
    }
}

/// Adaptive glass material that uses Liquid Glass on macOS 26+ and falls back to VisualEffectView on older versions
struct AdaptiveGlassMaterial: ViewModifier {
    var variant: GlassVariant = .regular
    var shape: AnyShape = AnyShape(Capsule())
    var material: NSVisualEffectView.Material? = nil
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            // Use Liquid Glass on macOS 26+
            // Note: Variant support is simulated via opacity for visual differentiation
            content
                .background {
                    Color.clear
                        .glassEffect(in: shape)
                        .opacity(glassOpacity(for: variant))
                }
        } else {
            // Fallback to VisualEffectView on older macOS
            content
                .background {
                    VisualEffectView(
                        material: material ?? variant.fallbackMaterial,
                        blendingMode: blendingMode
                    )
                }
        }
    }

    private func glassOpacity(for variant: GlassVariant) -> Double {
        switch variant {
        case .regular: return 1.0
        case .interactive: return 0.95
        case .prominent: return 0.9
        }
    }
}

/// Type-erased shape wrapper to allow any shape to be stored
struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

/// Convenience extension for applying adaptive glass effects
extension View {
    /// Applies an adaptive glass effect that uses Liquid Glass on macOS 26+ and VisualEffectView on older versions
    /// - Parameters:
    ///   - variant: The glass variant to use (default: .regular)
    ///   - shape: The shape of the glass effect (default: capsule)
    ///   - material: Optional custom NSVisualEffectView material for fallback (overrides variant default)
    ///   - blendingMode: The blending mode for fallback (default: .behindWindow)
    func adaptiveGlass<S: Shape>(
        variant: GlassVariant = .regular,
        in shape: S = Capsule(),
        material: NSVisualEffectView.Material? = nil,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) -> some View {
        self.modifier(
            AdaptiveGlassMaterial(
                variant: variant,
                shape: AnyShape(shape),
                material: material,
                blendingMode: blendingMode
            )
        )
    }

    /// Applies an adaptive glass effect with rectangular shape
    /// - Parameters:
    ///   - variant: The glass variant to use (default: .regular)
    ///   - material: Optional custom NSVisualEffectView material for fallback
    ///   - blendingMode: The blending mode for fallback (default: .behindWindow)
    func adaptiveGlass(
        variant: GlassVariant = .regular,
        material: NSVisualEffectView.Material? = nil,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) -> some View {
        self.modifier(
            AdaptiveGlassMaterial(
                variant: variant,
                shape: AnyShape(Rectangle()),
                material: material,
                blendingMode: blendingMode
            )
        )
    }
}
