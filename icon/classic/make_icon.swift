// The original cream-and-orange icon, kept for reference. Draws it at every
// size macOS asks for and packs it into an .icns next to this file (the build
// uses icon/AppIcon.icns, not this one).
// Run from the project root: swift icon/classic/make_icon.swift
//
// Geometry follows Apple's macOS icon grid: a 1024 canvas with an 824pt
// continuous-corner body inset 100pt, so the system shows it as-is instead
// of boxing it in a grey squircle.
import AppKit

let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let paperTop = color(0xF6F3EC), paperBottom = color(0xE3DDD0)
let ink = color(0x2B2A27)
let signal = color(0xE4572E)

/// Rounded rect with continuous corners (curvature eases in, unlike a
/// circular arc), which is what makes the outline read as a macOS icon.
func squircle(_ rect: CGRect, radius r: CGFloat) -> CGPath {
    let path = CGMutablePath()
    // Each corner, walked counter-clockwise: `a` points back along the
    // incoming edge, `b` out along the outgoing one.
    let corners: [(CGPoint, CGVector, CGVector)] = [
        (CGPoint(x: rect.maxX, y: rect.minY), CGVector(dx: -1, dy: 0), CGVector(dx: 0, dy: 1)),
        (CGPoint(x: rect.maxX, y: rect.maxY), CGVector(dx: 0, dy: -1), CGVector(dx: -1, dy: 0)),
        (CGPoint(x: rect.minX, y: rect.maxY), CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: -1)),
        (CGPoint(x: rect.minX, y: rect.minY), CGVector(dx: 0, dy: 1), CGVector(dx: 1, dy: 0)),
    ]
    for (i, (c, a, b)) in corners.enumerated() {
        func p(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
            CGPoint(x: c.x + (a.dx * u + b.dx * v) * r, y: c.y + (a.dy * u + b.dy * v) * r)
        }
        if i == 0 { path.move(to: p(1.52866, 0)) } else { path.addLine(to: p(1.52866, 0)) }
        path.addCurve(to: p(0.63149, 0.07491), control1: p(1.08849, 0), control2: p(0.86841, 0))
        path.addCurve(to: p(0.07491, 0.63149), control1: p(0.37282, 0.16906), control2: p(0.16906, 0.37282))
        path.addCurve(to: p(0, 1.52866), control1: p(0, 0.86841), control2: p(0, 1.08849))
    }
    path.closeSubpath()
    return path
}

func capsule(_ rect: CGRect) -> CGPath {
    let r = min(rect.width, rect.height) / 2
    return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}

func verticalGradient(_ ctx: CGContext, _ rect: CGRect, _ stops: [(CGFloat, CGColor)]) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: stops.map(\.1) as CFArray, locations: stops.map(\.0))!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY),
                           end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
}

/// SF Symbols–style arrow (shaft plus open chevron, round caps), so the icon
/// sits in the same family as the menu bar glyph.
func arrow(_ ctx: CGContext, x: CGFloat, from y0: CGFloat, to y1: CGFloat,
           head: CGFloat, weight: CGFloat, color: CGColor) {
    let dir: CGFloat = y1 > y0 ? 1 : -1
    let path = CGMutablePath()
    path.move(to: CGPoint(x: x, y: y0))
    path.addLine(to: CGPoint(x: x, y: y1))
    path.move(to: CGPoint(x: x - head, y: y1 - dir * head))
    path.addLine(to: CGPoint(x: x, y: y1))
    path.addLine(to: CGPoint(x: x + head, y: y1 - dir * head))
    ctx.addPath(path)
    ctx.setStrokeColor(color)
    ctx.setLineWidth(weight)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
}

/// A mouse scroll wheel seen from above, sitting in its slot.
func wheel(_ ctx: CGContext, slot: CGRect, ridges: Bool) {
    ctx.addPath(capsule(slot))
    ctx.setFillColor(ink)
    ctx.fillPath()

    let roller = slot.insetBy(dx: 15, dy: 15)
    ctx.saveGState()
    ctx.addPath(capsule(roller))
    ctx.clip()
    // Lit from above: brightest just over the middle, falling off toward
    // both ends where the surface turns away.
    verticalGradient(ctx, roller, [(0, color(0x45433E)), (0.6, color(0xA9A59B)), (1, color(0x4F4D47))])

    if ridges {
        // Evenly spaced around the circumference, so they bunch up toward
        // the ends the way a real roller's grip does.
        let radius = roller.height / 2 - 6
        for k in -8...8 {
            let theta = CGFloat(k) * .pi / 19
            let y = roller.midY + radius * sin(theta)
            let t = 9 * cos(theta)
            ctx.setFillColor(color(0x000000, 0.34))
            ctx.fill(CGRect(x: roller.minX, y: y - t / 2, width: roller.width, height: t))
            ctx.setFillColor(color(0xFFFFFF, 0.14))
            ctx.fill(CGRect(x: roller.minX, y: y - t / 2 - 3 * cos(theta), width: roller.width,
                            height: 3 * cos(theta)))
        }
    }
    ctx.restoreGState()
}

/// `points` is the size the image stands in for, not its pixel count: the
/// 16pt and 32pt slots get heavier strokes and lose the fine ridges.
func draw(_ ctx: CGContext, pixelScale s: CGFloat, points: Int) {
    let body = squircle(CGRect(x: 100, y: 100, width: 824, height: 824), radius: 185.4)

    // Shadow offsets ignore the CTM, so scale them by hand.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 20 * s, color: color(0x000000, 0.3))
    ctx.addPath(body)
    ctx.setFillColor(paperBottom)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    verticalGradient(ctx, CGRect(x: 100, y: 100, width: 824, height: 824),
                     [(0, paperBottom), (1, paperTop)])
    ctx.restoreGState()

    let weight: CGFloat = points <= 16 ? 80 : points <= 32 ? 66 : 54
    wheel(ctx, slot: CGRect(x: 444, y: 262, width: 136, height: 500), ridges: points >= 128)
    arrow(ctx, x: 298, from: 324, to: 700, head: 72, weight: weight, color: ink)
    arrow(ctx, x: 726, from: 700, to: 324, head: 72, weight: weight, color: signal)
}

func render(points: Int, scale: Int) -> CGImage {
    let px = points * scale
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let s = CGFloat(px) / 1024
    ctx.scaleBy(x: s, y: s)
    draw(ctx, pixelScale: s, points: points)
    return ctx.makeImage()!
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        let url = iconset.appendingPathComponent(name)
        let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, render(points: points, scale: scale), nil)
        guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(name)") }
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", dir.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("wrote \(dir.appendingPathComponent("AppIcon.icns").path)")
