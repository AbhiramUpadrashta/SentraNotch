//
//  Devices.swift — Sentra Notch
//  NEW in Sentra: Bluetooth pairing live activity (mouse, keyboard, trackpad, AirPods, headphones,
//  speakers, game controllers…) with battery levels. Also Mac power events and download activity.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import AppKit
import IOBluetooth
import IOKit
import IOKit.ps

// MARK: - Bluetooth

enum DeviceKind: String {
    case mouse, trackpad, keyboard, headphones, airpods, airpodsPro, airpodsMax, beats, speaker, gamepad, phone, watch, other

    var symbol: String {
        switch self {
        case .mouse: return "computermouse.fill"
        case .trackpad: return "rectangle.and.hand.point.up.left.fill"
        case .keyboard: return "keyboard.fill"
        case .headphones: return "headphones"
        case .airpods: return "airpods"
        case .airpodsPro: return "airpodspro"
        case .airpodsMax: return "airpodsmax"
        case .beats: return "beats.headphones"
        case .speaker: return "hifispeaker.fill"
        case .gamepad: return "gamecontroller.fill"
        case .phone: return "iphone"
        case .watch: return "applewatch"
        case .other: return "dot.radiowaves.left.and.right"
        }
    }
    var isAudio: Bool { [.headphones, .airpods, .airpodsPro, .airpodsMax, .beats, .speaker].contains(self) }
}

struct DeviceEvent: Equatable {
    let id = UUID()
    var name: String
    var kind: DeviceKind
    var connected: Bool
    var battery: Int?          // single / combined
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    var charging: Bool
}

final class BluetoothMonitor: NSObject {
    static let shared = BluetoothMonitor()
    private var connectNote: IOBluetoothUserNotification?
    private var startedAt = Date()
    private var seen = Set<String>()

    func start() {
        startedAt = Date()
        connectNote = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
    }

    @objc private func connected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        device.register(forDisconnectNotification: self, selector: #selector(disconnected(_:device:)))
        // The system reports already-connected devices right after registering; don't announce those.
        guard Date().timeIntervalSince(startedAt) > 3 else { return }
        announce(device, connected: true)
        // Battery levels often arrive a moment after the connection.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in self?.announce(device, connected: true, update: true) }
    }

    @objc private func disconnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        note.unregister()
        guard Prefs.bool(Prefs.bluetoothDisconnect) else { return }
        announce(device, connected: false)
    }

    private func announce(_ d: IOBluetoothDevice, connected: Bool, update: Bool = false) {
        guard Prefs.bool(Prefs.bluetoothActivity) else { return }
        var e = DeviceEvent(name: d.name ?? "Bluetooth device", kind: Self.kind(of: d), connected: connected,
                            battery: nil, left: nil, right: nil, caseLevel: nil, charging: false)
        if connected { Self.readBattery(d, into: &e) }
        let ev = e
        Task { @MainActor in
            let model = NotchModel.shared
            if update {
                // Only refresh if we're still showing this device and now know its battery.
                guard case .device(let cur)? = model.peek, cur.name == ev.name, cur.connected,
                      ev.battery != nil || ev.left != nil else { return }
                var merged = ev
                merged.charging = ev.charging
                model.peek = .device(DeviceEventRefresh.keepID(cur, with: merged))
                return
            }
            model.show(.device(ev), for: min(4, max(3, Prefs.double(Prefs.bluetoothSeconds))))
        }
    }

    static func kind(of d: IOBluetoothDevice) -> DeviceKind {
        let name = (d.name ?? "").lowercased()
        if name.contains("airpods max") { return .airpodsMax }
        if name.contains("airpods pro") { return .airpodsPro }
        if name.contains("airpods") { return .airpods }
        if name.contains("beats") || name.contains("powerbeats") { return .beats }
        if name.contains("trackpad") { return .trackpad }
        if name.contains("mouse") { return .mouse }
        if name.contains("keyboard") { return .keyboard }
        if name.contains("controller") || name.contains("dualsense") || name.contains("xbox") { return .gamepad }
        let major = d.deviceClassMajor, minor = d.deviceClassMinor
        switch major {
        case 0x05: // peripheral
            switch (minor & 0x30) >> 4 {
            case 1: return .keyboard
            case 2: return .mouse
            case 3: return .keyboard
            default: return (minor & 0x0F) == 0x01 || (minor & 0x0F) == 0x02 ? .gamepad : .other
            }
        case 0x04: // audio/video
            switch minor { case 0x05, 0x07, 0x0A: return .speaker; default: return .headphones }
        case 0x02: return .phone
        case 0x07: return .watch
        default: return .other
        }
    }

    /// Battery from the Bluetooth stack (AirPods/Beats/headphones) or from the HID driver (Magic Mouse/Keyboard/Trackpad…).
    static func readBattery(_ d: IOBluetoothDevice, into e: inout DeviceEvent) {
        func kvc(_ k: String) -> Int? {
            guard d.responds(to: NSSelectorFromString(k)), let n = d.value(forKey: k) as? NSNumber, n.intValue > 0 else { return nil }
            return n.intValue
        }
        e.battery = kvc("batteryPercentSingle") ?? kvc("batteryPercentCombined")
        e.left = kvc("batteryPercentLeft"); e.right = kvc("batteryPercentRight"); e.caseLevel = kvc("batteryPercentCase")
        if e.battery == nil, let l = e.left, let r = e.right { e.battery = min(l, r) }
        if e.battery == nil, let hid = hidBattery(address: d.addressString ?? "", name: d.name ?? "") {
            e.battery = hid.level; e.charging = hid.charging
        }
    }

    static func hidBattery(address: String, name: String) -> (level: Int, charging: Bool)? {
        let want = address.lowercased().replacingOccurrences(of: ":", with: "-")
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"), &iter) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iter) }
        var result: (Int, Bool)?
        while case let svc = IOIteratorNext(iter), svc != 0 {
            defer { IOObjectRelease(svc) }
            func prop(_ k: String) -> Any? { IORegistryEntryCreateCFProperty(svc, k as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() }
            guard let pct = prop("BatteryPercent") as? Int else { continue }
            let addr = (prop("DeviceAddress") as? String ?? "").lowercased().replacingOccurrences(of: ":", with: "-")
            let product = prop("Product") as? String ?? ""
            if (!want.isEmpty && addr == want) || (!name.isEmpty && product == name) {
                let flags = prop("BatteryStatusFlags") as? Int ?? 0
                result = (pct, flags == 3 || flags & 0x04 != 0)
                break
            }
        }
        return result
    }
}

