//
//  Prefs.swift — Sentra Notch
//  Every user setting lives here, with its default. Views read them through @AppStorage(Prefs.x).
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import SwiftUI

enum Prefs {
    // General
    static let showMenuBarIcon = "showMenuBarIcon"
    static let allDisplays = "allDisplays"
    static let followMouseDisplay = "followMouseDisplay"
    static let openOnHover = "openOnHover"
    static let hoverDelay = "hoverDelay"
    static let extendHoverArea = "extendHoverArea"
    static let haptics = "haptics"
    static let heightMode = "heightMode"                // notch | menubar | custom
    static let customHeight = "customHeight"
    static let nonNotchHeight = "nonNotchHeight"
    static let hideInFullscreen = "hideInFullscreen"    // never | always | unlessPlaying
    static let hideFromRecording = "hideFromRecording"
    static let settingsInNotch = "settingsInNotch"
    static let optionClickAction = "optionClickAction"  // settings | shelf | mirror | none
    static let gestures = "gestures"
    static let closeGesture = "closeGesture"
    static let gestureSensitivity = "gestureSensitivity"
    static let helloAnimation = "helloAnimation"
    static let autoCheckUpdates = "autoCheckUpdates"

    // Appearance / themes
    static let theme = "theme"                          // midnight | glass | aurora | oled
    static let accent = "accent"                        // hex string, "" = system
    static let shadow = "shadow"
    static let glow = "glow"                            // lighting effect behind artwork
    static let cornerScaling = "cornerScaling"
    static let idleFace = "idleFace"
    static let tileLabels = "tileLabels"
    static let showMirror = "showMirror"                // camera button in the open notch
    static let mirrorCircle = "mirrorCircle"
    static let showCalendar = "showCalendar"

    // Media
    static let mediaSource = "mediaSource"              // auto | music | spotify
    static let waveStyle = "waveStyle"                  // waves | bars | pulse | off
    static let colorfulWaves = "colorfulWaves"
    static let tintPlayer = "tintPlayer"
    static let sliderColor = "sliderColor"              // white | album | accent
    static let sneakPeek = "sneakPeek"
    static let sneakPeekStyle = "sneakPeekStyle"        // standard | inline
    static let sneakPeekSeconds = "sneakPeekSeconds"
    static let showShuffleRepeat = "showShuffleRepeat"
    static let lyrics = "lyrics"
    static let lyricsClosed = "lyricsClosed"            // show the current lyric under the closed notch
    static let controlSlots = "controlSlots"            // comma separated
    static let hideWhenPaused = "hideWhenPaused"

    // HUD
    static let hudReplace = "hudReplace"
    static let hudInline = "hudInline"
    static let hudGradient = "hudGradient"
    static let hudAccent = "hudAccent"
    static let hudPercent = "hudPercent"
    static let hudInOpenNotch = "hudInOpenNotch"

    // Devices (new in Sentra)
    static let bluetoothActivity = "bluetoothActivity"
    static let bluetoothSeconds = "bluetoothSeconds"
    static let bluetoothDisconnect = "bluetoothDisconnect"

    // Battery
    static let batteryIndicator = "batteryIndicator"
    static let batteryPercent = "batteryPercent"
    static let powerNotifications = "powerNotifications"
    static let lowBatteryAlert = "lowBatteryAlert"

    // Downloads
    static let downloads = "downloads"

    // Shelf
    static let shelf = "shelf"
    static let shelfOpensByDefault = "shelfOpensByDefault"
    static let copyOnDrag = "copyOnDrag"
    static let autoRemoveShelf = "autoRemoveShelf"
    static let expandedDrop = "expandedDrop"

    // Calendar
    static let hideAllDay = "hideAllDay"
    static let fullEventTitles = "fullEventTitles"
    static let showReminders = "showReminders"
    static let hideDoneReminders = "hideDoneReminders"
    static let hiddenCalendars = "hiddenCalendars"

    static let didOnboard = "didOnboard"
    static let lastSeenVersion = "lastSeenVersion"

    static let defaults: [String: Any] = [
        showMenuBarIcon: true, allDisplays: false, followMouseDisplay: true, openOnHover: true, hoverDelay: 0.25,
        extendHoverArea: false, haptics: true, heightMode: "notch", customHeight: 32.0, nonNotchHeight: 30.0,
        hideInFullscreen: "unlessPlaying", hideFromRecording: false, settingsInNotch: true, optionClickAction: "settings",
        gestures: true, closeGesture: true, gestureSensitivity: 0.5, helloAnimation: true, autoCheckUpdates: true,
        theme: "midnight", accent: "#7C9CFF", shadow: true, glow: true, cornerScaling: true, idleFace: true,
        tileLabels: false, showMirror: true, mirrorCircle: false, showCalendar: true,
        mediaSource: "auto", waveStyle: "bars", colorfulWaves: true, tintPlayer: true, sliderColor: "album",
        sneakPeek: true, sneakPeekStyle: "standard", sneakPeekSeconds: 3.5, showShuffleRepeat: true, lyrics: false, lyricsClosed: true,
        controlSlots: "shuffle,previous,play,next,repeat", hideWhenPaused: false,
        hudReplace: false, hudInline: false, hudGradient: true, hudAccent: true, hudPercent: true, hudInOpenNotch: true,
        bluetoothActivity: true, bluetoothSeconds: 3.5, bluetoothDisconnect: true,
        batteryIndicator: true, batteryPercent: true, powerNotifications: true, lowBatteryAlert: true,
        downloads: true,
        shelf: true, shelfOpensByDefault: true, copyOnDrag: false, autoRemoveShelf: false, expandedDrop: true,
        hideAllDay: false, fullEventTitles: false, showReminders: true, hideDoneReminders: true, hiddenCalendars: "",
        didOnboard: false, lastSeenVersion: "",
    ]

    static func register() { UserDefaults.standard.register(defaults: defaults) }
    static func bool(_ k: String) -> Bool { UserDefaults.standard.bool(forKey: k) }
    static func double(_ k: String) -> Double { UserDefaults.standard.double(forKey: k) }
    static func string(_ k: String) -> String { UserDefaults.standard.string(forKey: k) ?? "" }
}

// MARK: - Theme

struct Theme {
    let background: AnyShapeStyle
    let border: Color
    let glow: Color

    static func current() -> Theme {
        let accent = Color(hex: Prefs.string(Prefs.accent)) ?? .accentColor
        switch Prefs.string(Prefs.theme) {
        case "glass":  return Theme(background: AnyShapeStyle(.ultraThinMaterial.opacity(0.98)), border: .white.opacity(0.10), glow: .clear)
        case "aurora": return Theme(background: AnyShapeStyle(Color.black), border: accent.opacity(0.55), glow: accent.opacity(0.45))
        default:       return Theme(background: AnyShapeStyle(Color.black), border: .clear, glow: .clear)   // midnight & OLED: pure notch black
        }
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
    var hexString: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .white
        return String(format: "#%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
    static var sentraAccent: Color { Color(hex: Prefs.string(Prefs.accent)) ?? .accentColor }
}

enum Haptics {
    static func tap() {
        guard Prefs.bool(Prefs.haptics) else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}
