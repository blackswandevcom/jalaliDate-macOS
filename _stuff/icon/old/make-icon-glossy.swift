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

func drawIcon(_ ctx: CGContext, small: Bool, tiny: Bool = false) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = squircle(body, radius: 185)

    // Drop shadow under the body.
    ctx.saveGState()
    shadow(ctx, -12, 28, rgb(0x000000, 0.32))
    ctx.addPath(bodyPath); ctx.setFillColor(lapis); ctx.fillPath()
    ctx.restoreGState()

    // Background gradient: Persian turquoise (top-left) -> deep lapis (bottom-right).
    ctx.saveGState()
    ctx.addPath(bodyPath); ctx.clip()
    linearGradient(ctx, [turquoise, turquoiseMd, lapis, lapisDeep], [0, 0.35, 0.72, 1],
                   from: CGPoint(x: 150, y: 110), to: CGPoint(x: 880, y: 930))
    // Soft top glow for depth.
    radialGradient(ctx, [rgb(0xFFFFFF, 0.20), rgb(0xFFFFFF, 0)], center: CGPoint(x: 380, y: 140), radius: 560)

    if !small {
        // Gold eslimi ornaments in the four corners + a hairline inner frame.
        let unit = eslimiCorner()
        ctx.setStrokeColor(rgb(0xF1C76B, 0.30))
        ctx.setLineWidth(5); ctx.setLineCap(.round); ctx.setLineJoin(.round)
        for (i, corner) in [CGPoint(x: body.minX, y: body.minY), CGPoint(x: body.maxX, y: body.minY),
                            CGPoint(x: body.maxX, y: body.maxY), CGPoint(x: body.minX, y: body.maxY)].enumerated() {
            ctx.saveGState()
            ctx.translateBy(x: corner.x, y: corner.y)
            ctx.rotate(by: CGFloat(i) * .pi / 2)
            ctx.addPath(unit); ctx.strokePath()
            ctx.restoreGState()
        }
        ctx.setStrokeColor(rgb(0xF1C76B, 0.20)); ctx.setLineWidth(3)
        ctx.addPath(squircle(body.insetBy(dx: 26, dy: 26), radius: 160)); ctx.strokePath()
    }
    ctx.restoreGState()

    // Inner rim highlight on the body.
    ctx.saveGState()
    ctx.addPath(bodyPath); ctx.clip()
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.18)); ctx.setLineWidth(4)
    ctx.addPath(squircle(body.insetBy(dx: 2, dy: 2), radius: 183)); ctx.strokePath()
    ctx.restoreGState()

    // ---- Calendar page ----
    let page = tiny ? CGRect(x: 190, y: 220, width: 644, height: 640)
             : small ? CGRect(x: 214, y: 236, width: 596, height: 600)
                     : CGRect(x: 240, y: 262, width: 544, height: 572)
    let pageR: CGFloat = small ? 76 : 60
    let pagePath = CGPath(roundedRect: page, cornerWidth: pageR, cornerHeight: pageR, transform: nil)
    let bandH: CGFloat = small ? 170 : 150

    // Stacked sheets behind (tear-off pad).
    if !small {
        for (i, a) in [(2, 0.55), (1, 0.80)] as [(Int, CGFloat)] {
            let off = CGFloat(i) * 14
            let r = page.offsetBy(dx: 0, dy: off).insetBy(dx: CGFloat(i) * 12, dy: 0)
            ctx.saveGState()
            shadow(ctx, -6, 14, rgb(0x061536, 0.30))
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: pageR, cornerHeight: pageR, transform: nil))
            ctx.setFillColor(rgb(0xDCE4EE, a)); ctx.fillPath()
            ctx.restoreGState()
        }
    }

    // Page shadow + paper fill.
    ctx.saveGState()
    shadow(ctx, -18, 36, rgb(0x061536, 0.45))
    ctx.addPath(pagePath); ctx.setFillColor(paperTop); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(pagePath); ctx.clip()
    linearGradient(ctx, [paperTop, paperBot], [0, 1],
                   from: CGPoint(x: 0, y: page.minY + bandH), to: CGPoint(x: 0, y: page.maxY))
    // Gold / saffron band.
    let band = CGRect(x: page.minX, y: page.minY, width: page.width, height: bandH)
    ctx.saveGState()
    ctx.clip(to: band)
    linearGradient(ctx, [goldLight, gold, saffron], [0, 0.45, 1],
                   from: CGPoint(x: 0, y: band.minY), to: CGPoint(x: 0, y: band.maxY))
    // Gentle sheen on the band.
    ctx.setFillColor(rgb(0xFFFFFF, 0.16))
    ctx.fill(CGRect(x: band.minX, y: band.minY, width: band.width, height: bandH * 0.42))
    ctx.restoreGState()
    // Band bottom edge shade.
    ctx.setFillColor(rgb(0x9A5A10, 0.22))
    ctx.fill(CGRect(x: page.minX, y: band.maxY - 4, width: page.width, height: 4))
    ctx.restoreGState()

    // Sun mark (shamseh) on the band.
    let sunC = CGPoint(x: page.midX, y: band.midY + (small ? 6 : 8))
    let sunR: CGFloat = small ? 40 : 30
    ctx.saveGState()
    ctx.setFillColor(rgb(0xFFFBEF, 0.96))
    let rays = small ? 8 : 12
    for i in 0..<rays {
        let a = CGFloat(i) / CGFloat(rays) * 2 * .pi
        let inner = sunR * 1.30, outer = sunR * (small ? 1.85 : 1.80)
        let w: CGFloat = small ? 0.20 : 0.13
        let tri = CGMutablePath()
        tri.move(to: CGPoint(x: sunC.x + cos(a) * outer, y: sunC.y + sin(a) * outer))
        tri.addLine(to: CGPoint(x: sunC.x + cos(a + w) * inner, y: sunC.y + sin(a + w) * inner))
        tri.addLine(to: CGPoint(x: sunC.x + cos(a - w) * inner, y: sunC.y + sin(a - w) * inner))
        tri.closeSubpath()
        ctx.addPath(tri)
    }
    ctx.fillPath()
    ctx.fillEllipse(in: CGRect(x: sunC.x - sunR, y: sunC.y - sunR, width: sunR * 2, height: sunR * 2))
    if !small {
        ctx.setFillColor(rgb(0xF0B848, 1))
        let r2 = sunR * 0.45
        ctx.fillEllipse(in: CGRect(x: sunC.x - r2, y: sunC.y - r2, width: r2 * 2, height: r2 * 2))
    }
    ctx.restoreGState()

    // Binder rings.
    let ringXs: [CGFloat] = small ? [page.minX + 150, page.maxX - 150] : [page.minX + 128, page.maxX - 128]
    let ringW: CGFloat = small ? 44 : 30, ringTop = page.minY - (small ? 44 : 38), ringBot = page.minY + (small ? 50 : 44)
    for x in ringXs {
        // Punched hole.
        ctx.setFillColor(rgb(0x7A4A12, 0.55))
        let hr: CGFloat = small ? 20 : 15
        ctx.fillEllipse(in: CGRect(x: x - hr, y: ringBot - hr - 4, width: hr * 2, height: hr * 2))
        // Ring body.
        let ring = CGRect(x: x - ringW / 2, y: ringTop, width: ringW, height: ringBot - ringTop)
        let rp = CGPath(roundedRect: ring, cornerWidth: ringW / 2, cornerHeight: ringW / 2, transform: nil)
        ctx.saveGState()
        shadow(ctx, -4, 6, rgb(0x000000, 0.35))
        ctx.addPath(rp); ctx.setFillColor(rgb(0x1B2F5E)); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(rp); ctx.clip()
        linearGradient(ctx, [rgb(0x5D79B8), rgb(0x22397A), rgb(0x0F1E48)], [0, 0.5, 1],
                       from: CGPoint(x: ring.minX, y: 0), to: CGPoint(x: ring.maxX, y: 0))
        ctx.restoreGState()
    }

    // Perforation dots under the band (tear-off cue).
    if !small {
        ctx.setFillColor(rgb(0x173A8A, 0.16))
        var x = page.minX + 34
        while x < page.maxX - 30 {
            ctx.fillEllipse(in: CGRect(x: x - 3.5, y: band.maxY + 16, width: 7, height: 7))
            x += 22
        }
    }

    // Day number + month.
    let contentTop = band.maxY
    if small {
        drawText(ctx, dayText, font: dayFont(tiny ? 470 : 400), color: ink,
                 center: CGPoint(x: page.midX, y: contentTop + (page.maxY - contentTop) / 2 + 4), tracking: tiny ? 40 : 0)
    } else {
        let area = page.maxY - contentTop
        drawText(ctx, dayText, font: dayFont(300), color: ink,
                 center: CGPoint(x: page.midX, y: contentTop + area * 0.41))
        drawText(ctx, monthText, font: monthFont(82), color: rgb(0x1584A0),
                 center: CGPoint(x: page.midX, y: contentTop + area * 0.82))
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
