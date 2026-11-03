import AVFoundation
import SwiftUI

/// Animated or media background behind the header.
struct HeaderEffectView: View {
    let effect: HeaderEffect
    let paused: Bool

    var body: some View {
        switch effect {
        case let .animated(style, colors, speed, intensity):
            AnimatedBackground(style: style, colors: colors.isEmpty ? [.orange] : colors,
                               speed: speed, intensity: intensity, paused: paused)
        case let .media(url, kind, dim):
            ZStack {
                if kind == .video {
                    LoopingVideo(url: url, paused: paused)
                } else if let image = MediaCache.image(url) {
                    Image(nsImage: image).resizable().scaledToFill()
                }
                Color.black.opacity(dim)
            }
        }
    }
}

enum MediaCache {
    private static var images: [URL: NSImage] = [:]
    static func image(_ url: URL) -> NSImage? {
        if let i = images[url] { return i }
        let i = NSImage(contentsOf: url)
        images[url] = i
        return i
    }
    static func clear() { images.removeAll() }
}

// MARK: - Animated styles

struct AnimatedBackground: View {
    let style: AnimatedStyle
    let colors: [Color]
    let speed: Double
    let intensity: Double
    let paused: Bool

    private func c(_ i: Int) -> Color { colors[i % colors.count] }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: paused)) { context in
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000) * speed
            if style == .liquid {
                liquid(t)
            } else {
                Canvas { g, size in draw(&g, size, t) }
            }
        }
        .allowsHitTesting(false)
    }

    // A 3×3 mesh whose inner points drift.
    private func liquid(_ t: Double) -> some View {
        let a = Float(0.08 + 0.2 * intensity)
        func s(_ x: Double) -> Float { Float(sin(x)) }
        return MeshGradient(width: 3, height: 3, points: [
            [0, 0], [0.5 + a * s(t * 0.7), 0], [1, 0],
            [0, 0.5 + a * s(t * 0.9 + 1)], [0.5 + a * s(t * 0.8 + 2), 0.5 + a * s(t * 0.6 + 3)], [1, 0.5 + a * s(t * 0.75 + 4)],
            [0, 1], [0.5 + a * s(t * 0.65 + 5), 1], [1, 1],
        ], colors: [c(0), c(1), c(2), c(1), c(2), c(0), c(2), c(0), c(1)])
    }

    private func draw(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height
        let rect = CGRect(origin: .zero, size: size)
        let vertical = GraphicsContext.Shading.linearGradient(Gradient(colors: [c(0), c(1)]), startPoint: .zero, endPoint: CGPoint(x: w, y: h))

        switch style {
        case .aurora:
            g.fill(Path(rect), with: .color(c(0)))
            g.drawLayer { l in
                l.addFilter(.blur(radius: h * 0.28))
                for i in 0..<5 {
                    let x = w * (0.5 + 0.48 * sin(t * 0.21 + Double(i) * 1.7))
                    let y = h * (0.5 + 0.35 * cos(t * 0.17 + Double(i) * 2.3))
                    let r = CGRect(x: x - w * 0.28, y: y - h * 0.55, width: w * 0.56, height: h * 1.1)
                    l.fill(Path(ellipseIn: r), with: .color(c(1 + i % 2).opacity(0.35 + 0.5 * intensity)))
                }
            }

        case .waves:
            g.fill(Path(rect), with: vertical)
            for k in 0..<4 {
                let base = h * (0.38 + 0.17 * Double(k))
                let amp = h * 0.07 * (0.5 + intensity)
                let freq = 1.4 + Double(k) * 0.35
                var p = Path()
                p.move(to: CGPoint(x: 0, y: h))
                for step in 0...60 {
                    let x = w * Double(step) / 60
                    let y = base + amp * sin(x / w * .pi * 2 * freq + t * (0.8 + Double(k) * 0.25) + Double(k))
                    p.addLine(to: CGPoint(x: x, y: y))
                }
                p.addLine(to: CGPoint(x: w, y: h))
                p.closeSubpath()
                g.fill(p, with: .color(c(2).opacity(0.10 + 0.07 * Double(k))))
            }

        case .lava:
            g.fill(Path(rect), with: vertical)
            for (layer, color) in [(0, c(2)), (1, c(1))] {
                g.drawLayer { l in
                    l.addFilter(.alphaThreshold(min: 0.5, color: color.opacity(0.85)))
                    l.addFilter(.blur(radius: h * 0.09))
                    l.drawLayer { inner in
                        let count = 5 + Int(intensity * 4)
                        for i in 0..<count {
                            let seedX = Self.seed(i, 11 + layer), seedR = Self.seed(i, 23 + layer)
                            let r = h * (0.16 + 0.16 * seedR) * (layer == 0 ? 1 : 0.7)
                            let x = w * seedX + sin(t * 0.3 + Double(i)) * w * 0.06
                            let y = h * (0.5 + 0.55 * sin(t * (0.18 + 0.1 * seedR) + Double(i) * 1.9 + Double(layer)))
                            inner.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.black))
                        }
                    }
                }
            }

        case .starfield:
            g.fill(Path(rect), with: .color(c(0)))
            g.fill(Path(rect), with: .radialGradient(Gradient(colors: [c(1), c(0).opacity(0)]),
                                                    center: CGPoint(x: w / 2, y: h / 2), startRadius: 0, endRadius: w * 0.55))
            let center = CGPoint(x: w / 2, y: h / 2)
            let maxR = hypot(w, h) / 2
            let count = 60 + Int(intensity * 140)
            for i in 0..<count {
                let angle = Self.seed(i, 3) * .pi * 2
                let z = (Self.seed(i, 5) + t * 0.12).truncatingRemainder(dividingBy: 1)
                let r = pow(z, 2.2) * maxR
                let r0 = pow(max(z - 0.03, 0), 2.2) * maxR
                var p = Path()
                p.move(to: CGPoint(x: center.x + cos(angle) * r0, y: center.y + sin(angle) * r0))
                p.addLine(to: CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r))
                g.stroke(p, with: .color(c(2).opacity(min(1, z * 1.4))), style: StrokeStyle(lineWidth: 0.6 + z * 2.2, lineCap: .round))
            }

        case .girih:
            g.fill(Path(rect), with: vertical)
            let s = h * 0.62
            let shift = (t * 6).truncatingRemainder(dividingBy: s)
            var l = g
            l.translateBy(x: w / 2, y: h / 2)
            l.rotate(by: .radians(t * 0.04))
            let line = c(2).opacity(0.18 + 0.4 * intensity)
            let span = Int(ceil(hypot(w, h) / s)) + 1
            for gx in -span...span {
                for gy in -span...span {
                    let cx = Double(gx) * s + shift, cy = Double(gy) * s
                    let pulse = 1 + 0.06 * sin(t * 0.8 + Double(gx + gy))
                    l.stroke(Self.star(center: CGPoint(x: cx, y: cy), radius: s * 0.42 * pulse), with: .color(line), lineWidth: 1.2)
                    l.stroke(Self.polygon(center: CGPoint(x: cx + s / 2, y: cy + s / 2), radius: s * 0.16, sides: 8, rotation: .pi / 8),
                             with: .color(line.opacity(0.7)), lineWidth: 1)
                }
            }

        case .rings:
            g.fill(Path(rect), with: vertical)
            for (cx, cy, phase) in [(0.22, 0.4, 0.0), (0.8, 0.75, 0.5)] {
                for k in 0..<5 {
                    let f = (t * 0.18 + Double(k) / 5 + phase).truncatingRemainder(dividingBy: 1)
                    let r = f * w * 0.7
                    let circle = Path(ellipseIn: CGRect(x: w * cx - r, y: h * cy - r, width: r * 2, height: r * 2))
                    g.stroke(circle, with: .color(c(2).opacity((1 - f) * (0.25 + 0.5 * intensity))), lineWidth: 2)
                }
            }

        case .fireworks:
            g.fill(Path(rect), with: .linearGradient(Gradient(colors: [c(0), c(0).opacity(0.85)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            let bursts = 3 + Int(intensity * 3)
            for b in 0..<bursts {
                let period = 2.6 + Self.seed(b, 41)
                let local = t + Double(b) * period / Double(bursts)
                let cycle = floor(local / period)
                let p = (local / period) - cycle
                let k = Int(cycle) * 13 + b
                let cx = w * (0.1 + 0.8 * Self.seed(k, 7)), cy = h * (0.2 + 0.45 * Self.seed(k, 9))
                let color = [c(1), c(2), Color.white][k % 3]
                if p < 0.18 {
                    // rocket trail rising
                    let q = p / 0.18
                    var trail = Path()
                    trail.move(to: CGPoint(x: cx, y: h))
                    trail.addLine(to: CGPoint(x: cx, y: h - (h - cy) * q))
                    g.stroke(trail, with: .color(color.opacity(0.5 * q)), lineWidth: 1.2)
                    continue
                }
                let q = (p - 0.18) / 0.82
                let r = h * 0.55 * (1 - pow(1 - q, 3))
                let count = 18
                for i in 0..<count {
                    let a = Double(i) / Double(count) * .pi * 2 + Self.seed(k, 3)
                    let x = cx + cos(a) * r, y = cy + sin(a) * r + q * q * h * 0.18
                    let x0 = cx + cos(a) * r * 0.82, y0 = cy + sin(a) * r * 0.82 + q * q * h * 0.16
                    var spark = Path()
                    spark.move(to: CGPoint(x: x0, y: y0))
                    spark.addLine(to: CGPoint(x: x, y: y))
                    g.stroke(spark, with: .color(color.opacity(max(0, 1 - q * q))), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
                g.fill(Path(ellipseIn: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6)), with: .color(.white.opacity(max(0, 0.8 - q * 2))))
            }

        case .lanterns:
            g.fill(Path(rect), with: vertical)
            for i in 0..<(25 + Int(intensity * 25)) {
                let x = w * Self.seed(i, 51), y = h * Self.seed(i, 53)
                let tw = 0.3 + 0.7 * abs(sin(t * (0.6 + Self.seed(i, 55)) + Double(i)))
                g.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(.white.opacity(0.7 * tw)))
            }
            // Crescent
            let mr = h * 0.22, mc = CGPoint(x: w * 0.47, y: h * 0.3)
            let moon = Path(ellipseIn: CGRect(x: mc.x - mr, y: mc.y - mr, width: mr * 2, height: mr * 2))
                .subtracting(Path(ellipseIn: CGRect(x: mc.x - mr * 0.55, y: mc.y - mr * 1.12, width: mr * 2, height: mr * 2)))
            g.drawLayer { l in
                l.addFilter(.shadow(color: c(2).opacity(0.8), radius: 10))
                l.fill(moon, with: .color(c(2)))
            }
            // Hanging lanterns
            for (i, fx) in [0.04, 0.4, 0.56].enumerated() {
                let len = h * (0.12 + 0.14 * Double(i % 2))
                let swing = sin(t * 0.9 + Double(i) * 1.3) * 0.12 * (0.5 + intensity)
                var l = g
                l.translateBy(x: w * fx, y: 0)
                l.rotate(by: .radians(swing))
                var string = Path(); string.move(to: .zero); string.addLine(to: CGPoint(x: 0, y: len))
                l.stroke(string, with: .color(c(2).opacity(0.6)), lineWidth: 0.8)
                let lw = h * 0.16, lh = h * 0.26
                let body = CGRect(x: -lw / 2, y: len + lh * 0.18, width: lw, height: lh * 0.7)
                let flicker = 0.75 + 0.25 * sin(t * 7 + Double(i) * 2)
                l.fill(Path(ellipseIn: body.insetBy(dx: -lw * 0.9, dy: -lh * 0.6)),
                       with: .radialGradient(Gradient(colors: [c(2).opacity(0.45 * flicker), .clear]),
                                             center: CGPoint(x: body.midX, y: body.midY), startRadius: 0, endRadius: lw * 1.4))
                var cap = Path()
                cap.move(to: CGPoint(x: -lw * 0.35, y: len + lh * 0.18))
                cap.addLine(to: CGPoint(x: 0, y: len))
                cap.addLine(to: CGPoint(x: lw * 0.35, y: len + lh * 0.18))
                cap.closeSubpath()
                l.fill(cap, with: .color(c(2)))
                l.fill(Path(roundedRect: body, cornerRadius: lw * 0.3), with: .color(c(2).opacity(0.85 * flicker)))
                l.stroke(Path(roundedRect: body, cornerRadius: lw * 0.3), with: .color(c(1)), lineWidth: 1)
                var ribs = Path()
                ribs.move(to: CGPoint(x: 0, y: body.minY)); ribs.addLine(to: CGPoint(x: 0, y: body.maxY))
                l.stroke(ribs, with: .color(c(1).opacity(0.6)), lineWidth: 0.8)
            }

        case .snowfall:
            g.fill(Path(rect), with: vertical)
            g.drawLayer { l in
                l.addFilter(.blur(radius: 4))
                for i in 0..<14 {
                    let x = w * Self.seed(i, 61), y = h * (0.15 + 0.7 * Self.seed(i, 63))
                    let on = 0.35 + 0.65 * abs(sin(t * (0.8 + Self.seed(i, 65)) + Double(i)))
                    let r = h * (0.05 + 0.05 * Self.seed(i, 67))
                    l.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                           with: .color((i % 2 == 0 ? c(1) : c(2)).opacity(0.75 * on)))
                }
            }
            for i in 0..<(40 + Int(intensity * 60)) {
                let sp = 0.06 + 0.08 * Self.seed(i, 71)
                let y = ((Self.seed(i, 73) + t * sp).truncatingRemainder(dividingBy: 1)) * (h + 10) - 5
                let x = w * Self.seed(i, 75) + sin(t * 0.8 + Double(i)) * 8
                let r = 0.8 + 1.8 * Self.seed(i, 77)
                g.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.85)))
            }

        case .blossoms:
            g.fill(Path(rect), with: .linearGradient(Gradient(colors: [c(0), c(1).opacity(0.9)]), startPoint: CGPoint(x: 0, y: h), endPoint: CGPoint(x: w, y: 0)))
            g.fill(Path(ellipseIn: CGRect(x: w * 0.7, y: -h * 0.5, width: h * 1.3, height: h * 1.3)),
                   with: .radialGradient(Gradient(colors: [c(2).opacity(0.9), c(2).opacity(0)]),
                                         center: CGPoint(x: w * 0.7 + h * 0.65, y: h * 0.15), startRadius: 0, endRadius: h * 0.65))
            for i in 0..<(18 + Int(intensity * 26)) {
                let sp = 0.05 + 0.06 * Self.seed(i, 81)
                let y = ((Self.seed(i, 83) + t * sp).truncatingRemainder(dividingBy: 1)) * (h + 16) - 8
                let x = w * Self.seed(i, 85) + sin(t * 0.7 + Double(i) * 1.7) * 14 - y * 0.15
                let size = 4 + 5 * Self.seed(i, 87)
                var l = g
                l.translateBy(x: x, y: y)
                l.rotate(by: .radians(t * (0.6 + Self.seed(i, 89)) + Double(i)))
                l.scaleBy(x: 1, y: 0.55 + 0.45 * abs(sin(t + Double(i))))
                let petal = Path(ellipseIn: CGRect(x: -size / 2, y: -size / 4, width: size, height: size / 2))
                l.fill(petal, with: .color((i % 3 == 0 ? c(2) : Color(white: 1, opacity: 1).mix(with: c(1), by: 0.35)).opacity(0.9)))
            }

        case .embers:
            g.fill(Path(rect), with: .color(c(0)))
            g.fill(Path(rect), with: .radialGradient(Gradient(colors: [c(1).opacity(0.75), c(1).opacity(0)]),
                                                    center: CGPoint(x: w * 0.5, y: h * 1.15), startRadius: 0, endRadius: w * 0.55))
            for i in 0..<(35 + Int(intensity * 55)) {
                let sp = 0.12 + 0.18 * Self.seed(i, 91)
                let p = (Self.seed(i, 93) + t * sp).truncatingRemainder(dividingBy: 1)
                let y = h * (1.05 - p * 1.1)
                let spread = (Self.seed(i, 95) - 0.5) * w * (0.4 + 0.6 * p)
                let x = w * 0.5 + spread + sin(t * 2 + Double(i)) * 6 * p
                let r = (1 - p) * (1.2 + 1.6 * Self.seed(i, 97))
                let flick = 0.6 + 0.4 * sin(t * 9 + Double(i) * 3)
                g.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                       with: .color((i % 3 == 0 ? c(2) : c(1)).opacity((1 - p) * flick)))
            }

        case .hearts:
            g.fill(Path(rect), with: vertical)
            for i in 0..<(10 + Int(intensity * 14)) {
                let sp = 0.05 + 0.07 * Self.seed(i, 101)
                let p = (Self.seed(i, 103) + t * sp).truncatingRemainder(dividingBy: 1)
                let size = h * (0.08 + 0.12 * Self.seed(i, 105))
                let x = w * Self.seed(i, 107) + sin(t * 1.1 + Double(i)) * 10
                let y = h * (1.1 - p * 1.25)
                var l = g
                l.translateBy(x: x, y: y)
                l.rotate(by: .radians(sin(t + Double(i)) * 0.25))
                l.fill(Self.heart(size), with: .color((i % 3 == 0 ? c(2) : c(1)).opacity(0.85 * sin(p * .pi))))
            }

        case .liquid:
            break
        }
    }

    private static func heart(_ s: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: s * 0.35))
        p.addCurve(to: CGPoint(x: -s / 2, y: -s * 0.1), control1: CGPoint(x: -s * 0.1, y: s * 0.25), control2: CGPoint(x: -s / 2, y: s * 0.15))
        p.addArc(center: CGPoint(x: -s / 4, y: -s * 0.1), radius: s / 4, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: s / 4, y: -s * 0.1), radius: s / 4, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: 0, y: s * 0.35), control1: CGPoint(x: s / 2, y: s * 0.15), control2: CGPoint(x: s * 0.1, y: s * 0.25))
        p.closeSubpath()
        return p
    }

    /// Eight-point star: two squares turned 45° to each other.
    private static func star(center: CGPoint, radius: Double) -> Path {
        var p = Path()
        for i in 0..<16 {
            let a = Double(i) / 16 * .pi * 2
            let r = i.isMultiple(of: 2) ? radius : radius * 0.62
            let pt = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }

    private static func polygon(center: CGPoint, radius: Double, sides: Int, rotation: Double) -> Path {
        var p = Path()
        for i in 0..<sides {
            let a = Double(i) / Double(sides) * .pi * 2 + rotation
            let pt = CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }

    static func seed(_ i: Int, _ salt: Int) -> Double {
        let v = sin(Double(i * 7919 + salt * 104729)) * 43758.5453
        return v - floor(v)
    }
}

// MARK: - Looping muted video

struct LoopingVideo: NSViewRepresentable {
    let url: URL
    let paused: Bool

    func makeNSView(context: Context) -> PlayerView { PlayerView() }

    func updateNSView(_ view: PlayerView, context: Context) {
        view.load(url)
        paused ? view.player.pause() : view.player.play()
    }

    final class PlayerView: NSView {
        let player = AVQueuePlayer()
        private let playerLayer = AVPlayerLayer()
        private var looper: AVPlayerLooper?
        private var current: URL?

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            player.isMuted = true
            player.preventsDisplaySleepDuringVideoPlayback = false
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
            layer?.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layout() {
            super.layout()
            playerLayer.frame = bounds
        }

        func load(_ url: URL) {
            guard url != current else { return }
            current = url
            player.removeAllItems()
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        }
    }
}
