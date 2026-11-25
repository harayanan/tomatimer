import AppKit
import SwiftUI
import Combine

/// Owns the menu bar item (pie glyph + countdown) and its popover.
/// Left-click pauses/resumes a running timer; right-click or ⌥-click opens the panel.
/// When nothing is running, a left-click opens the panel.
@MainActor
final class StatusItemController: NSObject {
    private let engine: TimerEngine
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var pulseTimer: Timer?
    private var pulseDim = false
    private var attention = false
    private var lastSignature = ""

    init(engine: TimerEngine, settings: Settings, onQuit: @escaping () -> Void) {
        self.engine = engine
        super.init()

        if let button = item.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }

        popover.behavior = .transient
        popover.animates = true
        let host = NSHostingController(rootView: PopoverView(engine: engine, settings: settings, onQuit: onQuit))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host

        engine.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        refresh()
    }

    /// Pulse the item amber while the user has drifted off.
    func setAttention(_ on: Bool) {
        guard on != attention else { return }
        attention = on
        pulseTimer?.invalidate()
        pulseTimer = nil
        item.button?.alphaValue = 1
        if on {
            let t = Timer(timeInterval: 0.8, target: self, selector: #selector(pulse), userInfo: nil, repeats: true)
            t.tolerance = 0.1
            RunLoop.main.add(t, forMode: .common)
            pulseTimer = t
        }
        lastSignature = ""
        refresh()
    }

    func closePopover() {
        popover.performClose(nil)
    }

    // MARK: Clicks

    @objc private func handleClick() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        let event = NSApp.currentEvent
        let wantsPanel = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.option) == true
            || event?.modifierFlags.contains(.control) == true
        if wantsPanel || engine.state == .idle {
            showPopover()
        } else {
            engine.toggle()
            bump()
        }
    }

    private func showPopover() {
        guard let button = item.button else { return }
        engine.refreshDay()
        activateApp()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    /// Brief dip so a click-to-pause gets visible feedback.
    private func bump() {
        guard let button = item.button, !attention else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.08
            button.animator().alphaValue = 0.45
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 110_000_000)
            guard let self, !self.attention else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.18
                self.item.button?.animator().alphaValue = 1
            }, completionHandler: nil)
        }
    }

    @objc private func pulse() {
        pulseDim.toggle()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.7
            item.button?.animator().alphaValue = pulseDim ? 0.35 : 1
        }
    }

    // MARK: Rendering

    private func refresh() {
        guard let button = item.button else { return }

        let showTime = engine.state != .idle
        let text = showTime ? engine.timeString : ""
        let fraction = engine.fractionRemaining
        let signature = "\(engine.phase)|\(engine.state)|\(text)|\(Int(fraction * 400))|\(attention)"
        guard signature != lastSignature else { return }
        lastSignature = signature

        button.image = MenuBarGlyph.image(
            state: engine.state, phase: engine.phase, fraction: fraction, attention: attention
        )

        if text.isEmpty {
            button.attributedTitle = NSAttributedString(string: "")
        } else {
            button.attributedTitle = MenuBarGlyph.title(text, paused: engine.state == .paused)
        }

        let intention = engine.intention.trimmingCharacters(in: .whitespaces)
        var tip = intention.isEmpty ? "Tomatimer" : "Working on: \(intention)"
        if engine.state != .idle { tip += "\nClick to \(engine.state == .running ? "pause" : "resume") · Right-click for options" }
        button.toolTip = tip
    }
}

/// Menu bar artwork. 16 pt square glyphs, drawn at display resolution.
enum MenuBarGlyph {
    static let side: CGFloat = 16

    static func image(state: RunState, phase: Phase, fraction: Double, attention: Bool) -> NSImage {
        if attention && state != .running {
            return pie(fraction: 1, color: Theme.attention)
        }
        switch state {
        case .running: return pie(fraction: fraction, color: Theme.nsColor(for: phase))
        case .paused: return paused(fraction: fraction)
        case .idle: return idle()
        }
    }

    static func title(_ text: String, paused: Bool) -> NSAttributedString {
        NSAttributedString(string: " " + text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: paused ? NSColor.secondaryLabelColor : NSColor.labelColor,
            .baselineOffset: 0.5,
        ])
    }

    /// Outer ring + shrinking wedge (12 o'clock, clockwise) for the time left.
    static func pie(fraction: Double, color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let c = NSPoint(x: rect.midX, y: rect.midY)
            let ring = NSBezierPath(ovalIn: circleRect(c, 6.9))
            ring.lineWidth = 1.5
            color.setStroke()
            ring.stroke()

            color.withAlphaComponent(0.2).setFill()
            NSBezierPath(ovalIn: circleRect(c, 4.9)).fill()

            color.setFill()
            wedge(c, radius: 4.9, fraction: fraction)?.fill()
            return true
        }
    }

    /// Template: ring, faint remaining wedge, pause bars.
    static func paused(fraction: Double) -> NSImage {
        let img = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let c = NSPoint(x: rect.midX, y: rect.midY)
            let ring = NSBezierPath(ovalIn: circleRect(c, 6.9))
            ring.lineWidth = 1.5
            NSColor.black.setStroke()
            ring.stroke()

            NSColor.black.withAlphaComponent(0.22).setFill()
            wedge(c, radius: 4.9, fraction: fraction)?.fill()

            NSColor.black.setFill()
            for dx in [-1.75, 1.75] as [CGFloat] {
                NSBezierPath(roundedRect: NSRect(x: c.x + dx - 0.8, y: c.y - 2.75, width: 1.6, height: 5.5),
                             xRadius: 0.8, yRadius: 0.8).fill()
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    /// Template: small tomato outline (ring + calyx).
    static func idle() -> NSImage {
        let img = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let c = NSPoint(x: rect.midX, y: rect.midY - 1.2)
            let r: CGFloat = 6.0
            let body = NSBezierPath(ovalIn: circleRect(c, r))
            body.lineWidth = 1.5
            NSColor.black.setStroke()
            body.stroke()

            NSColor.black.setFill()
            let top = c.y + r
            for (dx, angle) in [(-2.5, 26.0), (2.5, -26.0)] as [(CGFloat, CGFloat)] {
                var t = AffineTransform(translationByX: c.x + dx, byY: top + 0.3)
                t.rotate(byDegrees: angle)
                let leaf = NSBezierPath(ovalIn: NSRect(x: -2.9, y: -1.2, width: 5.8, height: 2.4))
                leaf.transform(using: t)
                leaf.fill()
            }
            NSBezierPath(roundedRect: NSRect(x: c.x - 0.7, y: top - 0.2, width: 1.4, height: 3.2),
                         xRadius: 0.7, yRadius: 0.7).fill()
            return true
        }
        img.isTemplate = true
        return img
    }

    private static func circleRect(_ c: NSPoint, _ r: CGFloat) -> NSRect {
        NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
    }

    private static func wedge(_ c: NSPoint, radius: CGFloat, fraction: Double) -> NSBezierPath? {
        guard fraction > 0.002 else { return nil }
        if fraction >= 0.998 { return NSBezierPath(ovalIn: circleRect(c, radius)) }
        let p = NSBezierPath()
        p.move(to: c)
        p.appendArc(withCenter: c, radius: radius, startAngle: 90, endAngle: 90 - 360 * CGFloat(fraction), clockwise: true)
        p.close()
        return p
    }
}

@MainActor
func activateApp() {
    if #available(macOS 14.0, *) {
        NSApp.activate()
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }
}
