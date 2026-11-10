//
//  Shelf.swift — Sentra Notch
//  Drop files, images, links or text on the notch; drag them out again, Quick Look, AirDrop or share.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import AppKit
import QuickLookThumbnailing
import QuickLookUI
import SwiftUI
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var bookmark: Data?
    var text: String?
    var name: String

    var url: URL? {
        guard let bookmark else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI], bookmarkDataIsStale: &stale)
    }
}

@MainActor
final class ShelfModel: ObservableObject {
    static let shared = ShelfModel()
    @Published var items: [ShelfItem] = []
    @Published var selected = Set<UUID>()
    @Published var thumbs: [UUID: NSImage] = [:]
    private let key = "shelfItems"

    init() {
        if let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode([ShelfItem].self, from: d) {
            items = s.filter { $0.text != nil || $0.url != nil }
            items.forEach(thumb)
        }
    }

    private func save() { UserDefaults.standard.set(try? JSONEncoder().encode(items), forKey: key) }

    func add(url: URL) {
        var u = url
        if Prefs.bool(Prefs.copyOnDrag), u.isFileURL {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Sentra Notch/Shelf", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent(u.lastPathComponent)
            try? FileManager.default.removeItem(at: dest)
            if (try? FileManager.default.copyItem(at: u, to: dest)) != nil { u = dest }
        }
        if !u.isFileURL { add(text: u.absoluteString); return }
        guard !items.contains(where: { $0.url == u }), let bm = try? u.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        let it = ShelfItem(bookmark: bm, text: nil, name: u.lastPathComponent)
        withAnimation(.notchPeek) { items.append(it) }
        thumb(it); save()
    }

    func add(text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        withAnimation(.notchPeek) { items.append(ShelfItem(text: t, name: String(t.prefix(40)))) }
        save()
    }

    func remove(_ it: ShelfItem) {
        withAnimation(.notchPeek) { items.removeAll { $0.id == it.id }; selected.remove(it.id) }
        thumbs[it.id] = nil; save()
    }
    func clear() { withAnimation(.notchPeek) { items.removeAll(); selected.removeAll() }; thumbs.removeAll(); save() }
    func draggedOut(_ it: ShelfItem) { if Prefs.bool(Prefs.autoRemoveShelf) { remove(it) } }

    func handle(providers: [NSItemProvider]) -> Bool {
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = p.loadObject(ofClass: URL.self) { u, _ in if let u { Task { @MainActor in ShelfModel.shared.add(url: u) } } }
            } else if p.canLoadObject(ofClass: URL.self) {
                _ = p.loadObject(ofClass: URL.self) { u, _ in if let u { Task { @MainActor in ShelfModel.shared.add(url: u) } } }
            } else if p.canLoadObject(ofClass: String.self) {
                _ = p.loadObject(ofClass: String.self) { s, _ in if let s { Task { @MainActor in ShelfModel.shared.add(text: s) } } }
            } else if p.canLoadObject(ofClass: NSImage.self) {
                _ = p.loadObject(ofClass: NSImage.self) { img, _ in
                    guard let img = img as? NSImage, let tiff = img.tiffRepresentation,
                          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
                    let u = FileManager.default.temporaryDirectory.appendingPathComponent("Image \(Int(Date().timeIntervalSince1970)).png")
                    try? png.write(to: u)
                    Task { @MainActor in ShelfModel.shared.add(url: u) }
                }
            }
        }
        return true
    }

    private func thumb(_ it: ShelfItem) {
        guard let u = it.url else { return }
        let req = QLThumbnailGenerator.Request(fileAt: u, size: CGSize(width: 96, height: 96), scale: 2, representationTypes: .all)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
            let img = rep?.nsImage ?? NSWorkspace.shared.icon(forFile: u.path)
            Task { @MainActor in ShelfModel.shared.thumbs[it.id] = img }
        }
    }

    // Actions
    var selectedURLs: [URL] { items.filter { selected.contains($0.id) || selected.isEmpty }.compactMap(\.url) }
    func airDrop(_ urls: [URL]) {
        guard !urls.isEmpty, let s = NSSharingService(named: .sendViaAirDrop), s.canPerform(withItems: urls) else { return }
        s.perform(withItems: urls)
    }
    func share(_ items: [Any], from view: NSView?) {
        guard let view else { return }
        NSSharingServicePicker(items: items).show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
    func quickLook(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        QuickLooker.shared.urls = urls
        QuickLooker.shared.show()
    }
}

