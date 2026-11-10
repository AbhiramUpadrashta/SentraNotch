//
//  NotchWindow.swift — Sentra Notch
//  The transparent panel that sits over the notch, plus mouse/hover/gesture/drag/fullscreen handling.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    static let canvas = CGSize(width: 820, height: 340)

    init(screen: NSScreen) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
        sharingType = Prefs.bool(Prefs.hideFromRecording) ? .none : .readOnly
        place(on: screen)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func place(on screen: NSScreen) {
        let f = screen.frame
        setFrame(NSRect(x: f.midX - Self.canvas.width / 2, y: f.maxY - Self.canvas.height,
                        width: Self.canvas.width, height: Self.canvas.height), display: true)
    }
}

/// Hosting view that turns trackpad swipes into notch gestures.
final class GestureHostingView<Content: View>: NSHostingView<Content> {
    private var accX: CGFloat = 0, accY: CGFloat = 0, fired = false

    override func scrollWheel(with e: NSEvent) {
        guard Prefs.bool(Prefs.gestures) else { return super.scrollWheel(with: e) }
        if e.phase == .began { accX = 0; accY = 0; fired = false }
        accX += e.scrollingDeltaX
        accY += e.scrollingDeltaY * (e.isDirectionInvertedFromDevice ? 1 : -1)   // >0 = fingers moved down
        let need = 20 + CGFloat(1 - Prefs.double(Prefs.gestureSensitivity)) * 120
        if !fired {
            let model = NotchModel.shared
            if accY > need && !model.isOpen { fired = true; model.open() }
            else if accY < -need && model.isOpen && Prefs.bool(Prefs.closeGesture) { fired = true; model.close() }
            else if abs(accX) > need * 1.4 && model.isOpen && model.tab == .home && MusicModel.shared.hasMedia {
                fired = true
                if accX > 0 { MusicModel.shared.previous() } else { MusicModel.shared.next() }
                Haptics.tap()
            }
        }
        if e.phase == .ended || e.momentumPhase == .ended { accX = 0; accY = 0; fired = false }
    }
}

@MainActor
final class NotchController {
    static let shared = NotchController()
    private var panels: [NSScreen: NotchPanel] = [:]
    private var monitors: [Any] = []
    private var hoverTimer: Timer?
    private var closeTimer: Timer?
    private var fullscreenTimer: Timer?
    private var dragChangeCount = NSPasteboard(name: .drag).changeCount
    private var activeScreen: NSScreen?

