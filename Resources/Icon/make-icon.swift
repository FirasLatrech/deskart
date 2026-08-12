import AppKit
// Generate the app icon: cyan dots forming a shape on a dark rounded square,
// echoing the preview canvas.
func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let r = CGRect(x: 0, y: 0, width: size, height: size)
    // Rounded-square background, macOS "squircle"-ish
    let inset = size * 0.055
    let bg = NSBezierPath(roundedRect: r.insetBy(dx: inset, dy: inset),
                          xRadius: size * 0.225, yRadius: size * 0.225)
    NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.14, alpha: 1).setFill()
    bg.fill()
    // Dot ring + centre, a miniature "arrangement"
    let cx = size/2, cy = size/2
    let dot = size * 0.052
    func fill(_ x: CGFloat, _ y: CGFloat, _ c: NSColor, _ scale: CGFloat = 1) {
        c.setFill()
        NSBezierPath(ovalIn: CGRect(x: x-dot*scale, y: y-dot*scale,
                                    width: dot*2*scale, height: dot*2*scale)).fill()
    }
    let cyan = NSColor(calibratedRed: 0.28, green: 0.78, blue: 0.96, alpha: 1)
    let ring = size * 0.245
    for i in 0..<10 {
        let a = CGFloat(i) / 10 * .pi * 2 - .pi/2
        fill(cx + ring*cos(a), cy + ring*sin(a), cyan)
    }
    fill(cx, cy, cyan, 1.15)
    // A few "parked" dots in the corner, matching the app's own behaviour
    let g = NSColor(calibratedWhite: 1, alpha: 0.22)
    for r0 in 0..<2 { for c0 in 0..<2 {
        fill(size*0.845 - CGFloat(c0)*dot*2.4, size*0.155 + CGFloat(r0)*dot*2.4, g, 0.68)
    } }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}
let out = CommandLine.arguments[1]
for s in [16,32,64,128,256,512,1024] {
    let rep = drawIcon(size: CGFloat(s))
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(out)/icon_\(s).png"))
}
print("icons written")
