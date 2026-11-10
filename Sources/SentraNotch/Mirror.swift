//
//  Mirror.swift — Sentra Notch
//  A quick camera mirror in the open notch.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import AVFoundation
import SwiftUI

final class MirrorCamera {
    static let shared = MirrorCamera()
    let session = AVCaptureSession()
    private var configured = false
    private let queue = DispatchQueue(label: "sentra.camera")

    func start() {
        queue.async { [self] in
            if !configured {
                guard let dev = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: dev),
                      session.canAddInput(input) else { return }
                session.sessionPreset = .medium
                session.addInput(input)
                configured = true
            }
            if !session.isRunning { session.startRunning() }
        }
    }
    func stop() { queue.async { [self] in if session.isRunning { session.stopRunning() } } }

    static var allowed: Bool { AVCaptureDevice.authorizationStatus(for: .video) == .authorized }
    static func request(_ done: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { ok in DispatchQueue.main.async { done(ok) } }
    }
}

struct CameraPreview: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: MirrorCamera.shared.session)
        layer.videoGravity = .resizeAspectFill
        layer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))   // mirror
        v.layer = layer
        MirrorCamera.shared.start()
        return v
    }
    func updateNSView(_ v: NSView, context: Context) {}
    static func dismantleNSView(_ v: NSView, coordinator: ()) { MirrorCamera.shared.stop() }
}
