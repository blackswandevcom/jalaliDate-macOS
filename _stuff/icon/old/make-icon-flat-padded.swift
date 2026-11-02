#!/usr/bin/env swift
// make-icon.swift — draws the jDate app icon (vector, CoreGraphics + CoreText)
// and writes every macOS AppIcon size into Assets.xcassets/AppIcon.appiconset.
//
// Run from the project root:  swift _stuff/icon/make-icon.swift
// Also writes _stuff/icon/jdate-icon-1024.png as a preview/master.

import AppKit
import CoreText
import Foundation

// MARK: - Paths

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let iconDir = scriptURL.deletingLastPathComponent()
let projectRoot = iconDir.deletingLastPathComponent().deletingLastPathComponent()
let appIconSet = projectRoot.appendingPathComponent("JalaliDateApp/Assets.xcassets/AppIcon.appiconset")

// MARK: - Content

let dayText = "۱۱"
let monthText = "آبان"

// MARK: - Palette

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let turquoise   = rgb(0x22B8B0)
let turquoiseMd = rgb(0x1584A0)
let lapis       = rgb(0x173A8A)
let lapisDeep   = rgb(0x0E2259)
let ink         = rgb(0x132E6B)
let gold        = rgb(0xE9BE62)
let goldLight   = rgb(0xF8D57E)
let saffron     = rgb(0xE59A2C)
let paperTop    = rgb(0xFFFFFF)
let paperBot    = rgb(0xECF1F7)

// MARK: - Fonts

func font(files: [String], postScript: String, fallbacks: [String], size: CGFloat) -> CTFont {
    let dirs = [NSHomeDirectory() + "/Library/Fonts", "/Library/Fonts"]
    for f in files {
        for d in dirs {
            let url = URL(fileURLWithPath: d + "/" + f) as CFURL
            if let descs = CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor],
               let desc = descs.first {
                return CTFontCreateWithFontDescriptor(desc, size, nil)
            }
        }
    }
    for name in [postScript] + fallbacks {
        let f = CTFontCreateWithName(name as CFString, size, nil)
        if (CTFontCopyPostScriptName(f) as String) == name { return f }
    }
    return CTFontCreateWithName("GeezaPro-Bold" as CFString, size, nil)
}

func dayFont(_ s: CGFloat) -> CTFont {
    font(files: ["YekanBakhFaNum-ExtraBlack.ttf", "Vazirmatn-Black.ttf", "IRANYekanXFaNum-Black.ttf"],
         postScript: "YekanBakhFaNum-ExtraBlack", fallbacks: ["Vazirmatn-Black", "GeezaPro-Bold"], size: s)
}
func monthFont(_ s: CGFloat) -> CTFont {
    font(files: ["YekanBakhFaNum-Bold.ttf", "Vazirmatn-Bold.ttf", "IRANYekanXFaNum-Bold.ttf"],
         postScript: "YekanBakhFaNum-Bold", fallbacks: ["Vazirmatn-Bold", "GeezaPro-Bold"], size: s)
}

// MARK: - Geometry helpers (top-left coordinate space, 1024 units)

/// Continuous-corner body shape: a superellipse (|x|^n + |y|^n = 1), which is what the
/// Big Sur icon grid's "squircle" approximates. `radius` is kept for call-site readability
/// and picks the exponent (larger radius -> rounder).
func squircle(_ r: CGRect, radius: CGFloat) -> CGPath {
    let n: CGFloat = 5.0 * (185 / max(radius, 1)) * (min(r.width, r.height) / 824)
    let p = CGMutablePath()
    let a = r.width / 2, b = r.height / 2, cx = r.midX, cy = r.midY
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = cx + a * (c >= 0 ? 1 : -1) * pow(abs(c), 2 / n)
        let y = cy + b * (s >= 0 ? 1 : -1) * pow(abs(s), 2 / n)
        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
    }
    p.closeSubpath()
    return p
}

func linearGradient(_ ctx: CGContext, _ colors: [CGColor], _ locs: [CGFloat], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                       colors: colors as CFArray, locations: locs)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func radialGradient(_ ctx: CGContext, _ colors: [CGColor], center: CGPoint, radius: CGFloat) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                       colors: colors as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

