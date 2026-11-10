//
//  SystemHUD.swift — Sentra Notch
//  Volume, mute, display brightness and keyboard backlight: watches every change and shows it in the notch.
//  Optionally replaces the macOS on-screen HUD by handling the media keys itself (needs Accessibility).
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import AppKit
import CoreAudio
import AudioToolbox

// MARK: - Volume (CoreAudio)

enum Volume {
    static var device: AudioDeviceID {
        var id = AudioDeviceID(0), size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return id
    }
    static var volumeAddr = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                                                       mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
    static var muteAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
                                                     mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)

    static var level: Double {
        get {
            var v = Float32(0), size = UInt32(MemoryLayout<Float32>.size)
            AudioObjectGetPropertyData(device, &volumeAddr, 0, nil, &size, &v)
            return Double(v)
        }
        set {
            var v = Float32(min(1, max(0, newValue)))
            AudioObjectSetPropertyData(device, &volumeAddr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
        }
    }
    static var muted: Bool {
        get {
            var m = UInt32(0), size = UInt32(MemoryLayout<UInt32>.size)
            AudioObjectGetPropertyData(device, &muteAddr, 0, nil, &size, &m)
            return m != 0
        }
        set {
            var m = UInt32(newValue ? 1 : 0)
            AudioObjectSetPropertyData(device, &muteAddr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &m)
        }
    }
}

// MARK: - Display brightness (DisplayServices, private but stable since 10.12)

enum Brightness {
    private typealias Get = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Set = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private static let lib = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private static let getFn: Get? = lib.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map { unsafeBitCast($0, to: Get.self) }
    private static let setFn: Set? = lib.flatMap { dlsym($0, "DisplayServicesSetBrightness") }.map { unsafeBitCast($0, to: Set.self) }

    static var display: CGDirectDisplayID {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16), n = UInt32(0)
        CGGetOnlineDisplayList(16, &ids, &n)
        return ids.prefix(Int(n)).first { CGDisplayIsBuiltin($0) != 0 } ?? CGMainDisplayID()
    }
    static var level: Double? {
        get {
            guard let getFn else { return nil }
            var v: Float = 0
            return getFn(display, &v) == 0 ? Double(v) : nil
        }
        set { if let v = newValue, let setFn { _ = setFn(display, Float(min(1, max(0, v)))) } }
    }
}

// MARK: - Keyboard backlight (CoreBrightness, private)

enum KeyboardLight {
    private static let client: NSObject? = {
        dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)
        guard let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else { return nil }
        return cls.init()
    }()
    private static var keyboardID: UInt64 {
        guard let c = client, c.responds(to: NSSelectorFromString("copyKeyboardBacklightIDs")),
              let ids = c.perform(NSSelectorFromString("copyKeyboardBacklightIDs"))?.takeUnretainedValue() as? [NSNumber],
              let first = ids.first else { return 1 }
        return first.uint64Value
    }
    static var level: Double? {
        get {
            let sel = NSSelectorFromString("brightnessForKeyboard:")
            guard let c = client, c.responds(to: sel) else { return nil }
            typealias F = @convention(c) (AnyObject, Selector, UInt64) -> Float
            let f = unsafeBitCast(c.method(for: sel), to: F.self)
            return Double(f(c, sel, keyboardID))
        }
        set {
            let sel = NSSelectorFromString("setBrightness:forKeyboard:")
            guard let v = newValue, let c = client, c.responds(to: sel) else { return }
            typealias F = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
            let f = unsafeBitCast(c.method(for: sel), to: F.self)
            _ = f(c, sel, Float(min(1, max(0, v))), keyboardID)
        }
    }
}

// MARK: - Monitor

@MainActor
final class SystemHUD {
    static let shared = SystemHUD()
    private var lastVolume = -1.0, lastMuted = false, lastBrightness = -1.0, lastKeyboard = -1.0
    private var pollTimer: Timer?
    private var tap: CFMachPort?
    private var listenedDevice: AudioDeviceID = 0
    private var suppressPollUntil = Date.distantPast
    private var keyPressedUntil = Date.distantPast   // auto-brightness changes are ignored; only key presses show
    private var keyMonitor: Any?

