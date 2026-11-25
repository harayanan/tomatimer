import AppKit
import SwiftUI
import Combine

/// Owns the menu bar item (ring + countdown) and its popover.
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
            button.action = #selector(togglePopover)
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

    /// Pulse the item and tint it amber while the user has drifted off.
    func setAttention(_ on: Bool) {
        guard on != attention else { return }
        attention = on
        pulseTimer?.invalidate()
        pulseTimer = nil
        item.button?.alphaValue = 1
        if on {
            let t = Timer(timeInterval: 0.7, target: self, selector: #selector(pulse), userInfo: nil, repeats: true)
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

    @objc private func pulse() {
        pulseDim.toggle()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            item.button?.animator().alphaValue = pulseDim ? 0.3 : 1
        }
    }

    @objc private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            engine.refreshDay()
            activateApp()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func refresh() {
        guard let button = item.button else { return }

        let showTime = engine.state != .idle
        let text = showTime ? engine.timeString : ""
        // Quantise the ring so the image is only redrawn when it visibly changes.
        let steps = Int((engine.fractionRemaining * 48).rounded())
        let signature = "\(engine.phase)|\(engine.state)|\(text)|\(steps)|\(attention)"
        guard signature != lastSignature else { return }
        lastSignature = signature

        let color: NSColor
        switch engine.state {
        case .running: color = Theme.nsColor(for: engine.phase)
        case .paused: color = .secondaryLabelColor
        case .idle: color = attention ? Theme.attention : .labelColor
        }

        let image: NSImage
        if engine.state == .idle && !attention {
            image = Self.ringImage(fraction: 1, color: .black, trackAlpha: 1)
            image.isTemplate = true
        } else {
            let fraction = engine.state == .idle ? 1 : Double(steps) / 48
            image = Self.ringImage(fraction: fraction, color: color, trackAlpha: 0.28)
        }
        button.image = image

        if text.isEmpty {
            button.attributedTitle = NSAttributedString(string: "")
        } else {
            let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
            button.attributedTitle = NSAttributedString(string: " " + text, attributes: [
                .font: font,
                .foregroundColor: engine.state == .paused ? NSColor.secondaryLabelColor : NSColor.labelColor,
                .baselineOffset: 0.5,
            ])
        }

        let intention = engine.intention.trimmingCharacters(in: .whitespaces)
        button.toolTip = intention.isEmpty ? "Tomatimer" : "Working on: \(intention)"
    }

    /// 16 pt ring: faint track plus an arc for the time left, starting at 12 o'clock.
    static func ringImage(fraction: Double, color: NSColor, trackAlpha: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            let lineWidth: CGFloat = 2.2
            let inset = rect.insetBy(dx: 1.8, dy: 1.8)
            let track = NSBezierPath(ovalIn: inset)
            track.lineWidth = lineWidth
            color.withAlphaComponent(trackAlpha).setStroke()
            track.stroke()

            if fraction > 0.001 && trackAlpha < 1 {
                let arc = NSBezierPath()
                arc.appendArc(
                    withCenter: NSPoint(x: rect.midX, y: rect.midY),
                    radius: inset.width / 2,
                    startAngle: 90,
                    endAngle: 90 - 360 * CGFloat(fraction),
                    clockwise: true
                )
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                color.setStroke()
                arc.stroke()
            }
            return true
        }
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
