//
//  Music.swift — Sentra Notch
//  Now playing for every app (via MediaRemote adapter), with Apple Music / Spotify AppleScript fallbacks,
//  playback control, artwork colour and optional synced lyrics.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import AppKit
import SwiftUI

enum MediaCommand: Int { case play = 0, pause = 1, toggle = 2, stop = 3, next = 4, previous = 5 }

protocol MediaSource: AnyObject {
    var onUpdate: (([String: Any]) -> Void)? { get set }
    func start()
    func stop()
    func send(_ c: MediaCommand)
    func seek(_ seconds: Double)
    func setShuffle(_ on: Bool)
    func setRepeat(_ mode: Int)
}

@MainActor
final class MusicModel: ObservableObject {
    static let shared = MusicModel()

    @Published var title = ""
    @Published var artist = ""
    @Published var album = ""
    @Published var artwork: NSImage?
    @Published var artworkColor: Color = .sentraAccent
    @Published var isPlaying = false
    @Published var duration: Double = 0
    @Published var shuffle = false
    @Published var repeatMode = 0              // 0 off, 1 one, 2 all
    @Published var bundleID = ""
    @Published var recentlyActive = false
    @Published var lyrics: [(Double, String)] = []

    private var elapsedAt: Double = 0
    private var timestamp = Date()
    private var rate: Double = 1
    private var source: MediaSource?
    private var idleTimer: Timer?
    private var lastTrackKey = ""

    var hasMedia: Bool { !title.isEmpty }
    var showsCompact: Bool { hasMedia && (isPlaying || (recentlyActive && !Prefs.bool(Prefs.hideWhenPaused))) }
    var appIcon: NSImage? {
        guard !bundleID.isEmpty, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    func elapsed(at date: Date = Date()) -> Double {
        let e = elapsedAt + (isPlaying ? date.timeIntervalSince(timestamp) * rate : 0)
        return duration > 0 ? min(max(0, e), duration) : max(0, e)
    }

    func currentLyric(at date: Date = Date()) -> String? {
        guard !lyrics.isEmpty else { return nil }
        let t = elapsed(at: date) + 0.25
        return lyrics.last(where: { $0.0 <= t })?.1
    }

    // MARK: Source selection

    func start() {
        source?.stop()
        let choice = Prefs.string(Prefs.mediaSource)
        var s: MediaSource
        if choice == "music" { s = AppleScriptSource(kind: .music) }
        else if choice == "spotify" { s = AppleScriptSource(kind: .spotify) }
        else if let a = AdapterSource(), a.works() { s = a }
        else { s = AppleScriptSource(kind: .auto) }
        s.onUpdate = { [weak self] info in Task { @MainActor in self?.apply(info) } }
        s.start()
        source = s
    }

    private func apply(_ i: [String: Any]) {
        let newTitle = i["title"] as? String ?? ""
        let newArtist = i["artist"] as? String ?? ""
        let key = newTitle + "|" + newArtist
        if newTitle.isEmpty { clear(); return }
        let wasPlaying = isPlaying
        title = newTitle; artist = newArtist
        album = i["album"] as? String ?? ""
        if let m = i["durationMicros"] as? Double { duration = m / 1_000_000 }
        else { duration = (i["duration"] as? Double) ?? Double(i["duration"] as? Int ?? 0) }
        let playing = (i["playing"] as? Bool) ?? false
        isPlaying = playing
        rate = (i["playbackRate"] as? Double).map { $0 > 0 ? $0 : 1 } ?? 1
        if let m = i["elapsedTimeMicros"] as? Double {
            elapsedAt = m / 1_000_000
            if let ts = i["timestampEpochMicros"] as? Double { timestamp = Date(timeIntervalSince1970: ts / 1_000_000) } else { timestamp = Date() }
        } else if let e = i["elapsedTime"] as? Double {
            elapsedAt = e
            if let ts = i["timestamp"] as? String, let d = ISO8601DateFormatter.flexible.date(from: ts) { timestamp = d }
            else if let ts = i["timestamp"] as? Double { timestamp = Date(timeIntervalSince1970: ts) }
            else { timestamp = Date() }
        }
        if let sh = i["shuffleMode"] as? Int { shuffle = sh >= 2 }
        if let sh = i["shuffle"] as? Bool { shuffle = sh }
        if let r = i["repeatMode"] as? Int { repeatMode = r == 3 ? 2 : r == 2 ? 1 : r == 1 ? 0 : r }
        bundleID = (i["parentApplicationBundleIdentifier"] as? String) ?? (i["bundleIdentifier"] as? String) ?? bundleID
        if let b64 = i["artworkData"] as? String, let d = Data(base64Encoded: b64), let img = NSImage(data: d) {
            setArtwork(img)
        } else if let d = i["artworkRaw"] as? Data, let img = NSImage(data: d) {
            setArtwork(img)
        } else if let u = i["artworkURL"] as? String, key != lastTrackKey, let url = URL(string: u) {
            Task { if let (d, _) = try? await URLSession.shared.data(from: url), let img = NSImage(data: d) { await MainActor.run { self.setArtwork(img) } } }
        } else if key != lastTrackKey, i["artworkData"] == nil {
            artwork = nil
        }

        if key != lastTrackKey {
            lastTrackKey = key
            lyrics = []
            if Prefs.bool(Prefs.sneakPeek), playing { NotchModel.shared.show(.track, for: Prefs.double(Prefs.sneakPeekSeconds)) }
            if Prefs.bool(Prefs.lyrics) { fetchLyrics() }
        } else if playing && !wasPlaying && Prefs.bool(Prefs.sneakPeek) {
            NotchModel.shared.show(.track, for: Prefs.double(Prefs.sneakPeekSeconds))
        }
        markActive()
    }

    private func markActive() {
        recentlyActive = true
        idleTimer?.invalidate()
        if !isPlaying {
            idleTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
                Task { @MainActor in withAnimation(.notchClose) { self?.recentlyActive = false } }
            }
        }
    }

