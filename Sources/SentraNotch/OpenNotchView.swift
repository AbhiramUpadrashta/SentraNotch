//
//  OpenNotchView.swift — Sentra Notch
//  The expanded notch: header with tabs, then music player, calendar and mirror — or the shelf.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import SwiftUI

struct OpenNotchView: View {
    @EnvironmentObject var model: NotchModel
    var body: some View {
        VStack(spacing: 8) {
            Header()
            Group {
                if model.tab == .shelf && Prefs.bool(Prefs.shelf) { ShelfView() }
                else { HomeView() }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
        .animation(.notchPeek, value: model.tab)
    }
}

struct Header: View {
    @EnvironmentObject var model: NotchModel
    @ObservedObject var power = PowerMonitor.shared
    @AppStorage(Prefs.shelf) private var shelf = true
    @AppStorage(Prefs.settingsInNotch) private var settingsButton = true
    @AppStorage(Prefs.batteryIndicator) private var battery = true
    @AppStorage(Prefs.batteryPercent) private var percent = true

    var body: some View {
        HStack(spacing: 6) {
            if shelf {
                tab(.home, "house.fill")
                tab(.shelf, "tray.fill")
            }
            Spacer()
            if case .hud(let k, let v, let m)? = model.openHUD {
                HStack(spacing: 6) {
                    Image(systemName: k.symbol(for: v, muted: m)).font(.system(size: 11, weight: .semibold))
                    HUDBar(value: m ? 0 : v).frame(width: 70, height: 4)
                }.transition(.opacity.combined(with: .scale))
            }
            Color.clear.frame(width: model.closedSize.width - 30, height: 1)
            Spacer()
            if Prefs.bool(Prefs.showMirror) {
                Button { withAnimation(.notchPeek) { model.cameraOn.toggle() } } label: {
                    Image(systemName: model.cameraOn ? "camera.fill" : "camera").font(.system(size: 11.5)).frame(width: 26, height: 22)
                        .foregroundStyle(model.cameraOn ? Color.sentraAccent : .white)
                }.buttonStyle(HoverButtonStyle()).help("Mirror")
            }
            if settingsButton {
                Button { SettingsWindow.show() } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 12)).frame(width: 26, height: 22)
                }.buttonStyle(HoverButtonStyle())
            }
            if battery && power.hasBattery {
                HStack(spacing: 4) {
                    if percent { Text("\(power.level)%").font(.system(size: 11, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(.white.opacity(0.8)) }
                    BatteryIcon(level: power.level, charging: power.onAC)
                }
                .help(power.minutesLeft.map { "\($0 / 60)h \($0 % 60)m left" } ?? "")
            }
        }
        .frame(height: max(24, model.closedSize.height - 4))
    }

    private func tab(_ t: NotchTab, _ icon: String) -> some View {
        Button { withAnimation(.notchPeek) { model.tab = t } } label: {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                .frame(width: 30, height: 22)
                .background(Capsule().fill(model.tab == t ? Color.white.opacity(0.14) : .clear))
                .foregroundStyle(model.tab == t ? .white : .white.opacity(0.5))
        }.buttonStyle(.plain)
    }
}

struct HoverButtonStyle: ButtonStyle {
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(hover ? 1 : 0.75))
            .background(Capsule().fill(.white.opacity(hover ? 0.12 : 0)))
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .onHover { hover = $0 }
    }
}

struct HomeView: View {
    @ObservedObject var music = MusicModel.shared
    @AppStorage(Prefs.showCalendar) private var calendar = true
    @EnvironmentObject var model: NotchModel
    var body: some View {
        HStack(spacing: 14) {
            if music.hasMedia { PlayerView() } else { NothingPlaying() }
            if calendar { CalendarPanel().frame(width: 168) }
            if model.cameraOn { MirrorPanel().transition(.scale.combined(with: .opacity)) }
        }
    }
}

struct NothingPlaying: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 13).fill(.white.opacity(0.06)).frame(width: 76, height: 76)
                .overlay(Image(systemName: "music.note").font(.system(size: 30)).foregroundStyle(.white.opacity(0.3)))
            VStack(alignment: .leading, spacing: 4) {
                Text("Nothing playing").font(.system(size: 14, weight: .semibold))
                Text("Play music in any app — Spotify, Apple Music, YouTube in your browser…").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity)
    }
}

