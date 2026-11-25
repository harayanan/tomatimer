import AppKit
import SwiftUI

/// `Tomatimer --snapshot <dir>` renders the UI to PNGs and exits.
/// CI runs this so the design can be reviewed without a Mac at hand.
@MainActor
enum Snapshot {
    static func run(outDir: String) {
        let out = URL(fileURLWithPath: outDir)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        PromptBody.animate = false

        let settings = Settings()
        let engine = TimerEngine(settings: settings)
        engine.intention = "Q3 board deck: market sizing"

        // Menu bar states
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            save(menuBarStrip(appearance: appearance), to: out.appendingPathComponent("menubar-\(name).png"))
        }

        // Popover states
        let states: [(String, Phase, RunState, Double, Int, Bool)] = [
            ("running", .focus, .running, 0.62, 2, false),
            ("paused", .focus, .paused, 0.41, 2, false),
            ("break", .shortBreak, .running, 0.55, 3, false),
            ("idle", .focus, .idle, 1, 0, false),
            ("settings", .focus, .running, 0.62, 2, true),
        ]
        for (name, phase, state, fraction, cycle, showSettings) in states {
            engine.debugSet(phase: phase, state: state, fraction: fraction, cycle: cycle, today: cycle + 3)
            for (mode, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
                let view = PopoverView(engine: engine, settings: settings, onQuit: {}, showSettings: showSettings)
                    .background(appearance == .darkAqua ? Color(white: 0.17) : Color(white: 0.96))
                render(view, appearance: appearance, name: "popover-\(name)-\(mode)", out: out)
            }
        }

        // Prompts
        engine.debugSet(phase: .shortBreak, state: .idle, fraction: 1, cycle: 2, today: 5)
        let breakPrompt = Prompt(
            symbol: "leaf.fill", tint: Theme.color(for: .shortBreak),
            eyebrow: "Focus complete · 5 today", title: "Take a 5-minute break",
            detail: "Stand up, drink water, look at something far away.", intention: nil,
            primary: PromptAction(title: "Start break") {}, secondary: PromptAction(title: "Skip break") {},
            tertiary: PromptAction(title: "Close") {}
        )
        let backPrompt = Prompt(
            symbol: "target", tint: Theme.color(for: .focus),
            eyebrow: "Break over", title: "Back to work", detail: nil,
            intention: .constant("Q3 board deck: market sizing"),
            primary: PromptAction(title: "Start focus") {}, secondary: PromptAction(title: "5 more minutes") {},
            tertiary: PromptAction(title: "Done for today") {}
        )
        let awayPrompt = Prompt(
            symbol: "arrow.uturn.backward.circle.fill", tint: Theme.color(for: .focus),
            eyebrow: "Welcome back", title: "Away 7 min",
            detail: "Resume: Q3 board deck: market sizing · 11:42 left", intention: nil,
            primary: PromptAction(title: "Back to it") {}, secondary: PromptAction(title: "Restart block") {},
            tertiary: PromptAction(title: "Pause timer") {}
        )
        for (name, prompt) in [("overlay-break", breakPrompt), ("overlay-back", backPrompt)] {
            let view = ZStack {
                LinearGradient(colors: [Color(red: 0.16, green: 0.13, blue: 0.20), Color(red: 0.07, green: 0.07, blue: 0.10)],
                               startPoint: .top, endPoint: .bottom)
                PromptBody(prompt: prompt, large: true).frame(maxWidth: 640)
            }
            .frame(width: 1440, height: 900)
            render(view, appearance: .darkAqua, name: name, out: out)
        }
        let card = ZStack {
            LinearGradient(colors: [Color(red: 0.35, green: 0.45, blue: 0.62), Color(red: 0.62, green: 0.48, blue: 0.55)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            PromptBody(prompt: awayPrompt, large: false)
                .frame(width: 420)
                .padding(.vertical, 28)
                .padding(.horizontal, 24)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.12).opacity(0.92)))
        }
        .frame(width: 760, height: 460)
        render(card, appearance: .darkAqua, name: "card-away", out: out)

        print("snapshots written to \(outDir)")
    }

    // MARK: Rendering

    /// Renders with two methods (SwiftUI ImageRenderer and AppKit layer render), since each
    /// handles different controls; the reviewer picks whichever is faithful.
    private static func render<V: View>(_ view: V, appearance: NSAppearance.Name, name: String, out: URL) {
        let scheme: ColorScheme = appearance == .darkAqua ? .dark : .light
        let themed = view.environment(\.colorScheme, scheme)

        let renderer = ImageRenderer(content: themed)
        renderer.scale = 2
        if let img = renderer.nsImage, let data = png(from: img) {
            try? data.write(to: out.appendingPathComponent("\(name).png"))
        }

        let hosting = NSHostingView(rootView: themed)
        hosting.appearance = NSAppearance(named: appearance)
        let size = hosting.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = hosting
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: out.appendingPathComponent("\(name)@appkit.png"))
        }
    }

    private static func menuBarStrip(appearance: NSAppearance.Name) -> Data? {
        let rows: [(NSImage, String?, Bool)] = [
            (MenuBarGlyph.image(state: .running, phase: .focus, fraction: 0.70, attention: false), "17:30", false),
            (MenuBarGlyph.image(state: .running, phase: .focus, fraction: 0.20, attention: false), "4:58", false),
            (MenuBarGlyph.image(state: .running, phase: .shortBreak, fraction: 0.45, attention: false), "2:15", false),
            (MenuBarGlyph.image(state: .running, phase: .longBreak, fraction: 0.85, attention: false), "12:44", false),
            (MenuBarGlyph.image(state: .paused, phase: .focus, fraction: 0.55, attention: false), "13:45", true),
            (MenuBarGlyph.image(state: .idle, phase: .focus, fraction: 1, attention: false), nil, false),
            (MenuBarGlyph.image(state: .idle, phase: .focus, fraction: 1, attention: true), nil, false),
        ]
        let scale: CGFloat = 4
        let width: CGFloat = 560, height: CGFloat = 24
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: width, height: height)
        let dark = appearance == .darkAqua
        NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            (dark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
            var x: CGFloat = 12
            for (image, text, paused) in rows {
                let glyph = image.isTemplate ? tinted(image, dark ? .white : .black) : image
                glyph.draw(in: NSRect(x: x, y: 4, width: 16, height: 16))
                x += 16
                if let text {
                    let title = MenuBarGlyph.title(text, paused: paused)
                    title.draw(at: NSPoint(x: x, y: 4))
                    x += title.size().width
                }
                x += 22
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        return rep.representation(using: .png, properties: [:])
    }

    private static func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }

    private static func png(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private static func save(_ data: Data?, to url: URL) {
        try? data?.write(to: url)
    }
}
