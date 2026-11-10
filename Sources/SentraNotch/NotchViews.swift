//
//  NotchViews.swift — Sentra Notch
//  Everything drawn inside the notch: closed live activities and the open notch.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import SwiftUI

// MARK: - Shape

struct NotchShape: Shape {
    var top: CGFloat
    var bottom: CGFloat
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(top, bottom) } set { top = newValue.first; bottom = newValue.second }
    }
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX + top, y: r.minY + top), control: CGPoint(x: r.minX + top, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + top, y: r.maxY - bottom))
        p.addQuadCurve(to: CGPoint(x: r.minX + top + bottom, y: r.maxY), control: CGPoint(x: r.minX + top, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - top - bottom, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - top, y: r.maxY - bottom), control: CGPoint(x: r.maxX - top, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - top, y: r.minY + top))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.maxX - top, y: r.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Root

struct NotchRootView: View {
    @EnvironmentObject var model: NotchModel
    @ObservedObject var music = MusicModel.shared
    @AppStorage(Prefs.theme) private var themeName = "midnight"
    @AppStorage(Prefs.shadow) private var shadow = true
    @AppStorage(Prefs.cornerScaling) private var cornerScaling = true

    var body: some View {
        let size = model.currentSize
        let open = model.isOpen
        let theme = Theme.current()
        let bottom: CGFloat = open ? (cornerScaling ? 26 : 18) : (model.peek != nil ? 16 : 10)
        let topR: CGFloat = open ? 14 : 6
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                NotchShape(top: topR, bottom: bottom)
                    .fill(theme.background)
                    .overlay(NotchShape(top: topR, bottom: bottom).stroke(theme.border, lineWidth: 1))
                    .shadow(color: theme.glow, radius: open ? 18 : 8)
                    .shadow(color: .black.opacity(shadow && (open || model.peek != nil) ? 0.55 : 0), radius: 14, y: 6)
                content(open: open)
                    .padding(.horizontal, topR + (open ? 14 : 4))
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .clipShape(NotchShape(top: topR, bottom: bottom))
            }
            .frame(width: size.width + topR * 2, height: size.height)
            .onDrop(of: [.fileURL, .url, .text, .image], isTargeted: Binding(get: { model.dropTargeted }, set: { t in
                model.dropTargeted = t; if t { model.open(.shelf) }
            })) { ShelfModel.shared.handle(providers: $0) }
            .onTapGesture {
                if NSEvent.modifierFlags.contains(.option) { optionClick(); return }
                if !model.isOpen { model.open() }
            }
            .opacity(model.hidden ? 0 : 1)
            Spacer(minLength: 0)
        }
        .frame(width: NotchPanel.canvas.width, height: NotchPanel.canvas.height, alignment: .top)
        .animation(.notchOpen, value: open)
        .animation(.notchPeek, value: model.peek)
        .animation(.notchPeek, value: music.showsCompact)
        .preferredColorScheme(.dark)
    }

    private func optionClick() {
        switch Prefs.string(Prefs.optionClickAction) {
        case "shelf": model.open(.shelf)
        case "mirror": UserDefaults.standard.set(!Prefs.bool(Prefs.showMirror), forKey: Prefs.showMirror); model.open(.home)
        case "none": model.open()
        default: SettingsWindow.show()
        }
    }

    @ViewBuilder private func content(open: Bool) -> some View {
        if open {
            OpenNotchView().transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
        } else if let p = model.peek {
            PeekView(peek: p, closed: model.closedSize).transition(.opacity.combined(with: .blurReplace))
        } else if music.showsCompact {
            CompactMusicView(closed: model.closedSize).transition(.opacity)
        } else if Prefs.bool(Prefs.idleFace) && model.hovering {
            IdleFace().frame(height: model.closedSize.height).transition(.opacity)
        }
    }
}

// MARK: - Closed: music