struct PlayerView: View {
    @ObservedObject var music = MusicModel.shared
    @AppStorage(Prefs.glow) private var glow = true
    @AppStorage(Prefs.tintPlayer) private var tint = true
    @AppStorage(Prefs.sliderColor) private var sliderColor = "album"
    @AppStorage(Prefs.controlSlots) private var slots = "shuffle,previous,play,next,repeat"
    @AppStorage(Prefs.showShuffleRepeat) private var shuffleRepeat = true
    @State private var dragValue: Double?

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                if glow, let a = music.artwork {
                    Image(nsImage: a).resizable().scaledToFill().frame(width: 76, height: 76).blur(radius: 20).opacity(music.isPlaying ? 0.8 : 0.35)
                }
                ArtworkView(size: 76, radius: 13)
                    .scaleEffect(music.isPlaying ? 1 : 0.9)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: music.isPlaying)
                    .onTapGesture { music.openPlayerApp() }
                if let icon = music.appIcon {
                    Image(nsImage: icon).resizable().frame(width: 24, height: 24).offset(x: 6, y: 6)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        MarqueeText(text: music.title).font(.system(size: 14, weight: .semibold))
                        Text(music.artist).font(.system(size: 12)).foregroundStyle(tint ? music.artworkColor : .white.opacity(0.6)).lineLimit(1)
                    }
                    if Prefs.string(Prefs.waveStyle) == "dance" {
                        Dancers(playing: music.isPlaying, color: music.artworkColor, who: Prefs.string(Prefs.dancer))
                            .frame(width: Prefs.string(Prefs.dancer) == "both" ? 96 : 60, height: 56)
                    } else {
                        MusicWaves(playing: music.isPlaying, color: music.artworkColor, bars: 5).frame(width: 30, height: 18)
                    }
                }
                TimelineView(.periodic(from: .now, by: 0.5)) { tl in
                    VStack(alignment: .leading, spacing: 2) {
                        if Prefs.bool(Prefs.lyrics), let line = music.currentLyric(at: tl.date) {
                            Text(line).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                                .id(line).transition(.push(from: .bottom))
                        }
                        scrubber(now: tl.date)
                    }
                    .animation(.easeOut(duration: 0.25), value: music.currentLyric(at: tl.date))
                }
                HStack(spacing: 4) {
                    ForEach(slots.split(separator: ",").map(String.init), id: \.self) { slot in control(slot) }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var sliderTint: Color {
        switch sliderColor { case "white": return .white; case "accent": return .sentraAccent; default: return music.artworkColor }
    }

    private func scrubber(now: Date) -> some View {
        let dur = max(music.duration, 1)
        let value = dragValue ?? music.elapsed(at: now)
        return VStack(spacing: 1) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15)).frame(height: dragValue == nil ? 4 : 7)
                    Capsule().fill(sliderTint).frame(width: g.size.width * value / dur, height: dragValue == nil ? 4 : 7)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { dragValue = min(max(0, $0.location.x / g.size.width), 1) * dur }
                    .onEnded { _ in if let v = dragValue { music.seek(to: v) }; dragValue = nil })
                .animation(.spring(response: 0.25), value: dragValue == nil)
            }.frame(height: 10)
            HStack {
                Text(Self.time(value)); Spacer(); Text("-" + Self.time(max(0, dur - value)))
            }.font(.system(size: 9.5, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(.white.opacity(0.45))
        }
    }

    static func time(_ s: Double) -> String { String(format: "%d:%02d", Int(s) / 60, Int(s) % 60) }

    @ViewBuilder private func control(_ slot: String) -> some View {
        switch slot {
        case "shuffle" where shuffleRepeat:
            ctl("shuffle", size: 12, on: music.shuffle) { music.toggleShuffle() }
        case "repeat" where shuffleRepeat:
            ctl(music.repeatMode == 1 ? "repeat.1" : "repeat", size: 12, on: music.repeatMode != 0) { music.cycleRepeat() }
        case "previous": ctl("backward.fill", size: 15) { music.previous() }
        case "next": ctl("forward.fill", size: 15) { music.next() }
        case "play":
            ctl(music.isPlaying ? "pause.fill" : "play.fill", size: 22) { music.togglePlay() }
        case "airplay": ctl("airplayaudio", size: 13) { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!) }
        default: EmptyView()
        }
    }

    private func ctl(_ icon: String, size: CGFloat, on: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button { action(); Haptics.tap() } label: {
            Image(systemName: icon).font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(on ? sliderTint : .white)
                .frame(width: 34, height: 28)
        }.buttonStyle(HoverButtonStyle())
    }
}

