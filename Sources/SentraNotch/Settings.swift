//
//  Settings.swift — Sentra Notch
//  The settings window.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import SwiftUI

@MainActor
enum SettingsWindow {
    private static var window: NSWindow?
    static func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
                             styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            w.title = "Sentra Notch Settings"
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView())
            w.center()
            window = w
        }
        NotchModel.shared.close()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "General", appearance = "Appearance", media = "Media", hud = "HUD", devices = "Devices & Battery"
    case calendar = "Calendar", reminders = "Reminders", shelf = "Shelf", shortcuts = "Shortcuts", about = "About"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintpalette.fill"
        case .media: return "play.circle.fill"
        case .hud: return "dial.medium.fill"
        case .devices: return "headphones"
        case .calendar: return "calendar"
        case .reminders: return "drop.fill"
        case .shelf: return "tray.fill"
        case .shortcuts: return "command"
        case .about: return "info.circle.fill"
        }
    }
}

struct SettingsView: View {
    @State private var page: SettingsPage = .general
    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: $page) { p in
                Label(p.rawValue, systemImage: p.icon).tag(p)
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            Form { pageView }.formStyle(.grouped).navigationTitle(page.rawValue)
        }
        .frame(minWidth: 720, minHeight: 560)
        .onChange(of: page) { _, _ in }
    }

    @ViewBuilder private var pageView: some View {
        switch page {
        case .general: GeneralPage()
        case .appearance: AppearancePage()
        case .media: MediaPage()
        case .hud: HUDPage()
        case .devices: DevicesPage()
        case .calendar: CalendarPage()
        case .reminders: RemindersPage()
        case .shelf: ShelfPage()
        case .shortcuts: ShortcutsPage()
        case .about: AboutPage()
        }
    }
}

@MainActor private func rebuild() { NotchController.shared.refreshSettings() }

struct GeneralPage: View {
    @AppStorage(Prefs.showMenuBarIcon) var menuBar = true
    @AppStorage(Prefs.allDisplays) var allDisplays = false
    @AppStorage(Prefs.followMouseDisplay) var followMouse = true
    @AppStorage(Prefs.openOnHover) var hover = true
    @AppStorage(Prefs.hoverDelay) var delay = 0.25
    @AppStorage(Prefs.extendHoverArea) var extend = false
    @AppStorage(Prefs.haptics) var haptics = true
    @AppStorage(Prefs.heightMode) var heightMode = "notch"
    @AppStorage(Prefs.customHeight) var customHeight = 32.0
    @AppStorage(Prefs.nonNotchHeight) var nonNotch = 30.0
    @AppStorage(Prefs.hideInFullscreen) var fullscreen = "unlessPlaying"
    @AppStorage(Prefs.hideFromRecording) var hideRec = false
    @AppStorage(Prefs.gestures) var gestures = true
    @AppStorage(Prefs.closeGesture) var closeGesture = true
    @AppStorage(Prefs.gestureSensitivity) var sensitivity = 0.5
    @AppStorage(Prefs.optionClickAction) var optionClick = "settings"
    @AppStorage(Prefs.helloAnimation) var hello = true
    @State private var login = LoginItem.enabled

