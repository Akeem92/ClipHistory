// Draws the app icon at every size macOS asks for, into ClipHistory.iconset/.
// build.sh then hands that folder to `iconutil` to pack it into ClipHistory.icns.
//
// Deliberately no image assets: the icon is drawn with Bezier paths so there is
// nothing binary in the repo and you can restyle it by editing numbers here.
//
// Run directly:  swift Tools/make-icon.swift
// Lives outside Sources/ so SPM does not compile it into the app.

import AppKit

// The exact filenames `iconutil` requires. Anything missing and it refuses to pack.
let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

func renderIcon(pixels: Int) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let side = CGFloat(pixels)

    // macOS icons don't fill their canvas — the rounded square sits inside a margin,
    // which is why Apple's icons all look optically the same size in the Dock.
    let inset = side * 0.09
    let plate = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let cornerRadius = plate.width * 0.235

    let squircle = NSBezierPath(roundedRect: plate, xRadius: cornerRadius, yRadius: cornerRadius)
    if let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.36, green: 0.56, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 0.15, green: 0.25, blue: 0.79, alpha: 1),
    ]) {
        gradient.draw(in: squircle, angle: -90)
    }

    // Glyph: two offset cards, i.e. a stack of past clippings.
    let cardWidth = plate.width * 0.46
    let cardHeight = plate.height * 0.56
    let cardCorner = cardWidth * 0.14

    let backCard = NSRect(
        x: plate.midX - cardWidth / 2 + plate.width * 0.075,
        y: plate.midY - cardHeight / 2 + plate.height * 0.075,
        width: cardWidth, height: cardHeight
    )
    NSColor(white: 1, alpha: 0.45).setFill()
    NSBezierPath(roundedRect: backCard, xRadius: cardCorner, yRadius: cardCorner).fill()

    let frontCard = NSRect(
        x: plate.midX - cardWidth / 2 - plate.width * 0.045,
        y: plate.midY - cardHeight / 2 - plate.height * 0.055,
        width: cardWidth, height: cardHeight
    )
    NSColor.white.setFill()
    NSBezierPath(roundedRect: frontCard, xRadius: cardCorner, yRadius: cardCorner).fill()

    // Text lines, skipped below 64px where they'd just turn to mud.
    if pixels >= 64 {
        NSColor(srgbRed: 0.19, green: 0.31, blue: 0.84, alpha: 1).setFill()
        let lineHeight = max(1, frontCard.height * 0.055)
        let lineX = frontCard.minX + frontCard.width * 0.17
        for (index, widthFraction) in [0.66, 0.50, 0.58].enumerated() {
            let y = frontCard.maxY - frontCard.height * (0.28 + CGFloat(index) * 0.20)
            let line = NSRect(
                x: lineX, y: y,
                width: frontCard.width * CGFloat(widthFraction),
                height: lineHeight
            )
            NSBezierPath(roundedRect: line, xRadius: lineHeight / 2, yRadius: lineHeight / 2).fill()
        }
    }

    return rep
}

let outputDirectory = URL(fileURLWithPath: "ClipHistory.iconset")
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

var written = 0
for variant in variants {
    guard
        let rep = renderIcon(pixels: variant.pixels),
        let png = rep.representation(using: .png, properties: [:])
    else {
        print("!! failed to render \(variant.name)")
        continue
    }
    let url = outputDirectory.appendingPathComponent("\(variant.name).png")
    if (try? png.write(to: url)) != nil {
        written += 1
    } else {
        print("!! failed to write \(url.lastPathComponent)")
    }
}

print("    rendered \(written)/\(variants.count) sizes into ClipHistory.iconset/")
exit(written == variants.count ? 0 : 1)