    func start() {
        lastVolume = Volume.level; lastMuted = Volume.muted
        lastBrightness = Brightness.level ?? -1; lastKeyboard = KeyboardLight.level ?? -1
        listenToDevice()
        var defAddr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defAddr, .main) { _, _ in
            Task { @MainActor in SystemHUD.shared.listenToDevice() }
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            Task { @MainActor in SystemHUD.shared.poll() }
        }
        applyReplacement()
        // Watch the brightness / keyboard-light keys (no permission needed for media keys).
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { e in
            guard e.subtype.rawValue == 8 else { return }
            let code = Int((e.data1 & 0xFFFF0000) >> 16)
            if [2, 3, 21, 22, 23].contains(code) {
                Task { @MainActor in SystemHUD.shared.keyPressedUntil = Date().addingTimeInterval(1.2) }
            }
        }
    }

    private func listenToDevice() {
        let dev = Volume.device
        guard dev != listenedDevice else { return }
        listenedDevice = dev
        for var addr in [Volume.volumeAddr, Volume.muteAddr] {
            AudioObjectAddPropertyListenerBlock(dev, &addr, .main) { _, _ in
                Task { @MainActor in SystemHUD.shared.volumeChanged() }
            }
        }
    }

    private func volumeChanged() {
        let v = Volume.level, m = Volume.muted
        guard abs(v - lastVolume) > 0.001 || m != lastMuted else { return }
        lastVolume = v; lastMuted = m
        NotchModel.shared.show(.hud(.volume, v, muted: m), for: 3)
    }

    private func poll() {
        guard Date() > suppressPollUntil else { return }
        let byKey = Date() < keyPressedUntil
        if let b = Brightness.level, abs(b - lastBrightness) > 0.004 {
            let first = lastBrightness < 0
            lastBrightness = b
            if !first && byKey { NotchModel.shared.show(.hud(.brightness, b, muted: false), for: 3) }
        }
        if let k = KeyboardLight.level, abs(k - lastKeyboard) > 0.004 {
            let first = lastKeyboard < 0
            lastKeyboard = k
            if !first && byKey { NotchModel.shared.show(.hud(.keyboard, k, muted: false), for: 3) }
        }
    }

    // MARK: Replacing the system HUD

    func applyReplacement() {
        if Prefs.bool(Prefs.hudReplace) { installTap() } else { removeTap() }
    }

    static var accessibilityGranted: Bool { AXIsProcessTrusted() }
    static func askAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private func installTap() {
        guard tap == nil else { return }
        guard Self.accessibilityGranted else { Self.askAccessibility(); return }
        let mask = CGEventMask(1 << 14)   // NX_SYSDEFINED
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                eventsOfInterest: mask, callback: { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let t = SystemHUD.tapRef { CGEvent.tapEnable(tap: t, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8 else { return Unmanaged.passUnretained(event) }
            let code = Int((ns.data1 & 0xFFFF0000) >> 16)
            let down = ((ns.data1 & 0xFF00) >> 8) == 0xA
            let fine = ns.modifierFlags.contains(.shift) && ns.modifierFlags.contains(.option)
            let handled: Set<Int> = [0, 1, 2, 3, 7, 21, 22, 23]
            guard handled.contains(code) else { return Unmanaged.passUnretained(event) }
            if down { Task { @MainActor in SystemHUD.shared.handleKey(code, fine: fine) } }
            return nil
        }, userInfo: nil)
        guard let tap else { return }
        Self.tapRef = tap
        let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    nonisolated(unsafe) static var tapRef: CFMachPort?

    private func removeTap() {
        guard let t = tap else { return }
        CGEvent.tapEnable(tap: t, enable: false)
        tap = nil; Self.tapRef = nil
    }

    private func handleKey(_ code: Int, fine: Bool) {
        let step = fine ? 1.0 / 64 : 1.0 / 16
        func snap(_ v: Double) -> Double { (v / step).rounded() * step }
        switch code {
        case 0, 1:
            if Volume.muted { Volume.muted = false }
            Volume.level = snap(Volume.level + (code == 0 ? step : -step))
            playFeedback()
        case 7:
            Volume.muted.toggle()
        case 2, 3:
            if let b = Brightness.level {
                let nv = min(1, max(0, snap(b + (code == 2 ? step : -step))))
                Brightness.level = nv
                lastBrightness = nv
                suppressPollUntil = Date().addingTimeInterval(0.3)
                NotchModel.shared.show(.hud(.brightness, nv, muted: false), for: 3)
            }
        case 21, 22, 23:
            if let k = KeyboardLight.level {
                let nv = code == 23 ? (k > 0 ? 0 : 0.5) : min(1, max(0, snap(k + (code == 21 ? step : -step))))
                KeyboardLight.level = nv
                lastKeyboard = nv
                suppressPollUntil = Date().addingTimeInterval(0.3)
                NotchModel.shared.show(.hud(.keyboard, nv, muted: false), for: 3)
            }
        default: break
        }
    }

    /// The little "pop" macOS plays when changing volume, if the user has it turned on.
    private func playFeedback() {
        guard UserDefaults(suiteName: "NSGlobalDomain")?.integer(forKey: "com.apple.sound.beep.feedback") == 1 else { return }
        NSSound(named: "Pop")?.play()
    }
}
