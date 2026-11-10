//
//  Notifications.swift — Sentra Notch
//  Shows incoming notifications and alarms (Clock, Calendar, Messages, Mail…) in the notch.
//  Reads the banner text that macOS shows, through the Accessibility API (needs Accessibility permission).
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import AppKit
import ApplicationServices

final class NotificationWatcher {
    static let shared = NotificationWatcher()
    private var observer: AXObserver?
    private var appElement: AXUIElement?
    private var lastKey = ""
    private var lastAt = Date.distantPast
    private var pending: DispatchWorkItem?

    func start() {
        stop()
        guard Prefs.bool(Prefs.notifications), AXIsProcessTrusted(),
              let ncApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else { return }
        let pid = ncApp.processIdentifier
        var obs: AXObserver?
        guard AXObserverCreate(pid, { _, _, _, _ in NotificationWatcher.shared.changed() }, &obs) == .success, let obs else { return }
        let el = AXUIElementCreateApplication(pid)
        for n in [kAXWindowCreatedNotification, kAXCreatedNotification, kAXUIElementDestroyedNotification] {
            AXObserverAddNotification(obs, el, n as CFString, nil)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        observer = obs; appElement = el
    }

    func stop() {
        if let obs = observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode) }
        observer = nil; appElement = nil
    }

    /// Banners build up over a few events; read them once things settle.
    private func changed() {
        pending?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.read() }
        pending = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: w)
    }

    private func read() {
        guard let app = appElement else { return }
        var windows: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows)
        guard let wins = windows as? [AXUIElement], let win = wins.first else { return }
        var texts: [String] = []
        collect(win, depth: 0, into: &texts)
        texts = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && $0.count < 400 }
        guard let title = texts.first else { return }
        let body = texts.dropFirst().prefix(2).joined(separator: " · ")
        let key = title + "|" + body
        // The same banner is reported several times; also skip Notification Center's own list when it's opened.
        guard key != lastKey || Date().timeIntervalSince(lastAt) > 8, texts.count <= 6 else { return }
        lastKey = key; lastAt = Date()
        let isAlarm = (title + body).range(of: "alarm|timer|wake up|reminder", options: [.regularExpression, .caseInsensitive]) != nil
        Task { @MainActor in
            NotchModel.shared.show(.notification(title, body, alarm: isAlarm), for: isAlarm ? 6 : 4)
        }
    }

    private func collect(_ el: AXUIElement, depth: Int, into out: inout [String]) {
        guard depth < 9, out.count < 8 else { return }
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role)
        if (role as? String) == kAXStaticTextRole as String {
            var v: CFTypeRef?
            AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &v)
            if let s = v as? String { out.append(s) }
            return
        }
        var kids: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &kids)
        for k in (kids as? [AXUIElement]) ?? [] { collect(k, depth: depth + 1, into: &out) }
    }
}