struct CompactMusicView: View {
    @ObservedObject var music = MusicModel.shared
    let closed: CGSize
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ArtworkView(size: closed.height - 8, radius: 6)
                    .shadow(color: music.artworkColor.opacity(music.isPlaying ? 0.6 : 0), radius: 6)
                Spacer()
                MusicWaves(playing: music.isPlaying, color: music.artworkColor, bars: 5)
                    .frame(width: Prefs.string(Prefs.waveStyle) == "dance" ? (Prefs.string(Prefs.dancer) == "both" ? 40 : 22) : 24,
                           height: Prefs.string(Prefs.waveStyle) == "dance" ? closed.height - 4 : closed.height * 0.5)
            }
            .frame(height: closed.height)
            if music.showsLyricLine {
                TimelineView(.periodic(from: .now, by: 0.4)) { tl in
                    Text(music.currentLyric(at: tl.date) ?? "♪")
                        .font(.system(size: 11.5, weight: .medium)).foregroundStyle(music.artworkColor)
                        .lineLimit(1).frame(maxWidth: .infinity).padding(.horizontal, 10)
                        .contentTransition(.opacity)
                        .animation(.easeOut(duration: 0.25), value: music.currentLyric(at: tl.date))
                }
                .frame(height: 20)
            }
        }
    }
}

struct ArtworkView: View {
    @ObservedObject var music = MusicModel.shared
    var size: CGFloat
    var radius: CGFloat
    var body: some View {
        ZStack {
            if let a = music.artwork {
                Image(nsImage: a).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [music.artworkColor.opacity(0.9), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note").font(.system(size: size * 0.4, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .id(music.title)
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Peeks (live activities)

struct PeekView: View {
    let peek: Peek
    let closed: CGSize
    var body: some View {
        switch peek {
        case .hud(let k, let v, let muted): HUDPeek(kind: k, value: v, muted: muted, closed: closed)
        case .device(let e): DevicePeek(event: e, closed: closed)
        case .power(let e): PowerPeek(event: e, closed: closed)
        case .track: TrackPeek(closed: closed)
        case .download(let name, let done): DownloadPeek(name: name, done: done, closed: closed)
        case .hello: HelloPeek(closed: closed)
        case .notification(let t, let b, let alarm): NotificationPeek(title: t, bodyText: b, alarm: alarm, closed: closed)
        }
    }
}

/// Lays content out on both sides of the camera housing, with optional text underneath.
struct SidesLayout<L: View, R: View, B: View>: View {
    let closed: CGSize
    @ViewBuilder var left: L
    @ViewBuilder var right: R
    @ViewBuilder var bottom: B
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                left.frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: closed.width - 20)
                right.frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: closed.height)
            bottom
        }
    }
}

struct HUDPeek: View {
    let kind: HUDKind; let value: Double; let muted: Bool; let closed: CGSize
    @AppStorage(Prefs.hudInline) private var inline = false
    @AppStorage(Prefs.hudPercent) private var percent = true
    var body: some View {
        if inline {
            SidesLayout(closed: closed) {
                icon
            } right: {
                HUDBar(value: muted ? 0 : value).frame(width: 84, height: 5)
            } bottom: { EmptyView() }
        } else {
            SidesLayout(closed: closed) {
                icon
            } right: {
                if percent { Text("\(Int((muted ? 0 : value) * 100))%").font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit().contentTransition(.numericText()).fixedSize() }
            } bottom: {
                HUDBar(value: muted ? 0 : value).frame(height: 6).padding(.horizontal, 14)
            }
        }
    }
    private var icon: some View {
        Image(systemName: kind.symbol(for: value, muted: muted))
            .font(.system(size: 14, weight: .semibold))
            .contentTransition(.symbolEffect(.replace))
            .foregroundStyle(.white)
            .fixedSize()
            .frame(minWidth: 26)
    }
}

struct HUDBar: View {
    var value: Double
    @AppStorage(Prefs.hudGradient) private var gradient = true
    @AppStorage(Prefs.hudAccent) private var accent = true
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.14))
                Capsule()
                    .fill(gradient ? AnyShapeStyle(LinearGradient(colors: [(accent ? Color.sentraAccent : .white).opacity(0.7), accent ? .sentraAccent : .white],
                                                                startPoint: .leading, endPoint: .trailing))
                                   : AnyShapeStyle(accent ? Color.sentraAccent : .white))
                    .frame(width: max(0, g.size.width * value))
                    .shadow(color: (accent ? Color.sentraAccent : .white).opacity(0.6), radius: 4)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: value)
    }
}

