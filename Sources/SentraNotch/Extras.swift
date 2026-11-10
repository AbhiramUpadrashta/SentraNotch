//
//  Extras.swift — Sentra Notch
//  Live charging animation, wellbeing reminders and the album-art morph between closed and open notch.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import SwiftUI
import CoreGraphics

// MARK: - Album art morph (closed ⇄ open)

private struct AlbumNSKey: EnvironmentKey { static let defaultValue: Namespace.ID? = nil }
extension EnvironmentValues {
    var albumNS: Namespace.ID? { get { self[AlbumNSKey.self] } set { self[AlbumNSKey.self] = newValue } }
}
extension View {
    @ViewBuilder func albumMatch(_ ns: Namespace.ID?) -> some View {
        if let ns { matchedGeometryEffect(id: "album-art", in: ns) } else { self }
    }
}

// MARK: - Power flowing into the battery

/// Energy pulses stream from a bolt into the battery, which fills up with glowing liquid.
struct PowerFlow: View {
    let level: Int
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 50)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in draw(ctx, size, t) }
        }
    }
    private func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let H = size.height, W = size.width
        let green = Color(red: 0.25, green: 0.95, blue: 0.5), mint = Color(red: 0.6, green: 1, blue: 0.8)
        let bw = min(W * 0.62, H * 2.1), bh = H * 0.8
        let body = CGRect(x: W - bw - 3, y: (H - bh) / 2, width: bw, height: bh)
        let cable = body.minX - 2
        // bolt at the far left
        let bx = H * 0.32, pulse = 0.75 + 0.25 * sin(t * 6)
        var bolt = Path()
        let s = H * 0.42, cx = bx, cy = H / 2
        bolt.move(to: CGPoint(x: cx + s * 0.15, y: cy - s))
        bolt.addLine(to: CGPoint(x: cx - s * 0.5, y: cy + s * 0.12))
        bolt.addLine(to: CGPoint(x: cx - s * 0.02, y: cy + s * 0.12))
        bolt.addLine(to: CGPoint(x: cx - s * 0.15, y: cy + s))
        bolt.addLine(to: CGPoint(x: cx + s * 0.5, y: cy - s * 0.12))
        bolt.addLine(to: CGPoint(x: cx + s * 0.02, y: cy - s * 0.12))
        bolt.closeSubpath()
        ctx.drawLayer { g in g.addFilter(.blur(radius: 3)); g.fill(bolt, with: .color(green.opacity(pulse))) }
        ctx.fill(bolt, with: .color(.white))
        // track + flowing energy pulses
        let x0 = bx + s * 0.7
        ctx.stroke(Path { p in p.move(to: CGPoint(x: x0, y: cy)); p.addLine(to: CGPoint(x: cable, y: cy)) },
                   with: .color(green.opacity(0.18)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        for k in 0..<3 {
            let ph = (t * 1.4 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
            let x = x0 + (cable - x0) * ph, len = max(3, (cable - x0) * 0.22)
            let seg = Path { p in p.move(to: CGPoint(x: max(x0, x - len), y: cy)); p.addLine(to: CGPoint(x: x, y: cy)) }
            ctx.drawLayer { g in g.addFilter(.blur(radius: 2)); g.stroke(seg, with: .color(green), lineWidth: 3.5) }
            ctx.stroke(seg, with: .color(mint), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        // battery shell
        let r = bh * 0.3
        ctx.stroke(Path(roundedRect: body, cornerRadius: r), with: .color(.white.opacity(0.6)), lineWidth: 1.2)
        ctx.fill(Path(roundedRect: CGRect(x: body.maxX + 0.8, y: body.midY - bh * 0.18, width: 2.2, height: bh * 0.36), cornerRadius: 1),
                 with: .color(.white.opacity(0.6)))
        var inner = ctx
        let ib = body.insetBy(dx: 2, dy: 2)
        inner.clip(to: Path(roundedRect: ib, cornerRadius: r * 0.7))
        // liquid with a living surface, slowly "breathing" upward to show charge being added
        let breathe = (t * 0.5).truncatingRemainder(dividingBy: 1) * 0.06
        let frac = min(1, Double(level) / 100 + breathe)
        let fx = ib.minX + ib.width * frac
        var liquid = Path()
        liquid.move(to: CGPoint(x: ib.minX, y: ib.maxY)); liquid.addLine(to: CGPoint(x: ib.minX, y: ib.minY))
        for y in stride(from: ib.minY, through: ib.maxY, by: 0.5) {
            liquid.addLine(to: CGPoint(x: fx + sin((y - ib.minY) / ib.height * .pi * 2 + t * 7) * 1.4, y: y))
        }
        liquid.addLine(to: CGPoint(x: ib.minX, y: ib.maxY)); liquid.closeSubpath()
        inner.fill(liquid, with: .linearGradient(Gradient(colors: [green.opacity(0.75), green, mint]),
                                                 startPoint: CGPoint(x: ib.minX, y: 0), endPoint: CGPoint(x: fx, y: 0)))
        // charge front glow + shine sweep
        inner.drawLayer { g in g.addFilter(.blur(radius: 2.5)); g.fill(Path(CGRect(x: fx - 2, y: ib.minY, width: 3, height: ib.height)), with: .color(.white.opacity(0.8))) }
        let sx = ib.minX + (t * 0.9).truncatingRemainder(dividingBy: 1) * (fx - ib.minX + 10) - 5
        inner.fill(Path(CGRect(x: sx, y: ib.minY, width: 4, height: ib.height)), with: .color(.white.opacity(0.25)))
        // bubbles rising in the liquid
        for k in 0..<4 {
            let ph = (t * 0.8 + Double(k) * 0.27).truncatingRemainder(dividingBy: 1)
            let x = ib.minX + (fx - ib.minX) * (0.15 + Double(k) * 0.22)
            let y = ib.maxY - ph * ib.height, rr = 0.9 + Double(k % 2) * 0.5
            inner.fill(Path(ellipseIn: CGRect(x: x - rr, y: y - rr, width: rr * 2, height: rr * 2)), with: .color(.white.opacity(0.55 * (1 - ph))))
        }
    }
}

/// Shown in the closed notch while the Mac charges and no music is playing.
struct ChargingLiveView: View {
    @ObservedObject var power = PowerMonitor.shared
    let closed: CGSize
    var body: some View {
        SidesLayout(closed: closed) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(red: 0.3, green: 0.95, blue: 0.55))
                    .symbolEffect(.pulse, options: .repeating)
                Text("\(power.level)%").font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText())
            }
        } right: {
            PowerFlow(level: power.level).frame(width: 58, height: 16)
        } bottom: { EmptyView() }
    }
}

