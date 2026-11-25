// Рисует иконку программы: тёмный скруглённый квадрат с мини-графом. Аргумент — папка .iconset
import Cocoa

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024
    let bg = NSBezierPath(roundedRect: NSRect(x: 100*s, y: 100*s, width: 824*s, height: 824*s), xRadius: 185*s, yRadius: 185*s)
    NSColor(calibratedWhite: 0.06, alpha: 1).setFill(); bg.fill()
    NSColor(calibratedWhite: 0.18, alpha: 1).setStroke(); bg.lineWidth = 6*s; bg.stroke()

    let root = NSPoint(x: 260*s, y: 512*s)
    let mids = [NSPoint(x: 520*s, y: 700*s), NSPoint(x: 520*s, y: 512*s), NSPoint(x: 520*s, y: 324*s)]
    let leaves: [[CGFloat]] = [[770, 780], [770, 680], [770, 512], [770, 380], [770, 268]]
    let parentOf = [0, 0, 1, 2, 2]
    NSColor(calibratedWhite: 1, alpha: 0.55).setStroke()
    func curve(_ a: NSPoint, _ b: NSPoint) {
        let p = NSBezierPath(); p.move(to: a)
        let mx = (a.x + b.x) / 2
        p.curve(to: b, controlPoint1: NSPoint(x: mx, y: a.y), controlPoint2: NSPoint(x: mx, y: b.y))
        p.lineWidth = 14*s; p.lineCapStyle = .round; p.stroke()
    }
    for m in mids { curve(root, m) }
    for (i, l) in leaves.enumerated() { curve(mids[parentOf[i]], NSPoint(x: l[0]*s, y: l[1]*s)) }
    func dot(_ p: NSPoint, _ r: CGFloat, _ c: NSColor) { c.setFill(); NSBezierPath(ovalIn: NSRect(x: p.x-r, y: p.y-r, width: r*2, height: r*2)).fill() }
    dot(root, 46*s, NSColor(calibratedRed: 0.48, green: 0.64, blue: 1, alpha: 1))
    for m in mids { dot(m, 26*s, NSColor(calibratedWhite: 0.9, alpha: 1)) }
    let leafColors = [NSColor(calibratedRed: 0.29, green: 0.87, blue: 0.5, alpha: 1), .init(calibratedWhite: 0.85, alpha: 1),
                      NSColor(calibratedRed: 0.98, green: 0.75, blue: 0.14, alpha: 1), .init(calibratedWhite: 0.85, alpha: 1),
                      NSColor(calibratedRed: 0.97, green: 0.44, blue: 0.44, alpha: 1)]
    for (i, l) in leaves.enumerated() { dot(NSPoint(x: l[0]*s, y: l[1]*s), 22*s, leafColors[i]) }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (size, scale) in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
    let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
    try! draw(size*scale).write(to: URL(fileURLWithPath: out).appendingPathComponent(name))
}