/// Draws a single-line string centred on `center` using its glyph ink bounds
/// (optical centring, independent of ascender/descender metrics).
func drawText(_ ctx: CGContext, _ text: String, font: CTFont, color: CGColor, center: CGPoint, tracking: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        NSAttributedString.Key(kCTKernAttributeName as String): tracking,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    ctx.saveGState()
    ctx.textMatrix = .identity
    ctx.textPosition = .zero
    let ink = CTLineGetImageBounds(line, ctx) // in unflipped text space
    // We are in a flipped (top-left) space: flip locally so glyphs stand upright.
    ctx.translateBy(x: center.x, y: center.y)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = CGPoint(x: -ink.midX, y: -ink.midY)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

/// Shadows live in device space, so scale them with the output size.
var S: CGFloat = 1
func shadow(_ ctx: CGContext, _ dy: CGFloat, _ blur: CGFloat, _ color: CGColor) {
    ctx.setShadow(offset: CGSize(width: 0, height: dy * S), blur: blur * S, color: color)
}

// MARK: - Ornament (eslimi scroll)

/// One eslimi scroll unit for the top-left corner, in local coords where (0,0) is the
/// body's corner and the unit grows toward +x/+y.
func eslimiCorner() -> CGPath {
    let p = CGMutablePath()
    // Main sweeping stem from the top edge curling into a spiral.
    p.move(to: CGPoint(x: 250, y: 46))
    p.addCurve(to: CGPoint(x: 70, y: 130), control1: CGPoint(x: 170, y: 40), control2: CGPoint(x: 90, y: 70))
    p.addCurve(to: CGPoint(x: 120, y: 230), control1: CGPoint(x: 52, y: 185), control2: CGPoint(x: 80, y: 228))
    p.addCurve(to: CGPoint(x: 170, y: 170), control1: CGPoint(x: 160, y: 232), control2: CGPoint(x: 182, y: 200))
    p.addCurve(to: CGPoint(x: 128, y: 150), control1: CGPoint(x: 162, y: 150), control2: CGPoint(x: 140, y: 142))
    // Mirror stem from the left edge.
    p.move(to: CGPoint(x: 46, y: 250))
    p.addCurve(to: CGPoint(x: 70, y: 130), control1: CGPoint(x: 40, y: 200), control2: CGPoint(x: 48, y: 160))
    // Leaf (tear-drop) buds along the stems.
    func leaf(_ base: CGPoint, _ tip: CGPoint, _ w: CGFloat) {
        let dx = tip.x - base.x, dy = tip.y - base.y
        let len = hypot(dx, dy); let nx = -dy / len * w, ny = dx / len * w
        let mid = CGPoint(x: base.x + dx * 0.45, y: base.y + dy * 0.45)
        p.move(to: base)
        p.addQuadCurve(to: tip, control: CGPoint(x: mid.x + nx, y: mid.y + ny))
        p.addQuadCurve(to: base, control: CGPoint(x: mid.x - nx, y: mid.y - ny))
    }
    leaf(CGPoint(x: 205, y: 48), CGPoint(x: 262, y: 92), 22)
    leaf(CGPoint(x: 48, y: 205), CGPoint(x: 92, y: 262), 22)
    leaf(CGPoint(x: 110, y: 92), CGPoint(x: 150, y: 96), 12)
    leaf(CGPoint(x: 92, y: 110), CGPoint(x: 96, y: 150), 12)
    // Small dot (nokteh) at the spiral heart.
    p.addEllipse(in: CGRect(x: 136, y: 160, width: 14, height: 14))
    return p
}

// MARK: - Icon drawing (1024-unit, top-left space)

/// Flat, full-bleed icon: the artwork fills the whole 1024 canvas and macOS applies its own
/// rounded mask. No gradients, shadows or highlights — solid shapes only.
func drawIcon(_ ctx: CGContext, small: Bool, tiny: Bool = false) {
    let canvas = CGRect(x: 0, y: 0, width: 1024, height: 1024)

    // Solid Persian-turquoise background.
    ctx.setFillColor(rgb(0x1E8FA0)); ctx.fill(canvas)

    // Flat eslimi corners in a slightly darker tone (large sizes only).
    if false {
        let unit = eslimiCorner()
        ctx.setStrokeColor(rgb(0x167A8C)); ctx.setLineWidth(7)
        ctx.setLineCap(.round); ctx.setLineJoin(.round)
        let inset: CGFloat = 40
        for (i, corner) in [CGPoint(x: inset, y: inset), CGPoint(x: 1024 - inset, y: inset),
                            CGPoint(x: 1024 - inset, y: 1024 - inset), CGPoint(x: inset, y: 1024 - inset)].enumerated() {
            ctx.saveGState()
            ctx.translateBy(x: corner.x, y: corner.y)
            ctx.rotate(by: CGFloat(i) * .pi / 2)
            ctx.addPath(unit); ctx.strokePath()
            ctx.restoreGState()
        }
    }

    // ---- Calendar page (flat) ----
    let page = tiny ? CGRect(x: 120, y: 190, width: 784, height: 740)
             : small ? CGRect(x: 150, y: 200, width: 724, height: 700)
                     : CGRect(x: 172, y: 218, width: 680, height: 690)
    let pageR: CGFloat = small ? 90 : 72
    let pagePath = CGPath(roundedRect: page, cornerWidth: pageR, cornerHeight: pageR, transform: nil)
    let bandH: CGFloat = small ? 190 : 182

    ctx.addPath(pagePath); ctx.setFillColor(rgb(0xFFFFFF)); ctx.fillPath()

    // Flat saffron band.
    let band = CGRect(x: page.minX, y: page.minY, width: page.width, height: bandH)
    ctx.saveGState()
    ctx.addPath(pagePath); ctx.clip()
    ctx.setFillColor(rgb(0xF2B33D)); ctx.fill(band)
    ctx.restoreGState()

    // Flat sun mark.
    let sunC = CGPoint(x: page.midX, y: band.midY + (small ? 8 : 10))
    let sunR: CGFloat = small ? 44 : 34
    ctx.setFillColor(rgb(0xFFFFFF))
    let rays = small ? 8 : 12
    for i in 0..<rays {
        let ang = CGFloat(i) / CGFloat(rays) * 2 * .pi
        let inner = sunR * 1.32, outer = sunR * 1.85
        let w: CGFloat = small ? 0.20 : 0.13
        let tri = CGMutablePath()
        tri.move(to: CGPoint(x: sunC.x + cos(ang) * outer, y: sunC.y + sin(ang) * outer))
        tri.addLine(to: CGPoint(x: sunC.x + cos(ang + w) * inner, y: sunC.y + sin(ang + w) * inner))
        tri.addLine(to: CGPoint(x: sunC.x + cos(ang - w) * inner, y: sunC.y + sin(ang - w) * inner))
        tri.closeSubpath()
        ctx.addPath(tri)
    }
    ctx.fillPath()
    ctx.fillEllipse(in: CGRect(x: sunC.x - sunR, y: sunC.y - sunR, width: sunR * 2, height: sunR * 2))

    // Flat binder rings.
    let ringXs: [CGFloat] = small ? [page.minX + 170, page.maxX - 170] : [page.minX + 165, page.maxX - 165]
    let ringW: CGFloat = small ? 50 : 36, ringTop = page.minY - (small ? 52 : 46), ringBot = page.minY + (small ? 56 : 50)
    for x in ringXs {
        let ring = CGRect(x: x - ringW / 2, y: ringTop, width: ringW, height: ringBot - ringTop)
        ctx.addPath(CGPath(roundedRect: ring, cornerWidth: ringW / 2, cornerHeight: ringW / 2, transform: nil))
        ctx.setFillColor(rgb(0x132E6B)); ctx.fillPath()
    }

    // Day number + month.
    let contentTop = band.maxY
    if small {
        drawText(ctx, dayText, font: dayFont(tiny ? 500 : 440), color: rgb(0x132E6B),
                 center: CGPoint(x: page.midX, y: contentTop + (page.maxY - contentTop) / 2 + 4), tracking: tiny ? 40 : 0)
    } else {
        let area = page.maxY - contentTop
        drawText(ctx, dayText, font: dayFont(360), color: rgb(0x132E6B),
                 center: CGPoint(x: page.midX, y: contentTop + area * 0.42))
        drawText(ctx, monthText, font: monthFont(100), color: rgb(0x1E8FA0),
                 center: CGPoint(x: page.midX, y: contentTop + area * 0.83))
    }
}

// MARK: - Rendering

func render(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    let ctx = gc.cgContext
    ctx.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    ctx.setAllowsAntialiasing(true); ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    ctx.setShouldSmoothFonts(false)
    let s = CGFloat(pixels) / 1024
    S = s
    // Flip to a top-left origin and scale the 1024-unit design.
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: s, y: -s)
    drawIcon(ctx, small: pixels <= 32, tiny: pixels <= 16)
    ctx.flush()
    return rep.retagging(with: .sRGB) ?? rep
}

func write(_ rep: NSBitmapImageRep, to url: URL) {
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: url)
    print("wrote \(url.lastPathComponent) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
}

let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

let f = dayFont(10)
print("day font: \(CTFontCopyPostScriptName(f))  month font: \(CTFontCopyPostScriptName(monthFont(10)))")
for (name, px) in outputs {
    write(render(pixels: px), to: appIconSet.appendingPathComponent(name))
}
write(render(pixels: 1024), to: iconDir.appendingPathComponent("jdate-icon-1024.png"))