/// NEW: Bluetooth device pairing animation. The device symbol spins for ~2 seconds, then the battery appears.
struct DevicePeek: View {
    let event: DeviceEvent; let closed: CGSize
    @State private var spin = 0.0
    @State private var settled = false
    var body: some View {
        SidesLayout(closed: closed) {
            ZStack {
                Circle().stroke(Color.sentraAccent.opacity(settled ? 0 : 0.6), lineWidth: 1.5)
                    .scaleEffect(settled ? 1.6 : 0.8).opacity(settled ? 0 : 1)
                Image(systemName: event.kind.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(event.connected ? .white : .white.opacity(0.5))
                    .rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0))
            }.frame(width: 24, height: 24)
        } right: {
            if let b = event.battery, settled {
                BatteryRing(level: b, charging: event.charging).frame(width: 22, height: 22).transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: event.connected ? "dot.radiowaves.right" : "xmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(event.connected ? Color.sentraAccent : .white.opacity(0.5))
                    .symbolEffect(.variableColor.iterative, isActive: event.connected && !settled)
            }
        } bottom: {
            HStack(spacing: 6) {
                Text(event.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text(status).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.6)).contentTransition(.numericText())
            }
            .padding(.bottom, 4)
        }
        .onAppear {
            guard event.connected else { settled = true; return }
            withAnimation(.easeInOut(duration: 2)) { spin = 720 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { settled = true } }
        }
    }
    private var status: String {
        guard event.connected else { return "Disconnected" }
        guard settled else { return "Connecting…" }
        if let l = event.left, let r = event.right { return "L \(l)%  R \(r)%" + (event.caseLevel.map { "  Case \($0)%" } ?? "") }
        if let b = event.battery { return "\(b)%" + (event.charging ? " · Charging" : "") }
        return "Connected"
    }
}

struct BatteryRing: View {
    let level: Int; var charging = false
    var body: some View {
        let c: Color = level <= 20 ? .red : level <= 40 ? .orange : .green
        ZStack {
            Circle().stroke(.white.opacity(0.15), lineWidth: 2.5)
            Circle().trim(from: 0, to: CGFloat(level) / 100).stroke(c, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90))
            if charging { Image(systemName: "bolt.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(c) }
            else { Text("\(level)").font(.system(size: 7.5, weight: .bold, design: .rounded)) }
        }
    }
}

struct PowerPeek: View {
    let event: PowerEvent; let closed: CGSize
    @ObservedObject var power = PowerMonitor.shared
    var body: some View {
        SidesLayout(closed: closed) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
        } right: {
            HStack(spacing: 5) {
                Text("\(power.level)%").font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                if Prefs.bool(Prefs.chargingAnimation), case .pluggedIn = event { ChargingBattery(level: power.level).frame(width: 30, height: 14) }
                else { BatteryIcon(level: power.level, charging: power.onAC, color: color) }
            }
        } bottom: { EmptyView() }
    }
    private var label: String {
        switch event { case .pluggedIn: return "Charging"; case .unplugged: return "On Battery"; case .low: return "Low Battery"; case .full: return "Fully Charged" }
    }
    private var color: Color {
        switch event { case .low: return .red; case .unplugged: return .white; default: return .green }
    }
}

struct BatteryIcon: View {
    let level: Int; let charging: Bool; var color: Color = .green
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.5), lineWidth: 1).frame(width: 24, height: 12)
            RoundedRectangle(cornerRadius: 2).fill(level <= 20 && !charging ? .red : color).frame(width: max(2, 20 * CGFloat(level) / 100), height: 8).padding(.leading, 2)
            if charging { Image(systemName: "bolt.fill").font(.system(size: 8, weight: .heavy)).foregroundStyle(.white).frame(width: 24) }
        }
    }
}

