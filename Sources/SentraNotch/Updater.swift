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
        // Where to install: the app's real place. If macOS is running us from a quarantine copy
        // (App Translocation) or from the disk image, install into /Applications instead.
        var dest = Installer.originalURL(for: Bundle.main.bundleURL).path
        if dest.contains("/AppTranslocation/") || dest.hasPrefix("/Volumes/") || !dest.hasSuffix(".app") {
            dest = "/Applications/Sentra Notch.app"
        }
        let log = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/SentraNotch-update.log").path
        let script = """
        exec >>"$4" 2>&1
        echo "$(date) installing $2 -> $3"
        i=0; while /bin/kill -0 "$1" 2>/dev/null && [ $i -lt 100 ]; do /bin/sleep 0.2; i=$((i+1)); done
        /bin/kill -9 "$1" 2>/dev/null
        swap() { /bin/rm -rf "$3.old"; if [ -e "$3" ]; then /bin/mv "$3" "$3.old" || return 1; fi
                 if /usr/bin/ditto "$2" "$3"; then /bin/rm -rf "$3.old"; return 0; fi
                 /bin/rm -rf "$3"; [ -e "$3.old" ] && /bin/mv "$3.old" "$3"; return 1; }
        if swap "$@"; then echo replaced
        else
          echo "needs admin"
          /usr/bin/osascript -e 'on run argv' -e 'do shell script "/bin/rm -rf " & quoted form of ((item 2 of argv) & ".old") & "; /bin/mv " & quoted form of (item 2 of argv) & " " & quoted form of ((item 2 of argv) & ".old") & " 2>/dev/null; /usr/bin/ditto " & quoted form of (item 1 of argv) & " " & quoted form of (item 2 of argv) & " && /bin/rm -rf " & quoted form of ((item 2 of argv) & ".old") & " && /usr/sbin/chown -R " & (item 3 of argv) & " " & quoted form of (item 2 of argv) with prompt "Sentra Notch needs your password to finish updating." with administrator privileges' -e 'end run' "$2" "$3" "$(/usr/bin/id -u)"
        fi
        /usr/bin/xattr -dr com.apple.quarantine "$3" 2>/dev/null
        /usr/bin/open "$3"
        echo done
        """
        let helper = work.appendingPathComponent("install.sh")
        try script.write(to: helper, atomically: true, encoding: .utf8)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "/usr/bin/nohup /bin/sh \"$0\" \"$1\" \"$2\" \"$3\" \"$4\" >/dev/null 2>&1 &",
                       helper.path, String(ProcessInfo.processInfo.processIdentifier), app.path, dest, log]
        try p.run()
        UserDefaults.standard.set(r.version, forKey: pendingKey)
        NSApp.terminate(nil)
    }

    func verifyPendingUpdate() {
        guard let want = UserDefaults.standard.string(forKey: pendingKey) else { return }
        UserDefaults.standard.removeObject(forKey: pendingKey)
        if Self.isNewer(want, than: currentVersion) {
            alert("Sentra Notch \(want) didn’t finish installing", "Please try Check for Updates again, or download it from the website and drag it into Applications. Details: ~/Library/Logs/SentraNotch-update.log")
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