    func start() {
        rebuild()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in NotchController.shared.rebuild() }
        }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { e in
            Task { @MainActor in NotchController.shared.mouse(e) }
        }) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { e in
            Task { @MainActor in NotchController.shared.mouse(e) }
            return e
        }) { monitors.append(l) }
        fullscreenTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in NotchController.shared.checkFullscreen() }
        }
    }

    /// Creates one panel per display (or just the main/built-in one).
    func rebuild() {
        let screens: [NSScreen]
        if Prefs.bool(Prefs.allDisplays) {
            screens = NSScreen.screens
        } else {
            let builtIn = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
            screens = [builtIn ?? NSScreen.main ?? NSScreen.screens[0]]
        }
        for (s, p) in panels where !screens.contains(s) { p.orderOut(nil); panels[s] = nil }
        for s in screens {
            let p = panels[s] ?? makePanel(for: s)
            p.place(on: s)
            p.sharingType = Prefs.bool(Prefs.hideFromRecording) ? .none : .readOnly
            p.orderFrontRegardless()
            panels[s] = p
        }
        activeScreen = screens.first
        NotchModel.shared.closedSize = Self.notchSize(for: activeScreen ?? screens[0])
    }

    private func makePanel(for screen: NSScreen) -> NotchPanel {
        let p = NotchPanel(screen: screen)
        let host = GestureHostingView(rootView: NotchRootView().environmentObject(NotchModel.shared))
        host.frame = NSRect(origin: .zero, size: NotchPanel.canvas)
        host.autoresizingMask = [.width, .height]
        p.contentView = host
        return p
    }

    static func notchSize(for screen: NSScreen) -> CGSize {
        let menuBar = max(24, screen.frame.maxY - screen.visibleFrame.maxY)
        var width: CGFloat = 196, height: CGFloat
        let hasNotch = screen.safeAreaInsets.top > 0
        if hasNotch, let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
            width = screen.frame.width - l.width - r.width + 4
        }
        switch Prefs.string(Prefs.heightMode) {
        case "menubar": height = menuBar
        case "custom": height = max(20, Prefs.double(Prefs.customHeight))
        default: height = hasNotch ? screen.safeAreaInsets.top : max(20, Prefs.double(Prefs.nonNotchHeight))
        }
        return CGSize(width: width, height: height)
    }

    // MARK: Mouse

    private func notchRect(on screen: NSScreen, size: CGSize, extra: CGFloat = 0) -> NSRect {
        let f = screen.frame
        return NSRect(x: f.midX - size.width / 2 - extra, y: f.maxY - size.height - extra,
                      width: size.width + extra * 2, height: size.height + extra + 2)
    }

    private func mouse(_ e: NSEvent) {
        let model = NotchModel.shared
        let pt = NSEvent.mouseLocation
        if Prefs.bool(Prefs.followMouseDisplay), Prefs.bool(Prefs.allDisplays),
           let s = NSScreen.screens.first(where: { $0.frame.contains(pt) }), s != activeScreen, panels[s] != nil, !model.isOpen {
            activeScreen = s
            model.closedSize = Self.notchSize(for: s)
        }
        guard let screen = activeScreen, let panel = panels[screen], !model.hidden else { return }

        // Dragging files towards the notch opens the shelf.
        if e.type == .leftMouseDragged, Prefs.bool(Prefs.shelf) {
            let pb = NSPasteboard(name: .drag)
            if pb.changeCount != dragChangeCount {
                let zone = notchRect(on: screen, size: model.closedSize, extra: Prefs.bool(Prefs.expandedDrop) ? 120 : 30)
                if zone.contains(pt), (pb.types ?? []).contains(where: { $0 == .fileURL || $0 == .URL || $0 == .string || $0 == .png || $0 == .tiff }) {
                    model.open(.shelf)
                    panel.ignoresMouseEvents = false
                }
            }
        }
        if e.type == .leftMouseUp { dragChangeCount = NSPasteboard(name: .drag).changeCount }

        let size = model.isOpen ? model.openSize : model.currentSize
        let extra: CGFloat = model.isOpen ? 12 : (Prefs.bool(Prefs.extendHoverArea) ? 18 : 4)
        let inside = notchRect(on: screen, size: size, extra: extra).contains(pt)
        for (s, p) in panels { p.ignoresMouseEvents = !(inside && s == screen) }

        if inside != model.hovering { model.hovering = inside }

        if inside {
            closeTimer?.invalidate(); closeTimer = nil
            if !model.isOpen, Prefs.bool(Prefs.openOnHover), hoverTimer == nil {
                hoverTimer = Timer.scheduledTimer(withTimeInterval: max(0.05, Prefs.double(Prefs.hoverDelay)), repeats: false) { _ in
                    Task { @MainActor in
                        let c = NotchController.shared
                        c.hoverTimer = nil
                        if NotchModel.shared.hovering { NotchModel.shared.open() }
                    }
                }
            }
        } else {
            hoverTimer?.invalidate(); hoverTimer = nil
            if model.isOpen, closeTimer == nil, !model.dropTargeted, NSEvent.pressedMouseButtons == 0 {
                closeTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { _ in
                    Task { @MainActor in
                        NotchController.shared.closeTimer = nil
                        if !NotchModel.shared.hovering && !NotchModel.shared.dropTargeted { NotchModel.shared.close() }
                    }
                }
            }
        }
    }

    // MARK: Fullscreen

    private func checkFullscreen() {
        guard let screen = activeScreen else { return }
        let mode = Prefs.string(Prefs.hideInFullscreen)
        var full = false
        if mode != "never", let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier != Bundle.main.bundleIdentifier,
           let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            let mainH = NSScreen.screens.first?.frame.height ?? screen.frame.height
            for w in list where (w[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier && (w[kCGWindowLayer as String] as? Int) == 0 {
                guard let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
                // CG coordinates have their origin at the top-left of the main display.
                let rect = CGRect(x: b["X"] ?? 0, y: mainH - (b["Y"] ?? 0) - (b["Height"] ?? 0), width: b["Width"] ?? 0, height: b["Height"] ?? 0)
                if abs(rect.width - screen.frame.width) < 2 && abs(rect.height - screen.frame.height) < 2 && screen.frame.contains(CGPoint(x: rect.midX, y: rect.midY)) {
                    full = true; break
                }
            }
        }
        let hide = full && (mode == "always" || (mode == "unlessPlaying" && !MusicModel.shared.isPlaying))
        let model = NotchModel.shared
        if hide != model.hidden {
            withAnimation(.notchClose) { model.hidden = hide; if hide { model.isOpen = false } }
        }
    }

    func refreshSettings() { rebuild() }
}
