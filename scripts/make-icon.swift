#!/usr/bin/env swift
// Generates a 1024×1024 master app-icon PNG: a teal-gradient rounded-rect with a
// white mosque (crescent + onion dome + base), matching the menu bar glyph.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let size = 1024.0

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Rounded-rect "body" (macOS-style margins + corner radius).
let inset = size * 0.092
let body = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let radius = body.width * 0.2237

ctx.saveGState()
let bg = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
bg.addClip()
let grad = NSGradient(colors: [
    NSColor(srgbRed: 0.13, green: 0.60, blue: 0.55, alpha: 1),
    NSColor(srgbRed: 0.05, green: 0.34, blue: 0.40, alpha: 1),
])!
grad.draw(in: body, angle: -90)
ctx.restoreGState()

// --- Mosque, authored in a 0..100 (y-down) box, then transformed into `body`. ---
func cubic(_ p: NSBezierPath, _ to: (Double, Double), _ c1: (Double, Double), _ c2: (Double, Double)) {
    p.curve(to: NSPoint(x: to.0, y: to.1),
            controlPoint1: NSPoint(x: c1.0, y: c1.1),
            controlPoint2: NSPoint(x: c2.0, y: c2.1))
}

let bodyPath = NSBezierPath()
// onion dome
bodyPath.move(to: NSPoint(x: 50, y: 23))
cubic(bodyPath, (80, 57), (56, 31), (80, 45))
cubic(bodyPath, (50, 75), (80, 69), (66, 75))
cubic(bodyPath, (20, 57), (34, 75), (20, 69))
cubic(bodyPath, (50, 23), (20, 45), (44, 31))
bodyPath.close()
// neck
bodyPath.appendRect(NSRect(x: 46.5, y: 18, width: 7, height: 9))
// base bar (rounded)
bodyPath.append(NSBezierPath(roundedRect: NSRect(x: 16, y: 80, width: 68, height: 13), xRadius: 5, yRadius: 5))

// crescent: outer circle minus an offset inner circle (even-odd)
let crescent = NSBezierPath()
crescent.appendOval(in: NSRect(x: 42, y: 3, width: 16, height: 16))   // center (50,11) r8
crescent.appendOval(in: NSRect(x: 47, y: -0.5, width: 14, height: 14)) // center (54,6.5) r7
crescent.windingRule = .evenOdd

// Transform: fit the 100-box centered in `body`, flipping y (svg is y-down).
let scale = body.height * 0.62 / 100.0
let boxW = 100 * scale
var t = AffineTransform.identity
t.translate(x: body.midX - boxW / 2, y: body.midY + (100 * scale) / 2)
t.scale(x: scale, y: -scale)
bodyPath.transform(using: t)
crescent.transform(using: t)

NSColor.white.setFill()
bodyPath.fill()
crescent.fill()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to encode PNG\n".utf8)); exit(1)
}
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