// MARK: - Wellbeing reminders

struct ReminderKind: Identifiable, Equatable {
    let id: String, name: String, title: String, subtitle: String, symbol: String, color: Color, defaultOn: Bool, defaultMinutes: Double
    var enabledKey: String { "rem.\(id).on" }
    var minutesKey: String { "rem.\(id).min" }

    static let all: [ReminderKind] = [
        .init(id: "water", name: "Drink water", title: "Time for some water", subtitle: "Stay hydrated · a glass now", symbol: "drop.fill",
              color: Color(red: 0.35, green: 0.75, blue: 1), defaultOn: true, defaultMinutes: 60),
        .init(id: "break", name: "Take a break", title: "Take a short break", subtitle: "Stand up and walk around", symbol: "figure.walk",
              color: Color(red: 1, green: 0.7, blue: 0.3), defaultOn: true, defaultMinutes: 50),
        .init(id: "eyes", name: "Rest your eyes", title: "Rest your eyes", subtitle: "Look 20 ft away for 20 seconds", symbol: "eye.fill",
              color: Color(red: 0.6, green: 0.55, blue: 1), defaultOn: false, defaultMinutes: 20),
        .init(id: "stretch", name: "Stretch", title: "Stretch it out", subtitle: "Neck, shoulders and back", symbol: "figure.flexibility",
              color: Color(red: 0.4, green: 0.95, blue: 0.6), defaultOn: false, defaultMinutes: 90),
        .init(id: "posture", name: "Posture check", title: "Posture check", subtitle: "Sit up straight, relax your shoulders", symbol: "figure.stand",
              color: Color(red: 1, green: 0.5, blue: 0.7), defaultOn: false, defaultMinutes: 45),
    ]
    static func find(_ id: String) -> ReminderKind? { all.first { $0.id == id } }

    static var defaults: [String: Any] {
        var d: [String: Any] = [:]
        for k in all { d[k.enabledKey] = k.defaultOn; d[k.minutesKey] = k.defaultMinutes }
        return d
    }
}

@MainActor
final class ReminderMonitor {
    static let shared = ReminderMonitor()
    private var last: [String: Date] = [:]
    private var timer: Timer?

    func start() {
        UserDefaults.standard.register(defaults: ReminderKind.defaults)
        let now = Date()
        for k in ReminderKind.all { last[k.id] = now }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in Task { @MainActor in ReminderMonitor.shared.tick() } }
    }

    /// Seconds since the last keyboard / mouse input.
    private var idleSeconds: Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    private func tick() {
        let now = Date(), idle = idleSeconds
        for k in ReminderKind.all {
            if idle > 300 { last[k.id] = now; continue }          // away from the Mac already counts as a break
            guard UserDefaults.standard.bool(forKey: k.enabledKey) else { continue }
            let mins = max(5, UserDefaults.standard.double(forKey: k.minutesKey))
            guard now.timeIntervalSince(last[k.id] ?? now) >= mins * 60, idle < 90 else { continue }
            let m = NotchModel.shared
            guard !m.isOpen, !m.hidden, m.peek == nil else { continue }   // try again on the next tick
            last[k.id] = now
            show(k)
            break
        }
    }

    func show(_ k: ReminderKind) { NotchModel.shared.show(.reminder(k.id), for: 5) }
}