struct CalendarPanel: View {
    @ObservedObject var cal = CalendarModel.shared
    @AppStorage(Prefs.fullEventTitles) private var fullTitles = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(cal.day.formatted(.dateTime.day())).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(Color.sentraAccent)
                VStack(alignment: .leading, spacing: 0) {
                    Text(cal.day.formatted(.dateTime.weekday(.wide))).font(.system(size: 11, weight: .semibold))
                    Text(cal.day.formatted(.dateTime.month(.wide))).font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                dayButton("chevron.left", -1)
                dayButton("chevron.right", 1)
            }
            if !cal.eventsAllowed {
                Button("Show my calendar") { Task { await cal.requestAccess() } }
                    .font(.system(size: 11, weight: .medium)).buttonStyle(.borderless).foregroundStyle(Color.sentraAccent)
                Spacer(minLength: 0)
            } else if cal.items.isEmpty {
                Spacer(minLength: 0)
                Label("Nothing planned", systemImage: "sparkles").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                Spacer(minLength: 0)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) { ForEach(cal.items) { row($0) } }
                }
            }
        }
    }

    private func dayButton(_ icon: String, _ delta: Int) -> some View {
        Button { cal.select(Calendar.current.date(byAdding: .day, value: delta, to: cal.day)!) } label: {
            Image(systemName: icon).font(.system(size: 9, weight: .bold)).frame(width: 18, height: 18)
                .background(Circle().fill(.white.opacity(0.08)))
        }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.7))
    }

    private func row(_ it: AgendaItem) -> some View {
        let now = Date()
        let live = !it.isReminder && (it.start ?? .distantFuture) <= now && (it.end ?? .distantPast) > now
        return HStack(spacing: 6) {
            if it.isReminder {
                Button { cal.complete(it) } label: {
                    Image(systemName: it.done ? "checkmark.circle.fill" : "circle").font(.system(size: 10)).foregroundStyle(it.color)
                }.buttonStyle(.plain)
            } else {
                Circle().fill(it.color).frame(width: 6, height: 6)
            }
            Text(it.title).font(.system(size: 10.5, weight: .medium)).lineLimit(fullTitles ? 2 : 1)
            Spacer(minLength: 2)
            if let u = it.url {
                Button { NSWorkspace.shared.open(u) } label: { Image(systemName: "video.fill").font(.system(size: 8.5)) }
                    .buttonStyle(.plain).foregroundStyle(Color.sentraAccent)
            }
            Text(it.allDay ? (it.isReminder ? "To do" : "All day") : (it.start.map { $0.formatted(date: .omitted, time: .shortened) } ?? ""))
                .font(.system(size: 9, weight: .semibold, design: .rounded)).monospacedDigit()
                .padding(.horizontal, 5).padding(.vertical, 1.5)
                .background(Capsule().fill(live ? it.color.opacity(0.35) : .white.opacity(0.08)))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.vertical, 3).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(live ? it.color.opacity(0.12) : .white.opacity(0.03)))
    }
}

struct MirrorPanel: View {
    @AppStorage(Prefs.mirrorCircle) private var circle = false
    @State private var allowed = MirrorCamera.allowed
    var body: some View {
        Group {
            if allowed {
                CameraPreview().clipShape(circle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 14, style: .continuous)))
            } else {
                Button { MirrorCamera.request { allowed = $0 } } label: {
                    VStack(spacing: 4) { Image(systemName: "camera.fill"); Text("Mirror").font(.system(size: 10)) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)))
                }.buttonStyle(.plain)
            }
        }
        .frame(width: 96, height: 96)
    }
}