    private func clear() {
        withAnimation(.notchClose) {
            title = ""; artist = ""; album = ""; artwork = nil; isPlaying = false; duration = 0; lyrics = []
        }
        lastTrackKey = ""
    }

    private func setArtwork(_ img: NSImage) {
        artwork = img
        if let c = img.averageColor { artworkColor = Color(nsColor: c) }
    }

    // MARK: Controls

    func togglePlay() { source?.send(.toggle); isPlaying.toggle(); elapsedAt = elapsed(); timestamp = Date() }
    func next() { source?.send(.next) }
    func previous() { source?.send(.previous) }
    func seek(to s: Double) { source?.seek(s); elapsedAt = s; timestamp = Date() }
    func toggleShuffle() { shuffle.toggle(); source?.setShuffle(shuffle) }
    func cycleRepeat() { repeatMode = (repeatMode + 1) % 3; source?.setRepeat(repeatMode) }
    func openPlayerApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    // MARK: Lyrics (lrclib.net, only when the user turns lyrics on)

    private func fetchLyrics() {
        var c = URLComponents(string: "https://lrclib.net/api/get")!
        c.queryItems = [.init(name: "track_name", value: title), .init(name: "artist_name", value: artist),
                        .init(name: "album_name", value: album), .init(name: "duration", value: String(Int(duration)))]
        guard let url = c.url else { return }
        let key = lastTrackKey
        Task {
            guard let (d, _) = try? await URLSession.shared.data(from: url),
                  let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let synced = j["syncedLyrics"] as? String else { return }
            let parsed = Self.parseLRC(synced)
            await MainActor.run { if self.lastTrackKey == key { self.lyrics = parsed } }
        }
    }

    nonisolated static func parseLRC(_ s: String) -> [(Double, String)] {
        var out: [(Double, String)] = []
        for line in s.split(separator: "\n") {
            guard line.hasPrefix("["), let close = line.firstIndex(of: "]") else { continue }
            let stamp = line[line.index(after: line.startIndex)..<close].split(separator: ":")
            guard stamp.count == 2, let m = Double(stamp[0]), let sec = Double(stamp[1]) else { continue }
            let text = line[line.index(after: close)...].trimmingCharacters(in: .whitespaces)
            out.append((m * 60 + sec, text.isEmpty ? "♪" : text))
        }
        return out
    }
}

extension ISO8601DateFormatter {
    static let flexible: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
}

extension NSImage {
    var averageColor: NSColor? {
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var px = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        var c = NSColor(srgbRed: CGFloat(px[0]) / 255, green: CGFloat(px[1]) / 255, blue: CGFloat(px[2]) / 255, alpha: 1)
        // Keep it vivid enough to read on black.
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        c = NSColor(hue: h, saturation: min(1, s * 1.2), brightness: max(0.65, b), alpha: 1)
        return c
    }
}

// MARK: - MediaRemote adapter (works on every macOS version, every player)

final class AdapterSource: MediaSource {
    var onUpdate: (([String: Any]) -> Void)?
    private var process: Process?
    private var buffer = Data()
    private let script: String, framework: String, testClient: String
    private var stopped = false

    init?() {
        guard let res = Bundle.main.resourcePath else { return nil }
        script = res + "/mediaremote-adapter.pl"
        framework = res + "/MediaRemoteAdapter.framework"
        testClient = res + "/MediaRemoteAdapterTestClient"
        guard FileManager.default.fileExists(atPath: script), FileManager.default.fileExists(atPath: framework) else { return nil }
    }

    func works() -> Bool {
        guard FileManager.default.fileExists(atPath: testClient) else { return true }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [script, framework, testClient, "test"]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        let deadline = Date().addingTimeInterval(3)
        while p.isRunning && Date() < deadline { usleep(50_000) }
        if p.isRunning { p.terminate(); return true }
        return p.terminationStatus == 0
    }