struct ReminderPeek: View {
    let kind: ReminderKind; let closed: CGSize
    @State private var appear = false
    var body: some View {
        SidesLayout(closed: closed) {
            ReminderIcon(kind: kind).frame(width: 24, height: 24)
        } right: {
            TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack {
                    Circle().stroke(kind.color.opacity(0.2), lineWidth: 2)
                    Circle().trim(from: 0, to: appear ? 1 : 0).stroke(kind.color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Circle().fill(kind.color).frame(width: 5, height: 5).opacity(0.5 + 0.5 * sin(t * 5))
                }.frame(width: 18, height: 18)
            }
        } bottom: {
            HStack(spacing: 6) {
                Text(kind.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(kind.color)
                Text(kind.subtitle).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
            }
            .padding(.bottom, 4)
        }
        .onAppear { withAnimation(.easeInOut(duration: 4.5)) { appear = true } }
    }
}

/// Animated icon per reminder: water fills a glass, the walker bounces, the eye blinks…
struct ReminderIcon: View {
    let kind: ReminderKind
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            if kind.id == "water" {
                Canvas { ctx, size in water(ctx, size, t) }
            } else {
                let blink = kind.id == "eyes" ? (sin(t * 2.6) > 0.93 ? 0.1 : 1) : 1
                Image(systemName: kind.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(kind.color)
                    .scaleEffect(x: 1, y: blink)
                    .offset(y: kind.id == "break" ? -abs(sin(t * 6)) * 2.5 : 0)
                    .rotationEffect(.degrees(kind.id == "stretch" ? sin(t * 3) * 12 : kind.id == "posture" ? sin(t * 2) * 5 : 0))
                    .shadow(color: kind.color.opacity(0.7), radius: 4)
            }
        }
    }
    private func water(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height
        var glass = Path()
        glass.move(to: CGPoint(x: w * 0.2, y: h * 0.1)); glass.addLine(to: CGPoint(x: w * 0.3, y: h * 0.92))
        glass.addLine(to: CGPoint(x: w * 0.7, y: h * 0.92)); glass.addLine(to: CGPoint(x: w * 0.8, y: h * 0.1))
        let fill = 0.25 + 0.6 * min(1, (t * 0.35).truncatingRemainder(dividingBy: 1.4))
        var c = ctx
        var clip = glass; clip.closeSubpath()
        c.clip(to: clip)
        let top = h * 0.92 - (h * 0.82) * fill
        var water = Path()
        water.move(to: CGPoint(x: 0, y: h))
        for x in stride(from: 0, through: w, by: 1) { water.addLine(to: CGPoint(x: x, y: top + sin(x / w * .pi * 2 + t * 6) * 1.2)) }
        water.addLine(to: CGPoint(x: w, y: h)); water.closeSubpath()
        c.fill(water, with: .linearGradient(Gradient(colors: [kind.color, kind.color.opacity(0.6)]), startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: h)))
        for k in 0..<3 {
            let ph = (t * 0.9 + Double(k) * 0.33).truncatingRemainder(dividingBy: 1)
            let y = h * 0.9 - ph * (h * 0.9 - top), x = w * (0.38 + Double(k) * 0.12)
            c.fill(Path(ellipseIn: CGRect(x: x - 0.9, y: y - 0.9, width: 1.8, height: 1.8)), with: .color(.white.opacity(0.7 * (1 - ph))))
        }
        ctx.drawLayer { g in g.addFilter(.blur(radius: 2)); g.stroke(glass, with: .color(kind.color.opacity(0.6)), lineWidth: 2) }
        ctx.stroke(glass, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
    }
}

struct RemindersPage: View {
    @State private var refresh = 0
    var body: some View {
        Section("Reminders (new in Sentra)") {
            ForEach(ReminderKind.all) { k in ReminderRow(kind: k) }
            Text("Reminders pop out of the notch for 5 seconds with a small animation. They only appear while you're using the Mac, and time spent away (5 min or more) counts as a break.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct ReminderRow: View {
    let kind: ReminderKind
    @AppStorage private var on: Bool
    @AppStorage private var minutes: Double
    init(kind: ReminderKind) {
        self.kind = kind
        _on = AppStorage(wrappedValue: kind.defaultOn, kind.enabledKey)
        _minutes = AppStorage(wrappedValue: kind.defaultMinutes, kind.minutesKey)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: kind.symbol).foregroundStyle(kind.color).frame(width: 22)
                Toggle(kind.name, isOn: $on)
                Button("Preview") { ReminderMonitor.shared.show(kind) }.controlSize(.small)
            }
            if on {
                Picker("Every", selection: $minutes) {
                    ForEach([15.0, 20, 30, 45, 50, 60, 90, 120], id: \.self) { m in Text(m < 60 ? "\(Int(m)) min" : m == 60 ? "1 hour" : m == 90 ? "1.5 hours" : "2 hours").tag(m) }
                }
                .padding(.leading, 30)
            }
        }
    }
}
