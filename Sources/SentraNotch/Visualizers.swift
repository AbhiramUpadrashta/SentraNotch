//
//  Visualizers.swift — Sentra Notch
//  Music animations (spectrum bars, waves, pulse, dancers) and the charging animation.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import SwiftUI

/// Smooth pseudo-random motion: a few sines at unrelated speeds, so bars never move in lockstep.
private func noise(_ t: Double, _ seed: Double) -> Double {
    let v = sin(t * 2.3 + seed * 1.7) * 0.5 + sin(t * 3.7 + seed * 4.1) * 0.3 + sin(t * 6.1 + seed * 2.9) * 0.2
    return (v + 1) / 2   // 0…1
}

struct MusicWaves: View {
    var playing: Bool
    var color: Color
    var bars: Int = 4
    @AppStorage(Prefs.waveStyle) private var style = "bars"
    @AppStorage(Prefs.colorfulWaves) private var colorful = true
    @AppStorage(Prefs.dancer) private var dancer = "both"

    var body: some View {
        let tint = colorful ? color : .white
        if style == "dance" {
            Dancers(playing: playing, color: tint, who: dancer)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 60, paused: !playing)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in draw(ctx: ctx, size: size, t: t, tint: tint) }
            }
            .opacity(style == "off" ? 0 : 1)
        }
    }

    private func draw(ctx: GraphicsContext, size: CGSize, t: Double, tint: Color) {
        let shading = GraphicsContext.Shading.linearGradient(Gradient(colors: [tint.opacity(0.7), tint, tint.opacity(0.9)]),
                                                             startPoint: CGPoint(x: 0, y: size.height), endPoint: CGPoint(x: 0, y: 0))
        // a soft "kick" on every beat (~120 bpm) so the motion feels like music, not random noise
        let kick = playing ? pow(max(0, cos(t * .pi * 2)), 10) : 0
        switch style {
        case "waves":
            // Siri-like ribbons: mirrored waves, filled softly, with a glowing edge
            let mid = size.height / 2
            for layer in (0..<3).reversed() {
                let L = Double(layer)
                let energy = playing ? (0.95 - L * 0.22) * (0.5 + 0.35 * noise(t * 0.7, L * 2.3) + 0.25 * kick) : 0.05
                let amp = mid * min(1, energy)
                var up = Path(), down = Path()
                for x in stride(from: 0, through: size.width, by: 1) {
                    let r = x / size.width
                    let env = pow(sin(r * .pi), 1.6)
                    let y = amp * env * sin(r * .pi * (2 + L * 0.9) - t * (5 + L * 1.7) + L * 1.3)
                    let pU = CGPoint(x: x, y: mid - y), pD = CGPoint(x: x, y: mid + y)
                    if x == 0 { up.move(to: pU); down.move(to: pD) } else { up.addLine(to: pU); down.addLine(to: pD) }
                }
                var ribbon = up
                ribbon.addPath(Path { p in
                    for x in stride(from: size.width, through: 0, by: -1) {
                        let r = x / size.width, env = pow(sin(r * .pi), 1.6)
                        let y = amp * env * sin(r * .pi * (2 + L * 0.9) - t * (5 + L * 1.7) + L * 1.3)
                        if x == size.width { p.move(to: CGPoint(x: x, y: mid + y)) } else { p.addLine(to: CGPoint(x: x, y: mid + y)) }
                    }
                })
                ctx.fill(ribbon, with: .color(tint.opacity(0.14 + 0.06 * (2 - L))))
                let w = 1.8 - CGFloat(layer) * 0.45
                if layer == 0 {
                    ctx.drawLayer { g in
                        g.addFilter(.blur(radius: 2.5))
                        g.stroke(up, with: .color(tint), lineWidth: w + 2); g.stroke(down, with: .color(tint), lineWidth: w + 2)
                    }
                }
                let c = tint.opacity(1 - L * 0.3)
                ctx.stroke(up, with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: .round))
                ctx.stroke(down, with: .color(c.opacity(0.7)), style: StrokeStyle(lineWidth: w * 0.8, lineCap: .round))
            }
        case "pulse":
            let v = playing ? 0.55 + 0.45 * noise(t * 1.4, 1) : 0.4
            let r = min(size.width, size.height) / 2 * v
            ctx.fill(Path(ellipseIn: CGRect(x: size.width / 2 - r, y: size.height / 2 - r, width: r * 2, height: r * 2)), with: shading)
            for k in 0..<2 {
                let ph = (t * 0.9 + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)
                let rr = r * (1 + ph * 1.2)
                ctx.stroke(Path(ellipseIn: CGRect(x: size.width / 2 - rr, y: size.height / 2 - rr, width: rr * 2, height: rr * 2)),
                           with: .color(tint.opacity(playing ? 0.5 * (1 - ph) : 0)), lineWidth: 1)
            }
        default: // spectrum bars, mirrored around the middle, with a glow and a bright tip
            let n = max(3, bars)
            let gap = size.width * 0.14 / CGFloat(n)
            let w = (size.width - gap * CGFloat(n - 1)) / CGFloat(n)
            var rects: [CGRect] = []
            for i in 0..<n {
                let off = abs(Double(i) - Double(n - 1) / 2) / Double(n)
                let centre = 1 - off * 0.8
                let lowEnd = noise(t * 1.6, Double(i) * 1.37), highEnd = noise(t * 3.4, Double(i) * 2.11 + 5)
                let v = playing ? 0.16 + 0.84 * min(1, (0.62 * lowEnd + 0.38 * highEnd) * centre + kick * 0.35 * (1 - off)) : 0.16
                let h = max(w, size.height * v)
                rects.append(CGRect(x: CGFloat(i) * (w + gap), y: (size.height - h) / 2, width: w, height: h))
            }
            if playing {
                ctx.drawLayer { g in
                    g.addFilter(.blur(radius: 3))
                    for r in rects { g.fill(Path(roundedRect: r, cornerRadius: w / 2), with: .color(tint.opacity(0.55))) }
                }
            }
            let shade = GraphicsContext.Shading.linearGradient(Gradient(colors: [tint.opacity(0.75), tint, tint.opacity(0.75)]),
                                                               startPoint: CGPoint(x: 0, y: size.height), endPoint: CGPoint(x: 0, y: 0))
            for r in rects {
                ctx.fill(Path(roundedRect: r, cornerRadius: w / 2), with: shade)
                ctx.fill(Path(roundedRect: CGRect(x: r.minX + w * 0.2, y: r.minY + w * 0.15, width: w * 0.6, height: min(r.height * 0.3, w)), cornerRadius: w * 0.3),
                         with: .color(.white.opacity(playing ? 0.45 : 0.15)))
            }
        }
    }
}

