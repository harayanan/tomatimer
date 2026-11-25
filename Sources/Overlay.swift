import AppKit
import SwiftUI

struct PromptAction {
    let title: String
    let action: () -> Void
}

/// Content for both the full-screen overlay and the smaller centred card.
struct Prompt {
    var symbol: String
    var tint: Color
    var eyebrow: String
    var title: String
    var detail: String?
    var intention: Binding<String>?
    var primary: PromptAction
    var secondary: PromptAction?
    var tertiary: PromptAction?
}

enum OverlayKind {
    case phaseEnd, away, drift
}

/// Borderless window that can take keyboard focus (Return / Esc).
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class OverlayController {
    private var windows: [NSWindow] = []
    private(set) var kind: OverlayKind?

    var isShowing: Bool { !windows.isEmpty }

    /// Dims and blurs every display; the prompt sits on the display under the pointer.
    func showFullscreen(_ prompt: Prompt, kind: OverlayKind) {
        dismiss(animated: false)
        self.kind = kind
        let target = Self.screenUnderPointer()
        for screen in NSScreen.screens {
            let isTarget = screen.frame == target.frame
            let root = FullscreenBackdrop(prompt: isTarget ? prompt : nil)
            let window = makeWindow(frame: screen.frame, content: root)
            window.hasShadow = false
            present(window, makeKey: isTarget)
        }
    }

    /// A floating card centred on the display under the pointer.
    func showCard(_ prompt: Prompt, kind: OverlayKind) {
        dismiss(animated: false)
        self.kind = kind
        let screen = Self.screenUnderPointer()
        let hosting = NSHostingView(rootView: CardView(prompt: prompt))
        let size = hosting.fittingSize
        let vf = screen.visibleFrame
        let frame = NSRect(
            x: vf.midX - size.width / 2,
            y: vf.midY - size.height / 2 + vf.height * 0.12,
            width: size.width,
            height: size.height
        )
        let window = makeWindow(frame: frame, content: CardView(prompt: prompt))
        window.hasShadow = true
        present(window, makeKey: true)
    }

    func dismiss(animated: Bool = true) {
        let closing = windows
        windows = []
        kind = nil
        guard !closing.isEmpty else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                for w in closing { w.animator().alphaValue = 0 }
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                for w in closing { w.orderOut(nil) }
            }
        } else {
            for w in closing { w.orderOut(nil) }
        }
    }

    // MARK: Helpers

    private func makeWindow<V: View>(frame: NSRect, content: V) -> NSWindow {
        let window = OverlayWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
        window.setFrame(frame, display: false)
        return window
    }

    private func present(_ window: NSWindow, makeKey: Bool) {
        window.alphaValue = 0
        if makeKey {
            activateApp()
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }
        windows.append(window)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            window.animator().alphaValue = 1
        }
    }

    private static func screenUnderPointer() -> NSScreen {
        let p = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

// MARK: - Views

private struct FullscreenBackdrop: View {
    let prompt: Prompt?

    var body: some View {
        ZStack {
            VisualEffect(material: .fullScreenUI)
            Color.black.opacity(0.35)
            if let prompt {
                PromptBody(prompt: prompt, large: true)
                    .frame(maxWidth: 640)
                    .padding(40)
            }
        }
        .ignoresSafeArea()
    }
}

private struct CardView: View {
    let prompt: Prompt

    var body: some View {
        PromptBody(prompt: prompt, large: false)
            .frame(width: 420)
            .padding(.vertical, 28)
            .padding(.horizontal, 24)
            .background(VisualEffect(material: .hudWindow))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

private struct PromptBody: View {
    let prompt: Prompt
    let large: Bool

    var body: some View {
        VStack(spacing: large ? 18 : 12) {
            ZStack {
                Circle()
                    .fill(prompt.tint.opacity(0.22))
                    .frame(width: large ? 88 : 56, height: large ? 88 : 56)
                Image(systemName: prompt.symbol)
                    .font(.system(size: large ? 36 : 22, weight: .semibold))
                    .foregroundStyle(prompt.tint)
            }
            .padding(.bottom, large ? 6 : 2)

            Text(prompt.eyebrow.uppercased())
                .font(.system(size: large ? 13 : 11, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(prompt.tint)

            Text(prompt.title)
                .font(.system(size: large ? 46 : 24, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white)

            if let detail = prompt.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: large ? 19 : 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.72))
            }

            if let intention = prompt.intention {
                TextField("What will you work on next?", text: intention)
                    .textFieldStyle(.plain)
                    .font(.system(size: large ? 17 : 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: 420)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.10)))
                    .onSubmit { prompt.primary.action() }
            }

            HStack(spacing: 12) {
                if let secondary = prompt.secondary {
                    Button(secondary.title, action: secondary.action)
                        .buttonStyle(PillButtonStyle(tint: prompt.tint, prominent: false, large: large))
                        .keyboardShortcut(.cancelAction)
                }
                Button(prompt.primary.title, action: prompt.primary.action)
                    .buttonStyle(PillButtonStyle(tint: prompt.tint, large: large))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, large ? 10 : 6)

            if let tertiary = prompt.tertiary {
                Button(tertiary.title, action: tertiary.action)
                    .buttonStyle(.plain)
                    .font(.system(size: large ? 14 : 12))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.top, 2)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}
