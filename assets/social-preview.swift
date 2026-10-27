// Renders the NoFlickerBar social preview (1280x640 PNG): swift assets/social-preview.swift assets/social-preview.png
import AppKit

let W: CGFloat = 1280, H: CGFloat = 640
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "social-preview.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(deviceRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

// Background: near-black with a faint vertical gradient.
NSGradient(starting: rgb(24, 24, 28), ending: rgb(10, 10, 12))!
    .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, at p: NSPoint,
          mono: Bool = false, kern: CGFloat = 0) {
    let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
                    : NSFont.systemFont(ofSize: size, weight: weight)
    NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .kern: kern])
        .draw(at: p)
}

let left: CGFloat = 96

// Title and tagline.
text("NoFlickerBar", size: 76, weight: .bold, color: .white, at: NSPoint(x: left, y: 470), kern: -1.5)
text("Stops the idle flicker of a faulty MacBook Pro Touch Bar",
     size: 30, weight: .regular, color: rgb(170, 170, 178), at: NSPoint(x: left, y: 422))

// Touch Bar strip geometry.
let barW: CGFloat = 900, barH: CGFloat = 56
let barX = left + 130

func strip(y: CGFloat, glitch: Bool) {
    let r = NSRect(x: barX, y: y, width: barW, height: barH)
    let path = NSBezierPath(roundedRect: r, xRadius: 10, yRadius: 10)
    rgb(4, 4, 5).setFill()
    path.fill()

    if glitch {
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        // Dim glowing patch on the right fifth, seen between flashes.
        let glowW = barW / 5
        NSGradient(colors: [rgb(40, 40, 46, 0), rgb(110, 110, 120, 0.6)])!
            .draw(in: NSRect(x: r.maxX - glowW, y: r.minY, width: glowW, height: barH), angle: 0)
        // A flash lights the right two thirds as one bright field and covers the patch.
        let flashW = barW * 2 / 3
        let edge: CGFloat = 60
        let bright = rgb(228, 231, 242)
        NSGradient(colors: [bright.withAlphaComponent(0), bright])!
            .draw(in: NSRect(x: r.maxX - flashW, y: r.minY, width: edge, height: barH), angle: 0)
        bright.setFill()
        NSBezierPath(rect: NSRect(x: r.maxX - flashW + edge, y: r.minY, width: flashW - edge, height: barH)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    rgb(70, 70, 78).setStroke()
    path.lineWidth = 2
    path.stroke()
}

let beforeY: CGFloat = 270, afterY: CGFloat = 175
strip(y: beforeY, glitch: true)
strip(y: afterY, glitch: false)

text("before", size: 26, weight: .medium, color: rgb(255, 120, 110), at: NSPoint(x: left, y: beforeY + 13))
text("after", size: 26, weight: .medium, color: rgb(120, 220, 150), at: NSPoint(x: left, y: afterY + 13))

// Footer.
text("github.com/Lykoi18/NoFlickerBar", size: 26, weight: .regular, color: rgb(210, 210, 216),
     at: NSPoint(x: left, y: 78), mono: true)
let meta = "macOS · no SIP changes · free & open source"
let metaFont = NSFont.systemFont(ofSize: 22, weight: .regular)
let metaW = (meta as NSString).size(withAttributes: [.font: metaFont]).width
text(meta, size: 22, weight: .regular, color: rgb(130, 130, 138), at: NSPoint(x: W - 96 - metaW, y: 82))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
