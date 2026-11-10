//
//  NotchModel.swift — Sentra Notch
//  The single source of truth for what the notch is showing.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import SwiftUI

enum NotchTab: String { case home, shelf }

enum HUDKind: Equatable {
    case volume, brightness, keyboard, mic
    var symbol: String {
        switch self {
        case .volume: return "speaker.wave.2.fill"
        case .brightness: return "sun.max.fill"
        case .keyboard: return "light.max"
        case .mic: return "mic.fill"
        }
    }
    func symbol(for value: Double, muted: Bool) -> String {
        switch self {
        case .volume:
            if muted || value <= 0.001 { return "speaker.slash.fill" }
            return value < 0.33 ? "speaker.wave.1.fill" : value < 0.66 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        case .brightness: return value < 0.35 ? "sun.min.fill" : "sun.max.fill"
        case .keyboard: return value <= 0.01 ? "light.min" : "light.max"
        case .mic: return muted ? "mic.slash.fill" : "mic.fill"
        }
    }
}

/// Something that briefly takes over the closed notch ("live activity").
enum Peek: Equatable {
    case hud(HUDKind, Double, muted: Bool)
    case device(DeviceEvent)
    case power(PowerEvent)
    case track                  // sneak peek of a new song
    case download(String, done: Bool)
    case notification(String, String, alarm: Bool)
    case hello

    var priority: Int {
        switch self {
        case .hello: return 5
        case .hud: return 4
        case .device: return 3
        case .notification(_, _, let alarm): return alarm ? 4 : 3
        case .power: return 2
        case .download: return 1
        case .track: return 0
        }
    }
}

@MainActor
final class NotchModel: ObservableObject {
    static let shared = NotchModel()

    @Published var isOpen = false
    @Published var tab: NotchTab = .home
    @Published var peek: Peek?
    @Published var hidden = false            // e.g. fullscreen video
    @Published var hovering = false
    @Published var cameraOn = false        // camera only opens when the user clicks its button
    @Published var dropTargeted = false
    /// Size of the physical notch (or the fake one on displays without a notch).
    @Published var closedSize = CGSize(width: 200, height: 32)

    let openSize = CGSize(width: 640, height: 196)

    private var peekTimer: Timer?

    var currentSize: CGSize {
        if isOpen { return openSize }
        var s = closedSize
        switch peek {
        case .hud:
            if Prefs.bool(Prefs.hudInline) { s.width += 250 } else { s.height += 30; s.width += 120 }
        case .device: s.width += 260; s.height += 26
        case .notification: s.width += 300; s.height += 42
        case .power: s.width += 210
        case .track:
            if Prefs.string(Prefs.sneakPeekStyle) == "inline" { s.width += 220 } else { s.height += 34; s.width += 60 }
        case .download: s.width += 140
        case .hello: s.width += 120; s.height += 20
        case nil:
            if MusicModel.shared.showsCompact {
                s.width += 110
                if MusicModel.shared.showsLyricLine { s.height += 22; s.width += 60 }
            }
            else if PowerMonitor.shared.showsCompact { s.width += 72 }
        }
        return s
    }

    func open(_ tab: NotchTab? = nil) {
        if let tab { self.tab = tab }
        guard !isOpen else { return }
        Haptics.tap()
        withAnimation(.notchOpen) { isOpen = true; peek = nil }
    }

    func close() {
        guard isOpen else { return }
        withAnimation(.notchClose) { isOpen = false; cameraOn = false }
        tab = Prefs.bool(Prefs.shelfOpensByDefault) && !ShelfModel.shared.items.isEmpty ? .shelf : .home
    }

    func toggle() { isOpen ? close() : open() }

    /// Show a live activity for `seconds`. Lower-priority peeks don't interrupt higher ones.
    func show(_ p: Peek, for seconds: Double) {
        guard !hidden || p.priority >= 4 else { return }
        if let cur = peek, cur.priority > p.priority, cur != p { return }
        peekTimer?.invalidate()
        if isOpen {
            // In the open notch, HUDs show in the header; others are skipped.
            if case .hud = p, Prefs.bool(Prefs.hudInOpenNotch) { openHUD = p; scheduleOpenHUDClear() }
            return
        }
        withAnimation(.notchPeek) { peek = p }
        peekTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in withAnimation(.notchClose) { self?.peek = nil } }
        }
    }

    func clearPeek() { peekTimer?.invalidate(); withAnimation(.notchClose) { peek = nil } }

    // HUD shown inside the open notch header
    @Published var openHUD: Peek?
    private var openHUDTimer: Timer?
    private func scheduleOpenHUDClear() {
        openHUDTimer?.invalidate()
        openHUDTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: false) { [weak self] _ in
            Task { @MainActor in withAnimation { self?.openHUD = nil } }
        }
    }
}

extension Animation {
    static let notchOpen = Animation.spring(response: 0.42, dampingFraction: 0.78, blendDuration: 0)
    static let notchClose = Animation.spring(response: 0.38, dampingFraction: 0.92, blendDuration: 0)
    static let notchPeek = Animation.spring(response: 0.36, dampingFraction: 0.8, blendDuration: 0)
}