/// NEW: a little disco in the notch — neon outline dancers (boy, girl or both) doing disco moves
/// under a spinning mirror ball, with sweeping light beams and a flashing dance floor. Shapes only.
struct Dancers: View {
    var playing: Bool
    var color: Color
    var who: String     // boy | girl | both

    typealias Pose = [CGPoint]   // head, neck, pelvis, lElbow, lHand, rElbow, rHand, lKnee, lFoot, rKnee, rFoot
    private static func P(_ v: [CGFloat]) -> Pose { stride(from: 0, to: v.count, by: 2).map { CGPoint(x: v[$0], y: v[$0 + 1]) } }
    private static func mirror(_ p: Pose) -> Pose {
        let m = p.map { CGPoint(x: 1 - $0.x, y: $0.y) }
        return [m[0], m[1], m[2], m[5], m[6], m[3], m[4], m[9], m[10], m[7], m[8]]
    }
    static let moves: [Pose] = {
        let pointUp = P([0.50,0.14, 0.50,0.26, 0.52,0.55, 0.40,0.42, 0.47,0.53, 0.66,0.16, 0.80,0.03, 0.44,0.76, 0.40,0.97, 0.62,0.75, 0.66,0.97])
        let pointDown = P([0.48,0.16, 0.49,0.28, 0.50,0.57, 0.37,0.44, 0.22,0.62, 0.61,0.42, 0.55,0.53, 0.40,0.77, 0.36,0.97, 0.60,0.77, 0.64,0.97])
        let roll = P([0.53,0.15, 0.52,0.27, 0.57,0.56, 0.41,0.37, 0.53,0.35, 0.65,0.40, 0.54,0.42, 0.47,0.77, 0.43,0.97, 0.65,0.75, 0.69,0.97])
        return [pointUp, pointDown, roll, mirror(pointUp), mirror(pointDown), mirror(roll)]
    }()
    static let bpm = 116.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 50, paused: !playing)) { tl in
            let t = playing ? tl.date.timeIntervalSinceReferenceDate : 0
            Canvas { ctx, size in scene(ctx, size, t) }
        }
    }

    private static func hue(_ h: Double, _ l: Double = 0.6) -> Color {
        Color(hue: (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360, saturation: 1, brightness: min(1, l + 0.4))
    }

    private func scene(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let W = size.width, H = size.height
        let beat = t * Self.bpm / 60
        let hue = Double(Int(floor(beat)) * 47 % 360)
        // dance floor
        let n = 8, tw = W / CGFloat(n), fy = H * 0.9
        for i in 0..<n {
            let on = (Int(floor(beat)) + i) % 3 == 0
            ctx.fill(Path(CGRect(x: CGFloat(i) * tw + 0.5, y: fy, width: tw - 1, height: H - fy)),
                     with: .color(on ? Self.hue(hue + Double(i) * 40, 0.5).opacity(0.55) : .white.opacity(0.06)))
        }
        // light beams from the mirror ball
        let ball = CGPoint(x: W / 2, y: H * 0.1)
        for k in 0..<3 {
            let a = Double.pi / 2 + sin(t * 1.3 + Double(k) * 2.1) * 0.9, sp = 0.12
            var beam = Path()
            beam.move(to: ball)
            beam.addLine(to: CGPoint(x: ball.x + cos(a - sp) * H * 2, y: ball.y + sin(a - sp) * H * 2))
            beam.addLine(to: CGPoint(x: ball.x + cos(a + sp) * H * 2, y: ball.y + sin(a + sp) * H * 2))
            ctx.fill(beam, with: .color(Self.hue(hue + Double(k) * 120).opacity(0.16)))
        }
        // dancers
        let list: [Bool] = who == "boy" ? [false] : who == "girl" ? [true] : [false, true]
        let fw = min(W / CGFloat(list.count), H * 0.75)
        let gap = (W - fw * CGFloat(list.count)) / CGFloat(list.count + 1)
        for (i, girl) in list.enumerated() {
            figure(ctx, CGRect(x: gap + CGFloat(i) * (fw + gap), y: H * 0.12, width: fw, height: H * 0.8), girl: girl, t: t, hue: hue + Double(i) * 140)
        }
        // mirror ball
        let br = max(3, H * 0.1)
        var c2 = ctx
        c2.clip(to: Path(ellipseIn: CGRect(x: ball.x - br, y: ball.y - br, width: br * 2, height: br * 2)))
        c2.fill(Path(CGRect(x: ball.x - br, y: ball.y - br, width: br * 2, height: br * 2)), with: .color(Color(red: 0.79, green: 0.82, blue: 0.91)))
        var grid = Path()
        for k in -3...3 { let yy = ball.y + CGFloat(k) * br / 3.2; grid.move(to: CGPoint(x: ball.x - br, y: yy)); grid.addLine(to: CGPoint(x: ball.x + br, y: yy)) }
        let rot = (t * 1.5).truncatingRemainder(dividingBy: 1)
        for k in -3...4 { let xx = ball.x + sin((Double(k) / 4 + rot / 4) * .pi) * br; grid.move(to: CGPoint(x: xx, y: ball.y - br)); grid.addLine(to: CGPoint(x: xx, y: ball.y + br)) }
        c2.stroke(grid, with: .color(Color(red: 0.35, green: 0.39, blue: 0.47)), lineWidth: max(0.5, br * 0.12))
        // sparkles
        for k in 0..<4 {
            let tw2 = (sin(t * 9 + Double(k) * 1.9) + 1) / 2
            guard tw2 > 0.7 else { continue }
            let a = Double(k) * 1.6 + t
            let sp = CGPoint(x: ball.x + cos(a) * br * 1.8, y: ball.y + sin(a) * br * 1.3 + br * 0.6)
            ctx.fill(Path(CGRect(x: sp.x - 0.5, y: sp.y - br * 0.5, width: 1, height: br)), with: .color(.white.opacity(tw2)))
            ctx.fill(Path(CGRect(x: sp.x - br * 0.5, y: sp.y - 0.5, width: br, height: 1)), with: .color(.white.opacity(tw2)))
        }
    }

    private func pose(_ t: Double, offset: Double) -> Pose {
        let b = t * Self.bpm / 60 + offset
        let i = Int(floor(b)) % Self.moves.count
        var f = b - floor(b)
        f = min(1, f * 1.6); f = f * f * (3 - 2 * f)       // hit each pose, then hold it
        let a = Self.moves[i], c = Self.moves[(i + 1) % Self.moves.count]
        return zip(a, c).map { CGPoint(x: $0.x + ($1.x - $0.x) * f, y: $0.y + ($1.y - $0.y) * f) }
    }

    private func figure(_ ctx: GraphicsContext, _ r: CGRect, girl: Bool, t: Double, hue: Double) {
        let p = pose(t, offset: girl ? 3 : 0)
        let bob = abs(sin(t * .pi * Self.bpm / 60)) * 0.025
        func pt(_ i: Int) -> CGPoint { CGPoint(x: r.minX + p[i].x * r.width, y: r.minY + (p[i].y + bob) * r.height) }
        let s = r.height, edge = max(1, s * 0.024)
        let c1 = Self.hue(hue), c2 = Self.hue(hue + 50, 0.62)
        let ink = Color(red: 0.02, green: 0.016, blue: 0.04)
        let hd = pt(0), nk = pt(1), pv = pt(2), hr = s * 0.075
        func tube(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint? = nil) -> Path {
            var q = Path(); q.move(to: a)
            if let c { q.addQuadCurve(to: b, control: c) } else { q.addLine(to: b) }
            return q
        }
        // Each piece: glow, neon tube, then hollow — drawn back to front so arms show over the body.
        func piece(_ path: Path, _ w: CGFloat, _ col: Color) {
            ctx.drawLayer { g in
                g.addFilter(.blur(radius: max(1.5, s * 0.045)))
                g.stroke(path, with: .color(col), style: StrokeStyle(lineWidth: w + edge * 3, lineCap: .round, lineJoin: .round))
            }
            ctx.stroke(path, with: .color(col), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
            ctx.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: max(0, w - edge * 2), lineCap: .round, lineJoin: .round))
        }
        piece(tube(pv, pt(8), pt(7)), s * 0.065, c2)
        piece(tube(pv, pt(10), pt(9)), s * 0.065, c2)
        if !girl { for f in [8, 10] { let q = pt(f); piece(tube(CGPoint(x: q.x - s * 0.04, y: q.y - s * 0.015), CGPoint(x: q.x + s * 0.04, y: q.y - s * 0.015)), s * 0.06, c2) } }
        piece(tube(nk, pv), s * (girl ? 0.1 : 0.13), c1)
        if girl {
            let sw = sin(t * .pi * Self.bpm / 60) * s * 0.03, top = pv.y - s * 0.1, bot = pv.y + s * 0.14
            var dress = Path()
            dress.move(to: CGPoint(x: pv.x - s * 0.05, y: top))
            dress.addLine(to: CGPoint(x: pv.x - s * 0.17 + sw, y: bot))
            dress.addQuadCurve(to: CGPoint(x: pv.x + s * 0.17 + sw, y: bot), control: CGPoint(x: pv.x + sw, y: bot + s * 0.04))
            dress.addLine(to: CGPoint(x: pv.x + s * 0.05, y: top))
            dress.closeSubpath()
            ctx.drawLayer { g in
                g.addFilter(.blur(radius: max(1.5, s * 0.045)))
                g.stroke(dress, with: .color(c2), lineWidth: edge * 3)
            }
            ctx.fill(dress, with: .color(ink))
            ctx.stroke(dress, with: .color(c2), style: StrokeStyle(lineWidth: edge * 1.2, lineJoin: .round))
            let sway = sin(t * 7) * hr * 0.6
            piece(tube(CGPoint(x: hd.x - hr * 0.4, y: hd.y - hr * 0.3), CGPoint(x: hd.x - hr * 1.5 + sway, y: hd.y + hr * 2.2),
                       CGPoint(x: hd.x - hr * 1.6, y: hd.y + hr * 0.4)), hr * 0.9, c1)       // hair flowing
        }
        piece(tube(nk, pt(4), pt(3)), s * 0.05, c1)
        piece(tube(nk, pt(6), pt(5)), s * 0.05, c1)
        if !girl { piece(tube(CGPoint(x: hd.x, y: hd.y - hr * 0.25), CGPoint(x: hd.x + 0.01, y: hd.y - hr * 0.25)), hr * 2.9, c1) }  // afro
        piece(tube(hd, CGPoint(x: hd.x + 0.01, y: hd.y)), hr * 2, c1)
    }
}

