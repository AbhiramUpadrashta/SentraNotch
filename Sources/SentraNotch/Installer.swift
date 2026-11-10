//
//  Installer.swift — Sentra Notch
//  On first launch from Downloads or the disk image, offers to move Sentra Notch into Applications,
//  removes the download quarantine flag, deletes the downloaded copy and relaunches.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import AppKit
import Darwin

@MainActor
enum Installer {
    private static let skipKey = "skipMoveToApplications"

    /// Returns true when the app is being moved + relaunched (caller should stop launching).
    static func moveToApplicationsIfNeeded() -> Bool {
        let source = originalURL(for: Bundle.main.bundleURL)
        if isInApplications(source) || UserDefaults.standard.bool(forKey: skipKey) { return false }

        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "Move Sentra Notch to Applications?"
        a.informativeText = "Sentra Notch works best from the Applications folder: it shows up in Launchpad and Spotlight, can start at login, and updates install smoothly."
        a.addButton(withTitle: "Move to Applications")
        a.addButton(withTitle: "Not Now")
        a.showsSuppressionButton = true
        a.suppressionButton?.title = "Don’t ask again"
        let res = a.runModal()
        if a.suppressionButton?.state == .on { UserDefaults.standard.set(true, forKey: skipKey) }
        guard res == .alertFirstButtonReturn else { return false }

        let fm = FileManager.default
        let dest = URL(fileURLWithPath: "/Applications/Sentra Notch.app")
        do {
            if fm.fileExists(atPath: dest.path) { try fm.trashItem(at: dest, resultingItemURL: nil) }
            try fm.copyItem(at: source, to: dest)
        } catch {
            // /Applications isn't writable for this user: ask for the password once.
            let script = "do shell script \"/bin/rm -rf \" & quoted form of \"\(dest.path)\" & \"; /usr/bin/ditto \" & quoted form of \"\(source.path)\" & \" \" & quoted form of \"\(dest.path)\" & \"; /usr/sbin/chown -R \(getuid()) \" & quoted form of \"\(dest.path)\" with prompt \"Sentra Notch needs your password to move itself to Applications.\" with administrator privileges"
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            guard err == nil, fm.fileExists(atPath: dest.path) else {
                let f = NSAlert()
                f.messageText = "Couldn’t move Sentra Notch"
                f.informativeText = "Please drag Sentra Notch into your Applications folder in Finder."
                f.runModal()
                return false
            }
        }
        run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", dest.path])
        if !source.path.hasPrefix("/Volumes/") { try? fm.trashItem(at: source, resultingItemURL: nil) }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", dest.path]
        try? p.run()
        NSApp.terminate(nil)
        return true
    }

    static func isInApplications(_ url: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().path
        return path.hasPrefix("/Applications/") || path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path + "/Applications/")
    }

    private static func run(_ tool: String, _ args: [String]) {
        let p = Process(); p.executableURL = URL(fileURLWithPath: tool); p.arguments = args
        try? p.run(); p.waitUntilExit()
    }

    /// When macOS runs a downloaded app from a read-only copy ("App Translocation"), find the real .app on disk.
    private typealias IsTranslocatedFn = @convention(c) (CFURL, UnsafeMutablePointer<Bool>, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> DarwinBoolean
    private typealias OriginalPathFn = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?

    nonisolated static func originalURL(for url: URL) -> URL {
        guard let h = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY) else { return url }
        defer { dlclose(h) }
        guard let a = dlsym(h, "SecTranslocateIsTranslocatedURL"), let b = dlsym(h, "SecTranslocateCreateOriginalPathForURL") else { return url }
        let isT = unsafeBitCast(a, to: IsTranslocatedFn.self), orig = unsafeBitCast(b, to: OriginalPathFn.self)
        var t = false
        guard isT(url as CFURL, &t, nil).boolValue, t, let o = orig(url as CFURL, nil)?.takeRetainedValue() else { return url }
        return o as URL
    }
}
