import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
let canvas: CGFloat = 1024

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("Could not create bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS icon grid: 824pt body centred on a 1024pt canvas.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.shadowBlurRadius = 28
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()
NSColor.black.setFill()
squircle.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(colors: [
    NSColor(calibratedRed: 0.36, green: 0.62, blue: 1.00, alpha: 1),
    NSColor(calibratedRed: 0.20, green: 0.33, blue: 0.95, alpha: 1),
    NSColor(calibratedRed: 0.42, green: 0.22, blue: 0.86, alpha: 1),
])!.draw(in: squircle, angle: -70)

NSGraphicsContext.saveGraphicsState()
squircle.addClip()
NSGradient(colors: [NSColor.white.withAlphaComponent(0.35), NSColor.white.withAlphaComponent(0)])!
    .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
NSGraphicsContext.restoreGraphicsState()

let rim = NSBezierPath(roundedRect: body.insetBy(dx: 2, dy: 2), xRadius: 184, yRadius: 184)
rim.lineWidth = 4
NSColor.white.withAlphaComponent(0.35).setStroke()
rim.stroke()

let config = NSImage.SymbolConfiguration(pointSize: 440, weight: .semibold)
    .applying(.init(paletteColors: [.white]))
if let symbol = NSImage(systemSymbolName: "list.clipboard.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let size = symbol.size
    let rect = NSRect(x: (canvas - size.width) / 2, y: (canvas - size.height) / 2 - 6, width: size.width, height: size.height)
    NSGraphicsContext.saveGraphicsState()
    let glyphShadow = NSShadow()
    glyphShadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    glyphShadow.shadowBlurRadius = 18
    glyphShadow.shadowOffset = NSSize(width: 0, height: -8)
    glyphShadow.set()
    symbol.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("Could not encode PNG") }
try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