final class QuickLooker: NSObject, QLPreviewPanelDataSource {
    static let shared = QuickLooker()
    var urls: [URL] = []
    func show() {
        guard let p = QLPreviewPanel.shared() else { return }
        p.dataSource = self
        p.reloadData()
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { urls.count }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! { urls[index] as NSURL }
}

struct ShelfView: View {
    @ObservedObject var shelf = ShelfModel.shared
    @EnvironmentObject var model: NotchModel
    @State private var anchor: NSView?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(model.dropTargeted ? Color.sentraAccent : .white.opacity(0.18))
                .background(RoundedRectangle(cornerRadius: 16).fill(model.dropTargeted ? Color.sentraAccent.opacity(0.10) : .clear))
            if shelf.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 26)).foregroundStyle(.white.opacity(0.5))
                        .symbolEffect(.bounce, value: model.dropTargeted)
                    Text("Drop files, images or links here").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(shelf.items) { it in item(it) }
                    }.padding(10)
                }
            }
        }
        .background(ViewGrabber(view: $anchor))
        .overlay(alignment: .topTrailing) {
            if !shelf.items.isEmpty {
                HStack(spacing: 6) {
                    pill("airplayaudio", "AirDrop") { shelf.airDrop(shelf.selectedURLs) }
                    pill("square.and.arrow.up", "Share") {
                        let things: [Any] = shelf.items.filter { shelf.selected.isEmpty || shelf.selected.contains($0.id) }.map { $0.url ?? $0.text as Any }
                        shelf.share(things, from: anchor)
                    }
                    pill("trash", "Clear") { shelf.clear() }
                }.padding(6)
            }
        }
    }

    private func pill(_ icon: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.system(size: 10, weight: .semibold)).frame(width: 22, height: 22) }
            .buttonStyle(.plain).background(.white.opacity(0.10), in: Circle()).foregroundStyle(.white).help(help)
    }

    private func item(_ it: ShelfItem) -> some View {
        let isSel = shelf.selected.contains(it.id)
        return VStack(spacing: 4) {
            Group {
                if let img = shelf.thumbs[it.id] { Image(nsImage: img).resizable().scaledToFit() }
                else { Image(systemName: it.text != nil ? "text.quote" : "doc.fill").font(.system(size: 24)).foregroundStyle(.white.opacity(0.7)) }
            }.frame(width: 50, height: 50)
            Text(it.name).font(.system(size: 9.5, weight: .medium)).lineLimit(1).frame(width: 66).foregroundStyle(.white.opacity(0.8))
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 10).fill(isSel ? Color.sentraAccent.opacity(0.28) : .white.opacity(0.04)))
        .onTapGesture { if isSel { shelf.selected.remove(it.id) } else { shelf.selected.insert(it.id) } }
        .onTapGesture(count: 2) { if let u = it.url { NSWorkspace.shared.open(u) } }
        .onDrag {
            shelf.draggedOut(it)
            if let u = it.url { return NSItemProvider(contentsOf: u) ?? NSItemProvider() }
            return NSItemProvider(object: (it.text ?? "") as NSString)
        }
        .contextMenu {
            if let u = it.url {
                Button("Open") { NSWorkspace.shared.open(u) }
                Button("Quick Look") { shelf.quickLook([u]) }
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([u]) }
                Button("AirDrop") { shelf.airDrop([u]) }
                Button("Copy Path") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(u.path, forType: .string) }
            } else if let t = it.text {
                Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(t, forType: .string) }
                if let u = URL(string: t), u.scheme?.hasPrefix("http") == true { Button("Open Link") { NSWorkspace.shared.open(u) } }
            }
            Divider()
            Button("Remove from Shelf", role: .destructive) { shelf.remove(it) }
        }
    }
}

struct ViewGrabber: NSViewRepresentable {
    @Binding var view: NSView?
    func makeNSView(context: Context) -> NSView { let v = NSView(); DispatchQueue.main.async { view = v }; return v }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
