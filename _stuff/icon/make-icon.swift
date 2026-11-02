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

// The date jDate v1.0 was first released: 2024-11-03 = 13 Aban 1403.
let dayText = "۱۳"
let monthText = "آبان ۱۴۰۳"

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

/// Modern full-bleed calendar icon: the whole icon IS the calendar page (no frame or padding).
/// macOS applies its own rounded mask. Turquoise header with the month, big day number below.
let variant = ProcessInfo.processInfo.environment["ICON_VARIANT"] ?? "A"
let previewOnly = ProcessInfo.processInfo.environment["ICON_PREVIEW"] == "1"

func drawIcon(_ ctx: CGContext, small: Bool, tiny: Bool = false) {
    switch variant {
    case "B": drawB(ctx, small: small, tiny: tiny)
    case "C": drawC(ctx, small: small, tiny: tiny)
    case "D": drawD(ctx, small: small, tiny: tiny)
    default: drawA(ctx, small: small, tiny: tiny)
    }
}

func fillRect(_ ctx: CGContext, _ r: CGRect, _ c: CGColor) { ctx.setFillColor(c); ctx.fill(r) }

/// B — "Night": deep indigo gradient, big glowing gradient ۱۱, thin crescent + month.
func drawB(_ ctx: CGContext, small: Bool, tiny: Bool) {
    let canvas = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    ctx.saveGState(); ctx.clip(to: canvas)
    linearGradient(ctx, [rgb(0x1B1F4B), rgb(0x2B1D63), rgb(0x0B0F2A)], [0, 0.55, 1], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 1024, y: 1024))
    radialGradient(ctx, [rgb(0x7C5CFF, 0.45), rgb(0x7C5CFF, 0)], center: CGPoint(x: 512, y: 560), radius: 520)
    ctx.restoreGState()
    // Day number filled with a warm gradient (draw text as clip).
    let font = dayFont(small ? 640 : 560)
    let center = CGPoint(x: 512, y: small ? 540 : 500)
    let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: dayText, attributes: attrs))
    ctx.saveGState()
    ctx.textMatrix = .identity
    let ink = CTLineGetImageBounds(line, ctx)
    ctx.translateBy(x: center.x, y: center.y); ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = CGPoint(x: -ink.midX, y: -ink.midY)
    ctx.setTextDrawingMode(.clip)
    CTLineDraw(line, ctx)
    ctx.scaleBy(x: 1, y: -1); ctx.translateBy(x: -center.x, y: -center.y)
    linearGradient(ctx, [rgb(0xFFE29A), rgb(0xFF9F5A), rgb(0xFF5E8A)], [0, 0.5, 1], from: CGPoint(x: 0, y: 260), to: CGPoint(x: 0, y: 760))
    ctx.restoreGState()
    if !small {
        // Crescent
        let c = CGPoint(x: 512, y: 150), r: CGFloat = 54
        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)); ctx.clip()
        ctx.addRect(CGRect(x: 0, y: 0, width: 1024, height: 400))
        ctx.addEllipse(in: CGRect(x: c.x - r + 34, y: c.y - r - 12, width: r * 2, height: r * 2))
        ctx.setFillColor(rgb(0xFFE29A)); ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()
        drawText(ctx, monthText, font: monthFont(120), color: rgb(0xFFFFFF, 0.85), center: CGPoint(x: 512, y: 880))
    }
}

/// C — "Shamseh": saffron→pomegranate gradient with a white sun-dial ring of 30 ticks around the day.
func drawC(_ ctx: CGContext, small: Bool, tiny: Bool) {
    let canvas = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    ctx.saveGState(); ctx.clip(to: canvas)
    linearGradient(ctx, [rgb(0xFFB547), rgb(0xF2643A), rgb(0xC2264B)], [0, 0.5, 1], from: CGPoint(x: 120, y: 0), to: CGPoint(x: 900, y: 1024))
    ctx.restoreGState()
    let c = CGPoint(x: 512, y: 512)
    if !small {
        // 30 day ticks; the first 11 (days passed) solid, the rest faint.
        for i in 0..<30 {
            let a = -CGFloat.pi / 2 + CGFloat(i) / 30 * 2 * .pi
            let r1: CGFloat = 330, r2: CGFloat = i % 5 == 0 ? 400 : 380
            ctx.setStrokeColor(rgb(0xFFFFFF, i < 11 ? 1 : 0.35))
            ctx.setLineWidth(i % 5 == 0 ? 18 : 12); ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
            ctx.addLine(to: CGPoint(x: c.x + cos(a) * r2, y: c.y + sin(a) * r2))
            ctx.strokePath()
        }
    } else {
        ctx.setStrokeColor(rgb(0xFFFFFF)); ctx.setLineWidth(60)
        ctx.addEllipse(in: CGRect(x: c.x - 400, y: c.y - 400, width: 800, height: 800)); ctx.strokePath()
    }
    drawText(ctx, dayText, font: dayFont(small ? 500 : 380), color: rgb(0xFFFFFF), center: CGPoint(x: 512, y: small ? 520 : 480), tracking: 10)
    if !small { drawText(ctx, monthText, font: monthFont(96), color: rgb(0xFFFFFF, 0.9), center: CGPoint(x: 512, y: 680)) }
}

