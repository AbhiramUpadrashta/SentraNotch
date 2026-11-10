//
//  Updater.swift — Sentra Notch
//  "Check for Updates": downloads the newest GitHub release, verifies its Ed25519 signature,
//  the bundle ID, version and code signature, then swaps the app and relaunches.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import AppKit
import CryptoKit

@MainActor
final class Updater {
    static let shared = Updater()
    static let repo = "AbhiramUpadrashta/SentraNotch"
    static let asset = "SentraNotch.zip"
    static let publicKey = "rMThdWzBvY5vl7LDK43b08XVHYRFDDKv/FFmpbFeRJQ="
    private let lastCheckKey = "lastUpdateCheck", pendingKey = "pendingUpdate"
    private var busy = false

    var currentVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    struct Release { let version: String; let notes: String; let zip: URL; let sig: URL }

    func checkInBackgroundIfDue() {
        guard Prefs.bool(Prefs.autoCheckUpdates) else { return }
        let last = UserDefaults.standard.double(forKey: lastCheckKey)
        if Date().timeIntervalSince1970 - last > 20 * 3600 { check(userInitiated: false) }
        Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
            Task { @MainActor in if Prefs.bool(Prefs.autoCheckUpdates) { Updater.shared.check(userInitiated: false) } }
        }
    }

    func check(userInitiated: Bool) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
            guard let r = try? await latest() else {
                if userInitiated { alert("Couldn’t check for updates", "Please check your internet connection and try again.") }
                return
            }
            guard Self.isNewer(r.version, than: currentVersion) else {
                if userInitiated { alert("You’re up to date", "Sentra Notch \(currentVersion) is the newest version.") }
                return
            }
            let a = NSAlert()
            a.messageText = "Sentra Notch \(r.version) is available"
            a.informativeText = "You have \(currentVersion). Update now? It takes a few seconds and keeps your settings.\n\n\(r.notes.prefix(600))"
            a.addButton(withTitle: "Update Now"); a.addButton(withTitle: "Later")
            NSApp.activate(ignoringOtherApps: true)
            guard a.runModal() == .alertFirstButtonReturn else { return }
            do { try await install(r) } catch { alert("The update didn’t install", error.localizedDescription + "\n\nYou can download Sentra Notch from the website.") }
        }
    }

    private func latest() async throws -> Release {
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (d, _) = try await URLSession.shared.data(for: req)
        guard let j = try JSONSerialization.jsonObject(with: d) as? [String: Any], let tag = j["tag_name"] as? String else { throw URLError(.badServerResponse) }
        let assets = j["assets"] as? [[String: Any]] ?? []
        func url(_ n: String) -> URL? {
            (assets.first { $0["name"] as? String == n }?["browser_download_url"] as? String).flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? $0 : nil }
        }
        guard let zip = url(Self.asset), let sig = url(Self.asset + ".sig") else { throw URLError(.fileDoesNotExist) }
        return Release(version: tag.hasPrefix("v") ? String(tag.dropFirst()) : tag, notes: j["body"] as? String ?? "", zip: zip, sig: sig)
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private func install(_ r: Release) async throws {
        struct Fail: LocalizedError { let errorDescription: String? }
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("sentra-update-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let (tmp, resp) = try await URLSession.shared.download(from: r.zip)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw Fail(errorDescription: "The download failed.") }
        let zip = work.appendingPathComponent("update.zip")
        try fm.moveItem(at: tmp, to: zip)
        let (sigData, _) = try await URLSession.shared.data(from: r.sig)
        let sigText = String(decoding: sigData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let sig = Data(base64Encoded: sigText), let keyData = Data(base64Encoded: Self.publicKey),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              key.isValidSignature(sig, for: try Data(contentsOf: zip)) else {
            throw Fail(errorDescription: "The download couldn’t be verified, so it wasn’t installed.")
        }
        let out = work.appendingPathComponent("new")
        guard run("/usr/bin/ditto", ["-x", "-k", zip.path, out.path]) == 0 else { throw Fail(errorDescription: "Couldn’t unpack the update.") }
        let apps = (try fm.contentsOfDirectory(at: out, includingPropertiesForKeys: nil)).filter { $0.pathExtension == "app" }
        guard apps.count == 1, let app = apps.first,
              let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              info["CFBundleShortVersionString"] as? String == r.version,
              run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path]) == 0 else {
            throw Fail(errorDescription: "The downloaded update looks damaged.")
        }
        _ = run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", app.path])
        let dest = Bundle.main.bundlePath
        let script = """
        while /bin/kill -0 "$1" 2>/dev/null; do /bin/sleep 0.2; done
        /bin/rm -rf "$3.old"; /bin/mv "$3" "$3.old" && /usr/bin/ditto "$2" "$3" && /bin/rm -rf "$3.old" || { /bin/rm -rf "$3"; /bin/mv "$3.old" "$3"; }
        /usr/bin/open "$3"
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "/usr/bin/nohup /bin/sh -c '\(script.replacingOccurrences(of: "'", with: "'\\''"))' x \"$0\" \"$1\" \"$2\" >/dev/null 2>&1 &",
                       String(ProcessInfo.processInfo.processIdentifier), app.path, dest]
        guard dest.hasSuffix(".app") else { throw Fail(errorDescription: "Unexpected install location.") }
        try p.run()
        UserDefaults.standard.set(r.version, forKey: pendingKey)
        NSApp.terminate(nil)
    }

    func verifyPendingUpdate() {
        guard let want = UserDefaults.standard.string(forKey: pendingKey) else { return }
        UserDefaults.standard.removeObject(forKey: pendingKey)
        if Self.isNewer(want, than: currentVersion) {
            alert("Sentra Notch \(want) didn’t finish installing", "Please download it from the website and drag it into Applications.")
        }
    }

    @discardableResult private func run(_ tool: String, _ args: [String]) -> Int32 {
        let p = Process(); p.executableURL = URL(fileURLWithPath: tool); p.arguments = args
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return -1 }
        p.waitUntilExit(); return p.terminationStatus
    }

    private func alert(_ t: String, _ m: String) {
        let a = NSAlert(); a.messageText = t; a.informativeText = m
        NSApp.activate(ignoringOtherApps: true); a.runModal()
    }
}
