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

/// NEW: outline dancers (boy, girl or both) that dance while music plays. Shapes only, no faces.
struct Dancers: View {
    var playing: Bool
    var color: Color
    var who: String     // boy | girl | both

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 45, paused: !playing)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let figures: [Bool] = who == "boy" ? [false] : who == "girl" ? [true] : [false, true]
                let w = size.width / CGFloat(figures.count)
                for (i, girl) in figures.enumerated() {
                    figure(ctx: ctx, rect: CGRect(x: CGFloat(i) * w, y: 0, width: w, height: size.height), girl: girl,
                           t: playing ? t + Double(i) * 0.35 : 0)
                }
            }
        }
    }

    private func figure(ctx: GraphicsContext, rect r: CGRect, girl: Bool, t: Double) {
        let s = min(r.width / 1.0, r.height / 1.25)      // figure scale
        let beat = sin(t * 2 * .pi * 2.0)               // 120 bpm
        let bounce = abs(beat) * s * 0.06
        let sway = sin(t * 2 * .pi) * s * 0.07
        let cx = r.midX + sway
        let headR = s * 0.11
        let headY = r.minY + headR + s * 0.04 + bounce
        let neck = CGPoint(x: cx, y: headY + headR)
        let hip = CGPoint(x: cx - sway * 0.4, y: neck.y + s * 0.38)
        let style = StrokeStyle(lineWidth: max(1.2, s * 0.06), lineCap: .round, lineJoin: .round)
        var p = Path()
        // head (outline)
        p.addEllipse(in: CGRect(x: cx - headR, y: headY - headR, width: headR * 2, height: headR * 2))
        if girl {   // ponytail swings with the beat
            p.move(to: CGPoint(x: cx + headR * 0.8, y: headY - headR * 0.3))
            p.addQuadCurve(to: CGPoint(x: cx + headR * (1.9 + beat * 0.4), y: headY + headR * 0.6),
                           control: CGPoint(x: cx + headR * 1.8, y: headY - headR * 0.8))
        }
        // body
        p.move(to: neck); p.addLine(to: hip)
        // arms: up-and-down disco moves
        let shoulder = CGPoint(x: neck.x, y: neck.y + s * 0.08)
        let la = Angle.degrees(-150 + 70 * sin(t * 2 * .pi * 2)), ra = Angle.degrees(-30 - 70 * sin(t * 2 * .pi * 2 + .pi))
        for a in [la, ra] {
            let elbow = CGPoint(x: shoulder.x + cos(a.radians) * s * 0.17, y: shoulder.y + sin(a.radians) * s * 0.17)
            let hand = CGPoint(x: elbow.x + cos(a.radians + 0.6) * s * 0.15, y: elbow.y + sin(a.radians + 0.6) * s * 0.15)
            p.move(to: shoulder); p.addLine(to: elbow); p.addLine(to: hand)
        }
        if girl {   // skirt outline
            let hem = s * 0.2
            p.move(to: CGPoint(x: hip.x - s * 0.06, y: hip.y - s * 0.08))
            p.addLine(to: CGPoint(x: hip.x - hem + sway * 0.3, y: hip.y + s * 0.12))
            p.addLine(to: CGPoint(x: hip.x + hem + sway * 0.3, y: hip.y + s * 0.12))
            p.addLine(to: CGPoint(x: hip.x + s * 0.06, y: hip.y - s * 0.08))
        }
        // legs: alternate steps
        let step = sin(t * 2 * .pi * 2)
        let legTop = girl ? CGPoint(x: hip.x, y: hip.y + s * 0.12) : hip
        let floorY = r.maxY - s * 0.02
        for side in [-1.0, 1.0] {
            let lift = max(0, step * side) * s * 0.12
            let knee = CGPoint(x: legTop.x + side * s * 0.09, y: (legTop.y + floorY) / 2 - lift)
            let foot = CGPoint(x: legTop.x + side * s * 0.13, y: floorY - lift * 0.6)
            p.move(to: legTop); p.addLine(to: knee); p.addLine(to: foot)
        }
        ctx.stroke(p, with: .color(color), style: style)
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
