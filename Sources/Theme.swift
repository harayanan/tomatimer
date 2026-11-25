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
            .padding(.horizontal, large ? 30 : 22)
            .padding(.vertical, large ? 13 : 9)
            .background(
                ZStack {
                    if prominent {
                        Capsule().fill(LinearGradient(
                            colors: [tint.opacity(0.80), tint],
                            startPoint: .top, endPoint: .bottom
                        ))
                        Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                    } else {
                        Capsule().fill(Color.primary.opacity(0.09))
                    }
                }
            )
            .shadow(color: prominent ? tint.opacity(0.35) : Color.clear, radius: 6, x: 0, y: 3)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Round icon button used beside the primary pill.
struct CircleIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CircleIconBody(configuration: configuration)
    }

    private struct CircleIconBody: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.75))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.primary.opacity(configuration.isPressed ? 0.16 : (hovering ? 0.11 : 0.07))))
                .scaleEffect(configuration.isPressed ? 0.93 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
                .onHover { hovering = $0 }
                .contentShape(Circle())
        }
    }
}
