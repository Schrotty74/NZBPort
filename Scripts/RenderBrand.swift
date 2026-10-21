import AppKit

// Original port mark: offset incoming route and a low, asymmetric dock.
// No system symbol, font glyph, or third-party artwork is used.
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let icon = folder.appendingPathComponent("NZBPort.icon/Assets/Port.svg")
let svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<g fill="#FFFFFF">
<path d="M248 600 L322 600 L340 704 Q344 728 372 728 L682 728 Q706 728 713 705 L749 600 L826 600 L784 732 Q764 800 690 800 L366 800 Q286 800 274 728 Z"/>
<path d="M218 236 L470 236 Q562 236 562 328 L562 486 L642 486 L522 620 L402 486 L482 486 L482 328 Q482 312 466 312 L218 312 Z"/>
</g></svg>
"""
try Data(svg.utf8).write(to: icon)

let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 512, pixelsHigh: 512,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: image)
let context = NSGraphicsContext.current!.cgContext
context.translateBy(x: 0, y: 512)
context.scaleBy(x: 0.8, y: -0.8)
context.translateBy(x: -200, y: -200)
NSColor.white.setFill()
let dock = NSBezierPath()
dock.move(to: .init(x: 248, y: 600)); dock.line(to: .init(x: 322, y: 600))
dock.line(to: .init(x: 340, y: 704)); dock.curve(to: .init(x: 372, y: 728), controlPoint1: .init(x: 344, y: 728), controlPoint2: .init(x: 344, y: 728))
dock.line(to: .init(x: 682, y: 728)); dock.curve(to: .init(x: 713, y: 705), controlPoint1: .init(x: 706, y: 728), controlPoint2: .init(x: 706, y: 728))
dock.line(to: .init(x: 749, y: 600)); dock.line(to: .init(x: 826, y: 600)); dock.line(to: .init(x: 784, y: 732))
dock.curve(to: .init(x: 690, y: 800), controlPoint1: .init(x: 764, y: 800), controlPoint2: .init(x: 764, y: 800))
dock.line(to: .init(x: 366, y: 800)); dock.curve(to: .init(x: 274, y: 728), controlPoint1: .init(x: 286, y: 800), controlPoint2: .init(x: 286, y: 800)); dock.close(); dock.fill()
let route = NSBezierPath()
route.move(to: .init(x: 218, y: 236)); route.line(to: .init(x: 470, y: 236))
route.curve(to: .init(x: 562, y: 328), controlPoint1: .init(x: 562, y: 236), controlPoint2: .init(x: 562, y: 236))
for p in [NSPoint(x: 562,y: 486), .init(x: 642,y: 486), .init(x: 522,y: 620), .init(x: 402,y: 486), .init(x: 482,y: 486), .init(x: 482,y: 328)] { route.line(to: p) }
route.curve(to: .init(x: 466,y: 312), controlPoint1: .init(x: 482,y: 312), controlPoint2: .init(x: 482,y: 312))
route.line(to: .init(x: 218,y: 312)); route.close(); route.fill()
NSGraphicsContext.restoreGraphicsState()
try image.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("BrandMark.png"))