/// Optional charging animation: liquid filling a battery with a pulsing bolt.
struct ChargingBattery: View {
    let level: Int
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let body = CGRect(x: 1, y: 1, width: size.width - 5, height: size.height - 2)
                let shell = Path(roundedRect: body, cornerRadius: size.height * 0.28)
                ctx.stroke(shell, with: .color(.white.opacity(0.55)), lineWidth: 1.2)
                ctx.fill(Path(roundedRect: CGRect(x: size.width - 3, y: size.height * 0.33, width: 2.5, height: size.height * 0.34), cornerRadius: 1),
                         with: .color(.white.opacity(0.55)))
                var inner = ctx
                inner.clip(to: Path(roundedRect: body.insetBy(dx: 2, dy: 2), cornerRadius: size.height * 0.2))
                let fillW = (body.width - 4) * CGFloat(level) / 100
                var wave = Path()
                let x0 = body.minX + 2, top = body.minY + 2, bottom = body.maxY - 2
                wave.move(to: CGPoint(x: x0, y: bottom)); wave.addLine(to: CGPoint(x: x0, y: top))
                for y in stride(from: top, through: bottom, by: 0.5) {
                    let x = x0 + fillW + sin((y / body.height) * .pi * 2 + t * 6) * 1.6
                    wave.addLine(to: CGPoint(x: x, y: y))
                }
                wave.addLine(to: CGPoint(x: x0, y: bottom)); wave.closeSubpath()
                inner.fill(wave, with: .linearGradient(Gradient(colors: [Color(red: 0.2, green: 0.85, blue: 0.45), Color(red: 0.55, green: 1, blue: 0.6)]),
                                                       startPoint: CGPoint(x: x0, y: 0), endPoint: CGPoint(x: x0 + fillW, y: 0)))
                // shine sweeping across
                let sx = x0 + (t * 0.8).truncatingRemainder(dividingBy: 1) * (fillW + 12) - 6
                inner.fill(Path(CGRect(x: sx, y: top, width: 5, height: bottom - top)), with: .color(.white.opacity(0.25)))
            }
            .overlay(Image(systemName: "bolt.fill").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                .scaleEffect(1 + 0.15 * sin(t * 4)).shadow(color: .green, radius: 3))
        }
    }
}
