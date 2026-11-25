// Draws the Tomatimer app icon into an .iconset folder.
// Usage: swift scripts/make-icon.swift <out.iconset>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func drawIcon(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let scale = CGFloat(pixels) / 1024
    ctx.cgContext.scaleBy(x: scale, y: scale)

    // Squircle tile (macOS icon grid: 824 pt body inside 1024 canvas).
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -12 * scale)
    shadow.shadowBlurRadius = 28 * scale
    shadow.set()
    rgb(229, 56, 43).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: rgb(255, 122, 92), ending: rgb(222, 48, 38))!.draw(in: tile, angle: -90)

    // Soft top highlight.
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    NSGradient(starting: NSColor.white.withAlphaComponent(0.18), ending: NSColor.white.withAlphaComponent(0))!
        .draw(in: NSRect(x: 100, y: 560, width: 824, height: 364), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Timer ring: faint track + 75% arc from 12 o'clock, clockwise.
    let center = NSPoint(x: 512, y: 488)
    let radius: CGFloat = 245
    let track = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    track.lineWidth = 72
    NSColor.white.withAlphaComponent(0.26).setStroke()
    track.stroke()

    let arc = NSBezierPath()
    arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 270, clockwise: true)
    arc.lineWidth = 72
    arc.lineCapStyle = .round
    NSColor.white.setStroke()
    arc.stroke()

    // Leaves at the top, like a tomato stem.
    let green = rgb(52, 199, 112)
    for (dx, angle) in [(-62.0, 28.0), (62.0, -28.0)] {
        var t = AffineTransform(translationByX: 512 + dx, byY: center.y + radius + 28)
        t.rotate(byDegrees: angle)
        let leaf = NSBezierPath(ovalIn: NSRect(x: -78, y: -30, width: 156, height: 60))
        leaf.transform(using: t)
        green.setFill()
        leaf.fill()
    }
    let stem = NSBezierPath(roundedRect: NSRect(x: 497, y: center.y + radius + 20, width: 30, height: 78), xRadius: 15, yRadius: 15)
    rgb(36, 160, 88).setFill()
    stem.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(Int, String)] = [
    (16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"),
    (128, "128x128"), (256, "128x128@2x"), (256, "256x256"), (512, "256x256@2x"),
    (512, "512x512"), (1024, "512x512@2x"),
]
for (px, name) in sizes {
    try drawIcon(pixels: px).write(to: URL(fileURLWithPath: "\(outDir)/icon_\(name).png"))
}
print("icon written to \(outDir)")