/// D — "Split": diagonal two-tone turquoise / lapis, oversized white ۱۱ crossing the split, sun dot.
func drawD(_ ctx: CGContext, small: Bool, tiny: Bool) {
    fillRect(ctx, CGRect(x: 0, y: 0, width: 1024, height: 1024), rgb(0x1D3B8F))
    let tri = CGMutablePath()
    tri.move(to: .zero); tri.addLine(to: CGPoint(x: 1024, y: 0)); tri.addLine(to: CGPoint(x: 0, y: 1024)); tri.closeSubpath()
    ctx.addPath(tri); ctx.setFillColor(rgb(0x19B3B0)); ctx.fillPath()
    // Saffron sun in the top-right corner area.
    let sr: CGFloat = small ? 120 : 92
    ctx.setFillColor(rgb(0xFFC23D))
    ctx.fillEllipse(in: CGRect(x: 760 - sr, y: 250 - sr, width: sr * 2, height: sr * 2))
    drawText(ctx, dayText, font: dayFont(small ? 680 : 620), color: rgb(0xFFFFFF), center: CGPoint(x: small ? 470 : 450, y: small ? 560 : 560), tracking: 20)
    if !small { drawText(ctx, monthText, font: monthFont(104), color: rgb(0xFFFFFF), center: CGPoint(x: 760, y: 880)) }
}

/// A — "Calendar page": full-bleed page, turquoise→lapis header with the month, big lapis day.
/// The date is jDate's first release (13 Aban 1403).
func drawA(_ ctx: CGContext, small: Bool, tiny: Bool) {
    let canvas = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    let headerH: CGFloat = small ? 300 : 320
    let ruleH: CGFloat = small ? 36 : 26

    // Warm paper with a barely-there vertical shade.
    ctx.saveGState(); ctx.clip(to: canvas)
    linearGradient(ctx, [rgb(0xFFFFFF), rgb(0xF3F5F9)], [0, 1], from: CGPoint(x: 0, y: headerH), to: CGPoint(x: 0, y: 1024))
    ctx.restoreGState()

    // Header: Persian turquoise → deep lapis.
    let header = CGRect(x: 0, y: 0, width: 1024, height: headerH)
    ctx.saveGState(); ctx.clip(to: header)
    linearGradient(ctx, [rgb(0x18C6B8), rgb(0x0E8FB0), rgb(0x1F4FA8)], [0, 0.55, 1], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 1024, y: headerH))
    ctx.restoreGState()
    // Saffron rule.
    ctx.saveGState(); ctx.clip(to: CGRect(x: 0, y: headerH, width: 1024, height: ruleH))
    linearGradient(ctx, [rgb(0xFFC94A), rgb(0xFF9F2E)], [0, 1], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 1024, y: 0))
    ctx.restoreGState()

    let ink = rgb(0x1A2F7A)
    if small {
        drawText(ctx, dayText, font: dayFont(tiny ? 620 : 580), color: ink,
                 center: CGPoint(x: 512, y: headerH + ruleH + (1024 - headerH - ruleH) / 2 + 10), tracking: tiny ? 50 : 20)
    } else {
        drawText(ctx, monthText, font: monthFont(150), color: rgb(0xFFFFFF),
                 center: CGPoint(x: 512, y: headerH * 0.56))
        drawText(ctx, dayText, font: dayFont(520), color: ink,
                 center: CGPoint(x: 512, y: headerH + ruleH + (1024 - headerH - ruleH) * 0.47), tracking: 20)
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
if previewOnly {
    let dir = iconDir.appendingPathComponent("options")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    write(render(pixels: 1024), to: dir.appendingPathComponent("option-\(variant).png"))
    write(render(pixels: 32), to: dir.appendingPathComponent("option-\(variant)-32.png"))
} else {
    for (name, px) in outputs {
        write(render(pixels: px), to: appIconSet.appendingPathComponent(name))
    }
    write(render(pixels: 1024), to: iconDir.appendingPathComponent("jdate-icon-1024.png"))
}
