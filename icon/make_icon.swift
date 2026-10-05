// Renders the app icon SVGs next to this file into icon/AppIcon.icns.
// Run from the project root: swift icon/make_icon.swift
//
// The artwork comes from the ScrollToggle design system: AppIcon.svg is the
// master for 64px and up, while AppIcon-32px.svg and AppIcon-16px.svg are
// redrawn for the small slots (heavier arrows, no seam at 16px). WebKit does
// the rasterizing because the SVGs rely on masks and a drop-shadow filter
// that NSImage's SVG support leaves out.
import AppKit
import WebKit

let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

/// Every slot an .icns carries, with the SVG drawn for that pixel size.
let slots: [(name: String, svg: String, pixels: Int)] = [
    ("icon_16x16", "AppIcon-16px.svg", 16),
    ("icon_16x16@2x", "AppIcon-32px.svg", 32),
    ("icon_32x32", "AppIcon-32px.svg", 32),
    ("icon_32x32@2x", "AppIcon.svg", 64),
    ("icon_128x128", "AppIcon.svg", 128),
    ("icon_128x128@2x", "AppIcon.svg", 256),
    ("icon_256x256", "AppIcon.svg", 256),
    ("icon_256x256@2x", "AppIcon.svg", 512),
    ("icon_512x512", "AppIcon.svg", 512),
    ("icon_512x512@2x", "AppIcon.svg", 1024),
]

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

/// The snapshot comes back at the screen's backing scale, so redraw it at
/// exactly `pixels` square before saving.
func writePNG(_ image: NSImage, pixels: Int, to url: URL) {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    var rect = CGRect(x: 0, y: 0, width: pixels, height: pixels)
    ctx.draw(image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!, in: rect)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(url.lastPathComponent)") }
}

func packIcns() {
    let out = dir.appendingPathComponent("AppIcon.icns")
    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconset.path, "-o", out.path]
    try! iconutil.run()
    iconutil.waitUntilExit()
    guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
    print("wrote \(out.path)")
}

/// Loads each SVG into an offscreen web view, one after another, and
/// snapshots it at its slot's size.
final class Renderer: NSObject, WKNavigationDelegate {
    private let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1024, height: 1024))
    private var pending = slots[...]

    override init() {
        super.init()
        web.setValue(false, forKey: "drawsBackground")  // keep the corners transparent
        web.navigationDelegate = self
        loadNext()
    }

    private func loadNext() {
        guard let slot = pending.first else {
            packIcns()
            exit(0)
        }
        web.loadFileURL(dir.appendingPathComponent(slot.svg), allowingReadAccessTo: dir)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let slot = pending.removeFirst()
        let config = WKSnapshotConfiguration()
        config.rect = web.bounds
        config.snapshotWidth = NSNumber(value: slot.pixels)
        web.takeSnapshot(with: config) { image, error in
            guard let image else { fatalError("could not render \(slot.svg): \(String(describing: error))") }
            writePNG(image, pixels: slot.pixels, to: iconset.appendingPathComponent(slot.name + ".png"))
            self.loadNext()
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        fatalError("could not load \(pending.first?.svg ?? "?"): \(error)")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let renderer = Renderer()
app.run()