enum DeviceEventRefresh {
    /// Keeps the same identity so the view doesn't restart its pairing animation.
    static func keepID(_ old: DeviceEvent, with new: DeviceEvent) -> DeviceEvent {
        var o = old
        o.battery = new.battery; o.left = new.left; o.right = new.right; o.caseLevel = new.caseLevel; o.charging = new.charging
        return o
    }
}

// MARK: - Mac battery / power

enum PowerEvent: Equatable {
    case pluggedIn(Int), unplugged(Int), low(Int), full
}

@MainActor
final class PowerMonitor: ObservableObject {
    static let shared = PowerMonitor()
    @Published var level = 100
    @Published var charging = false
    @Published var onAC = true
    @Published var hasBattery = false
    @Published var minutesLeft: Int?
    private var warnedLow = Set<Int>()
    private var started = false

    var showsCompact: Bool { false }

    func start() {
        read(announce: false)
        let ctx = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let src = IOPSNotificationCreateRunLoopSource({ _ in
            Task { @MainActor in PowerMonitor.shared.read(announce: true) }
        }, ctx)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
        }
        started = true
    }

    func read(announce: Bool) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let first = list.first,
              let d = IOPSGetPowerSourceDescription(info, first)?.takeUnretainedValue() as? [String: Any] else { hasBattery = false; return }
        hasBattery = true
        let cur = d[kIOPSCurrentCapacityKey] as? Int ?? 0, max = d[kIOPSMaxCapacityKey] as? Int ?? 100
        let newLevel = max > 0 ? Int((Double(cur) / Double(max) * 100).rounded()) : cur
        let newAC = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let newCharging = d[kIOPSIsChargingKey] as? Bool ?? false
        let tte = d[kIOPSTimeToEmptyKey] as? Int ?? -1
        minutesLeft = tte > 0 ? tte : nil

        if announce && Prefs.bool(Prefs.powerNotifications) {
            if newAC && !onAC { NotchModel.shared.show(.power(.pluggedIn(newLevel)), for: 3.5) }
            else if !newAC && onAC { NotchModel.shared.show(.power(.unplugged(newLevel)), for: 3.5) }
            else if newAC && newLevel >= 100 && level < 100 { NotchModel.shared.show(.power(.full), for: 3.5) }
        }
        if announce && Prefs.bool(Prefs.lowBatteryAlert) && !newAC {
            for t in [20, 10, 5] where newLevel <= t && !warnedLow.contains(t) {
                warnedLow.insert(t); NotchModel.shared.show(.power(.low(newLevel)), for: 4); break
            }
        }
        if newAC { warnedLow.removeAll() }
        level = newLevel; onAC = newAC; charging = newCharging
    }
}

// MARK: - Downloads (Safari, Chrome, Edge, Firefox, Arc…)

@MainActor
final class DownloadMonitor {
    static let shared = DownloadMonitor()
    private var source: DispatchSourceFileSystemObject?
    private var timer: Timer?
    private var active = Set<String>()
    private let partial = ["crdownload", "download", "part", "opdownload", "partial"]

    func start() {
        guard Prefs.bool(Prefs.downloads), source == nil else { return }
        let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let s = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        s.setEventHandler { Task { @MainActor in DownloadMonitor.shared.scan() } }
        s.setCancelHandler { close(fd) }
        s.resume()
        source = s
        scan()
    }

    func stop() { source?.cancel(); source = nil; timer?.invalidate() }

    private func scan() {
        let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        let now = Set(names.filter { partial.contains(($0 as NSString).pathExtension.lowercased()) })
        for gone in active.subtracting(now) {
            let finalName = Self.finalName(gone)
            if names.contains(finalName) { NotchModel.shared.show(.download(finalName, done: true), for: 3) }
        }
        active = now
        if let first = now.first {
            NotchModel.shared.show(.download(Self.finalName(first), done: false), for: 2.5)
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in Task { @MainActor in DownloadMonitor.shared.scan() } }
        }
    }

    static func finalName(_ partialName: String) -> String {
        var n = (partialName as NSString).deletingPathExtension
        if n.hasPrefix("Unconfirmed ") { n = "Download" }
        return n
    }
}