    var body: some View {
        Section("System") {
            Toggle("Launch at login", isOn: $login).onChange(of: login) { _, v in LoginItem.set(v) }
            Toggle("Show menu bar icon", isOn: $menuBar)
            Toggle("Play the hello animation on start", isOn: $hello)
            Toggle("Haptic feedback", isOn: $haptics)
            HStack {
                Button("Restart Sentra Notch") { (NSApp.delegate as? AppDelegate)?.restart() }
                Spacer()
                Button("Quit Sentra Notch", role: .destructive) { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
        }
        Section("Displays") {
            Toggle("Show on all displays", isOn: $allDisplays).onChange(of: allDisplays) { _, _ in rebuild() }
            Toggle("Move to the display with the pointer", isOn: $followMouse).disabled(!allDisplays)
            Picker("Notch height", selection: $heightMode) {
                Text("Match the real notch").tag("notch"); Text("Match the menu bar").tag("menubar"); Text("Custom").tag("custom")
            }.onChange(of: heightMode) { _, _ in rebuild() }
            if heightMode == "custom" { Slider(value: $customHeight, in: 20...44, step: 1) { Text("Height \(Int(customHeight)) pt") }.onChange(of: customHeight) { _, _ in rebuild() } }
            Slider(value: $nonNotch, in: 20...44, step: 1) { Text("Displays without a notch: \(Int(nonNotch)) pt") }.onChange(of: nonNotch) { _, _ in rebuild() }
            Picker("In full screen apps", selection: $fullscreen) {
                Text("Always show").tag("never"); Text("Hide unless music is playing").tag("unlessPlaying"); Text("Always hide").tag("always")
            }
            Toggle("Hide from screenshots & screen recordings", isOn: $hideRec).onChange(of: hideRec) { _, _ in rebuild() }
        }
        Section("Opening") {
            Toggle("Open on hover", isOn: $hover)
            Slider(value: $delay, in: 0...1, step: 0.05) { Text("Hover delay \(String(format: "%.2f", delay)) s") }.disabled(!hover)
            Toggle("Bigger hover area", isOn: $extend)
            Picker("⌥-click on the notch", selection: $optionClick) {
                Text("Open settings").tag("settings"); Text("Open the shelf").tag("shelf"); Text("Toggle the mirror").tag("mirror"); Text("Nothing special").tag("none")
            }
        }
        Section("Gestures") {
            Toggle("Swipe down on the notch to open", isOn: $gestures)
            Toggle("Swipe up to close", isOn: $closeGesture).disabled(!gestures)
            Slider(value: $sensitivity, in: 0...1) { Text("Sensitivity") }.disabled(!gestures)
            Text("Swipe left or right on the open notch to change tracks.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct AppearancePage: View {
    @AppStorage(Prefs.theme) var theme = "midnight"
    @AppStorage(Prefs.accent) var accent = "#7C9CFF"
    @AppStorage(Prefs.shadow) var shadow = true
    @AppStorage(Prefs.glow) var glow = true
    @AppStorage(Prefs.cornerScaling) var corners = true
    @AppStorage(Prefs.idleFace) var face = true
    @AppStorage(Prefs.settingsInNotch) var gear = true
    @AppStorage(Prefs.showMirror) var mirror = true
    @AppStorage(Prefs.mirrorCircle) var circle = false
    let swatches = ["#7C9CFF", "#FF8FB1", "#5FD9B6", "#FFB36B", "#A78BFA", "#F5F5F7"]

    var body: some View {
        Section("Theme") {
            Picker("Notch theme", selection: $theme) {
                Text("Notch black").tag("midnight"); Text("Glass").tag("glass"); Text("Aurora glow").tag("aurora")
            }.pickerStyle(.segmented)
            HStack {
                Text("Accent colour")
                Spacer()
                ForEach(swatches, id: \.self) { s in
                    Circle().fill(Color(hex: s)!).frame(width: 20, height: 20)
                        .overlay(Circle().stroke(.primary, lineWidth: accent == s ? 2 : 0).padding(-3))
                        .onTapGesture { accent = s }
                }
                ColorPicker("", selection: Binding(get: { Color(hex: accent) ?? .blue }, set: { accent = $0.hexString })).labelsHidden()
            }
        }
        Section("Look") {
            Toggle("Shadow under the open notch", isOn: $shadow)
            Toggle("Album art glow", isOn: $glow)
            Toggle("Rounder corners when open", isOn: $corners)
            Toggle("Show a little face when idle", isOn: $face)
            Toggle("Settings button in the notch", isOn: $gear)
        }
        Section("Mirror") {
            Toggle("Camera button in the open notch (opens only when you click it)", isOn: $mirror)
            Toggle("Circle shape", isOn: $circle).disabled(!mirror)
        }
    }
}

struct MediaPage: View {
    @AppStorage(Prefs.mediaSource) var source = "auto"
    @AppStorage(Prefs.waveStyle) var waves = "waves"
    @AppStorage(Prefs.colorfulWaves) var colorful = true
    @AppStorage(Prefs.dancer) var dancer = "both"
    @AppStorage(Prefs.tintPlayer) var tint = true
    @AppStorage(Prefs.sliderColor) var slider = "album"
    @AppStorage(Prefs.sneakPeek) var peek = true
    @AppStorage(Prefs.sneakPeekStyle) var peekStyle = "standard"
    @AppStorage(Prefs.sneakPeekSeconds) var seconds = 3.5
    @AppStorage(Prefs.showShuffleRepeat) var shuffle = true
    @AppStorage(Prefs.lyrics) var lyrics = false
    @AppStorage(Prefs.lyricsClosed) var lyricsClosed = true
    @AppStorage(Prefs.hideWhenPaused) var hidePaused = false
    @AppStorage(Prefs.controlSlots) var slots = "shuffle,previous,play,next,repeat"

    var body: some View {
        Section("Source") {
            Picker("Music from", selection: $source) {
                Text("Any app (recommended)").tag("auto"); Text("Apple Music").tag("music"); Text("Spotify").tag("spotify")
            }.onChange(of: source) { _, _ in MusicModel.shared.start() }
        }
        Section("Visualizer") {
            Picker("Animation", selection: $waves) {
                Text("Bars").tag("bars"); Text("Waves").tag("waves"); Text("Pulse").tag("pulse"); Text("Dance").tag("dance"); Text("Off").tag("off")
            }.pickerStyle(.segmented)
            if waves == "dance" {
                Picker("Dancers", selection: $dancer) { Text("Boy").tag("boy"); Text("Girl").tag("girl"); Text("Both").tag("both") }.pickerStyle(.segmented)
            }
            Toggle("Use album colours", isOn: $colorful)
            HStack { Text("Preview"); Spacer(); MusicWaves(playing: true, color: .sentraAccent, bars: 5).frame(width: waves == "dance" ? 70 : 40, height: waves == "dance" ? 34 : 22) }
        }
        Section("Player") {
            Toggle("Tint the player with album colours", isOn: $tint)
            Picker("Progress bar colour", selection: $slider) { Text("Album").tag("album"); Text("Accent").tag("accent"); Text("White").tag("white") }
            Toggle("Shuffle & repeat buttons", isOn: $shuffle)
            Picker("Buttons", selection: $slots) {
                Text("Shuffle · ◀◀ · ▶ · ▶▶ · Repeat").tag("shuffle,previous,play,next,repeat")
                Text("◀◀ · ▶ · ▶▶").tag("previous,play,next")
                Text("◀◀ · ▶ · ▶▶ · Output").tag("previous,play,next,airplay")
            }
            Toggle("Synced lyrics (from lrclib.net)", isOn: $lyrics)
            Toggle("Show the current lyric under the closed notch", isOn: $lyricsClosed).disabled(!lyrics)
            Toggle("Hide music from the closed notch when paused", isOn: $hidePaused)
            Text("When music stops, the notch goes back to normal after 15 seconds. The last song stays in the open notch so you can press play again.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Sneak peek") {
            Toggle("Show the song when it changes", isOn: $peek)
            Picker("Style", selection: $peekStyle) { Text("Below the notch").tag("standard"); Text("Beside the notch").tag("inline") }.disabled(!peek)
            Slider(value: $seconds, in: 3...4, step: 0.5) { Text("Show for \(String(format: "%.1f", seconds)) s") }.disabled(!peek)
        }
    }
}

struct HUDPage: View {
    @AppStorage(Prefs.hudReplace) var replace = false
    @AppStorage(Prefs.hudInline) var inline = false
    @AppStorage(Prefs.hudGradient) var gradient = true
    @AppStorage(Prefs.hudAccent) var accent = true
    @AppStorage(Prefs.hudPercent) var percent = true
    @AppStorage(Prefs.hudInOpenNotch) var openNotch = true
    var body: some View {
        Section("Volume, brightness & keyboard light") {
            Toggle("Replace the macOS HUD", isOn: $replace).onChange(of: replace) { _, _ in SystemHUD.shared.applyReplacement() }
            if replace && !SystemHUD.accessibilityGranted {
                Button("Grant Accessibility permission") { SystemHUD.askAccessibility() }
            }
            Text("Changes always show in the notch. Replacing hides Apple's own pop-up and needs Accessibility. Hold ⇧⌥ for fine steps.")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Style", selection: $inline) { Text("Below the notch").tag(false); Text("Beside the notch").tag(true) }
            Toggle("Show percentage", isOn: $percent)
            Toggle("Gradient bar", isOn: $gradient)
            Toggle("Use accent colour", isOn: $accent)
            Toggle("Show in the open notch too", isOn: $openNotch)
            HUDBar(value: 0.62).frame(height: 6)
        }
    }
}

struct DevicesPage: View {
    @AppStorage(Prefs.bluetoothActivity) var bt = true
    @AppStorage(Prefs.bluetoothDisconnect) var disconnect = true
    @AppStorage(Prefs.bluetoothSeconds) var seconds = 3.5
    @AppStorage(Prefs.batteryIndicator) var battery = true
    @AppStorage(Prefs.batteryPercent) var percent = true
    @AppStorage(Prefs.powerNotifications) var power = true
    @AppStorage(Prefs.chargingAnimation) var chargeAnim = true
    @AppStorage(Prefs.chargingLive) var chargeLive = true
    @AppStorage(Prefs.lowBatteryAlert) var low = true
    @AppStorage(Prefs.downloads) var downloads = true
    @AppStorage(Prefs.notifications) var notifs = true
    var body: some View {
        Section("Bluetooth (new in Sentra)") {
            Toggle("Pairing animation with battery", isOn: $bt)
            Toggle("Also show when a device disconnects", isOn: $disconnect).disabled(!bt)
            Slider(value: $seconds, in: 3...4, step: 0.5) { Text("Show for \(String(format: "%.1f", seconds)) s") }.disabled(!bt)
            Text("Mouse, keyboard, trackpad, AirPods, headphones, speakers and game controllers. The icon spins for 2 seconds, then the battery appears.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Mac battery") {
            Toggle("Battery in the open notch", isOn: $battery)
            Toggle("Show percentage", isOn: $percent).disabled(!battery)
            Toggle("Plugged in / unplugged / full", isOn: $power)
            Toggle("Charging animation (power flowing into the battery)", isOn: $chargeAnim)
            Toggle("Keep it live in the notch while charging (when no music is playing)", isOn: $chargeLive)
            Toggle("Low battery warnings (20%, 10%, 5%)", isOn: $low)
        }
        Section("Notifications & alarms (new in Sentra)") {
            Toggle("Show notifications and alarms in the notch", isOn: $notifs).onChange(of: notifs) { _, _ in NotificationWatcher.shared.start() }
            if notifs && !SystemHUD.accessibilityGranted {
                Button("Grant Accessibility permission") { SystemHUD.askAccessibility() }
            }
            Text("Messages, Mail, Calendar, Clock alarms and timers… the notch rings and shows the title for 4 seconds (6 for alarms). Needs Accessibility.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Downloads") {
            Toggle("Show downloads in progress", isOn: $downloads).onChange(of: downloads) { _, v in v ? DownloadMonitor.shared.start() : DownloadMonitor.shared.stop() }
        }
    }
}

struct CalendarPage: View {
    @AppStorage(Prefs.showCalendar) var show = true
    @AppStorage(Prefs.hideAllDay) var allDay = false
    @AppStorage(Prefs.fullEventTitles) var full = false
    @AppStorage(Prefs.showReminders) var reminders = true
    @AppStorage(Prefs.hideDoneReminders) var hideDone = true
    @AppStorage(Prefs.hiddenCalendars) var hidden = ""
    @ObservedObject var cal = CalendarModel.shared
    var body: some View {
        Section {
            Toggle("Show the calendar", isOn: $show)
            if !cal.eventsAllowed { Button("Allow Calendar & Reminders access") { Task { await cal.requestAccess() } } }
            Toggle("Hide all-day events", isOn: $allDay).onChange(of: allDay) { _, _ in cal.reload() }
            Toggle("Show full event titles", isOn: $full)
            Toggle("Show reminders", isOn: $reminders).onChange(of: reminders) { _, _ in cal.reload() }
            Toggle("Hide completed reminders", isOn: $hideDone).disabled(!reminders)
        }
        if !cal.calendars.isEmpty {
            Section("Calendars") {
                ForEach(cal.calendars, id: \.calendarIdentifier) { c in
                    Toggle(isOn: Binding(get: { !hidden.split(separator: ",").contains(Substring(c.calendarIdentifier)) }, set: { on in
                        var set = Set(hidden.split(separator: ",").map(String.init))
                        if on { set.remove(c.calendarIdentifier) } else { set.insert(c.calendarIdentifier) }
                        hidden = set.joined(separator: ","); cal.reload()
                    })) { HStack { Circle().fill(Color(cgColor: c.cgColor)).frame(width: 9); Text(c.title) } }
                }
            }
        }
    }
}

struct ShelfPage: View {
    @AppStorage(Prefs.shelf) var shelf = true
    @AppStorage(Prefs.shelfOpensByDefault) var openDefault = true
    @AppStorage(Prefs.copyOnDrag) var copy = false
    @AppStorage(Prefs.autoRemoveShelf) var autoRemove = false
    @AppStorage(Prefs.expandedDrop) var expanded = true
    var body: some View {
        Section {
            Toggle("Enable the shelf", isOn: $shelf)
            Toggle("Open the shelf tab when it has files", isOn: $openDefault)
            Toggle("Bigger drop area around the notch", isOn: $expanded)
            Toggle("Keep a copy of dropped files", isOn: $copy)
            Toggle("Remove items after dragging them out", isOn: $autoRemove)
            Button("Clear the shelf") { ShelfModel.shared.clear() }
            Text("Drop files, images, links or text on the notch. Double-click to open, right-click for Quick Look, AirDrop and more.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct ShortcutsPage: View {
    var body: some View {
        Section("Global shortcuts") {
            ForEach(HotKeys.shared.list, id: \.id) { Text($0.label).font(.system(.body, design: .monospaced)) }
        }
        Section("Gestures") {
            Text("Hover: open · Swipe down: open · Swipe up: close · Swipe sideways: next / previous track · ⌥-click: your choice in General")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct AboutPage: View {
    @AppStorage(Prefs.autoCheckUpdates) var auto = true
    var body: some View {
        Section {
            HStack(spacing: 16) {
                AppIconView().frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sentra Notch").font(.title2.bold())
                    Text("Version \(Updater.shared.currentVersion)").foregroundStyle(.secondary)
                    Text("Powered by Bubbles Aro").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        Section("Updates") {
            Button("Check for Updates…") { Updater.shared.check(userInitiated: true) }
            Toggle("Check automatically every day", isOn: $auto)
            Button("Quit Sentra Notch", role: .destructive) { NSApp.terminate(nil) }
            Text("Updates are signed and verified before they install.").font(.caption).foregroundStyle(.secondary)
        }
        Section {
            Link("Website", destination: Links.website)
            Link("Support", destination: Links.mail)
        }
    }
}
