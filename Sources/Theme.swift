import AppKit
import SwiftUI

enum Theme {
    static let focus = NSColor(srgbRed: 1.00, green: 0.36, blue: 0.30, alpha: 1)     // tomato
    static let shortBreak = NSColor(srgbRed: 0.20, green: 0.78, blue: 0.48, alpha: 1) // leaf green
    static let longBreak = NSColor(srgbRed: 0.28, green: 0.60, blue: 1.00, alpha: 1)  // calm blue
    static let attention = NSColor(srgbRed: 1.00, green: 0.66, blue: 0.20, alpha: 1)  // amber

    static func nsColor(for phase: Phase) -> NSColor {
        switch phase {
        case .focus: return focus
        case .shortBreak: return shortBreak
        case .longBreak: return longBreak
        }
    }

    static func color(for phase: Phase) -> Color {
        Color(nsColor: nsColor(for: phase))
    }
}

/// Blur backdrop for SwiftUI content hosted in AppKit windows.
struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}

struct PillButtonStyle: ButtonStyle {
    var tint: Color
    var prominent: Bool = true
    var large: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: large ? 17 : 13, weight: .semibold, design: .rounded))
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .padding(.horizontal, large ? 28 : 18)
            .padding(.vertical, large ? 12 : 7)
            .background(
                Capsule().fill(prominent ? tint : Color.primary.opacity(0.10))
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(Capsule())
    }
}
