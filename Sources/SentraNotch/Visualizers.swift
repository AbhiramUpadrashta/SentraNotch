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
        switch style {
        case "waves":
            for layer in 0..<3 {
                var p = Path()
                let amp = size.height / 2 * (playing ? (0.9 - Double(layer) * 0.22) * (0.55 + 0.45 * noise(t * 0.6, Double(layer))) : 0.06)
                for x in stride(from: 0, through: size.width, by: 1) {
                    let r = x / size.width
                    let y = size.height / 2 + amp * sin(r * .pi) * sin(r * .pi * (2.4 + Double(layer) * 0.8) - t * (4 + Double(layer) * 1.4))
                    if x == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
                ctx.stroke(p, with: .color(tint.opacity(1 - Double(layer) * 0.3)), style: StrokeStyle(lineWidth: 2 - CGFloat(layer) * 0.45, lineCap: .round))
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
        default: // spectrum bars, mirrored around the middle like a real analyser
            let n = max(3, bars)
            let gap = size.width * 0.12 / CGFloat(n)
            let w = (size.width - gap * CGFloat(n - 1)) / CGFloat(n)
            for i in 0..<n {
                let centre = 1 - abs(Double(i) - Double(n - 1) / 2) / Double(n) * 0.9
                let v = playing ? 0.18 + 0.82 * noise(t * 2.2, Double(i) * 1.37) * centre : 0.16
                let h = max(w, size.height * v)
                let rect = CGRect(x: CGFloat(i) * (w + gap), y: (size.height - h) / 2, width: w, height: h)
                ctx.fill(Path(roundedRect: rect, cornerRadius: w / 2), with: shading)
            }
        }
    }
}

/// NEW: neon dancers (hip-hop boy, ballerina girl, or both) that dance while music plays.
/// Glowing light-outline figures with light trails — shapes only, no faces.
struct Dancers: View {
    var playing: Bool
    var color: Color
    var who: String     // boy | girl | both