struct TrackPeek: View {
    let closed: CGSize
    @ObservedObject var music = MusicModel.shared
    @AppStorage(Prefs.sneakPeekStyle) private var style = "standard"
    var body: some View {
        SidesLayout(closed: closed) {
            ArtworkView(size: closed.height - 10, radius: 5)
        } right: {
            if style == "inline" {
                Text(music.title).font(.system(size: 11, weight: .semibold)).lineLimit(1).frame(maxWidth: 140, alignment: .trailing)
            } else {
                MusicWaves(playing: music.isPlaying, color: music.artworkColor).frame(width: 22, height: closed.height * 0.42)
            }
        } bottom: {
            if style != "inline" {
                MarqueeText(text: music.artist.isEmpty ? music.title : "\(music.title) · \(music.artist)")
                    .font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white.opacity(0.85)).padding(.horizontal, 12).padding(.bottom, 6)
            }
        }
    }
}

struct NotificationPeek: View {
    let title: String; let bodyText: String; let alarm: Bool; let closed: CGSize
    @State private var ring = false
    var body: some View {
        SidesLayout(closed: closed) {
            Image(systemName: alarm ? "alarm.fill" : "bell.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(alarm ? .orange : .sentraAccent)
                .rotationEffect(.degrees(ring ? 14 : -14), anchor: .top)
                .animation(.easeInOut(duration: 0.12).repeatCount(alarm ? 14 : 6, autoreverses: true), value: ring)
                .onAppear { ring = true }
        } right: {
            Text(alarm ? "Alarm" : "Now").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.55))
        } bottom: {
            VStack(spacing: 1) {
                Text(title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                if !bodyText.isEmpty { Text(bodyText).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7)).lineLimit(1) }
            }
            .padding(.horizontal, 14).padding(.bottom, 6)
        }
        .onTapGesture { NotchModel.shared.clearPeek() }
    }
}

struct DownloadPeek: View {
    let name: String; let done: Bool; let closed: CGSize
    var body: some View {
        SidesLayout(closed: closed) {
            Image(systemName: done ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(done ? .green : .sentraAccent)
                .symbolEffect(.pulse, isActive: !done)
        } right: {
            Text(done ? "Done" : name).font(.system(size: 11, weight: .medium)).lineLimit(1).frame(maxWidth: 110, alignment: .trailing)
        } bottom: { EmptyView() }
    }
}

struct HelloPeek: View {
    let closed: CGSize
    @State private var show = false
    var body: some View {
        VStack {
            Spacer(minLength: closed.height - 4)
            Text("Sentra Notch")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [Color(hex: "#7C9CFF")!, Color(hex: "#FF8FB1")!, Color(hex: "#5FD9B6")!], startPoint: .leading, endPoint: .trailing))
                .opacity(show ? 1 : 0).scaleEffect(show ? 1 : 0.8).blur(radius: show ? 0 : 6)
                .padding(.bottom, 5)
        }
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.15)) { show = true } }
    }
}

struct IdleFace: View {
    @State private var blink = false
    var body: some View {
        HStack {
            Spacer()
            HStack(spacing: 5) {
                ForEach(0..<2, id: \.self) { _ in Capsule().fill(.white).frame(width: 4, height: blink ? 1 : 6) }
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.08)) { blink = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { withAnimation(.easeInOut(duration: 0.08)) { blink = false } }
            }
        }
    }
}

struct MarqueeText: View {
    let text: String
    @State private var offset: CGFloat = 0
    @State private var textW: CGFloat = 0
    @State private var boxW: CGFloat = 0
    var body: some View {
        GeometryReader { g in
            Text(text).fixedSize().background(GeometryReader { t in Color.clear.onAppear { textW = t.size.width; boxW = g.size.width; run() } })
                .offset(x: offset)
                .frame(width: g.size.width, alignment: textW > g.size.width ? .leading : .center)
        }
        .frame(height: 16)
        .clipped()
        .id(text)
    }
    private func run() {
        guard textW > boxW else { return }
        offset = 0
        withAnimation(.linear(duration: Double(textW - boxW) / 30).delay(1).repeatForever(autoreverses: true)) { offset = boxW - textW }
    }
}
