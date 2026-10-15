import AppKit
import SwiftUI

/// Exercises the real SwiftUI panel and AppKit sliders without processing audio.
@available(macOS 14.2, *)
@MainActor
final class MixerPreviewRenderer {
    private let view: TransparentMixerHostingView
    private let window: MixerPanel

    init() {
        view = TransparentMixerHostingView(rootView: MixerView(model: MixerModel(preview: true)))
        let size = view.fittingSize
        view.frame = NSRect(origin: .zero, size: size)
        window = MixerPanel(contentRect: view.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.contentView = view
    }

    func export(to url: URL) throws {
        // Let the same hosting view receive its new appearance before capturing it.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            view.cacheDisplay(in: view.bounds, to: bitmap)
        }
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: url)
    }

    static func exportAppearanceCycle(to directory: URL) throws {
        let application = NSApplication.shared
        application.finishLaunching()
        let originalAppearance = application.appearance
        defer { application.appearance = originalAppearance }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let renderer = MixerPreviewRenderer()
        for (name, appearance) in [
            ("Soundcheck-light", NSAppearance.Name.aqua),
            ("Soundcheck-dark", NSAppearance.Name.darkAqua),
            ("Soundcheck-light-after-dark", NSAppearance.Name.aqua)
        ] {
            application.appearance = NSAppearance(named: appearance)
            try renderer.export(to: directory.appendingPathComponent(name + ".png"))
        }
    }
}