    // Skeleton joints in a unit box (x right, y down): head, neck, pelvis, lElbow, lHand, rElbow, rHand, lKnee, lFoot, rKnee, rFoot
    typealias Pose = [CGPoint]
    private static func P(_ v: [CGFloat]) -> Pose { stride(from: 0, to: v.count, by: 2).map { CGPoint(x: v[$0], y: v[$0 + 1]) } }
    private static func mirror(_ p: Pose) -> Pose {
        let m = p.map { CGPoint(x: 1 - $0.x, y: $0.y) }
        return [m[0], m[1], m[2], m[5], m[6], m[3], m[4], m[9], m[10], m[7], m[8]]
    }
    static let hipHop: [Pose] = {
        let a = P([0.50,0.10, 0.50,0.22, 0.50,0.52, 0.36,0.30, 0.27,0.15, 0.66,0.34, 0.75,0.48, 0.42,0.72, 0.37,0.96, 0.60,0.72, 0.67,0.96])
        let b = P([0.55,0.12, 0.52,0.24, 0.48,0.54, 0.38,0.37, 0.33,0.52, 0.67,0.19, 0.82,0.07, 0.41,0.76, 0.40,0.97, 0.66,0.58, 0.57,0.80])
        let c = P([0.45,0.19, 0.48,0.31, 0.52,0.61, 0.33,0.41, 0.28,0.57, 0.65,0.40, 0.75,0.29, 0.37,0.77, 0.29,0.97, 0.67,0.79, 0.74,0.97])
        return [a, b, c, mirror(b)]
    }()
    static let ballet: [Pose] = {
        let a = P([0.40,0.12, 0.42,0.22, 0.48,0.48, 0.30,0.22, 0.15,0.14, 0.58,0.12, 0.66,0.02, 0.48,0.72, 0.48,0.98, 0.67,0.45, 0.88,0.35])
        let b = P([0.50,0.12, 0.50,0.22, 0.50,0.50, 0.42,0.10, 0.48,0.01, 0.58,0.10, 0.52,0.01, 0.48,0.73, 0.49,0.98, 0.58,0.65, 0.50,0.74])
        let c = P([0.50,0.12, 0.50,0.22, 0.50,0.50, 0.34,0.27, 0.18,0.30, 0.66,0.27, 0.82,0.30, 0.46,0.74, 0.44,0.98, 0.56,0.74, 0.58,0.98])
        return [a, b, c, mirror(a)]
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 50, paused: !playing)) { tl in
            let t = playing ? tl.date.timeIntervalSinceReferenceDate : 0
            Canvas { ctx, size in
                let list: [Bool] = who == "boy" ? [false] : who == "girl" ? [true] : [false, true]
                let w = size.width / CGFloat(list.count)
                for (i, girl) in list.enumerated() {
                    let h = size.height, fw = min(w, h * 0.9)
                    let rect = CGRect(x: CGFloat(i) * w + (w - fw) / 2, y: 0, width: fw, height: h)
                    dancer(ctx, rect, girl: girl, t: t + Double(i) * 0.5)
                }
            }
        }
    }

    private func pose(_ poses: [Pose], t: Double, bpm: Double) -> Pose {
        let beats = t * bpm / 60
        let i = Int(floor(beats)) % poses.count
        var f = beats - floor(beats)
        f = f * f * (3 - 2 * f)                       // smoothstep: snap into each move
        let a = poses[i], b = poses[(i + 1) % poses.count]
        return zip(a, b).map { CGPoint(x: $0.x + ($1.x - $0.x) * f, y: $0.y + ($1.y - $0.y) * f) }
    }

    private func dancer(_ ctx: GraphicsContext, _ r: CGRect, girl: Bool, t: Double) {
        let p = pose(girl ? Self.ballet : Self.hipHop, t: t, bpm: girl ? 70 : 100)
        let bounce = girl ? 0 : abs(sin(t * .pi * 100 / 60)) * 0.02
        func pt(_ i: Int) -> CGPoint { CGPoint(x: r.minX + p[i].x * r.width, y: r.minY + (p[i].y - bounce) * r.height) }
        func line(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint? = nil) -> Path {
            var q = Path(); q.move(to: a)
            if let c { q.addQuadCurve(to: b, control: c) } else { q.addLine(to: b) }
            return q
        }
        let s = r.height
        let main: Color = girl ? Color(red: 1, green: 0.31, blue: 0.85) : Color(red: 1, green: 0.42, blue: 0.17)
        let second: Color = girl ? Color(red: 0.44, green: 0.55, blue: 1) : Color(red: 0.18, green: 0.84, blue: 1)
        let shoe = Color(red: 1, green: 0.83, blue: 0.3)
        let hd = pt(0), nk = pt(1), pv = pt(2), hr = s * 0.07
        // Body parts as tubes: drawing each tube in colour, then hollowing them all out,
        // leaves one glowing outline around the whole silhouette.
        var parts: [(Path, CGFloat, Color)] = []
        parts.append((line(nk, pv), s * (girl ? 0.11 : 0.15), main))                          // torso
        parts.append((line(nk, pt(4), pt(3)), s * (girl ? 0.045 : 0.06), main))              // arms
        parts.append((line(nk, pt(6), pt(5)), s * (girl ? 0.045 : 0.06), main))
        let legTop = girl ? CGPoint(x: pv.x, y: pv.y + s * 0.02) : pv
        parts.append((line(legTop, pt(8), pt(7)), s * (girl ? 0.055 : 0.08), second))       // legs
        parts.append((line(legTop, pt(10), pt(9)), s * (girl ? 0.055 : 0.08), second))
        parts.append((line(hd, CGPoint(x: hd.x + 0.01, y: hd.y)), hr * 2, main))             // head
        if girl {
            let bun = CGPoint(x: hd.x + hr * 0.3, y: hd.y - hr * 1.1)
            parts.append((line(bun, CGPoint(x: bun.x + 0.01, y: bun.y)), hr * 0.9, main))
            let fl = sin(t * 6) * s * 0.015                                                    // tutu flutters
            parts.append((line(CGPoint(x: pv.x - s * 0.17, y: pv.y + s * 0.03 + fl), CGPoint(x: pv.x + s * 0.17, y: pv.y + s * 0.03 - fl),
                               CGPoint(x: pv.x, y: pv.y - s * 0.02)), s * 0.07, second))
        } else {
            parts.append((line(CGPoint(x: hd.x - hr * 0.2, y: hd.y - hr * 0.2), CGPoint(x: hd.x + hr * 0.3, y: hd.y + hr * 0.2)), hr * 2.5, main)) // hood
            for f in [8, 10] {
                let q = pt(f)
                parts.append((line(CGPoint(x: q.x - s * 0.025, y: q.y), CGPoint(x: q.x + s * 0.045, y: q.y)), s * 0.06, shoe))  // sneakers
            }
        }
        var trails = Path()
        for k in 0..<3 {
            let ph = t * (1.1 + Double(k) * 0.35) + Double(k) * 2.1
            let rx = r.width * (0.46 + 0.06 * Double(k)), ry = r.height * (0.32 + 0.05 * Double(k))
            for j in 0...12 {
                let a = ph + Double(j) * 0.13
                let q = CGPoint(x: r.midX + cos(a) * rx, y: r.midY + sin(a * 1.3) * ry)
                if j == 0 { trails.move(to: q) } else { trails.addLine(to: q) }
            }
        }
        let edge = max(1, s * 0.022)
        func style(_ w: CGFloat) -> StrokeStyle { StrokeStyle(lineWidth: max(0, w), lineCap: .round, lineJoin: .round) }
        ctx.drawLayer { g in
            g.addFilter(.blur(radius: max(1.5, s * 0.05)))
            g.opacity = 0.9
            for (q, w, c) in parts { g.stroke(q, with: .color(c), style: style(w + edge * 3)) }
        }
        ctx.stroke(trails, with: .color(color.opacity(0.35)), style: StrokeStyle(lineWidth: max(0.8, s * 0.012), lineCap: .round))
        for (q, w, c) in parts { ctx.stroke(q, with: .color(c), style: style(w)) }
        for (q, w, _) in parts { ctx.stroke(q, with: .color(.black), style: style(w - edge * 2)) }
        for (q, w, c) in parts { ctx.stroke(q, with: .color(c.opacity(0.13)), style: style(w - edge * 2)) }
        ctx.fill(Path(ellipseIn: CGRect(x: r.midX - r.width * 0.32, y: r.maxY - 2.5, width: r.width * 0.64, height: 3)),
                 with: .color((girl ? main : second).opacity(0.5)))
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