    func start() {
        stopped = false
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [script, framework, "stream", "--no-diff", "--debounce=80", "--micros"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let d = h.availableData
            guard !d.isEmpty else { return }
            self?.consume(d)
        }
        p.terminationHandler = { [weak self] _ in
            guard let self, !self.stopped else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.start() }
        }
        try? p.run()
        process = p
    }

    private func consume(_ d: Data) {
        buffer.append(d)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            guard let j = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            let payload = j["payload"] as? [String: Any] ?? [:]
            onUpdate?(payload)
        }
    }

    func stop() { stopped = true; process?.terminate() }

    private func run(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [script, framework] + args
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try? p.run()
    }

    func send(_ c: MediaCommand) { run(["send", String(c.rawValue)]) }
    func seek(_ seconds: Double) { run(["seek", String(Int(seconds * 1_000_000))]) }
    func setShuffle(_ on: Bool) { run(["shuffle", on ? "3" : "1"]) }
    func setRepeat(_ mode: Int) { run(["repeat", mode == 0 ? "1" : mode == 1 ? "2" : "3"]) }
}

// MARK: - AppleScript (Apple Music / Spotify)

final class AppleScriptSource: MediaSource {
    enum Kind { case music, spotify, auto }
    var onUpdate: (([String: Any]) -> Void)?
    private let kind: Kind
    private var timer: Timer?
    private let queue = DispatchQueue(label: "sentra.applescript")
    private var lastTrack = ""

    init(kind: Kind) { self.kind = kind }

    private var app: (name: String, id: String)? {
        let music = ("Music", "com.apple.Music"), spotify = ("Spotify", "com.spotify.client")
        func running(_ id: String) -> Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty }
        switch kind {
        case .music: return running(music.1) ? music : nil
        case .spotify: return running(spotify.1) ? spotify : nil
        case .auto: return running(spotify.1) ? spotify : running(music.1) ? music : nil
        }
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.poll() }
        poll()
    }
    func stop() { timer?.invalidate() }

    private func poll() {
        guard let app else { onUpdate?([:]); return }
        let isSpotify = app.id == "com.spotify.client"
        let src = """
        tell application "\(app.name)"
          if player state is stopped then return {"stopped"}
          set t to current track
          return {player state as string, name of t, artist of t, album of t, duration of t, player position, \(isSpotify ? "shuffling, repeating, artwork url of t" : "shuffle enabled, (song repeat as string), \"\"")}
        end tell
        """
        queue.async { [weak self] in
            guard let self else { return }
            var err: NSDictionary?
            guard let d = NSAppleScript(source: src)?.executeAndReturnError(&err), d.numberOfItems >= 7 else { self.onUpdate?([:]); return }
            func str(_ i: Int) -> String { d.atIndex(i)?.stringValue ?? "" }
            func num(_ i: Int) -> Double { d.atIndex(i)?.doubleValue ?? 0 }
            var info: [String: Any] = [
                "playing": str(1) == "playing", "title": str(2), "artist": str(3), "album": str(4),
                "duration": isSpotify ? num(5) / 1000 : num(5), "elapsedTime": num(6),
                "shuffle": d.atIndex(7)?.booleanValue ?? false, "bundleIdentifier": app.id,
            ]
            let rep = str(8)
            info["repeatMode"] = isSpotify ? ((d.atIndex(8)?.booleanValue ?? false) ? 3 : 1) : (rep == "one" ? 2 : rep == "all" ? 3 : 1)
            let key = str(2) + str(3)
            if key != self.lastTrack {
                self.lastTrack = key
                if isSpotify { info["artworkURL"] = d.atIndex(9)?.stringValue ?? "" }
                else if let art = NSAppleScript(source: "tell application \"Music\" to get data of artwork 1 of current track")?.executeAndReturnError(nil) {
                    info["artworkRaw"] = art.data
                }
            }
            self.onUpdate?(info)
        }
    }

    private func tell(_ cmd: String) {
        guard let app else { return }
        queue.async { _ = NSAppleScript(source: "tell application \"\(app.name)\" to \(cmd)")?.executeAndReturnError(nil) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.poll() }
    }

    func send(_ c: MediaCommand) {
        switch c {
        case .play: tell("play")
        case .pause: tell("pause")
        case .toggle: tell("playpause")
        case .stop: tell("pause")
        case .next: tell("next track")
        case .previous: tell("previous track")
        }
    }
    func seek(_ seconds: Double) { tell("set player position to \(seconds)") }
    func setShuffle(_ on: Bool) { tell(app?.id == "com.spotify.client" ? "set shuffling to \(on)" : "set shuffle enabled to \(on)") }
    func setRepeat(_ mode: Int) {
        if app?.id == "com.spotify.client" { tell("set repeating to \(mode != 0)") }
        else { tell("set song repeat to \(mode == 0 ? "off" : mode == 1 ? "one" : "all")") }
    }
}
