//
//  App.swift — Sentra Notch
//  App start-up, menu bar item, global shortcuts, launch at login and onboarding.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

enum Links {
    static let website = URL(string: "https://bubbles.foo.ng/SentraNotch/")!
    static let company = URL(string: "https://bubbles.foo.ng/")!
    static let repo = URL(string: "https://github.com/AbhiramUpadrashta/SentraNotch")!
    static let mail = URL(string: "mailto:abhi@bubbles.foo.ng?subject=Sentra%20Notch")!
}

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let d = AppDelegate()
        app.delegate = d
        app.setActivationPolicy(.accessory)
        app.run()
    }

    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ n: Notification) {
        Prefs.register()
        if Installer.moveToApplicationsIfNeeded() { return }
        NotchController.shared.start()
        MusicModel.shared.start()
        SystemHUD.shared.start()
        BluetoothMonitor.shared.start()
        PowerMonitor.shared.start()
        ReminderMonitor.shared.start()
        CalendarModel.shared.start()
        if Prefs.bool(Prefs.didOnboard) { DownloadMonitor.shared.start() }
        HotKeys.shared.register()
        NotificationWatcher.shared.start()
        // Accessibility may be granted later in System Settings; pick it up when we become active again.
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            NotificationWatcher.shared.start()
        }
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            if AXIsProcessTrusted() { NotificationWatcher.shared.start() }
        }
        updateStatusItem()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in (NSApp.delegate as? AppDelegate)?.updateStatusItem() }
        }
        if Prefs.bool(Prefs.helloAnimation) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { NotchModel.shared.show(.hello, for: 3) }
        }
        if !Prefs.bool(Prefs.didOnboard) { DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { Onboarding.show() } }
        Updater.shared.checkInBackgroundIfDue()
        Updater.shared.verifyPendingUpdate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindow.show(); return true
    }

    func updateStatusItem() {
        let want = Prefs.bool(Prefs.showMenuBarIcon)
        if want, statusItem == nil {
            let s = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            s.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Sentra Notch")
            let m = NSMenu()
            m.addItem(withTitle: "Open Notch", action: #selector(toggleNotch), keyEquivalent: "").target = self
            m.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
            m.addItem(withTitle: "Check for Updates…", action: #selector(checkUpdates), keyEquivalent: "").target = self
            m.addItem(.separator())
            m.addItem(withTitle: "Restart Sentra Notch", action: #selector(restart), keyEquivalent: "").target = self
            m.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            s.menu = m
            statusItem = s
        } else if !want, let s = statusItem {
            NSStatusBar.system.removeStatusItem(s); statusItem = nil
        }
    }

    @objc func toggleNotch() { NotchModel.shared.toggle() }
    @objc func openSettings() { SettingsWindow.show() }
    @objc func checkUpdates() { Updater.shared.check(userInitiated: true) }
    @objc func restart() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 0.5; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? p.run()
        NSApp.terminate(nil)
    }
}

enum LoginItem {
    static var enabled: Bool { SMAppService.mainApp.status == .enabled }
    static func set(_ on: Bool) { try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
}

// MARK: - Global shortcuts (Carbon hot keys, no Accessibility permission needed)

@MainActor
final class HotKeys {
    static let shared = HotKeys()
    struct Shortcut { let id: UInt32; let key: Int; let mods: Int; let label: String; let action: @MainActor () -> Void }
    let list: [Shortcut] = [
        Shortcut(id: 1, key: kVK_ANSI_N, mods: cmdKey | optionKey, label: "⌥⌘N  Open / close the notch") { NotchModel.shared.toggle() },
        Shortcut(id: 2, key: kVK_ANSI_S, mods: cmdKey | optionKey, label: "⌥⌘S  Open the shelf") { NotchModel.shared.open(.shelf) },
        Shortcut(id: 3, key: kVK_ANSI_P, mods: cmdKey | optionKey, label: "⌥⌘P  Show what's playing") {
            if MusicModel.shared.hasMedia { NotchModel.shared.show(.track, for: 3.5) }
        },
    ]
    private var refs: [EventHotKeyRef?] = []

    func register() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let id = hk.id
            Task { @MainActor in HotKeys.shared.list.first { $0.id == id }?.action() }
            return noErr
        }, 1, &spec, nil, nil)
        for s in list {
            var ref: EventHotKeyRef?
            RegisterEventHotKey(UInt32(s.key), UInt32(s.mods), EventHotKeyID(signature: OSType(0x534E5448), id: s.id), GetApplicationEventTarget(), 0, &ref)
            refs.append(ref)
        }
    }
}

// MARK: - Onboarding

@MainActor
enum Onboarding {
    private static var window: NSWindow?
    static func show() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 520), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: OnboardingView { w.close(); UserDefaults.standard.set(true, forKey: Prefs.didOnboard); DownloadMonitor.shared.start() })
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

struct OnboardingView: View {
    var done: () -> Void
    @State private var calendar = CalendarModel.shared.eventsAllowed
    @State private var camera = MirrorCamera.allowed
    @State private var access = SystemHUD.accessibilityGranted
    @State private var appear = false

    var body: some View {
        VStack(spacing: 18) {
            AppIconView().frame(width: 92, height: 92).scaleEffect(appear ? 1 : 0.6).opacity(appear ? 1 : 0)
            Text("Welcome to Sentra Notch").font(.system(size: 26, weight: .bold, design: .rounded))
            Text("Your notch, now intelligent. Hover over it to open. A few optional permissions unlock more:")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 400)
            VStack(spacing: 10) {
                perm("calendar", "Calendar & Reminders", "Today's agenda in the notch", calendar) {
                    Task { await CalendarModel.shared.requestAccess(); calendar = CalendarModel.shared.eventsAllowed }
                }
                perm("camera.fill", "Camera", "The mirror, only when you open it", camera) { MirrorCamera.request { camera = $0 } }
                perm("keyboard", "Accessibility", "Notifications & alarms in the notch, and the volume HUD", access) {
                    SystemHUD.askAccessibility()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { access = SystemHUD.accessibilityGranted }
                }
            }
            Button(action: done) { Text("Get Started").frame(width: 200) }.controlSize(.large).buttonStyle(.borderedProminent)
        }
        .padding(30)
        .frame(width: 520, height: 520)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { appear = true } }
    }

    private func perm(_ icon: String, _ title: String, _ sub: String, _ ok: Bool, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).frame(width: 30)
            VStack(alignment: .leading) { Text(title).fontWeight(.semibold); Text(sub).font(.caption).foregroundStyle(.secondary) }
            Spacer()
            if ok { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) } else { Button("Allow", action: action) }
        }
        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.5)))
    }
}

struct AppIconView: View {
    var body: some View { Image(nsImage: NSApp.applicationIconImage ?? NSImage()).resizable() }
}
